mod stored_term;

use rustler::*;
use rustler::types::LocalPid;
use rustler::error::Error;
use rustler_sys;
use std::mem::MaybeUninit;
use rustler::wrapper::ErlNifPid;
use std::sync::{Mutex, Condvar};
use std::time::Duration;
use crate::stored_term::StoredTerm;

struct ManualFuture {
    mutex: Mutex<Option<StoredTerm>>,
    cond: Condvar,
}

impl ManualFuture {
    pub fn new() -> ManualFuture {
        ManualFuture {mutex: Mutex::new(None), cond: Condvar::new()}
    }

    pub fn wait_until_filled(& self) -> Result<StoredTerm, Error> {
        let (mut guard, wait_timeout_result) = self.cond.wait_timeout_while(
            self.mutex.lock().unwrap(),
            Duration::from_millis(5000),
            |pending| { pending.is_none() }
        )
            .unwrap();
        if wait_timeout_result.timed_out() {
            // println!("{}", "Unfortunately timed out!")
            Err(Error::Atom("Unfortunately timed out!"))
        } else {
            let val = guard.take().unwrap();
            Ok(val)
        }
        // println!("{:?}", guard)
    }
    pub fn fill(&self, value: StoredTerm) {
        let mut started = self.mutex.lock().unwrap();
        *started = Some(value);
        self.cond.notify_all();
    }
}

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(ManualFuture, env);
    true
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

/// Attempts to turn `name` into a LocalPid
/// Uses [`enif_whereis_pid`](https://www.erlang.org/doc/man/erl_nif.html#enif_whereis_pid) under the hood.
///
/// NOTE: Current implementation is very dirty, as we use transmutation to build a struct whose internals are not exposed by Rustler itself.
fn whereis_pid<'a>(env: Env<'a>, name: Term<'a>) -> Result<LocalPid, Error> {
    let mut enif_pid = MaybeUninit::uninit();

    if unsafe { rustler_sys::enif_whereis_pid(env.as_c_arg(), name.as_c_arg(), enif_pid.as_mut_ptr()) } == 0 {
        Err(Error::Term(Box::new("No pid registered under the given name.")))
    } else {
        // Safety: Initialized by successful enif call
        let enif_pid = unsafe {enif_pid.assume_init()};

        // Safety: Safe because `LocalPid` has only one field.
        // NOTE: Dirty hack, but there is no other way to create a LocalPid exposed from `rustler`.
        let pid = unsafe { std::mem::transmute::<ErlNifPid, LocalPid>(enif_pid) };
        Ok(pid)
    }
}

// #[rustler::nif]
// fn send_to_elixir<'a>(env: Env<'a>, pid: Term<'a>, value: Term<'a>) -> Result<(), Error> {
//     do_send_to_elixir(env, pid, value)
// }

fn do_send_to_elixir<'a>(env: Env<'a>, pid: Term<'a>, value: Term<'a>) -> Result<(), Error> {
    let pid : LocalPid = pid.decode().or_else(|_| whereis_pid(env, pid))?;

    env.send(&pid, value);
    Ok(())
}

/// Will run `fun` with the parameters `parameters`
/// on the process indicated by `pid_or_name`.
///
/// Returns an Ok result whose content is a term which might be one of:
/// - `{:ok, some_term}` on a successfull call.
/// - `{:error, {:exception, some_exception}}` if the function `raise`d an exception.
/// - `{:error, {:exit, exit_message}}` if an exit was caught.
/// - `{:error, {:throw, value}}` if a value was `throw`n.
///
/// Raises an ArgumentError (e.g. returns `Err(Error::BadArg)` on the Rust side) if `fun` is not a function or `parameters` is not a list.
#[rustler::nif(schedule = "DirtyCpu")]
fn apply_elixir_fun<'a>(env: Env<'a>, pid_or_name: Term<'a>, fun: Term<'a>, parameters: Term<'a>) -> Result<Term<'a>, Error> {
    if !fun.is_fun() {
        return Err(Error::BadArg)
    }

    if !parameters.is_list() {
        return Err(Error::BadArg)
    }

    let future = ResourceArc::new(ManualFuture::new());
    let fun_tuple = rustler::types::tuple::make_tuple(env, &[fun, parameters, future.encode(env)]);
    do_send_to_elixir(env, pid_or_name, fun_tuple)?;

    // println!("Waiting for response");
    let result = future.wait_until_filled()?;
    let result = result.encode(env); // Turns StoredTerm into Term
    Ok(result)
}

#[rustler::nif]
fn fill_future<'a>(result: StoredTerm, future: ResourceArc<ManualFuture>) {
    future.fill(result);
}

rustler::init!("Elixir.RustlerElixirFun", [apply_elixir_fun, fill_future], load = load);
