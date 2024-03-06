


defmodule Cursor do

  defstruct [:row, :col, :orientation, :face]

  def turn(cursor, turn) do
    n_orientation =
      case cursor.orientation do
        :left ->
          case turn do
            "L" -> :down
            "R" -> :top
          end
        :top ->
          case turn do
            "L" -> :left
            "R" -> :right
          end
        :right ->
          case turn do
            "L" -> :top
            "R" -> :down
          end
        :down ->
          case turn do
            "L" -> :right
            "R" -> :left
          end
      end

    %Cursor{ cursor | orientation: n_orientation }
  end
end

defprotocol MMap do
  def at(struct, context)
  def advance(struct, cursor)
end


defmodule MapFlat do
  defstruct [:grid, :bounds]
end

defmodule MapCube do

  # Hardcoded transitions between cube faces
  # for example cube and actual cube
  @ex_face_mappings %{
    {1, :left}  => {3, :top},
    {1, :top}   => {2, :top},
    {1, :right} => {6, :right},
    {1, :down}  => {4, :top},

    {2, :left}  => {6, :down},
    {2, :top}   => {1, :top},
    {2, :right} => {3, :left},
    {2, :down}  => {5, :down},

    {3, :left}  => {2, :right},
    {3, :top}   => {1, :left},
    {3, :right} => {4, :left},
    {3, :down}  => {5, :left},

    {4, :left}  => {3, :right},
    {4, :top}   => {1, :down},
    {4, :right} => {6, :top},
    {4, :down}  => {5, :top},

    {5, :left}  => {3, :down},
    {5, :top}   => {4, :down},
    {5, :right} => {6, :left},
    {5, :down}  => {2, :down},

    {6, :left}  => {5, :right},
    {6, :top}   => {4, :right},
    {6, :right} => {1, :right},
    {6, :down}  => {2, :left},
  }

  @face_mappings %{
    {1, :left}  => {4, :left},
    {1, :top}   => {6, :left},
    {1, :right} => {2, :left},
    {1, :down}  => {3, :top},

    {2, :left}  => {1, :right},
    {2, :top}   => {6, :down},
    {2, :right} => {5, :right},
    {2, :down}  => {3, :right},

    {3, :left}  => {4, :top},
    {3, :top}   => {1, :down},
    {3, :right} => {2, :down},
    {3, :down}  => {5, :top},

    {4, :left}  => {1, :left},
    {4, :top}   => {3, :left},
    {4, :right} => {5, :left},
    {4, :down}  => {6, :top},

    {5, :left}  => {4, :right},
    {5, :top}   => {3, :down},
    {5, :right} => {2, :right},
    {5, :down}  => {6, :right},

    {6, :left}  => {1, :top},
    {6, :top}   => {4, :down},
    {6, :right} => {5, :down},
    {6, :down}  => {2, :top},
  }

  defstruct [:face_lookup, :side_len]

  def next_face_transition(cursor, map) do
    {r, c} = {cursor.row, cursor.col}

    face_mappings = case map.side_len do
      4 -> @ex_face_mappings
      50 -> @face_mappings
      _ -> raise "Unsupported cube side len"
    end

    {n_face, n_side} = Map.get(face_mappings, {cursor.face, cursor.orientation})

    dir_change = {cursor.orientation, n_side}

    max_idx = map.side_len-1

    # NOTE: the 2nd elem of dir_change indicates which SIDE of the cube face we are arriving at
    # Our new direction is the OPPOSITE of this 2nd elem, e.g. if we arrive on the :left of a cube face,
    # we are now going :right
    {n_r, n_c} = case dir_change do

      # FORMAT: { row_idx, col_idx }
      {:left, face_entry_side} ->
        case face_entry_side do
          :left -> {max_idx - r, 0}
          :top -> {0, r}
          :right -> {r, max_idx}
          :down -> {max_idx, max_idx - r}
        end

      {:top, face_entry_side} ->
        case face_entry_side do
          :left -> {c, 0}
          :top -> {0, max_idx - c}
          :right -> {max_idx - c, max_idx}
          :down -> {max_idx, c}
        end

      {:right, face_entry_side} ->
        case face_entry_side do
          :left -> {r, 0}
          :top -> {0, max_idx - r}
          :right -> {max_idx - r , max_idx}
          :down -> {max_idx, r}
        end

      {:down, face_entry_side} ->
        case face_entry_side do
          :left -> {max_idx - c, 0}
          :top -> {0, c}
          :right -> {c, max_idx}
          :down -> {max_idx, max_idx - c}
        end
    end

    get_opposite = & case &1 do
      :left -> :right
      :top -> :down
      :right -> :left
      :down -> :top
    end

    %Cursor{ cursor | row: n_r, col: n_c, orientation: get_opposite.(n_side), face: n_face }
  end
