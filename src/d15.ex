
defmodule Sensor do
  defstruct [:sensor, :b_dist, :range]
end

defmodule PivotRange do
  defstruct [:range, :pivot]
end

defmodule BeaconExclusion do

  def parse(lines) do
    # "x=2, y=18"
    # Sensor at x=2, y=18: closest beacon is at x=-2, y=15
    lines |>
    Enum.map(& Regex.named_captures(~r/.*x=(?<s_x>-?[0-9]+), y=(?<s_y>-?[0-9]+).*x=(?<b_x>-?[0-9]+), y=(?<b_y>-?[0-9]+)/, &1)) |>
    Enum.reduce({[], []}, fn captures, {sensors, beacons} ->
      [s_x, s_y, b_x, b_y] =
        [captures["s_x"], captures["s_y"], captures["b_x"], captures["b_y"]] |>
        Enum.map(& String.to_integer(&1))

        s = %Sensor{ sensor: {s_x, s_y}, b_dist: abs(s_x - b_x) + abs(s_y - b_y)}
      { [s | sensors], [{b_x, b_y} | beacons] }
    end)
  end

  def init_pivot_range(row_y, sensor) do

    {s_x, s_y} = sensor.sensor

    # get straight-line distance to row
    row_dist = abs(s_y - row_y)

    # get bounds on both sides where manhattan distance
    remaining_steps = sensor.b_dist - row_dist
    %PivotRange{range: (s_x - remaining_steps)..(s_x + remaining_steps), pivot: elem(sensor.sensor,1)}
  end

  def iter_pivot_range(row_y, sensor) do

    y_pivot = sensor.pivot

    prev_range = sensor.range

    # we are getting closer to sensor -->
    # dist to get to row_y is decreasing -->
    # more leftover steps in budget of 'nearest_dist' -->
    # range expands

    incr = if row_y <= y_pivot, do: 1, else: -1
    n_range = (prev_range.first - incr)..(prev_range.last + incr)
    n_range = if n_range.step < 0, do: nil, else: n_range

    %PivotRange{sensor | range: n_range}
  end

  def clip_pivot_ranges(pivot_ranges, lower_bound, upper_bound) do
    pivot_ranges |>
    Enum.map(fn p_r ->
      r = p_r.range
      %PivotRange{ p_r | range: max(r.first, lower_bound)..min(r.last, upper_bound) }
    end) |>
    Enum.filter(fn p_r ->
      p_r.range.first <= p_r.range.last
    end)
  end

  def sort_pivot_ranges(ranges) do
    ranges |>
    Enum.sort(& (&1.range.first < &2.range.first) or (&1.range.first == &2.range.first and &1.range.last < &2.range.last))
  end

  def activate_sensors(row_y, sensors) do
    {active, inactive} =
      sensors |>
      Enum.split_with(
      fn sensor ->
        {_s_x, s_y} = sensor.sensor
        # can sensor reach row to invalidate anything in it
        abs(s_y - row_y) <= sensor.b_dist
      end)

    active =
      active |>
      Enum.map(& BeaconExclusion.init_pivot_range(row_y, &1))

    {active, inactive}
  end

  def merge_pivot_ranges(rem, merged) when length(rem) < 2 do
    # reverse for left-right coordinate ordering (not necessary)
    rem ++ merged |>
    Enum.reverse
  end

  def merge_pivot_ranges([cur | rem], merged) do

    [next | trunc_rem] = rem

    [cur_r, next_r] = [cur.range, next.range]

    {rem, merged} = cond do
      # cur is redundant, let it be discarded
      cur_r.first == next_r.first ->
        {rem, merged}

      # cur & next overlap, merge cur and next
      cur_r.last >= next_r.first ->
        {[%PivotRange{pivot: nil, range: cur_r.first..max(cur_r.last, next_r.last)} | trunc_rem], merged}

      # cur & next DO NOT overlap, add cur to merged
      cur_r.last < next_r.first ->
        # prepending > appending
        {rem, [cur | merged]}
    end

    BeaconExclusion.merge_pivot_ranges(rem, merged)

  end
