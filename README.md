# Bazaar Merchant

A demo/reference implementation of a UCP-compliant merchant using the [Bazaar SDK](../bazaar).

This Phoenix application demonstrates how to build an e-commerce API that AI shopping agents can interact with via the [Universal Commerce Protocol (UCP)](https://ucp.dev).

## What This Demo Shows

- Implementing the `Bazaar.Handler` behaviour
- In-memory store for checkouts and orders (no database required)
- Complete checkout flow: create → update → complete
- Order management: get, cancel
- UCP discovery profile at `/.well-known/ucp`

## Quick Start

```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit `http://localhost:4000/.well-known/ucp` to see the discovery profile.

## Validating with ucp-tools

Use the [ucp-tools CLI](https://github.com/user/ucp-tools) to validate your implementation:

```bash
# Validate the discovery profile
ucp validate profile http://localhost:4000

# Run checkout flow tests (if available)
ucp test checkout http://localhost:4000
```

Note: Local development uses HTTP. Production deployments should use HTTPS.

## Project Structure

```
lib/bazaar_merchant/
├── ucp_handler.ex           # Bazaar.Handler implementation
├── store/                   # In-memory data store
│   ├── checkout.ex          # Checkout struct and logic
│   ├── order.ex             # Order struct and logic
│   └── store.ex             # GenServer for state management
└── ...
```

## Handler Implementation

The core of the implementation is `Merchant.UCPHandler`:

```elixir
defmodule Merchant.UCPHandler do
  use Bazaar.Handler

  @impl true
  def capabilities, do: [:checkout, :orders]

  @impl true
  def business_profile do
    %{
      "name" => "Bazaar Merchant Demo",
      "description" => "A demo store showcasing the Bazaar SDK for UCP",
      "support_email" => "support@bazaar-merchant.example"
    }
  end

  @impl true
  def create_checkout(params, conn) do
    # Your checkout creation logic
  end

  # ... other callbacks
end
```

## UCP Endpoints

The router mounts these endpoints via `bazaar_routes/2`:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/.well-known/ucp` | Discovery profile |
| POST | `/checkout-sessions` | Create checkout |
| GET | `/checkout-sessions/:id` | Get checkout |
| PATCH | `/checkout-sessions/:id` | Update checkout |
| DELETE | `/checkout-sessions/:id` | Cancel checkout |
| POST | `/checkout-sessions/:id/complete` | Complete checkout |
| GET | `/orders/:id` | Get order |
| POST | `/orders/:id/actions/cancel` | Cancel order |

## Testing the Flow

1. Create a checkout:
```bash
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "USD",
    "line_items": [{
      "item": {"id": "SKU-001", "title": "Widget", "price": 1999},
      "quantity": 1,
      "totals": [{"type": "subtotal", "amount": 1999}]
    }],
    "totals": [{"type": "total", "amount": 1999}]
  }'
```

2. Update with buyer info:
```bash
curl -X PATCH http://localhost:4000/checkout-sessions/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "buyer": {
      "email": "buyer@example.com",
      "first_name": "Jane",
      "last_name": "Doe"
    }
  }'
```

3. Complete the checkout:
```bash
curl -X POST http://localhost:4000/checkout-sessions/{id}/complete
```

## Related Projects

- [Bazaar](../bazaar) - The Elixir SDK for UCP
- [Smelter](../smelter) - JSON Schema to Elixir code generator
- [UCP Specification](https://ucp.dev) - The Universal Commerce Protocol
