defmodule Merchant.Repo.Migrations.CreateCheckouts do
  use Ecto.Migration

  def change do
    create table(:checkouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "incomplete"
      add :currency, :string, null: false
      add :line_items, :jsonb, null: false, default: "[]"
      add :totals, :jsonb, null: false, default: "[]"
      add :buyer, :jsonb
      add :shipping_address, :jsonb
      add :billing_address, :jsonb
      add :payment, :jsonb, default: "{}"
      add :messages, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"
      add :expires_at, :utc_datetime
      add :order_id, :binary_id

      timestamps()
    end

    create index(:checkouts, [:status])
    create index(:checkouts, [:inserted_at])
  end
end
