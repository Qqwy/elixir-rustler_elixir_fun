defmodule RustlerElixirFun.FunExecutionServer do
  @moduledoc """
  This GenServer listens for native code to send sets of functions + parameters to it.

  It will then execute these functions (by calling `apply(fun, parameters)` on them),
  and return the results to the native code.


    iex> {:ok, pid} = RustlerElixirFun.FunExecutionServer.start_link([])
    iex> RustlerElixirFun.Internal.apply_elixir_fun(pid, fn x -> x * 2 end, [10])
    {:ok, 20}

  It is recommended to use a registered name (and start the process in a supervision tree)
  to make sure that you won't have to handle checking PIDs for aliveness in native code:

    iex> {:ok, _} = RustlerElixirFun.FunExecutionServer.start_link([name: :my_fancy_worker_server])
    iex> RustlerElixirFun.Internal.apply_elixir_fun(:my_fancy_worker_server, fn x -> x * 2 end, [42])
    {:ok, 84}

  If you might call a function many times in short succession, or want to call many different functions,
  it might make sense to use `RustlerElixirFun.Pool` instead.
"""

  use GenServer
  def start_link(gen_server_options) do
    GenServer.start_link(__MODULE__, {}, gen_server_options)
    # GenServer.start_link(__MODULE__, {}, name: __MODULE__)
  end

  @impl true
  def init({}) do
    {:ok, {}}
  end

  @impl true
  # Used when called directly from native code
  def handle_info({fun, params, future_ptr}, state) when is_function(fun) and is_list(params) and is_integer(future_ptr) do
    run_function(fun, params, future_ptr)
    {:noreply, state}
  end

  @impl true
  # Used when called from a pool
  def handle_cast({{fun, params, future_ptr}, from}, state) when is_function(fun) and is_list(params) and is_integer(future_ptr) do
    run_function(fun, params, future_ptr)
    GenServer.cast(from, {:checkin, self()})
    {:noreply, state}
  end

  defp run_function(fun, params, future_ptr) do
    result =
      try do
        apply(fun, params)
      rescue
        exception ->
          {:error, {:exception, exception}}
      catch
        kind, problem when kind in [:exit, :throw] ->
          {:error, {kind, problem}}
      else
        good_result ->
          {:ok, good_result}
      end
    RustlerElixirFun.Internal.fill_future(result, future_ptr)
  end
end
