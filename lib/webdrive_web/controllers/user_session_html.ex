defmodule WebdriveWeb.UserSessionHTML do
  @moduledoc """
  The User Session HTML module.
  """

  use WebdriveWeb, :html

  attr :id, :string, default: nil
  attr :error_message, :string, default: nil

  def new(assigns) do
    ~H"""
    <h1>{gettext("Password protected file")}</h1>

    <%= if @error_message do %>
      <div class="bg-rose-50 p-3 text-rose-900 shadow-md ring-rose-500 fill-rose-900">
        <p>{@error_message}</p>
      </div>
    <% end %>

    <.simple_form :let={f} for={%{"id" => @id}} action={~p"/sharings"}>
      <.input type="password" field={f[:secret]} label={gettext("Password")} required={true} />
      <.input type="hidden" field={f[:id]} required={true} />
      <:actions>
        <input type="submit" value={gettext("Unlock")} />
      </:actions>
    </.simple_form>
    """
  end
end
