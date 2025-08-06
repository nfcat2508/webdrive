defmodule WebdriveWeb.Plugs.Locale do
  @moduledoc """
    A plug for setting/updating the locale in session.
  """

  import Plug.Conn

  @locales ["no", "en", "de"]

  def init(default), do: default

  def call(%Plug.Conn{params: %{"locale" => loc}} = conn, _default) when loc in @locales do
    Gettext.put_locale(loc)

    put_session(conn, "locale", loc)
  end

  def call(conn, default) do
    (get_session(conn, "locale") || default)
    |> Gettext.put_locale()

    conn
  end
end
