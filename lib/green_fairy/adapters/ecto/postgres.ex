defmodule GreenFairy.Adapters.Ecto.Postgres do
  @moduledoc """
  PostgreSQL adapter struct for filter protocol dispatch.

  This struct represents a PostgreSQL database connection with optional
  extensions like PostGIS. The `GreenFairy.Filter` protocol dispatches
  on this struct to apply PostgreSQL-specific filter implementations.

  ## Options

  - `:repo` - The Ecto repo module
  - `:extensions` - List of enabled extensions (e.g., `[:postgis, :pg_trgm]`)

  ## Example

      adapter = GreenFairy.Adapters.Ecto.Postgres.new(MyApp.Repo,
        extensions: [:postgis]
      )

      # Check extension availability
      GreenFairy.Adapters.Ecto.Postgres.postgis?(adapter)
      #=> true

  """

  defstruct [:repo, extensions: []]

  @type extension :: :postgis | :pg_trgm | :fuzzystrmatch | atom()

  @type t :: %__MODULE__{
          repo: module(),
          extensions: [extension()]
        }

  @doc "Create a new Postgres adapter"
  @spec new(module(), keyword()) :: t()
  def new(repo, opts \\ []) do
    %__MODULE__{
      repo: repo,
      extensions: opts[:extensions] || []
    }
  end

  @doc "Check if PostGIS extension is enabled"
  @spec postgis?(t()) :: boolean()
  def postgis?(%__MODULE__{extensions: ext}), do: :postgis in ext

  @doc "Check if pg_trgm extension is enabled for fuzzy text search"
  @spec pg_trgm?(t()) :: boolean()
  def pg_trgm?(%__MODULE__{extensions: ext}), do: :pg_trgm in ext

  @doc "Check if fuzzystrmatch extension is enabled for phonetic matching"
  @spec fuzzystrmatch?(t()) :: boolean()
  def fuzzystrmatch?(%__MODULE__{extensions: ext}), do: :fuzzystrmatch in ext
end
