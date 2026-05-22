defmodule ZcashExplorerWeb.PageControllerTest do
  use ZcashExplorerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  test "GET /rpc", %{conn: conn} do
    conn = get(conn, "/rpc")
    assert html_response(conn, 200) =~ "Public JSON-RPC endpoints"
  end

  test "GET /join", %{conn: conn} do
    conn = get(conn, "/join")
    body = html_response(conn, 200)
    assert body =~ "Join the NU7 testnet"
    assert body =~ "join-nu7-testnet.sh"
    assert body =~ "--mine"
  end
end
