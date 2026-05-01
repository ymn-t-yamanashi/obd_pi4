defmodule ObdPi4.Ui.Scene.Dashboard do
  @moduledoc false

  use Scenic.Scene

  alias Scenic.Graph
  import Scenic.Primitives

  @tick_ms 50
  @center {640, 360}
  @radius 220
  @needle_len 180
  # 0rpmを左下、最大側を右下に寄せる一般的な車載メーター風の角度
  @start_deg 150
  @end_deg 30

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
    {cx, cy} = @center
    angle = gauge_angle(scene.assigns.value)
    {nx, ny} = polar(@center, @needle_len, angle)

    graph =
      Graph.build()
      |> rect({1280, 720}, fill: {9, 13, 24})
      |> circle(@radius + 20, translate: @center, stroke: {4, {109, 224, 255}})
      |> circle(@radius, translate: @center, fill: {17, 26, 45})
      |> draw_ticks()
      |> line({{cx, cy}, {nx, ny}}, stroke: {8, {248, 95, 95}})
      |> circle(12, translate: @center, fill: :white)

    push_graph(scene, graph)
  end

  defp draw_ticks(graph) do
    Enum.reduce(0..10, graph, fn i, acc ->
      deg = gauge_angle(i / 10)
      p1 = polar(@center, @radius - 10, deg)
      p2 = polar(@center, @radius - 35, deg)
      line(acc, {p1, p2}, stroke: {4, {159, 199, 255}})
    end)
  end

  defp polar({cx, cy}, r, deg) do
    rad = :math.pi() * deg / 180
    {cx + r * :math.cos(rad), cy + r * :math.sin(rad)}
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

  defp gauge_angle(value) do
    span = rem(@end_deg - @start_deg + 360, 360)
    normalize_deg(@start_deg + value * span)
  end

  defp normalize_deg(deg) when deg > 180, do: deg - 360
  defp normalize_deg(deg), do: deg
end
