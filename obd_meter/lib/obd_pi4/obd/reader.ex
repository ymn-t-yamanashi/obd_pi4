defmodule ObdPi4.Obd.Reader do
  use GenServer

  alias Circuits.UART
  alias ObdPi4.Obd.Parser
  alias ObdPi4.Obd.State

  @interval_ms 16
  @uart_speed 115_200
  @open_retry_ms 1_000
  @pid_map %{
    "010C" => :rpm,
    "0105" => :coolant_temp_c,
    "010E" => :ignition_advance_deg,
    "010B" => :map_kpa,
    "0142" => :battery_v
  }
  @fast_pid_order ["010E", "010B"]
  @slow_pid_order ["0105", "0142"]
  @slow_every 5
  @init_cmds ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_arg) do
    {:ok, uart} = UART.start_link()
    state = %{
      uart: uart,
      device: System.get_env("OBD_DEVICE", "/dev/ttyUSB0"),
      ready: false,
      fast_index: 0,
      slow_index: 0,
      tick: 0
    }

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
          {:noreply, %{state | ready: true, fast_index: 0, slow_index: 0, tick: 0}}
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
  def handle_info(:poll, %{ready: true, fast_index: f_idx, slow_index: s_idx, tick: tick} = state) do
    fast_len = length(@fast_pid_order)
    fast_pid = Enum.at(@fast_pid_order, f_idx)
    next_fast_idx = rem(f_idx + 1, fast_len)

    case query_pid(state.uart, "010C") do
      {:ok, rpm} ->
        values = %{rpm: rpm}

        values =
          case query_pid(state.uart, fast_pid) do
            {:ok, val} ->
              Map.put(values, Map.fetch!(@pid_map, fast_pid), val)

            _ ->
              values
          end

        values =
          if rem(tick, @slow_every) == 0 do
            slow_pid = Enum.at(@slow_pid_order, s_idx)

            case query_pid(state.uart, slow_pid) do
              {:ok, val} -> Map.put(values, Map.fetch!(@pid_map, slow_pid), val)
              _ -> values
            end
          else
            values
          end

        values |> Parser.normalize() |> State.put()
        Process.send_after(self(), :poll, @interval_ms)
        next_slow_idx = if rem(tick, @slow_every) == 0, do: rem(s_idx + 1, length(@slow_pid_order)), else: s_idx
        {:noreply, %{state | fast_index: next_fast_idx, slow_index: next_slow_idx, tick: tick + 1}}

      _ ->
        UART.close(state.uart)
        State.set_status(:disconnected)
        Process.send_after(self(), :connect, @open_retry_ms)
        {:noreply, %{state | ready: false}}
    end
  end

  def handle_info(:poll, state) do
    Process.send_after(self(), :connect, @open_retry_ms)
    {:noreply, state}
  end

  defp init_adapter(uart) do
    Enum.all?(@init_cmds, fn cmd ->
      case command(uart, cmd, 800) do
        {:ok, _} -> true
        _ -> false
      end
    end)
  end

  defp query_pid(uart, pid) do
    with {:ok, response} <- command(uart, pid, 120),
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
