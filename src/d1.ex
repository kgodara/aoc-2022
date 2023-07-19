defmodule ChunkSum do

  def calc_accum_p1(line, {max_accum, accum}) do
    if String.length(line) == 0 do
      {max(max_accum, accum), 0}
    else
      {max_accum, accum + String.to_integer(line)}
    end
  end


  def calc_accum_p2(line, {max_accum, accum}) do

    # segment has ended
    if String.length(line) == 0 do

      {min_val, min_idx} = Enum.with_index(max_accum) |> Enum.min()

      # Replace min element if accum is greater
      if min_val < accum do
        {List.replace_at(max_accum, min_idx, accum), 0}
      else
        {max_accum, 0}
      end

    else
      {max_accum, accum + String.to_integer(line)}
    end
  end
end


input = File.read!("../input/d1.txt")
lines = String.split(input, "\n")

max_sum = Enum.reduce(lines, {0, 0}, &ChunkSum.calc_accum_p1/2)
max_triplet = Enum.reduce(lines, {[0,0,0], 0}, &ChunkSum.calc_accum_p2/2)

IO.puts("Part 1: #{elem max_sum, 0}")
IO.puts("Part 2: #{Enum.sum(elem(max_triplet, 0))}")