defmodule RustlerElixirFun do
  # @moduledoc """
  # Documentation for `RustlerElixirFun`.
  # """

  # @doc """
  # Hello world.

  # ## Examples

  #     iex> RustlerElixirFun.hello()
  #     :world

  # """
  # def hello do
  #   :world
  # end
  use Rustler,
    otp_app: :rustler_elixir_fun,
    crate: :rustler_elixir_fun

  # def send_to_elixir(_pid, _value), do: :erlang.nif_error(:nif_not_loaded)

  def apply_elixir_fun(_pid_or_name, _fun, _parameters), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  # Called internally by the wrapper process
  # once it has finished running the elixir function,
  # but should not ever be called directly.
  def fill_future(_result, _future), do: :erlang.nif_error(:nif_not_loaded)

  defmodule FunExecutionServer do
    use GenServer
    def start_link() do
      GenServer.start_link(__MODULE__, {}, name: __MODULE__)
    end

    @impl true
    def init({}) do
      {:ok, {}}
    end

    @impl true
    def handle_info({fun, params, future}, state) when is_function(fun) and is_list(params) do
      IO.inspect("Foo Received function and params: #{inspect(fun)}, #{inspect(params)}")
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
      # IO.inspect(result, label: :result)
      RustlerElixirFun.fill_future(result, future)

      {:noreply, state}
    end
  end
end
