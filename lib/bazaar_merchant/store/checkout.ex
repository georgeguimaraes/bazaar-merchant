defmodule Merchant.Store.Checkout do
  @moduledoc "Checkout schema representing a shopping session."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(incomplete requires_escalation ready_for_complete complete_in_progress completed canceled)

  schema "checkouts" do
    field :status, :string, default: "incomplete"
    field :currency, :string
    field :line_items, {:array, :map}, default: []
    field :totals, {:array, :map}, default: []
    field :buyer, :map
    field :shipping_address, :map
    field :billing_address, :map
    field :payment, :map, default: %{"handlers" => []}
    field :messages, {:array, :map}, default: []
    field :metadata, :map, default: %{}
    field :expires_at, :utc_datetime

    # Reference to order when completed
    field :order_id, :binary_id

    timestamps()
  end

  def changeset(checkout, attrs) do
    checkout
    |> cast(attrs, [
      :status,
      :currency,
      :line_items,
      :totals,
      :buyer,
      :shipping_address,
      :billing_address,
      :payment,
      :messages,
      :metadata,
      :expires_at,
      :order_id
    ])
    |> validate_required([:currency, :line_items])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:line_items, min: 1)
  end

  def update_changeset(checkout, attrs) do
    checkout
    |> cast(attrs, [
      :status,
      :line_items,
      :totals,
      :buyer,
      :shipping_address,
      :billing_address,
      :payment,
      :messages,
      :metadata
    ])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses

  def ready_for_complete?(%__MODULE__{} = checkout) do
    has_buyer?(checkout) && has_shipping_address?(checkout)
  end

  defp has_buyer?(%{buyer: nil}), do: false

  defp has_buyer?(%{buyer: buyer}) do
    buyer["email"] != nil || buyer["phone_number"] != nil
  end

  defp has_shipping_address?(%{shipping_address: nil}), do: false

  defp has_shipping_address?(%{shipping_address: addr}) do
    has_street = addr["street_address"] != nil || addr["line1"] != nil
    has_postal = addr["postal_code"] != nil
    has_street && has_postal
  end
end
