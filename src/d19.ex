defmodule Blueprint do
  defstruct [:id, :o_ore, :c_ore, :ob_ore, :ob_clay, :g_ore, :g_ob]
end

defmodule Rates do
  defstruct [:ore, :clay, :obsidian, :geode]
  def new_bot(%Rates{} = rates, bot) do
    Map.replace!(rates, bot, Map.get(rates,bot)+1)
  end
end

defmodule Amounts do
  defstruct [:ore, :clay, :obsidian, :geode]

  def advance(amts, rates, iter \\ 1)

  def advance(%Amounts{} = amts, %Rates{} = rates, iter) do
    %Amounts{
      ore: amts.ore + (rates.ore * iter),
      clay: amts.clay + (rates.clay * iter),
      obsidian: amts.obsidian + (rates.obsidian * iter),
      geode: amts.geode + (rates.geode * iter),
    }
  end

  def new_bot(%Amounts{} = amts, %Rates{} = rates, bp, bot) do
    case bot do
      :ore ->
        %Amounts{
          amts |
          ore: amts.ore - bp.o_ore
        }
      :clay ->
        %Amounts{
          amts |
          ore: amts.ore - bp.c_ore
        }
      :obsidian ->
        %Amounts{
          amts |
          ore:  amts.ore - bp.ob_ore,
          clay: amts.clay - bp.ob_clay,
        }
      :geode ->
        %Amounts{
          amts |
          ore: amts.ore - bp.g_ore,
          obsidian: amts.obsidian - bp.g_ob
        }
    end
  end
end

