defmodule ObdPi4.Ui.Scene.Dashboard do
  use Scenic.Scene

  import Scenic.Primitives

  alias Scenic.Graph
  alias ObdPi4.Obd.State

  @font_size 40
  @refresh_ms 100

  @impl true
  def init(_scene_arg, _opts, _viewport) do
    Process.send_after(self(), :tick, @refresh_ms)

    {:ok, %{graph: Graph.build() |> draw(State.get())}, push: draw(Graph.build(), State.get())}
  end

  @impl true
  def handle_info(:tick, state) do
    data = State.get()
    graph = draw(Graph.build(), data)

    Process.send_after(self(), :tick, @refresh_ms)
    {:noreply, %{state | graph: graph}, push: graph}
  end

  defp draw(graph, data) do
    status =
      case data[:status] do
        :connected -> "CONNECTED"
        _ -> "DISCONNECTED"
      end

    graph
    |> rect({1240, 680}, translate: {20, 20}, stroke: {2, :white})
    |> text("RPM: #{fmt(data[:rpm])}", translate: {60, 110}, font_size: @font_size, fill: :white)
    |> text("COOLANT: #{fmt(data[:coolant_temp_c])} C",
      translate: {60, 210},
      font_size: @font_size,
      fill: :white
    )
    |> text("IGN ADV: #{fmt(data[:ignition_advance_deg])} deg",
      translate: {60, 310},
      font_size: @font_size,
      fill: :white
    )
    |> text("MAP: #{fmt(data[:map_kpa])} kPa",
      translate: {60, 410},
      font_size: @font_size,
      fill: :white
    )
    |> text("BATTERY: #{fmt(data[:battery_v])} V",
      translate: {60, 510},
      font_size: @font_size,
      fill: :white
    )
    |> text("OBD: #{status}", translate: {60, 610}, font_size: @font_size, fill: :green)
  end

  defp fmt(nil), do: "--"
  defp fmt(value), do: to_string(value)
end
