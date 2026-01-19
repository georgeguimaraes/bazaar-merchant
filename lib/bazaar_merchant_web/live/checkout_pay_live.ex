defmodule MerchantWeb.CheckoutPayLive do
  @moduledoc """
  Mock payment page for checkout escalation flow.

  When an AI agent creates a checkout but can't complete payment,
  it returns a continue_url pointing here. The human can then
  complete the payment with mock card details.
  """

  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, to_form(%{"card_number" => "", "expiry" => "", "cvc" => ""}))
     |> assign(:processing, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Store.get_checkout(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Checkout not found")
         |> push_navigate(to: ~p"/")}

      %{status: "completed"} = checkout ->
        {:noreply,
         socket
         |> put_flash(:info, "This checkout has already been completed")
         |> push_navigate(to: ~p"/orders/#{checkout.order_id}")}

      %{status: "canceled"} ->
        {:noreply,
         socket
         |> put_flash(:error, "This checkout has been canceled")
         |> push_navigate(to: ~p"/")}

      checkout ->
        {:noreply,
         socket
         |> assign(:checkout, checkout)
         |> assign(:page_title, "Complete Payment")}
    end
  end

  @impl true
  def handle_event("validate", %{"card_number" => _, "expiry" => _, "cvc" => _} = params, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("submit_payment", params, socket) do
    socket = assign(socket, :processing, true)

    # Simulate payment processing delay
    Process.sleep(1000)

    checkout = socket.assigns.checkout
    card_number = params["card_number"] || ""

    payment_info = %{
      "method" => "card",
      "last_four" => String.slice(card_number, -4, 4)
    }

    case Store.complete_checkout(checkout, payment_info) do
      {:ok, {_checkout, order}} ->
        {:noreply,
         socket
         |> put_flash(:success, "Payment successful! Your order has been placed.")
         |> push_navigate(to: ~p"/orders/#{order.id}")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Payment failed. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center">
      <div class="container max-w-4xl mx-auto px-4 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Order Summary</h2>

              <div class="divide-y">
                <div
                  :for={item <- @checkout.line_items}
                  class="py-3 flex justify-between items-center"
                >
                  <div>
                    <p class="font-medium">{item["item"]["title"]}</p>
                    <p class="text-sm text-base-content/50">Qty: {item["quantity"]}</p>
                  </div>
                  <p class="font-mono">${format_price(get_item_total(item))}</p>
                </div>
              </div>

              <div class="divider"></div>

              <div class="space-y-2">
                <div :for={total <- @checkout.totals} class="flex justify-between">
                  <span class="capitalize">{total["type"]}</span>
                  <span class={"font-mono #{if total["type"] == "total", do: "font-bold text-lg"}"}>
                    ${format_price(total["amount"])}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Payment Details</h2>
              <p class="text-sm text-base-content/50 mb-4">
                This is a mock payment form. Enter any card number to complete the order.
              </p>

              <form phx-submit="submit_payment" phx-change="validate" class="space-y-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Card Number</span>
                  </label>
                  <input
                    type="text"
                    name="card_number"
                    placeholder="4242 4242 4242 4242"
                    class="input input-bordered"
                    value={@form.params["card_number"]}
                    required
                  />
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Expiry</span>
                    </label>
                    <input
                      type="text"
                      name="expiry"
                      placeholder="MM/YY"
                      class="input input-bordered"
                      value={@form.params["expiry"]}
                      required
                    />
                  </div>

                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">CVC</span>
                    </label>
                    <input
                      type="text"
                      name="cvc"
                      placeholder="123"
                      class="input input-bordered"
                      value={@form.params["cvc"]}
                      required
                    />
                  </div>
                </div>

                <div class="alert alert-info text-sm">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    class="stroke-current shrink-0 w-6 h-6"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    >
                    </path>
                  </svg>
                  <span>Test card: 4242 4242 4242 4242, any expiry/CVC</span>
                </div>

                <button
                  type="submit"
                  class={["btn btn-primary btn-block btn-lg", @processing && "loading"]}
                  disabled={@processing}
                >
                  {if @processing,
                    do: "Processing...",
                    else: "Pay $#{format_price(get_total(@checkout.totals))}"}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_price(cents) when is_integer(cents) do
    :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp format_price(_), do: "0.00"

  defp get_total(totals) when is_list(totals) do
    Enum.find_value(totals, 0, fn
      %{"type" => "total", "amount" => amount} -> amount
      _ -> nil
    end)
  end

  defp get_total(_), do: 0

  defp get_item_total(item) do
    case item["totals"] do
      [%{"amount" => amount} | _] -> amount
      _ -> 0
    end
  end
end
