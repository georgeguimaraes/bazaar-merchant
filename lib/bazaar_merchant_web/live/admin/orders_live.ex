defmodule MerchantWeb.Admin.OrdersLive do
  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Orders")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    status = params["status"]
    orders = Store.list_orders(status: status)

    socket
    |> assign(:orders, orders)
    |> assign(:selected_status, status)
    |> assign(:order, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Store.get_order(id) do
      nil ->
        socket
        |> put_flash(:error, "Order not found")
        |> push_navigate(to: ~p"/admin/orders")

      order ->
        socket
        |> assign(:order, order)
        |> assign(:page_title, "Order #{String.slice(order.id, 0, 8)}...")
        |> assign(:show_ship_form, false)
        |> assign(:carrier, "")
        |> assign(:tracking_number, "")
    end
  end

  @impl true
  def handle_event("show_ship_form", _, socket) do
    {:noreply, assign(socket, :show_ship_form, true)}
  end

  @impl true
  def handle_event("hide_ship_form", _, socket) do
    {:noreply, assign(socket, :show_ship_form, false)}
  end

  @impl true
  def handle_event("update_carrier", %{"value" => value}, socket) do
    {:noreply, assign(socket, :carrier, value)}
  end

  @impl true
  def handle_event("update_tracking", %{"value" => value}, socket) do
    {:noreply, assign(socket, :tracking_number, value)}
  end

  @impl true
  def handle_event("mark_processing", _, socket) do
    case Store.add_fulfillment_event(socket.assigns.order, :processing) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign(:order, order)
         |> put_flash(:info, "Order marked as processing")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update order")}
    end
  end

  @impl true
  def handle_event("mark_shipped", _, socket) do
    carrier = socket.assigns.carrier
    tracking = socket.assigns.tracking_number

    tracking_url =
      case carrier do
        "UPS" -> "https://www.ups.com/track?tracknum=#{tracking}"
        "FedEx" -> "https://www.fedex.com/fedextrack/?trknbr=#{tracking}"
        "USPS" -> "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{tracking}"
        "DHL" -> "https://www.dhl.com/en/express/tracking.html?AWB=#{tracking}"
        _ -> nil
      end

    opts =
      [carrier: carrier, tracking_number: tracking, tracking_url: tracking_url]
      |> Enum.reject(fn {_, v} -> v == "" or is_nil(v) end)

    case Store.add_fulfillment_event(socket.assigns.order, :shipped, opts) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign(:order, order)
         |> assign(:show_ship_form, false)
         |> put_flash(:info, "Order marked as shipped")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update order")}
    end
  end

  @impl true
  def handle_event("mark_delivered", _, socket) do
    case Store.add_fulfillment_event(socket.assigns.order, :delivered,
           description: "Package delivered"
         ) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign(:order, order)
         |> put_flash(:info, "Order marked as delivered")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update order")}
    end
  end

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Order Details</h1>
          <.link navigate={~p"/admin/orders"} class="btn btn-ghost">Back to Orders</.link>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2 space-y-6">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <div class="flex justify-between items-start">
                  <div>
                    <h2 class="card-title">Order #{String.slice(@order.id, 0, 8)}...</h2>
                    <p class="text-sm text-base-content/60">
                      Created {format_datetime(@order.inserted_at)}
                    </p>
                  </div>
                  <.status_badge status={@order.status} />
                </div>

                <div class="divider"></div>

                <h3 class="font-semibold mb-3">Line Items</h3>
                <div class="space-y-3">
                  <div
                    :for={item <- @order.line_items}
                    class="flex justify-between items-center p-3 bg-base-200 rounded-lg"
                  >
                    <div class="flex items-center gap-3">
                      <img
                        src={item["item"]["image_url"] || "https://placehold.co/48x48?text=?"}
                        alt={item["item"]["title"]}
                        class="w-12 h-12 rounded object-cover"
                      />
                      <div>
                        <p class="font-medium">{item["item"]["title"]}</p>
                        <p class="text-sm text-base-content/60">
                          SKU: {item["item"]["id"]} · Qty: {item["quantity"]}
                        </p>
                      </div>
                    </div>
                    <p class="font-mono">${format_price(item["item"]["price"] * item["quantity"])}</p>
                  </div>
                </div>

                <div class="divider"></div>

                <div class="space-y-2">
                  <div :for={total <- @order.totals} class="flex justify-between">
                    <span class="capitalize">{total["type"]}</span>
                    <span class={if total["type"] == "total", do: "font-bold", else: ""}>
                      ${format_price(total["amount"])}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Customer Information</h2>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                  <%= if @order.buyer do %>
                    <div>
                      <h4 class="font-semibold text-sm mb-2">Buyer</h4>
                      <p>{@order.buyer["first_name"]} {@order.buyer["last_name"]}</p>
                      <p class="text-sm text-base-content/60">{@order.buyer["email"]}</p>
                      <p :if={@order.buyer["phone_number"]} class="text-sm text-base-content/60">
                        {@order.buyer["phone_number"]}
                      </p>
                    </div>
                  <% end %>

                  <%= if @order.shipping_address do %>
                    <div>
                      <h4 class="font-semibold text-sm mb-2">Shipping Address</h4>
                      <address class="not-italic text-sm">
                        <p>
                          {@order.shipping_address["first_name"]} {@order.shipping_address[
                            "last_name"
                          ]}
                        </p>
                        <p>{@order.shipping_address["street_address"]}</p>
                        <p :if={@order.shipping_address["extended_address"]}>
                          {@order.shipping_address["extended_address"]}
                        </p>
                        <p>
                          {@order.shipping_address["address_locality"]}, {@order.shipping_address[
                            "address_region"
                          ]}
                          {@order.shipping_address["postal_code"]}
                        </p>
                        <p>{@order.shipping_address["address_country"]}</p>
                      </address>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <div class="space-y-6">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Fulfillment Actions</h2>

                <div class="space-y-3 mt-4">
                  <%= if @order.status == "pending" do %>
                    <button phx-click="mark_processing" class="btn btn-warning btn-block">
                      Start Processing
                    </button>
                  <% end %>

                  <%= if @order.status in ["pending", "processing"] do %>
                    <%= if @show_ship_form do %>
                      <div class="space-y-3 p-3 bg-base-200 rounded-lg">
                        <input
                          type="text"
                          placeholder="Carrier (e.g., UPS, FedEx)"
                          value={@carrier}
                          phx-keyup="update_carrier"
                          class="input input-bordered w-full"
                        />
                        <input
                          type="text"
                          placeholder="Tracking Number"
                          value={@tracking_number}
                          phx-keyup="update_tracking"
                          class="input input-bordered w-full"
                        />
                        <div class="flex gap-2">
                          <button phx-click="mark_shipped" class="btn btn-info flex-1">
                            Confirm Ship
                          </button>
                          <button phx-click="hide_ship_form" class="btn btn-ghost">Cancel</button>
                        </div>
                      </div>
                    <% else %>
                      <button phx-click="show_ship_form" class="btn btn-info btn-block">
                        Mark as Shipped
                      </button>
                    <% end %>
                  <% end %>

                  <%= if @order.status == "shipped" do %>
                    <button phx-click="mark_delivered" class="btn btn-success btn-block">
                      Mark as Delivered
                    </button>
                  <% end %>

                  <%= if @order.status in ["delivered", "canceled", "refunded"] do %>
                    <div class="alert">
                      <span>Order is {String.upcase(@order.status)}</span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Fulfillment History</h2>

                <% events = get_in(@order.fulfillment, ["events"]) || [] %>

                <%= if events == [] do %>
                  <p class="text-sm text-base-content/50 mt-2">No fulfillment events yet</p>
                <% else %>
                  <ul class="timeline timeline-vertical timeline-compact mt-4">
                    <li :for={{event, idx} <- Enum.with_index(events)}>
                      <hr :if={idx > 0} />
                      <div class="timeline-start text-xs text-base-content/60">
                        {format_event_time(event["occurred_at"])}
                      </div>
                      <div class="timeline-middle">
                        <.event_icon type={event["type"]} />
                      </div>
                      <div class="timeline-end timeline-box">
                        <p class="font-medium capitalize">{event["type"]}</p>
                        <p :if={event["carrier"]} class="text-xs">
                          {event["carrier"]}
                          <span :if={event["tracking_number"]}>#{event["tracking_number"]}</span>
                        </p>
                        <a
                          :if={event["tracking_url"]}
                          href={event["tracking_url"]}
                          target="_blank"
                          class="link link-primary text-xs"
                        >
                          Track Package
                        </a>
                        <p :if={event["description"]} class="text-xs text-base-content/60">
                          {event["description"]}
                        </p>
                      </div>
                      <hr :if={idx < length(events) - 1} />
                    </li>
                  </ul>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
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
                    <th></th>
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
                    <td>
                      <.link navigate={~p"/admin/orders/#{order.id}"} class="btn btn-xs btn-ghost">
                        View
                      </.link>
                    </td>
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
        "refunded" -> "error"
        _ -> "ghost"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"badge badge-#{@color} badge-sm"}>{@status}</span>
    """
  end

  defp event_icon(assigns) do
    icon =
      case assigns.type do
        "processing" -> "hero-clock"
        "shipped" -> "hero-truck"
        "in_transit" -> "hero-arrow-path"
        "delivered" -> "hero-check-circle"
        "failed_attempt" -> "hero-exclamation-circle"
        "canceled" -> "hero-x-circle"
        _ -> "hero-question-mark-circle"
      end

    assigns = assign(assigns, :icon, icon)

    ~H"""
    <.icon name={@icon} class="size-5" />
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

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %H:%M")
  end

  defp format_datetime(_), do: "-"

  defp format_event_time(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%b %d, %H:%M")
      _ -> iso_string
    end
  end

  defp format_event_time(_), do: "-"
end
