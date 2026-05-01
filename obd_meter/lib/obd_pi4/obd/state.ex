defmodule ObdPi4.Obd.State do
  use GenServer

  @pids [:rpm, :coolant_temp_c, :ignition_advance_deg, :map_kpa, :battery_v]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def get, do: GenServer.call(__MODULE__, :get)

  def put(values) when is_map(values), do: GenServer.cast(__MODULE__, {:put, values})
  def set_status(status) when status in [:connected, :disconnected], do: GenServer.cast(__MODULE__, {:status, status})

  @impl true
  def init(_arg) do
    initial =
      @pids
      |> Enum.map(fn key -> {key, nil} end)
      |> Map.new()
      |> Map.put(:status, :disconnected)
      |> Map.put(:updated_at, nil)

    {:ok, initial}
  end

  @impl true
  def handle_call(:get, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:put, values}, state) do
    next_state =
      state
      |> Map.merge(values)
      |> Map.put(:updated_at, System.system_time(:millisecond))
      |> Map.put(:status, :connected)

    {:noreply, next_state}
  end

  @impl true
  def handle_cast({:status, status}, state) do
    {:noreply, Map.put(state, :status, status)}
  end
end
