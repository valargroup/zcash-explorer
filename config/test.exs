use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :zcash_explorer, ZcashExplorer.Repo,
  username: "postgres",
  password: "postgres",
  database: "zcash_explorer_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :zcash_explorer, ZcashExplorerWeb.Endpoint,
  http: [port: 4002],
  server: false

config :zcash_explorer, Zcashex,
  zcashd_hostname: "localhost",
  zcashd_port: "8232",
  zcashd_username: "zcashrpc",
  zcashd_password: "password",
  vk_cpus: "0.2",
  vk_mem: "1024M",
  vk_runnner_image: "nighthawkapps/vkrunner",
  zcash_network: "mainnet"

config :zcash_explorer, ZcashExplorer.Faucet,
  enabled: false,
  source_address: nil,
  amount: "0.1",
  daily_ip_limit: 10,
  window_seconds: 86_400,
  min_confirmations: 1,
  operation_poll_attempts: 30,
  operation_poll_interval_ms: 1_000

# Print only warnings and errors during test
config :logger, level: :warn
