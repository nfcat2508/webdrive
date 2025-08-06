import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/webdrive start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :webdrive, WebdriveWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  database_url =
    if File.exists?(database_url) do
      database_url |> File.read!() |> String.trim()
    else
      database_url
    end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :webdrive, Webdrive.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  secret_key_base =
    if File.exists?(secret_key_base) do
      secret_key_base |> File.read!() |> String.trim()
    else
      secret_key_base
    end

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :webdrive, WebdriveWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https", path: "/wd"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP.
  #
  # config :webdrive, Webdrive.Mailer,
  #   adapter: Swoosh.Adapters.SMTP,
  #   relay: System.get_env("MAIL_RELAY"),
  #   username: System.get_env("MAIL_USERNAME"),
  #   password: System.get_env("MAIL_PASS"),
  #   ssl: true,
  #   #  tls: :always,
  #   auth: :always,
  #   #  dkim: [
  #   #    s: "default",
  #   #    d: "domain.com",
  #   #    private_key: {:pem_plain, File.read!("priv/keys/domain.private")}
  #   #  ],
  #   retries: 2,
  #   no_mx_lookups: false

  # config :swoosh, :api_client, false

  config :webdrive, uploads_directory: System.fetch_env!("UPLOADS_DIRECTORY")
end
