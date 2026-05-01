defmodule ObdPi4.Ui.Bootstrapper do
  @moduledoc false

  use GenServer

  @retry_ms 500

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(state) do
    send(self(), :ensure_viewport)
    {:ok, state}
  end

  @impl true
  def handle_info(:ensure_viewport, state) do
    if :erlang.whereis(:main_viewport) == :undefined do
      viewport_config = Application.fetch_env!(:obd_pi4, :viewport)

      started =
        try do
          case Scenic.ViewPort.start(viewport_config) do
            {:ok, _vp} -> true
            _ -> false
          end
        rescue
          _ -> false
        catch
          _, _ -> false
        end

      unless started do
        Process.send_after(self(), :ensure_viewport, @retry_ms)
      end
    end

    {:noreply, state}
  end
end
