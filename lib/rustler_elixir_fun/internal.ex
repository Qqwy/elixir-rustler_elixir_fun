defmodule RustlerElixirFun.Internal do
  use Rustler,
    otp_app: :rustler_elixir_fun,
    crate: :rustler_elixir_fun

  @doc """
  Calls the Rust NIF directly.

  This is mainly useful to simplify testing;
  in your actual projects, you'll want to call the Rust function directly from your Rust code.
  """
  def apply_elixir_fun(_pid_or_name, _fun, _parameters), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  # Called internally by the wrapper process
  # once it has finished running the elixir function,
  # but should not ever be called directly.
  def fill_future(_result, _future), do: :erlang.nif_error(:nif_not_loaded)
end
