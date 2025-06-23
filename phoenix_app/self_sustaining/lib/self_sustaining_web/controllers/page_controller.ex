defmodule SelfSustainingWeb.PageController do
  use SelfSustainingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
