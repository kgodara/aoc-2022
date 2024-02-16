defmodule Lava do

  @lower_bound 0
  @upper_bound 20

  @sides_list [
    [-1,0,0],
    [1,0,0],

    [0,-1,0],
    [0,1,0],

    [0,0,-1],
    [0,0,1]
  ]

  def parse(lines) do
    lines |>
    Enum.map(fn line ->
      line |>
      String.split(",") |>
      Enum.map(& String.to_integer/1)
    end)
  end

  # Return a map of all sides (represented as the coordinates
  # of a cube that would be adjacent to an existing side).
  # Ex: Cube [1,1,1], represent the top of the cube as [1,2,1]
  def enumerate_all_sides(cubes) do

    side_freqs = %{}

    cubes |>
    Enum.reduce(side_freqs, fn [x,y,z],map ->
      Enum.reduce([
        [x-1,y,z],
        [x+1,y,z],
        [x,y-1,z],
        [x,y+1,z],
        [x,y,z-1],
        [x,y,z+1]
      ], map, fn k,m -> Map.update(m, k, 1, & &1 + 1) end)
    end)
  end

  def dfs_to_freedom([x,y,z], _, seen_set, _) when (
    (x < @lower_bound or x > @upper_bound) or
    (y < @lower_bound or y > @upper_bound) or
    (z < @lower_bound or z > @upper_bound)
  ) do
    {true, seen_set}
  end

  # Doing DFS since should be better to escape coord bounds than BFS
  # which will waste a lot of time when already free
  def dfs_to_freedom(cube, cube_set, seen_set, free_set) do
    [x,y,z] = cube

    # seen_set needs to include all cubes this round of DFS will
    # investigate so downstream doesn't loop back

    if MapSet.member?(free_set, cube) do
      {true, seen_set}
    else
      adj_list = @sides_list |>
      Enum.map(fn [x_delta,y_delta,z_delta] -> [x+x_delta, y+y_delta, z+z_delta] end)

      updated_set = adj_list |>
        Enum.reduce(seen_set, fn n_cube,acc -> MapSet.put(acc, n_cube) end)

      adj_list |>
      Enum.filter(& not(MapSet.member?(cube_set, &1)) and not(MapSet.member?(seen_set, &1))) |>
      Enum.reduce_while({false, updated_set}, fn n_cube,{_,cur_set} ->
        {is_free?, cur_set} = Lava.dfs_to_freedom(n_cube, cube_set, cur_set, free_set)
        if is_free? == true do
          {:halt, {true, cur_set}}
        else
          {:cont, {false, cur_set}}
        end
      end)
    end
  end
end

# Sorting along each axis and checking for cases such as
# (assuming X is sorted): [1,2,2], [2,2,2]
# doesn't work because of cases like: [1,2,2], [1,3,2], [2,2,2]

# Easier if we bucket by sorted-axis key, then take buckets that are 1 unit apart
# and iterate two pointers looking for overlaps

# NOTE: coordinate values don't seem to go > 20, good for buckets

# Part 2:
#   In part 1 we get all overlapping sides,
#   let's remove these from the set of all sides to get the
#   set of non-overlapping sides. These just need to find a path beyond
#   the min/max of any axis to be definitely not-trapped.
#
#  2801*6 = 16,806 sides,
#  16,806 - 2*(2066+2084+2068) = 4,370 sides to consider
#
# Run DFS on each side to see if we can escape?
# Can memoize for perf if needed
#
# NOTE: multiple exposed sides can lead to a single DFS / path,
#   should attach "weight" to each DFS query to indicate how many sides it resolves

defmodule Main do
  def main() do

    lines = File.read!("../input/d18.txt") |>
      String.trim_trailing |>
      String.split("\n")

    cubes = Lava.parse(lines)

    all_sides = Lava.enumerate_all_sides(cubes)

    cube_set = cubes |> MapSet.new

    exposed_sides = all_sides |>
      Enum.filter(fn {coord, _freq} -> not MapSet.member?(cube_set, coord) end)

    num_exposed_sides = exposed_sides |>
    Enum.reduce(0, fn {_coord,freq},sum -> freq+sum end)


    {_memoized, res_list} =
      exposed_sides |>
      # memoizing set, + list of {is_free?,freq} pairs
      Enum.reduce({MapSet.new,[]}, fn {cube, freq},{free_set_acc, res} ->
        {is_free?, free_set} = Lava.dfs_to_freedom(cube, cube_set, MapSet.new, free_set_acc)

        {
          (if is_free? == true, do: MapSet.union(free_set_acc, free_set), else: free_set_acc),
          [{is_free?, freq}] ++ res
        }
      end)

    external_exposed =
      res_list |>
      Enum.filter( fn {free, _freq} -> free == true end) |>
      Enum.reduce(0, fn {_free, freq},sum -> sum + freq end)

    IO.inspect(num_exposed_sides, label: "Part 1")
    IO.inspect(external_exposed, label: "Part 2")
  end
end

Main.main()
