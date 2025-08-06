defmodule WebdriveWeb.UserSessionController do
  use WebdriveWeb, :controller

  alias Webdrive.Accounts
  alias Webdrive.Files
  alias WebdriveWeb.{ActionReporting, UserAuth}

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, %{"id" => id, "secret" => secret}) do
    if sharing = Files.get_sharing_by_id_and_secret(id, secret) do
      UserAuth.authorize_for_files(conn, sharing)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the link is registered.
      render(conn, "new.html", id: id, error_message: gettext("Invalid link or password"))
    end
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      if user.confirmed_at do
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)
      else
        conn
        |> put_flash(:info, "Please check your mails and confirm the account creation")
        |> redirect(to: ~p"/")
      end
    else
      conn
      |> ActionReporting.suspect_conn("login failed")
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  def show(conn, %{"id" => id}) do
    render(conn, :new, error_message: nil, id: id)
  end
end
