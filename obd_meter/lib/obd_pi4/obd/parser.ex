defmodule ObdPi4.Obd.Parser do
  @moduledoc false

  @rpm_range 0..9000
  @coolant_range -20..120
  @ignition_range -10..45
  @map_range 20..101
  @battery_range {11.0, 15.0}

  def normalize(values) when is_map(values) do
    values
    |> Enum.reduce(%{}, fn
      {:rpm, v}, acc -> Map.put(acc, :rpm, clamp_int(v, @rpm_range))
      {:coolant_temp_c, v}, acc -> Map.put(acc, :coolant_temp_c, clamp_int(v, @coolant_range))
      {:ignition_advance_deg, v}, acc -> Map.put(acc, :ignition_advance_deg, clamp_int(v, @ignition_range))
      {:map_kpa, v}, acc -> Map.put(acc, :map_kpa, clamp_int(v, @map_range))
      {:battery_v, v}, acc -> Map.put(acc, :battery_v, clamp_float(v, @battery_range))
      _, acc -> acc
    end)
  end

  def parse_pid(pid, response) when is_binary(pid) and is_binary(response) do
    with {:ok, bytes} <- extract_bytes(response),
         {:ok, value} <- decode(pid, bytes) do
      {:ok, value}
    end
  end

  defp decode("010C", [0x41, 0x0C, a, b | _]), do: {:ok, trunc((a * 256 + b) / 4)}
  defp decode("0105", [0x41, 0x05, a | _]), do: {:ok, a - 40}
  defp decode("010E", [0x41, 0x0E, a | _]), do: {:ok, trunc(a / 2 - 64)}
  defp decode("010B", [0x41, 0x0B, a | _]), do: {:ok, a}
  defp decode("0142", [0x41, 0x42, a, b | _]), do: {:ok, Float.round((a * 256 + b) / 1000, 2)}
  defp decode(_, _), do: {:error, :unexpected_payload}

  defp extract_bytes(response) do
    clean =
      response
      |> String.upcase()
      |> String.replace(~r/SEARCHING\.\.\./, "")
      |> String.replace(~r/[^0-9A-F]/, "")

    if rem(byte_size(clean), 2) != 0 or clean == "" do
      {:error, :invalid_hex}
    else
      bytes =
        clean
        |> String.codepoints()
        |> Enum.chunk_every(2)
        |> Enum.map(fn [a, b] -> String.to_integer(a <> b, 16) end)

      {:ok, bytes}
    end
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
