defmodule Cleanup do
  def p1(line, accum) do
    # get all 4 bounds values
    [left_one, right_one, left_two, right_two] = String.split(line,",") |>
      Enum.map(&String.split(&1, "-")) |>
      Enum.flat_map(fn [x, y] -> [String.to_integer(x), String.to_integer(y)] end)

    enclosing_found? = cond do
      left_one <= left_two and right_one >= right_two -> 1
      left_two <= left_one and right_two >= right_one -> 1
      true -> 0
    end

    accum + enclosing_found?
  end

  def p2(line, accum) do
    # get all 4 bounds values
    [left_one, right_one, left_two, right_two] = String.split(line,",") |>
      Enum.map(&String.split(&1, "-")) |>
      Enum.flat_map(fn [x, y] -> [String.to_integer(x), String.to_integer(y)] end)

    enclosing_found? = cond do
      # 'two' intersects with 'one', necessary for ANY intersection
      left_two <= right_one and right_two >= left_one -> 1
      true -> 0
    end

    accum + enclosing_found?
  end

end


lines = File.read!("../input/d4.txt")
lines = String.split(lines, "\n")

res_one = Enum.reduce(lines, 0, &Cleanup.p1/2)
res_two = Enum.reduce(lines, 0, &Cleanup.p2/2)

IO.puts("Part 1: #{res_one}")
IO.puts("Part 2: #{res_two}")
