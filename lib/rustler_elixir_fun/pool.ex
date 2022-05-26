defmodule RustlerElixirFun.Pool do
  @default_options [name: __MODULE__, size: 50, max_overflow: 20]

  @moduledoc """
  This Supervisor manages a pool of worker processes
  which will each listen to native code sending sets of functions + parameters.

  Currently uses the default options:
  ```
  #{inspect(@default_options)}
  ```

  Note that when starting, the 'name' will be used as registered name for the `RustlerElixirFun.Pool.PoolMaster` process.
  You can use this name directly in the native Rust code.

  (If you ever need to interact with the poolboy pool itself: its name will be `name` + `.PoolboyPool`).


      iex> Supervisor.start_link(RustlerElixirFun.Pool, [name: MyPool])
      iex> ((1..100)
      iex> |> Task.async_stream(fn i -> RustlerElixirFun.Internal.apply_elixir_fun(MyPool, fn x -> x * 2 end, [i]) end, max_concurrency: 50)
      iex> |> Enum.to_list
      iex> |> Enum.map(fn {:ok, {:ok, val}} -> val end)
      iex> |> Enum.sum() )
      10100
  """

  use Supervisor

  defp poolboy_config(pool_name, size, max_overflow) do
    [
      name: {:local, poolboy_pool_name(pool_name)},
      worker_module: RustlerElixirFun.FunExecutionServer,
      size: size,
      max_overflow: max_overflow
    ]
  end

  @doc false
  def poolboy_pool_name(pool_name) do
    Module.concat(pool_name, "PoolboyBool")
  end

  def start_link(options \\ @default_options) when is_list(options) do
    Supervisor.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    pool_name = options[:name] || @default_options[:name]
    size = options[:size] || @default_options[:max_overflow]
    max_overflow = options[:max_overflow] || @default_options[:max_overflow]
    children = [
      :poolboy.child_spec(pool_name, poolboy_config(pool_name, size, max_overflow)),
      {__MODULE__.PoolMaster, pool_name}
    ]
    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
