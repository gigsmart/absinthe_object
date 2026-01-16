defmodule SocialNetworkWeb.GraphQL.Subscriptions.RootSubscription do
  use GreenFairy.Subscription

  alias SocialNetworkWeb.GraphQL.Types

  subscriptions do
    @desc "Subscribe to new posts"
    field :post_created, Types.Post do
      config fn _args, _info ->
        {:ok, topic: "posts"}
      end

      trigger :create_post, topic: fn _post -> "posts" end
    end

    @desc "Subscribe to new comments on a post"
    field :comment_added, Types.Comment do
      arg :post_id, non_null(:id)

      config fn args, _info ->
        {:ok, topic: "post:#{args.post_id}:comments"}
      end

      trigger :create_comment,
        topic: fn comment ->
          "post:#{comment.post_id}:comments"
        end
    end
  end
end
