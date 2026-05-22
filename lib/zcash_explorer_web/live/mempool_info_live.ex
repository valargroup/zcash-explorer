defmodule ZcashExplorerWeb.MempoolInfoLive do
  use ZcashExplorerWeb, :live_view
  import Phoenix.LiveView.Helpers

  @impl true
  def render(assigns) do
    ~L"""
    <p class="text-2xl font-semibold text-gray-900 dark:dark:bg-slate-800 dark:text-slate-100">
    <%= @mempool_info %>
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 1000)

    {:ok, assign(socket, :mempool_info, cached_mempool_size())}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 1000)
    {:noreply, assign(socket, :mempool_info, cached_mempool_size())}
  end

  defp cached_mempool_size do
    case Cachex.get(:app_cache, "mempool_info") do
      {:ok, info} when is_map(info) -> Map.get(info, "size", 0)
      _ -> 0
    end
  end
end
