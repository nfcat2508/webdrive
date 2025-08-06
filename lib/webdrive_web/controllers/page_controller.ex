defmodule WebdriveWeb.PageController do
  use WebdriveWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
