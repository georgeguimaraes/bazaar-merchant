defmodule MerchantWeb.Admin.DashboardLive do
  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin Dashboard")}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    checkout_stats = Store.checkout_stats()
    order_stats = Store.order_stats()
    revenue = Store.revenue_total()
    recent_checkouts = Store.list_checkouts(limit: 5)
    recent_orders = Store.list_orders(limit: 5)

    {:noreply,
     socket
     |> assign(:checkout_stats, checkout_stats)
     |> assign(:order_stats, order_stats)
     |> assign(:revenue, revenue)
     |> assign(:recent_checkouts, recent_checkouts)
     |> assign(:recent_orders, recent_orders)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Admin Dashboard</h1>
          <.link navigate={~p"/"} class="btn btn-ghost">View Store</.link>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <.stat_card
            title="Total Revenue"
            value={"$#{format_price(@revenue)}"}
            icon="currency-dollar"
            color="primary"
          />
          <.stat_card
            title="Total Orders"
            value={@order_stats.total}
            icon="shopping-bag"
            color="secondary"
          />
          <.stat_card
            title="Active Checkouts"
            value={@checkout_stats.incomplete}
            icon="shopping-cart"
            color="accent"
          />
          <.stat_card
            title="Completed"
            value={@checkout_stats.completed}
            icon="check-circle"
            color="success"
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="flex justify-between items-center">
                <h2 class="card-title">Recent Checkouts</h2>
                <.link navigate={~p"/admin/checkouts"} class="btn btn-ghost btn-sm">
                  View All
                </.link>
              </div>
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Status</th>
                      <th>Total</th>
                      <th>Created</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={checkout <- @recent_checkouts}>
                      <td class="font-mono text-xs">{String.slice(checkout.id, 0, 8)}...</td>
                      <td><.status_badge status={checkout.status} /></td>
                      <td>${format_price(get_total(checkout.totals))}</td>
                      <td class="text-sm">{format_time(checkout.inserted_at)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="flex justify-between items-center">
                <h2 class="card-title">Recent Orders</h2>
                <.link navigate={~p"/admin/orders"} class="btn btn-ghost btn-sm">View All</.link>
              </div>
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Status</th>
                      <th>Total</th>
                      <th>Created</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={order <- @recent_orders}>
                      <td class="font-mono text-xs">{String.slice(order.id, 0, 8)}...</td>
                      <td><.status_badge status={order.status} /></td>
                      <td>${format_price(get_total(order.totals))}</td>
                      <td class="text-sm">{format_time(order.inserted_at)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-8">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Quick Actions</h2>
              <div class="flex gap-4 flex-wrap">
                <.link navigate={~p"/admin/products"} class="btn btn-outline">
                  Manage Products
                </.link>
                <.link navigate={~p"/admin/checkouts"} class="btn btn-outline">
                  View Checkouts
                </.link>
                <.link navigate={~p"/admin/orders"} class="btn btn-outline">View Orders</.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="stat bg-base-100 rounded-box shadow">
      <div class={"stat-figure text-#{@color}"}>
        <.stat_icon name={@icon} class="w-8 h-8" />
      </div>
      <div class="stat-title">{@title}</div>
      <div class={"stat-value text-#{@color}"}>{@value}</div>
    </div>
    """
  end

  defp stat_icon(%{name: "currency-dollar"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp stat_icon(%{name: "shopping-bag"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
      />
    </svg>
    """
  end

  defp stat_icon(%{name: "shopping-cart"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 00-16.536-1.84M7.5 14.25L5.106 5.272M6 20.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm12.75 0a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"
      />
    </svg>
    """
  end

  defp stat_icon(%{name: "check-circle"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp status_badge(assigns) do
    color =
      case assigns.status do
        "completed" -> "success"
        "delivered" -> "success"
        "shipped" -> "info"
        "processing" -> "warning"
        "pending" -> "warning"
        "incomplete" -> "ghost"
        "ready_for_complete" -> "info"
        "canceled" -> "error"
        _ -> "ghost"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"badge badge-#{@color} badge-sm"}>{@status}</span>
    """
  end

  defp format_price(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp format_price(_), do: "0.00"

  defp get_total(totals) when is_list(totals) do
    Enum.find_value(totals, 0, fn
      %{"type" => "total", "amount" => amount} -> amount
      _ -> nil
    end)
  end

  defp get_total(_), do: 0

  defp format_time(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %H:%M")
  end

  defp format_time(_), do: "-"
end
