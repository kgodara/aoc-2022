
defmodule Rope do


  def move_head({hx, hy}, dir) do
    additive_move? = dir in ["U", "R"]
    vert_move? = dir in ["U", "D"]

    case {vert_move?, additive_move?} do
        {true, true} -> {hx, hy+1}
        {true, false} -> {hx, hy-1}
        {false, true} -> {hx+1, hy}
        {false, false} -> {hx-1, hy}
    end
  end


  def move_tail({tx, ty}, {hx, hy}) do

    # are head and tail nonadjacent (tail has to move)?
    nonadjacent? = case {abs(hx - tx), abs(hy - ty)} do
      {dx, dy} when dx > 1 or dy > 1 -> true
      _ -> false
    end

    # will the tail's move be diagonal?
    diag_step? = case {abs(hx - tx), abs(hy - ty)} do
      {dx, dy} when (dx > 0 and dy > 0) and (dx > 1 or dy > 1) -> true
      _ -> false
    end

    # moved tail coords
    case {nonadjacent?, diag_step?} do

      # diagonal moves are all [+/- 1, +/- 1]
      {_, true} ->
        # sign function for dx, dy (positive -> 1, negative -> -1)
        # NOTE: 'case' statement is more legible, sign function is here FOR FUN
        dx = hx-tx
        dx = div(dx, max(1, abs(dx)))

        dy = hy-ty
        dy = div(dy, max(1, abs(dy)))

        {tx + dx, ty + dy}

      # non-diagonal moves will always involve tail having a 
      # manhattan dist of 2 (in a straight line) from head,
      # so can use div 2 to correctly increment/decrement coords 
      {true, false} -> {tx + div(hx - tx,2), ty + div(hy - ty,2)}
      _ -> {tx, ty}
    end
  end


  def exec_move({_, steps}, {node_list, uniq_pos}) when steps == 0 do
    {node_list, uniq_pos}
  end


  def exec_move({dir, steps}, {node_list, uniq_pos}) do

    # update the head element manually
    moved_head = node_list |>
      List.first |>
      Rope.move_head(dir)

    # update each non-head (tail) element by one step,
    # using prior (already moved) element
    moved_nodes = Enum.reduce(Enum.drop(node_list,1), [moved_head],
        & [Rope.move_tail(&1, List.first &2)] ++ &2) |>
    Enum.reverse

    # Only add the last tail node's position to MapSet 
    Rope.exec_move({dir, steps-1}, {moved_nodes, MapSet.put(uniq_pos, List.last moved_nodes )})
  end
end


lines = File.read!("../input/d9.txt") |> String.trim_trailing |> String.split("\n")

parsed_move_cmds = lines |>
  Enum.map(& String.split(&1, " ")) |>
  Enum.map(& {List.first(&1), &1 |> List.last |> String.to_integer})

origin = {0,0}
pos_set = MapSet.new([origin])

[{_, tail_pos1}, {_, tail_pos2}] = Enum.map([2,10], 
  fn n -> Enum.reduce(parsed_move_cmds, {List.duplicate(origin, n), pos_set}, & Rope.exec_move(&1, &2)) end
)


IO.puts("Part 1: #{MapSet.size tail_pos1}")
IO.puts("Part 2: #{MapSet.size tail_pos2}")

