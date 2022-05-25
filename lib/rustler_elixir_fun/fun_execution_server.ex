defmodule RustlerElixirFun.FunExecutionServer do
  use GenServer
  def start_link(_) do
    GenServer.start_link(__MODULE__, {})
    # GenServer.start_link(__MODULE__, {}, name: __MODULE__)
  end

  @impl true
  def init({}) do
    {:ok, {}}
  end

  @impl true
  # Used when we call it directly
  def handle_info({fun, params, future}, state) when is_function(fun) and is_list(params) and is_reference(future) do
    run_function(fun, params, future)
    {:noreply, state}
  end

  @impl true
  # Used when we call it from a pool
  def handle_cast({{fun, params, future}, from}, state) when is_function(fun) and is_list(params) and is_reference(future) do
    IO.puts("Using worker #{inspect(self())}")

    run_function(fun, params, future)
    GenServer.cast(from, {:checkin, self()})
    {:noreply, state}
  end

  defp run_function(fun, params, future) do
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
    RustlerElixirFun.Internal.fill_future(result, future)
  end
end
