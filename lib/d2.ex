defmodule RPS do
  # scores

  @lose 0
  @draw 3
  @win 6

  @r 1
  @p 2
  @s 3

  def p1(line, accum_score) do
    moves = String.split(line)

    moves =
      Enum.map(moves, fn ch ->
        cond do
          ch in ["A", "X"] ->
            :r

          ch in ["B", "Y"] ->
            :p

          ch in ["C", "Z"] ->
            :s
        end
      end)

    score =
      case Enum.at(moves, 1) do
        :r -> @r
        :p -> @p
        :s -> @s
      end

    accum_score + score +
      case moves do
        [:r, :p] ->
          @win

        [:r, :s] ->
          @lose

        [:p, :r] ->
          @lose

        [:p, :s] ->
          @win

        [:s, :r] ->
          @win

        [:s, :p] ->
          @lose

        _ ->
          @draw
      end
  end

  def p2(line, accum_score) do
    vals = String.split(line)

    outcome =
      case Enum.at(vals, 1) do
        "X" -> :l
        "Y" -> :d
        "Z" -> :w
      end

    {opp_move, opp_move_score} =
      case Enum.at(vals, 0) do
        "A" -> {:r, @r}
        "B" -> {:p, @p}
        "C" -> {:s, @s}
      end

    loses_to = %{
      :r => @p,
      :p => @s,
      :s => @r
    }

    beats = %{
      :r => @s,
      :p => @r,
      :s => @p
    }

    accum_score +
      case outcome do
        :l -> @lose + beats[opp_move]
        :d -> @draw + opp_move_score
        :w -> @win + loses_to[opp_move]
      end
  end
end

defmodule D2 do
  def sol(input) do
    lines = String.split(input, "\n")

    p1_score = Enum.reduce(lines, 0, &RPS.p1/2)
    p2_score = Enum.reduce(lines, 0, &RPS.p2/2)

    IO.puts("Part 1: #{p1_score}")
    IO.puts("Part 2: #{p2_score}")
  end
end
