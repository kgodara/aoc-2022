defmodule Cmd do
  @enforce_keys [:name]
  defstruct [:name, :param]
end



defmodule CathodeRayTube do

  @noop_incr 1
  @addx_incr 2

  @row_len 40
  @row_last_idx 39

  @cycle_incr 40

  def p1([], _, _, _, res) do
    res
  end


  def p1([next_cmd | rest], x_reg, cycle_num, next_sample_idx, res) do

    cycle_num = cycle_num + (if next_cmd.name == "noop", do: @noop_incr, else: @addx_incr)

    {res, next_sample_idx} = if cycle_num >= next_sample_idx do
      {res + (x_reg * next_sample_idx), next_sample_idx + @cycle_incr}
    else
      {res, next_sample_idx}
    end

    x_reg = x_reg + (if next_cmd.name == "addx", do: next_cmd.param, else: 0)

    CathodeRayTube.p1(rest, x_reg, cycle_num, next_sample_idx, res)
  end

  # get char for current 'pixel_pos', given a 'sprite_pos'
  def char_given(pixel_pos, sprite_pos) do
    if abs(pixel_pos - sprite_pos) <= 1, do: "*", else: "."
  end


  def p2([], _, _, _) do
  end
  

  def p2([next_cmd | rest], sprite_pos, pixel_pos, to_write) do

    # buffered char, for after line break
    if to_write != nil do
      IO.write(to_write)
    end

    # always printing at least one char on current line
    IO.write(char_given(pixel_pos, sprite_pos))

    to_write = case {next_cmd.name, pixel_pos} do

      # is second 'addx' char on new line?
      {"addx", @row_last_idx} ->
        char_given(0, sprite_pos)

      # is second 'addx' char on cur line?
      {"addx", _} ->
        IO.write(char_given(pixel_pos+1, sprite_pos))
        nil

      # is 'next_cmd' a 'noop' cmd?
      {_, _} ->
        nil
    end

    # update pixel_pos wrt rows + add conditional new line 
    pixel_pos = pixel_pos + (if next_cmd.name == "noop", do: @noop_incr, else: @addx_incr)

    if pixel_pos > @row_last_idx do
      IO.write("\n")
    end

    pixel_pos = rem(pixel_pos, @row_len)

    # update sprite_pos based on cmd
    sprite_pos = sprite_pos + (if next_cmd.name == "addx", do: next_cmd.param, else: 0)

    CathodeRayTube.p2(rest, sprite_pos, pixel_pos, to_write)
  end
end


defmodule Main do
  @cycle_first_interval 20
  @x_reg_start_val 1

  def main() do
    lines = File.read!("../input/d10.txt") |> String.trim_trailing("\n") |> String.split("\n")

    cmd_list = lines |>
      Enum.map(fn cmd -> cmd |> String.split(" ") end) |>
      Enum.map(fn tokens ->
        if length(tokens) == 1 do
          %Cmd{name: List.first(tokens)}
        else
          %Cmd{name: List.first(tokens), param: tokens |> List.last |> String.to_integer}
        end
    end)

    res = CathodeRayTube.p1(cmd_list, @x_reg_start_val, 0, @cycle_first_interval, 0)
    IO.puts("Part 1: #{res}")

    CathodeRayTube.p2(cmd_list, @x_reg_start_val, 0, nil)
  end
end

Main.main

