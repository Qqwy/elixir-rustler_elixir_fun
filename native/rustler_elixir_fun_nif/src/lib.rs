use rustler::*;
use rustler::error::Error;
use rustler_stored_term::StoredTerm;
use rustler_elixir_fun;
use rustler_elixir_fun::ManualFuture;

fn load(_env: Env, _info: Term) -> bool {
    true
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif(
    name = "apply_elixir_fun",
    schedule = "DirtyCpu"
)]
/// Exposed as NIF for easy testing
/// But normally, you'd want to call `rustler_elixir_fun::apply_elixir_fun`
/// from some other Rust code (rather than from Elixir) instead.
fn apply_elixir_fun_nif<'a>(env: Env<'a>, pid_or_name: Term<'a>, fun: Term<'a>, parameters: Term<'a>) -> Result<Term<'a>, Error> {
    Ok(rustler_elixir_fun::apply_elixir_fun(env, pid_or_name, fun, parameters)?.encode(env))
}

#[rustler::nif]
/// Called by the internal Elixir code of this library whenever a function is completed.
///
/// Should not be called manually from your own Elixir code.
// fn fill_future<'a>(result: StoredTerm, future: ResourceArc<ManualFuture>) {
//     future.fill(result);
// }

fn fill_future<'a>(result: StoredTerm, raw_future_ptr: usize) {
    let future_ptr = raw_future_ptr as *const ManualFuture;
    unsafe { future_ptr.as_ref().expect("Should be a ManualFuture") }.fill(result);
}

rustler::init!("Elixir.RustlerElixirFun.Internal", [apply_elixir_fun_nif, fill_future], load = load);
