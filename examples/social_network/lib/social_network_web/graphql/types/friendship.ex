defmodule SocialNetworkWeb.GraphQL.Types.Friendship do
  use Absinthe.Object.Type

  alias SocialNetworkWeb.GraphQL.{Enums, Interfaces}

  type "Friendship", struct: SocialNetwork.Accounts.Friendship do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :status, Enums.FriendshipStatus

    field :user, non_null(:user)
    field :friend, non_null(:user)

    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end
end
