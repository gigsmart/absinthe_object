defmodule SocialNetworkWeb.GraphQL.Queries.RootQuery do
  @moduledoc """
  Root query module demonstrating GreenFairy's query macros.

  ## Query Field Generation

  Query fields are generated from multiple sources:

  1. **Type-side `expose`** - Types with `expose :id` auto-generate query fields
     This is the recommended approach for simple lookups.

  2. **Query-side fields** - Custom fields defined in this module for:
     - Complex queries with filters
     - List queries
     - Fields requiring custom resolver logic

  ## Example

  In types:

      type "User", struct: User do
        expose :id          # Generates: user(id: ID!): User
        expose :email       # Generates: userByEmail(email: String!): User
      end

  In queries (this module):

      queries do
        node_field()        # Relay Node resolution
        field :users, list_of(:user) do ... end
      end

  """
  use GreenFairy.Query

  alias SocialNetworkWeb.GraphQL.Types

  queries do
    # Relay Node field - automatically decodes GlobalId and fetches the record
    # Uses the schema's configured repo and global_id implementation
    node_field()

    # NOTE: user(id:) and post(id:) are auto-generated from the types
    # because they have `expose :id` defined. No need to define them here!

    # Current viewer - custom field (not exposed via GlobalId)
    field :viewer, Types.User do
      resolve fn _, %{context: context} ->
        {:ok, context[:current_user]}
      end
    end

    # List queries - these still need custom resolvers
    field :users, list_of(Types.User) do
      resolve fn _args, _resolution ->
        {:ok, SocialNetwork.Repo.all(SocialNetwork.Accounts.User)}
      end
    end

    field :posts, list_of(Types.Post) do
      arg :visibility, :post_visibility

      resolve fn args, _resolution ->
        import Ecto.Query
        query = from(p in SocialNetwork.Content.Post)

        query =
          if args[:visibility] do
            from p in query, where: p.visibility == ^args[:visibility]
          else
            query
          end

        {:ok, SocialNetwork.Repo.all(query)}
      end
    end
  end
end
