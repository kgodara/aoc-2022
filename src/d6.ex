defmodule PacketParser do


  def validate_next(window, packet_size, buffer, pos_idx) when length(window) == packet_size and length(buffer) > 0 do
 
    is_start_packet? = window |> Enum.uniq |> length |> Kernel.==(packet_size)

    if is_start_packet? != true do
      {next, new_buffer} = List.pop_at(buffer, 0)

      window |>
      Enum.drop(1) |>
      Kernel.++([next]) |>
      PacketParser.validate_next(packet_size, new_buffer, pos_idx+1)
    else
      pos_idx
    end
  end

end

buffer = File.read!("../input/d6.txt") |> String.to_charlist

args = [4, 14] |>
  Enum.map(&{Enum.take(buffer, &1), &1, Enum.drop(buffer, &1), &1})

[start_packet_idx_p1, start_packet_idx_p2] = Enum.map(args, &PacketParser.validate_next(elem(&1,0), elem(&1,1), elem(&1,2), elem(&1,3)))

IO.puts("Part 1: #{start_packet_idx_p1}")
IO.puts("Part 2: #{start_packet_idx_p2}")