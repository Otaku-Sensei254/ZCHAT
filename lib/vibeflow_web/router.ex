defmodule VibeflowWeb.Router do
  use VibeflowWeb, :router

  import VibeflowWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VibeflowWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", VibeflowWeb do
    pipe_through :api

    get "/unread_chats_count", Api.UnreadController, :show
  end

  scope "/", VibeflowWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{VibeflowWeb.UserAuth, :mount_current_user}, VibeflowWeb.UserActivityHook] do
      live "/", HomeLive, :home
      live "/feed", UI.FeedLive, :index
      live "/posts/new", CreatePostLive, :new
      live "/posts/:uuid", UI.SinglePostLive, :show
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
      live "/tags/:tag", UI.TagLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", VibeflowWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:vibeflow, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VibeflowWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end



  #MODERATOR ZONE
  pipeline :moderator do
    plug VibeflowWeb.Plugs.EnsureModerator
    plug :put_root_layout, html: {VibeflowWeb.Layouts, :root}
    plug :put_layout, html: {VibeflowWeb.Layouts, :sidepanel}
    plug VibeflowWeb.Plugs.LoadNavigation
  end

  scope "/moderator", VibeflowWeb.Moderator do
    pipe_through [:browser, :require_authenticated_user, :moderator]

    live_session :moderator,
      layout: {VibeflowWeb.Layouts, :sidepanel},
      on_mount: [
          {VibeflowWeb.UserAuth, :mount_current_user},
          {VibeflowWeb.ModeratorAuthLive, :ensure_moderator},
          {VibeflowWeb.AdminLayoutHook, :default},
          VibeflowWeb.UserActivityHook
      ] do
      live "/dashboard", DashboardLive, :index
      live "/reports", ReportsLive, :index
      live "/reports/:id", ReportsLive, :show
    end
  end


  #SALES EXECUTIVE ZONE
  pipeline :sales do
  plug VibeflowWeb.Plugs.EnsureSalesExecutive
  plug :put_root_layout, html: {VibeflowWeb.Layouts, :root}
  plug :put_layout, html: {VibeflowWeb.Layouts, :sidepanel}
  plug VibeflowWeb.Plugs.LoadNavigation
end

scope "/sales-executive", VibeflowWeb.Sales do
  pipe_through [:browser, :require_authenticated_user, :sales]

  live_session :sales,
    layout: {VibeflowWeb.Layouts, :sidepanel},
    on_mount: [
      {VibeflowWeb.UserAuth, :mount_current_user},
      {VibeflowWeb.SalesAuthLive, :ensure_sales_executive},
      {VibeflowWeb.AdminLayoutHook, :default},
      VibeflowWeb.UserActivityHook
    ] do
    live "/dashboard", DashboardLive, :index
    live "/ads-request", AdsRequestLive, :index
    live "/ads-request/new", AdsRequestLive, :new
    live "/ads-request/:id", AdsRequestLive, :show
  end
end




  # ADMIN ZONE

  pipeline :admin do
    plug VibeflowWeb.Plugs.EnsureAdmin
    plug :put_root_layout, html: {VibeflowWeb.Layouts, :root}
    plug :put_layout, html: {VibeflowWeb.Layouts, :sidepanel}
    plug VibeflowWeb.Plugs.LoadNavigation
  end

scope "/admin", VibeflowWeb.Admin do
  pipe_through [:browser, :require_authenticated_user, :admin]

  live_session :admin,
    layout: {VibeflowWeb.Layouts, :sidepanel},
    on_mount: [
      {VibeflowWeb.UserAuth, :mount_current_user},
      {VibeflowWeb.AdminAuthLive, :ensure_admin},
      {VibeflowWeb.AdminLayoutHook, :default},
      VibeflowWeb.UserActivityHook
    ] do
    live "/dashboard", DashboardLive, :index
    live "/users", ManagementLive, :index
    live "/users/:user_id/edit_roles", UserRolesLive, :edit
    live "/roles", CreateRolesLive
  end
end

  # scope "/moderator", VibeflowWeb.Moderator do
  #   pipe_yhrough [:browser, :require_authenticated_user]
  #   live_session :moderator

  # end

  ## Authentication routes

  scope "/", VibeflowWeb do
    pipe_through [:browser]

    # 1. Keep Register and Reset Password here (Standard behavior)
    live_session :redirect_if_user_is_authenticated,
      on_mount: [{VibeflowWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
      live "/users/register", UserRegistrationLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Public routes that don't require authentication

  # Protected routes that require authentication
  scope "/", VibeflowWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{VibeflowWeb.UserAuth, :ensure_authenticated}, VibeflowWeb.UserActivityHook] do
      live "/users/settings", UserSettingsLive, :edit
      live "/waves", Waves.WavesLive, :index
      live "/waves/view/:username", Waves.ViewWavesLive, :show
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/users/:username", Profiles.UserProfileLive, :show
      live "/notifications", UI.NotificationsLive
      live "/posts/:uuid/edit", CreatePostLive, :edit
    end

    live_session :chat,
      on_mount: [{VibeflowWeb.UserAuth, :mount_current_user},
      {VibeflowWeb.ChatAuthHook, :require_member }, VibeflowWeb.UserActivityHook] do
      live "/chat", Chat.ChatLive, :index
      live "/chat/:uuid", Chat.ChatLive, :index
    end
  end

  scope "/", VibeflowWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{VibeflowWeb.UserAuth, :mount_current_user}, VibeflowWeb.UserActivityHook] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

end
