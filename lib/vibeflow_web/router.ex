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

  pipeline :api_auth do
    plug VibeflowWeb.Plugs.ApiAuth
  end

  scope "/api", VibeflowWeb do
    pipe_through :api

    get "/unread_chats_count", Api.UnreadController, :show
  end

  scope "/api/v1", VibeflowWeb.Api.V1 do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/forgot-password", AuthController, :forgot_password
    post "/auth/reset-password", AuthController, :reset_password
    post "/auth/confirm-email", AuthController, :confirm_email
    post "/auth/resend-confirmation", AuthController, :resend_confirmation
  end

  scope "/api/v1", VibeflowWeb.Api.V1 do
    pipe_through :api

    get "/feed", FeedController, :index
    get "/feed/trending", FeedController, :trending
    get "/feed/categories", FeedController, :categories
    get "/feed/posts/search", FeedController, :search_posts
    get "/feed/tags", FeedController, :tags
    get "/feed/categories/counts", FeedController, :category_counts
  end

  scope "/api/v1", VibeflowWeb.Api.V1 do
    pipe_through [:api, VibeflowWeb.Plugs.OptionalApiAuth]

    get "/posts/:uuid", PostController, :show
    get "/feed/suggestions", FeedController, :suggestions
    get "/waves", WaveController, :index
    get "/waves/:username", WaveController, :show_user_waves
  end

  scope "/api/v1", VibeflowWeb.Api.V1 do
    pipe_through [:api, :api_auth]

    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    post "/posts", PostController, :create
    put "/posts/:uuid", PostController, :update
    delete "/posts/:uuid", PostController, :delete
    post "/posts/:uuid/like", PostController, :like
    post "/posts/:uuid/repost", PostController, :repost
    post "/posts/:uuid/save", PostController, :save
    post "/posts/:uuid/share", PostController, :share
    post "/posts/:uuid/view", PostController, :track_view
    post "/posts/:uuid/comments", PostController, :create_comment
    delete "/comments/:comment_id", PostController, :delete_comment
    put "/comments/:comment_id", PostController, :update_comment
    post "/comments/:comment_id/pin", PostController, :pin_comment
    post "/comments/:comment_id/like", PostController, :like_comment

    get "/users/search", UserController, :search
    get "/users/:username", UserController, :show
    post "/users/:username/follow", UserController, :follow
    delete "/users/:username/follow", UserController, :unfollow
    get "/users/:username/followers", UserController, :followers
    get "/users/:username/following", UserController, :following
    get "/users/:username/creator-hub", UserController, :creator_hub
    put "/users/profile", UserController, :update_profile
    put "/users/password", UserController, :update_password
    get "/users/saved-posts", UserController, :saved_posts
    get "/users/verification-status", UserController, :verification_status
    get "/users/social-accounts", UserController, :social_accounts
    post "/users/social-accounts", UserController, :add_social_account
    delete "/users/social-accounts/:id", UserController, :delete_social_account
    post "/users/verify", UserController, :submit_verification

    get "/chat/conversations", ChatController, :conversations
    get "/chat/conversations/:uuid/messages", ChatController, :messages
    post "/chat/conversations/:uuid/messages", ChatController, :create_message
    delete "/chat/conversations/:uuid/messages/:id", ChatController, :delete_message
    put "/chat/conversations/:uuid/messages/:id", ChatController, :update_message
    post "/chat/start/:username", ChatController, :start_conversation
    put "/chat/conversations/:uuid/skin", ChatController, :update_skin
    post "/chat/conversations/:uuid/read", ChatController, :mark_read
    get "/chat/unread-count", ChatController, :unread_count

    post "/waves", WaveController, :create
    post "/waves/:uuid/view", WaveController, :mark_viewed
    post "/waves/:uuid/like", WaveController, :like

    post "/music/tracks", MusicController, :create_track

    post "/uploads/media", MediaController, :upload

    get "/store/items", StoreController, :index
    post "/store/purchase", StoreController, :purchase

    get "/notifications", NotificationController, :index
    post "/notifications/:id/read", NotificationController, :mark_read
    post "/notifications/read-all", NotificationController, :mark_all_read
    delete "/notifications", NotificationController, :clear

    # Admin API
    get "/admin/stats", AdminController, :stats
    get "/admin/users", AdminController, :users
    put "/admin/users/:id/roles", AdminController, :update_user_roles
    post "/admin/users/:user_id/toggle_role/:role_id", AdminController, :toggle_role
    delete "/admin/users/:user_id/remove_role/:role_id", AdminController, :remove_role
    get "/admin/verifications", AdminController, :verifications
    post "/admin/verifications/:id/approve", AdminController, :approve_verification
    post "/admin/verifications/:id/reject", AdminController, :reject_verification
    get "/admin/roles", AdminController, :roles
    post "/admin/roles", AdminController, :create_role
    get "/admin/permissions", AdminController, :permissions
    get "/admin/verifications/count", AdminController, :verification_count
  end

  # Authenticated upload API - requires login via session
  pipeline :upload_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :fetch_current_user
  end

  scope "/api", VibeflowWeb do
    pipe_through [:upload_api, :require_authenticated_user]

    post "/uploads/init", Api.UploadController, :init
    put "/uploads/:upload_id/data", Api.UploadController, :upload
  end

  scope "/", VibeflowWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{VibeflowWeb.UserAuth, :mount_current_user}, VibeflowWeb.UserActivityHook] do
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

  # MODERATOR ZONE
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
      live "/verification-requests", VerificationsLive, :index
      live "/reports", ReportsLive, :index
      live "/reports/:id", ReportsLive, :show
    end
  end

  # SALES EXECUTIVE ZONE
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
      live "/verification-requests", VerificationsLive, :index
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
      live "/", HomeLive, :home
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
      live "/users/:username/creator-hub", Profiles.CreatorHubLive, :show
      live "/users/:username", Profiles.UserProfileLive, :show
      live "/wave-store", UI.Store.StoreLive, :index
      live "/notifications", UI.NotificationsLive
      live "/posts/:uuid/edit", CreatePostLive, :edit

      # Chat routes moved inside this session
      live "/chat", Chat.ChatLive, :index
      live "/chat/settings", Chat.ChatSettingsLive, :index
      live "/chat/:uuid/settings", Chat.ChatSettingsRouterLive, :index
      live "/chat/:uuid/group-settings", Chat.ChatGroupSettingsLive, :index
      live "/chat/:uuid/individual-settings", Chat.ChatSettingsLive, :index
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
