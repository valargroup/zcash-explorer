defmodule ZcashExplorer.Faucet do
  @moduledoc """
  Testnet transparent-address faucet.
  """

  @default_config [
    enabled: false,
    source_address: nil,
    amount: "0.1",
    daily_ip_limit: 10,
    window_seconds: 86_400,
    min_confirmations: 1,
    operation_poll_attempts: 30,
    operation_poll_interval_ms: 1_000,
    rpc_module: ZcashExplorer.RPC,
    rate_limiter_module: ZcashExplorer.Faucet.RateLimiter
  ]

  @shielded_prefixes ["zc", "zs", "u"]
  @testnet_transparent_prefixes ["tm", "tn"]
  @pending_message "transaction submission is still pending"

  def config do
    Keyword.merge(@default_config, Application.get_env(:zcash_explorer, __MODULE__, []))
  end

  def enabled? do
    config = config()

    Keyword.get(config, :enabled, false) == true &&
      testnet?() &&
      present?(Keyword.get(config, :source_address))
  end

  def amount do
    Keyword.get(config(), :amount)
  end

  def request_funds(address, ip) do
    address = String.trim(to_string(address || ""))
    config = config()

    with :ok <- ensure_enabled(config),
         :ok <- validate_address_format(address),
         :ok <- rate_limit(ip, config),
         :ok <- validate_address_with_zcashd(address, config),
         {:ok, operation_id} <- submit_transfer(address, config),
         {:ok, txid} <- poll_operation(operation_id, config) do
      {:ok, txid}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :invalid_address}
    end
  end

  def format_error(:disabled), do: "Faucet is not available."
  def format_error(:not_testnet), do: "Faucet is only available on testnet."
  def format_error(:missing_source_address), do: "Faucet source address is not configured."
  def format_error(:blank_address), do: "Enter a transparent testnet address."
  def format_error(:invalid_address), do: "Enter a valid transparent testnet address."
  def format_error(:shielded_or_unified_address), do: "Faucet only supports transparent addresses."
  def format_error(:rate_limited), do: "This IP has reached the faucet request limit. Try again later."
  def format_error(:invalid_amount), do: "Faucet amount is not configured correctly."
  def format_error(:pending), do: @pending_message
  def format_error(reason) when is_binary(reason), do: reason
  def format_error(reason), do: "Faucet request failed: #{inspect(reason)}"

  defp ensure_enabled(config) do
    cond do
      Keyword.get(config, :enabled, false) != true -> {:error, :disabled}
      !testnet?() -> {:error, :not_testnet}
      !present?(Keyword.get(config, :source_address)) -> {:error, :missing_source_address}
      true -> :ok
    end
  end

  defp validate_address_format(""), do: {:error, :blank_address}

  defp validate_address_format(address) do
    cond do
      starts_with_any?(address, @shielded_prefixes) ->
        {:error, :shielded_or_unified_address}

      testnet?() && !starts_with_any?(address, @testnet_transparent_prefixes) ->
        {:error, :invalid_address}

      true ->
        :ok
    end
  end

  defp validate_address_with_zcashd(address, config) do
    rpc_module = Keyword.fetch!(config, :rpc_module)

    case rpc_module.call("validateaddress", [address]) do
      {:ok, %{"isvalid" => true}} -> :ok
      {:ok, _} -> {:error, :invalid_address}
      {:error, reason} -> {:error, reason}
    end
  end

  defp rate_limit(ip, config) do
    rate_limiter_module = Keyword.fetch!(config, :rate_limiter_module)
    rate_limiter_module.allow?(ip, config)
  end

  defp submit_transfer(destination_address, config) do
    with {:ok, amount} <- parse_amount(Keyword.fetch!(config, :amount)) do
      rpc_module = Keyword.fetch!(config, :rpc_module)
      source_address = Keyword.fetch!(config, :source_address)
      min_confirmations = Keyword.fetch!(config, :min_confirmations)

      rpc_module.call(
        "z_sendmany",
        [
          source_address,
          [
            %{
              "address" => destination_address,
              "amount" => amount
            }
          ],
          min_confirmations
        ],
        120_000
      )
    end
  end

  defp poll_operation(operation_id, config) do
    do_poll_operation(operation_id, config, Keyword.fetch!(config, :operation_poll_attempts))
  end

  defp do_poll_operation(_operation_id, _config, 0), do: {:error, :pending}

  defp do_poll_operation(operation_id, config, attempts_left) do
    rpc_module = Keyword.fetch!(config, :rpc_module)

    case rpc_module.call("z_getoperationstatus", [[operation_id]]) do
      {:ok, [%{"status" => "success", "result" => %{"txid" => txid}} | _]} ->
        {:ok, txid}

      {:ok, [%{"status" => "failed", "error" => %{"message" => message}} | _]} ->
        {:error, message}

      {:ok, [%{"status" => "failed", "error" => error} | _]} ->
        {:error, error}

      {:ok, [%{"status" => status} | _]} when status in ["queued", "executing"] ->
        sleep(config)
        do_poll_operation(operation_id, config, attempts_left - 1)

      {:ok, []} ->
        sleep(config)
        do_poll_operation(operation_id, config, attempts_left - 1)

      {:ok, response} ->
        {:error, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_amount(amount) when is_float(amount) and amount > 0, do: {:ok, amount}
  defp parse_amount(amount) when is_integer(amount) and amount > 0, do: {:ok, amount / 1}

  defp parse_amount(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> {:error, :invalid_amount}
    end
  end

  defp parse_amount(_amount), do: {:error, :invalid_amount}

  defp sleep(config) do
    Process.sleep(Keyword.fetch!(config, :operation_poll_interval_ms))
  end

  defp testnet? do
    config = Application.get_env(:zcash_explorer, Zcashex, [])
    Keyword.get(config, :zcash_network) == "testnet"
  end

  defp starts_with_any?(address, prefixes) do
    Enum.any?(prefixes, &String.starts_with?(address, &1))
  end

  defp present?(nil), do: false
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: true
end
