# Likely can be improved greatly

import Bitwise

defmodule Tree do
  def visible_left_top(_, row_idx, num_rows, _, out_grid) when row_idx >= num_rows do
    out_grid
  end

  def visible_left_top(grid, row_idx, num_rows, above_max, out_grid) do
    left_incr =
      grid[row_idx]
      |> Enum.reduce(
        {[], -1},
        fn val, {out_row, max_seen} ->
          {List.insert_at(out_row, 0, if(max_seen < val, do: 1, else: 0)), max(max_seen, val)}
        end
      )
      |> elem(0)
      |> Enum.reverse()

    top_incr =
      grid[row_idx]
      |> Enum.reduce(
        {[], 0},
        fn val, {out_row, col_idx} ->
          {List.insert_at(out_row, 0, if(Enum.at(above_max, col_idx) < val, do: 1, else: 0)),
           col_idx + 1}
        end
      )
      |> elem(0)
      |> Enum.reverse()

    above_max =
      Enum.zip(above_max, grid[row_idx])
      |> Enum.map(&max(elem(&1, 0), elem(&1, 1)))

    res = Enum.map(Enum.zip(left_incr, top_incr), &(elem(&1, 0) ||| elem(&1, 1)))

    Tree.visible_left_top(grid, row_idx + 1, num_rows, above_max, Map.put(out_grid, row_idx, res))
  end

  def visible_left_top(grid) do
    above_max = List.duplicate(-1, length(grid[0]))

    out_grid =
      Enum.map(grid, fn {k, v} -> {k, List.duplicate(0, length(v))} end)
      |> Map.new()

    Tree.visible_left_top(grid, 0, map_size(out_grid), above_max, out_grid)
  end

  # flip horizontally and vertically
  def mirror_grid(grid, row_num) do
    grid
    |> Enum.map(fn {k, v} ->
      {
        row_num - 1 - k,
        Enum.reverse(v)
      }
    end)
    |> Map.new()
  end

  def max_scenic_score(_, {row_idx, _}, num_rows, max_score) when row_idx >= num_rows do
    max_score
  end

  def max_scenic_score(grid, {row_idx, col_idx}, num_rows, max_score) do
    cmp_val = Enum.at(grid[row_idx], col_idx)
    col_num = length(grid[0])

    # find 1-based index, if no index found return default
    # (list, default)
    find_1_based_index = fn data, default ->
      data
      |> Enum.with_index(&{&1, &2 + 1})
      |> Enum.find({nil, default}, &(elem(&1, 0) >= cmp_val))
      |> elem(1)
    end

    [num_on_left, num_on_right, num_above, num_below] = [
      col_idx,
      col_num - (col_idx + 1),
      row_idx,
      num_rows - (row_idx + 1)
    ]

    # define anon funcs to get trees in path to each of four edges
    # using grid as arg so that can use
    # capture operator instead of "fn _ -> .. end"

    on_left = &(&1[row_idx] |> Enum.slice(0..(col_idx - 1)) |> Enum.reverse())
    on_right = &(&1[row_idx] |> Enum.slice((col_idx + 1)..(col_num - 1)))

    above =
      &(Enum.reduce((row_idx - 1)..0//-1, [], fn i, acc ->
          List.insert_at(acc, 0, Enum.at(&1[i], col_idx))
        end)
        |> Enum.reverse())

    below =
      &(Enum.reduce((row_idx + 1)..(num_rows - 1), [], fn i, acc ->
          List.insert_at(acc, 0, Enum.at(&1[i], col_idx))
        end)
        |> Enum.reverse())

    check_with_bounds = fn cond, {to_edge, num_to_edge} ->
      if cond == true, do: 0, else: find_1_based_index.(to_edge.(grid), num_to_edge)
    end

    {l, r, u, d} = {
      check_with_bounds.(col_idx == 0, {on_left, num_on_left}),
      check_with_bounds.(col_idx == col_num - 1, {on_right, num_on_right}),
      check_with_bounds.(row_idx == 0, {above, num_above}),
      check_with_bounds.(row_idx == num_rows - 1, {below, num_below})
    }

    row_idx = row_idx + div(col_idx + 1, col_num)
    col_idx = rem(col_idx + 1, col_num)

    Tree.max_scenic_score(
      grid,
      {row_idx, col_idx},
      num_rows,
      max(max_score, l * r * u * d)
    )
  end
end

defmodule D8 do
  def sol(input) do
    # All we have to do is maintain 2 values for each row & col, max_seen, max_seen_backward
    # then we can do two traversals over the entire grid

    lines = input |> String.split("\n")

    row_num = length(lines)

    empty_grid =
      Enum.map(0..(row_num - 1), &{&1, []})
      |> Map.new()

    # parse lines of [0-9] integers to map of lists
    grid =
      lines
      |> Enum.reduce({empty_grid, 0}, fn <<line::binary>>, {grid, row} ->
        {
          Map.put(grid, row, line |> :binary.bin_to_list() |> Enum.map(&(&1 - 48))),
          row + 1
        }
      end)
      |> elem(0)

    left_up_grid = Tree.visible_left_top(grid)

    # mirror grid passover will give right + up results,
    # mirror again to map to original locations
    right_down_grid =
      grid |> Tree.mirror_grid(row_num) |> Tree.visible_left_top() |> Tree.mirror_grid(row_num)

    # get number of visible trees, checking mirrored and unmirrored grids (|||)
    res =
      Enum.zip(left_up_grid, right_down_grid)
      |> Enum.reduce(
        0,
        fn {{_, v1}, {_, v2}}, acc ->
          acc + (Enum.zip(v1, v2) |> Enum.reduce(0, fn {x1, x2}, acc2 -> acc2 + (x1 ||| x2) end))
        end
      )

    res2 = Tree.max_scenic_score(grid, {0, 0}, row_num, -1)

    IO.puts("Part 1: #{res}")
    IO.puts("Part 2: #{res2}")
  end
end
