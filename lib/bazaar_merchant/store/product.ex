defmodule Merchant.Store.Product do
  @moduledoc "Product schema representing an item available for purchase."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "products" do
    field :sku, :string
    field :title, :string
    field :description, :string
    field :price_cents, :integer
    field :image_url, :string
    field :stock, :integer, default: 100
    field :category, :string
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :sku,
      :title,
      :description,
      :price_cents,
      :image_url,
      :stock,
      :category,
      :active
    ])
    |> validate_required([:sku, :title, :price_cents])
    |> validate_number(:price_cents, greater_than: 0)
    |> validate_number(:stock, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
  end

  def price_dollars(%__MODULE__{price_cents: cents}) do
    cents / 100
  end
end
