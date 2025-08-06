defmodule WebdriveWeb.FileSharingControllerTest do
  use WebdriveWeb.ConnCase

  import Webdrive.FilesFixtures
  import Webdrive.AccountsFixtures

  describe "Post /uploads/:upload_id/sharings" do
    setup do
      user = user_fixture()
      [user: user, existing_upload: upload_fixture(%{owner: user.email})]
    end

    test "not accessible if not authenticated", %{
      conn: conn,
      existing_upload: upload
    } do
      # given
      given_secret = valid_secret()

      # when user is not authenticated
      conn_result = post(conn, "/uploads/#{upload.id}/sharings", secret: given_secret)

      # then user is redirected to login page
      assert redirected_to(conn_result) == ~p"/users/log_in"

      # and no sharing was created
      # TODO
    end

    test "with valid input", %{conn: conn, existing_upload: upload, user: user} do
      # given
      given_secret = valid_secret()

      # when
      conn_result =
        conn |> log_in_user(user) |> post("/uploads/#{upload.id}/sharings", secret: given_secret)

      # then
      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["info"] =~ "Link to file:"
    end

    test "returns error when invalid param name given", %{
      conn: conn,
      existing_upload: upload,
      user: user
    } do
      given_secret = valid_secret()

      conn_result =
        conn
        |> log_in_user(user)
        |> post("/uploads/#{upload.id}/sharings", invalid_param: given_secret)

      # then
      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["error"] == "error creating file sharing"
    end

    test "returns error when invalid param value given", %{
      conn: conn,
      existing_upload: upload,
      user: user
    } do
      # given secret is too short
      invalid_secret = "cat"

      # when
      conn_result =
        conn
        |> log_in_user(user)
        |> post("/uploads/#{upload.id}/sharings", secret: invalid_secret)

      # then
      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["error"] == "error creating file sharing"
    end
  end

  describe "Delete /uploads/:upload_id/sharings/:id" do
    setup do
      user = user_fixture()
      upload = upload_fixture(%{owner: user.email})
      [user: user, existing_sharing: file_sharing_fixture(upload), existing_upload: upload]
    end

    test "not accessible if not authenticated", %{
      conn: conn,
      existing_sharing: sharing,
      existing_upload: upload
    } do
      # when user is not authenticated
      target_url = "/uploads/#{upload.id}/sharings/#{sharing.id}"
      conn_result = delete(conn, target_url)

      # then user is redirected to login page
      assert redirected_to(conn_result) == ~p"/users/log_in"

      # and the sharing is still available to authenticated user
      # TODO
    end

    test "with existing ID deletes successfully", %{
      conn: conn,
      existing_sharing: sharing,
      existing_upload: upload,
      user: user
    } do
      conn = log_in_user(conn, user)
      target_url = "/uploads/#{upload.id}/sharings/#{sharing.id}"
      conn_result = delete(conn, target_url)

      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["info"] == "file sharing deleted"

      conn_result = get(conn, ~p"/uploads")
      actual_body = assert html_response(conn_result, 200)
      refute actual_body =~ sharing.identifier_user_param
    end

    test "returns error if deletion is tried a second time", %{
      conn: conn,
      existing_sharing: sharing,
      existing_upload: upload,
      user: user
    } do
      conn = log_in_user(conn, user)
      target_url = "/uploads/#{upload.id}/sharings/#{sharing.id}"
      delete(conn, target_url)
      # second time should fail
      conn_result = delete(conn, target_url)

      assert redirected_to(conn_result) == ~p"/uploads"
      assert conn_result.assigns.flash["error"] == "invalid request"
    end
  end
end
