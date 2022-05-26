# RustlerElixirFun

Calling an Elixir or Erlang function from native Rust code.

This is a work-in-progress.

## Installation

`rustler_elixir_fun` is split into two parts: an Elixir library, and a Rust library.
In a project where you are writing your own NIF, you'll need both.


First, add the [Rust crate](https://crates.io/crates/rustler_elixir_fun) to your `Crate.toml`:

```
[dependencies]
rustler_elixir_fun = "0.1.0"
```

Secondly, add the [Elixir library](https://hex.pm/packages/rustler_elixir_fun) to your `mix.exs`:
```elixir
def deps do
  [
    {:rustler_elixir_fun, "~> 0.1.0"}
  ]
end
```


## Basic usage

Make sure you have started either [`RustlerElixirFun.FunExecutionServer`](https://hexdocs.pm/rustler_elixir_fun/RustlerElixirFun.FunExecutionServer.html) or [`RustlerElixirFun.Pool`](https://hexdocs.pm/rustler_elixir_fun/RustlerElixirFun.Pool.html) depending on how often you expect calls to be made. Using a pool is slightly slower but does not have a single-process bottleneck.

You'll probably want to start one or the other of these under your supervision tree, as a named process (See the Elixir documentation for more details).

Now, in your Rust code, you'll want to call [`rustler_elixir_fun::apply_elixir_fun(env, pid_or_name, fun, parameters)`](https://docs.rs/rustler_elixir_fun/0.1.0/rustler_elixir_fun/fn.apply_elixir_fun.html).

This will, assuming that `pid_or_name` refers to the server or pool you've started earlier, run the Elixir function `fun` by passing it the `parameters`, returning its result.
See the [Rust documentation](https://docs.rs/rustler_elixir_fun/0.1.0/rustler_elixir_fun/fn.apply_elixir_fun.html) for more details.

## Documentation

- Elixir documentation can be found at [https://hexdocs.pm/rustler_elixir_fun](https://hexdocs.pm/rustler_elixir_fun).
- Rust documentation can be found at [https://docs.rs/rustler_elixir_fun/](https://docs.rs/rustler_elixir_fun/).

## How does it work?

In diagram form:

![sequence_diagram](/media/rustler_elixir_fun_sequence_diagram.png)

In text form:

1. In native code, create a manual 'future' (a mutex wrapping a potentially-empty value, and a condition variable).
2. Wrap this 'future' into a reference which can be passed back to Elixir.
3. Send `{fun, params, future_ref}` to a particular process <small>(or pool of processes)</small> which you've been running.
4. Block the native code until the future is filled. <small>(Or a timeout is triggered)</small>
5. In the elixir GenServer, run the function, <small>(handle errors)</small> and once the result is obtained, call a _second_ NIF with the result and the future_ref.
6. This NIF will 'fill' the future with the passed result and immediately return.
7. Now the original native code will continue.

## How fast is it?

A simple benchmark has been set up to check the overhead of calling a simple function (`fn x -> x * x end`) directly from elixir (using `apply(fun, [some_number])`) vs calling a NIF which will use `rustler_elixir_fun` to call back into Elixir.

The outcome: It is not super fast, but for many situations it will be fast enough. It takes roughly 85 times longer, at 9.5µs vs 0.11µs.

This overhead, while not neglegible, might still be considered ‘good enough’ for many projects, as an overhead of 9.5µs will often be overshadowed if there is some actual work (such as communication with other processes, IO, etc.) going on inside the function.

Run these benchmarks yourself by (after cloning the repo) running

```
MIX_ENV=bench mix run bench/call_overhead.ex 
```


```
$ MIX_ENV=bench mix run bench/call_overhead.ex 
Operating System: Linux
CPU Information: Intel(R) Core(TM) i7-6700HQ CPU @ 2.60GHz
Number of Available Cores: 8
Available memory: 31.18 GB
Elixir 1.12.0
Erlang 24.0.1

Benchmark suite executing with the following configuration:
warmup: 2 s
time: 5 s
memory time: 0 ns
reduction time: 0 ns
parallel: 1
inputs: 100, 100_000, 100_000_000
Estimated total run time: 1.40 min

Benchmarking apply(fun, param) with input 100 ...
Benchmarking apply(fun, param) with input 100_000 ...
Benchmarking apply(fun, param) with input 100_000_000 ...
Benchmarking apply_elixir_fun(Pool, fun, param) with input 100 ...
Benchmarking apply_elixir_fun(Pool, fun, param) with input 100_000 ...
Benchmarking apply_elixir_fun(Pool, fun, param) with input 100_000_000 ...
Benchmarking apply_elixir_fun(Server, fun, param) with input 100 ...
Benchmarking apply_elixir_fun(Server, fun, param) with input 100_000 ...
Benchmarking apply_elixir_fun(Server, fun, param) with input 100_000_000 ...
Benchmarking fun.(param) with input 100 ...
Benchmarking fun.(param) with input 100_000 ...
Benchmarking fun.(param) with input 100_000_000 ...

##### With input 100 #####
Name                                           ips        average  deviation         median         99th %
apply(fun, param)                           8.65 M       0.116 μs   ±144.37%       0.114 μs       0.178 μs
fun.(param)                                 8.64 M       0.116 μs   ±147.69%       0.114 μs       0.156 μs
apply_elixir_fun(Pool, fun, param)         0.104 M        9.63 μs   ±222.87%        8.54 μs       27.16 μs
apply_elixir_fun(Server, fun, param)       0.101 M        9.95 μs   ±233.02%        8.68 μs       27.38 μs

Comparison: 
apply(fun, param)                           8.65 M
fun.(param)                                 8.64 M - 1.00x slower +0.00003 μs
apply_elixir_fun(Pool, fun, param)         0.104 M - 83.27x slower +9.51 μs
apply_elixir_fun(Server, fun, param)       0.101 M - 86.01x slower +9.83 μs

##### With input 100_000 #####
Name                                           ips        average  deviation         median         99th %
apply(fun, param)                           8.55 M       0.117 μs   ±140.47%       0.115 μs       0.160 μs
fun.(param)                                 8.41 M       0.119 μs   ±131.56%       0.115 μs       0.180 μs
apply_elixir_fun(Server, fun, param)       0.104 M        9.59 μs   ±209.01%        8.53 μs       26.84 μs
apply_elixir_fun(Pool, fun, param)        0.0994 M       10.06 μs   ±179.97%        8.80 μs       27.30 μs

Comparison: 
apply(fun, param)                           8.55 M
fun.(param)                                 8.41 M - 1.02x slower +0.00198 μs
apply_elixir_fun(Server, fun, param)       0.104 M - 82.02x slower +9.47 μs
apply_elixir_fun(Pool, fun, param)        0.0994 M - 86.05x slower +9.94 μs

##### With input 100_000_000 #####
Name                                           ips        average  deviation         median         99th %
fun.(param)                                 8.42 M       0.119 μs   ±114.30%       0.115 μs       0.185 μs
apply(fun, param)                           8.27 M       0.121 μs   ±141.67%       0.118 μs        0.25 μs
apply_elixir_fun(Server, fun, param)       0.103 M        9.75 μs   ±219.29%        8.53 μs       27.54 μs
apply_elixir_fun(Pool, fun, param)        0.0961 M       10.40 μs   ±193.83%        8.94 μs       27.95 μs

Comparison: 
fun.(param)                                 8.42 M
apply(fun, param)                           8.27 M - 1.02x slower +0.00213 μs
apply_elixir_fun(Server, fun, param)       0.103 M - 82.08x slower +9.63 μs
apply_elixir_fun(Pool, fun, param)        0.0961 M - 87.54x slower +10.28 μs
```

## Attribution & Thanks

I did not come up with this on my own. Very clever people have recognized this approach before.

Thank you, [Erlang Forums user @robashton](https://erlangforums.com/t/how-to-call-a-fun-from-a-nif/915/8?u=qqwy) and [GitHub user @tessi](https://github.com/tessi/wasmex/issues/256#issuecomment-848339952) for your explanations and inspiration!
