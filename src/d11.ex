
defmodule Monkey do
  defstruct [:items, :op, :test, :pass, :fail]
end


defmodule KeepAway do


  def op_to_fn(op_str) do
    tokens = String.split(op_str)

    op = case List.first(tokens) do
      "+" -> &Kernel.+/2
      "*" -> &Kernel.*/2
    end

    case Enum.at(tokens, 1) do
      "old" ->
        &(op.(&1, &1))
      _ ->
        num = Enum.at(tokens, 1) |> String.to_integer
        &(op.(&1, num))
    end
  end


  def parse_monkeys([], _, monkey_lookup) do
    monkey_lookup
  end


  def parse_monkeys(["" | rest], cur_monkey, monkey_lookup) do
    KeepAway.parse_monkeys(rest, cur_monkey, monkey_lookup)
  end


  def parse_monkeys([cur_line | rest], cur_monkey, monkey_lookup) do

    {cur_monkey, monkey_lookup} = 
    cond do
      String.contains?(cur_line, "Monkey ") ->
        monkey_num = Regex.run(~r/[[:digit:]]/, cur_line, capture: :first) |> List.first |> String.to_integer
        {monkey_num, Map.put(monkey_lookup, monkey_num, %Monkey{})}

      String.contains?(cur_line, "Starting items: ") ->
        item_list = cur_line |>
          String.trim_leading("Starting items: ") |>
          String.split(", ") |>
          Enum.map(& String.to_integer(&1))

        {cur_monkey, Map.update!(monkey_lookup, cur_monkey, & %{&1 | items: item_list})}

      String.contains?(cur_line, "Operation: ") ->
        op_fn = cur_line |>
          String.trim_leading("Operation: new = old ") |>
          KeepAway.op_to_fn

        {cur_monkey, Map.update!(monkey_lookup, cur_monkey, & %{&1 | op: op_fn})}

      String.contains?(cur_line, "Test: ") ->
        div_by_num = cur_line |> String.split(" ") |> List.last |> String.to_integer

        {cur_monkey, Map.update!(monkey_lookup, cur_monkey, & %{&1 | test: div_by_num})}

      String.contains?(cur_line, "If true") ->
        monkey_target = cur_line |>
          String.trim_leading("If true: throw to monkey ") |>
          String.to_integer

        {cur_monkey, Map.update!(monkey_lookup, cur_monkey, & %{&1 | pass: monkey_target})}
        
      String.contains?(cur_line, "If false") ->
        monkey_target = cur_line |>
          String.trim_leading("If false: throw to monkey ") |>
          String.to_integer

        {cur_monkey, Map.update!(monkey_lookup, cur_monkey, & %{&1 | fail: monkey_target})}
    end

    KeepAway.parse_monkeys(rest, cur_monkey, monkey_lookup)
  end


  def items_to_mod_list(monkey_lookup) do
    # get all div by vals
    div_by_map = Map.values(monkey_lookup) |> Enum.map(& &1.test) |> Enum.reduce(%{}, fn v, m -> Map.put(m, v, nil) end)

    # transform each item from a single scalar
    # to a list with an entry wrt each div test val
    monkey_lookup |>
    Enum.map(fn {id,m} ->

      new_items = m.items |>
        Enum.map(fn item ->
          Enum.reduce(Map.keys(div_by_map), %{}, fn k, item_map ->
            Map.put(item_map, k, rem(item, k))
          end)
        end)

      {id, %{m | items: new_items}}
    end) |>
    Map.new
  end


  def exec_round_p1(monkey_lookup, cur_monkey, inspect_freq) do

    if Map.has_key?(monkey_lookup, cur_monkey) do
      m = monkey_lookup[cur_monkey]

      inspect_freq = inspect_freq |> Map.update!(cur_monkey, & &1 + length(m.items))

      monkey_lookup = 
        m.items |>
        Enum.reduce(monkey_lookup, fn item, map ->
          worry = m.op.(item) |> Kernel.div(3)
          map |>
          # remove item from cur_monkey
          Map.update!(cur_monkey, & %{&1 | items: &1.items |> List.delete(item)}) |>
          # add updated item to pass/fail monkey
          Map.update!((if Kernel.rem(worry, m.test) == 0, do: m.pass, else: m.fail), & %{&1 | items: [worry] ++ &1.items})

        end)

      KeepAway.exec_round_p1(monkey_lookup, cur_monkey + 1, inspect_freq)
    else
      {monkey_lookup, inspect_freq}
    end
  end


  def exec_round_p2(monkey_lookup, cur_monkey, inspect_freq) do

    if Map.has_key?(monkey_lookup, cur_monkey) do
      m = monkey_lookup[cur_monkey]

      inspect_freq = inspect_freq |> Map.update!(cur_monkey, & &1 + length(m.items))

      monkey_lookup = 
        m.items |>
        Enum.reduce(monkey_lookup, fn item, map ->

          # update all div_test vals wrt v
          new_item = item |> Enum.map(fn {k, v} -> {k, m.op.(v) |> rem(k)} end) |> Map.new

          map |>
          # remove item from cur_monkey
          Map.update!(cur_monkey, & %{&1 | items: &1.items |> List.delete(item)}) |>
          # add updated item to pass/fail monkey
          Map.update!((if Map.get(new_item, m.test) == 0, do: m.pass, else: m.fail), & %{&1 | items: [new_item] ++ &1.items})

        end)

      KeepAway.exec_round_p2(monkey_lookup, cur_monkey + 1, inspect_freq)
    else
      {monkey_lookup, inspect_freq}
    end
  end
