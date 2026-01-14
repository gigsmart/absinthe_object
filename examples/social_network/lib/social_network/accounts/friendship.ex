defmodule SocialNetwork.Accounts.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "friendships" do
    field :status, Ecto.Enum, values: [:pending, :accepted, :blocked]

    belongs_to :user, SocialNetwork.Accounts.User
    belongs_to :friend, SocialNetwork.Accounts.User

    timestamps()
  end

  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:status, :user_id, :friend_id])
    |> validate_required([:user_id, :friend_id])
    |> unique_constraint([:user_id, :friend_id])
  end
end