end



defmodule Main do
  def main() do

    file_str = "../input/d15.txt"

    lines = File.read!(file_str) |>
      String.trim_trailing |>
      String.split("\n", trim: true)

    {sensors, beacons} = BeaconExclusion.parse(lines)

    exclude_row = if String.contains?(file_str, "d15_ex"), do: 20, else: 2_000_000

    lower_bound = 0
    upper_bound = if String.contains?(file_str, "d15_ex"), do: 20, else: 4_000_000

    # Faster Approach:
    # Instead of calculating ranges for each sensor for each row independently,
    # modify each sensor's range bounds depending on if the manhattan distance
    # (which is only changing due to vertical increments)
    # is moving closer/further away from the beacon.
    # NOTE: This will have to use unclipped ranges.

    # Q: But, sorting & merging ranges is the bottleneck? Does this improve that?
    # A: Well, if we re-use sorted ranges list then next sort should have, on average,
    #    less swaps to perform.

    # Q: Can we improve merge range step?

    # Part 1
    ranges =
      sensors |>
      Enum.map(fn sensor ->
        BeaconExclusion.init_pivot_range(exclude_row, sensor)
      end) |>
      Enum.filter(& &1.range.step >= 0)

    merged_ranges =
      ranges |>
      BeaconExclusion.sort_pivot_ranges |>
      BeaconExclusion.merge_pivot_ranges([])

    beacon_excludes =
      beacons |>
      Enum.filter(& elem(&1, 1) == exclude_row) |>
      Enum.map(& elem(&1, 0)) |>
      Enum.reduce([], & [&1 | &2]) |>
      MapSet.new

    num_spots =
      merged_ranges |>
      Enum.map(& &1.range) |>
      Enum.reduce(0, & (&1.last - &1.first) + 1 + &2)

    p1_res = num_spots - MapSet.size(beacon_excludes)



    # Part 2
    p2_res = Enum.reduce(lower_bound..upper_bound, {[], sensors, nil},
    fn cur_row, {prev_active, prev_inactive, res} ->

      if res != nil do
        {nil, nil, res}
      else

        # check which sensors are now active (can reach cur_row before its beacon), update 'inactive'
        # init ranges for activated sensors
        {activated, inactive} = BeaconExclusion.activate_sensors(cur_row, prev_inactive)

        # update active sensor ranges & filter used-up sensors (out of range for good)
        active =
          prev_active |>
          Enum.map(& BeaconExclusion.iter_pivot_range(cur_row, &1)) |>
          Enum.filter(& &1.range != nil)

        # combine all now-active sensors + sort
        active = BeaconExclusion.sort_pivot_ranges(activated ++ active)

        merged_ranges =
          active |>
          BeaconExclusion.merge_pivot_ranges([]) |>
          BeaconExclusion.clip_pivot_ranges(lower_bound, upper_bound)

        num_spots =
          merged_ranges |>
          Enum.map(& &1.range) |>
          Enum.reduce(0, & (&1.last - &1.first) + 1 + &2)

        {
          active,
          inactive,
          (if num_spots == upper_bound, do: {cur_row, merged_ranges}, else: res)
        }

      end
    end) |>
    elem(2)



    {p2_res_row, p2_res_ranges} = p2_res
    p2_res_ranges = p2_res_ranges |> Enum.map(& &1.range)

    # handle beacon at edges
    p2_res_col = if length(p2_res_ranges) > 1 do
      [_, p2_right] = p2_res_ranges
      p2_right.first - 1
    else
      [p2_center] = p2_res_ranges
      if p2_center.first > 0 do
        0
      else
        p2_center.last+1
      end
    end

    p2_res = (p2_res_col * 4000000) + p2_res_row

    IO.inspect(p1_res, label: "Part 1")
    IO.inspect(p2_res, label: "Part 2")

  end
end


Main.main()
