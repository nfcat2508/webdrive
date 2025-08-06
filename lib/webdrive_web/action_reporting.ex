defmodule WebdriveWeb.ActionReporting do
  @moduledoc """
  A helper for dealing with specific actions triggered by remote users.
  """

  alias Plug.Conn

  require Logger

  @doc """
  Logs a suspicious action triggered by a client using the app.
  Returns the given conn
  """
  def suspect_conn(%Conn{} = conn, message) do
    log_suspect(conn.remote_ip, message)

    conn
  end

  @doc """
  Logs a suspicious action triggered by a client using the app.
  """
  def suspect(remote_ip, message) do
    log_suspect(remote_ip, message)
  end

  defp log_suspect(remote_ip, message) do
    if remote_ip == nil do
      Logger.warning("no remote_ip")
    end

    Logger.warning("[sus] #{message}", remote_ip: to_ip_string(remote_ip))
  end

  defp to_ip_string(remote_ip) when is_tuple(remote_ip) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp to_ip_string(_), do: nil
end
