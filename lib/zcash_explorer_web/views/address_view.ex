defmodule ZcashExplorerWeb.AddressView do
  use ZcashExplorerWeb, :view

  def title(:get_address, _assigns), do: "Edit Profile"

  def zatoshi_to_zec(zatoshi) do
    zatoshi_per_zec = :math.pow(10, -8)
    zatoshi_per_zec * zatoshi
  end

  def spend_zatoshi(received, balance) do
    (received - balance) |> zatoshi_to_zec
  end

  def page_url(address, page, cursor) do
    params =
      [{"page", to_string(page)}]
      |> maybe_add_param("cursor", cursor)
      |> URI.encode_query()

    "/explorer/address/#{address}?#{params}"
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: params ++ [{key, to_string(value)}]

  def format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.join(",")
  end

  def format_number(_), do: "0"
end
