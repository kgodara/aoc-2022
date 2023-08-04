defmodule Rucksack do
  def p1(line, accum) do

    # Transform characters:
    # A-Z --> [65,90] --> [27,52]
    # a-z --> [97,122] --> [1,26]
    ch_list = String.to_charlist(line) |>
      Enum.map(fn ch -> 
          if ch >= 97 do
            ch - 96
          else
            ch - 38
          end
        end)

    # Get left and right halves as sets
    [left, right] = 
      length(ch_list) |>
      div(2) |>
      (&Enum.split(ch_list, &1)).() |>
      Tuple.to_list |>
      Enum.map(&MapSet.new/1)

    # return common element across halves + accumulated score
    MapSet.intersection(left, right) |>
      MapSet.to_list |>
      Enum.at(0) |>
      Kernel.+(accum)
  end


  def p2(line_triplet, accum) do

    # Transform characters for line_triplet - [[..], [..], [..]]:
    # A-Z --> [65,90] --> [27,52]
    # a-z --> [97,122] --> [1,26]
    ch_list = Enum.map(line_triplet, &String.to_charlist/1) |>
      Enum.map(
        &Enum.map(&1, fn ch -> 
          if ch >= 97 do
            ch - 96
          else
            ch - 38
          end
        end)
      )

    # get common element among list triplet [[..], [..], [..]]
    # + accumulated score
    Enum.map(ch_list, &MapSet.new/1) |>
      Enum.reduce(fn set, intersect -> MapSet.intersection(set, intersect) end) |>
      MapSet.to_list |>
      Enum.at(0) |>
      Kernel.+(accum)

  end
end


lines = File.read!("../input/d3.txt")
lines = String.split(lines, "\n")

res_one = Enum.reduce(lines, 0, &Rucksack.p1/2)

res_two = Enum.chunk_every(lines, 3) |>
  Enum.reduce(0, &Rucksack.p2/2)

IO.puts("Part 1: #{res_one}")
IO.puts("Part 2: #{res_two}")
