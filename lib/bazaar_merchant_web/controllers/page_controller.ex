defmodule MerchantWeb.PageController do
  use MerchantWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/")
  end

  def privacy(conn, _params) do
    render(conn, :privacy, page_title: "Privacy Policy")
  end

  def terms(conn, _params) do
    render(conn, :terms, page_title: "Terms of Service")
  end
end
