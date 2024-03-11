


defmodule BlizzardBasin do

  def parse(lines) do
    # drop up/down walls
    lines =
      lines |>
      Enum.slice(1..length(lines)-2)

    lines |>
    Enum.map(& String.graphemes/1) |>
    # drop left/right walls
    Enum.map(& Enum.slice(&1, 1..length(&1)-2)) |>
    Enum.with_index |>
    Enum.reduce(%{}, fn {row, row_idx}, blizz_acc ->
      row |>
      Enum.with_index |>
      Enum.reduce(blizz_acc, fn {ch, col_idx}, blizz_row_acc ->
        case ch do
          "." -> blizz_row_acc
          blizz ->
            dir = case blizz do
              "<" -> :left
              "^" -> :up
              ">" -> :right
              "v" -> :down
            end

            Map.put(blizz_row_acc, {row_idx, col_idx}, [dir])
        end
      end)
    end)
  end

  def bounds_and_dst(lines) do
    # last idx that is valid
    down_bound_idx = (lines |> length) - 2 - 1
    right_bound_idx = (lines |> hd |> String.graphemes |> length) - 2 - 1

    dst = {down_bound_idx, right_bound_idx}

    {down_bound_idx, right_bound_idx, dst}
  end

  # Memoize by time-step
  def advance_blizzards(blizz_lookup, steps_taken, {down_bound, right_bound}) do

    case Map.has_key?(blizz_lookup, steps_taken) do
      true -> blizz_lookup
      false ->
        prev_state = Map.get(blizz_lookup, steps_taken-1)

        n_state =
          prev_state |>
          Enum.map(fn {{r, c}, dir_list} ->
            dir_list |>
            Enum.map(fn dir ->
              {n_r, n_c} = case dir do
                :left -> {r, c-1}
                :up -> {r-1, c}
                :right -> {r, c+1}
                :down -> {r+1, c}
              end

              # Update if need to wrap
              {n_r, n_c} = cond do
                n_r < 0 -> {down_bound, n_c}
                n_c < 0 -> {n_r, right_bound}
                n_r > down_bound -> {0, n_c}
                n_c > right_bound -> {n_r, 0}
                true -> {n_r, n_c}
              end

              {{n_r, n_c}, dir}
            end)
          end) |>
          List.flatten |>
          # Need to update dir lists for each cell,
          # e.g. create list or
          Enum.reduce(%{}, fn {{r,c},dir}, blizz_acc ->
            blizz_acc |>
            Map.put_new_lazy({r,c}, fn -> [] end) |>
            Map.update!({r,c}, & [dir] ++ &1)
          end)

        Map.put(blizz_lookup, steps_taken, n_state)
    end
  end

  # abort when lower_bound on steps is >= min_steps
  # ~4x prune on example
  def traverse(_, {_, _, {d_r, d_c}}, {{p_r, p_c}, steps_taken, min_steps}, seen)
  when (steps_taken + ((d_r-p_r) + (d_c-p_c))) >= min_steps do
    {min_steps, seen}
  end

  # arrived
  def traverse(_, {_, _, dst}, {pos, steps_taken, _}, seen) when pos == dst do
    IO.puts("ARRIVED #{steps_taken}")
    {steps_taken, seen}
  end

  # memoized blizzard movement, it's independent of our traversal
  def traverse(blizz_lookup, {down_bound, right_bound, dst}, {pos, steps_taken, min_steps}, seen) do
    # NOTE: can switch places with an adjacent blizzard in one turn
    # NOTE: can't share place with blizzard
    # NOTE: blizzards move first during turn

    # Use manhattan dist as heuristic for moves to prioritize
    # DFS with min_steps to reach end for pruning

    # max, 5 possible actions
    # wait + 4 dirs to move

    #IO.puts("#{steps_taken}")

    # First, advance the blizzards
    blizz_lookup = BlizzardBasin.advance_blizzards(blizz_lookup, steps_taken, {down_bound, right_bound})

    # Second, get all valid possible moves, assumptions:
    #   1. Backtracking is allowed.
    #   2. Can swap position with blizzard on same turn.
    #   3. Cannot remain in-place if blizzard occupies current cell.

    # So, check the advanced blizzards 'blizz_lookup', for up to max 5 moves into empty cells

    blizz_state = Map.get(blizz_lookup, steps_taken)


    {r, c} = pos

    # Order list by manhattan dist to destination
    # First group:  [down, right]
    # Second group: [remain]
    # Third group:  [up, left]
    move_closer = [
      # NOT going past edge AND NOT moving into blizzard
      # down
      (if (r+1) <= down_bound and blizz_state |> Map.get({r+1,c}) |> is_nil, do: {r+1,c}, else: nil),
      # right
      (if (c+1) <= right_bound and blizz_state |> Map.get({r,c+1}) |> is_nil, do: {r,c+1}, else: nil),
    ]

    remain = [(if blizz_state |> Map.get({r,c}) |> is_nil, do: {r,c}, else: nil)]

    move_farther = [
      # NOT going past edge AND NOT moving into blizzard
      # up
      (if (r-1) >= 0 and blizz_state |> Map.get({r-1,c}) |> is_nil, do: {r-1,c}, else: nil),
      # left
      (if (c-1) >= 0 and blizz_state |> Map.get({r,c-1}) |> is_nil, do: {r,c-1}, else: nil),
    ]

    valid_moves = (move_closer ++ remain ++ move_farther) |>
      List.flatten |>
      Enum.filter(& &1 != nil)


    # handle starting pos, don't allow moving left/right since row is -1
    valid_moves = case pos do
      # 2 possible moves from starting position
      {-1, 0} -> Enum.filter(valid_moves, & &1 in [{0,0}, {-1,0}])
      _ -> valid_moves
    end


    #IO.inspect({steps_taken, pos}, label: "{steps_taken, pos}")
    #IO.inspect({steps_taken, pos, valid_moves}, label: "{steps_taken, pos, valid_moves}")

    # Abort if path won't set new bound
    Enum.reduce_while(valid_moves, {min_steps, seen}, fn move, {min_steps_acc, seen_acc} ->
      if (steps_taken+1) >= min_steps_acc do
        {:halt, {min_steps_acc, seen_acc}}
      else

        # if already traversed pos at given tick skip, else traverse
        case MapSet.member?(seen_acc, {elem(move,0), elem(move,1), steps_taken + 1}) do
          true -> {:cont, {min_steps_acc, seen_acc}}
          false ->
            {n_min, n_seen} = BlizzardBasin.traverse(blizz_lookup,
              {down_bound, right_bound, dst},
              {move, steps_taken + 1, min_steps_acc},
              MapSet.put(seen_acc, {elem(move,0), elem(move,1), steps_taken + 1})
            )

            {
              :cont,
              {
                min(min_steps_acc, n_min),
                n_seen
              }
            }
        end
      end
    end)
  end
end



defmodule Main do
  def main do
    lines = File.read!("../input/d24.txt") |>
      String.trim_trailing |>
      String.split("\n")

    blizz_lookup = BlizzardBasin.parse(lines)

    # IO.inspect(blizz_lookup, label: "blizz_lookup")

    start_pos = {-1, 0}

    {down_bound, right_bound, dst} = BlizzardBasin.bounds_and_dst(lines)
    # Set dst to bottom-right corner, add 1 for step to finish

    {res_p1, _} = BlizzardBasin.traverse(%{ -1 => blizz_lookup }, {down_bound, right_bound, dst}, {start_pos, 0, :infinity}, MapSet.new([{-1,0,0}]))

    IO.inspect(res_p1+1, label: "Part 1")


  end
end


Main.main()
