
defmodule Rope do

  def exec_move_p1({dir, steps},{{hx, hy}, {tx, ty}}, uniq_pos) do

    additive_move? = dir in ["U", "R"]
    vert_move? = dir in ["U", "D"]

    uniq_pos = MapSet.put(uniq_pos, {tx, ty})

    Enum.reduce(1..steps, {{hx, hy}, {tx, ty}, uniq_pos}, fn _, {{hx, hy}, {tx, ty}, t_pos_set} ->
      # move the head
      {hx, hy} = case {vert_move?, additive_move?} do
        {true, true} -> {hx, hy+1}
        {true, false} -> {hx, hy-1}
        {false, true} -> {hx+1, hy}
        {false, false} -> {hx-1, hy}
      end

      nonadjacent? = case {abs(hx - tx), abs(hy - ty)} do
        {dx, dy} when dx > 1 or dy > 1 -> true
        _ -> false
      end

      diag_step? = case {abs(hx - tx), abs(hy - ty)} do
        {dx, dy} when (dx > 0 and dy > 0) and (dx > 1 or dy > 1) -> true
        _ -> false
      end

      {tx, ty} = case {nonadjacent?, diag_step?} do
        {_, true} ->
          case {hx - tx, hy - ty} do
            {dx, dy} when dx > 0 and dy > 0 -> {tx + 1, ty + 1}
            {dx, dy} when dx > 0 and dy < 0 -> {tx + 1, ty - 1}
            {dx, dy} when dx < 0 and dy > 0 -> {tx - 1, ty + 1}
            {dx, dy} when dx < 0 and dy < 0 -> {tx - 1, ty - 1}
          end
        {true, false} -> {tx + div(hx - tx,2), ty + div(hy - ty,2)}
        _ -> {tx, ty}

      end

      {{hx, hy}, {tx, ty}, t_pos_set |> MapSet.put({tx, ty})}

    end)
  end

end


lines = File.read!("../input/d9.txt") |> String.trim_trailing |> String.split("\n")

tail_positions = lines |>
  Enum.map(fn i -> i |> String.split(" ") end) |>
  Enum.map(fn [dir, steps] -> {dir, String.to_integer(steps)} end) |>
  Enum.reduce({{0,0}, {0,0}, MapSet.new([{0,0}])}, fn move_args, {h, t, t_pos} -> Rope.exec_move_p1(move_args, {h, t}, t_pos) end)

IO.puts(elem(tail_positions, 2) |> MapSet.size)