end


defimpl MMap, for: MapFlat do
  def at(%MapFlat{} = map, {r,c}) do
    Map.get(map.grid, {r,c})
  end

  def advance(%MapFlat{} = map, %Cursor{} = cursor) do
    {r, c} = {cursor.row, cursor.col}

    {n_r, n_c} = case cursor.orientation do
      :left -> {r, c-1}
      :top -> {r-1, c}
      :right -> {r, c+1}
      :down -> {r+1, c}
    end

    # Return coords based if need to wrap
    {n_r, n_c} = case MMap.at(map, {n_r, n_c}) do
      nil ->
        # Need to wrap, get next value based on orientation + position
        case cursor.orientation do
          :left ->
            wrapped_c = Map.get(map.bounds, {:right, n_r})
            {n_r, wrapped_c}
          :right ->
            wrapped_c = Map.get(map.bounds, {:left, n_r})
            {n_r, wrapped_c}
          :top ->
            wrapped_r = Map.get(map.bounds, {:down, n_c})
            {wrapped_r, n_c}
          :down ->
            wrapped_r = Map.get(map.bounds, {:top, n_c})
            {wrapped_r, n_c}
        end
      # no wrapping
      _ -> {n_r, n_c}
    end

    # Check for wall
    case MMap.at(map, {n_r, n_c}) do
      nil -> raise "advance returned invalid cell coords"
      :open -> %Cursor{ cursor | row: n_r, col: n_c }
      :wall -> nil
    end
  end
end

defimpl MMap, for: MapCube do
  def at(%MapCube{} = map, {r, c, face}) do
    n_face_map = Map.get(map.face_lookup, face)
    Map.get(n_face_map, {r,c})
  end

  def advance(%MapCube{} = map, %Cursor{} = cursor) do
    {r, c} = {cursor.row, cursor.col}

    {n_r, n_c} = case cursor.orientation do
      :left -> {r, c-1}
      :top -> {r-1, c}
      :right -> {r, c+1}
      :down -> {r+1, c}
    end

    # Get new coordinates / dir, if transitioning to new face
    n_cursor =
      if n_r < 0 or n_c < 0 or n_r >= map.side_len or n_c >= map.side_len do
        MapCube.next_face_transition(cursor, map)
      else
        %Cursor{ cursor | row: n_r, col: n_c }
      end

    # Check for wall
    case MMap.at(map, {n_cursor.row, n_cursor.col, n_cursor.face}) do
      nil -> raise "next returned invalid cell coords"
      :open -> n_cursor
      :wall -> nil
    end
  end
end


