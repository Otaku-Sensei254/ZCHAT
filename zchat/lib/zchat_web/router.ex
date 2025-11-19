defmodule ZchatWeb.Router do
  use ZchatWeb, :router

  import ZchatWeb.UserAuth
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZchatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ZchatWeb do
    pipe_through :browser

    live_session :public,
    on_mount: [{ZchatWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :home
      live "/posts/new", CreatePost, :new
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZchatWeb do
    #   pipe_through :api
    # end

    # Enable LiveDashboard and Swoosh mailbox preview in development
    if Application.compile_env(:zchat, :dev_routes) do
      # If you want to use the LiveDashboard in production, you should put
      # it behind authentication and allow only admins to access it.
      # If your application does not have an admins-only section yet,
      # you can use Plug.BasicAuth to set up some basic authentication
      # as long as you are also using SSL (which you should anyway).
      import Phoenix.LiveDashboard.Router

      scope "/dev" do
        pipe_through :browser

        live_dashboard "/dashboard", metrics: ZchatWeb.Telemetry
        forward "/mailbox", Plug.Swoosh.MailboxPreview
      end
    end

# ADMIN ZONE
  scope "/admin", ZchatWeb do
    pipe_through [:browser, :require_authenticated_user]

    # We chain two hooks:
    # 1. mount_current_user (gets the user from session)
    # 2. ensure_admin (checks if that user is an admin)
    live_session :admin, on_mount: [{ZchatWeb.UserAuth, :mount_current_user}, {ZchatWeb.AdminAuthLive, :ensure_admin}] do

      # We will build this page next!
      live "/admindashboard", Admin.DashboardLive

    end
  end

    ## Authentication routes

    scope "/", ZchatWeb do
      pipe_through [:browser, :redirect_if_user_is_authenticated]

      live_session :redirect_if_user_is_authenticated,
      on_mount: [{ZchatWeb.UserAuth, :redirect_if_user_is_authenticated}] do
        live "/users/register", UserRegistrationLive, :new
        live "/users/log_in", UserLoginLive, :new
        live "/users/reset_password", UserForgotPasswordLive, :new
        live "/users/reset_password/:token", UserResetPasswordLive, :edit
      end

      post "/users/log_in", UserSessionController, :create
    end


    scope "/", ZchatWeb do
      pipe_through [:browser, :require_authenticated_user]

      live_session :require_authenticated_user,
      on_mount: [{ZchatWeb.UserAuth, :ensure_authenticated}] do
        live "/feed", UI.FeedLive, :index
        live "/users/settings", UserSettingsLive, :edit
        live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
        live "/posts/:id", UI.SinglePostLive, :show
        live "/users/:username", Profiles.UserProfileLive, :show
        live "/notifications", UI.NotificationsLive
      end
  end

  scope "/", ZchatWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{ZchatWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
