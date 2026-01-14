defmodule SocialNetworkWeb.GraphQL.Enums.PostVisibility do
  use GreenFairy.Enum

  enum "PostVisibility" do
    value :public, description: "Visible to everyone"
    value :friends, description: "Visible only to friends"
    value :private, description: "Visible only to the author"
  end
end
