defmodule SocialNetwork.Repo do
  use Ecto.Repo,
    otp_app: :social_network,
    adapter: Ecto.Adapters.SQLite3
end
