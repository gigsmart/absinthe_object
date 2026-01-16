defmodule SocialNetworkWeb.GraphQL.Queries.RootQuery do
  use GreenFairy.Query

  alias SocialNetworkWeb.GraphQL.Interfaces
  alias SocialNetworkWeb.GraphQL.Types

  queries do
    field :node, Interfaces.Node do
      arg :id, non_null(:id)

      resolve fn %{id: _id}, _ ->
        # Parse global ID and fetch node
        {:ok, nil}
      end
    end

    field :viewer, Types.User do
      resolve fn _, %{context: context} ->
        {:ok, context[:current_user]}
      end
    end

    field :user, Types.User do
      arg :id, non_null(:id)

      resolve fn %{id: id}, _ ->
        {:ok, SocialNetwork.Repo.get(SocialNetwork.Accounts.User, id)}
      end
    end

    field :users, list_of(Types.User) do
      resolve fn _args, _resolution ->
        {:ok, SocialNetwork.Repo.all(SocialNetwork.Accounts.User)}
      end
    end

    field :post, Types.Post do
      arg :id, non_null(:id)

      resolve fn %{id: id}, _ ->
        {:ok, SocialNetwork.Repo.get(SocialNetwork.Content.Post, id)}
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
