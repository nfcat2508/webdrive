defmodule WebdriveWeb.ProjectComponents do
  @moduledoc """
    Provides project specific UI components.
  """

  use Phoenix.Component

  use Gettext, backend: WebdriveWeb.Gettex

  import WebdriveWeb.CoreComponents, only: [modal: 1, button: 1, icon: 1, hide_modal: 2]

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :subject, :string, default: nil

  def enc_pass_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <div>
        <div>{@subject}</div>
        <input
          id={input_id(@id)}
          type="password"
          value=""
          placeholder="please enter..."
          phx-hook="BlurOnEnter"
        />
        <.button
          id={button_id(@id)}
          type="button"
          phx-hook="FinishPass"
          data-input_id={input_id(@id)}
          data-modal_id={@id}
        >
          OK
        </.button>
      </div>
    </.modal>
    """
  end

  attr :id, :string, required: true
  attr :subject, :string, default: nil
  attr :upload, :any, required: true
  attr :url, :string, required: true
  attr :progress_id, :string, required: true
  attr :error_id, :string, required: true

  def dec_pass_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <div>
        <div>{@subject}</div>
        <div class="flex gap-x-2 mt-4">
          <div class="bg-lime-100 w-1/2 h-48 flex flex-col justify-between">
            <div>Download and decrypt in your browser</div>
            <input
              id={input_id(@id)}
              type="password"
              value=""
              class="w-full text-center"
              placeholder="please enter..."
              phx-hook="BlurOnEnter"
            />
            <button
              id={"dl-#{@upload.id}"}
              phx-hook="Download"
              data-url={@url}
              data-name={@upload.name}
              data-size={@upload.size}
              data-input_id={input_id(@id)}
              data-progress_id={@progress_id}
              phx-setup={setup_download(@error_id, @id, @progress_id)}
              phx-teardown={JS.hide(to: "##{@progress_id}")}
              phx-error={JS.show(to: "##{@error_id}")}
            >
              <.icon name="hero-arrow-down-tray" class="h-12 w-12" />
            </button>
          </div>
          <div class="bg-sky-100 w-1/2 h-48 flex flex-col justify-between">
            <div>Download encrypted file (decrypt it later by external tools)</div>
            <.link navigate={@url}>
              <.icon name="hero-arrow-down-tray" class="h-12 w-12" />
            </.link>
          </div>
        </div>
      </div>
    </.modal>
    """
  end

  defp input_id(id), do: "ipt#{id}"

  defp button_id(id), do: "btn#{id}"

  defp setup_download(error_id, modal_id, progress_id) do
    JS.hide(to: "##{error_id}")
    |> hide_modal(modal_id)
    |> JS.show(to: "##{progress_id}")
  end
end
