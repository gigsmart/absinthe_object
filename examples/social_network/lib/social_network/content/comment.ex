defmodule SocialNetwork.Content.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string

    belongs_to :author, SocialNetwork.Accounts.User
    belongs_to :post, SocialNetwork.Content.Post
    belongs_to :parent, SocialNetwork.Content.Comment
    has_many :replies, SocialNetwork.Content.Comment, foreign_key: :parent_id
    has_many :likes, SocialNetwork.Content.Like

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :post_id, :parent_id])
    |> validate_required([:body, :author_id, :post_id])
  end
end
