defmodule Board do
  # Note: Problem with the matrix approach is that things don't move in same dir ->
  # relative distances between cells will change ->
  # need to separate to two groups: {right, down}, {left, up}
  defstruct [:d_r_mat, :u_l_mat, :right_bound, :down_bound]

  def from_lines(lines) do
    rows_all =
      lines
      # drop up/down walls
      |> Enum.slice(1..(length(lines) - 2))
      |> Enum.map(&String.graphemes/1)
      # drop left/right walls
      |> Enum.map(&Enum.slice(&1, 1..(length(&1) - 2)))
      |> Enum.reduce([], fn row, matrix ->
        n_row =
          row
          |> Enum.map(fn ch ->
            case ch do
              "." -> :empty
              "<" -> :left
              "^" -> :up
              ">" -> :right
              "v" -> :down
            end
          end)

        matrix ++ [n_row]
      end)

    rows_d_r =
      rows_all
      |> Enum.map(fn row ->
        Enum.map(row, fn cell ->
          case cell do
            x when x in [:down, :right] -> x
            _ -> :empty
          end
        end)
      end)

    rows_u_l =
      rows_all
      |> Enum.map(fn row ->
        Enum.map(row, fn cell ->
          case cell do
            x when x in [:left, :up] -> x
            _ -> :empty
          end
        end)
      end)

    %Board{d_r_mat: rows_d_r, u_l_mat: rows_u_l}
    |> Board.bounds()
  end

  def bounds(%Board{} = board) do
    # last idx that is valid
    down_bound_idx = (board.d_r_mat |> length) - 1
    right_bound_idx = (board.d_r_mat |> hd |> length) - 1

    %Board{board | right_bound: right_bound_idx, down_bound: down_bound_idx}
  end

  def adj_empty_at_tick(board, {r, c}, start, ticks_to_simulate) do
    adj_list = [
      {r, c + 1},
      {r + 1, c},
      {r, c},
      {r, c - 1},
      {r - 1, c}
    ]

    adj_list
    |> Enum.filter(fn {n_r, n_c} ->
      # allow option to remain at start pos if we haven't left it yet
      ({n_r, n_c} == start and {r, c} == start) or
        (n_r >= 0 and n_c >= 0 and n_r <= board.down_bound and n_c <= board.right_bound)
    end)
    |> Enum.filter(fn {n_r, n_c} ->
      num_cols = board.right_bound + 1
      num_rows = board.down_bound + 1

      # ticks_to_simulate % row_len
      shift_horiz = rem(ticks_to_simulate, num_cols)
      right_cell = rem(n_c - shift_horiz + num_cols, num_cols)
      # add num_cols so negative numbers wrap around
      left_cell = rem(n_c + shift_horiz, num_cols)

      # ticks_to_simulate % col_len
      shift_vert = rem(ticks_to_simulate, num_rows)
      down_cell = rem(n_r - shift_vert + num_rows, num_rows)
      # add num_rows so negative numbers wrap around
      up_cell = rem(n_r + shift_vert, num_rows)

      # NOTE: Important to filter to correct directional blizzard, e.g. ' == :right'
      # so other directional blizzard at cell doesn't get counted.
      # defaults of [] so that the bottom_right start pos (which is beyond row bound)
      # doesn't cause nil problem
      right_blizz? = board.d_r_mat |> Enum.at(n_r, []) |> Enum.at(right_cell) == :right
      down_blizz? = board.d_r_mat |> Enum.at(down_cell, []) |> Enum.at(n_c) == :down

      left_blizz? = board.u_l_mat |> Enum.at(n_r, []) |> Enum.at(left_cell) == :left
      up_blizz? = board.u_l_mat |> Enum.at(up_cell, []) |> Enum.at(n_c) == :up

      # check if a blizzard going in ANY direction will occupy {n_r, n_c}
      # start pos is also always open if we haven't left it yet
      [right_blizz?, down_blizz?, left_blizz?, up_blizz?] == [false, false, false, false] or
        ({n_r, n_c} == start and {r, c} == start)
    end)
  end
end

defmodule BlizzardBasin do
  def traverse(board, start_dst, pos_steps, seen \\ MapSet.new())

  # abort when lower_bound on steps is >= min_steps
  # ~4x prune on example
  def traverse(_, {_, {d_r, d_c}}, {{p_r, p_c}, steps_taken, min_steps}, seen)
      when steps_taken + (d_r - p_r + (d_c - p_c)) >= min_steps do
    {min_steps, seen}
  end

  # arrived
  def traverse(_, {_, dst}, {pos, steps_taken, _}, seen) when pos == dst do
    # dst is cell right before the actual destination, so add 1 to steps required,
    # (destination cell is out-of-bounds and always empty)
    {steps_taken + 1, seen}
  end

  def traverse(board, {start, dst}, {pos, steps_taken, min_steps}, seen) do
    # NOTE: can switch places with an adjacent blizzard in one turn
    # NOTE: can't share place with blizzard
    # NOTE: blizzards move first during turn

    # Use manhattan dist as heuristic for moves to prioritize
    # DFS with min_steps to reach end for pruning

    # max, 5 possible actions
    # wait + 4 dirs to move

    # get all valid possible moves, assumptions:
    #   1. Backtracking is allowed.
    #   2. Can swap position with blizzard on same turn.
    #   3. Cannot remain in-place if blizzard occupies current cell.

    # Order list by manhattan dist to destination
    # First group:  [down, right]
    # Second group: [remain]
    # Third group:  [up, left]
    valid_moves = Board.adj_empty_at_tick(board, pos, start, steps_taken + 1)

    # if going bottom-left -> top-right,
    # reverse valid_moves to make min l1 dist moves first
    valid_moves =
      case dst do
        {0, 0} -> Enum.reverse(valid_moves)
        _ -> valid_moves
      end

    # Abort if path won't set new bound
    Enum.reduce_while(valid_moves, {min_steps, seen}, fn move, {min_steps_acc, seen_acc} ->
      # can't improve by making more moves
      if steps_taken + 1 >= min_steps_acc do
        {:halt, {min_steps_acc, seen_acc}}
      else
        # if already traversed pos at given tick skip, else traverse
        case MapSet.member?(seen_acc, {elem(move, 0), elem(move, 1), steps_taken + 1}) do
          true ->
            {:cont, {min_steps_acc, seen_acc}}

          false ->
            {n_min, n_seen} =
              BlizzardBasin.traverse(
                board,
                {start, dst},
                {move, steps_taken + 1, min_steps_acc},
                MapSet.put(seen_acc, {elem(move, 0), elem(move, 1), steps_taken + 1})
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

defmodule D24 do
  def sol(input) do
    lines =
      input
      |> String.split("\n")

    board = Board.from_lines(lines)

    # Set dsts to corner, add 1 for step to finish
    top_left_start = {-1, 0}
    down_right_start = {board.down_bound + 1, board.right_bound}

    top_left_dst = {0, 0}
    down_right_dst = {board.down_bound, board.right_bound}

    results =
      [
        {top_left_start, down_right_dst},
        {down_right_start, top_left_dst},
        {top_left_start, down_right_dst}
      ]
      |> Enum.reduce(
        [0],
        fn {start, dst}, res_list ->
          steps =
            BlizzardBasin.traverse(board, {start, dst}, {start, res_list |> hd(), :infinity})
            |> elem(0)

          [steps] ++ res_list
        end
      )
      |> Enum.reverse()

    [_, res_p1, _, res_p2] = results

    IO.inspect(res_p1, label: "Part 1")
    IO.inspect(res_p2, label: "Part 2")
  end
end
