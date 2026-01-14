defmodule SocialNetwork.Repo.Migrations.CreateFriendships do
  use Ecto.Migration

  def change do
    create table(:friendships) do
      add :status, :string, null: false, default: "pending"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :friend_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:friendships, [:user_id])
    create index(:friendships, [:friend_id])
    create unique_index(:friendships, [:user_id, :friend_id])
  end
end
