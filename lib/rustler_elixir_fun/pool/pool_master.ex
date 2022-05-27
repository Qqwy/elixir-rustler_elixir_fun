defmodule RustlerElixirFun.Pool.PoolMaster do
  @moduledoc """
  Delegates work to the various workers in the pool.

  This module is used internally when interacting with `RustlerElixirFun.Pool`.
  """
  use GenServer
  def start_link(pool_name) do
    GenServer.start_link(__MODULE__, %{pool_name: pool_name}, name: pool_name)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_info({fun, params, future_ptr}, state) when is_function(fun) and is_list(params) and is_integer(future_ptr) do
    worker = :poolboy.checkout(RustlerElixirFun.Pool.poolboy_pool_name(state.pool_name))
    GenServer.cast(worker, {{fun, params, future_ptr}, self()})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:checkin, from}, state) do
    :poolboy.checkin(RustlerElixirFun.Pool.poolboy_pool_name(state.pool_name), from)
    {:noreply, state}
  end
end
