defmodule WebdriveWeb.UploadLive do
  use WebdriveWeb, :live_view

  alias Phoenix.LiveView.UploadConfig
  alias WebdriveWeb.ActionReporting
  alias Webdrive.Files

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    peer_data = get_connect_info(socket, :peer_data)

    {:ok,
     socket
     |> assign(remote_ip: peer_data.address)
     |> assign(form: to_form(%{"encrypt" => true}))
     |> assign(pass_entered: false)
     |> assign(with_encryption: true)
     |> allow_upload(:files,
       accept: :any,
       max_file_size: 850_000_000,
       max_entries: 3,
       external: &presign_upload/2
     )}
  end

  defp presign_upload(entry, socket) do
    meta = %{
      uploader: "UpEnc",
      token: create_token(socket, entry)
    }

    {:ok, meta, socket}
  end

  defp create_token(socket, entry) do
    conf = socket.assigns.uploads.files

    Phoenix.LiveView.Static.sign_token(
      socket.endpoint,
      %{
        pid: self(),
        ref: {conf.ref, entry.ref},
        cid: conf.cid
      }
    )
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    with_encryption = params["encrypt"] == "true"
    socket = assign(socket, with_encryption: with_encryption)

    if with_encryption do
      if !socket.assigns.pass_entered do
        {:noreply, push_event(socket, "enter_pass", %{})}
      else
        {:noreply, socket}
      end
    else
      {:noreply,
       socket
       |> assign(pass_entered: false)
       |> push_event("remove_pass", %{})}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("has-pass", _params, socket) do
    {:noreply, assign(socket, pass_entered: true)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    conf = socket.assigns.uploads.files

    conf.entries
    |> Enum.map(fn entry ->
      {entry, UploadConfig.entry_pid(conf, entry)}
    end)
    |> Enum.filter(fn {_entry, pid} -> is_pid(pid) end)
    |> Enum.map(fn {entry, pid} ->
      Phoenix.LiveView.UploadChannel.consume(pid, entry, fn %{path: path}, entry ->
        consume_entry(path, entry, socket)
      end)
    end)
    |> Keyword.filter(fn {key, _val} -> key != :ok end)
    |> log(socket.assigns.remote_ip)

    {:noreply, redirect(socket, to: ~p"/uploads")}
  end

  defp consume_entry(path, entry, socket) do
    result =
      entry
      |> to_upload_params(path, socket.assigns.pass_entered)
      |> Files.create_upload_from_params(socket.assigns.current_user.email)

    {:ok, result}
  end

  defp to_upload_params(entry, path, encrypted) do
    %{
      filename: entry.client_name,
      path: path,
      content_type: entry.client_type,
      encrypted: encrypted
    }
  end

  defp log(errors, remote_ip) do
    if errors != [] do
      ActionReporting.suspect(remote_ip, "Upload error: #{inspect(errors)}")
    end
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(whatever), do: "Error: #{whatever}"
end
