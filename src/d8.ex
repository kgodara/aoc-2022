defmodule Tree do


  def passover(grid, row_idx, num_rows, above_max, out_grid) when row_idx < num_rows do
    
    left_incr = grid[row_idx] |>
      Enum.reduce(
        {[], -1},
        fn val, {out_row, max_seen} -> { List.insert_at(out_row, 0, (if max_seen < val, do: 1, else: 0) ), max(max_seen, val) }
      end) |>
      elem(0) |>
      Enum.reverse

    top_incr = grid[row_idx] |>
      Enum.reduce(
        {[], 0},
        fn val, {out_row, col_idx} -> { List.insert_at(out_row, 0, (if Enum.at(above_max, col_idx) < val, do: 1, else: 0) ), col_idx + 1 }
      end) |>
      elem(0) |>
      Enum.reverse

    above_max = Enum.zip(above_max, grid[row_idx]) |>
      Enum.map(& max( elem(&1, 0), elem(&1, 1) ))

    res = Enum.map(Enum.zip(left_incr, top_incr), & elem(&1, 0) + elem(&1, 1))

    Tree.passover(grid, row_idx+1, num_rows, above_max, Map.update!(out_grid, row_idx, fn _ -> res end))
  end


  def passover(_, _, _, _, out_grid) do
    out_grid
  end


  def passover(grid) do
    above_max = List.duplicate(-1, length(grid[0]))

    out_grid = Enum.map(grid, fn {k,v} -> {k, List.duplicate(0, length(v))} end) |>
      Map.new

    Tree.passover(grid, 0, Kernel.map_size(out_grid), above_max, out_grid)
  end


  def mirror_grid(grid, row_num) do
    grid |>
    Enum.map(fn {k, v} -> {
      row_num - 1 - k,
      Enum.reverse(v)
    } end) |>
    Map.new
  end

end


# All we have to do is maintain 2 values for each row & col, max_seen, max_seen_backward
# then we can do two traversals over the entire grid

lines = File.read!("../input/d8.txt") |> String.trim_trailing |> String.split("\n")

row_num = length(lines)

empty_grid = Enum.map(0..(row_num-1), &{&1, []}) |>
  Map.new


grid = lines |>
  Enum.reduce({empty_grid, 0}, fn <<line::binary>>, {grid, row} -> {
    Map.put(grid, row, line |> :binary.bin_to_list |> Enum.map(& &1-48)),
    row+1
  } end) |>
  elem(0)

mirror_grid = Tree.mirror_grid(grid, row_num)


out_grid = Tree.passover(grid)
out_rev_grid = Tree.passover(mirror_grid) |> Tree.mirror_grid(row_num)

final_grid = Enum.zip(out_grid, out_rev_grid) |>
  Enum.map(fn {{k, v1}, {_, v2}} -> {k, Enum.zip(v1, v2) |> Enum.map(& elem(&1, 0) + elem(&1, 1))} end) |>
  Map.new

# drop top row
#final_grid = Map.delete(final_grid, 0)
# drop bottom row
#final_grid = Map.delete(final_grid, row_num-1)
# drop first col
#final_grid = Enum.map(final_grid, fn {k, v} -> {k, Enum.drop(v, 1)} end) |> Map.new
# drop last col
#final_grid = Enum.map(final_grid, fn {k, v} -> {k, List.pop_at(v, length(v)-1) |> elem(1)} end) |> Map.new

res = final_grid |>
  Enum.reduce(0, fn {_, v},outer_sum -> outer_sum + Enum.reduce(v, 0, fn b, inner_sum -> inner_sum + min(b,1) end) end)

IO.puts("Part 1: #{res}")


