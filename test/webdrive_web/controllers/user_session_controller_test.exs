defmodule WebdriveWeb.UserSessionControllerTest do
  use WebdriveWeb.ConnCase, async: true

  import ExUnit.CaptureLog
  import Webdrive.AccountsFixtures
  import Webdrive.FilesFixtures

  alias Ecto.Changeset
  alias Webdrive.Files.FileSharing

  setup do
    %{
      user: confirmed_user_fixture(),
      unconfirmed_user: user_fixture()
    }
  end

  describe "POST /users/log_in" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log_out"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_webdrive_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "hompage following registration", %{
      conn: conn,
      unconfirmed_user: user
    } do
      conn =
        conn
        |> post(~p"/users/log_in", %{
          "_action" => "registered",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Please check your mails and confirm the account creation"
    end

    test "login following password update", %{conn: conn, user: user} do
      conn =
        conn
        |> post(~p"/users/log_in", %{
          "_action" => "password_updated",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      {conn, log} =
        with_log(fn ->
          post(conn, ~p"/users/log_in", %{
            "user" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
          })
        end)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log_in"
      assert suspicious_action_logged(log, "login failed")
    end

    test "redirects to home page with unconfirmed account", %{conn: conn, unconfirmed_user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Please check your mails and confirm the account creation"

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end

  describe "Get /sharings/:id" do
    test "returns password input form for valid ID", %{conn: conn} do
      # given
      given_id = valid_id()

      # when
      sharing_url = sharing_url(given_id)
      conn = get(conn, sharing_url)

      # then
      actual_body = assert html_response(conn, 200)
      assert actual_body =~ "Password protected file"
      assert actual_body =~ ~s(<form action="/sharings" method="post">)
    end

    # For security reasons, we return the same site, even if attackers try to guess a URL.
    # Attackers will fail on (simulated) password validation
    test "returns password input form even for invalid ID", %{conn: conn} do
      # given
      given_invalid_id = "invalid"

      # when
      sharing_url = sharing_url(given_invalid_id)
      conn = get(conn, sharing_url)

      # then
      actual_body = assert html_response(conn, 200)
      assert actual_body =~ "Password protected file"
      assert actual_body =~ ~s(<form action="/sharings" method="post">)
    end
  end

  describe "Post /sharings" do
    test "redirects to file list if id/secret combination is valid", %{conn: conn} do
      # given
      shared_file = upload_fixture()
      given_secret = "cats!_AT_n8!"

      existing_sharing =
        file_sharing_fixture(
          %{upload_id: shared_file.id, secret: given_secret},
          shared_file.owner
        )

      # when
      conn =
        post(conn, ~p"/sharings",
          id: existing_sharing.identifier_user_param,
          secret: given_secret
        )

      # then
      assert redirected_to(conn) == ~p"/uploads"
    end

    test "displays error if secret is incorrect", %{conn: conn} do
      # given
      shared_file = upload_fixture()
      given_secret = "cats!_AT_n8!"

      existing_sharing =
        file_sharing_fixture(
          %{upload_id: shared_file.id, secret: given_secret},
          shared_file.owner
        )

      # when
      conn =
        post(conn, ~p"/sharings",
          id: existing_sharing.identifier_user_param,
          secret: "inC0rrect_Secret"
        )

      # then
      assert html_response(conn, 200) =~ "Invalid link or password"
    end
  end

  defp valid_id do
    FileSharing.changeset(prepare_file_sharing(), prepare_file_sharing_attrs())
    |> Changeset.get_change(:identifier_user_param)
  end

  defp sharing_url(id) do
    "/sharings/#{id}"
  end
end
