defmodule Merchant.Store do
  @moduledoc """
  The Store context - manages products, checkouts, and orders.
  """

  import Ecto.Query
  alias Merchant.Repo
  alias Merchant.Store.{Product, Checkout, Order}

  # Products

  def list_products(opts \\ []) do
    Product
    |> filter_active(Keyword.get(opts, :active, true))
    |> filter_category(Keyword.get(opts, :category))
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  defp filter_active(query, nil), do: query
  defp filter_active(query, true), do: where(query, [p], p.active == true)
  defp filter_active(query, false), do: query

  defp filter_category(query, nil), do: query
  defp filter_category(query, category), do: where(query, [p], p.category == ^category)

  def get_product(id), do: Repo.get(Product, id)

  def get_product!(id), do: Repo.get!(Product, id)

  def get_product_by_sku(sku), do: Repo.get_by(Product, sku: sku)

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def product_categories do
    Product
    |> select([p], p.category)
    |> distinct(true)
    |> where([p], not is_nil(p.category))
    |> Repo.all()
  end

  # Checkouts

  def list_checkouts(opts \\ []) do
    Checkout
    |> filter_checkout_status(Keyword.get(opts, :status))
    |> order_by([c], desc: c.inserted_at)
    |> limit(^Keyword.get(opts, :limit, 100))
    |> Repo.all()
  end

  defp filter_checkout_status(query, nil), do: query
  defp filter_checkout_status(query, status), do: where(query, [c], c.status == ^status)

  def get_checkout(id), do: Repo.get(Checkout, id)

  def get_checkout!(id), do: Repo.get!(Checkout, id)

  def create_checkout(attrs) do
    # Enrich line items with product data
    line_items = enrich_line_items(attrs["line_items"] || attrs[:line_items] || [])
    totals = calculate_totals(line_items, attrs["currency"] || attrs[:currency])

    # Set expiration (24 hours from now)
    expires_at = DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:second)

    checkout_attrs =
      attrs
      |> Map.put("line_items", line_items)
      |> Map.put("totals", totals)
      |> Map.put("expires_at", expires_at)
      |> Map.put("payment", %{
        "handlers" => [
          %{"type" => "card", "name" => "Credit/Debit Card"},
          %{"type" => "mock_pay", "name" => "Mock Pay (Test)"}
        ]
      })

    %Checkout{}
    |> Checkout.changeset(checkout_attrs)
    |> Repo.insert()
  end

  def update_checkout(%Checkout{status: "completed"}, _attrs) do
    {:error, :already_completed}
  end

  def update_checkout(%Checkout{status: "canceled"}, _attrs) do
    {:error, :already_canceled}
  end

  def update_checkout(%Checkout{} = checkout, attrs) do
    # Recalculate totals if line items changed
    attrs = if attrs["line_items"] do
      line_items = enrich_line_items(attrs["line_items"])
      totals = calculate_totals(line_items, checkout.currency)
      attrs
      |> Map.put("line_items", line_items)
      |> Map.put("totals", totals)
    else
      attrs
    end

    # Determine new status based on completeness
    attrs = update_checkout_status(checkout, attrs)

    checkout
    |> Checkout.update_changeset(attrs)
    |> Repo.update()
  end

  defp update_checkout_status(checkout, attrs) do
    updated = struct(checkout, atomize_keys(attrs))

    new_status = cond do
      Checkout.ready_for_complete?(updated) -> "ready_for_complete"
      true -> "incomplete"
    end

    Map.put(attrs, "status", new_status)
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    _ -> %{}
  end

  def cancel_checkout(%Checkout{status: "completed"}) do
    {:error, :already_completed}
  end

  def cancel_checkout(%Checkout{status: "canceled"} = checkout) do
    {:ok, checkout}
  end

  def cancel_checkout(%Checkout{} = checkout) do
    checkout
    |> Checkout.update_changeset(%{"status" => "canceled"})
    |> Repo.update()
  end

  def complete_checkout(%Checkout{status: status}) when status not in ["ready_for_complete", "incomplete"] do
    {:error, :invalid_status}
  end

  def complete_checkout(%Checkout{} = checkout, payment_info \\ %{}) do
    Repo.transaction(fn ->
      # Create order
      order_changeset = Order.from_checkout(checkout, payment_info)
      {:ok, order} = Repo.insert(order_changeset)

      # Update checkout
      {:ok, updated_checkout} = checkout
        |> Checkout.update_changeset(%{"status" => "completed", "order_id" => order.id})
        |> Repo.update()

      {updated_checkout, order}
    end)
  end

  # Orders

  def list_orders(opts \\ []) do
    Order
    |> filter_order_status(Keyword.get(opts, :status))
    |> order_by([o], desc: o.inserted_at)
    |> limit(^Keyword.get(opts, :limit, 100))
    |> Repo.all()
  end

  defp filter_order_status(query, nil), do: query
  defp filter_order_status(query, status), do: where(query, [o], o.status == ^status)

  def get_order(id), do: Repo.get(Order, id)

  def get_order!(id), do: Repo.get!(Order, id)

  def cancel_order(%Order{status: status}) when status in ["shipped", "delivered"] do
    {:error, :cannot_cancel_shipped}
  end

  def cancel_order(%Order{status: "canceled"} = order) do
    {:ok, order}
  end

  def cancel_order(%Order{} = order) do
    order
    |> Order.changeset(%{status: "canceled"})
    |> Repo.update()
  end

  def update_order_status(%Order{} = order, status) do
    order
    |> Order.changeset(%{status: status})
    |> Repo.update()
  end

  # Helpers

  defp enrich_line_items(line_items) do
    Enum.map(line_items, fn li ->
      item_id = get_in(li, ["item", "id"]) || get_in(li, [:item, :id])
      quantity = li["quantity"] || li[:quantity] || 1

      case get_product_by_sku(item_id) || get_product(item_id) do
        nil ->
          # Product not found, return as-is with error
          %{
            "item" => %{"id" => item_id, "title" => "Unknown Product", "price" => 0},
            "quantity" => quantity,
            "totals" => [%{"type" => "subtotal", "amount" => 0}]
          }

        product ->
          subtotal = product.price_cents * quantity
          %{
            "item" => %{
              "id" => product.sku || product.id,
              "title" => product.title,
              "price" => product.price_cents,
              "image_url" => product.image_url
            },
            "quantity" => quantity,
            "totals" => [%{"type" => "subtotal", "amount" => subtotal}]
          }
      end
    end)
  end

  defp calculate_totals(line_items, _currency) do
    subtotal = Enum.reduce(line_items, 0, fn li, acc ->
      item_subtotal = get_in(li, ["totals", Access.at(0), "amount"]) || 0
      acc + item_subtotal
    end)

    # Mock tax calculation (8%)
    tax = round(subtotal * 0.08)

    # Mock shipping (free over $50, otherwise $5.99)
    shipping = if subtotal >= 5000, do: 0, else: 599

    total = subtotal + tax + shipping

    totals = [
      %{"type" => "subtotal", "amount" => subtotal},
      %{"type" => "tax", "amount" => tax}
    ]

    totals = if shipping > 0 do
      totals ++ [%{"type" => "fulfillment", "amount" => shipping}]
    else
      totals
    end

    totals ++ [%{"type" => "total", "amount" => total}]
  end

  # Stats for dashboard

  def checkout_stats do
    from(c in Checkout,
      select: %{
        total: count(c.id),
        incomplete: count(fragment("CASE WHEN status = 'incomplete' THEN 1 END")),
        completed: count(fragment("CASE WHEN status = 'completed' THEN 1 END")),
        canceled: count(fragment("CASE WHEN status = 'canceled' THEN 1 END"))
      }
    )
    |> Repo.one()
  end

  def order_stats do
    from(o in Order,
      select: %{
        total: count(o.id),
        pending: count(fragment("CASE WHEN status = 'pending' THEN 1 END")),
        processing: count(fragment("CASE WHEN status = 'processing' THEN 1 END")),
        shipped: count(fragment("CASE WHEN status = 'shipped' THEN 1 END")),
        delivered: count(fragment("CASE WHEN status = 'delivered' THEN 1 END"))
      }
    )
    |> Repo.one()
  end

  def revenue_total do
    from(o in Order,
      where: o.status not in ["canceled", "refunded"],
      select: sum(fragment("(totals->-1->>'amount')::integer"))
    )
    |> Repo.one() || 0
  end
end
