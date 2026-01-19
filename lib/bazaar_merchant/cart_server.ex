defmodule Merchant.CartServer do
  @moduledoc """
  Simple in-memory cart storage for demo purposes.
  Uses an Agent with a Map - carts are lost on server restart.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_cart(cart_id) do
    Agent.get(__MODULE__, fn carts -> Map.get(carts, cart_id, %{}) end)
  end

  def put_cart(cart_id, cart) do
    Agent.update(__MODULE__, fn carts -> Map.put(carts, cart_id, cart) end)
    broadcast_update(cart_id, cart)
    cart
  end

  def add_item(cart_id, product, quantity) do
    Agent.get_and_update(__MODULE__, fn carts ->
      cart = Map.get(carts, cart_id, %{})
      item_id = product.id
      existing_qty = get_in(cart, [item_id, :quantity]) || 0
      new_qty = min(existing_qty + quantity, product.stock)

      updated_cart =
        Map.put(cart, item_id, %{
          id: product.id,
          sku: product.sku,
          title: product.title,
          price_cents: product.price_cents,
          image_url: product.image_url,
          quantity: new_qty,
          stock: product.stock
        })

      broadcast_update(cart_id, updated_cart)
      {updated_cart, Map.put(carts, cart_id, updated_cart)}
    end)
  end

  def update_quantity(cart_id, item_id, quantity) do
    Agent.get_and_update(__MODULE__, fn carts ->
      cart = Map.get(carts, cart_id, %{})

      updated_cart =
        case Map.get(cart, item_id) do
          nil -> cart
          item -> Map.put(cart, item_id, %{item | quantity: max(1, min(quantity, item.stock))})
        end

      broadcast_update(cart_id, updated_cart)
      {updated_cart, Map.put(carts, cart_id, updated_cart)}
    end)
  end

  def remove_item(cart_id, item_id) do
    Agent.get_and_update(__MODULE__, fn carts ->
      cart = Map.get(carts, cart_id, %{})
      updated_cart = Map.delete(cart, item_id)
      broadcast_update(cart_id, updated_cart)
      {updated_cart, Map.put(carts, cart_id, updated_cart)}
    end)
  end

  def clear_cart(cart_id) do
    put_cart(cart_id, %{})
  end

  def cart_count(cart_id) do
    get_cart(cart_id)
    |> Map.values()
    |> Enum.reduce(0, fn item, acc -> acc + item.quantity end)
  end

  def cart_total(cart_id) do
    get_cart(cart_id)
    |> Map.values()
    |> Enum.reduce(0, fn item, acc -> acc + item.price_cents * item.quantity end)
  end

  def subscribe(cart_id) do
    Phoenix.PubSub.subscribe(Merchant.PubSub, "cart:#{cart_id}")
  end

  defp broadcast_update(cart_id, cart) do
    Phoenix.PubSub.broadcast(Merchant.PubSub, "cart:#{cart_id}", {:cart_updated, cart})
  end
end
