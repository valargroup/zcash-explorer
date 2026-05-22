defmodule ZcashExplorerWeb.BlockChainSizeLive do
  use ZcashExplorerWeb, :live_view
  import Phoenix.LiveView.Helpers

  @impl true
  def render(assigns) do
    ~L"""
    <p class="text-2xl font-semibold text-gray-900 dark:dark:bg-slate-800 dark:text-slate-100">
    <%= Sizeable.filesize(@blockchain_size) %>
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 15000)

    {:ok, assign(socket, :blockchain_size, cached_metric("size_on_disk", 0))}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15000)
    {:noreply, assign(socket, :blockchain_size, cached_metric("size_on_disk", 0))}
  end

  defp cached_metric(key, default) do
    case Cachex.get(:app_cache, "metrics") do
      {:ok, info} when is_map(info) -> Map.get(info, key, default)
      _ -> default
    end
  end
end
