defmodule ObdPi4.Obd.Reader do
  use GenServer

  alias ObdPi4.Obd.Parser
  alias ObdPi4.Obd.State

  @interval_ms 200

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_arg) do
    state = %{tick: 0, device: System.get_env("OBD_DEVICE", "/dev/ttyUSB0")}
    Process.send_after(self(), :poll, @interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, %{tick: tick} = state) do
    # Phase 1: 実機未接続でもUI確認できるようにダミー値を投入。
    values =
      %{
        rpm: 800 + rem(tick * 120, 6000),
        coolant_temp_c: 70 + rem(tick, 25),
        ignition_advance_deg: 5 + rem(tick, 20),
        map_kpa: 30 + rem(tick, 50),
        battery_v: 12.2 + rem(tick, 20) / 10
      }
      |> Parser.normalize()

    State.put(values)

    Process.send_after(self(), :poll, @interval_ms)
    {:noreply, %{state | tick: tick + 1}}
  end
end
