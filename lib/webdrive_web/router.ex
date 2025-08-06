defmodule WebdriveWeb.Router do
  use WebdriveWeb, :router

  import WebdriveWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {WebdriveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug WebdriveWeb.Plugs.ForwardedFor

    plug :put_secure_browser_headers, %{
      "content-security-policy" => "default-src 'self'; img-src 'self' data:"
    }

    plug :fetch_current_sharing_id
    plug :fetch_current_user
    plug WebdriveWeb.Plugs.Locale, "en"
  end

  scope "/", WebdriveWeb do
    pipe_through :browser

    get "/", PageController, :home

    resources "/sharings", UserSessionController, only: [:show, :create]
  end

  scope "/", WebdriveWeb do
    pipe_through [:browser, :require_authenticated_user]

    resources "/uploads", UploadController, only: [:create, :delete] do
      resources "/sharings", FileSharingController, only: [:create, :delete]
    end

    live_session :require_authenticated_user,
      on_mount: [{WebdriveWeb.UserAuth, :ensure_authenticated}] do
      live "/uploads/new", UploadLive
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", WebdriveWeb do
    pipe_through [:browser, :require_file_access]

    resources "/uploads", UploadController, only: [:index, :show]
  end

  scope "/", WebdriveWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{WebdriveWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", WebdriveWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{WebdriveWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:webdrive, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WebdriveWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
