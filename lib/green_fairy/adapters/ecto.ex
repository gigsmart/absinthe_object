defmodule GreenFairy.Adapters.Ecto do
  @moduledoc """
  Backing adapter for Ecto schemas.

  This adapter automatically detects Ecto schemas and provides:

  - **CQL Support**: Extracts field metadata for filtering, infers operators from Ecto types
  - **DataLoader Support**: Configures batched loading using Dataloader.Ecto

  ## Supported Ecto Types

  - `:string` - text operations (eq, neq, contains, starts_with, ends_with, in, is_nil)
  - `:integer`, `:float`, `:decimal` - numeric comparisons (eq, neq, gt, lt, gte, lte, in, is_nil)
  - `:boolean` - equality only (eq, is_nil)
  - `:id`, `:binary_id` - id operations (eq, neq, in, is_nil)
  - `:naive_datetime`, `:utc_datetime`, `:date`, `:time` - temporal comparisons
  - `{:parameterized, Ecto.Enum, _}` - enum operations (eq, neq, in, is_nil)
  - `:map`, `:array` - equality only (eq, is_nil)

  ## Usage

  The Ecto adapter is the default adapter and is auto-detected:

      type "User", struct: MyApp.Accounts.User do
        use GreenFairy.Extensions.CQL

        field :id, non_null(:id)
        field :name, :string
        field :posts, list_of(:post) do
          dataload :posts
        end
      end

  CQL will automatically detect that `MyApp.Accounts.User` is an Ecto schema
  and the adapter will be used for both CQL filtering and DataLoader.
  """

  use GreenFairy.Adapter

  @type_operators %{
    string: [:eq, :neq, :contains, :starts_with, :ends_with, :in, :is_nil],
    integer: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    float: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    decimal: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    boolean: [:eq, :is_nil],
    id: [:eq, :neq, :in, :is_nil],
    binary_id: [:eq, :neq, :in, :is_nil],
    naive_datetime: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    utc_datetime: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    utc_datetime_usec: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    naive_datetime_usec: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    date: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    time: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    time_usec: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    map: [:eq, :is_nil],
    array: [:eq, :is_nil]
  }

  # ===========================================================================
  # Core Callbacks
  # ===========================================================================

  @impl true
  def handles?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  def handles?(_), do: false

  @impl true
  def capabilities, do: [:cql, :dataloader]

  # ===========================================================================
  # CQL Callbacks
  # ===========================================================================

  @impl true
  def queryable_fields(module) do
    if handles?(module) do
      module.__schema__(:fields)
    else
      []
    end
  end

  @impl true
  def field_type(module, field) do
    if handles?(module) do
      module.__schema__(:type, field)
    else
      nil
    end
  end

  @impl true
  def operators_for_type(type) do
    case type do
      # Handle Ecto.Enum parameterized type
      {:parameterized, Ecto.Enum, _} ->
        [:eq, :neq, :in, :is_nil]

      # Handle array types
      {:array, _inner_type} ->
        [:eq, :is_nil]

      # Handle map types
      {:map, _inner_type} ->
        [:eq, :is_nil]

      # Handle embedded schemas
      {:parameterized, Ecto.Embedded, _} ->
        [:eq, :is_nil]

      # Standard types
      type when is_atom(type) ->
        Map.get(@type_operators, type, [:eq, :in])

      # Unknown types default to basic operators
      _ ->
        [:eq, :in]
    end
  end

  # ===========================================================================
  # DataLoader Callbacks
  # ===========================================================================

  @impl true
  def dataloader_source(_module), do: :repo

  @impl true
  def dataloader_batch_key(module, field, args) do
    # For Ecto, we batch by the association and any query args
    {module, field, args}
  end

  @impl true
  def dataloader_default_args(_module, _field), do: %{}

  # ===========================================================================
  # Ecto-Specific Helpers
  # ===========================================================================

  @doc """
  Returns the complete type-to-operators mapping.

  Useful for introspection and documentation.
  """
  def type_operators, do: @type_operators

  @doc """
  Checks if a module is an Ecto schema.

  Convenience function that delegates to `handles?/1`.
  """
  def ecto_schema?(module), do: handles?(module)

  @doc """
  Returns associations defined on an Ecto schema.
  """
  def associations(module) do
    if handles?(module) do
      module.__schema__(:associations)
    else
      []
    end
  end

  @doc """
  Returns the association struct for a given association name.
  """
  def association(module, name) do
    if handles?(module) do
      module.__schema__(:association, name)
    else
      nil
    end
  end

  @doc """
  Returns the primary key fields for an Ecto schema.
  """
  def primary_key(module) do
    if handles?(module) do
      module.__schema__(:primary_key)
    else
      []
    end
  end
end
