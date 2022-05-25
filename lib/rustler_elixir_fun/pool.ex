defmodule RustlerElixirFun.Pool do
  use Application
  @pool_name :worker

  defp poolboy_config do
    [
      name: {:local, @pool_name},
      worker_module: RustlerElixirFun.FunExecutionServer,
      size: 50,
      max_overflow: 20
    ]
  end

  def start(_type, _args) do
    children = [
      :poolboy.child_spec(@pool_name, poolboy_config()),
      __MODULE__.PoolMaster
    ]
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defmodule PoolMaster do
    use GenServer
    def start_link(_) do
      GenServer.start_link(__MODULE__, {}, name: __MODULE__)
    end

    def init(_) do
      {:ok, {}}
    end

    def handle_info({fun, params, future}, state) when is_function(fun) and is_list(params) and is_reference(future) do
      worker = :poolboy.checkout(:worker)
      GenServer.cast(worker, {{fun, params, future}, self()})
      {:noreply, state}
    end
    def handle_cast({:checkin, from}, state) do
      :poolboy.checkin(:worker, from)
      {:noreply, state}
    end
  end
end
