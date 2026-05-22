defmodule ZcashExplorerWeb.LtsPoolLive do
  use ZcashExplorerWeb, :live_view
  import Phoenix.LiveView.Helpers
  @impl true
  def render(assigns) do
    currency = if(assigns.blockchain_info["chain"] == "main", do: "ZEC", else: "TAZ")

    ~L"""
    <p class="text-2xl font-semibold text-gray-900 dark:dark:bg-slate-800 dark:text-slate-100">
    <%= lts_value(@blockchain_info["valuePools"]) %> <%= currency %>
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 15000)

    {:ok, assign(socket, :blockchain_info, cached_metrics())}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)
    {:noreply, assign(socket, :blockchain_info, cached_metrics())}
  end

  defp lts_value(value_pools) do
    value_pools |> get_value_pools() |> Map.get("lts", 0)
  end

  defp get_value_pools(value_pools) when is_list(value_pools) do
    Enum.map(value_pools, fn %{"id" => name, "chainValue" => value} -> {name, value} end)
    |> Map.new()
  end

  defp get_value_pools(_value_pools), do: %{}

  defp cached_metrics do
    case Cachex.get(:app_cache, "metrics") do
      {:ok, info} when is_map(info) -> info
      _ -> %{"chain" => "test", "valuePools" => []}
    end
  end
end
