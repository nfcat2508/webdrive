defmodule WebdriveWeb.FileSharingController do
  use WebdriveWeb, :controller

  alias Webdrive.Files
  alias WebdriveWeb.UserAuth

  def create(conn, params) do
    params
    |> Files.create_file_sharing(UserAuth.user_id(conn))
    |> case do
      {:ok, sharing} ->
        put_flash(
          conn,
          :info,
          gettext("Link to file: %{url}",
            url: url(~p"/sharings/#{sharing.identifier_user_param}")
          )
        )

      {:error, _} ->
        put_flash(
          conn,
          :error,
          gettext("error creating file sharing")
        )
    end
    |> redirect(to: ~p"/uploads")
  end

  def delete(conn, %{"id" => id}) do
    id
    |> Files.delete_file_sharing(UserAuth.user_id(conn))
    |> case do
      :ok -> put_flash(conn, :info, gettext("file sharing deleted"))
      :error -> put_flash(conn, :error, gettext("invalid request"))
    end
    |> redirect(to: ~p"/uploads")
  end
end
