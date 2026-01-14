defmodule SocialNetwork.Content.Like do
  use Ecto.Schema
  import Ecto.Changeset

  schema "likes" do
    belongs_to :user, SocialNetwork.Accounts.User
    belongs_to :post, SocialNetwork.Content.Post
    belongs_to :comment, SocialNetwork.Content.Comment

    timestamps()
  end

  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :post_id, :comment_id])
    |> validate_required([:user_id])
    |> validate_likeable()
  end

  defp validate_likeable(changeset) do
    post_id = get_field(changeset, :post_id)
    comment_id = get_field(changeset, :comment_id)

    case {post_id, comment_id} do
      {nil, nil} -> add_error(changeset, :base, "must like either a post or comment")
      {_, nil} -> changeset
      {nil, _} -> changeset
      {_, _} -> add_error(changeset, :base, "cannot like both a post and comment")
    end
  end
end
