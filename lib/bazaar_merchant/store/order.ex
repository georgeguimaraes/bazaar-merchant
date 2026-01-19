defmodule Merchant.Store.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending processing shipped delivered canceled refunded)

  schema "orders" do
    field :checkout_id, :binary_id
    field :status, :string, default: "pending"
    field :currency, :string
    field :line_items, {:array, :map}, default: []
    field :totals, {:array, :map}, default: []
    field :buyer, :map
    field :shipping_address, :map
    field :billing_address, :map
    field :fulfillment, :map, default: %{"expectations" => [], "events" => []}
    field :adjustments, {:array, :map}, default: []
    field :metadata, :map, default: %{}

    # Payment info (mock)
    field :payment_method, :string
    field :payment_last_four, :string

    timestamps()
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :checkout_id, :status, :currency, :line_items, :totals, :buyer,
      :shipping_address, :billing_address, :fulfillment, :adjustments,
      :metadata, :payment_method, :payment_last_four
    ])
    |> validate_required([:checkout_id, :currency, :line_items, :totals])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses

  def from_checkout(checkout, payment_info \\ %{}) do
    %__MODULE__{}
    |> changeset(%{
      checkout_id: checkout.id,
      currency: checkout.currency,
      line_items: checkout.line_items,
      totals: checkout.totals,
      buyer: checkout.buyer,
      shipping_address: checkout.shipping_address,
      billing_address: checkout.billing_address,
      metadata: checkout.metadata,
      payment_method: payment_info["method"] || "card",
      payment_last_four: payment_info["last_four"] || "4242"
    })
  end

  def permalink_url(%__MODULE__{id: id}) do
    MerchantWeb.Endpoint.url() <> "/orders/#{id}"
  end
end
