defmodule VibeflowWeb.PageController do
  use VibeflowWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end

  def privacy(conn, _params) do
    render(conn, :privacy, layout: {VibeflowWeb.Layouts, :app})
  end

  def terms(conn, _params) do
    render(conn, :terms, layout: {VibeflowWeb.Layouts, :app})
  end
end
