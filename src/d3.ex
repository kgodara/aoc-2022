defmodule Rucksack do

  # Transform characters:
  # A-Z --> [65,90] --> [27,52]
  # a-z --> [97,122] --> [1,26]
  def charlist_remap(data) do
    data |>
    Enum.map(&
      if &1 >= 97 do
        &1 - 96
      else
        &1 - 38
      end
    )
  end


  def p1(line, accum) do

    ch_list = line |> String.to_charlist |> Rucksack.charlist_remap

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

    ch_list = line_triplet |>
      Enum.map(&String.to_charlist/1) |>
      Enum.map(&Rucksack.charlist_remap(&1))

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
