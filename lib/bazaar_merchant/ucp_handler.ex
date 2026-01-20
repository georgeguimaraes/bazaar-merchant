defmodule Merchant.UCPHandler do
  @moduledoc """
  UCP Handler implementation for Bazaar Merchant demo store.

  This handler demonstrates a complete UCP-compliant merchant implementation
  with checkout sessions, orders, and mock payment processing.
  """

  use Bazaar.Handler

  alias Merchant.Store
  require Logger

  @impl true
  def capabilities, do: [:checkout, :orders, :catalog]

  @impl true
  def business_profile do
    # Use relative paths - DiscoveryProfile will resolve them with the request base URL
    %{
      "name" => "Bazaar Merchant Demo",
      "description" => "A demo store showcasing the Bazaar SDK for UCP",
      "logo_url" => "/images/logo.svg",
      "support_email" => "support@bazaar-merchant.example",
      "signing_keys" => [
        %{
          "kty" => "EC",
          "kid" => "bazaar-demo-key-1",
          "use" => "sig",
          "alg" => "ES256",
          "crv" => "P-256",
          "x" => "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
          "y" => "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0"
        }
      ]
    }
  end

  # Checkout callbacks

  @impl true
  def create_checkout(params, conn) do
    Logger.info("Creating checkout", params: params, agent: conn.assigns[:ucp_agent])
    base_url = get_base_url(conn)

    case Store.create_checkout(params) do
      {:ok, checkout} ->
        {:ok, checkout_to_ucp(checkout, base_url)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def get_checkout(id, conn) do
    base_url = get_base_url(conn)

    case Store.get_checkout(id) do
      nil -> {:error, :not_found}
      checkout -> {:ok, checkout_to_ucp(checkout, base_url)}
    end
  end

  @impl true
  def update_checkout(id, params, conn) do
    base_url = get_base_url(conn)

    case Store.get_checkout(id) do
      nil ->
        {:error, :not_found}

      checkout ->
        case Store.update_checkout(checkout, params) do
          {:ok, updated} -> {:ok, checkout_to_ucp(updated, base_url)}
          {:error, :already_completed} -> {:error, :invalid_state}
          {:error, :already_canceled} -> {:error, :invalid_state}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def cancel_checkout(id, _conn) do
    case Store.get_checkout(id) do
      nil ->
        {:error, :not_found}

      checkout ->
        case Store.cancel_checkout(checkout) do
          {:ok, canceled} -> {:ok, %{"id" => canceled.id, "status" => "canceled"}}
          {:error, :already_completed} -> {:error, :invalid_state}
        end
    end
  end

  @impl true
  def complete_checkout(id, conn) do
    base_url = get_base_url(conn)

    case Store.get_checkout(id) do
      nil ->
        {:error, :not_found}

      checkout ->
        case Store.complete_checkout(checkout) do
          {:ok, {updated_checkout, _order}} ->
            {:ok, checkout_to_ucp(updated_checkout, base_url)}

          {:error, :invalid_status} ->
            {:error, :invalid_state}
        end
    end
  end

  # Order callbacks

  @impl true
  def get_order(id, _conn) do
    case Store.get_order(id) do
      nil -> {:error, :not_found}
      order -> {:ok, order_to_ucp(order)}
    end
  end

  @impl true
  def cancel_order(id, _conn) do
    case Store.get_order(id) do
      nil ->
        {:error, :not_found}

      order ->
        case Store.cancel_order(order) do
          {:ok, canceled} -> {:ok, %{"id" => canceled.id, "status" => "canceled"}}
          {:error, :cannot_cancel_shipped} -> {:error, :invalid_state}
        end
    end
  end

  # Catalog callbacks

  @impl true
  def list_products(params, _conn) do
    opts = [
      category: params["category"],
      limit: parse_limit(params["limit"], 50)
    ]

    products = Store.list_products(opts)

    {:ok,
     %{
       "products" => Enum.map(products, &product_to_ucp/1),
       "has_more" => false
     }}
  end

  @impl true
  def get_product(id, _conn) do
    case Store.get_product(id) || Store.get_product_by_sku(id) do
      nil -> {:error, :not_found}
      product -> {:ok, product_to_ucp(product)}
    end
  end

  @impl true
  def search_products(params, _conn) do
    query = params["q"] || params["query"] || ""

    opts = [
      category: params["category"],
      limit: parse_limit(params["limit"], 20)
    ]

    products = Store.search_products(query, opts)

    {:ok,
     %{
       "products" => Enum.map(products, &product_to_ucp/1),
       "query" => query,
       "has_more" => false
     }}
  end

  # Webhook callback

  @impl true
  def handle_webhook(%{"event" => event, "data" => data}) do
    Logger.info("Received webhook", event: event, data: data)
    {:ok, :processed}
  end

  def handle_webhook(_) do
    {:error, :invalid_webhook}
  end

  # Private helpers

  defp checkout_to_ucp(checkout, base_url) do
    base = %{
      "id" => checkout.id,
      "status" => checkout.status,
      "currency" => checkout.currency,
      "line_items" => checkout.line_items,
      "totals" => checkout.totals,
      "links" => [
        %{"type" => "privacy_policy", "url" => base_url <> "/privacy"},
        %{"type" => "terms_of_service", "url" => base_url <> "/terms"}
      ],
      "payment" => checkout.payment,
      "messages" => checkout.messages || [],
      "metadata" => checkout.metadata || %{}
    }

    base
    |> maybe_add("buyer", checkout.buyer)
    |> maybe_add("shipping_address", checkout.shipping_address)
    |> maybe_add("billing_address", checkout.billing_address)
    |> maybe_add("expires_at", format_datetime(checkout.expires_at))
    |> maybe_add("continue_url", continue_url(checkout, base_url))
  end

  defp order_to_ucp(order) do
    %{
      "id" => order.id,
      "checkout_id" => order.checkout_id,
      "permalink_url" => Merchant.Store.Order.permalink_url(order),
      "status" => order.status,
      "currency" => order.currency,
      "line_items" => order.line_items,
      "totals" => order.totals,
      "buyer" => order.buyer,
      "shipping_address" => order.shipping_address,
      "fulfillment" => order.fulfillment || %{"expectations" => [], "events" => []},
      "adjustments" => order.adjustments || [],
      "metadata" => order.metadata || %{}
    }
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp product_to_ucp(product) do
    %{
      "id" => product.sku || product.id,
      "title" => product.title,
      "description" => product.description,
      "price" => product.price_cents,
      "currency" => "USD",
      "image_url" => product.image_url,
      "category" => product.category,
      "in_stock" => product.stock > 0,
      "stock" => product.stock
    }
  end

  defp parse_limit(nil, default), do: default
  defp parse_limit(limit, _default) when is_integer(limit), do: min(limit, 100)

  defp parse_limit(limit, default) when is_binary(limit) do
    case Integer.parse(limit) do
      {n, _} -> min(n, 100)
      :error -> default
    end
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp continue_url(%{status: status, id: id}, base_url)
       when status in ["incomplete", "ready_for_complete"] do
    base_url <> "/checkout/#{id}/pay"
  end

  defp continue_url(_, _), do: nil

  defp get_base_url(conn) do
    forwarded_proto = Plug.Conn.get_req_header(conn, "x-forwarded-proto") |> List.first()

    scheme =
      cond do
        forwarded_proto in ["https", "http"] -> forwarded_proto
        conn.scheme == :https -> "https"
        true -> "http"
      end

    port_suffix = if conn.port in [80, 443], do: "", else: ":#{conn.port}"

    if forwarded_proto == "https" do
      "#{scheme}://#{conn.host}"
    else
      "#{scheme}://#{conn.host}#{port_suffix}"
    end
  end
end
