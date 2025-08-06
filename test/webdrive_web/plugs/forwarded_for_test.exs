defmodule WebdriveWeb.Plugs.ForwardedForTest do
  use ExUnit.Case, async: true

  alias Plug.Conn
  alias WebdriveWeb.Plugs.ForwardedFor

  test "use IP from X-Forwarded-For header" do
    test()
    |> given_header({"X-Forwarded-For", "194.63.248.47"})
    |> when_plug_is_called()
    |> then_remote_ip_is({194, 63, 248, 47})
  end

  test "fallback to existing remote_ip, if header missing" do
    test()
    |> given_remote_ip({123, 45, 678, 90})
    |> given_header_not_present("X-Forwarded-For")
    |> when_plug_is_called()
    |> then_remote_ip_is({123, 45, 678, 90})
  end

  test "fallback to existing remote_ip, if header value invalid" do
    test()
    |> given_remote_ip({123, 45, 678, 90})
    |> given_header({"X-Forwarded-For", "194.63.248.abc"})
    |> when_plug_is_called()
    |> then_remote_ip_is({123, 45, 678, 90})
    |> then_a_warning_is_logged_containing("194.63.248.abc")
  end

  defp test, do: %{conn: Phoenix.ConnTest.build_conn()}

  defp given_header(test, {name, value}) do
    %{test | conn: Conn.put_req_header(test.conn, String.downcase(name), value)}
  end

  defp given_header_not_present(test, name) do
    %{test | conn: Conn.delete_req_header(test.conn, String.downcase(name))}
  end

  defp given_remote_ip(test, ip) do
    %{test | conn: %{test.conn | remote_ip: ip}}
  end

  defp when_plug_is_called(test) do
    {conn, log} = ExUnit.CaptureLog.with_log(fn -> ForwardedFor.call(test.conn, []) end)

    test
    |> Map.put(:conn, conn)
    |> Map.put(:log, log)
  end

  defp then_remote_ip_is(test, expected) do
    assert test.conn.remote_ip == expected

    test
  end

  defp then_a_warning_is_logged_containing(test, expected) do
    assert test.log =~ expected

    test
  end
end
