
defmodule RPS do

  @lose 0
  @draw 3
  @win 6
  
  def rps_p1(line, accum_score) do

    moves = String.split(line)

    moves = Enum.map(moves, fn ch -> cond do 
          ch in ["A", "X"] ->
            :r
          ch in ["B", "Y"] ->
            :p
          ch in ["C", "Z"] ->
            :s
        end
      end
    )

    score = case Enum.at(moves, 1) do
      :r -> 1
      :p -> 2
      :s -> 3
    end

    accum_score + score + case moves do
        [:r, :p] -> @win
        [:r, :s] -> @lose

        [:p, :r] -> @lose
        [:p, :s] -> @win

        [:s, :r] -> @win
        [:s, :p] -> @lose

        _ ->
          @draw
    end
  end


  def rps_p2(line, accum_score) do

    vals = String.split(line)

    outcome = case Enum.at(vals, 1) do
      "X" -> :l
      "Y" -> :d
      "Z" -> :w
    end

    opp_move = case Enum.at(vals, 0) do
      "A" -> :r
      "B" -> :p
      "C" -> :s
    end

    move_scores = %{:r => 1, :p => 2, :s => 3}

    loses_to = %{
      :r => move_scores[:p],
      :p => move_scores[:s],
      :s => move_scores[:r],
    }

    beats = %{
      :r => move_scores[:s],
      :p => move_scores[:r],
      :s => move_scores[:p],
    }

    accum_score + case outcome do
      :l -> @lose + beats[opp_move]
      :d -> @draw + move_scores[opp_move]
      :w -> @win + loses_to[opp_move]
    end
  end

end


input = File.read!("../input/d2.txt")

lines = String.split(input, "\n")

p1_score = Enum.reduce(lines, 0, &RPS.rps_p1/2)
p2_score = Enum.reduce(lines, 0, &RPS.rps_p2/2)

IO.puts("Part 1: #{p1_score}")
IO.puts("Part 2: #{p2_score}")



