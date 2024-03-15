defmodule Coord do
  defstruct [:row, :col]
end

defmodule HillClimb do
  @ascii_char_a 97
  @ascii_char_z 122
  @ascii_char_start 83
  @ascii_char_end 69

  def parse_grid([], grid, _) do
    grid
  end

  def parse_grid(lines) do
    num_rows = length(lines)
    num_cols = Enum.at(lines, 0) |> String.length()

    grid =
      lines
      |> Enum.with_index()
      |> Enum.reduce(Map.new(), fn {<<line::binary>>, row_idx}, grid ->
        line
        |> :binary.bin_to_list()
        |> Enum.with_index(fn elem, col_idx -> {{row_idx, col_idx}, elem} end)
        |> Map.new()
        |> Map.merge(grid)
      end)

    # get coordinates of start & end
    # start = 'S'
    # end = 'E'
    {start_coord, end_coord} =
      Enum.reduce(grid, {%Coord{}, %Coord{}}, fn {{row_idx, col_idx}, val}, {start_c, end_c} ->
        {
          if(val == @ascii_char_start, do: %Coord{row: row_idx, col: col_idx}, else: start_c),
          if(val == @ascii_char_end, do: %Coord{row: row_idx, col: col_idx}, else: end_c)
        }
      end)

    # set value of start cell to 'a' (97)
    # set value of end cell to 'z' (122)

    grid =
      grid
      |> Map.update!({start_coord.row, start_coord.col}, fn _val -> @ascii_char_a end)
      |> Map.update!({end_coord.row, end_coord.col}, fn _val -> @ascii_char_z end)

    # remap to heights, (0-25)
    grid =
      grid
      |> Enum.map(fn {{row_idx, col_idx}, val} -> {{row_idx, col_idx}, val - 97} end)
      |> Map.new()

    {start_coord, end_coord, grid, {num_rows, num_cols}}
  end

  def find_possible_starts(grid) do
    grid
    |> Enum.reduce([], fn {{row_idx, col_idx}, val}, acc ->
      if val == 0 do
        [%Coord{row: row_idx, col: col_idx}] ++ acc
      else
        acc
      end
    end)
  end

  # end found
  def traverse_grid(
        [{pos, steps_taken} | _rest],
        _grid,
        {_num_rows, _num_cols},
        _seen_coords,
        end_pos
      )
      when pos == end_pos do
    steps_taken
  end

  # no path possible from starting point
  def traverse_grid([], _, _, _, _) do
    nil
  end

  # BFS search for paths
  def traverse_grid(
        [{src, steps_taken} | dst_q],
        grid,
        {num_rows, num_cols},
        seen_coords,
        end_pos
      ) do
    # During each step, you can move exactly one square up, down, left, or right.
    # ... the elevation of the destination square can be at most one higher than
    # the elevation of your current square; that is, if your current elevation
    # is m, you could step to elevation n, but not to elevation o.

    candidates = [
      %Coord{row: src.row - 1, col: src.col},
      %Coord{row: src.row + 1, col: src.col},
      %Coord{row: src.row, col: src.col - 1},
      %Coord{row: src.row, col: src.col + 1}
    ]

    src_height = grid |> Map.get({src.row, src.col})

    # exclude coords already processed / set to be processed + invalid coords
    # remove positions which are more than 1 higher
    valid_dst_list =
      candidates
      |> Enum.filter(
        &(&1.row >= 0 and &1.row < num_rows and (&1.col >= 0 and &1.col < num_cols) and
            &1 not in seen_coords)
      )
      |> Enum.filter(fn c_pos ->
        dst_height = grid |> Map.get({c_pos.row, c_pos.col})
        dst_height <= src_height + 1
      end)

    # instead of appending to end of position list in each iteration,
    # collect items to add, then add in one concat op

    dst_to_add = valid_dst_list |> Enum.map(&{&1, steps_taken + 1})

    new_seen_coords =
      valid_dst_list
      |> Enum.reduce(seen_coords, fn dst, seen -> seen |> MapSet.put(dst) end)

    HillClimb.traverse_grid(
      dst_q ++ dst_to_add,
      grid,
      {num_rows, num_cols},
      new_seen_coords,
      end_pos
    )
  end
end

defmodule D12 do
  def sol(input) do
    lines =
      input
      |> String.split("\n")

    {start_c, end_c, grid, {num_rows, num_cols}} = HillClimb.parse_grid(lines)
    possible_starts = HillClimb.find_possible_starts(grid)

    min_path_default_start =
      HillClimb.traverse_grid(
        [{start_c, 0}],
        grid,
        {num_rows, num_cols},
        MapSet.new([start_c]),
        end_c
      )

    min_path_all_starts =
      possible_starts
      |> Enum.map(
        &HillClimb.traverse_grid([{&1, 0}], grid, {num_rows, num_cols}, MapSet.new([&1]), end_c)
      )
      |> Enum.filter(&(&1 != nil))
      |> Enum.min()

    IO.puts("Part 1: #{min_path_default_start}")
    IO.puts("Part 2: #{min_path_all_starts}")
  end
end
