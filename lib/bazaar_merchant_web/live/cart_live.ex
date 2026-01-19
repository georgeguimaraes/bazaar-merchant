defmodule MerchantWeb.CartLive do
  @moduledoc """
  Shopping cart page with real cart functionality.
  """

  use MerchantWeb, :live_view

  alias Merchant.CartServer
  alias Merchant.Store

  @impl true
  def mount(_params, session, socket) do
    cart_id = session["cart_id"] || "default"

    if connected?(socket) do
      CartServer.subscribe(cart_id)
    end

    cart = CartServer.get_cart(cart_id)

    {:ok,
     socket
     |> assign(:page_title, "Cart")
     |> assign(:cart_id, cart_id)
     |> assign(:cart, cart)
     |> assign(:cart_items, Map.values(cart))
     |> assign(:cart_total, CartServer.cart_total(cart_id))}
  end

  @impl true
  def handle_event("update_quantity", %{"id" => id, "quantity" => quantity}, socket) do
    qty = String.to_integer(quantity)
    CartServer.update_quantity(socket.assigns.cart_id, id, qty)
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_item", %{"id" => id}, socket) do
    CartServer.remove_item(socket.assigns.cart_id, id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_cart", _params, socket) do
    CartServer.clear_cart(socket.assigns.cart_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_checkout", _params, socket) do
    cart_items = socket.assigns.cart_items

    if cart_items == [] do
      {:noreply, put_flash(socket, :error, "Cart is empty")}
    else
      line_items =
        Enum.map(cart_items, fn item ->
          %{"item" => %{"id" => item.sku}, "quantity" => item.quantity}
        end)

      params = %{
        "currency" => "USD",
        "line_items" => line_items,
        "payment" => %{}
      }

      case Store.create_checkout(params) do
        {:ok, checkout} ->
          CartServer.clear_cart(socket.assigns.cart_id)

          {:noreply,
           socket
           |> put_flash(:info, "Checkout created!")
           |> push_navigate(to: ~p"/checkout/#{checkout.id}/pay")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create checkout: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def handle_info({:cart_updated, cart}, socket) do
    {:noreply,
     socket
     |> assign(:cart, cart)
     |> assign(:cart_items, Map.values(cart))
     |> assign(:cart_total, CartServer.cart_total(socket.assigns.cart_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="navbar bg-base-100 shadow-lg mb-4">
        <div class="flex-1">
          <.link navigate={~p"/"} class="btn btn-ghost text-xl">Bazaar Merchant</.link>
        </div>
        <div class="flex-none gap-2">
          <.link navigate={~p"/admin"} class="btn btn-ghost">Admin</.link>
        </div>
      </div>

      <div class="container max-w-3xl mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">Shopping Cart</h1>

        <%= if @cart_items == [] do %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body text-center py-12">
              <div class="text-6xl mb-4">🛒</div>
              <p class="text-lg text-base-content/70">Your cart is empty</p>
              <div class="mt-6">
                <.link navigate={~p"/"} class="btn btn-primary">Browse Products</.link>
              </div>
            </div>
          </div>
        <% else %>
          <div class="card bg-base-100 shadow-xl mb-6">
            <div class="card-body">
              <div class="divide-y">
                <div :for={item <- @cart_items} class="py-4 flex items-center gap-4">
                  <img
                    src={
                      item.image_url || "https://placehold.co/80x80?text=#{URI.encode(item.title)}"
                    }
                    alt={item.title}
                    class="w-20 h-20 rounded object-cover"
                  />
                  <div class="flex-1">
                    <h3 class="font-semibold">{item.title}</h3>
                    <p class="text-sm text-base-content/50">SKU: {item.sku}</p>
                    <p class="text-primary font-bold">${format_price(item.price_cents)}</p>
                  </div>
                  <div class="flex items-center gap-2">
                    <input
                      type="number"
                      value={item.quantity}
                      min="1"
                      max={item.stock}
                      class="input input-bordered w-20"
                      phx-change="update_quantity"
                      phx-value-id={item.id}
                      name="quantity"
                    />
                    <button
                      class="btn btn-ghost btn-sm text-error"
                      phx-click="remove_item"
                      phx-value-id={item.id}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-5 w-5"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                        />
                      </svg>
                    </button>
                  </div>
                  <div class="text-right w-24">
                    <p class="font-bold">${format_price(item.price_cents * item.quantity)}</p>
                  </div>
                </div>
              </div>

              <div class="divider"></div>

              <div class="flex justify-between items-center text-xl">
                <span class="font-semibold">Total:</span>
                <span class="font-bold text-primary">${format_price(@cart_total)}</span>
              </div>

              <div class="card-actions justify-between mt-6">
                <button class="btn btn-ghost" phx-click="clear_cart">Clear Cart</button>
                <button class="btn btn-primary btn-lg" phx-click="create_checkout">
                  Proceed to Checkout
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">For AI Agents</h2>
            <p class="text-sm text-base-content/70">
              Create a checkout via the UCP API at
              <code class="bg-base-200 px-1 rounded">POST /checkout-sessions</code>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_price(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp format_price(_), do: "0.00"
end
