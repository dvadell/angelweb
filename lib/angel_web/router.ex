defmodule AngelWeb.Router do
  use AngelWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AngelWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AngelWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/graphs", IndexLive.Index, :index
    live "/graphs/new", IndexLive.Index, :new
    live "/graphs/:id/edit", IndexLive.Index, :edit

    live "/graphs/:id", IndexLive.Show, :show
    live "/graphs/:id/show/edit", IndexLive.Show, :edit
  end

  scope "/api/v1", AngelWeb do
    pipe_through :api

    post "/metric", MetricController, :create
    get "/graphs/:name", MetricController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:angel, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AngelWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
