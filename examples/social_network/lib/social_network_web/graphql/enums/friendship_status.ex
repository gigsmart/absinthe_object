defmodule SocialNetworkWeb.GraphQL.Enums.FriendshipStatus do
  use GreenFairy.Enum

  enum "FriendshipStatus" do
    value :pending, description: "Friend request sent but not yet accepted"
    value :accepted, description: "Friendship is active"
    value :blocked, description: "User has blocked this friend"
  end
end
