defmodule SocialNetwork.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SocialNetwork.Repo,
      {Plug.Cowboy, scheme: :http, plug: SocialNetwork.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: SocialNetwork.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
