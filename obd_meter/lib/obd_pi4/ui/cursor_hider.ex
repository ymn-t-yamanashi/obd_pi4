defmodule ObdPi4.Ui.CursorHider do
  @moduledoc false

  use GenServer

  @hide_seq IO.iodata_to_binary([27, "[?25l"])
  @targets ["/dev/tty0", "/dev/tty1"]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    send(self(), :hide_cursor)
    {:ok, state}
  end

  @impl true
  def handle_info(:hide_cursor, state) do
    Enum.each(@targets, &hide_cursor/1)
    Process.send_after(self(), :hide_cursor, 1_000)
    {:noreply, state}
  end

  defp hide_cursor(path) do
    case File.open(path, [:write]) do
      {:ok, io} ->
        IO.binwrite(io, @hide_seq)
        File.close(io)

      _ ->
        :ok
    end
  end
end
