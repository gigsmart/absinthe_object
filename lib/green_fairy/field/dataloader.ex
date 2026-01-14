defmodule GreenFairy.Field.Dataloader do
  @moduledoc """
  DataLoader integration for relationship fields.

  This module provides resolver generation for relationship fields
  using Absinthe's dataloader integration. It integrates with the
  unified adapter system to automatically configure batch keys and
  sources based on the backing data store.

  ## Usage

  The DataLoader module is used automatically when you define relationships:

      type "User", struct: MyApp.Accounts.User do
        has_many :posts, MyApp.GraphQL.Types.Post
        has_one :profile, MyApp.GraphQL.Types.Profile
        belongs_to :organization, MyApp.GraphQL.Types.Organization
      end

  ## Adapter Integration

  When a struct has a backing adapter (like Ecto), the DataLoader
  automatically uses the adapter to determine:

  - The dataloader source (e.g., `:repo` for Ecto)
  - The batch key format
  - Default args for queries

  ## Custom Configuration

  You can override adapter defaults per-field:

      has_many :active_posts, MyApp.GraphQL.Types.Post,
        args: %{status: :active},
        source: :custom_source

  """

  alias GreenFairy.Adapter

  @doc """
  Generates a DataLoader resolver for a relationship field.

  ## Options

  - `:source` - The dataloader source to use (defaults to adapter's source or `:repo`)
  - `:args` - Additional args to pass to the loader
  - `:callback` - Post-processing callback for results
  - `:adapter` - Explicit adapter to use (defaults to auto-detected)

  """
  def resolver(type_module, field_name, opts \\ []) do
    source_opt = Keyword.get(opts, :source)
    args = Keyword.get(opts, :args, %{})
    callback = Keyword.get(opts, :callback)
    adapter_opt = Keyword.get(opts, :adapter)

    # Determine the struct module for adapter lookup
    struct_module = get_struct_module(type_module)

    # Find adapter for the struct
    adapter =
      if adapter_opt do
        adapter_opt
      else
        if struct_module, do: Adapter.find_adapter(struct_module, nil), else: nil
      end

    # Generate a resolver function that uses dataloader
    fn parent, args_from_query, %{context: context} ->
      # Get adapter-provided default args
      adapter_args =
        if adapter && function_exported?(adapter, :dataloader_default_args, 2) do
          adapter.dataloader_default_args(struct_module, field_name)
        else
          %{}
        end

      # Merge args: adapter defaults < resolver opts < query args
      merged_args =
        adapter_args
        |> Map.merge(args)
        |> Map.merge(args_from_query)

      loader =
        context
        |> Map.get(:loader)
        |> case do
          nil ->
            raise "DataLoader not found in context. Make sure to configure it in your schema."

          loader ->
            loader
        end

      # Determine source: explicit > adapter > context > :repo
      source_name =
        source_opt ||
          adapter_source(adapter, struct_module) ||
          Map.get(context, :dataloader_source) ||
          :repo

      # Determine batch key
      batch_key =
        if adapter && function_exported?(adapter, :dataloader_batch_key, 3) do
          adapter.dataloader_batch_key(struct_module, field_name, merged_args)
        else
          {field_name, merged_args}
        end

      loader
      |> Dataloader.load(source_name, batch_key, parent)
      |> on_load(&handle_dataloader_result(&1, source_name, batch_key, parent, callback))
    end
  end

  defp handle_dataloader_result(loader, source_name, batch_key, parent, callback) do
    result = Dataloader.get(loader, source_name, batch_key, parent)

    if callback do
      callback.(result)
    else
      {:ok, result}
    end
  end

  @doc """
  Creates an on_load callback for async dataloader resolution.
  """
  def on_load(loader, callback) do
    Absinthe.Resolution.Helpers.on_load(loader, callback)
  end

  @doc """
  Returns the dataloader source for a given type module.

  This can be used to programmatically determine which source to use
  for a type.
  """
  def source_for(type_module) do
    struct_module = get_struct_module(type_module)

    if struct_module do
      adapter = Adapter.find_adapter(struct_module, nil)
      adapter_source(adapter, struct_module) || :repo
    else
      :repo
    end
  end

  # Get struct module from type module if available
  defp get_struct_module(type_module) do
    if Code.ensure_loaded?(type_module) &&
         function_exported?(type_module, :__green_fairy_struct__, 0) do
      type_module.__green_fairy_struct__()
    else
      nil
    end
  end

  # Get adapter's dataloader source
  defp adapter_source(nil, _struct_module), do: nil

  defp adapter_source(adapter, struct_module) do
    if function_exported?(adapter, :dataloader_source, 1) do
      adapter.dataloader_source(struct_module)
    else
      nil
    end
  end
end
