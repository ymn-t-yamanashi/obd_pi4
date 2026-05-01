defmodule ObdPi4.Ui.Scene.Dashboard do
  @moduledoc false

  use Scenic.Scene

  alias Scenic.Graph
  alias ObdPi4.Ui.Gauge
  import Scenic.Primitives

  @tick_ms 50
  @gauge_radius 95

  @impl true
  def init(scene, _param, _opts) do
    scene =
      scene
      |> assign(
        rpm: 0.0,
        temp: 0.0,
        ign: 0.0,
        map: 0.0,
        volt: 0.0,
        dir: 1,
        connected: false
      )
      |> render()

    Process.send_after(self(), :tick, @tick_ms)
    {:ok, scene}
  end

  @impl true
  def handle_info(:tick, scene) do
    {base, dir} = next_value(scene.assigns.rpm, scene.assigns.dir)

    scene =
      scene
      |> assign(
        rpm: base,
        temp: wave(base, 0.25),
        ign: wave(base, 0.50),
        map: wave(base, 0.75),
        volt: wave(base, 0.12),
        dir: dir,
        connected: true
      )
      |> render()

    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, scene}
  end

  defp render(scene) do
    centers = [
      {220, 200},
      {640, 200},
      {1060, 200},
      {220, 520},
      {640, 520},
      {1060, 520}
    ]

    graph =
      Graph.build()
      |> rect({1280, 720}, fill: {9, 13, 24})
      |> Gauge.put(
        center: Enum.at(centers, 0),
        radius: @gauge_radius,
        value: scene.assigns.rpm,
        min: 0,
        max: 9000,
        title: "ENGINE RPM",
        unit: "rpm",
        formatter: fn v -> Integer.to_string(trunc(v)) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 1),
        radius: @gauge_radius,
        value: scene.assigns.temp,
        min: -20,
        max: 120,
        title: "COOLANT TEMP",
        unit: "C",
        formatter: fn v -> Integer.to_string(trunc(v)) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 2),
        radius: @gauge_radius,
        value: scene.assigns.ign,
        min: -10,
        max: 45,
        title: "IGNITION ADV",
        unit: "°",
        formatter: fn v -> Integer.to_string(trunc(v)) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 3),
        radius: @gauge_radius,
        value: scene.assigns.map,
        min: 20,
        max: 101,
        title: "MANIFOLD ABS",
        unit: "kPa",
        formatter: fn v -> Integer.to_string(trunc(v)) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 4),
        radius: @gauge_radius,
        value: scene.assigns.volt,
        min: 11.0,
        max: 15.0,
        title: "BATTERY VOLT",
        unit: "V",
        formatter: fn v -> :erlang.float_to_binary(v, decimals: 1) end
      )
      |> draw_status_card(Enum.at(centers, 5), scene.assigns.connected)

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

  defp wave(value, phase) do
    wrapped = value + phase
    wrapped - :math.floor(wrapped)
  end

  defp draw_status_card(graph, {cx, cy}, connected) do
    {label, color} =
      if connected, do: {"CONNECTED", {65, 201, 120}}, else: {"DISCONNECTED", {220, 90, 90}}

    graph
    |> text("OBD STATUS", translate: {cx, cy - 30}, text_align: :center, font_size: 28, fill: :white)
    |> text(label, translate: {cx, cy + 20}, text_align: :center, font_size: 34, fill: color)
  end
end