defmodule Parse do

  def parse_directions(input) do
    directions =
      input |>
      String.trim_trailing |>
      String.split("\n") |>
      Enum.reverse |>
      hd()

    directions |>
      String.graphemes |>
      Enum.chunk_by(fn c ->
        case Integer.parse(c) do
          :error -> false
          _ -> true
        end
      end) |>
      Enum.map(fn list ->
        str = case length(list) do
          1 -> List.first(list)
          _ -> Enum.join(list, "")
        end

        case Integer.parse(str) do
          :error -> str
          {val, _} -> val
        end
      end)
  end

  def parse_board(input) do
    input |>
    String.trim_trailing |>
    String.split("\n") |>
    # drop directions & empty line between board and directions
    Enum.reverse |>
    Enum.drop(2) |>
    Enum.reverse
  end

  def parse(input) do

    board = Parse.parse_board(input)

    {board, bounds} =
      board |>
      Enum.with_index |>
      Enum.reduce({%{}, %{}}, fn {line, line_idx}, {board_map, bounds_map} ->

        line_elems =
          line |>
          String.graphemes |>
          Enum.with_index |>
          Enum.filter(fn {ch, _} -> ch != " " end) |>
          Enum.reduce([], fn {ch, ch_idx}, tup_list ->
            type = case ch do
              "." -> :open
              "#" -> :wall
              _ -> raise "Invalid input!"
            end

            [{{line_idx, ch_idx}, type}] ++ tup_list
          end)

          # First elem in this list is left_bound -> {:left, ...}
          # Last elem in this list is right_bound -> {:right, ...}
          # NOTE: line_elems is backwards so reverse

          {{left_line_idx, left_ch_idx}, _} = line_elems |> Enum.reverse |> hd
          {{right_line_idx, right_ch_idx}, _} = line_elems |> hd

          bounds_map = Map.put(bounds_map, {:left, left_line_idx}, left_ch_idx)
          bounds_map = Map.put(bounds_map, {:right, right_line_idx}, right_ch_idx)

          # Each elem can be top_bound if smaller val not already in key -> {:top, ...}
          # Each elem can be down_bound if great val not already in key -> {:top, ...}
          bounds_map =
            line_elems |>
            Enum.reduce(bounds_map, fn {{line_idx, ch_idx}, _}, bounds_acc ->
              # top bound
              bounds_acc = case Map.get(bounds_acc, {:top, ch_idx}) do
                nil -> Map.put(bounds_acc, {:top, ch_idx}, line_idx)
                existing ->
                  if existing > line_idx do
                    Map.put(bounds_acc, {:top, ch_idx}, line_idx)
                  else
                    bounds_acc
                  end
              end

              # down bound
              case Map.get(bounds_acc, {:down, ch_idx}) do
                nil -> Map.put(bounds_acc, {:down, ch_idx}, line_idx)
                existing ->
                  if existing < line_idx do
                    Map.put(bounds_acc, {:down, ch_idx}, line_idx)
                  else
                    bounds_acc
                  end
              end
          end)

        {
          Map.merge(board_map, Map.new(line_elems)),
          bounds_map
        }
      end)

    {board, bounds}
  end

  def parse_cube_faces(input, cube_line_height) do

    board = Parse.parse_board(input)
    cube_side_len = cube_line_height

    # max 6 possible cube faces
    max_possible_lines = cube_line_height * 6

    flattened_lines =
      Enum.reduce(0..(cube_line_height-1), [], fn cube_line_idx, normalized_lines ->

        flattened_line =
          board |>
          Enum.slice(cube_line_idx..max_possible_lines) |>
          Enum.take_every(cube_line_height) |>
          Enum.join("") |>
          String.graphemes |>
          Enum.filter(& &1 != " ")

        [flattened_line] ++ normalized_lines
      end) |>
      Enum.reverse

    # Get lookup by cube face index
    {_,cube_face_map} = Enum.reduce(1..6, {flattened_lines, %{}}, fn cube_face, {normalized_lines, face_lookup} ->
      {face_chars, rem} =
        normalized_lines |>
        Enum.reduce({[], []}, fn ch_list, {face_char_acc, rem_lines} ->

          face_line_chars = ch_list |> Enum.slice(0..(cube_side_len-1))
          rem = ch_list |> Enum.slice(cube_side_len..length(ch_list))
          {
            face_char_acc ++ [face_line_chars],
            rem_lines ++ [rem]
          }
        end)

      single_face_lookup =
        face_chars |>
        Enum.with_index |>
        Enum.reduce([], fn {face_line, line_idx}, face_tup_list ->
          line_tup_list =
            face_line |>
            Enum.with_index |>
            Enum.map(fn {face_ch, col_idx} ->
              type = case face_ch do
                "." -> :open
                "#" -> :wall
                _ -> raise "Invalid input!"
              end

              {{line_idx, col_idx}, type}
            end)

          face_tup_list ++ line_tup_list
        end) |>
        Map.new

      {rem, Map.put(face_lookup, cube_face, single_face_lookup)}
    end)

    cube_face_map
  end

  def get_face_global_coords(input, cube_side_len) do
    board = Parse.parse_board(input)

    char_lists =
      board |>
      Enum.map(fn line ->
        line |>
        String.graphemes
      end)

    char_lists |>
    Enum.take_every(cube_side_len) |>
    Enum.with_index |>
    Enum.reduce(%{}, fn {row_top_line, line_idx}, face_coords ->

      # Find offset (number of empty cells at start of row) before counting
      # the number of faces on the line
      col_start_offset = row_top_line |>
        Enum.find_index(fn ch -> ch == "." or ch == "#" end) |>
        div(cube_side_len)

      row_top_line = row_top_line |>
        Enum.filter(& &1 != " ")

      num_faces =
        row_top_line |>
        Enum.take_every(cube_side_len) |>
        length
      Enum.reduce(0..(num_faces-1), face_coords, fn i, faces_acc ->
        Map.put(faces_acc, map_size(faces_acc)+1, {line_idx, col_start_offset + i})
      end)
    end)
  end
