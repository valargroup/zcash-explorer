defmodule ZcashExplorer.RpcEndpoints do
  @moduledoc """
  Discovers public JSON-RPC endpoints published by Kresko runs.
  """

  @default_rpc_port 18_232

  def list do
    config = Application.get_env(:zcash_explorer, __MODULE__, [])
    payload_dirs = payload_dirs(config)

    nodes =
      config
      |> node_dirs()
      |> Enum.flat_map(&nodes_from_dir(&1, payload_dirs))

    configs =
      config
      |> config_paths(payload_dirs)
      |> Enum.flat_map(&nodes_from_config(&1, payload_dirs))

    peers = peer_nodes(config)

    (nodes ++ configs ++ peers)
    |> Enum.uniq_by(& &1.endpoint)
    |> Enum.sort_by(&{&1.role, &1.name})
  end

  defp node_dirs(config) do
    [
      config[:nodes_dir],
      System.get_env("KRESKO_RPC_NODES_DIR"),
      System.get_env("KRESKO_NODES_DIR"),
      join(config[:run_dir], "nodes"),
      join(System.get_env("KRESKO_RUN_DIR"), "nodes")
    ]
    |> Enum.concat(
      payload_dirs(config)
      |> Enum.flat_map(&[join(&1, "nodes"), join(&1, "../nodes")])
    )
    |> Enum.concat([priv_path("kresko/nodes")])
    |> existing_dirs()
  end

  defp payload_dirs(config) do
    [
      config[:payload_dir],
      System.get_env("KRESKO_RPC_PAYLOAD_DIR"),
      System.get_env("KRESKO_PAYLOAD_DIR"),
      "/root/kresko/payload",
      "/root/payload",
      priv_path("kresko/payload")
    ]
    |> existing_dirs()
  end

  defp config_paths(config, payload_dirs) do
    [
      config[:config_path],
      System.get_env("KRESKO_RPC_CONFIG_PATH"),
      System.get_env("KRESKO_CONFIG_PATH"),
      join(config[:run_dir], "config.json"),
      join(System.get_env("KRESKO_RUN_DIR"), "config.json")
    ]
    |> Enum.concat(
      payload_dirs
      |> Enum.flat_map(&[join(&1, "config.json"), join(&1, "../config.json")])
    )
    |> Enum.concat([priv_path("kresko/config.json")])
    |> existing_files()
  end

  defp nodes_from_dir(dir, payload_dirs) do
    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.flat_map(&node_from_json_file(&1, payload_dirs))
  end

  defp node_from_json_file(path, payload_dirs) do
    with {:ok, contents} <- File.read(path),
         {:ok, node} <- Jason.decode(contents),
         endpoint when is_binary(endpoint) <- endpoint_for(node, payload_dirs) do
      [attrs(node, endpoint, path)]
    else
      _ -> []
    end
  end

  defp nodes_from_config(path, payload_dirs) do
    with {:ok, contents} <- File.read(path),
         {:ok, %{"miners" => miners} = config} <- Jason.decode(contents),
         true <- is_list(miners) do
      Enum.flat_map(miners, fn miner ->
        miner =
          Map.merge(
            %{
              "experiment" => config["experiment"],
              "run" => config["run"] || config["run_name"] || config["chain_id"]
            },
            miner
          )

        case endpoint_for(miner, payload_dirs) do
          endpoint when is_binary(endpoint) -> [attrs(miner, endpoint, path)]
          _ -> []
        end
      end)
    else
      _ -> []
    end
  end

  defp peer_nodes(config) do
    rpc_port = public_rpc_port(config)

    case Cachex.get(:app_cache, "zcash_nodes") do
      {:ok, nodes} when is_list(nodes) ->
        Enum.flat_map(nodes, &peer_node(&1, rpc_port))

      _ ->
        []
    end
  end

  defp peer_node(%{"addr" => addr}, rpc_port) do
    with host when is_binary(host) <- host_from_addr(addr) do
      [
        %{
          endpoint: "http://#{host}:#{rpc_port}",
          experiment: "",
          name: display_host(host),
          provider: "",
          region: "",
          role: "peer",
          run: "",
          source_path: "zcash_nodes"
        }
      ]
    else
      _ -> []
    end
  end

  defp peer_node(_, _rpc_port), do: []

  defp endpoint_for(%{"rpc_url" => rpc_url}, _payload_dirs) when is_binary(rpc_url) and rpc_url != "" do
    rpc_url
  end

  defp endpoint_for(%{"rpc_endpoint" => rpc_endpoint}, _payload_dirs)
       when is_binary(rpc_endpoint) and rpc_endpoint != "" do
    rpc_endpoint
  end

  defp endpoint_for(node, payload_dirs) do
    with public_ip when is_binary(public_ip) and public_ip != "" <- node["public_ip"] do
      port = rpc_port(node["name"], payload_dirs) || @default_rpc_port
      "http://#{public_ip}:#{port}"
    else
      _ -> nil
    end
  end

  defp attrs(node, endpoint, source_path) do
    %{
      endpoint: endpoint,
      experiment: node["experiment"] || "",
      name: node["name"] || "",
      provider: node["provider"] || "",
      region: node["region"] || "",
      role: node["role"] || node["node_type"] || "",
      run: node["run"] || "",
      source_path: source_path
    }
  end

  defp rpc_port(name, payload_dirs) do
    payload_dirs
    |> Enum.flat_map(&candidate_tomls(&1, name))
    |> Enum.find_value(&rpc_port_from_toml/1)
  end

  defp candidate_tomls(payload_dir, name) do
    names =
      [name, short_node_name(name)]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    exact =
      Enum.flat_map(names, fn node_name ->
        [
          Path.join([payload_dir, node_name, "zebrad.toml"]),
          Path.join([payload_dir, node_name, "zebrad.bootstrap.toml"])
        ]
      end)

    exact ++ Path.wildcard(Path.join([payload_dir, "miner-*", "zebrad.toml"]))
  end

  defp rpc_port_from_toml(path) do
    with true <- File.regular?(path),
         {:ok, contents} <- File.read(path),
         listen_addr when is_binary(listen_addr) <- rpc_listen_addr(contents),
         [_, port] <- Regex.run(~r/:(\d+)$/, listen_addr) do
      String.to_integer(port)
    else
      _ -> nil
    end
  end

  defp rpc_listen_addr(contents) do
    contents
    |> String.split("\n")
    |> Enum.reduce({nil, nil}, fn line, {section, listen_addr} ->
      trimmed = String.trim(line)

      cond do
        Regex.match?(~r/^\[[^\]]+\]$/, trimmed) ->
          {trimmed, listen_addr}

        section == "[rpc]" ->
          case Regex.run(~r/^listen_addr\s*=\s*"([^"]+)"/, trimmed) do
            [_, addr] -> {section, addr}
            _ -> {section, listen_addr}
          end

        true ->
          {section, listen_addr}
      end
    end)
    |> elem(1)
  end

  defp short_node_name(name) when is_binary(name) do
    case Regex.run(~r/^(.+-\d+)-\d+$/, name) do
      [_, short] -> short
      _ -> name
    end
  end

  defp short_node_name(_), do: nil

  defp public_rpc_port(config) do
    [
      config[:rpc_port],
      System.get_env("KRESKO_RPC_PORT"),
      Application.get_env(:zcash_explorer, Zcashex, [])[:zcashd_port],
      @default_rpc_port
    ]
    |> Enum.find_value(&normalize_port/1)
  end

  defp normalize_port(port) when is_integer(port) and port > 0, do: port

  defp normalize_port(port) when is_binary(port) do
    case Integer.parse(port) do
      {port, ""} when port > 0 -> port
      _ -> nil
    end
  end

  defp normalize_port(_), do: nil

  defp host_from_addr(addr) when is_binary(addr) do
    addr = String.trim(addr)

    cond do
      addr == "" ->
        nil

      String.starts_with?(addr, "[") ->
        bracketed_host(addr)

      true ->
        case String.split(addr, ":") do
          [host, _port] -> host
          [host] -> host
          _ -> nil
        end
    end
  end

  defp host_from_addr(_), do: nil

  defp bracketed_host(addr) do
    case Regex.run(~r/^\[([^\]]+)\](?::\d+)?$/, addr) do
      [_, host] -> "[#{host}]"
      _ -> nil
    end
  end

  defp display_host("[" <> bracketed), do: String.trim_trailing(bracketed, "]")
  defp display_host(host), do: host

  defp existing_dirs(paths) do
    paths
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
    |> Enum.filter(&File.dir?/1)
  end

  defp existing_files(paths) do
    paths
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
    |> Enum.filter(&File.regular?/1)
  end

  defp join(nil, _path), do: nil
  defp join(path, suffix), do: Path.expand(Path.join(path, suffix))

  defp priv_path(path) do
    case :code.priv_dir(:zcash_explorer) do
      {:error, _} -> nil
      priv_dir -> Path.join(to_string(priv_dir), path)
    end
  end
end
