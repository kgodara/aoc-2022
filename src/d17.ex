
# ROCKS:
_="""
####    -- Dash

.#.
###     -- Plus
.#.

..#
..#     -- L
###

#
#
#       -- Pillar
#

##
##      -- Square
"""

defmodule Rock do
  defstruct [:type, :point_coords, :left, :right, :bottom]
end

# Stateful jet stream which cycles over jet sequence
defmodule JetStream do
  defstruct [:stack, :cycle, :seq_len]

  def init(line) do

    jet_seq = Tetris.parse(line)
    jet_cycle = Stream.cycle(jet_seq)
    jet_seq_len = length(jet_seq)

    %JetStream {
      stack: Enum.take(jet_cycle, jet_seq_len),
      cycle: jet_cycle,
      seq_len: jet_seq_len,
    }
  end

  def next(%JetStream{stack: []} = stream) do
    JetStream.next(
      %JetStream { stream | stack: Enum.take(stream.cycle, stream.seq_len) }
    )
  end

  def next(%JetStream{} = stream) do
    [jet | n_stack] = stream.stack
    {
      jet,
      %JetStream { stream | stack: n_stack }
    }
  end
end

defmodule Tower do
  defstruct [:cols, :top, :freqs, :dropped]
end

defmodule Tetris do
  # How to represent these rocks?
  # With bottom edge / left edge coords?
  #   NO, this doesn't work because for 'L' shape depending on where left edge vertically may/may not be able to move
  # Thought: Check all points with nothing below + all points with nothing on left/right,
  # but these rocks basically have no insignificant points so just check them all.
  # Can we just represent a rock as a set of relative deltas starting from their top-leftmost point,
  # alongside an offset for global position

  @rock_fall_seq [:dash, :plus, :L, :pillar, :square]

  @cycle_start_col_sum 74
  @rocks_per_cycle 1_705
  @height_per_cycle 2_582

  @dash_left [0]
  @dash_right [3]
  @dash_bottom [0,1,2,3]

  @plus_left [0,1,4]
  @plus_right [0,3,4]
  @plus_bottom [1,3,4]

  @l_left [0,1,2]
  @l_right [0,1,4]
  @l_bottom [2,3,4]


  @pillar_left [0,1,2,3]
  @pillar_right [0,1,2,3]
  @pillar_bottom [3]


  @square_left [0,2]
  @square_right [1,3]
  @square_bottom [2,3]


  def spawn_rock(type, topmost) do

    # Each rock appears so that its left edge is two units away from the left wall
    # and its bottom edge is three units above the highest rock in the room
    # (or the floor, if there isn't one).

    #IO.inspect(topmost, label: "topmost")

    left_coord = 2
    bottom_offset = 4

    bottom_edge = topmost + bottom_offset

    case type do
      :dash ->
        global_coords = [
          {left_coord,   bottom_edge},
          {left_coord+1, bottom_edge},
          {left_coord+2, bottom_edge},
          {left_coord+3, bottom_edge}
        ]
        %Rock{ type: :dash, point_coords: global_coords }

      :plus ->
        global_coords = [
          {left_coord+1, bottom_edge + 2},

          {left_coord, bottom_edge + 1},
          {left_coord+1, bottom_edge + 1},
          {left_coord+2, bottom_edge + 1},

          {left_coord+1, bottom_edge}
        ]

        %Rock{ type: :plus, point_coords: global_coords }

      :L ->
        global_coords = [
          {left_coord+2, bottom_edge + 2},

          {left_coord+2, bottom_edge + 1},

          {left_coord, bottom_edge},
          {left_coord+1, bottom_edge},
          {left_coord+2, bottom_edge},
        ]

        %Rock{ type: :L, point_coords: global_coords }

      :pillar ->
        global_coords = [
          {left_coord, bottom_edge + 3},
          {left_coord, bottom_edge + 2},
          {left_coord, bottom_edge + 1},
          {left_coord, bottom_edge}
        ]

        %Rock{ type: :pillar, point_coords: global_coords }

      :square ->
        global_coords = [
          {left_coord, bottom_edge + 1},
          {left_coord+1, bottom_edge + 1},

          {left_coord, bottom_edge},
          {left_coord+1, bottom_edge},
        ]

        %Rock{ type: :square, point_coords: global_coords }
    end
  end

  def rock_dir_coords(rock, dir) do
    case rock.type do
      :dash ->
        case dir do
          :bottom -> @dash_bottom
          :left -> @dash_left
          :right -> @dash_right
        end
      :plus ->
        case dir do
          :bottom -> @plus_bottom
          :left -> @plus_left
          :right -> @plus_right
        end
      :L ->
        case dir do
          :bottom -> @l_bottom
          :left -> @l_left
          :right -> @l_right
        end
      :pillar ->
        case dir do
          :bottom -> @pillar_bottom
          :left -> @pillar_left
          :right -> @pillar_right
        end
      :square ->
        case dir do
          :bottom -> @square_bottom
          :left -> @square_left
          :right -> @square_right
        end
    end
  end

  def shift_horizontal(rock, move, col_set) do

    case move do
      :left ->
        left_coords =
          Tetris.rock_dir_coords(rock, :left) |>
          Enum.map(& Enum.at(rock.point_coords, &1))

        can_shift? =
          left_coords |>
          Enum.all?(fn {x,y} ->
            # Need to make sure that all points being moved INTO are in the list of empty column spaces
            # can't move into wall
            if x == 0 do
              false
            else
              # is cell not filled?
              not MapSet.member?(col_set[x-1], y)
            end
          end)

        n_point_coords = if can_shift? == true do
          rock.point_coords |>
          Enum.map(fn {x,y} -> {x-1,y} end)
        else
          rock.point_coords
        end

        %{rock | point_coords: n_point_coords}

      :right ->
        right_coords =
          Tetris.rock_dir_coords(rock, :right) |>
          Enum.map(& Enum.at(rock.point_coords, &1))

        can_shift? =
          right_coords |>
          Enum.all?(fn {x,y} ->
            # can't move into wall
            if x == 6 do
              false
            else
              # is cell not filled?
              not MapSet.member?(col_set[x+1], y)
            end
          end)

        n_point_coords = if can_shift? == true do
          rock.point_coords |>
          Enum.map(fn {x,y} -> {x+1,y} end)
        else
          rock.point_coords
        end
        %{rock | point_coords: n_point_coords}

      nil ->
        rock
    end
  end

  def shift_vertical(rock, col_set) do

    bottom_coords =
      Tetris.rock_dir_coords(rock, :bottom) |>
      Enum.map(& Enum.at(rock.point_coords, &1))

    can_shift? =
      bottom_coords |>
      Enum.all?(fn {x,y} ->
        # is cell empty?
        not Enum.member?(col_set[x], y-1)
      end)

    n_point_coords = if can_shift? == true do
      rock.point_coords |>
      Enum.map(fn {x,y} -> {x,y-1} end)
    else
      rock.point_coords
    end

    {%{rock | point_coords: n_point_coords}, can_shift?}
  end

  def place_rock(rock, tower, to_drop) do
    # Place rock:
    # 1. Add Rock coords to col_stacks + sort stacks
    # 2. Check for intersection(s) between all stacks, take max found and filter all lower vals out of stacks
    #     Maybe improve by using map of frequencies of filled column cells to see if any row if filled?

    n_tower =
      rock.point_coords |>
      # 1. Add Rock coords to col_stacks + sort stacks
      #      ONLY add if: coord is not blocked (above OR left OR right)
      Enum.reduce(tower, fn {x,y}, tower ->
        %Tower{
          tower |
          cols: Map.put(tower.cols, x, MapSet.put(tower.cols[x], y)),
          top: max(tower.top, y),
          freqs: Map.update(tower.freqs, y, 1, & &1 + 1)
        }
      end)

    n_tower = %Tower{ n_tower | dropped: n_tower.dropped + 1}

    # iterate over point_coords, find first one that has created new floor,
    # remove all below from col_set + freq_map

    highest_filled =
      rock.point_coords |>
      Enum.map(fn {_,y} -> y end) |>
      Enum.find(& n_tower.freqs[&1] == 7)


    if not is_nil(highest_filled) do
      # Given a Tetris:
      #   When map_set_size == @cycle_start_col_sum for the FIRST time, the cycle has begun for non-example case.
      #   Each subsequent time that map_set_size == @cycle_start_col_sum:
      #     1. @rocks_per_cycle more rocks will have been placed
      #     2. The topmost point will have increased by @height_per_cycle

      map_set_size = n_tower.cols |> Enum.reduce(0,fn {_,set},a -> a + MapSet.size(set) end)

      # Filter out all cells below the new floor

      n_tower = %Tower{
        n_tower |
        cols: n_tower.cols |>
          Enum.map(fn {x, set} ->
            { x,
              set |>
              MapSet.filter(& &1 >= highest_filled)
            }
          end) |>
          Map.new,

          freqs: n_tower.freqs |>
            Map.filter(fn {k,_} -> k > highest_filled end)
      }

      # Do all of the complete cycles we can fit in before the end
      if map_set_size == @cycle_start_col_sum do
        cycles_to_skip = div(to_drop - n_tower.dropped, @rocks_per_cycle)

        n_dropped = n_tower.dropped + (cycles_to_skip * @rocks_per_cycle)

        raised_cols =
          n_tower.cols |>
          Enum.map(fn {x, set} ->
            {
              x,
              set |>
              MapSet.to_list |>
              Enum.map(& &1 + (cycles_to_skip * @height_per_cycle)) |>
              MapSet.new
            }
          end) |>
          Map.new

        raised_freq_map =
          n_tower.freqs |>
          Enum.map(fn {k,v} ->
            {k + (cycles_to_skip * @height_per_cycle), v}
          end) |>
          Map.new

        %Tower{
          cols: raised_cols,
          top: n_tower.top + (cycles_to_skip * @height_per_cycle),
          freqs: raised_freq_map,
          dropped: n_dropped
        }
      else
        n_tower
      end
    else
      n_tower
    end
  end

  def drop_rock(rock, jet_stream, tower, to_drop) do
    # 1. Do horizontal movement
    #   get all unobstructed points in target dir
    #     if any blocked from moving, cancel move
    #     else execute movement
    # 2. Do vertical movement

    {jet, n_jet_stream} = JetStream.next(jet_stream)
    rock = Tetris.shift_horizontal(rock, jet, tower.cols)


    # vertical
    {rock, shifted} = Tetris.shift_vertical(rock, tower.cols)


    if shifted == true do
      Tetris.drop_rock(rock, n_jet_stream, tower, to_drop)
    else
      {
        Tetris.place_rock(rock, tower, to_drop),
        n_jet_stream
      }
    end
  end

  def drop_all_rocks(to_drop, _, _, %Tower{dropped: dropped} = tower) when to_drop == dropped do
    tower.top
  end

  def drop_all_rocks(to_drop, [], jet_stream, tower) do
    Tetris.drop_all_rocks(
      to_drop,
      @rock_fall_seq,
      jet_stream,
      tower
    )
  end

  def drop_all_rocks(to_drop, [next_rock | rem_rocks], jet_stream, tower) do

    n_rock = Tetris.spawn_rock(next_rock, tower.top)

    {n_tower, n_jet_stream} = Tetris.drop_rock(n_rock, jet_stream, tower, to_drop)

    Tetris.drop_all_rocks(to_drop, rem_rocks, n_jet_stream, n_tower)
  end

  def parse(line) do
    line |>
    String.graphemes |>
    Enum.map(fn ch ->
      case ch do
        "<" -> :left
        ">" -> :right
      end
    end)
  end
end


# Perf Improvement:
#   1. Whenever placing a rock that establishes a higher lower bound for column heights,
#        remove all coordinates with y < min(col_heights)
#   2. Shift to using sorted stacks (Lists) to represent empty spaces
#        this way can easily use slice to remove irrelevant points
#        + column tops will represent lowest empty spot instead of highest filled spot

defmodule Main do

  def main() do

    is_ex? = false

    file_path = if is_ex? == true, do: "../input/d17_ex.txt", else: "../input/d17.txt"

    line = File.read!(file_path) |>
      String.trim_trailing

    jet_stream = JetStream.init(line)

    # 7 columns with first filled spot at y=0 (floor), list values indicate filled cells
    tower = %Tower{
      cols: Enum.map(0..6, & {&1, MapSet.new([0])}) |> Map.new,
      top: 0,
      freqs: %{},
      dropped: 0
    }

    p1_res = Tetris.drop_all_rocks(2022, [], jet_stream, tower)
    p2_res = Tetris.drop_all_rocks(1_000_000_000_000, [], jet_stream, tower)

    IO.inspect(p1_res, label: "Part 1")
    IO.inspect(p2_res, label: "Part 2")

  end
end


Main.main()
