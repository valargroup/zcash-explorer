defmodule ZcashExplorerWeb.FaucetController do
  use ZcashExplorerWeb, :controller

  alias ZcashExplorer.Faucet

  def index(conn, _params) do
    render_faucet(conn)
  end

  def create(conn, %{"address" => address}) do
    ip = client_ip(conn)

    case Faucet.request_funds(address, ip) do
      {:ok, txid} ->
        conn
        |> put_flash(:info, "Faucet transaction submitted.")
        |> render("index.html", assigns(address, txid))

      {:error, reason} ->
        conn
        |> put_flash(:error, Faucet.format_error(reason))
        |> render("index.html", assigns(address, nil))
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, Faucet.format_error(:blank_address))
    |> render("index.html", assigns("", nil))
  end

  defp render_faucet(conn) do
    if Faucet.enabled?() do
      render(conn, "index.html", assigns("", nil))
    else
      send_resp(conn, 404, "Not found")
    end
  end

  defp assigns(address, txid) do
    [
      address: address,
      txid: txid,
      amount: Faucet.amount(),
      csrf_token: get_csrf_token(),
      page_title: "Zcash Testnet Faucet"
    ]
  end

  defp client_ip(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end
end
