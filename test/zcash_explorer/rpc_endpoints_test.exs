defmodule ZcashExplorer.RpcEndpointsTest do
  use ExUnit.Case, async: false

  alias ZcashExplorer.RpcEndpoints

  setup do
    previous = Application.get_env(:zcash_explorer, RpcEndpoints)

    env_names =
      ~w(
        KRESKO_RPC_NODES_DIR
        KRESKO_NODES_DIR
        KRESKO_RUN_DIR
        KRESKO_RPC_PAYLOAD_DIR
        KRESKO_PAYLOAD_DIR
        KRESKO_RPC_CONFIG_PATH
        KRESKO_CONFIG_PATH
      )

    previous_env = Map.new(env_names, &{&1, System.get_env(&1)})

    Enum.each(env_names, &System.delete_env/1)

    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "zcash-explorer-rpc-endpoints-#{System.unique_integer([:positive])}"
      )

    nodes_dir = Path.join(tmp_dir, "nodes")
    payload_dir = Path.join(tmp_dir, "payload")

    File.mkdir_p!(nodes_dir)
    File.mkdir_p!(Path.join(payload_dir, "miner-0"))

    on_exit(fn ->
      if previous do
        Application.put_env(:zcash_explorer, RpcEndpoints, previous)
      else
        Application.delete_env(:zcash_explorer, RpcEndpoints)
      end

      Enum.each(previous_env, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)

      File.rm_rf!(tmp_dir)
    end)

    %{nodes_dir: nodes_dir, payload_dir: payload_dir}
  end

  test "discovers node json files and reads the rpc port from payload zebrad config", %{
    nodes_dir: nodes_dir,
    payload_dir: payload_dir
  } do
    File.write!(
      Path.join(nodes_dir, "miner-0-0.json"),
      Jason.encode!(%{
        "experiment" => "nu7-pow-vultr-4",
        "name" => "miner-0-0",
        "provider" => "vultr",
        "public_ip" => "155.138.237.238",
        "region" => "atl",
        "role" => "miner",
        "run" => "nu7-pow-vultr-4-20260508-1952"
      })
    )

    File.write!(
      Path.join([payload_dir, "miner-0", "zebrad.toml"]),
      """
      [network]
      listen_addr = "0.0.0.0:18233"

      [rpc]
      listen_addr = "0.0.0.0:18232"
      """
    )

    Application.put_env(:zcash_explorer, RpcEndpoints,
      nodes_dir: nodes_dir,
      payload_dir: payload_dir
    )

    assert [
             %{
               endpoint: "http://155.138.237.238:18232",
               name: "miner-0-0",
               provider: "vultr",
               region: "atl",
               role: "miner",
               run: "nu7-pow-vultr-4-20260508-1952"
             }
           ] = RpcEndpoints.list()
  end

  test "discovers miners from a run config without exposing local genesis data", %{
    payload_dir: payload_dir
  } do
    config_path = Path.join(payload_dir, "config.json")

    File.write!(
      config_path,
      Jason.encode!(%{
        "experiment" => "nu7-pow-vultr-4",
        "local_genesis" => %{
          "funded_keys" => [
            %{"secret_key_hex" => "do-not-render"}
          ]
        },
        "miners" => [
          %{
            "name" => "miner-1-0",
            "node_type" => "miner",
            "public_ip" => "95.179.198.212",
            "region" => "lhr"
          }
        ]
      })
    )

    Application.put_env(:zcash_explorer, RpcEndpoints, payload_dir: payload_dir)

    assert [%{endpoint: "http://95.179.198.212:18232"} = endpoint] =
             RpcEndpoints.list()

    refute Map.has_key?(endpoint, :local_genesis)
  end
end
