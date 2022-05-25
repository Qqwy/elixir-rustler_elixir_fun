use rustler::*;
use rustler::types::LocalPid;
use rustler::error::Error;
use rustler_sys;
use std::mem::MaybeUninit;
use rustler::wrapper::ErlNifPid;
use std::sync::{Mutex, Condvar};
use std::time::Duration;

struct WaitForResponse {
    mutex: Mutex<Option<bool>>,
    cond: Condvar,
}

impl WaitForResponse {
    pub fn new() -> WaitForResponse {
        WaitForResponse {mutex: Mutex::new(None), cond: Condvar::new()}
    }

    pub fn wait_until_unlocked(& self) {
        let guard = self.cond.wait_timeout_while(
            self.mutex.lock().unwrap(),
            Duration::from_millis(5000),
            |pending| { pending.is_some() }
        )
            .unwrap();
        println!("{:?}", guard)
    }
    pub fn unlock<'a>(&self, value: Term<'a>) {
        let mut started = self.mutex.lock().unwrap();
        *started = Some(true);
        self.cond.notify_all();
    }
}

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(WaitForResponse, env);
    true
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

fn whereis_pid<'a>(env: Env<'a>, name: Term<'a>) -> Result<LocalPid, Error> {
    let mut enif_pid = MaybeUninit::uninit();

    if unsafe { rustler_sys::enif_whereis_pid(env.as_c_arg(), name.as_c_arg(), enif_pid.as_mut_ptr()) } == 0 {
        Err(Error::Atom("No pid registered under the given name."))
    } else {
        // Safety: Initialized by successful enif call
        let enif_pid = unsafe {enif_pid.assume_init()};

        // Safety: Safe because `LocalPid` has only one field.
        // NOTE: Dirty hack, but there is no other way to create a LocalPid exposed from `rustler`.
        let pid = unsafe { std::mem::transmute::<ErlNifPid, LocalPid>(enif_pid) };
        Ok(pid)
    }
}

#[rustler::nif]
fn send_to_elixir<'a>(env: Env<'a>, pid: Term<'a>, value: Term<'a>) -> Result<(), Error> {
    do_send_to_elixir(env, pid, value)
    // let binary = String::from("Hello world!").encode(env);
    // let pid : LocalPid = pid.decode().or_else(|_| whereis_pid(env, pid))?;

    // env.send(&pid, binary);
    // Ok(())
}

fn do_send_to_elixir<'a>(env: Env<'a>, pid: Term<'a>, value: Term<'a>) -> Result<(), Error> {
    // let binary = String::from("Hello world!").encode(env);
    let pid : LocalPid = pid.decode().or_else(|_| whereis_pid(env, pid))?;

    env.send(&pid, value);
    Ok(())
}

#[rustler::nif]
fn apply_elixir_fun<'a>(env: Env<'a>, pid_or_name: Term<'a>, fun: Term<'a>, parameters: Term<'a>) -> Result<(), Error> {
    if fun.is_fun() {
        let wait1 = ResourceArc::new(WaitForResponse::new());
        // let wait2 = ResourceArc::clone(&wait1);
        // let lock_and_cond = ResourceArc::new((Mutex::new(true), Condvar::new()));
        // let lock_and_cond2 = Arc::clone(lock_and_cond);

        let fun_tuple = rustler::types::tuple::make_tuple(env, &[fun, parameters, wait1.encode(env)]);

        // env.send(pid, fun_tuple)
        do_send_to_elixir(env, pid_or_name, fun_tuple);

        println!("Waiting for response");
        wait1.wait_until_unlocked();

        println!("Finished waiting for response!");
        Ok(())
    } else {
        Err(Error::Atom("`apply_elixir_fun` called with a term that is not a function."))
    }
}

#[rustler::nif]
fn callback_result<'a>(env: Env<'a>, result: Term<'a>, wait2: ResourceArc<WaitForResponse>) {
    println!("callback result called with: {:?}", result);
    wait2.unlock(result);
}

rustler::init!("Elixir.RustlerElixirFun", [send_to_elixir, apply_elixir_fun, callback_result], load = load);
