defmodule SocialNetwork.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :body, :text, null: false
      add :media_url, :string
      add :visibility, :string, null: false, default: "public"
      add :author_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:posts, [:author_id])
    create index(:posts, [:visibility])
  end
end
