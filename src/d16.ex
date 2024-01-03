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

  # Goal: traverse from s to all other nodes in all permutations
  # Can do DFS with min() to coalesce
  def traverse_all_permutations(flow_graph, dists, cur, closed_valves, score, rem_time) when length(closed_valves) == 0 or rem_time == 0 do
    score
  end

  def traverse_all_permutations(flow_graph, dists, cur, closed_valves, score, rem_time) do

    closed_valves_set = MapSet.new(closed_valves)

    closed_valves |>
    Enum.reduce(0, fn id, final_score ->
      # - 1 here for the tick used to open 'id' valve
      n_time = rem_time - dists[cur][id] - 1
      #IO.write("Opening Valve #{flow_graph[id].label} with State {score, rem_time}")
      #IO.inspect({score, rem_time})
      #IO.write("\n")
      max(
        final_score,
        # activate 'id' valve
        ValveNetwork.traverse_all_permutations(
          flow_graph,
          dists,
          id,
          # remove activated valve from closed_valves
          MapSet.delete(closed_valves_set, id) |> MapSet.to_list,
          # flow available on all ticks after opening
          score + (flow_graph[id].flow * n_time),
          n_time
        )
      )
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
    #IO.inspect(dists, label: "dists")

    flow_network = ValveNetwork.gen_flow_network(valve_lookup)

    #IO.inspect(flow_network, label: "flow_network")


    x = ValveNetwork.traverse_all_permutations(flow_network,
      dists,
      # TODO: Fix this

      flow_network[start_node_id].id,
      flow_network |> Map.values |> Enum.map(& &1.id) |> Enum.filter(& &1 != 0),
      0,
      30
    )

    IO.inspect(x)



  end
end


Main.main()
