defmodule Grove do
  def zero_to_start(nums) do
    zero_idx = Enum.find_index(nums, &(&1 == 0))

    Enum.slice(nums, zero_idx..(length(nums) - 1)) ++ Enum.slice(nums, 0..(zero_idx - 1))
  end

  def mix(zero_dists, iter_num \\ 0)

  def mix(zero_dists, iter_num) when iter_num == length(zero_dists) do
    zero_dists
  end

  def mix(zero_dists, iter_num) do
    # Find next num by looking for num with orig_idx == iter_num
    # find and find_index together
    {c_num, orig_num_idx, c_num_idx} =
      zero_dists
      |> Enum.reduce_while(0, fn {num, num_idx}, cur_idx ->
        if num_idx == iter_num do
          {:halt, {num, num_idx, cur_idx}}
        else
          {:cont, cur_idx + 1}
        end
      end)

    # mod len-1, since we are shifting over list with elem removed
    # if is negative, then we are wrapping backwards,
    # elixir's negative indexing means insert(-1) will insert at the very end,
    # so decr by 1
    new_idx_pos = rem(c_num_idx + c_num, length(zero_dists) - 1)
    new_idx_pos = if new_idx_pos < 0, do: length(zero_dists) + new_idx_pos - 1, else: new_idx_pos

    zero_dists =
      List.insert_at(zero_dists |> List.delete_at(c_num_idx), new_idx_pos, {c_num, orig_num_idx})

    Grove.mix(zero_dists, iter_num + 1)
  end

  def sol(zero_dists) do
    targets = [1_000, 2_000, 3_000]

    targets
    |> Enum.map(fn target ->
      target = rem(target, length(zero_dists))

      Enum.at(zero_dists, target)
    end)
  end
end

defmodule D20 do
  def sol(input) do
    nums =
      input
      |> String.split("\n")
      |> Enum.map(&String.to_integer/1)

    # NOTE/ASSUMPTION: only one 0 value in list

    res_p1 =
      nums
      |> Enum.with_index()
      |> Grove.mix()
      |> Enum.map(&elem(&1, 0))
      |> Grove.zero_to_start()
      |> Grove.sol()
      |> Enum.sum()

    with_orig_order =
      nums
      |> Enum.map(&(&1 * 811_589_153))
      |> Enum.with_index()

    res_p2 =
      Enum.reduce(0..9, with_orig_order, fn _, ordered -> Grove.mix(ordered) end)
      |> Enum.map(&elem(&1, 0))
      |> Grove.zero_to_start()
      |> Grove.sol()
      |> Enum.sum()

    IO.inspect(res_p1, label: "Part 1")
    IO.inspect(res_p2, label: "Part 2")
  end
end
