defmodule Valve do
  defstruct [:id, :label, :flow, :adj_labels, :adj_ids]
end


defmodule ValveNetwork do
  def parse(lines) do
    # NOTE: 'valves' can be singular
    # Valve AA has flow rate=0; tunnels lead to valves DD, II, BB

    # lookup valve by id
    valve_lookup = lines|>
    Enum.map(fn line ->
      Regex.named_captures(~r/(?<label>[A-Z][A-Z]).*flow rate=(?<flow>[0-9]+).*valves? (?<adj>.*)/, line)
    end) |>
    Enum.reduce(%{}, fn captures, lookup ->
      [label, flow, neighbours] = [captures["label"], captures["flow"], captures["adj"]]

      flow = flow |> String.to_integer
      neighbours = neighbours |> String.split(", ")

      Map.put(lookup, map_size(lookup), %Valve{ id: map_size(lookup), label: label, flow: flow, adj_labels: neighbours })
    end)


    # map of labels to ids
    label_id_lookup =
      valve_lookup |>
      Enum.reduce(%{}, fn {_k, v}, lookup ->
        Map.put(lookup, v.label, v.id)
      end)

    # adj matrix using ids
    adj_matrix = valve_lookup |>
    Map.values |>
    Enum.reduce(%{}, fn v, lookup ->
      adj_ids =
        v.adj_labels |>
        Enum.map(& Map.get(label_id_lookup, &1))
      Map.put(lookup, v.id, adj_ids)
    end)

    valve_lookup =
      valve_lookup |>
      Enum.map(fn {k,v} ->
        {k, %Valve{v | adj_ids: Map.get(adj_matrix, v.id)}}
      end) |>
      Map.new

    {valve_lookup, label_id_lookup["AA"]}

  end

  def bfs(graph, s) do
    bfs(%{}, graph, graph[s.id].adj_ids, [], 1) |>
    Map.delete(s.id)
  end

  defp bfs(paths, _, [], [], _), do: paths

  defp bfs(paths, graph, [], neighbors, layer) do
    bfs(paths, graph, neighbors, [], layer + 1)
  end

  defp bfs(paths, graph, [u | tail], neighbors, layer) do
    cond do
      # already seen, ignore and move on
      Map.has_key?(paths, u) ->
        bfs(paths, graph, tail, neighbors, layer)

      # found new node:
      #   add dist to paths
      #   continue iterating remaining neighbours of cur_node
      #   How does the appending prevent multiple new nodes from stacking up in neighbors?
      #     OH, it doesn't matter because all the new node's neighbors are the same dist
      #     think wave climbing up beach,
      #     we are OK with losing info on path that got us to any point
      #

      true ->
        Map.put_new(paths, u, layer)
        |> bfs(graph, tail, graph[u].adj_ids ++ neighbors, layer)
    end
  end

  # Question: Is it possible to say that any seq that ends at the same point
  # and is worse than another in terms of rem_time AND score should be discarded?
  # (<= rem_time && <= score)

  # That should be a tighter bound than comparing sequences with all of the same members

  # Goal: traverse from s to all other nodes in all permutations
  # Can do DFS with min() to coalesce
  def traverse_all_permutations(flow_graph, dists, cur, closed_valves, score, rem_time, limits) when rem_time == 0 or length(closed_valves) == 0 do
    # if rem(limits["c"], 1_000_000) == 0, do: IO.write("#{limits["c"]}\n")
    {score, Map.update!(limits, "c", & &1 + 1)}
  end

  def traverse_all_permutations(flow_graph, dists, cur, closed_valves, score, rem_time, limits) do

    # Problem: an id in 'closed_valves' == cur

    closed_valves_set = MapSet.new(closed_valves)

    closed_valves |>
    Enum.reduce({0, limits}, fn id, {final_score, limits} ->
      # - 1 here for the tick used to open 'id' valve
      #IO.inspect(closed_valves, label: "closed_valves")
      #IO.inspect({cur, id}, label: "{cur, id}")
      #if id == cur do
      #  IO.inspect({score, rem_time}, label: "{score, rem_time}")
      #  IO.inspect(cur, label: "cur")
      #  IO.inspect(closed_valves, label: "closed_valves")
      #  IO.inspect(limits, label: "limits")
      #end
      n_time = rem_time - dists[cur][id] - 1

      # flow available on all ticks after opening
      n_score = score + (flow_graph[id].flow * n_time)

      # remove activated valve from closed_valves
      # n_closed = MapSet.delete(closed_valves, id)

      {pursue?, n_limits} =
        # We haven't been to this line yet
        if not Map.has_key?(limits, id) do
          {true, Map.put(limits, id, {n_time, n_score})}
        else
          {o_time, o_score} = Map.get(limits, id)
          #IO.inspect([{o_time, o_score}, {n_time, n_score}], label: "cmp")

          # we should pursue this seq if SOMETHING is better than last time we were at this node
          if (n_time > o_time or n_score > o_score) do
            # we should update this node's limit if both params are <= to prev
            # This means that time can only monotonically increase which seems bad
            # But, why are there actual correctness problems?
            if n_time >= o_time and n_score >= o_score do
              IO.inspect(limits, label: "limits")
              {true, Map.put(limits, id, {n_time, n_score})}
            else
              {true, limits}
            end
          else
            {false, limits}
          end
        end

      #IO.inspect({pursue?, id}, label: "get_update results")
      # IO.write()
      if pursue? == true and n_time >= 0 do

        #if n_time < 2 do
        #  IO.inspect(MapSet.delete(closed_valves, id), label: "n_closed")
        #end

        {s, l} = ValveNetwork.traverse_all_permutations(
          flow_graph,
          dists,
          id,
          MapSet.delete(closed_valves_set, id) |> MapSet.to_list,
          n_score,
          n_time,
          n_limits
        )
        {max(final_score, s), l}
      else
        {final_score, limits}
      end
    end)
  end

  # Strip out all nodes with 0 flow besides 'AA'
  def gen_flow_network(graph) do
    graph |>
    Enum.filter(fn {k,v} -> v.flow > 0 or v.label == "AA" end) |>
    Map.new
  end
