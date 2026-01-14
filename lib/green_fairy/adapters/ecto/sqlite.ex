defmodule GreenFairy.Adapters.Ecto.SQLite do
  @moduledoc """
  SQLite adapter struct for filter protocol dispatch.

  This struct represents a SQLite database connection. SQLite has limited
  support for advanced features like geo queries, so many filters will
  use approximations or return errors.

  ## Options

  - `:repo` - The Ecto repo module

  ## Example

      adapter = GreenFairy.Adapters.Ecto.SQLite.new(MyApp.Repo)

  ## Limitations

  - **Geo queries**: No native spatial support. Geo.Near uses Haversine
    approximation which may be slow for large datasets.
  - **Full-text search**: Basic LIKE-based matching only.

  """

  defstruct [:repo]

  @type t :: %__MODULE__{
          repo: module()
        }

  @doc "Create a new SQLite adapter"
  @spec new(module(), keyword()) :: t()
  def new(repo, _opts \\ []) do
    %__MODULE__{repo: repo}
  end
end
