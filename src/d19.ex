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

  def advance(%Amounts{} = amts, %Rates{} = rates) do
    %Amounts{
      ore: amts.ore + rates.ore,
      clay: amts.clay + rates.clay,
      obsidian: amts.obsidian + rates.obsidian,
      geode: amts.geode + rates.geode,
    }
  end

  def new_bot(%Amounts{} = amts, %Rates{} = rates, bp, bot) do
    Map.replace!(amts, bot, Map.get(amts,bot) - Map.get(rates,bot))
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
      IO.inspect([id, o_ore, c_ore, ob_ore, ob_clay, g_ore, g_ob], label: "parsed")

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

  def attempt_spawn({{%Amounts{} = amts, %Amounts{} = n_amts}, %Rates{} = rates}, bp, bot) do

    can_spawn? =
      case bot do
        :ore -> amts.ore >= bp.o_ore
        :clay -> amts.ore >= bp.c_ore
        :obsidian -> amts.ore >= bp.ob_ore and amts.clay >= bp.ob_clay
        :geode -> amts.ore >= bp.g_ore and amts.obsidian >= bp.g_ob
      end

      if can_spawn? == true, do: Mining.new_bot({n_amts, rates}, bp, bot), else: nil
  end

  def max_possible_geodes(rem_time, amts, rates) do
    # Optimal geodes from rem_time is:
    {_,_,future_geodes} =
      Enum.reduce(rem_time..1//-1, {false, 0, amts.geode}, fn _rem, {incr_rate?, num_bots, geodes} ->
        num_bots = (if incr_rate? == true, do: num_bots+1, else: num_bots)
        {
          true,
          num_bots,
          geodes + rates.geode + num_bots
        }
      end)

    # TODO: this upper bound is very high, can bring down by incorporating other downstream resources
    future_geodes
  end

  def simulate(bp, amts, rates, rem_time, max_seen \\ 0)

  def simulate(_bp, amts, _rates, 0, _max_seen) do
    if amts.ore == 4 and amts.clay == 25 and amts.obsidian == 7 and amts.geode == 2 do
      IO.inspect(amts, label: "FINAL Amounts")
      IO.inspect(_rates, label: "FINAL Rates")
      IO.puts("\n")
    end
    amts.geode
  end


  def simulate(bp, amts, rates, rem_time, max_seen) do

    n_amts = Amounts.advance(amts, rates)


    #IO.inspect(rem_time, label: "rem")
    #IO.inspect(amts, label: "ITER amts: ")
    #IO.inspect(rates, label: "ITER rates")

    #IO.inspect("")

    geode_upper_bound = Mining.max_possible_geodes(rem_time, amts, rates)

    if geode_upper_bound > max_seen do
      filtered =
        @robots |>
        Enum.map(fn bot ->
          Mining.attempt_spawn({{amts, n_amts}, rates}, bp, bot)
        end) |>
        Enum.filter(& not is_nil(&1))

      # TODO: Could remove this if every bot can be spawned --> never want to wait
      # add case where we waiting for another bot to be spawnable

      # TODO: Could indicate to further bots which bots need to be spawned next
      # e.g. if ore can already be spawned now, it's never worth it to:
      #   1. not spawn it now
      #   2. wait
      #   3. spawn later
      filtered =
        if length(filtered) == length(@robots) do
          filtered
        else
          [{n_amts, rates}] ++ filtered
        end

      #IO.inspect(filtered, label: "FILTERED")
      #IO.puts("\n")

      filtered |>
      Enum.reduce(max_seen, fn {amts, rates}, max_acc ->
        max(max_acc, Mining.simulate(bp, amts, rates, rem_time-1, max_acc))
      end)
    else
      # IO.puts("Skipping")
      max_seen
    end
  end





  # geode rate can't change, incr and return result
  def simulate2(bp, amts, rates, 1) do
    Mining.simulate(bp, Amounts.advance(amts, rates), rates, 0)
  end

  # geode rate can only change by 1, check if we can make geode bot or not
  def simulate2(bp, amts, rates, 2) do
    # Can we make a geode bot

    spawn_attempt = Mining.attempt_spawn({{amts, Amounts.advance(amts, rates)}, rates}, bp, :geode)

    if is_nil(spawn_attempt) do
      Mining.simulate(
        bp,
        Amounts.advance(amts, rates),
        rates,
        1
      )
    else
      Mining.simulate(
        bp,
        elem(spawn_attempt,0),
        elem(spawn_attempt,1),
        1
      )
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

    lines = File.read!("../input/d19_ex.txt") |>
      String.trim_trailing |>
      String.split("\n")

    bps = Mining.parse(lines) |> List.first()

    bps = [bps]

    bps |>
    Enum.map(fn bp ->
      res = Mining.simulate(bp,
        %Amounts{ore: 0, clay: 0, obsidian: 0, geode: 0},
        %Rates{ore: 1, clay: 0, obsidian: 0, geode: 0},
        24
      )
      IO.inspect(res, label: "max geodes")
      res
    end)


    IO.inspect(bps, label: "bps")
  end
end



Main.main()
