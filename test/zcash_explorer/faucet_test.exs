defmodule ZcashExplorer.FaucetTest.RPC do
  def call("validateaddress", [address]) do
    send(self(), {:rpc_call, "validateaddress", [address]})
    Process.get(:validateaddress_response, {:ok, %{"isvalid" => true}})
  end

  def call("z_sendmany", params, timeout) do
    send(self(), {:rpc_call, "z_sendmany", params, timeout})
    Process.get(:z_sendmany_response, {:ok, "opid-1"})
  end

  def call("z_getoperationstatus", params) do
    send(self(), {:rpc_call, "z_getoperationstatus", params})

    Process.get(:operation_status_response, {
      :ok,
      [%{"status" => "success", "result" => %{"txid" => "txid-1"}}]
    })
  end
end

defmodule ZcashExplorer.FaucetTest.RateLimiter do
  def allow?(ip, _config) do
    send(self(), {:rate_limit, ip})
    Process.get(:rate_limit_response, :ok)
  end
end

defmodule ZcashExplorer.FaucetTest do
  use ExUnit.Case, async: false

  alias ZcashExplorer.Faucet

  setup do
    old_faucet_config = Application.get_env(:zcash_explorer, Faucet)
    old_zcashex_config = Application.get_env(:zcash_explorer, Zcashex)

    Application.put_env(:zcash_explorer, Zcashex,
      zcashd_hostname: "localhost",
      zcashd_port: "8232",
      zcashd_username: "zcashrpc",
      zcashd_password: "password",
      zcash_network: "testnet"
    )

    Application.put_env(:zcash_explorer, Faucet,
      enabled: true,
      source_address: "tm-source",
      amount: "0.1",
      daily_ip_limit: 10,
      window_seconds: 86_400,
      min_confirmations: 1,
      operation_poll_attempts: 1,
      operation_poll_interval_ms: 0,
      rpc_module: ZcashExplorer.FaucetTest.RPC,
      rate_limiter_module: ZcashExplorer.FaucetTest.RateLimiter
    )

    on_exit(fn ->
      restore_env(Faucet, old_faucet_config)
      restore_env(Zcashex, old_zcashex_config)
    end)
  end

  test "reports disabled when the faucet is not enabled" do
    Application.put_env(:zcash_explorer, Faucet, Keyword.put(Faucet.config(), :enabled, false))

    assert Faucet.request_funds("tm-destination", "127.0.0.1") == {:error, :disabled}
  end

  test "rejects shielded and unified addresses without calling the rate limiter" do
    assert Faucet.request_funds("u1example", "127.0.0.1") ==
             {:error, :shielded_or_unified_address}

    refute_received {:rate_limit, _ip}
  end

  test "rejects non-testnet transparent prefixes" do
    assert Faucet.request_funds("t1mainnet", "127.0.0.1") == {:error, :invalid_address}
  end

  test "submits z_sendmany from the configured source address and returns txid" do
    assert Faucet.request_funds("tm-destination", "127.0.0.1") == {:ok, "txid-1"}

    assert_received {:rate_limit, "127.0.0.1"}
    assert_received {:rpc_call, "validateaddress", ["tm-destination"]}

    assert_received {:rpc_call, "z_sendmany",
                     [
                       "tm-source",
                       [%{"address" => "tm-destination", "amount" => 0.1}],
                       1
                     ], 120_000}

    assert_received {:rpc_call, "z_getoperationstatus", [["opid-1"]]}
  end

  test "returns zcashd operation failure messages" do
    Process.put(:operation_status_response, {
      :ok,
      [%{"status" => "failed", "error" => %{"message" => "insufficient funds"}}]
    })

    assert Faucet.request_funds("tm-destination", "127.0.0.1") ==
             {:error, "insufficient funds"}
  end

  test "returns pending when the async operation does not finish in time" do
    Process.put(:operation_status_response, {:ok, []})

    assert Faucet.request_funds("tm-destination", "127.0.0.1") == {:error, :pending}
  end

  defp restore_env(module, nil), do: Application.delete_env(:zcash_explorer, module)
  defp restore_env(module, value), do: Application.put_env(:zcash_explorer, module, value)
end
