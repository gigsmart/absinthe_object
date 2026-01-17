defmodule SocialNetworkWeb.GraphQL.Schema do
  @moduledoc """
  Social Network GraphQL Schema.

  This is all you need! GreenFairy handles everything automatically:
  - Type discovery from root Query/Mutation/Subscription modules
  - Built-in scalars (datetime, naive_datetime, etc.)
  - DataLoader context and plugins
  - Subscription node_name
  - GlobalId encoding/decoding for Node resolution
  - Repo available in context for database operations
  """

  use GreenFairy.Schema,
    query: SocialNetworkWeb.GraphQL.Queries.RootQuery,
    mutation: SocialNetworkWeb.GraphQL.Mutations.RootMutation,
    subscription: SocialNetworkWeb.GraphQL.Subscriptions.RootSubscription,
    repo: SocialNetwork.Repo
    # Optional: custom global_id implementation
    # global_id: MyApp.CustomGlobalId
end