defmodule Mining do

  @robots [:ore, :clay, :obsidian, :geode]

  def parse(lines) do

    # Ex: Blueprint 1: Each ore robot costs 3 ore. Each clay robot costs 4 ore. Each obsidian robot costs 3 ore and 18 clay. Each geode robot costs 4 ore and 19 obsidian.
    lines |>
    Enum.map(fn line ->
      r = Regex.named_captures(~r/Blueprint (?<id>[0-9]+).*(?<ore>[0-9]+).* (?<clay>[0-9]+).* (?<oore>[0-9]+).* (?<oclay>[0-9]+).* (?<gore>[0-9]+).* (?<gobsidian>[0-9]+).*/, line)

      [id, o_ore, c_ore, ob_ore, ob_clay, g_ore, g_ob] =
        [r["id"], r["ore"], r["clay"], r["oore"], r["oclay"], r["gore"], r["gobsidian"]] |>
        Enum.map(& String.to_integer/1)

      %Blueprint{
        id:       id,
        o_ore:    o_ore,
        c_ore:    c_ore,
        ob_ore:   ob_ore,
        ob_clay:  ob_clay,
        g_ore:    g_ore,
        g_ob:     g_ob
      }
    end)
  end

  def new_bot({%Amounts{} = amts, %Rates{} = rates}, bp, bot) do
    { Amounts.new_bot(amts, rates, bp, bot), Rates.new_bot(rates, bot) }
  end

  def can_spawn?({%Amounts{} = amts, %Rates{} = rates}, bp, bot) do
    case bot do
      :ore -> amts.ore >= bp.o_ore
      :clay -> amts.ore >= bp.c_ore
      :obsidian -> amts.ore >= bp.ob_ore and amts.clay >= bp.ob_clay
      :geode -> amts.ore >= bp.g_ore and amts.obsidian >= bp.g_ob
    end
  end

  def attempt_skipping_spawn(bp, amts, rates, rem_time, spawn_target) do

    #IO.inspect({spawn_target, rem_time, rates}, label: "skipping_spawn()")

    # could we ever spawn this bot?
    possible? = case spawn_target do
      :ore -> rates.ore > 0
      :clay -> rates.ore > 0
      :obsidian -> rates.ore > 0 and rates.clay > 0
      :geode -> rates.ore > 0 and rates.obsidian > 0
    end

    if possible? == true do
      # Assumption: one of the constituents must be less than its blueprint requirement
      # in order for the bot to be unspawnable.
      # So, we shouldn't have to worry about final results being negative.
      ticks_needed = case spawn_target do
        :ore -> ceil((bp.o_ore - amts.ore) / rates.ore)
        :clay -> ceil((bp.c_ore - amts.ore) / rates.ore)
        :obsidian -> max(
          ceil((bp.ob_ore - amts.ore) / rates.ore),
          ceil((bp.ob_clay - amts.clay) / rates.clay)
        )
        :geode -> max(
          ceil((bp.g_ore - amts.ore) / rates.ore),
          ceil((bp.g_ob - amts.obsidian) / rates.obsidian)
        )
      end

      # include tick for spawning the bot
      ticks_needed = ticks_needed + 1

      # TODO: just for debugging allow spawning on last tick
      # problem with optimizing is that valid paths are cut out
      # can just use advance(a,r,$x) if (rem_time - ticks_needed) <= 0
      #   (newly created bot will have 0 impact) / won't be spawned

      if (rem_time - ticks_needed) > 0 do
        n_amts = Amounts.advance(amts, rates, ticks_needed)
        {n_amts, n_rates} = Mining.new_bot({n_amts, rates}, bp, spawn_target)
        {n_amts, n_rates, rem_time - ticks_needed}
      else
        {Amounts.advance(amts, rates, rem_time), rates, 0}
      end
    else
      nil
    end
  end

  def simulate(bp, amts, rates, rem_time, max_seen \\ 0)

  def simulate(bp, amts, rates, rem_time, _max_seen) when rem_time < 3 do
    spawnable? = Mining.can_spawn?({amts, rates}, bp, :geode) && rem_time == 2

    n_amts = Amounts.advance(amts, rates, rem_time)
    geode_res = (if spawnable? == true, do: n_amts.geode + 1, else: n_amts.geode)
    geode_res
  end

  def simulate(bp, amts, rates, rem_time, max_seen) do

    n_amts = Amounts.advance(amts, rates)

    geode_upper_bound = amts.geode + (rates.geode * rem_time) + Enum.sum(1..(rem_time-1))

    # NOTE: could tighten this upper bound by using the ore/obsidian constraint
    # e.g. instead of '+ Enum.sum(1..(rem_time-1))'
    # init: num_makeable_geode_robots
    # init: ore_upper_bound, ob_upper_bound
    # init: num_ore_cost,

    # what if we init:
    #   ore_upper_bound
    #   clay_upper_bound (limited by ore_upper_bound / bp clay bot cost)
    #   ob_upper_bound (limited by clay_upper_bound / ore_upper_bound / costs)
    #

    # NOTE: ore_upper_bound can be constrained 2 more than geodes since, geode bot can be made until
    # geode upper bound includes increasing production including tick=1
    # but ore bot prod can happen tick = 3 at the latest (so a geode bot can be made tick = 2)

    # Ex: rem_time = 7
    # amts.geode = 4, rates.geode = 2
    # geode: 4 + (2 * 7) + sum(1..6) --> 39
    #
    # amts.ore = 4, rates.ore = 2
    # ore: 4 + (2 * 7) + sum()
    #
    # geode bot made at rem_time=7 --> 6 ticks of impact
    # ore bot made at rem_time=7   --> 4 ticks of impact (tick=1 only geode rate matters) + (tick=2 ore needs to be enough to make a geode bot)
    # So, for ore: Enum.sum(1..(rem_time-3))

    # rem_time = 3
    # sum = 0 --> ore bot made on tick = 3 / produce on tick=2 / AFTER check for geode prod occurs --> WORTHLESS

    # rem_time = 4
    # sum = 1 --> ore bot made on tick=4 / produce on tick=3 / geode bot may be enabled on tick=2

    #max_ore_seq = Enum.reduce(rem_time..1, 0, fn i,acc ->
    #
    #end)



    #ore_upper_bound = amts.ore + (rates.ore * rem_time) + Enum.sum(0..(rem_time-3))

    # NOTE: CLAY bot can't even be made on tick=4, since obsidian would have to be made on tick=3, but new obsidian
    # couldn't produce before geode check on tick=2

    # TODO: how to bind clay_upper_bound by ore_upper_bound?
    #clay_upper_bound = amts.clay + (rates.clay * rem_time) + Enum.sum(0..(rem_time-4)//1)

    # bind the ramping obsidian increase to make sure that bots aren't produced in excess of clay/ore limits

    #obsidian_max_bots = min( div(ore_upper_bound, bp.ob_ore), div(clay_upper_bound, bp.ob_clay) )


    #obsidian_clay_max_bots = min(obsidian_max_bots, )

    #obsidian_ramping = Enum.sum(0..(rem_time-3))

    #obsidian_upper_bound = amts.obsidian + (rates.obsidian * rem_time)

    #geode_upper_bound =



    if geode_upper_bound > max_seen do

      # Impl thought:
      # Make method to incr rem_time by however long until given bot can be spawned,
      # including processing the actual spawning tick
      # return nil if impossible to spawn (resource has rate=0 OR will spawn on last tick OR run out of time)
      # return new amts/rates/rem_time if spawn is doable

        @robots |>
          Enum.reduce(max_seen, fn bot, max_acc ->
            spawnable? = Mining.can_spawn?({amts, rates}, bp, bot)# && not(bot == :clay && rem_time == 3)
            # NOTE: there is never a point in making a clay bot with rem_time = 3,
            # not enough time for the clay rate to impact geode production

            sim_res =
              if spawnable? == true do
                {amts, rates} = Mining.new_bot({n_amts, rates}, bp, bot)
                Mining.simulate(bp, amts, rates, rem_time-1, max_acc)
              else
                case Mining.attempt_skipping_spawn(bp, amts, rates, rem_time, bot) do
                  {amts, rates, rem_time} -> Mining.simulate(bp, amts, rates, rem_time, max_acc)
                  nil -> -1
                end
              end

              max(sim_res, max_acc)
        end)
    else
      max_seen
    end
  end
