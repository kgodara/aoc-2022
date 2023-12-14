defmodule Node do
  defstruct [:id, :x, :y]
end


defmodule Cave do

  def parse_nodes(lines) do

    rock_structs =
      lines |>
      Enum.map(fn line ->
        line |>
        String.split(" -> ") |>
        Enum.map(fn coord_pair ->
          String.split(coord_pair, ",") |> Enum.map(& String.to_integer(&1))
        end)
      end)

    all_coords =
      rock_structs |>
      Enum.map(fn rock_struct ->
        path_segments = rock_struct |>
          Enum.chunk_every(2, 1, :discard)

        struct_coords =
          path_segments |>
          Enum.map(fn path_segment ->
            [[x1,y1],[x2,y2]] = path_segment

            is_horizontal = x1 == x2

            points = abs((x1 - x2) + (y1 - y2))

            # Create node for every point on path segment
            segment_coords = Enum.reduce((if is_horizontal, do: y1..y2, else: x1..x2), [], fn point_idx, coord_list ->
              [x_coord, y_coord] = if is_horizontal, do: [x1, point_idx], else: [point_idx, y1]
              coord_list ++ [ {x_coord, y_coord} ]
            end)
          end) |>
          List.flatten

        struct_coords
      end) |>
      List.flatten


    {coord_id_lookup, id_node_lookup} =
      all_coords |>
      Enum.reduce({Map.new(), Map.new()}, fn coord, {coord_id_lookup, id_node_lookup} ->
        Cave.add_node(coord_id_lookup, id_node_lookup, coord)
      end)

    {coord_id_lookup, id_node_lookup}
  end

  def get_next_impacted_node_id(coord_id_lookup, x, upper_bound, lowest_node_height) when upper_bound > lowest_node_height do
    :abyss
  end

  # upper_bound should be: parent's y + 1 (inclusive)
  def get_next_impacted_node_id(coord_id_lookup, x, upper_bound, lowest_node_height) do
    case Map.get(coord_id_lookup, {x, upper_bound}) do
      impacted_node_id when not(is_nil(impacted_node_id)) -> impacted_node_id
      nil -> Cave.get_next_impacted_node_id(coord_id_lookup, x, upper_bound+1, lowest_node_height)
    end
  end

  # Return new node from dropped sand or nil if dropped into abyss
  def drop_sand(coord_id_lookup, id_node_lookup, x, upper_bound, lowest_node_height) do

    impacted_node = id_node_lookup |> Map.get(Cave.get_next_impacted_node_id(coord_id_lookup, x, upper_bound, lowest_node_height))

    # calc_left impact
    # if no left impact: calc_right impact
    # if no left impact AND no right impact, return 'impacted node'
    case impacted_node do
      nil -> :abyss
      impacted_node ->
        left_impact = case Map.has_key?(coord_id_lookup, {x-1, impacted_node.y}) do
          false -> Cave.drop_sand(coord_id_lookup, id_node_lookup, x-1, impacted_node.y+1, lowest_node_height)
          true -> :blocked
        end

        case left_impact do
          :blocked ->
            right_impact = case Map.has_key?(coord_id_lookup, {x+1, impacted_node.y}) do
              false -> Cave.drop_sand(coord_id_lookup, id_node_lookup, x+1, impacted_node.y+1, lowest_node_height)
              true -> :blocked
            end

            case right_impact do
              :blocked ->
                %{impacted_node | y: impacted_node.y-1}
              :abyss ->
                :abyss
              _ ->
                right_impact
            end
          :abyss ->
            :abyss
          _ ->
            left_impact
        end
    end
  end


  def add_node(coord_id_lookup, id_node_lookup, coords) do
    new_id = map_size(coord_id_lookup)
    {new_x, new_y} = coords

    coord_id_lookup = Map.put_new(coord_id_lookup, {new_x, new_y}, new_id)
    id_node_lookup = Map.put(id_node_lookup, new_id, %Node{id: new_id, x: new_x, y: new_y})

    {coord_id_lookup, id_node_lookup}
  end


  def add_floor_nodes(coord_id_lookup, id_node_lookup, lowest_node_height) do
    floor_y = lowest_node_height + 2

    # Increase floor_side_len by 1 so that nodes don't think that they can fall into the abyss
    floor_side_len = ((lowest_node_height + 2) - 1) + 1

    # add center floor node
    {coord_id_lookup, id_node_lookup} = Cave.add_node(coord_id_lookup, id_node_lookup, {500, floor_y})

    (500-floor_side_len)..(500+floor_side_len) |>
    Enum.reduce({coord_id_lookup, id_node_lookup},
      fn floor_x, {coord_id_lookup, id_node_lookup} ->
        Cave.add_node(coord_id_lookup, id_node_lookup, {floor_x, floor_y})
      end)
  end

  def drop_until_abyss(coord_id_lookup, id_node_lookup, x, upper_bound, lowest_node_height, num_iter) do

    case Cave.drop_sand(coord_id_lookup, id_node_lookup, x, upper_bound, lowest_node_height) do
      nil -> num_iter
      :abyss -> num_iter
      dropped_sand when dropped_sand.x == 500 and dropped_sand.y == 0 -> num_iter + 1
      dropped_sand ->
        new_id = map_size(coord_id_lookup)
        {coord_id_lookup, id_node_lookup} = Cave.add_node(coord_id_lookup, id_node_lookup, {dropped_sand.x, dropped_sand.y})
        #IO.inspect(Map.get(id_node_lookup, new_id), label: "Sand Dropped")
        #IO.write("\n")
        Cave.drop_until_abyss(coord_id_lookup, id_node_lookup, x, upper_bound, lowest_node_height, num_iter+1)
    end
  end
