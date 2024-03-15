# lib/mix/tasks/echo.ex
defmodule Mix.Tasks.Solve do
  alias Mix.Tasks.Solve
  @shortdoc "Solves AOC problems"
  use Mix.Task

  def parse_args(args) do
    aliases = [d: :day, t: :time, e: :ex, a: :all, s: :suppress]

    switches = [
      day: :integer,
      time: :boolean,
      ex: :boolean,
      all: :boolean,
      suppress: :boolean
    ]

    case OptionParser.parse(args, aliases: aliases, strict: switches) do
      {opts, [], []} -> opts
      {_, [], [{flag, _} | _]} -> Mix.raise("Invalid option(s): #{inspect(flag)}")
      {_, any, _} -> Mix.raise("Unexpected argument(s): #{any |> Enum.join(" ") |> inspect()}")
    end |>
    Map.new |>
    then(& Map.merge(%{ :time => false, :ex => false, :all => false, :suppress => false }, &1))
  end

  @impl Mix.Task
  def run(args) do
    parsed = Solve.parse_args(args)

    ex_str = if parsed.ex == true, do: "_ex", else: ""


    if parsed.all == true do
      total_time =
        Enum.reduce(1..25, 0, fn d,time_acc ->

          IO.puts("Day #{d}")

          input = File.read!("./input/d#{d}#{ex_str}.txt") |> String.trim_trailing
          fn_args = [input]

          mod = Module.concat(["D#{d}"])

          t =
            case parsed.time do
              true ->
                {time, _} = :timer.tc(mod, :sol, fn_args)
                if parsed.suppress == false do
                  IO.puts("⏱️ #{time / 1000} ms")
                end
                time/1000
              false ->
                apply(mod, :sol, fn_args)
                0
            end

          IO.puts("")

          time_acc + t

        end)

      if parsed.time == true, do: IO.puts("Total Time: #{total_time} ms")


    else
      input = File.read!("./input/d#{parsed.day}#{ex_str}.txt") |> String.trim_trailing

      fn_args = [input]

      mod = Module.concat(["D#{parsed.day}"])
      case parsed.time do
        true ->
          {time, _} = :timer.tc(mod, :sol, fn_args)
          IO.puts("⏱️ #{time / 1000} ms")
        false -> apply(mod, :sol, fn_args)
      end
    end


  end
end
