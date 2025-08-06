defmodule WebdriveWeb.UploadControllerTest do
  use WebdriveWeb.ConnCase

  import ExUnit.CaptureLog
  import Webdrive.FilesFixtures

  alias Webdrive.AccountsFixtures
  alias Webdrive.Files.Upload

  @moduletag :tmp_dir

  setup %{
    conn: conn
  } do
    user = AccountsFixtures.user_fixture()

    %{
      conn_authenticated: conn |> log_in_user(user),
      conn_unauthenticated: init_test_session(conn, %{}),
      user: user
    }
  end

  describe "Get /uploads/" do
    test "not accessible if neither authenticated nor authorised for shared file", %{
      conn_unauthenticated: conn
    } do
      # when
      conn_result = get_uploads(conn)

      # then user is redirected to login page
      assert redirected_to(conn_result) == ~p"/users/log_in"
    end

    test "returns no file if no files available", %{conn_authenticated: conn} do
      conn = get_uploads(conn)

      refute html_response(conn, 200) =~ "down"
    end

    test "returns links for download, delete, info and share uploaded file if authenticated", %{
      conn_authenticated: conn,
      user: user
    } do
      existing_upload = upload_fixture(%{owner: user.email})

      conn = get_uploads(conn)

      actual_body = assert html_response(conn, 200)
      assert actual_body =~ simple_download_link(existing_upload)
      assert actual_body =~ delete_link(existing_upload)
      assert actual_body =~ share_link(existing_upload)
      assert actual_body =~ info_button(existing_upload)
    end

    test "returns an additional download button when uploaded file is encrypted", %{
      conn_authenticated: conn,
      user: user
    } do
      existing_upload = upload_fixture(%{owner: user.email, encrypted: true})

      conn = get_uploads(conn)

      actual_body = assert html_response(conn, 200)
      assert actual_body =~ download_button(existing_upload)
      assert actual_body =~ simple_download_link(existing_upload)
    end

    test "returns shared file for download only, if :sharing_id in session", %{
      conn_unauthenticated: conn
    } do
      # given two uploads where one is shared
      existing_unshared_upload = upload_fixture()
      existing_shared_upload = upload_fixture()

      existing_sharing =
        file_sharing_fixture(
          %{upload_id: existing_shared_upload.id},
          existing_shared_upload.owner
        )

      # given user entered correct sharing ID and password (hence, having authorized sharing_id in session)
      conn = put_session(conn, :sharing_id, existing_sharing.identifier)

      # when user get uploads
      conn = get_uploads(conn)

      # then only the shared upload must be present which can be downloaded, but neither deleted, nor shared
      actual_body = assert html_response(conn, 200)
      refute actual_body =~ simple_download_link(existing_unshared_upload)
      assert actual_body =~ simple_download_link(existing_shared_upload)
      refute actual_body =~ delete_link(existing_shared_upload)
      refute actual_body =~ share_link(existing_shared_upload)
      refute actual_body =~ info_button(existing_shared_upload)
    end
  end

  describe "Get /uploads/:id" do
    test "not accessible if neither authenticated nor authorised for shared file", %{
      conn_unauthenticated: conn,
      tmp_dir: tmp_dir
    } do
      # given a shared file
      {upload, _} = create_shared_upload(tmp_dir, "content")

      # when called but user is neither authenticated nor authorized for shared file access
      conn_result = get(conn, "/uploads/#{upload.id}")

      # then user is redirected to login page
      assert redirected_to(conn_result) == ~p"/users/log_in"
    end

    test "with valid, shared ID gets the matching file for download", %{
      conn_unauthenticated: conn,
      tmp_dir: tmp_dir
    } do
      content = "meow from test"
      {upload, sharing} = create_shared_upload(tmp_dir, content)

      conn = put_session(conn, :sharing_id, sharing.identifier)

      conn_result = get(conn, "/uploads/#{upload.id}")

      assert response(conn_result, 200) == content
      assert response_content_type(conn_result, :text) == "text/plain"
    end

    test "redirects to index page, if requested file is not shared to user", %{
      conn_unauthenticated: conn,
      tmp_dir: tmp_dir
    } do
      content = "meow from test"
      {upload, _} = create_shared_upload(tmp_dir, content)

      # given user is authorized to access a specific shared file
      conn = put_session(conn, :sharing_id, create_sharing_id())

      # but user requests a different file
      {conn, log} =
        with_log(fn ->
          get(conn, "/uploads/#{upload.id}")
        end)

      # then download is rejected - user is redirected back to index page
      assert redirected_to(conn) == ~p"/uploads"
      # and a warning is logged
      assert suspicious_action_logged(log, "access not allowed")
    end
  end

  describe "Delete /uploads/:id" do
    test "not accessible if not authenticated", %{
      conn_unauthenticated: conn,
      tmp_dir: tmp_dir
    } do
      {_, upload} = create_file_and_upload(tmp_dir)

      conn_result = delete(conn, "/uploads/#{upload.id}")

      # then user is redirected to login page
      assert redirected_to(conn_result) == ~p"/users/log_in"
    end

    test "deletes entry successfully", %{conn_authenticated: conn, tmp_dir: tmp_dir, user: user} do
      {_, upload} = create_file_and_upload(tmp_dir, user.email)

      conn_result = delete(conn, "/uploads/#{upload.id}")

      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["info"] == "file deleted successfully"

      conn_result = get(conn, ~p"/uploads")
      actual_body = assert html_response(conn_result, 200)
      refute actual_body =~ upload.name
    end

    test "deletes the corresponding local file", %{
      conn_authenticated: conn,
      tmp_dir: tmp_dir,
      user: user
    } do
      {_, upload} = create_file_and_upload(tmp_dir, user.email)

      delete(conn, "/uploads/#{upload.id}")

      local_filename = Upload.local_path(upload.id, upload.name)
      refute File.exists?(local_filename)
    end

    test "returns error if unknown ID provided", %{conn_authenticated: conn} do
      {conn_result, log} =
        with_log(fn -> delete(conn, "/uploads/23") end)

      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["error"] == "no file deleted"
      assert suspicious_action_logged(log, "error deleting 23")
    end
  end

  defp get_uploads(conn), do: get(conn, "/uploads")

  defp create_file_and_upload(target_dir, owner \\ "test_owner") do
    filename = "#{target_dir}/test.txt"

    {:ok, upload} =
      file_with_content(filename)
      |> prepare_upload_params()
      |> Webdrive.Files.create_upload_from_params(owner)

    {filename, upload}
  end

  defp simple_download_link(upload) do
    ~r(<a href="/uploads/#{upload.id}".*data-phx-link="redirect")
  end

  defp download_button(upload) do
    ~r(<button id="dl-#{upload.id}" phx-hook="Download" data-url="/uploads/#{upload.id}")
  end

  defp delete_link(upload) do
    ~r(<a href="/uploads/#{upload.id}".*data-method="delete")
  end

  defp share_link(upload) do
    ~r(#sharing#{upload.id})
  end

  defp info_button(upload) do
    ~r(<button.*#info#{upload.id})
  end

  defp create_sharing_id do
    upload_fixture()
    |> file_sharing_fixture()
    |> Map.get(:identifier)
  end

  def create_shared_upload(tmp_dir, content, owner \\ "test_owner") do
    filename = "#{tmp_dir}/get_file_test.txt"

    {:ok, upload} =
      file_with_content(filename, content)
      |> prepare_upload_params()
      |> Webdrive.Files.create_upload_from_params(owner)

    sharing = file_sharing_fixture(upload)

    {upload, sharing}
  end
end
