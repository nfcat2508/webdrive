defmodule WebdriveWeb.UploadController do
  use WebdriveWeb, :controller

  alias Webdrive.Files
  alias WebdriveWeb.{ActionReporting, UserAuth}

  def index(conn, _params) do
    uploads = Files.available_uploads(sharing_id(conn), UserAuth.user_id(conn))

    render(conn, :index,
      uploads: uploads,
      actions: authorized_actions(sharing_id(conn))
    )
  end

  defp sharing_id(conn) do
    conn.assigns[:sharing_id]
  end

  defp authorized_actions(nil) do
    [:download, :delete, :share, :info]
  end

  defp authorized_actions(_sharing_id) do
    [:download]
  end

  def show(conn, %{"id" => id}) do
    case(Files.get_upload(id, sharing_id(conn), UserAuth.user_id(conn))) do
      {:sus, message} ->
        conn
        |> ActionReporting.suspect_conn(message)
        |> redirect(to: ~p"/uploads")

      {path, name} ->
        send_download(conn, {:file, path}, filename: name)

      _ ->
        redirect(conn, to: ~p"/uploads")
    end
  end

  def delete(conn, %{"id" => id}) do
    if Files.delete_upload(id, UserAuth.user_id(conn)) == :ok do
      flash_with_redirect(
        conn,
        :info,
        gettext("file deleted successfully"),
        ~p"/uploads"
      )
    else
      conn
      |> ActionReporting.suspect_conn("error deleting #{id}")
      |> flash_with_redirect(
        :error,
        gettext("no file deleted"),
        ~p"/uploads"
      )
    end
  end

  defp flash_with_redirect(conn, key, message, redirect_target) do
    conn
    |> put_flash(key, message)
    |> redirect(to: redirect_target)
  end
end
