defmodule Diffusion do
  def parse(lines) do
    lines
    |> Enum.reduce({0, MapSet.new()}, fn line, {r, coord_acc} ->
      coords =
        line
        |> String.graphemes()
        |> Enum.with_index()
        |> Enum.filter(&(elem(&1, 0) == "#"))
        |> Enum.map(fn {_ch, c} -> {r, c} end)

      {
        r + 1,
        MapSet.union(coord_acc, MapSet.new(coords))
      }
    end)
    |> elem(1)
  end

  def get_turn_moves(coord_set, dir_offset) do
    _y = """
    During the first half of each round, each Elf considers the eight positions adjacent to themself.
    If no other Elves are in one of those eight positions, the Elf does not do anything during this round.
    Otherwise, the Elf looks in each of four directions in the following order and proposes moving one step in the first valid direction:

    If there is no Elf in the N, NE, or NW adjacent positions, the Elf proposes moving north one step.
    If there is no Elf in the S, SE, or SW adjacent positions, the Elf proposes moving south one step.
    If there is no Elf in the W, NW, or SW adjacent positions, the Elf proposes moving west one step.
    If there is no Elf in the E, NE, or SE adjacent positions, the Elf proposes moving east one step.
    """

    moves_list =
      coord_set
      |> MapSet.to_list()
      |> Enum.reduce([], fn {r, c}, move_acc ->
        # directions clockwise, starting at N
        dirs = {
          # N
          MapSet.member?(coord_set, {r - 1, c}),
          MapSet.member?(coord_set, {r - 1, c + 1}),
          # E
          MapSet.member?(coord_set, {r, c + 1}),
          MapSet.member?(coord_set, {r + 1, c + 1}),
          # S
          MapSet.member?(coord_set, {r + 1, c}),
          MapSet.member?(coord_set, {r + 1, c - 1}),
          # W
          MapSet.member?(coord_set, {r, c - 1}),
          MapSet.member?(coord_set, {r - 1, c - 1})
        }

        if Tuple.to_list(dirs) |> Enum.any?() do
          # N, NE, NW, etc.
          move_north? = not (elem(dirs, 0) or elem(dirs, 1) or elem(dirs, 7))

          move_south? = not (elem(dirs, 3) or elem(dirs, 4) or elem(dirs, 5))

          move_west? = not (elem(dirs, 5) or elem(dirs, 6) or elem(dirs, 7))

          move_east? = not (elem(dirs, 1) or elem(dirs, 2) or elem(dirs, 3))

          dirs_labelled = [
            {move_north?, :north},
            {move_south?, :south},
            {move_west?, :west},
            {move_east?, :east}
          ]

          # Get the 4 directions ordered based on however many shifts have occurred
          dirs_ordered =
            Stream.cycle(dirs_labelled)
            |> Stream.take(4 + dir_offset)
            |> Enum.slice(dir_offset..(dir_offset + 3))

          # IO.inspect({{r,c}, dirs_ordered}, label: "{{r,c}, dirs_ordered}")

          move_dir =
            dirs_ordered
            |> Enum.find({nil, nil}, fn {can_move?, _} -> can_move? == true end)
            |> elem(1)

          {n_r, n_c} =
            case move_dir do
              :north -> {r - 1, c}
              :south -> {r + 1, c}
              :west -> {r, c - 1}
              :east -> {r, c + 1}
              nil -> {nil, nil}
            end

          case n_r do
            nil -> move_acc
            _ -> [{{r, c}, {n_r, n_c}}] ++ move_acc
          end

          # If all adjacent are empty, do nothing
        else
          move_acc
        end
      end)

    _z = """
    After each Elf has had a chance to propose a move, the second half of the round can begin.
    Simultaneously, each Elf moves to their proposed destination tile if they were the only Elf to propose moving to that position.
    If two or more Elves propose moving to the same position, none of those Elves move.
    """

    moves_freqs = moves_list |> Enum.frequencies_by(fn {{_r, _c}, {n_r, n_c}} -> {n_r, n_c} end)

    # eliminate duplicate moves
    moves_list
    |> Enum.filter(fn {{_r, _c}, {n_r, n_c}} -> Map.get(moves_freqs, {n_r, n_c}) == 1 end)
  end

  def exec_moves(moves_list, coord_set) do
    Enum.reduce(moves_list, coord_set, fn {{r, c}, {n_r, n_c}}, coord_acc ->
      coord_acc
      |> MapSet.delete({r, c})
      |> MapSet.put({n_r, n_c})
    end)
  end

  def exec_num_turns(coord_set, num_turns) do
    Enum.reduce(0..(num_turns - 1), coord_set, fn i, coord_acc ->
      Diffusion.get_turn_moves(coord_acc, rem(i, 4))
      |> Diffusion.exec_moves(coord_acc)
    end)
  end

  def exec_turns_to_stasis(coord_set) do
    Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), coord_set, fn i, coord_acc ->
      move_list = Diffusion.get_turn_moves(coord_acc, rem(i, 4))

      case length(move_list) do
        0 -> {:halt, i + 1}
        _ -> {:cont, Diffusion.exec_moves(move_list, coord_acc)}
      end
    end)
  end

  def calc_bbox_empty(coord_set) do
    # get bbox bounds, min/max for x and y
    {{min_r, max_r}, {min_c, max_c}} =
      coord_set
      |> MapSet.to_list()
      |> then(fn coord_list ->
        {
          Enum.min_max_by(coord_list, fn {r, _} -> r end)
          |> then(fn {{min_r, _}, {max_r, _}} -> {min_r, max_r} end),
          Enum.min_max_by(coord_list, fn {_, c} -> c end)
          |> then(fn {{_, min_c}, {_, max_c}} -> {min_c, max_c} end)
        }
      end)

    # +1 since both bounds are inclusive
    (abs(max_r - min_r) + 1) * (abs(max_c - min_c) + 1) - MapSet.size(coord_set)
  end
end

defmodule D23 do
  def sol(input) do
    lines =
      input
      |> String.split("\n")

    coord_lookup = Diffusion.parse(lines)

    p1_res =
      coord_lookup
      |> Diffusion.exec_num_turns(10)
      |> Diffusion.calc_bbox_empty()

    p2_res = Diffusion.exec_turns_to_stasis(coord_lookup)

    IO.inspect(p1_res, label: "Part 1")
    IO.inspect(p2_res, label: "Part 2")
  end
end
