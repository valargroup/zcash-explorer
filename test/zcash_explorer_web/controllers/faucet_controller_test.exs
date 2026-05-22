defmodule ZcashExplorerWeb.FaucetControllerTest.RPC do
  def call("validateaddress", [_address]), do: Process.get(:validateaddress_response, {:ok, %{"isvalid" => true}})
  def call("z_sendmany", _params, _timeout), do: Process.get(:z_sendmany_response, {:ok, "opid-1"})

  def call("z_getoperationstatus", _params) do
    Process.get(:operation_status_response, {
      :ok,
      [%{"status" => "success", "result" => %{"txid" => "txid-1"}}]
    })
  end
end

defmodule ZcashExplorerWeb.FaucetControllerTest.RateLimiter do
  def allow?(_ip, _config), do: Process.get(:rate_limit_response, :ok)
end

defmodule ZcashExplorerWeb.FaucetControllerTest do
  use ZcashExplorerWeb.ConnCase

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
      rpc_module: ZcashExplorerWeb.FaucetControllerTest.RPC,
      rate_limiter_module: ZcashExplorerWeb.FaucetControllerTest.RateLimiter
    )

    on_exit(fn ->
      restore_env(Faucet, old_faucet_config)
      restore_env(Zcashex, old_zcashex_config)
    end)

    :ok
  end

  test "GET /faucet renders the faucet page when enabled on testnet", %{conn: conn} do
    conn = get(conn, "/explorer/faucet")

    assert html_response(conn, 200) =~ "Testnet Faucet"
    assert html_response(conn, 200) =~ "Request testnet ZEC"
  end

  test "GET /faucet returns 404 when disabled", %{conn: conn} do
    Application.put_env(:zcash_explorer, Faucet, Keyword.put(Faucet.config(), :enabled, false))

    conn = get(conn, "/explorer/faucet")

    assert response(conn, 404) == "Not found"
  end

  test "POST /faucet rejects blank address", %{conn: conn} do
    conn = post(conn, "/explorer/faucet", %{"address" => ""})

    response = html_response(conn, 200)
    assert response =~ "Faucet request failed."
    assert response =~ "Enter a transparent testnet address."
  end

  test "POST /faucet rejects shielded and unified addresses", %{conn: conn} do
    conn = post(conn, "/explorer/faucet", %{"address" => "u1example"})

    response = html_response(conn, 200)
    assert response =~ "Faucet only supports transparent addresses."
  end

  test "POST /faucet renders rate limit errors", %{conn: conn} do
    Process.put(:rate_limit_response, {:error, :rate_limited})

    conn = post(conn, "/explorer/faucet", %{"address" => "tm-destination"})

    response = html_response(conn, 200)
    assert response =~ "This IP has reached the faucet request limit."
  end

  test "POST /faucet renders txid link on success", %{conn: conn} do
    conn = post(conn, "/explorer/faucet", %{"address" => "tm-destination"})

    response = html_response(conn, 200)
    assert response =~ "Faucet transaction submitted."
    assert response =~ ~s(href="/explorer/transactions/txid-1")
  end

  defp restore_env(module, nil), do: Application.delete_env(:zcash_explorer, module)
  defp restore_env(module, value), do: Application.put_env(:zcash_explorer, module, value)
end
