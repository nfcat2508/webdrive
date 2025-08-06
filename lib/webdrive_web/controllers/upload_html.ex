defmodule WebdriveWeb.UploadHTML do
  @moduledoc """
  The Upload HTML module.
  """

  use WebdriveWeb, :html

  require Integer

  alias Webdrive.Files

  @display_filename_max_length 34
  embed_templates "upload_html/*"

  attr :upload, Webdrive.Files.Upload
  attr :action, :string

  def action_link(%{action: :download} = assigns) do
    ~H"""
    <.link :if={!@upload.encrypted} navigate={~p"/uploads/#{@upload.id}"}>
      <.icon name="hero-arrow-down-tray" class="h-12 w-12" />
    </.link>
    <button :if={@upload.encrypted} phx-click={show_modal("dpm#{@upload.id}")}>
      <.icon name="hero-arrow-down-tray" class="h-12 w-12" />
    </button>
    """
  end

  def action_link(%{action: :delete} = assigns) do
    ~H"""
    <.link href={~p"/uploads/#{@upload.id}"} method="delete" data-confirm={gettext("Are you sure?")}>
      <.icon name="hero-trash" class="h-12 w-12" />
    </.link>
    """
  end

  def action_link(%{action: :share} = assigns) do
    ~H"""
    <.link phx-click={show_modal("sharing#{@upload.id}")}>
      <.icon name="hero-share" class="h-12 w-12" />
    </.link>
    """
  end

  def action_link(%{action: :info} = assigns) do
    ~H"""
    <button phx-click={show_modal("info#{@upload.id}")}>
      <.icon name="hero-information-circle" class="h-12 w-12" />
    </button>
    """
  end

  attr :upload_id, :string

  def sharing_modal(assigns) do
    ~H"""
    <.modal id={"sharing#{@upload_id}"}>
      {gettext("Enter password")}
      <.simple_form :let={f} for={%{}} action={~p"/uploads/#{@upload_id}/sharings"}>
        <.input
          id={"pw#{@upload_id}"}
          type="password"
          field={f[:secret]}
          label={gettext("Password")}
          required={true}
        />
        <div class="text-xs text-left">
          <span class="font-bold">{gettext("Password requirements:")}</span>
          <ul>
            <li>{gettext("min length: 12")}</li>
            <li>{gettext("at least one lower case character")}</li>
            <li>{gettext("at least one upper case character")}</li>
            <li>{gettext("at least one digit or punctuation character")}</li>
          </ul>
        </div>
        <:actions>
          <.button>{gettext("Create link")}</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  attr :upload, :any

  def info_modal(assigns) do
    ~H"""
    <.modal id={"info#{@upload.id}"}>
      <div class="flex flex-col gap-4 text-left">
        <.property name={gettext("Name")} value={@upload.name} />
        <.property name={gettext("Content-Type")} value={@upload.content_type || gettext("unknown")} />
        <.property name={gettext("Size")} value={Files.human_readable_size(@upload.size)} />
        <.property name={gettext("Encrypted")} value={@upload.encrypted} />
        <.property
          :if={@upload.sharing}
          name={gettext("Public Link")}
          value={
            url(
              WebdriveWeb.Endpoint,
              ~p"/sharings/#{Base.url_encode64(@upload.sharing.identifier, padding: false)}"
            )
          }
        />
      </div>
    </.modal>
    """
  end

  attr :name, :string, required: true
  attr :value, :any, required: true

  defp property(assigns) do
    ~H"""
    <div>
      <div class="font-bold text-xs sm:text-sm">{"#{@name}:"}</div>
      <div class="text-sm sm:text-base text-ellipsis overflow-hidden">{@value}</div>
    </div>
    """
  end

  defp even?(x), do: Integer.is_even(x)

  defp truncate(<<s::binary-size(@display_filename_max_length), _rest::binary>>), do: "#{s}..."
  defp truncate(s), do: s

  defp progress_id(id), do: "pe#{id}"

  defp error_id(id), do: "ee#{id}"
end
