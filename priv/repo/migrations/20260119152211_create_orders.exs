defmodule Merchant.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :checkout_id, :binary_id, null: false
      add :status, :string, null: false, default: "pending"
      add :currency, :string, null: false
      add :line_items, :jsonb, null: false, default: "[]"
      add :totals, :jsonb, null: false, default: "[]"
      add :buyer, :jsonb
      add :shipping_address, :jsonb
      add :billing_address, :jsonb
      add :fulfillment, :jsonb, default: ~s({"expectations": [], "events": []})
      add :adjustments, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"
      add :payment_method, :string
      add :payment_last_four, :string

      timestamps()
    end

    create index(:orders, [:checkout_id])
    create index(:orders, [:status])
    create index(:orders, [:inserted_at])
  end
end
