# Bazaar Merchant

A demo/reference implementation of a UCP and ACP-compliant merchant using the [Bazaar SDK](../bazaar).

This Phoenix application demonstrates how to build an e-commerce API that AI shopping agents can interact with via both:
- **[UCP](https://ucp.dev)** (Universal Commerce Protocol) - Used by Google Shopping agents
- **[ACP](https://github.com/agentic-commerce-protocol/acp-spec)** (Agentic Commerce Protocol) - Used by OpenAI Operator and Stripe

## What This Demo Shows

- Implementing the `Bazaar.Handler` behaviour
- Serving both UCP and ACP from a single handler
- In-memory store for checkouts and orders (no database required)
- Complete checkout flow: create → update → complete
- Order management: get, cancel
- UCP discovery profile at `/ucp/.well-known/ucp`

## Quick Start

```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit `http://localhost:4000/ucp/.well-known/ucp` to see the UCP discovery profile.

## Validation Tools

### UCP Validator

Use the [@ucptools/validator](../ucp-tools) to validate your UCP profile:

```bash
cd ../ucp-tools

# Validate from a file (save profile first)
curl -s http://localhost:4000/ucp/.well-known/ucp > /tmp/ucp-profile.json
npm run validate -- validate -f /tmp/ucp-profile.json

# Output as JSON
npm run validate -- validate -f /tmp/ucp-profile.json --json

# Quick validation (no network checks for schema fetching)
npm run validate -- validate -f /tmp/ucp-profile.json -q
```

The validator checks:
- **Structural validation**: JSON structure, required fields, version format
- **UCP rules**: Namespace/origin binding, endpoint requirements (HTTPS), signing keys
- **Network validation**: Remote schema fetching and verification

Example output:
```json
{
  "ok": true,
  "ucp_version": "2026-01-11",
  "issues": [],
  "sdk_validation": { "compliant": true }
}
```

**Note**: Local development uses HTTP which the validator will flag. Production deployments should use HTTPS.

### Request/Response Validation

Bazaar includes built-in validation plugs for development:

```elixir
# In your router pipeline
pipeline :ucp do
  plug Bazaar.Plugs.ValidateRequest   # Validates incoming requests
  plug Bazaar.Plugs.ValidateResponse, # Validates outgoing responses
    strict: Application.compile_env(:bazaar_merchant, :strict_validation, false)
end
```

- **ValidateRequest**: Validates incoming request bodies against UCP schemas (e.g., `CheckoutCreateReq`)
- **ValidateResponse**: Validates outgoing response bodies against UCP schemas (e.g., `CheckoutResp`)

Set `strict_validation: true` in config to raise on validation failures (useful for development).

### ACP Validation

ACP requests and responses are automatically transformed by `Bazaar.Protocol.Transformer`:
- Requests: ACP format → UCP format (before handler)
- Responses: UCP format → ACP format (after handler)

No separate ACP validator is needed; the same UCP schemas validate the transformed data.

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

## Endpoints

### UCP Endpoints (at `/ucp`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/ucp/.well-known/ucp` | Discovery profile |
| POST | `/ucp/checkout-sessions` | Create checkout |
| GET | `/ucp/checkout-sessions/:id` | Get checkout |
| PATCH | `/ucp/checkout-sessions/:id` | Update checkout |
| DELETE | `/ucp/checkout-sessions/:id` | Cancel checkout |
| POST | `/ucp/checkout-sessions/:id/actions/complete` | Complete checkout |
| GET | `/ucp/orders/:id` | Get order |
| POST | `/ucp/orders/:id/actions/cancel` | Cancel order |

### ACP Endpoints (at `/acp`)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/acp/checkout_sessions` | Create checkout |
| GET | `/acp/checkout_sessions/:id` | Get checkout |
| POST | `/acp/checkout_sessions/:id` | Update checkout |
| POST | `/acp/checkout_sessions/:id/complete` | Complete checkout |
| POST | `/acp/checkout_sessions/:id/cancel` | Cancel checkout |

Note: ACP does not have a discovery endpoint. Merchants register with the centralized Stripe/OpenAI registry.

## Testing the Flow

### UCP Flow

1. Create a checkout:
```bash
curl -X POST http://localhost:4000/ucp/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "usd",
    "items": [{"sku": "DEMO-001", "quantity": 1}]
  }'
```

2. Update with buyer info:
```bash
curl -X PATCH http://localhost:4000/ucp/checkout-sessions/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "buyer": {
      "email": "buyer@example.com",
      "name": "Jane Doe",
      "shipping_address": {
        "street_address": "123 Main St",
        "address_locality": "San Francisco",
        "address_region": "CA",
        "postal_code": "94102",
        "address_country": "US"
      }
    }
  }'
```

3. Complete the checkout:
```bash
curl -X POST http://localhost:4000/ucp/checkout-sessions/{id}/actions/complete
```

### ACP Flow

1. Create a checkout:
```bash
curl -X POST http://localhost:4000/acp/checkout_sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "usd",
    "line_items": [{"product": {"id": "DEMO-001"}, "quantity": 1}]
  }'
```

2. Update with buyer info:
```bash
curl -X POST http://localhost:4000/acp/checkout_sessions/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "buyer": {
      "email": "buyer@example.com",
      "name": "Jane Doe",
      "shipping_address": {
        "line_one": "123 Main St",
        "city": "San Francisco",
        "state": "CA",
        "postal_code": "94102",
        "country": "US"
      }
    }
  }'
```

3. Complete the checkout:
```bash
curl -X POST http://localhost:4000/acp/checkout_sessions/{id}/complete
```

### Key Differences

| Aspect | UCP | ACP |
|--------|-----|-----|
| Items key | `items` | `line_items` |
| SKU field | `sku` | `product.id` |
| Update method | `PATCH` | `POST` |
| Status: incomplete | `incomplete` | `not_ready_for_payment` |
| Address: street | `street_address` | `line_one` |
| Address: city | `address_locality` | `city` |

## Related Projects

- [Bazaar](../bazaar) - The Elixir SDK for UCP and ACP
- [Smelter](../smelter) - JSON Schema to Elixir code generator
- [UCP Specification](https://ucp.dev) - Universal Commerce Protocol (Google)
- [ACP Specification](https://github.com/agentic-commerce-protocol/acp-spec) - Agentic Commerce Protocol (OpenAI/Stripe)
