defmodule SocialNetworkWeb.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    description "An object with a globally unique ID"

    field :id, non_null(:id)
  end
end
