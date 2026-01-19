defmodule Merchant.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sku, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :price_cents, :integer, null: false
      add :image_url, :string
      add :stock, :integer, default: 100
      add :category, :string
      add :active, :boolean, default: true

      timestamps()
    end

    create unique_index(:products, [:sku])
    create index(:products, [:category])
    create index(:products, [:active])
  end
end
