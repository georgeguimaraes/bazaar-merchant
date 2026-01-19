defmodule MerchantWeb.Admin.CheckoutsLive do
  use MerchantWeb, :live_view

  alias Merchant.Store

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Checkouts")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = params["status"]
    checkouts = Store.list_checkouts(status: status)

    {:noreply,
     socket
     |> assign(:checkouts, checkouts)
     |> assign(:selected_status, status)
     |> assign(:selected_checkout, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Checkouts</h1>
          <.link navigate={~p"/admin"} class="btn btn-ghost">Back to Dashboard</.link>
        </div>

        <div class="flex gap-2 mb-6 flex-wrap">
          <.link
            navigate={~p"/admin/checkouts"}
            class={["btn btn-sm", !@selected_status && "btn-primary"]}
          >
            All
          </.link>
          <.link
            :for={status <- ~w(incomplete ready_for_complete completed canceled)}
            navigate={~p"/admin/checkouts?status=#{status}"}
            class={["btn btn-sm", @selected_status == status && "btn-primary"]}
          >
            {status}
          </.link>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Status</th>
                    <th>Currency</th>
                    <th>Items</th>
                    <th>Total</th>
                    <th>Buyer</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={checkout <- @checkouts} class="hover">
                    <td class="font-mono text-xs">{String.slice(checkout.id, 0, 8)}...</td>
                    <td><.status_badge status={checkout.status} /></td>
                    <td>{checkout.currency}</td>
                    <td>{length(checkout.line_items)}</td>
                    <td>${format_price(get_total(checkout.totals))}</td>
                    <td>{get_buyer_email(checkout.buyer)}</td>
                    <td class="text-sm">{format_time(checkout.inserted_at)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%= if @checkouts == [] do %>
              <div class="text-center py-8">
                <p class="text-base-content/50">No checkouts found</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    color =
      case assigns.status do
        "completed" -> "success"
        "ready_for_complete" -> "info"
        "incomplete" -> "ghost"
        "canceled" -> "error"
        _ -> "ghost"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"badge badge-#{@color} badge-sm"}>{@status}</span>
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

  defp get_buyer_email(nil), do: "-"
  defp get_buyer_email(%{"email" => email}), do: email
  defp get_buyer_email(_), do: "-"

  defp format_time(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %H:%M")
  end

  defp format_time(_), do: "-"
end
