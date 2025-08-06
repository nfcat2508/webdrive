defmodule WebdriveWeb.Plugs.ForwardedFor do
  @moduledoc """
    A plug for updating conn.remote_ip with value from X-Forwarded-For header
  """

  require Logger

  def init([]), do: []

  def call(%Plug.Conn{} = conn, _) do
    ip = ip_from(conn.req_headers) || conn.remote_ip
    %{conn | remote_ip: ip}
  end

  defp ip_from(headers) do
    headers
    |> Enum.find(fn {key, _value} -> key == "x-forwarded-for" end)
    |> to_ip()
  end

  defp to_ip(nil), do: nil

  defp to_ip({_, ip_string}) do
    ip_string
    |> to_charlist()
    |> :inet.parse_strict_address()
    |> case do
      {:ok, ip} ->
        ip

      _ ->
        Logger.warning("Could not parse IP: #{ip_string}")
        nil
    end
  end
end
