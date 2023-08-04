

# NOTE: directory names are not unique, assume files names are not either
defmodule SpaceManager do


  def parse_layout([], _, file_size_lookup, children_lookup, type_lookup) do
    {file_size_lookup, children_lookup, type_lookup}
  end


  # path: ["b", "a", "/"]
  # NOTE: can use an Entry struct or something to avoid both size_lookup & children_lookup
  def parse_layout(cmd_list, path, file_size_lookup, children_lookup, type_lookup) when length(cmd_list) > 0 do
    # [0-9]: add file_name:size keypair to map
    # dir: 

    # on: '$ cd $DIR_NAME' --> modify path and continue
    # on: '$ cd ..' --> modify path and continue
    # on: '$ ls' --> add all FILES to map
    # on: '4358974 $FILE.NAME' --> 
    #     add (file_name => file_size) -- file_size_lookup
    #     add (cwd_path => [file_name] ++ val) -- children_lookup
    #     add (file_name => :file) -- type_lookup
    # on: ''

    {cur_cmd, n_cmd_list} = List.pop_at(cmd_list, 0)
    cwd_path = Enum.join(Enum.reverse(path), "/")

    [n_path, n_file_size_lookup, n_children_lookup, n_type_lookup] = cond do
      # "$ cd .."
      cur_cmd == "$ cd .." ->

        new_path = Enum.drop(path, 1)
        [
          new_path,
          file_size_lookup,
          children_lookup,
          type_lookup
        ]

      # "$ cd $DIR_NAME"
      String.match?(cur_cmd, ~r/\$ cd .*/) ->

        new_cwd = String.split(cur_cmd, " ") |>
          Enum.at(2)

        new_path = [new_cwd] ++ path

        [
          new_path,
          file_size_lookup,
          children_lookup,
          type_lookup
        ]

      # "$ ls"
      cur_cmd == "$ ls" ->
        [
          path,
          file_size_lookup,
          children_lookup,
          type_lookup
        ]

      # "4358974 $FILE.NAME"
      String.match?(cur_cmd, ~r/[0-9]+ .*/) ->

        [file_size, file_name] = String.split(cur_cmd, " ")
        full_file_name = cwd_path <> "/" <> file_name

        new_file_size_lookup = Map.put(file_size_lookup, full_file_name, String.to_integer(file_size))
        new_children_lookup = Map.get_and_update(children_lookup, cwd_path, fn val -> {val, [full_file_name] ++ val} end) |> elem(1)
        new_type_lookup = Map.put(type_lookup, full_file_name, :file)

        [
          path,
          new_file_size_lookup,
          new_children_lookup,
          new_type_lookup
        ]

      # "dir $DIR_NAME"
      String.match?(cur_cmd, ~r/dir .*/) ->

        [_, dir_name] = String.split(cur_cmd, " ")
        full_dir_name = cwd_path <> "/" <> dir_name

        # add dir to new_children_lookup as key and val (parent & child)
        new_children_lookup = Map.put(children_lookup, full_dir_name, [])
        new_children_lookup = Map.get_and_update(new_children_lookup, cwd_path, fn val -> {val, [full_dir_name] ++ val} end) |> elem(1)
        new_type_lookup = Map.put(type_lookup, full_dir_name, :dir)

        [
          path,
          file_size_lookup,
          new_children_lookup,
          new_type_lookup
        ]
    end

    SpaceManager.parse_layout( n_cmd_list, n_path, n_file_size_lookup, n_children_lookup, n_type_lookup)
  end


  def fill_dir_sizes([], dir_size_lookup, file_size_lookup, _, _) do
    Map.merge(file_size_lookup, dir_size_lookup)
  end


  def fill_dir_sizes([{name, children} | tail], dir_size_lookup, file_size_lookup, children_lookup, type_lookup) do

    dir_size = Enum.reduce(children, 0, fn entry_name, acc_size ->
      entry_type = Map.get(type_lookup, entry_name)

      size_val = (if entry_type == :dir, do: dir_size_lookup, else: file_size_lookup) |>
        Map.get(entry_name)

      acc_size + size_val
    end)

    SpaceManager.fill_dir_sizes(
      tail,
      Map.put(dir_size_lookup, name, dir_size),
      file_size_lookup,
      children_lookup,
      type_lookup
    )
  end


  def fill_dir_sizes(file_size_lookup, children_lookup, type_lookup) do
    # sort by descending dir depth,
    # we want to resolve the tree bottom-up

    dir_size_by_depth = type_lookup |>
      Enum.filter(fn {_, type} -> type == :dir end) |>
      Enum.map(fn {name, _} ->
        { name,
          String.graphemes(name) |> Enum.count(& &1 == "/"),
        }
      end) |>
      Enum.sort(fn {_, depth1}, {_, depth2} -> depth1 >= depth2 end) |>
      Enum.map(fn {name, _depth} -> 
        {
          name,
          Map.get(children_lookup, name)
        }
      end)

    SpaceManager.fill_dir_sizes(dir_size_by_depth, Map.new(dir_size_by_depth), file_size_lookup, children_lookup, type_lookup) |> Map.new
  end


  def find_to_delete(full_size_lookup, type_lookup, total_space, needed_free_space) do
  
    used_space = full_size_lookup |> Map.get("/")

    available_space = total_space - used_space
    space_to_make = needed_free_space - available_space

    type_lookup |>
    Enum.filter(fn {_, type} -> type == :dir end) |>
    Enum.map(fn {name, _type} -> Map.get(full_size_lookup, name) end) |>
    Enum.filter(& &1 >= space_to_make) |>
    Enum.reduce(& min &1, &2)
  end
end


lines = File.read!("../input/d7.txt") |> String.split("\n")

{file_size_lookup, children_lookup, type_lookup} = SpaceManager.parse_layout(lines, [], %{}, %{"/" => []}, %{"/" => :dir})


full_size_lookup = SpaceManager.fill_dir_sizes(file_size_lookup, children_lookup, type_lookup)

p1_size = 
    type_lookup |>
    Enum.filter(fn {_, type} -> type == :dir end) |>
    Enum.map(fn {name, _type} ->
      Map.get(full_size_lookup, name)
    end) |>
    Enum.filter(& &1 <= 100000) |>
    Enum.reduce(& &1 + &2)

p2_to_delete = SpaceManager.find_to_delete(full_size_lookup, type_lookup, 70000000, 30000000)

IO.puts("Part 1: #{p1_size}")
IO.puts("Part 2: #{p2_to_delete}")






