defmodule Merchant.Repo do
  use Ecto.Repo,
    otp_app: :bazaar_merchant,
    adapter: Ecto.Adapters.Postgres
end
