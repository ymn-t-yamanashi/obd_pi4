defmodule ObdPi4.Ui.Scene.Dashboard do
  @moduledoc false

  use Scenic.Scene

  alias Scenic.Graph
  alias ObdPi4.Ui.Gauge
  import Scenic.Primitives

  @tick_ms 50
  @center {640, 360}
  @radius 220

  @impl true
  def init(scene, _param, _opts) do
    scene =
      scene
      |> assign(value: 0.0, dir: 1)
      |> render()

    Process.send_after(self(), :tick, @tick_ms)
    {:ok, scene}
  end

  @impl true
  def handle_info(:tick, scene) do
    {value, dir} = next_value(scene.assigns.value, scene.assigns.dir)

    scene =
      scene
      |> assign(value: value, dir: dir)
      |> render()

    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, scene}
  end

  defp render(scene) do
    graph =
      Graph.build()
      |> rect({1280, 720}, fill: {9, 13, 24})
      |> Gauge.put(
        center: @center,
        radius: @radius,
        value: scene.assigns.value,
        min: 0,
        max: 9000,
        unit: "RPM",
        formatter: fn v -> Integer.to_string(trunc(v)) end
      )

    push_graph(scene, graph)
  end

  defp next_value(value, dir) do
    step = 0.02
    next = value + step * dir

    cond do
      next >= 1.0 -> {1.0, -1}
      next <= 0.0 -> {0.0, 1}
      true -> {next, dir}
    end
  end

end
