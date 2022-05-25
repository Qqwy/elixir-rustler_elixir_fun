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

  def send_to_elixir(_pid, _value), do: :erlang.nif_error(:nif_not_loaded)

  def apply_elixir_fun(_pid_or_name, _fun, _parameters), do: :erlang.nif_error(:nif_not_loaded)

  def callback_result(_result, _resource), do: :erlang.nif_error(:nif_not_loaded)

  defmodule Foo do
    use GenServer
    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    @impl true
    def init(state) do
      {:ok, state}
    end

    def handle_info({fun, params, waiter}, state) when is_function(fun) and is_list(params) do
      IO.inspect("Foo Received function and params: #{inspect(fun)}, #{inspect(params)}")
      result = apply(fun, params)
      IO.inspect(result, label: :result)
      RustlerElixirFun.callback_result(result, waiter)

      {:noreply, state}
    end

    @impl true
    def handle_info(msg, state) do
      IO.inspect("Foo Received other message: #{inspect(msg)}")

      {:noreply, state}
    end
  end
end
