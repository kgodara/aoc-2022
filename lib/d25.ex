# 1. Decimal --> SNAFU
# How to tell when to do bigger_num
# then subtraction vs smaller_num and addition?
#
#   Seems like good approach is to check max
#   val in given num 'bits' then set highest bit when
#   max_expressible > target
#
#   Then step down bits with new target number based on diff
#   (which can be < 0 or > 0) and pick pos/negative accordingly
#

defmodule SNAFU do
  def parse(lines) do
    lines
    |> Enum.map(fn line ->
      line
      |> String.graphemes()
      |> Enum.map(fn ch ->
        case ch do
          "0" -> 0
          "1" -> 1
          "2" -> 2
          "-" -> -1
          "=" -> -2
        end
      end)
      |> Enum.reverse()
    end)
  end

  def to_decimal([], _step, acc) do
    acc
  end

  def to_decimal([0 | rem], step, acc) do
    SNAFU.to_decimal(rem, step + 1, acc)
  end

  # smaller bits at start
  def to_decimal([bit | rem], step, acc) do
    n_acc = acc + Integer.pow(5, step) * bit

    SNAFU.to_decimal(rem, step + 1, n_acc)
  end

  # Assume: decimal >= 0
  def get_first_digit(decimal, step) do
    sign = div(decimal, abs(decimal))

    decimal = abs(decimal)

    cumulative =
      if step == 0, do: 0, else: Enum.reduce(0..(step - 1), 0, &(&2 + 2 * Integer.pow(5, &1)))

    place_val = Integer.pow(5, step)
    one_bit = place_val + cumulative
    two_bit = place_val * 2 + cumulative

    bit =
      cond do
        one_bit >= decimal -> 1
        two_bit >= decimal -> 2
        true -> nil
      end

    case {bit, sign} do
      {nil, _} -> SNAFU.get_first_digit(decimal * sign, step + 1)
      _ -> {bit * sign, step}
    end
  end

  def from_decimal(num) do
    num
    |> SNAFU.decimal_to_bit_steps()
    |> SNAFU.from_bit_steps()
  end

  def decimal_to_bit_steps(residue, acc \\ [])

  def decimal_to_bit_steps(0, acc) do
    acc
  end

  def decimal_to_bit_steps(residue, acc) do
    {bit, step} = SNAFU.get_first_digit(residue, 0)

    residue = residue - Integer.pow(5, step) * bit

    SNAFU.decimal_to_bit_steps(residue, [{bit, step}] ++ acc)
  end

  def from_bit_steps(bit_step_list) do
    # get the max step in the list
    max_step =
      bit_step_list
      |> Enum.map(fn {_, step} -> step end)
      |> Enum.max()

    empty_num = Enum.reduce(0..max_step, [], fn _i, acc -> [0] ++ acc end)

    Enum.reduce(bit_step_list, empty_num, fn {bit, step}, acc ->
      bit_ch =
        case bit do
          0 -> "0"
          1 -> "1"
          2 -> "2"
          -1 -> "-"
          -2 -> "="
        end

      List.replace_at(acc, step, bit_ch)
    end)
    |> Enum.reverse()
    |> Enum.join("")
  end
end

defmodule D25 do
  def sol(input) do
    lines =
      input
      |> String.split("\n")

    parsed = SNAFU.parse(lines)

    sum =
      parsed
      |> Enum.map(&SNAFU.to_decimal(&1, 0, 0))
      |> Enum.sum()

    SNAFU.from_decimal(sum) |> IO.inspect(label: "Part 1")
  end
end