end



defmodule MonkeyMap do

  def traverse([], _, cursor) do
    cursor
  end

  def traverse([c_dir | rem_dir], map, cursor) when not is_integer(c_dir) do
    MonkeyMap.traverse(rem_dir, map, Cursor.turn(cursor, c_dir))
  end

  def traverse([c_dir | rem_dir], map, cursor) do

    n_cursor = Enum.reduce_while(0..c_dir-1, cursor, fn _step, cursor_acc ->
      case MMap.advance(map, cursor_acc) do
        nil -> {:halt, cursor_acc}
        c -> {:cont, c}
      end
    end)

    MonkeyMap.traverse(rem_dir, map, n_cursor)
  end

  def score(row, col, turn) do
    turn_score = case turn do
      :right -> 0
      :down -> 1
      :left -> 2
      :top -> 3
    end

    (row+1)*1_000 + (col+1)*4 + turn_score
  end
end


defmodule Main do
  def main do
    file_str = "../input/d22.txt"
    input = File.read!(file_str)

    # Part 1:
    {board, bounds} = Parse.parse(input)
    directions = Parse.parse_directions(input)

    top_leftmost =
      board |>
      Enum.filter(fn {{r,_c},type} -> r == 0 and type != :wall end) |>
      Enum.min()

    {{r,c},_} = top_leftmost

    cursor_p1 = MonkeyMap.traverse(directions, %MapFlat{grid: board, bounds: bounds}, %Cursor{row: r, col: c, orientation: :right})


    # Part 2:
    cube_side_len = if String.contains?(file_str, "_ex"), do: 4, else: 50

    cube_face_map = Parse.parse_cube_faces(input, cube_side_len)
    global_coords = Parse.get_face_global_coords(input, cube_side_len)

    cursor_p2 = MonkeyMap.traverse(directions, %MapCube{ face_lookup: cube_face_map, side_len: cube_side_len }, %Cursor{row: 0, col: 0, orientation: :right, face: 1})




    # Scoring
    res_p1 = MonkeyMap.score(cursor_p1.row, cursor_p1.col, cursor_p1.orientation)


    {face_row, face_col} = Map.get(global_coords, cursor_p2.face)

    row_global = cursor_p2.row + 1 + (face_row * cube_side_len)
    col_global = cursor_p2.col + 1 + (face_col * cube_side_len)

    res_p2 = MonkeyMap.score(row_global, col_global, cursor_p2.orientation)


    IO.inspect(res_p1, label: "Part 1")
    IO.inspect(res_p2, label: "Part 2")
  end
end


Main.main()
