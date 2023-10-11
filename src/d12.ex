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


    row_num = length(lines)

    empty_grid = Enum.map(0..(row_num-1), &{&1, []}) |>
      Map.new

    grid = lines |>
      Enum.reduce({empty_grid, 0}, fn <<line::binary>>, {grid, row} -> {
        Map.put(grid, row, line |> :binary.bin_to_list),
        row+1
      } end) |>
      elem(0)

    # get coordinates of start & end
    # start = 'S'
    # end = 'E'
    {start_coord, end_coord} = Enum.reduce(grid, {%Coord{}, %Coord{}}, fn {row_idx, row}, {start_c, end_c} ->
      # check for start --> 'S' = 83
      start_idx = Enum.find_index(row, fn val -> val == @ascii_char_start end)

      # check for end --> 'E' = 69
      end_idx = Enum.find_index(row, fn val -> val == @ascii_char_end end)

      {
        (if start_idx != nil, do: %Coord{row: row_idx, col: start_idx}, else: start_c),
        (if end_idx != nil, do: %Coord{row: row_idx, col: end_idx}, else: end_c),
      }
    end)

    # set value of start cell to 'a' (97)
    # set value of end cell to 'z' (122)

    grid = grid |>
      Map.update!(start_coord.row, fn row -> row |> List.replace_at(start_coord.col, @ascii_char_a) end) |>
      Map.update!(end_coord.row, fn row -> row |> List.replace_at(end_coord.col, @ascii_char_z) end)

    # remap to heights, (0-25)
    grid = grid |>
      Enum.map(fn {row_idx, row} -> {row_idx, row |> Enum.map(fn val -> val - 97 end)} end) |>
      Map.new

    {start_coord, end_coord, grid}
  end

  def find_possible_starts(grid) do
    grid |>
    Enum.reduce([], fn {row_idx, row}, acc ->
      valid_indexes = row |>
        Enum.with_index |>
        Enum.filter(fn {elem, _idx} -> elem == 0 end) |>
        Enum.map(fn {_elem, col_idx} -> %Coord{row: row_idx, col: col_idx} end)

      acc ++ valid_indexes
    end)
  end

  def traverse_grid([{pos, steps_taken} | _rest], _grid, _seen_coords, end_pos) when pos == end_pos do
    steps_taken
  end

  def traverse_grid([], _, _, _) do
    nil
  end

  def traverse_grid([{pos, steps_taken} | pos_q], grid, seen_coords, end_pos) do
    # During each step, you can move exactly one square up, down, left, or right.
    # To avoid needing to get out your climbing gear, the elevation of the
    # destination square can be at most one higher than the elevation of your
    # current square; that is, if your current elevation is m, you could step
    # to elevation n, but not to elevation o.

    num_rows = map_size(grid)

    # Assumption: same number of cols for every row
    num_cols = grid |> Map.get(0) |> length()

    candidates = [
      %Coord{row: pos.row-1, col: pos.col},
      %Coord{row: pos.row+1, col: pos.col},
      %Coord{row: pos.row, col: pos.col-1},
      %Coord{row: pos.row, col: pos.col+1}
    ]

    pos_height = grid |> Map.get(pos.row) |> Enum.at(pos.col)

    # exclude non-existent coords, or coords already processed / set to be processed
    new_pos_list = candidates |>
      Enum.filter(fn c_pos ->
        if (c_pos.row < 0 or
            c_pos.col < 0 or
            c_pos.row >= num_rows or
            c_pos.col >= num_cols or
            c_pos in seen_coords
            )
        do
          false
        else
          true
        end
      end)

    # remove positions which are more than 1 higher
    valid_pos_list = new_pos_list |>
      Enum.filter(fn c_pos ->
        dst_height = grid |> Map.get(c_pos.row) |> Enum.at(c_pos.col)
        dst_height <= (pos_height + 1)
      end)

    # instead of appending to end of position list in each iteration,
    # collect items to add, then add in one concat op

    pos_q_to_add = valid_pos_list |> Enum.map(& {&1, steps_taken + 1})

    new_seen_coords = valid_pos_list |>
      Enum.reduce(seen_coords, fn cur_pos, seen -> seen |> MapSet.put(cur_pos) end)


    HillClimb.traverse_grid(pos_q ++ pos_q_to_add, grid, new_seen_coords, end_pos)
  end
end




lines = File.read!("../input/d12.txt") |>
  String.trim_trailing |>
  String.split("\n")

{start_c, end_c, grid} = HillClimb.parse_grid(lines)

possible_starts = HillClimb.find_possible_starts(grid)

steps_taken = HillClimb.traverse_grid([{start_c, 0}], grid, MapSet.new([start_c]), end_c)

all_min_routes = possible_starts |>
  Enum.map(& HillClimb.traverse_grid([{&1, 0}], grid, MapSet.new([&1]), end_c)) |>
  Enum.filter(& &1 != nil)

min_route = Enum.min(all_min_routes)

IO.puts("Part 1: #{steps_taken}")
IO.puts("Part 2: #{min_route}")




