
defmodule Entry do
  @enforce_keys [:name, :type]
  defstruct [:name, :type, :size, children: []]
end

# NOTE: directory names are not unique, assume files names are not either
defmodule SpaceManager do

  @total_space 70_000_000
  @needed_free_space 30_000_000


  def parse_layout([], _, entry_lookup) do
    entry_lookup
  end

  def parse_layout(cmd_list, path, entry_lookup) when length(cmd_list) > 0 do
    
    {cur_cmd, n_cmd_list} = List.pop_at(cmd_list, 0)
    cwd_path = Enum.join(Enum.reverse(path), "/")

    # handle cd commands
    n_path = cond do
      cur_cmd == "$ cd .." ->
        Enum.drop(path, 1)

      # "$ cd $DIR_NAME"
      String.match?(cur_cmd, ~r/\$ cd .*/) ->
        cur_cmd |>
        String.split(" ") |>
        Enum.at(2) |>
        List.wrap |>
        Kernel.++(path)

      true ->
        path
    end

    # handle file/dir entries
    n_entry_lookup = cond do

      # "4358974 $FILE.NAME"
      String.match?(cur_cmd, ~r/[0-9]+ .*/) ->

        [file_size, file_name] = String.split(cur_cmd, " ")
        full_file_name = cwd_path <> "/" <> file_name

        entry_lookup |>
        Map.put(
          full_file_name,
          %Entry{
            name: full_file_name,
            type: :file,
            size: String.to_integer(file_size),
            children: []
          }
        ) |>
        Map.update!(cwd_path, fn entry -> %{entry | children: [full_file_name] ++ entry.children} end)

      # "dir $DIR_NAME"
      String.match?(cur_cmd, ~r/dir .*/) ->

        [_, dir_name] = String.split(cur_cmd, " ")
        full_dir_name = cwd_path <> "/" <> dir_name

        entry_lookup |>
        Map.put(
          full_dir_name,
          %Entry{
            name: full_dir_name,
            type: :dir,
          }
        ) |>
        Map.update!(cwd_path, fn entry -> %{entry | children: [full_dir_name] ++ entry.children} end)

      true ->
        entry_lookup
    end

    SpaceManager.parse_layout( n_cmd_list, n_path, n_entry_lookup )
  end


  def fill_dir_sizes([], entry_lookup) do
    entry_lookup
  end


  def fill_dir_sizes([dir_entry | tail], entry_lookup) do

    dir_size = dir_entry.children |>
      Enum.map(& entry_lookup[&1].size ) |>
      Enum.reduce(& &1 + &2)

    SpaceManager.fill_dir_sizes(
      tail,
      Map.update!(entry_lookup, dir_entry.name, fn entry -> %{entry | size: dir_size} end)
    )
  end


  def fill_dir_sizes(entry_lookup) do
    # sort by descending dir depth,
    # we want to resolve the tree bottom-up

    dir_by_depth = entry_lookup |>
      Map.values |>
      Enum.filter(& &1.type == :dir) |>
      Enum.map(fn e ->
        { e,
          String.graphemes(e.name) |> Enum.count(& &1 == "/"),
        }
      end) |>
      Enum.sort(fn {_, depth1}, {_, depth2} -> depth1 >= depth2 end) |>
      Enum.map(& elem(&1, 0))

    SpaceManager.fill_dir_sizes(dir_by_depth, entry_lookup)
  end

  def find_to_delete(entry_lookup) do
  
    used_space = entry_lookup |> Map.get("/") |> Map.get(:size)

    unused_space = @total_space - used_space
    space_to_make = @needed_free_space - unused_space

    entry_lookup |>
    Map.values |>
    Enum.filter(& &1.type == :dir) |>
    Enum.filter(& &1.size >= space_to_make) |>
    Enum.reduce(@total_space + 1, & min(&1.size, &2))
  end
end


defmodule Main do
  def main() do
    lines = File.read!("../input/d7.txt") |> String.split("\n")

    entry_lookup = SpaceManager.parse_layout(lines, [], %{"/" => %Entry{name: "/", type: :dir, size: 0, children: []}}) |>
      SpaceManager.fill_dir_sizes

    p1_size = 
        entry_lookup |>
        Map.values |>
        Enum.filter(& &1.type == :dir) |>
        Enum.filter(& &1.size <= 100_000) |>
        Enum.reduce(0, & &1.size + &2)

    p2_to_delete = entry_lookup |> SpaceManager.find_to_delete

    IO.puts("Part 1: #{p1_size}")
    IO.puts("Part 2: #{p2_to_delete}")
  end
end

Main.main

