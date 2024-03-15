defmodule Stacks do
  def update_stacks_from_line("", stacks, _stack_idx) do
    stacks
  end

  def update_stacks_from_line(data, stacks, stack_idx) do
    <<_, _, val, _, rest::binary>> = data

    dst_stack = stacks[stack_idx]

    # add value to stack if element is present
    updated_stack = if val != ?\s, do: [val] ++ dst_stack, else: dst_stack

    update_stacks_from_line(rest, Map.put(stacks, stack_idx, updated_stack), stack_idx + 1)
  end

  def populate_stacks(lines, empty_stacks, stack_count) do
    # add a space at the start of stack lines so that
    # can parse in batches of 4 bytes: '_[X]'
    lines
    |> Enum.slice(0..(stack_count - 1))
    |> Enum.map(&(" " <> &1))
    |> Enum.reduce(empty_stacks, fn line, accum ->
      Stacks.update_stacks_from_line(line, accum, 0)
    end)
  end

  def exec_move_p1(line, stacks) do
    # parse args from move cmd text
    # [1,3,5] --> indexes of move command parameters in tokenized str
    [amt, src, dst] =
      line
      |> String.split(" ", trim: true)
      |> Enum.with_index()
      |> Enum.filter(&(elem(&1, 1) in [1, 3, 5]))
      |> Enum.map(&(elem(&1, 0) |> String.to_integer()))

    # transfer 'amt' elements src -> dst, will naturally reverse
    {src_stack, dst_stack} =
      Enum.reduce(0..(amt - 1), {stacks[src - 1], stacks[dst - 1]}, fn _i, {src_s, dst_s} ->
        {ele, new_src} = List.pop_at(src_s, 0)
        new_dst = List.insert_at(dst_s, 0, ele)
        {new_src, new_dst}
      end)

    # return 'stacks' with updates src/dst stacks
    stacks
    |> Map.put(src - 1, src_stack)
    |> Map.put(dst - 1, dst_stack)
  end

  def exec_move_p2(line, stacks) do
    # parse args from move cmd text
    # [1,3,5] --> indexes of move command parameters in tokenized str
    [amt, src, dst] =
      line
      |> String.split(" ", trim: true)
      |> Enum.with_index()
      |> Enum.filter(&(elem(&1, 1) in [1, 3, 5]))
      |> Enum.map(&(elem(&1, 0) |> String.to_integer()))

    # move 'amt' elements out of src_stack
    {picked_elems, src_stack} =
      Enum.reduce(0..(amt - 1), {[], stacks[src - 1]}, fn _i, {data, src_s} ->
        {ele, src_new} = List.pop_at(src_s, 0)

        # time complexity of '++' is len(right operand) better to reverse once after
        {[ele] ++ data, src_new}
      end)

    dst_stack = Enum.reverse(picked_elems) ++ stacks[dst - 1]

    # return 'stacks' with updated src/dst stacks
    stacks
    |> Map.put(src - 1, src_stack)
    |> Map.put(dst - 1, dst_stack)
  end
end

defmodule D5 do
  def sol(input) do
    lines = input |> String.split("\n")

    # Parse Stack elements - Approaches:
    #   1. 2D List, iterate line by line and modify each list in 'empty_stacks' appropriately
    #     Have to get each stack, modify, then update stacks
    #   2. Get index of value (on line) for each stack, populate each stack individually
    #     Don't like because accessing EACH char requires iterating over 0..idx elems
    #   3. Map of lists, saves from having to iterate over stacks to find relevant stack
    #       Let's try this

    # get number of stacks, each stack comes in the form: ' [X]'
    stack_count =
      (" " <> Enum.at(lines, 0))
      |> String.length()
      |> div(4)

    # init stacks based on number of columns
    empty_stacks =
      Enum.map(0..(stack_count - 1), &{&1, []})
      |> Map.new()

    # parse and populate stacks then
    # reverse stacks so top element is at index 0
    pop_stacks =
      Stacks.populate_stacks(lines, empty_stacks, stack_count)
      |> Map.new(fn {key, val} -> {key, Enum.reverse(val)} end)

    # Parse move commands
    lines = Enum.filter(lines, &String.contains?(&1, "move"))

    # move elements according to move commands
    moved_p1 =
      Enum.reduce(lines, pop_stacks, fn line, accum -> Stacks.exec_move_p1(line, accum) end)

    moved_p2 =
      Enum.reduce(lines, pop_stacks, fn line, accum -> Stacks.exec_move_p2(line, accum) end)

    # get top element of each stack
    res_p1 = Enum.map(0..(stack_count - 1), &List.first(moved_p1[&1]))
    res_p2 = Enum.map(0..(stack_count - 1), &List.first(moved_p2[&1]))

    IO.puts("Part 1: #{res_p1}")
    IO.puts("Part 2: #{res_p2}")
  end
end
