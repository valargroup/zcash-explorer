# In this file, we load production configuration and secrets
# from environment variables.
import Config

secret_key_base =
  System.fetch_env!("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

zcashd_hostname =
  System.fetch_env!("ZCASHD_HOSTNAME") ||
    raise """
    environment variable ZCASHD_HOSTNAME is missing
    """

zcashd_port =
  System.fetch_env!("ZCASHD_PORT") ||
    raise """
    environment variable ZCASHD_PORT is missing
    """

zcashd_username =
  System.fetch_env!("ZCASHD_USERNAME") ||
    raise """
    environment variable ZCASHD_USERNAME is missing
    """

zcashd_password =
  System.fetch_env!("ZCASHD_PASSWORD") ||
    raise """
    environment variable ZCASHD_PASSWORD is missing
    """

explorer_hostname =
  System.fetch_env!("EXPLORER_HOSTNAME") ||
    raise """
    environment variable EXPLORER_HOSTNAME is missing
    """

vk_cpus =
  System.fetch_env!("VK_CPUS") ||
    raise """
    environment variable VK_CPUS is missing
    """

vk_mem =
  System.fetch_env!("VK_MEM") ||
    raise """
    environment variable VK_MEM is missing
    """

vk_runnner_image =
  System.fetch_env!("VK_RUNNER_IMAGE") ||
    raise """
    environment variable VK_RUNNER_IMAGE is missing
    """

zcash_network =
  System.fetch_env!("ZCASH_NETWORK") ||
    raise """
    environment variable ZCASH_NETWORK is missing
    """

lightwalletd_enabled =
  System.get_env("LIGHTWALLETD_ENABLED", "true")
  |> String.downcase()
  |> then(&(&1 in ["1", "true", "yes"]))

faucet_enabled =
  System.get_env("FAUCET_ENABLED", "false")
  |> String.downcase()
  |> then(&(&1 in ["1", "true", "yes"]))

config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  url: [
    host: explorer_hostname,
    port: String.to_integer(System.get_env("EXPLORER_PORT") || "443"),
    scheme: System.get_env("EXPLORER_SCHEME") || "https"
  ],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6], compress: true]
  ],
  secret_key_base: secret_key_base,
  # add all the domain names that will be routed to this application
  check_origin: [
    "http://127.0.0.1:4000",
    "//#{explorer_hostname}",
    "//localhost"
  ]

config :zcash_explorer, Zcashex,
  zcashd_hostname: zcashd_hostname,
  zcashd_port: zcashd_port,
  zcashd_username: zcashd_username,
  zcashd_password: zcashd_password,
  vk_cpus: vk_cpus,
  vk_mem: vk_mem,
  vk_runnner_image: vk_runnner_image,
  zcash_network: zcash_network

config :zcash_explorer, ZcashExplorer.Faucet,
  enabled: faucet_enabled,
  source_address: System.get_env("FAUCET_SOURCE_ADDRESS"),
  amount: System.get_env("FAUCET_AMOUNT", "0.1"),
  daily_ip_limit: System.get_env("FAUCET_DAILY_IP_LIMIT", "10") |> String.to_integer(),
  window_seconds: System.get_env("FAUCET_WINDOW_SECONDS", "86400") |> String.to_integer(),
  min_confirmations: System.get_env("FAUCET_MIN_CONFIRMATIONS", "1") |> String.to_integer(),
  operation_poll_attempts:
    System.get_env("FAUCET_OPERATION_POLL_ATTEMPTS", "30") |> String.to_integer(),
  operation_poll_interval_ms:
    System.get_env("FAUCET_OPERATION_POLL_INTERVAL_MS", "1000") |> String.to_integer()

if lightwalletd_enabled do
  lightwalletd_hostname =
    System.fetch_env!("LIGHTWALLETD_HOSTNAME") ||
      raise """
      environment variable LIGHTWALLETD_HOSTNAME is missing
      """

  lightwalletd_port =
    System.fetch_env!("LIGHTWALLETD_PORT") ||
      raise """
      environment variable LIGHTWALLETD_PORT is missing
      """

  lightwalletd_tls =
    System.get_env("LIGHTWALLETD_TLS", "false")
    |> String.downcase()
    |> then(&(&1 in ["1", "true", "yes"]))

  lightwalletd_cacertfile = System.get_env("LIGHTWALLETD_CACERTFILE")

  config :zcash_explorer, ZcashExplorer.Lightwalletd,
    enabled: true,
    hostname: lightwalletd_hostname,
    port: String.to_integer(lightwalletd_port),
    tls: lightwalletd_tls,
    cacertfile: lightwalletd_cacertfile
else
  config :zcash_explorer, ZcashExplorer.Lightwalletd, enabled: false
end

config :zcash_explorer, ZcashExplorerWeb.Endpoint, server: true