end

# What are the choices available at each minute?
#   1. Do nothing.
#   2. Build robot whose requirements are satisfied.

# What state to track?
# # resources, production rates, time remaining


# Maybe we could work backwards from the geode robot?
# No, that seems really hard.


# NOTE: Geode robot always has higher obsidian cost than ore cost
# NOTE: Obsidian robot always has higher clay cost than ore cost

defmodule Main do
  def main() do

    lines = File.read!("../input/d19.txt") |>
      String.trim_trailing |>
      String.split("\n")

    bps = Mining.parse(lines)


    _y = """
    p1_res = bps |>
    Enum.map(fn bp ->
      res = Mining.simulate(bp,
        %Amounts{ore: 0, clay: 0, obsidian: 0, geode: 0},
        %Rates{ore: 1, clay: 0, obsidian: 0, geode: 0},
        28
      )
      IO.inspect({bp.id, res}, label: "bp")
      res * bp.id
    end) |>
    Enum.reduce(0, & &1 + &2)
    """


    p2_res = bps |>
    Enum.take(3) |>
    Enum.map(fn bp ->
      res = Mining.simulate(bp,
        %Amounts{ore: 0, clay: 0, obsidian: 0, geode: 0},
        %Rates{ore: 1, clay: 0, obsidian: 0, geode: 0},
        24
      )
      IO.inspect({bp.id, res}, label: "bp")
      res * bp.id
    end) |>
    Enum.reduce(0, & &1 + &2)


    #IO.inspect(p1_res, label: "Part 1")
    #IO.inspect(p2_res, label: "Part 2")

  end
end



Main.main()
