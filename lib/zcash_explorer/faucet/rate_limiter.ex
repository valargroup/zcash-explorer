defmodule ZcashExplorer.Faucet.RateLimiter do
  @moduledoc """
  Process-local faucet request limiter backed by Cachex.

  Requests are serialized through this GenServer so concurrent submissions from
  the same IP cannot read the same counter and all pass at once.
  """

  use GenServer

  @cache :faucet_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state), do: {:ok, state}

  def allow?(ip, opts) when is_binary(ip) do
    GenServer.call(__MODULE__, {:allow, ip, opts})
  end

  def handle_call({:allow, ip, opts}, _from, state) do
    now = System.system_time(:second)
    window_seconds = Keyword.fetch!(opts, :window_seconds)
    limit = Keyword.fetch!(opts, :daily_ip_limit)
    key = "faucet:ip:#{ip}"
    cutoff = now - window_seconds

    timestamps =
      case Cachex.get(@cache, key) do
        {:ok, values} when is_list(values) -> values
        _ -> []
      end
      |> Enum.filter(&(&1 > cutoff))

    response =
      if length(timestamps) >= limit do
        {:error, :rate_limited}
      else
        Cachex.put(@cache, key, [now | timestamps], ttl: :timer.seconds(window_seconds))
        :ok
      end

    {:reply, response, state}
  end
end
