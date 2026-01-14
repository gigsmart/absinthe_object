defmodule GreenFairy.Adapters.Ecto.MySQL do
  @moduledoc """
  MySQL adapter struct for filter protocol dispatch.

  This struct represents a MySQL database connection. The `GreenFairy.Filter`
  protocol dispatches on this struct to apply MySQL-specific filter implementations.

  ## Options

  - `:repo` - The Ecto repo module
  - `:version` - MySQL version string (for feature detection)

  ## Example

      adapter = GreenFairy.Adapters.Ecto.MySQL.new(MyApp.Repo,
        version: "8.0.28"
      )

      # Check spatial support (requires MySQL 8.0+)
      GreenFairy.Adapters.Ecto.MySQL.spatial?(adapter)
      #=> true

  """

  defstruct [:repo, :version]

  @type t :: %__MODULE__{
          repo: module(),
          version: String.t() | nil
        }

  @doc "Create a new MySQL adapter"
  @spec new(module(), keyword()) :: t()
  def new(repo, opts \\ []) do
    %__MODULE__{
      repo: repo,
      version: opts[:version]
    }
  end

  @doc """
  Check if spatial functions are supported.

  MySQL 8.0+ has full spatial function support including
  `ST_Distance_Sphere` for geographic distance calculations.
  """
  @spec spatial?(t()) :: boolean()
  def spatial?(%__MODULE__{version: nil}), do: true

  def spatial?(%__MODULE__{version: version}) do
    case Version.parse(version) do
      {:ok, v} -> Version.compare(v, %Version{major: 8, minor: 0, patch: 0}) != :lt
      :error -> true
    end
  end

  @doc """
  Check if full-text search with natural language mode is supported.

  Available in all MySQL versions but with varying capabilities.
  """
  @spec fulltext?(t()) :: boolean()
  def fulltext?(%__MODULE__{}), do: true
end
