defmodule MerchantWeb.Admin.ProductsLive do
  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Products")}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    products = Store.list_products(active: nil)
    categories = Store.product_categories()

    {:noreply,
     socket
     |> assign(:products, products)
     |> assign(:categories, categories)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Products</h1>
          <.link navigate={~p"/admin"} class="btn btn-ghost">Back to Dashboard</.link>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Image</th>
                    <th>SKU</th>
                    <th>Title</th>
                    <th>Category</th>
                    <th>Price</th>
                    <th>Stock</th>
                    <th>Active</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={product <- @products} class="hover">
                    <td>
                      <div class="avatar">
                        <div class="w-12 h-12 rounded">
                          <img
                            src={
                              product.image_url ||
                                "https://placehold.co/48x48?text=#{URI.encode(product.title)}"
                            }
                            alt={product.title}
                          />
                        </div>
                      </div>
                    </td>
                    <td class="font-mono">{product.sku}</td>
                    <td>{product.title}</td>
                    <td><span class="badge badge-ghost">{product.category}</span></td>
                    <td>${format_price(product.price_cents)}</td>
                    <td>{product.stock}</td>
                    <td>
                      <input
                        type="checkbox"
                        class="toggle toggle-success toggle-sm"
                        checked={product.active}
                        disabled
                      />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%= if @products == [] do %>
              <div class="text-center py-8">
                <p class="text-base-content/50">No products found. Run seeds to add products.</p>
                <code class="mt-2 text-sm">mix run priv/repo/seeds.exs</code>
              </div>
            <% end %>
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
