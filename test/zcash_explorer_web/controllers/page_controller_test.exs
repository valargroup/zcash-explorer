defmodule ZcashExplorerWeb.PageControllerTest do
  use ZcashExplorerWeb.ConnCase

  test "GET / renders the NU7 testnet landing page", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)
    assert body =~ "NU7-rc0 Testnet"
    assert body =~ "join-nu7-testnet.sh"
    assert body =~ ~s(href="/explorer")
    refute body =~ "testnet coins"
  end

  test "GET /explorer/rpc", %{conn: conn} do
    conn = get(conn, "/explorer/rpc")
    assert html_response(conn, 200) =~ "Public JSON-RPC endpoints"
  end

  test "GET /explorer/join", %{conn: conn} do
    conn = get(conn, "/explorer/join")
    body = html_response(conn, 200)
    assert body =~ "Join the NU7 testnet"
    assert body =~ "join-nu7-testnet.sh"
    assert body =~ "--mine"
  end
end
