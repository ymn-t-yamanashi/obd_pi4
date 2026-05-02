defmodule ObdPi4.Ui.Scene.Dashboard do
  @moduledoc false

  use Scenic.Scene

  alias ObdPi4.Obd.State
  alias Scenic.Graph
  alias ObdPi4.Ui.Gauge
  import Scenic.Primitives

  @tick_ms 16
  @gauge_radius 235

  @impl true
  def init(scene, _param, _opts) do
    scene =
      scene
      |> assign(
        rpm: nil,
        temp: nil,
        ign: nil,
        map: nil,
        volt: nil,
        connected: false
      )
      |> render()

    Process.send_after(self(), :tick, @tick_ms)
    {:ok, scene}
  end

  @impl true
  def handle_info(:tick, scene) do
    obd = State.get()

    scene =
      scene
      |> assign(
        rpm: obd[:rpm],
        temp: obd[:coolant_temp_c],
        ign: obd[:ignition_advance_deg],
        map: obd[:map_kpa],
        volt: obd[:battery_v],
        connected: obd[:status] == :connected
      )
      |> render()

    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, scene}
  end

  defp render(scene) do
    centers = [
      {320, 270},
      {960, 270},
      {1600, 270},
      {320, 810},
      {960, 810},
      {1600, 810}
    ]

    graph =
      Graph.build()
      |> rect({1920, 1080}, fill: {9, 13, 24})
      |> Gauge.put(
        center: Enum.at(centers, 0),
        radius: @gauge_radius,
        value: normalize(scene.assigns.rpm, 0, 9000),
        min: 0,
        max: 9000,
        title: "ENGINE RPM",
        unit: "rpm",
        formatter: fn _v -> maybe_int(scene.assigns.rpm) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 1),
        radius: @gauge_radius,
        value: normalize(scene.assigns.temp, -20, 120),
        min: -20,
        max: 120,
        title: "COOLANT TEMP",
        unit: "C",
        formatter: fn _v -> maybe_int(scene.assigns.temp) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 2),
        radius: @gauge_radius,
        value: normalize(scene.assigns.ign, -10, 45),
        min: -10,
        max: 45,
        title: "IGNITION ADV",
        unit: "deg",
        formatter: fn _v -> maybe_int(scene.assigns.ign) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 3),
        radius: @gauge_radius,
        value: normalize(scene.assigns.map, 20, 101),
        min: 20,
        max: 101,
        title: "MANIFOLD ABS",
        unit: "kPa",
        formatter: fn _v -> maybe_int(scene.assigns.map) end
      )
      |> Gauge.put(
        center: Enum.at(centers, 4),
        radius: @gauge_radius,
        value: normalize(scene.assigns.volt, 11.0, 15.0),
        min: 11.0,
        max: 15.0,
        title: "BATTERY VOLT",
        unit: "V",
        formatter: fn _v -> maybe_float(scene.assigns.volt, 1) end
      )
      |> draw_status_card(Enum.at(centers, 5), scene.assigns.connected)

    push_graph(scene, graph)
  end

  defp draw_status_card(graph, {cx, cy}, connected) do
    {label, color} =
      if connected, do: {"CONNECTED", {65, 201, 120}}, else: {"DISCONNECTED", {220, 90, 90}}

    graph
    |> text("OBD STATUS", translate: {cx, cy - 30}, text_align: :center, font_size: 28, fill: :white)
    |> text(label, translate: {cx, cy + 20}, text_align: :center, font_size: 34, fill: color)
  end

  defp normalize(nil, _min, _max), do: 0.0

  defp normalize(value, min, max) when is_number(value) and max > min do
    ratio = (value - min) / (max - min)
    ratio |> max(0.0) |> min(1.0)
  end

  defp maybe_int(nil), do: "--"
  defp maybe_int(value) when is_number(value), do: value |> trunc() |> Integer.to_string()

  defp maybe_float(nil, _d), do: "--"
  defp maybe_float(value, d) when is_number(value), do: :erlang.float_to_binary(value * 1.0, decimals: d)
end
