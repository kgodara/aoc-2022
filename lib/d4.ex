defmodule Cleanup do
  def parse_bounds(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.split(&1, "-"))
    |> Enum.flat_map(fn [x, y] -> [String.to_integer(x), String.to_integer(y)] end)
  end

  def p1(line, accum) do
    # get all 4 bounds values
    [left_one, right_one, left_two, right_two] = Cleanup.parse_bounds(line)

    enclosing_found? =
      cond do
        left_one <= left_two and right_one >= right_two -> 1
        left_two <= left_one and right_two >= right_one -> 1
        true -> 0
      end

    accum + enclosing_found?
  end

  def p2(line, accum) do
    # get all 4 bounds values
    [left_one, right_one, left_two, right_two] = Cleanup.parse_bounds(line)

    # 'two' intersects with 'one', necessary for ANY intersection
    enclosing_found? = if left_two <= right_one and right_two >= left_one, do: 1, else: 0

    accum + enclosing_found?
  end
end

defmodule D4 do
  def sol(input) do
    lines = input |> String.split("\n")

    res_one = Enum.reduce(lines, 0, &Cleanup.p1/2)
    res_two = Enum.reduce(lines, 0, &Cleanup.p2/2)

    IO.puts("Part 1: #{res_one}")
    IO.puts("Part 2: #{res_two}")
  end
end
