defmodule ObdPi4.Obd.Parser do
  @moduledoc """
  OBDレスポンス解析の入口。
  現時点ではMVP向けに値マップをそのまま受け取り、異常値を最小限クリップする。
  """

  @rpm_range 0..9000
  @coolant_range -20..120
  @ignition_range -10..45
  @map_range 20..101
  @battery_range {11.0, 15.0}

  def normalize(values) when is_map(values) do
    %{
      rpm: clamp_int(values[:rpm], @rpm_range),
      coolant_temp_c: clamp_int(values[:coolant_temp_c], @coolant_range),
      ignition_advance_deg: clamp_int(values[:ignition_advance_deg], @ignition_range),
      map_kpa: clamp_int(values[:map_kpa], @map_range),
      battery_v: clamp_float(values[:battery_v], @battery_range)
    }
  end

  defp clamp_int(nil, _range), do: nil

  defp clamp_int(value, first..last//_step) when is_integer(value),
    do: min(max(value, first), last)

  defp clamp_int(_value, _range), do: nil

  defp clamp_float(nil, _range), do: nil

  defp clamp_float(value, {first, last}) when is_float(value) do
    value |> max(first) |> min(last) |> Float.round(2)
  end

  defp clamp_float(value, range) when is_integer(value) do
    value
    |> Kernel./(1)
    |> clamp_float(range)
  end

  defp clamp_float(_value, _range), do: nil
end
