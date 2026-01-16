defmodule SocialNetworkWeb.GraphQL.Mutations.RootMutation do
  use GreenFairy.Mutation

  alias SocialNetworkWeb.GraphQL.Types
  alias SocialNetworkWeb.GraphQL.Enums

  mutations do
    field :create_user, Types.User do
      arg :email, non_null(:string)
      arg :username, non_null(:string)
      arg :display_name, :string

      resolve fn args, _ ->
        %SocialNetwork.Accounts.User{}
        |> SocialNetwork.Accounts.User.changeset(args)
        |> SocialNetwork.Repo.insert()
      end
    end

    field :create_post, Types.Post do
      arg :body, non_null(:string)
      arg :media_url, :string
      arg :visibility, Enums.PostVisibility

      resolve fn args, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Content.Post{}
            |> SocialNetwork.Content.Post.changeset(Map.put(args, :author_id, user.id))
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :create_comment, Types.Comment do
      arg :post_id, non_null(:id)
      arg :body, non_null(:string)
      arg :parent_id, :id

      resolve fn args, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Content.Comment{}
            |> SocialNetwork.Content.Comment.changeset(Map.put(args, :author_id, user.id))
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :like_post, Types.Like do
      arg :post_id, non_null(:id)

      resolve fn %{post_id: post_id}, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Content.Like{}
            |> SocialNetwork.Content.Like.changeset(%{user_id: user.id, post_id: post_id})
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :send_friend_request, Types.Friendship do
      arg :friend_id, non_null(:id)

      resolve fn %{friend_id: friend_id}, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Accounts.Friendship{}
            |> SocialNetwork.Accounts.Friendship.changeset(%{
              user_id: user.id,
              friend_id: friend_id,
              status: :pending
            })
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :accept_friend_request, Types.Friendship do
      arg :friendship_id, non_null(:id)

      resolve fn %{friendship_id: friendship_id}, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          _user ->
            case SocialNetwork.Repo.get(SocialNetwork.Accounts.Friendship, friendship_id) do
              nil ->
                {:error, "Friendship not found"}

              friendship ->
                friendship
                |> SocialNetwork.Accounts.Friendship.changeset(%{status: :accepted})
                |> SocialNetwork.Repo.update()
            end
        end
      end
    end
  end
end
