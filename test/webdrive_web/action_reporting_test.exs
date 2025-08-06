defmodule WebdriveWeb.ActionReportingTest do
  use WebdriveWeb.ConnCase, async: true

  import ExUnit.CaptureLog

  alias WebdriveWeb.ActionReporting

  describe "suspect_conn/2" do
    test "logs a message with remote_ip as warning", %{conn: conn} do
      given_message = "cat is hungry"
      conn = %{conn | remote_ip: {123, 456, 789, 0}}

      fun = fn ->
        ActionReporting.suspect_conn(conn, given_message)
      end

      actual_log = capture_log(fun)

      assert suspicious_action_logged(actual_log, given_message)
      assert actual_log =~ "123.456.789.0"
    end

    test "logs an additional warning, if no remote_ip available", %{conn: conn} do
      given_message = "cat is hungry"
      conn = %{conn | remote_ip: nil}

      fun = fn ->
        ActionReporting.suspect_conn(conn, given_message)
      end

      actual_log = capture_log(fun)
      assert actual_log =~ "[warning] no remote_ip"
    end

    test "returns given conn", %{conn: conn} do
      actual = ActionReporting.suspect_conn(conn, "test")

      assert actual == conn
    end
  end

  describe "suspect/2" do
    test "logs a message with remote_ip as warning" do
      given_message = "cat is hungry"
      remote_ip = {123, 456, 789, 0}

      fun = fn ->
        ActionReporting.suspect(remote_ip, given_message)
      end

      actual_log = capture_log(fun)

      assert suspicious_action_logged(actual_log, given_message)
      assert actual_log =~ "123.456.789.0"
    end

    test "logs an additional warning, if no remote_ip provided" do
      fun = fn ->
        ActionReporting.suspect(nil, "test")
      end

      actual_log = capture_log(fun)
      assert actual_log =~ "[warning] no remote_ip"
    end
  end
end
