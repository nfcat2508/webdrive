defmodule Webdrive.Repo do
  use Ecto.Repo,
    otp_app: :webdrive,
    adapter: Ecto.Adapters.Postgres
end
