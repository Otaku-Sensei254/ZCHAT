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
      on_mount: [{ZchatWeb.UserAuth, :mount_current_user}, ZchatWeb.UserActivityHook] do
      live "/", HomeLive, :home
      live "/feed", UI.FeedLive, :index
      live "/posts/new", CreatePost, :new
      live "/posts/:id", UI.SinglePostLive, :show
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
      live "/tags/:tag", UI.TagLive, :show
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



  #MODERATOR ZONE
  pipeline :moderator do
    plug ZchatWeb.Plugs.EnsureModerator
    plug :put_root_layout, html: {ZchatWeb.Layouts, :root}
    plug :put_layout, html: {ZchatWeb.Layouts, :sidepanel}
    plug ZchatWeb.Plugs.LoadNavigation
  end

  scope "/moderator", ZchatWeb.Moderator do
    pipe_through [:browser, :require_authenticated_user, :moderator]

    live_session :moderator,
      layout: {ZchatWeb.Layouts, :sidepanel},
      on_mount: [
        {ZchatWeb.UserAuth, :mount_current_user},
        {ZchatWeb.ModeratorAuthLive, :ensure_moderator},
        {ZchatWeb.AdminLayoutHook, :default}
      ] do
      live "/dashboard", DashboardLive, :index
      live "/reports", ReportsLive, :index
      live "/reports/:id", ReportsLive, :show
    end
  end


  #SALES EXECUTIVE ZONE
  pipeline :sales do
  plug ZchatWeb.Plugs.EnsureSalesExecutive
  plug :put_root_layout, html: {ZchatWeb.Layouts, :root}
  plug :put_layout, html: {ZchatWeb.Layouts, :sidepanel}
  plug ZchatWeb.Plugs.LoadNavigation
end

scope "/sales-executive", ZchatWeb.Sales do
  pipe_through [:browser, :require_authenticated_user, :sales]

  live_session :sales,
    layout: {ZchatWeb.Layouts, :sidepanel},
    on_mount: [
      {ZchatWeb.UserAuth, :mount_current_user},
      {ZchatWeb.SalesAuthLive, :ensure_sales_executive},
      {ZchatWeb.AdminLayoutHook, :default}
    ] do
    live "/dashboard", DashboardLive, :index
    live "/ads-request", AdsRequestLive, :index
    live "/ads-request/new", AdsRequestLive, :new
    live "/ads-request/:id", AdsRequestLive, :show
  end
end




  # ADMIN ZONE

  pipeline :admin do
    plug ZchatWeb.Plugs.EnsureAdmin
    plug :put_root_layout, html: {ZchatWeb.Layouts, :root}
    plug :put_layout, html: {ZchatWeb.Layouts, :sidepanel}
    plug ZchatWeb.Plugs.LoadNavigation
  end

scope "/admin", ZchatWeb.Admin do
  pipe_through [:browser, :require_authenticated_user, :admin]

  live_session :admin,
    layout: {ZchatWeb.Layouts, :sidepanel},
    on_mount: [
      {ZchatWeb.UserAuth, :mount_current_user},
      {ZchatWeb.AdminAuthLive, :ensure_admin},
      {ZchatWeb.AdminLayoutHook, :default}
    ] do
    live "/dashboard", DashboardLive, :index
    live "/users", ManagementLive, :index
    live "/users/:user_id/edit_roles", UserRolesLive, :edit
    live "/roles", CreateRolesLive
  end
end

  # scope "/moderator", ZchatWeb.Moderator do
  #   pipe_yhrough [:browser, :require_authenticated_user]
  #   live_session :moderator

  # end

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

  # Public routes that don't require authentication

  # Protected routes that require authentication
  scope "/", ZchatWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ZchatWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/users/:username", Profiles.UserProfileLive, :show
      live "/notifications", UI.NotificationsLive
      live "/posts/:id/edit", CreatePost, :edit
    end

    live_session :chat,
      on_mount: [{ZchatWeb.UserAuth, :mount_current_user},
      {ZchatWeb.ChatAuthHook, :require_member }] do
      live "/chat", Chat.ChatLive, :index
      live "/chat/:id", Chat.ChatLive, :index
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