end

# Things that would be useful:
#   1. Find highest rock in given column below certain point
#     bottom for sand + sand going to abyss
#   2. Check whether coordinates are occupied (sand changing column)
#   3.

# Idea 1:
# Use 2D grid, check min/max of input to determine bounds
# Simple to impl, higher time-complexity

# Idea 2:
# Sort ranges by x-coord then y-coord -->
#   Instead of doing this and having to iterate over all ranges (worst-case) for every block of sand,
#   --> Idea 3

# Idea 3:
# Use a binary search tree, since each unit of sand either stays / goes left|right
# Challenge of BST: Need to replace sub-tree when sand comes to rest on rock



# Seems like may be best if we just have nodes keep track of their children via some id,
# rather than directly using nested lists, since will routinely be dropping / replacing lists otherwise
# QUESTION: How would be update the parents of a node on new sand coming to rest?
# ANSWER: Add parent tracking for all nodes?

# NOTE: A node represents an empty space ABOVE a block, not the block itself

# ON: Sand coming to rest:
#   NEW NODE has 0-2 children,
#     ARE ANY CHILDREN ALWAYS JUST ONE DIAGONAL AWAY? --> YES
#     We can't "inherit" children from newly-covered node since if it had children we would've traversed them
#     So, any new children must be one diagonal away (created by new block placement)

# NOTE: Wouldn't it be nice to have a map for x -> sorted list of nodes by descending height
# since

# Idea 4:
#   Challenge with BST init approach:
#   Rock struct may contain trees not initially linked to main tree, which will become linked by sand at rest
#   AKA, need to init sub-trees
#   Alternate approach: Traverse and find the next spot from the start every time


# If so, will need to explicitly maintain head (highest block in column 500)

# Also, each node can have 0-2 parents, e.g:
#     # #
#      #
# BUT: there's only one path for the sand to ever reach a given point, so in practice each node only has one parent

defmodule Main do
  def main() do

    lines = File.read!("../input/d14.txt") |>
      String.trim_trailing |>
      String.split("\n", trim: true)

    {coord_id_lookup, id_node_lookup} = Cave.parse_nodes(lines)

    lowest_node_height = (id_node_lookup |>
      Enum.max_by(fn {_id, node} -> node.y end) |>
      elem(1)).y

    IO.inspect(map_size(coord_id_lookup), label: "coord_id pairs")

    IO.inspect(Cave.drop_until_abyss(coord_id_lookup, id_node_lookup, 500, 0, lowest_node_height, 0), label: "Part 1: ")


    {coord_id_lookup, id_node_lookup} = Cave.add_floor_nodes(coord_id_lookup, id_node_lookup, lowest_node_height)
    lowest_node_height = (id_node_lookup |>
      Enum.max_by(fn {_id, node} -> node.y end) |>
      elem(1)).y

    IO.inspect(Cave.drop_until_abyss(coord_id_lookup, id_node_lookup, 500, 0, lowest_node_height, 0), label: "Part 2: ")
  end
end

Main.main()
