defmodule WebdriveWeb.UploadSocket do
  use Phoenix.Socket

  channel "up:*", WebdriveWeb.UploadChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
