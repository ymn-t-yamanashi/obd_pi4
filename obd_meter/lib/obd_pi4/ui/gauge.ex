defmodule ObdPi4.Ui.Gauge do
  @moduledoc false

  alias Scenic.Graph
  import Scenic.Primitives

  @default_bg {17, 26, 45}
  @default_ring {109, 224, 255}
  @default_tick {159, 199, 255}
  @default_needle {248, 95, 95}
  @default_value {255, 220, 120}

  @spec put(Graph.t(), keyword()) :: Graph.t()
  def put(graph, opts) do
    center = Keyword.get(opts, :center, {640, 360})
    radius = Keyword.get(opts, :radius, 220)
    value = Keyword.get(opts, :value, 0.0) |> clamp(0.0, 1.0)
    min_value = Keyword.get(opts, :min, 0)
    max_value = Keyword.get(opts, :max, 100)
    unit = Keyword.get(opts, :unit, "")
    formatter = Keyword.get(opts, :formatter, &default_formatter/1)

    start_deg = Keyword.get(opts, :start_deg, 150)
    end_deg = Keyword.get(opts, :end_deg, 30)
    needle_len = Keyword.get(opts, :needle_len, radius - 40)
    ring_color = Keyword.get(opts, :ring_color, @default_ring)
    bg_color = Keyword.get(opts, :bg_color, @default_bg)
    tick_color = Keyword.get(opts, :tick_color, @default_tick)
    needle_color = Keyword.get(opts, :needle_color, @default_needle)
    value_color = Keyword.get(opts, :value_color, @default_value)

    current = scale_value(value, min_value, max_value)
    display_value = formatter.(current)
    angle = gauge_angle(value, start_deg, end_deg)
    {cx, cy} = center
    {nx, ny} = polar(center, needle_len, angle)

    graph
    |> circle(radius + 20, translate: center, stroke: {4, ring_color})
    |> circle(radius, translate: center, fill: bg_color)
    |> draw_ticks(center, radius, start_deg, end_deg, tick_color)
    |> line({{cx, cy}, {nx, ny}}, stroke: {8, needle_color})
    |> circle(12, translate: center, fill: :white)
    |> text(unit, translate: {cx, cy + trunc(radius * 0.32)}, text_align: :center, font_size: 34, fill: :white)
    |> text(display_value,
      translate: {cx, cy + trunc(radius * 0.57)},
      text_align: :center,
      font_size: 64,
      fill: value_color
    )
  end

  defp draw_ticks(graph, center, radius, start_deg, end_deg, color) do
    Enum.reduce(0..10, graph, fn i, acc ->
      deg = gauge_angle(i / 10, start_deg, end_deg)
      p1 = polar(center, radius - 10, deg)
      p2 = polar(center, radius - 35, deg)
      line(acc, {p1, p2}, stroke: {4, color})
    end)
  end

  defp scale_value(value, min_value, max_value) do
    min_value + value * (max_value - min_value)
  end

  defp default_formatter(number) when is_float(number) do
    number
    |> trunc()
    |> Integer.to_string()
  end

  defp default_formatter(number), do: to_string(number)

  defp polar({cx, cy}, r, deg) do
    rad = :math.pi() * deg / 180
    {cx + r * :math.cos(rad), cy + r * :math.sin(rad)}
  end

  defp gauge_angle(value, start_deg, end_deg) do
    span = rem(end_deg - start_deg + 360, 360)
    normalize_deg(start_deg + value * span)
  end

  defp normalize_deg(deg) when deg > 180, do: deg - 360
  defp normalize_deg(deg), do: deg

  defp clamp(v, min, _max) when v < min, do: min
  defp clamp(v, _min, max) when v > max, do: max
  defp clamp(v, _min, _max), do: v
end
