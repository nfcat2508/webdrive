defmodule WebdriveWeb.Plugs.LocaleTest do
  use WebdriveWeb.ConnCase, async: true

  alias WebdriveWeb.Plugs.Locale

  @default_locale "en"

  describe "locale" do
    test "'no' is a valid locale", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("no")
      |> when_plug_is_called()
      |> then_locale_in_session_is("no")
    end

    test "'de' is a valid locale", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("de")
      |> when_plug_is_called()
      |> then_locale_in_session_is("de")
    end

    test "'en' is a valid locale", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("en")
      |> when_plug_is_called()
      |> then_locale_in_session_is("en")
    end
  end

  describe "sessions" do
    test "locale is initialized from valid locale parameter", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("no")
      |> when_plug_is_called()
      |> then_locale_in_session_is("no")
    end

    test "locale is empty, if invalid locale provided", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("zz")
      |> when_plug_is_called()
      |> then_no_locale_in_session()
    end

    test "locale is not changed, if no locale provided", %{conn: conn} do
      conn
      |> given_locale_in_session("no")
      |> when_plug_is_called()
      |> then_locale_in_session_is("no")
    end

    test "locale is overridden, if valid locale provided", %{conn: conn} do
      conn
      |> given_locale_in_session("no")
      |> given_locale_in_req_param("en")
      |> when_plug_is_called()
      |> then_locale_in_session_is("en")
    end

    test "locale is not changed, if invalid locale provided", %{conn: conn} do
      conn
      |> given_locale_in_session("no")
      |> given_locale_in_req_param("zz")
      |> when_plug_is_called()
      |> then_locale_in_session_is("no")
    end
  end

  describe "active" do
    test "locale is set to valid provided locale", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("no")
      |> when_plug_is_called()
      |> then_active_locale_is("no")
    end

    test "locale is set to default, if invalid locale provided", %{conn: conn} do
      conn
      |> given_empty_session()
      |> given_locale_in_req_param("zz")
      |> when_plug_is_called()
      |> then_active_locale_is(@default_locale)
    end

    test "locale is set to default, if no locale provided", %{conn: conn} do
      conn
      |> given_empty_session()
      |> when_plug_is_called()
      |> then_active_locale_is(@default_locale)
    end

    test "locale is preferred from session, if no locale provided", %{conn: conn} do
      conn
      |> given_locale_in_session("no")
      |> when_plug_is_called()
      |> then_active_locale_is("no")
    end

    test "locale is preferred from session, if invalid locale provided", %{conn: conn} do
      conn
      |> given_locale_in_session("no")
      |> given_locale_in_req_param("zz")
      |> when_plug_is_called()
      |> then_active_locale_is("no")
    end

    test "locale is changed, if valid locale provided", %{conn: conn} do
      conn
      |> given_locale_in_session("de")
      |> given_locale_in_req_param("no")
      |> when_plug_is_called()
      |> then_active_locale_is("no")
    end
  end

  defp given_empty_session(conn) do
    Plug.Test.init_test_session(conn, %{})
  end

  defp given_locale_in_session(conn, locale) do
    Plug.Test.init_test_session(conn, %{"locale" => locale})
  end

  defp given_locale_in_req_param(conn, locale) do
    %{conn | params: %{"locale" => locale}}
  end

  defp when_plug_is_called(conn, default \\ @default_locale) do
    Locale.call(conn, default)
  end

  defp then_locale_in_session_is(conn, locale) do
    actual = get_session(conn, "locale")
    assert actual == locale
  end

  defp then_no_locale_in_session(conn) do
    actual = get_session(conn, "locale")
    assert actual == nil
  end

  defp then_active_locale_is(_conn, locale) do
    assert Gettext.get_locale() == locale
  end
end
