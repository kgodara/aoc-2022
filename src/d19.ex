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

  def new_bot(%Amounts{} = amts, bp, bot) do
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
    { Amounts.new_bot(amts, bp, bot), Rates.new_bot(rates, bot) }
  end

  def can_spawn?(%Amounts{} = amts, bp, bot) do
    case bot do
      :ore -> amts.ore >= bp.o_ore
      :clay -> amts.ore >= bp.c_ore
      :obsidian -> amts.ore >= bp.ob_ore and amts.clay >= bp.ob_clay
      :geode -> amts.ore >= bp.g_ore and amts.obsidian >= bp.g_ob
    end
  end

  def attempt_skipping_spawn(bp, amts, rates, rem_time, spawn_target) do

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


  # We calculate a tighter-than-naive geode bound by creating sequences of maximum obsidian / clay amounts
  # at each tick.
  # IMPORTANT: We don't include any of the costs of creating any bots in these sequences because that creates tradeoffs.

  # In other words: if the cost of creating bots is 0 (given you have the materials),
  # and you can make multiple bots per tick, what is the most ore & obsidian you can have at each tick?

  # This gives an absolute upper bound on ore and obsidian at each tick

  # Next, we can just run over the sequence of ore and obsidian at each tick,
  # and simulate spawning geode bots WITH COST, to determine the absolute upper bound of geodes we can reach
  # from our current context to the last tick of this simulation.

  # This creates a geode upper bound which is actually constrained by its prerequisites,
  # and is much tighter, as opposed to say an upper bound based on if we could spawn a
  # geode bot from every tick from now until the last tick.


  # Note: this gave a 100x speed-up over a more naive geode bound impl.
  def calc_geode_upper_bound(%Amounts{} = amts, %Rates{} = rates, bp, rem_time) do
    {_, _, ore_max_seq, obsidian_max_seq} =
      # include amt vals before current tick processed since geode bot spawning will need
      Enum.reduce((rem_time)..1//-1, {amts, rates, [amts.ore], [amts.obsidian]},
      fn _, {amt_acc, rate_acc, ore_max_seq_acc, obsidian_max_seq_acc} ->

        # NOTE: we are ignoring bot costs in these bounds
        # try to spawn ore bot

        # try to spawn all bots besides geode bot + update rates
        n_r = Enum.reduce([:ore, :clay, :obsidian], rate_acc, fn bot, n_rate_acc ->
          if Mining.can_spawn?(amt_acc, bp, bot) == true do
            Rates.new_bot(n_rate_acc, bot)
          else
            n_rate_acc
          end
        end)

        # NOTE: we are ignoring bot costs in these bounds
        amt_acc = Amounts.advance(amt_acc, rate_acc)

        {
          amt_acc,
          n_r,
          [amt_acc.ore] ++ ore_max_seq_acc,
          [amt_acc.obsidian] ++ obsidian_max_seq_acc,
        }
      end)


    # remove amounts coming into rem_time=0 (added on last iter of above reduce)
    # otherwise, would end up simulating one extra tick
    #
    # need to reverse() so starting elems point to current tick and subseq point to future ticks
    ore_max_seq = ore_max_seq |> tl() |> Enum.reverse()
    obsidian_max_seq = obsidian_max_seq |> tl() |> Enum.reverse()

    zipped = Enum.zip(ore_max_seq, obsidian_max_seq)

    {geode_upper_bound, _, _, _} = Enum.reduce(zipped, {amts.geode, rates.geode, 0, 0},
    fn {cur_ore, cur_obsidian}, {g, g_rate, decr_ore, decr_obsidian} ->
      if (cur_ore - decr_ore) >= bp.g_ore and (cur_obsidian - decr_obsidian) >= bp.g_ob do
        {
          g + g_rate,
          g_rate + 1,
          decr_ore + bp.g_ore,
          decr_obsidian + bp.g_ob
        }
      else
        {g + g_rate, g_rate, decr_ore, decr_obsidian}
      end
    end)

    geode_upper_bound
  end

  def simulate(bp, amts, rates, rem_time, max_seen \\ 0)

  # when rem_time < 3, the only possibility is that one more geode bot can be made
  # before the last tick.
  def simulate(bp, amts, rates, rem_time, _max_seen) when rem_time < 3 do
    spawnable? = Mining.can_spawn?(amts, bp, :geode) && rem_time == 2

    n_amts = Amounts.advance(amts, rates, rem_time)
    if spawnable? == true, do: n_amts.geode + 1, else: n_amts.geode
  end

  def simulate(bp, amts, rates, rem_time, max_seen) do

    n_amts = Amounts.advance(amts, rates)

    geode_upper_bound = Mining.calc_geode_upper_bound(amts, rates, bp, rem_time)

    if geode_upper_bound > max_seen do

      @robots |>
      # Never spawn a bot whose rate is already > the
      # max cost of its resource for any bot,
      # since we can only make one bot per tick.
      Enum.filter(fn bot ->
        case bot do
          :ore -> rates.ore < bp.o_ore or rates.ore < bp.c_ore or rates.ore < bp.ob_ore or rates.ore < bp.g_ore
          :clay -> rates.clay < bp.ob_clay
          :obsidian -> rates.obsidian < bp.g_ob
          :geode -> true
        end
      end) |>
      Enum.reduce(max_seen, fn bot, max_acc ->
        spawnable? = Mining.can_spawn?(amts, bp, bot)
        # NOTE: there is never a point in making a clay bot with rem_time = 3,
        # not enough time for the clay rate to impact geode production
        # but putting a conditional destroyed performance

        sim_res =
          if spawnable? == true do
            {amts, rates} = Mining.new_bot({n_amts, rates}, bp, bot)
            Mining.simulate(bp, amts, rates, rem_time-1, max_acc)
          else
            # if we can't make the bot right now, try to simulate the case where we wait until we can spawn it
            # rem_time returned here could be < rem_time-1
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


defmodule Main do
  def main() do

    lines = File.read!("../input/d19.txt") |>
      String.trim_trailing |>
      String.split("\n")

    bps = Mining.parse(lines)

    init_amts = %Amounts{ore: 0, clay: 0, obsidian: 0, geode: 0}
    init_rates = %Rates{ore: 1, clay: 0, obsidian: 0, geode: 0}

    p1_res = bps |>
    Enum.map(fn bp ->
      Mining.simulate(bp,
        init_amts,
        init_rates,
        24
      ) * bp.id
    end) |>
    Enum.sum



    p2_res = bps |>
    Enum.take(3) |>
    Enum.map(fn bp ->
      Mining.simulate(bp,
        init_amts,
        init_rates,
        32
      )
    end) |>
    Enum.product


    IO.inspect(p1_res, label: "Part 1")
    IO.inspect(p2_res, label: "Part 2")

  end
end

Main.main()