end




# Part 2 Thoughts:

# NOTE: all the div tests use prime numbers

# All that matters is the divisibility test,
# and the only operations are: +, *, ^2
#   for +, we could just use mod wrt each div test, updating is trivial
#   
#   for *, can't we use mod in the following way to get distances?
#   Ex:
#     div 3?: 7 * 8, (7%3) * 8
#     div 3?: 56, 8
#     div 3?: 56%3, 8%3
#     div 3?: 2, 2
#
#
#     div 4?: 7 * 7, (7%4) * 7
#     div 4?: 49, 21
#     div 4?: 49%4, 21%4
#     div 4?: 1, 1
#
#   for ^2, this is just a case of *

# So, for part 2, instead of using a single monotonically increasing scalar to represent
# items, we instead continuously apply mod to a list of numbers (each entry corresponding to a divisibility test)
# on each operation, we update each number in the relevant item's list of values.
# To check for test pass/fail:
#   check if relevant number in list is 0
# (in practice the list is a map {div_by_val -> cur_worry_val})


lines = File.read!("../input/d11.txt") |>
  String.trim_trailing |>
  String.split("\n") |>
  Enum.map(& String.trim(&1))

monkey_lookup = KeepAway.parse_monkeys(lines, nil, %{})
init_freq = Map.keys(monkey_lookup) |> Enum.reduce(%{}, & Map.put(&2, &1, 0))

# Part 1 - 20 rounds
{_, freq} = Enum.reduce(1..20, {monkey_lookup, init_freq}, fn x, {m,f} ->
  KeepAway.exec_round_p1(m, 0, f) end)


m_lookup_nonscalar = KeepAway.items_to_mod_list(monkey_lookup)

{_, freq2} = Enum.reduce(1..10_000, {m_lookup_nonscalar, init_freq}, fn x, {m,f} -> KeepAway.exec_round_p2(m, 0, f) end)


# get largest two frequencies, multiply for result
[p1_res, p2_res] = [freq, freq2] |>
  Enum.map(fn x -> (
    x |>
    Map.values |>
    Enum.map(& -&1) |>
    Enum.sort |>
    Enum.slice(0..1) |>
    Enum.reduce(& &1 * &2)
  ) end)


IO.puts("Part 1: #{p1_res}")
IO.puts("Part 1: #{p2_res}")

