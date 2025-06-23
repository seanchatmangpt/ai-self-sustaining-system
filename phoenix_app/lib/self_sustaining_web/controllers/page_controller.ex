defmodule SelfSustainingWeb.PageController do
  @moduledoc """
  Main page controller for the SelfSustaining application.
  """

  use SelfSustainingWeb, :controller

  def index(conn, _params) do
    # The home page is often custom, but this will make it work
    render(conn, :index, layout: false)
  end
end
