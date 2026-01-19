defmodule MerchantWeb.Admin.OrdersLive do
  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Orders")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = params["status"]
    orders = Store.list_orders(status: status)

    {:noreply,
     socket
     |> assign(:orders, orders)
     |> assign(:selected_status, status)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Orders</h1>
          <.link navigate={~p"/admin"} class="btn btn-ghost">Back to Dashboard</.link>
        </div>

        <div class="flex gap-2 mb-6 flex-wrap">
          <.link
            navigate={~p"/admin/orders"}
            class={["btn btn-sm", !@selected_status && "btn-primary"]}
          >
            All
          </.link>
          <.link
            :for={status <- ~w(pending processing shipped delivered canceled)}
            navigate={~p"/admin/orders?status=#{status}"}
            class={["btn btn-sm", @selected_status == status && "btn-primary"]}
          >
            {status}
          </.link>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Order ID</th>
                    <th>Status</th>
                    <th>Currency</th>
                    <th>Items</th>
                    <th>Total</th>
                    <th>Payment</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={order <- @orders} class="hover">
                    <td class="font-mono text-xs">{String.slice(order.id, 0, 8)}...</td>
                    <td><.status_badge status={order.status} /></td>
                    <td>{order.currency}</td>
                    <td>{length(order.line_items)}</td>
                    <td>${format_price(get_total(order.totals))}</td>
                    <td>{order.payment_method} •••• {order.payment_last_four}</td>
                    <td class="text-sm">{format_time(order.inserted_at)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%= if @orders == [] do %>
              <div class="text-center py-8">
                <p class="text-base-content/50">No orders found</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    color =
      case assigns.status do
        "delivered" -> "success"
        "shipped" -> "info"
        "processing" -> "warning"
        "pending" -> "ghost"
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
