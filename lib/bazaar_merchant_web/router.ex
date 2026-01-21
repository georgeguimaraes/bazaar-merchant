defmodule MerchantWeb.Router do
  use MerchantWeb, :router
  use Bazaar.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MerchantWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :ucp do
    plug Bazaar.Plugs.UCPHeaders
    plug Bazaar.Plugs.Idempotency
  end

  # UCP API routes (Google agents)
  scope "/ucp" do
    pipe_through [:api, :ucp]
    bazaar_routes("/", Merchant.UCPHandler)
  end

  # ACP API routes (OpenAI/Stripe agents)
  scope "/acp" do
    pipe_through :api
    bazaar_routes("/", Merchant.UCPHandler, protocol: :acp)
  end

  # Web routes (for humans)
  scope "/", MerchantWeb do
    pipe_through :browser

    # Home / Product catalog
    live "/", HomeLive, :index
    live "/products/:id", ProductLive, :show

    # Cart
    live "/cart", CartLive, :index

    # Checkout payment (escalation URL)
    live "/checkout/:id/pay", CheckoutPayLive, :pay

    # Order confirmation
    live "/orders/:id", OrderLive, :show

    # Static pages
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
  end

  # Admin dashboard
  scope "/admin", MerchantWeb do
    pipe_through :browser

    live "/", Admin.DashboardLive, :index
    live "/checkouts", Admin.CheckoutsLive, :index
    live "/checkouts/:id", Admin.CheckoutsLive, :show
    live "/orders", Admin.OrdersLive, :index
    live "/orders/:id", Admin.OrdersLive, :show
    live "/products", Admin.ProductsLive, :index
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:bazaar_merchant, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MerchantWeb.Telemetry
    end
  end
end
