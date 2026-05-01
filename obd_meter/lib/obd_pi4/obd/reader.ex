defmodule ObdPi4.Obd.Reader do
  use GenServer

  alias Circuits.UART
  alias ObdPi4.Obd.Parser
  alias ObdPi4.Obd.State

  @interval_ms 200
  @uart_speed 115_200
  @open_retry_ms 1_000
  @pid_map %{
    "010C" => :rpm,
    "0105" => :coolant_temp_c,
    "010E" => :ignition_advance_deg,
    "010B" => :map_kpa,
    "0142" => :battery_v
  }
  @init_cmds ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_arg) do
    {:ok, uart} = UART.start_link()
    state = %{uart: uart, device: System.get_env("OBD_DEVICE", "/dev/ttyUSB0"), ready: false}
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case UART.open(state.uart, state.device, speed: @uart_speed, active: false) do
      :ok ->
        if init_adapter(state.uart) do
          State.set_status(:connected)
          Process.send_after(self(), :poll, @interval_ms)
          {:noreply, %{state | ready: true}}
        else
          UART.close(state.uart)
          State.set_status(:disconnected)
          Process.send_after(self(), :connect, @open_retry_ms)
          {:noreply, %{state | ready: false}}
        end

      _ ->
        State.set_status(:disconnected)
        Process.send_after(self(), :connect, @open_retry_ms)
        {:noreply, %{state | ready: false}}
    end
  end

  @impl true
  def handle_info(:poll, %{ready: true} = state) do
    values =
      @pid_map
      |> Enum.reduce(%{}, fn {pid, key}, acc ->
        case query_pid(state.uart, pid) do
          {:ok, val} -> Map.put(acc, key, val)
          _ -> acc
        end
      end)

    case map_size(values) do
      0 ->
        UART.close(state.uart)
        State.set_status(:disconnected)
        Process.send_after(self(), :connect, @open_retry_ms)
        {:noreply, %{state | ready: false}}

      _ ->
        values |> Parser.normalize() |> State.put()
        Process.send_after(self(), :poll, @interval_ms)
        {:noreply, state}
    end
  end

  def handle_info(:poll, state) do
    Process.send_after(self(), :connect, @open_retry_ms)
    {:noreply, state}
  end

  defp init_adapter(uart) do
    Enum.all?(@init_cmds, fn cmd ->
      case command(uart, cmd, 2_000) do
        {:ok, _} -> true
        _ -> false
      end
    end)
  end

  defp query_pid(uart, pid) do
    with {:ok, response} <- command(uart, pid, 1_000),
         {:ok, value} <- Parser.parse_pid(pid, response) do
      {:ok, value}
    end
  end

  defp command(uart, cmd, timeout_ms) do
    :ok = UART.write(uart, cmd <> "\r")
    read_until_prompt(uart, timeout_ms, "")
  end

  defp read_until_prompt(uart, timeout_ms, acc) do
    case UART.read(uart, timeout_ms) do
      {:ok, chunk} ->
        next = acc <> chunk
        if String.contains?(next, ">"), do: {:ok, next}, else: read_until_prompt(uart, timeout_ms, next)

      {:error, _} = err ->
        err
    end
  end
end
