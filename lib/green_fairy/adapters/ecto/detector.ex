defmodule GreenFairy.Adapters.Ecto.Detector do
  @moduledoc """
  Auto-detects the database type from an Ecto repo and returns the appropriate adapter.

  ## Usage

      # Auto-detect from repo
      adapter = GreenFairy.Adapters.Ecto.Detector.adapter_for(MyApp.Repo)
      #=> %GreenFairy.Adapters.Ecto.Postgres{repo: MyApp.Repo, extensions: []}

      # With options (e.g., PostGIS)
      adapter = GreenFairy.Adapters.Ecto.Detector.adapter_for(MyApp.Repo,
        extensions: [:postgis]
      )

  ## Supported Adapters

  | Ecto Adapter | Filter Adapter |
  |--------------|----------------|
  | `Ecto.Adapters.Postgres` | `Adapters.Ecto.Postgres` |
  | `Ecto.Adapters.MyXQL` | `Adapters.Ecto.MySQL` |
  | `Ecto.Adapters.Tds` | `Adapters.Ecto.MSSQL` |
  | `Ecto.Adapters.SQLite3` | `Adapters.Ecto.SQLite` |
  | `Exqlite.Ecto` | `Adapters.Ecto.SQLite` |

  """

  alias GreenFairy.Adapters.Ecto.{Postgres, MySQL, SQLite}

  @adapter_mapping %{
    Ecto.Adapters.Postgres => Postgres,
    Ecto.Adapters.MyXQL => MySQL,
    Ecto.Adapters.SQLite3 => SQLite,
    # Alternative SQLite adapter
    Exqlite.Ecto => SQLite
  }

  @doc """
  Returns the appropriate filter adapter struct for the given Ecto repo.

  ## Options

  Options are passed to the adapter's `new/2` function:

  - For Postgres: `:extensions` (e.g., `[:postgis, :pg_trgm]`)
  - For MySQL: `:version` (e.g., `"8.0.28"`)

  ## Examples

      iex> Detector.adapter_for(MyApp.Repo)
      %GreenFairy.Adapters.Ecto.Postgres{repo: MyApp.Repo, extensions: []}

      iex> Detector.adapter_for(MyApp.Repo, extensions: [:postgis])
      %GreenFairy.Adapters.Ecto.Postgres{repo: MyApp.Repo, extensions: [:postgis]}

  """
  @spec adapter_for(module(), keyword()) :: struct() | {:error, {:unknown_adapter, module()}}
  def adapter_for(repo, opts \\ []) do
    ecto_adapter = repo.__adapter__()

    case Map.get(@adapter_mapping, ecto_adapter) do
      nil -> {:error, {:unknown_adapter, ecto_adapter}}
      adapter_module -> adapter_module.new(repo, opts)
    end
  end

  @doc """
  Returns the appropriate filter adapter struct, raising on unknown adapters.
  """
  @spec adapter_for!(module(), keyword()) :: struct()
  def adapter_for!(repo, opts \\ []) do
    case adapter_for(repo, opts) do
      {:error, {:unknown_adapter, ecto_adapter}} ->
        raise ArgumentError, """
        Unknown Ecto adapter: #{inspect(ecto_adapter)}

        Supported adapters:
        #{Enum.map_join(@adapter_mapping, "\n", fn {k, v} -> "  - #{inspect(k)} => #{inspect(v)}" end)}

        You can manually create an adapter:

            GreenFairy.Adapters.Ecto.Postgres.new(#{inspect(repo)})

        Or implement a custom adapter for #{inspect(ecto_adapter)}.
        """

      adapter ->
        adapter
    end
  end

  @doc """
  Checks if the given Ecto adapter is supported.
  """
  @spec supported?(module()) :: boolean()
  def supported?(ecto_adapter) do
    Map.has_key?(@adapter_mapping, ecto_adapter)
  end

  @doc """
  Returns the list of supported Ecto adapters.
  """
  @spec supported_adapters() :: [module()]
  def supported_adapters do
    Map.keys(@adapter_mapping)
  end

  @doc """
  Registers a custom adapter mapping.

  This allows extending support to additional Ecto adapters at runtime.

  ## Example

      Detector.register_adapter(MyCustom.EctoAdapter, MyApp.Adapters.Custom)

  """
  @spec register_adapter(module(), module()) :: :ok
  def register_adapter(ecto_adapter, filter_adapter) do
    # Use persistent_term for efficient runtime lookup
    current = :persistent_term.get({__MODULE__, :custom_adapters}, %{})
    :persistent_term.put({__MODULE__, :custom_adapters}, Map.put(current, ecto_adapter, filter_adapter))
    :ok
  end
end
