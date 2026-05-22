defmodule ZcashExplorer.Faucet.RateLimiterTest do
  use ExUnit.Case, async: false

  alias ZcashExplorer.Faucet.RateLimiter

  setup do
    Cachex.clear(:faucet_cache)
    :ok
  end

  test "allows requests up to the configured limit" do
    opts = [daily_ip_limit: 2, window_seconds: 86_400]

    assert RateLimiter.allow?("127.0.0.1", opts) == :ok
    assert RateLimiter.allow?("127.0.0.1", opts) == :ok
    assert RateLimiter.allow?("127.0.0.1", opts) == {:error, :rate_limited}
  end

  test "tracks IPs independently" do
    opts = [daily_ip_limit: 1, window_seconds: 86_400]

    assert RateLimiter.allow?("127.0.0.1", opts) == :ok
    assert RateLimiter.allow?("127.0.0.2", opts) == :ok
    assert RateLimiter.allow?("127.0.0.1", opts) == {:error, :rate_limited}
  end

  test "prunes timestamps outside the window" do
    now = System.system_time(:second)
    Cachex.put(:faucet_cache, "faucet:ip:127.0.0.1", [now - 20])

    assert RateLimiter.allow?("127.0.0.1", daily_ip_limit: 1, window_seconds: 10) == :ok
  end
end
