# rustler_elixir_fun

Ever wanted to call an Elixir function from inside some Rust code?
Now you can!

This crate exposes the Rust code to interact with from your Rust code side.

See [the main GitHub repo](https://github.com/Qqwy/elixir-rustler_elixir_fun/) for more details.

## Installation

- Add it as a dependency to your `Cargo.toml`.
- Add the Elixir library of the same name to your `mix.exs`.

## Usage

The main function to call is `apply_elixir_fun`:
```rust
let some_result : Result<Term, Error> = rustler_elixir_fun::apply_elixir_fun(env, pid_or_process_name, fun, parameters)
```

This function will attempt to call `fun` using `parameters` on the Elixir side, and block the caller until a result is available.

- Be sure to register any NIF that calls this function as a 'Dirty CPU NIF'! (by annotating your NIFs with `#[rustler::nif(schedule = "DirtyCpu")]`).
  This is important for two reasons:
    1. calling back into Elixir might indeed take quite some time.
    2. we want to prevent schedulers to wait for themselves, which might otherwise sometimes happen.
