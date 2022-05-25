fun = fn x -> x * x end
{:ok, _} = Supervisor.start_link(RustlerElixirFun.Pool, [name: MyPool])
{:ok, _} = RustlerElixirFun.FunExecutionServer.start_link([name: Server])

Benchee.run(
  %{"fun.(param)" => fn param -> fun.(param) end,
    "apply(fun, param)" => fn param -> apply(fun, [param]) end,
    "apply_elixir_fun(Pool, fun, param)" => fn param -> RustlerElixirFun.Internal.apply_elixir_fun(Server, fun, [param]) end,
    "apply_elixir_fun(Server, fun, param)" => fn param -> RustlerElixirFun.Internal.apply_elixir_fun(Server, fun, [param]) end,
},
  inputs: %{
    "100" => 100,
    "100_000" => 100_000,
    "100_000_000" => 100_000_000,
  }
)
