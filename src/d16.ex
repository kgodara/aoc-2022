defmodule Valve do
  defstruct [:id, :label, :flow, :adj_labels, :adj_ids]
end

defmodule ValveNetwork do
  def parse(lines) do
    # NOTE: 'valves' can be singular

    # Example:
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

  # BFS is used to get a distance matrix so we can prune all valves with 0 flow
  # and only consider the starting valve and valves with non-zero flows
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

  def permute_pruned(_, _, closed_valves, score, rem_time, limits) when rem_time == 0 or length(closed_valves) == 0 do
    {score, limits}
  end

  # permute across all possibilities with pruning
  # limit_key is pruning mechanism, need to prune by:
  #   position in network
  #   opened_valves (useful for part 2)
  #   time remaining
  # returns: {max val for single agent, limits (best scores for all encountered 'limit_key')}
  def permute_pruned({flow_graph, dists}, cur, closed_valves, score, rem_time, limits) do

    # Problem: an id in 'closed_valves' == cur
    closed_valves_set = MapSet.new(closed_valves)

    closed_valves |>
    Enum.reduce({score, limits}, fn dst, {final_score, limits_acc} ->
      # - 1 here for the tick used to open 'dst' valve
      n_time = rem_time - dists[cur][dst] - 1

      # flow available on all ticks after opening
      n_score = score + (flow_graph[dst].flow * n_time)

      # are opening valve 'dst' in this iter so remove from closed_valves_set
      closed_valves_set = MapSet.delete(closed_valves_set, dst)
      open =
        flow_graph |>
        Map.values |>
        Enum.map(& &1.id) |>
        Enum.filter(& not MapSet.member?(closed_valves_set,&1))

      limit_key = {dst, open, n_time}
      limit_key_exists? = Map.has_key?(limits_acc, limit_key)

      n_limits =
        if not limit_key_exists? or n_score > Map.get(limits_acc, limit_key) do
          Map.put(limits_acc, limit_key, n_score)
        else
          limits_acc
        end

      pursue? = not limit_key_exists? or Map.get(limits_acc, limit_key) <= n_score

      if pursue? == true and n_time >= 0 do

        {s, l} = ValveNetwork.permute_pruned(
          {flow_graph, dists},
          dst,
          closed_valves_set |> MapSet.to_list,
          n_score,
          n_time,
          n_limits
        )
        {max(final_score, s), l}
      else
        {final_score, limits_acc}
      end
    end)
  end

  # Strip out all nodes with 0 flow besides 'AA'
  def gen_flow_network(graph) do
    graph |>
    Enum.filter(fn {_,v} -> v.flow > 0 end) |>
    Map.new
  end
end

# Thought:
# Valves with flow rate=0 exist just to add travel cost.
# If we had a triangular matrix of min-distances between all pairs,
# we could just enumerate all possibilites over that group with recursion.

# Is there a way to prune the recursion as we go?
# Or, is there a fast way to determine when a sequence is non-optimal?

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

    flow_network = ValveNetwork.gen_flow_network(valve_lookup)


    # closed valves with nonzero flow
    closed =
      flow_network |>
      Map.values |>
      Enum.map(& &1.id) |>
      MapSet.new


    [{res_p1, _}, {_, limits}] =
      [30,26] |>
      Enum.map(&
        ValveNetwork.permute_pruned(
          {flow_network, dists},
          start_node_id,
          closed,
          0,
          &1,
          %{}
        )
      )


    # Get max scores for every subset of nodes selected
    subset_max_scores = limits |>
      Enum.map(fn {{_id,open,_time}, score} -> {open,score} end) |>
      Enum.reduce(%{}, fn {open, score},acc ->
        if not Map.has_key?(acc, open) do
          Map.put(acc, open, score)
        else
          Map.put(acc, open, max(acc[open], score))
        end
      end)

    # Find best results for 2 agents by finding
    # the maximum possible score as a sum of 2 disjoint paths
    # over all subsets (assoc with their max scores)
    res_p2 =
      subset_max_scores |>
      Enum.reduce(0, fn {subset, score}, max_score ->
        set1 = subset |> MapSet.new

        subset_max_scores |>
        Map.delete(subset) |>
        Enum.reduce(max_score, fn {subset2, score2}, score_acc ->
          set2 = subset2 |> MapSet.new
          if MapSet.disjoint?(set1, set2) do
            max(score_acc, score+score2)
          else
            score_acc
          end
        end)
      end)

    IO.inspect(res_p1, label: "Part 1")
    IO.inspect(res_p2, label: "Part 2")

  end
end


Main.main()