end

# Init approach:


# Random thought:
#   If we do BFS traversal, can

# Thought:
# Valves with flow rate=0 exist just to add travel cost.
# If we had a triangular matrix of min-distances between all pairs,
# we could just enumerate all possibilites over that group with recursion.

# Is there a way to prune the recursion as we go?
# Or, is there a fast way to determine when a sequence is non-optimal?
# If we went to the max available node and back at the very start, we have a hard bound for pruning
#
# If any gains made so far are < 2x traversal cost to max node +


defmodule Main do
  def main() do
    lines = File.read!("../input/d16.txt") |>
      String.trim_trailing |>
      String.split("\n", trim: true)

    {valve_lookup, start_node_id} = ValveNetwork.parse(lines)

    dists =
      valve_lookup |>
      Map.keys |>
      Enum.reduce(%{}, fn id, lookup ->
        Map.put(lookup, id, ValveNetwork.bfs(valve_lookup, valve_lookup[id]))
      end)



    #IO.inspect(valve_lookup, label: "valve_lookup")
    IO.inspect(dists, label: "dists")

    flow_network = ValveNetwork.gen_flow_network(valve_lookup)

    #IO.inspect(flow_network, label: "flow_network")


    s_closed = flow_network |> Map.values |> Enum.map(& &1.id) |> Enum.filter(& &1 != start_node_id)

    IO.inspect(flow_network, label: "flow_network")

    x = ValveNetwork.traverse_all_permutations(
      flow_network,
      dists,
      flow_network[start_node_id].id,
      s_closed,
      0,
      30,
      %{"c" => 0}
    )

    IO.inspect(elem(x, 0))



  end
end


Main.main()
