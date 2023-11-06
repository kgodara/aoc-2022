# All that work for such a short solution...

defmodule DistressSignal do


    # return remaining input string
    def find_list_rbound(data, 0, right_bound) do
      {right_bound, data}
    end


    def find_list_rbound(data, depth, right_bound) do

      leading_token_trimmed = binary_slice(data, 1..byte_size(data))

      n_depth = depth + cond do
        data =~ ~r/^\[.*/ -> 1
        data =~ ~r/^\].*/ -> -1
        true -> 0
      end

      DistressSignal.find_list_rbound(leading_token_trimmed, n_depth, right_bound + 1)
    end


    # nil = no more elements, "" = no value, "" = nothing remaining
    def next_elem("") do
      {nil, "", ""}
    end


    # Searching for START of next element =>
    # skip commas / closing brackets
    def next_elem(<<first::binary-size(1), rest::binary>>) when first in [",", "]"]  do
      DistressSignal.next_elem(rest)
    end


    def next_elem(data) do
      # {type, elem, remaining}
      cond do
        # start of list 
        data =~ ~r/^\[.*/ ->

          {end_, rem} = DistressSignal.find_list_rbound(binary_slice(data, 1..byte_size(data)), 1, 0)

          # NOTE: binary_slice() does not allow slicing to an empty string since
          #   the range would have to be negative,
          #    hence binary_part()
          # This is relevant for empty lists, "[]"
          {:list, binary_part(data, 1, end_-1), rem}

        # match leading any-num-digit integer
        data =~ ~r/^[0-9]+/ ->
          leading_int = Regex.run(~r/^[0-9]+/, data, capture: :first) |> List.first
          {:int, leading_int, binary_slice(data, byte_size(leading_int)..byte_size(data))}
      end
    end


    def compare(left, right) do
      {l_type, l_val, l_rem} = DistressSignal.next_elem(left)
      {r_type, r_val, r_rem} = DistressSignal.next_elem(right)

      case {l_type, r_type} do
        {:int, :int} ->
          [l_int, r_int] = [l_val, r_val] |> Enum.map(& String.to_integer/1)
          cond do
            l_int > r_int -> false
            l_int < r_int -> true
            l_int == r_int -> DistressSignal.compare(l_rem, r_rem)
          end
        {:list, :list} when l_val == "" and r_val == "" ->
          # case where two empty lists co-occur,
          # and parsing should skip trying to evaluate list contents
          DistressSignal.compare(l_rem, r_rem)
        {l, r} when l in [:list, :int] and r in [:list, :int] ->
          DistressSignal.compare(l_val, r_val)
        {l, nil} when l != nil -> false
        {nil, _} -> true
      end
    end
end


lines = File.read!("../input/d13.txt") |>
  String.trim_trailing |>
  String.split("\n", trim: true)

# Part 1 sol
res = lines |>
  Enum.chunk_every(2) |>
  # attach 1-based index for summing up indexes of valid pairs
  Enum.with_index(1) |>
  Enum.map( fn {[first, second], idx} ->
    {DistressSignal.compare(first, second), idx}
  end) |>
  Enum.filter(fn {res, _} -> res end) |>
  Enum.map(& elem(&1, 1)) |>
  Enum.reduce(0, & &1 + &2)

# Part 2 sol
lines = lines |>
  List.insert_at(0, "[[2]]") |>
  List.insert_at(0, "[[6]]") |>
  Enum.sort(&DistressSignal.compare/2)

left_idx = lines |> Enum.find_index(& &1 == "[[2]]") |> Kernel.+(1)
right_idx = lines |> Enum.find_index(& &1 == "[[6]]") |> Kernel.+(1)


IO.puts("Part 1: #{res}")
IO.puts("Part 2: #{left_idx*right_idx}")
