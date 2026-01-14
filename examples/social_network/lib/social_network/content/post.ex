defmodule SocialNetwork.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :body, :string
    field :media_url, :string
    field :visibility, Ecto.Enum, values: [:public, :friends, :private]

    belongs_to :author, SocialNetwork.Accounts.User
    has_many :comments, SocialNetwork.Content.Comment
    has_many :likes, SocialNetwork.Content.Like

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :media_url, :visibility, :author_id])
    |> validate_required([:body, :author_id])
  end
end
