defmodule MerchantWeb.HomeLive do
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
     |> assign(:page_title, "Shop")
     |> assign(:cart_id, cart_id)
     |> assign(:cart_count, CartServer.cart_count(cart_id))}
  end

  @impl true
  def handle_info({:cart_updated, _cart}, socket) do
    cart_id = socket.assigns.cart_id
    {:noreply, assign(socket, :cart_count, CartServer.cart_count(cart_id))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    category = params["category"]
    products = Store.list_products(category: category)
    categories = Store.product_categories()

    {:noreply,
     socket
     |> assign(:products, products)
     |> assign(:categories, categories)
     |> assign(:selected_category, category)}
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
          <.link navigate={~p"/cart"} class="btn btn-ghost">
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
                d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"
              />
            </svg>
            Cart
            <%= if @cart_count > 0 do %>
              <span class="badge badge-primary badge-sm">{@cart_count}</span>
            <% end %>
          </.link>
          <.link navigate={~p"/admin"} class="btn btn-ghost">
            Admin
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold mb-2">Welcome to Bazaar Merchant</h1>
          <p class="text-lg text-base-content/70">
            A demo store powered by Bazaar SDK for UCP
          </p>
          <div class="badge badge-primary mt-2">AI Agent Ready</div>
        </div>

        <div class="flex gap-2 justify-center mb-8 flex-wrap">
          <.link
            navigate={~p"/"}
            class={["btn btn-sm", !@selected_category && "btn-primary"]}
          >
            All
          </.link>
          <.link
            :for={category <- @categories}
            navigate={~p"/?category=#{category}"}
            class={["btn btn-sm", @selected_category == category && "btn-primary"]}
          >
            {category}
          </.link>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          <.product_card :for={product <- @products} product={product} />
        </div>

        <%= if @products == [] do %>
          <div class="text-center py-12">
            <p class="text-lg text-base-content/50">No products found</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp product_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/products/#{@product.id}"}
      class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow"
    >
      <figure class="px-4 pt-4">
        <img
          src={
            @product.image_url || "https://placehold.co/300x200?text=#{URI.encode(@product.title)}"
          }
          alt={@product.title}
          class="rounded-xl h-48 w-full object-cover"
        />
      </figure>
      <div class="card-body">
        <h2 class="card-title">{@product.title}</h2>
        <p class="text-base-content/70 line-clamp-2">{@product.description}</p>
        <div class="flex justify-between items-center mt-2">
          <span class="text-2xl font-bold text-primary">
            ${format_price(@product.price_cents)}
          </span>
          <span class="badge badge-ghost">{@product.category}</span>
        </div>
        <div class="card-actions justify-end mt-2">
          <span class="text-sm text-base-content/50">SKU: {@product.sku}</span>
        </div>
      </div>
    </.link>
    """
  end

  defp format_price(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end
end
