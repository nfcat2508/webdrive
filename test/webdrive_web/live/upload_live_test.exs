defmodule WebdriveWeb.UploadLiveTest do
  use WebdriveWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Webdrive.AccountsFixtures

  describe "Upload form page" do
    @describetag :tmp_dir

    test "renders upload form page", %{conn: conn} do
      {:ok, _lv, html} =
        conn |> log_in_user(AccountsFixtures.user_fixture()) |> live(~p"/uploads/new")

      assert html =~ "id=\"upload-form\""
    end

    test "redirects if not authenticated", %{conn: conn} do
      result =
        conn
        |> live(~p"/uploads/new")
        |> follow_redirect(conn, "/users/log_in")

      assert {:ok, _conn} = result
    end
  end
end
