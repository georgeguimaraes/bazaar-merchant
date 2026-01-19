defmodule MerchantWeb.OrderLive do
  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Store.get_order(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Order not found")
         |> push_navigate(to: ~p"/")}

      order ->
        {:noreply,
         socket
         |> assign(:order, order)
         |> assign(:page_title, "Order Confirmation")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container max-w-2xl mx-auto px-4 py-8">
        <div class="text-center mb-8">
          <div class="text-6xl mb-4">
            {if @order.status in ["canceled", "refunded"], do: "\u274C", else: "\u2705"}
          </div>
          <h1 class="text-3xl font-bold">
            {if @order.status in ["canceled", "refunded"],
              do: "Order Canceled",
              else: "Order Confirmed!"}
          </h1>
          <p class="text-base-content/70 mt-2">
            Order #{String.slice(@order.id, 0, 8)}...
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <div class="flex justify-between items-center mb-4">
              <h2 class="card-title">Order Details</h2>
              <.status_badge status={@order.status} />
            </div>

            <div class="divide-y">
              <div
                :for={item <- @order.line_items}
                class="py-3 flex justify-between items-center"
              >
                <div class="flex items-center gap-4">
                  <img
                    src={
                      item["item"]["image_url"] ||
                        "https://placehold.co/64x64?text=#{URI.encode(item["item"]["title"] || "Item")}"
                    }
                    alt={item["item"]["title"]}
                    class="w-16 h-16 rounded object-cover"
                  />
                  <div>
                    <p class="font-medium">{item["item"]["title"]}</p>
                    <p class="text-sm text-base-content/50">
                      {item["quantity"]} x ${format_price(item["item"]["price"])}
                    </p>
                  </div>
                </div>
                <p class="font-mono">${format_price(get_item_total(item))}</p>
              </div>
            </div>

            <div class="divider"></div>

            <div class="space-y-2">
              <div :for={total <- @order.totals} class="flex justify-between">
                <span class="capitalize">{total["type"]}</span>
                <span class={"font-mono #{if total["type"] == "total", do: "font-bold text-lg"}"}>
                  ${format_price(total["amount"])}
                </span>
              </div>
            </div>
          </div>
        </div>

        <%= if @order.shipping_address do %>
          <div class="card bg-base-100 shadow-xl mb-6">
            <div class="card-body">
              <h2 class="card-title">Shipping Address</h2>
              <address class="not-italic">
                <p>{@order.shipping_address["first_name"]} {@order.shipping_address["last_name"]}</p>
                <p>{@order.shipping_address["street_address"]}</p>
                <%= if @order.shipping_address["extended_address"] do %>
                  <p>{@order.shipping_address["extended_address"]}</p>
                <% end %>
                <p>
                  {@order.shipping_address["address_locality"]}, {@order.shipping_address[
                    "address_region"
                  ]}
                  {@order.shipping_address["postal_code"]}
                </p>
                <p>{@order.shipping_address["address_country"]}</p>
              </address>
            </div>
          </div>
        <% end %>

        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title">Payment</h2>
            <p>
              <span class="capitalize">{@order.payment_method || "Card"}</span>
              ending in {@order.payment_last_four || "****"}
            </p>
          </div>
        </div>

        <div class="text-center mt-8">
          <.link navigate={~p"/"} class="btn btn-primary">Continue Shopping</.link>
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
    <span class={"badge badge-#{@color}"}>{@status}</span>
    """
  end

  defp format_price(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp format_price(_), do: "0.00"

  defp get_item_total(item) do
    case item["totals"] do
      [%{"amount" => amount} | _] -> amount
      _ -> 0
    end
  end
end
