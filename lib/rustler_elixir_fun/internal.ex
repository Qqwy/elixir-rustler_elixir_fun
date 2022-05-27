defmodule RustlerElixirFun.Internal do
  use Rustler,
    otp_app: :rustler_elixir_fun,
    crate: :rustler_elixir_fun_nif

  @doc """
  Calls the Rust NIF directly.

  This is mainly useful to simplify testing;
  in your actual projects, you'll want to call the Rust function directly from your Rust code.
  """
  def apply_elixir_fun(_pid_or_name, _fun, _parameters), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calls the Rust NIF directly.

  This is mainly useful to simplify testing;
  in your actual projects, you'll want to call the Rust function directly from your Rust code.

  This variant allows customizing the maximum time we wait for the function to return (to prevent any deadlocks).
  """
  def apply_elixir_fun_timeout(_pid_or_name, _fun, _parameters, _timeout_milliseconds), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  # Called internally by the wrapper process
  # once it has finished running the elixir function,
  # but should not ever be called directly.
  def fill_future(_result, _future_ptr), do: :erlang.nif_error(:nif_not_loaded)
end
