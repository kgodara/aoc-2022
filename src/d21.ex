
defmodule MonkeyOp do
  defstruct [:label, :type, :res, :l_label, :r_label]

  def resolve(%MonkeyOp{} = monkey_op, lookups) do
    case monkey_op.type do
      :literal -> monkey_op.res
      _ ->
        l  = Map.get(lookups, monkey_op.l_label)
        r  = Map.get(lookups, monkey_op.r_label)

        if is_nil(l) or is_nil(r) do
          nil
        else
          case monkey_op.type do
            :add ->
              l + r
            :sub ->
              l - r
            :mul ->
              l * r
            :div ->
              # NOTE: Assuming integer divisions for everything
              if rem(l, r) != 0 do
                raise "Division will truncate!"
              end
              div(l, r)
          end
        end
    end
  end
end


defmodule Monkey do
  def parse(input) do
    lines_seq = input |>
      String.trim_trailing |>
      String.split("\n") |>
      Enum.reverse

      lines_seq |>
      Enum.map(fn line ->
        parts = String.split(line, " ")
        case length(parts) do
          2 ->
            [label, lit] = parts
            %MonkeyOp{ label: label |> String.trim_trailing(":"), type: :literal, res: lit |> String.to_integer}
          4 ->
            [label, l, op, r] = parts

            op = case op do
              "+" -> :add
              "-" -> :sub
              "*" -> :mul
              "/" -> :div
            end

            %MonkeyOp{ label: label |> String.trim_trailing(":"), type: op, l_label: l, r_label: r, res: nil}
          _ -> raise "Invalid input"
        end
      end)
  end
  def exec(monkeys_ordered, monkeys_resolved \\ %{})

  def exec([], monkeys_resolved) do
    monkeys_resolved |> Map.get("root")
  end

  def exec(unresolved_monkeys, monkeys_resolved) do

    # Use a BFS type approach, scan remaining unsolved monkeys each iter

    # add all with not is_nil(m.res) to monkeys_resolved
    # + to 'newly_resolved map'
    # for every m in unresolved, update res based on resolved
    {still_unresolved, now_resolved} =
      unresolved_monkeys |>
      Enum.split_with(& is_nil(&1.res))

    monkeys_resolved =
      now_resolved |>
      Enum.reduce(monkeys_resolved, fn m, acc -> Map.put(acc, m.label, m.res) end)

    # for every m in unresolved, update res based on resolved
    still_unresolved =
      still_unresolved |>
      Enum.map(fn m ->
        case MonkeyOp.resolve(m, monkeys_resolved) do
          nil ->  m
          v -> %MonkeyOp{m | res: v}
        end
      end)

    Monkey.exec(still_unresolved, monkeys_resolved)
  end


  def exec2(unresolved, resolved, unresolvable) do

    start_unresolved = unresolved |> length

    merge_mapset_list = & (MapSet.union(&1, MapSet.new(&2 |> Enum.map(fn m -> m.label end))))

    # Use a BFS type approach, scan remaining unsolved monkeys each iter

    # add all with not is_nil(m.res) to monkeys_resolved
    # + to 'newly_resolved map'
    # for every m in unresolved, update res based on resolved
    {unresolved, resolved_list} =
      unresolved |>
      Enum.split_with(& is_nil(&1.res))

    {unresolved, unresolvable_list} =
      unresolved |>
      Enum.split_with(fn m ->
        case m.type do
          :literal -> true
          _ ->
            not MapSet.member?(unresolvable, m.l_label) or MapSet.member?(unresolvable, m.r_label)
        end
      end)

    unresolvable = merge_mapset_list.(unresolvable, unresolvable_list)

    resolved =
      resolved_list |>
      Enum.reduce(resolved, fn m, acc -> Map.put(acc, m.label, m.res) end)


    # for every m in unresolved, update res based on resolved
    unresolved =
      unresolved |>
      Enum.map(fn m ->
        case MonkeyOp.resolve(m, resolved) do
          nil ->  m
          v -> %MonkeyOp{m | res: v}
        end
      end)

    if start_unresolved != length(unresolved) do
      Monkey.exec2(unresolved, resolved, unresolvable)
    else
      resolved
    end
  end

  def resolve_from_root(%MonkeyOp{ label: "humn" } = _, _, target_val) do
    target_val
  end

  def resolve_from_root(%MonkeyOp{ type: :literal } = _, _, _) do
    raise "Can't traverse down literal node"
  end

  # Resolve cur_op and move to unresolved child
  def resolve_from_root(cur_op, {ops, resolved}, target_val) do

    l_val = Map.get(resolved, cur_op.l_label)
    r_val = Map.get(resolved, cur_op.r_label)

    # Resolve what the missing val needs to be
    {n_l_val, n_r_val} = case {l_val, r_val} do
      {l_val, nil} when not is_nil(l_val) ->
        case cur_op.type do
          :add -> {l_val, target_val - l_val}
          :sub -> {l_val, l_val - target_val}
          :mul ->
            # 3 * 8 = 24
            # l_val = 3, target_val = 24
            # target_val / l_val
            if rem(target_val, l_val) != 0 do
              raise "Division will truncate!"
            end
            {l_val, div(target_val, l_val)}
          :div ->
            # 24 / 3 = 8
            # l_val = 24, target_val = 8
            # l_val / target_val
            if rem(l_val, target_val) != 0 do
              raise "Division will truncate!"
            end
            {l_val, div(l_val, target_val)}
          end
      {nil, r_val} when not is_nil(r_val) ->
        case cur_op.type do
          :add ->
            {target_val - r_val, r_val}
          :sub ->
            {target_val + r_val, r_val}
          :mul ->
            # 3 * 8 = 24
            # r_val = 8, target_val = 24
            # target_val / r_val
            if rem(target_val, r_val) != 0 do
              raise "Division will truncate!"
            end
            {div(target_val, r_val), r_val}
          :div ->
            # 24 / 3 = 8
            # r_val = 3, target_val = 8
            # r_val * target_val
            {r_val * target_val, r_val}
          end
      {nil, nil} -> raise "Both children are undefined"
    end

    case {l_val, r_val} do
      {nil, _} ->
        resolved = resolved |>
          Map.put(cur_op.l_label, n_l_val)

        Monkey.resolve_from_root(Map.get(ops, cur_op.l_label), {ops, resolved}, n_l_val)

        {_, nil} ->
          resolved = resolved |>
            Map.put(cur_op.r_label, n_r_val)

        Monkey.resolve_from_root(Map.get(ops, cur_op.r_label), {ops, resolved}, n_r_val)
    end
  end
end


defmodule Main do
  def main() do

    ops = Monkey.parse(File.read!("../input/d21.txt"))

    p1_res = Monkey.exec(ops)

    # Part 2
    ops_filtered =
      ops |>
      Enum.filter(& &1.label != "humn")

    resolved = Monkey.exec2(ops_filtered, %{}, MapSet.new(["humn"]))

    root = ops |> Enum.find(& &1.label == "root")

    ops_map = ops |>
      Enum.map(& {&1.label, &1}) |>
      Map.new

    {start_label, target_val} =
      case {Map.get(resolved, root.l_label), Map.get(resolved, root.r_label)} do
        {nil, r} -> {root.l_label, r}
        {l, nil} -> {root.r_label, l}
        _ -> raise "Root has no children with definite values"
      end

    p2_res = Monkey.resolve_from_root(Map.get(ops_map, start_label), {ops_map, resolved}, target_val)

    IO.inspect(p1_res, label: "p1_res")
    IO.inspect(p2_res, label: "p2_res")
  end
end


Main.main()
