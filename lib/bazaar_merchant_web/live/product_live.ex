defmodule MerchantWeb.ProductLive do
  use MerchantWeb, :live_view

  alias Merchant.Store
  alias Merchant.CartServer

  @impl true
  def mount(_params, session, socket) do
    cart_id = session["cart_id"] || "default"

    if connected?(socket) do
      CartServer.subscribe(cart_id)
    end

    {:ok,
     socket
     |> assign(:cart_id, cart_id)
     |> assign(:cart_count, CartServer.cart_count(cart_id))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Store.get_product(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Product not found")
         |> push_navigate(to: ~p"/")}

      product ->
        {:noreply,
         socket
         |> assign(:product, product)
         |> assign(:page_title, product.title)
         |> assign(:quantity, 1)}
    end
  end

  @impl true
  def handle_event("update_quantity", %{"quantity" => quantity}, socket) do
    qty = String.to_integer(quantity)
    qty = max(1, min(qty, socket.assigns.product.stock))
    {:noreply, assign(socket, :quantity, qty)}
  end

  @impl true
  def handle_event("add_to_cart", _params, socket) do
    product = socket.assigns.product
    quantity = socket.assigns.quantity
    cart_id = socket.assigns.cart_id

    CartServer.add_item(cart_id, product, quantity)

    {:noreply,
     socket
     |> put_flash(:info, "Added #{quantity}x #{product.title} to cart")
     |> assign(:cart_count, CartServer.cart_count(cart_id))}
  end

  @impl true
  def handle_info({:cart_updated, _cart}, socket) do
    cart_id = socket.assigns.cart_id
    {:noreply, assign(socket, :cart_count, CartServer.cart_count(cart_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <div class="mb-4">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
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
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Shop
          </.link>
        </div>

        <div class="card lg:card-side bg-base-100 shadow-xl">
          <figure class="lg:w-1/2">
            <img
              src={
                @product.image_url ||
                  "https://placehold.co/600x400?text=#{URI.encode(@product.title)}"
              }
              alt={@product.title}
              class="w-full h-96 object-cover"
            />
          </figure>
          <div class="card-body lg:w-1/2">
            <div class="badge badge-ghost">{@product.category}</div>
            <h1 class="card-title text-3xl">{@product.title}</h1>
            <p class="text-base-content/70">{@product.description}</p>

            <div class="mt-4">
              <span class="text-4xl font-bold text-primary">
                ${format_price(@product.price_cents)}
              </span>
            </div>

            <div class="mt-4 flex items-center gap-4">
              <span class="text-sm">Quantity:</span>
              <input
                type="number"
                value={@quantity}
                min="1"
                max={@product.stock}
                class="input input-bordered w-24"
                phx-change="update_quantity"
                name="quantity"
              />
              <span class="text-sm text-base-content/50">
                {if @product.stock > 0, do: "#{@product.stock} in stock", else: "Out of stock"}
              </span>
            </div>

            <div class="card-actions mt-6">
              <button
                class="btn btn-primary btn-lg"
                disabled={@product.stock == 0}
                phx-click="add_to_cart"
              >
                Add to Cart
              </button>
              <.link navigate={~p"/cart"} class="btn btn-outline btn-lg">
                View Cart
                <%= if @cart_count > 0 do %>
                  <span class="badge badge-secondary">{@cart_count}</span>
                <% end %>
              </.link>
            </div>

            <div class="divider"></div>

            <div class="text-sm text-base-content/50">
              <p><strong>SKU:</strong> {@product.sku}</p>
              <p class="mt-2">
                <strong>For AI Agents:</strong>
                Use SKU "{@product.sku}" when creating checkout sessions via the UCP API.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_price(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end
end
