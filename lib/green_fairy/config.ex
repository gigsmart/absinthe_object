defmodule GreenFairy.Config do
  @moduledoc """
  Global configuration for GreenFairy.

  This module provides a way to configure global defaults that apply across
  all types in your schema, including:

  - **Global Authorization** - Default authorization that applies to all types
  - **Default Node Resolution** - How to fetch nodes by ID

  ## Usage

  Configure in your schema module:

      defmodule MyApp.GraphQL.Schema do
        use GreenFairy.Schema, discover: [MyApp.GraphQL]
        use GreenFairy.Relay, repo: MyApp.Repo

        use GreenFairy.Config,
          authorize: fn object, ctx ->
            # Global authorization - runs before type-specific authorization
            if ctx[:current_user] do
              :all
            else
              :none
            end
          end,
          node_resolver: fn type_module, id, ctx ->
            # Default way to fetch nodes
            struct = type_module.__green_fairy_struct__()
            MyApp.Repo.get(struct, id)
          end
      end

  ## Authorization Composition

  When both global and type-level authorization are defined:

  1. Global authorization runs first
  2. If global returns `:none`, the object is hidden
  3. If global returns `:all` or a field list, type-level authorization runs
  4. The final visible fields are the intersection of both

  ## Options

  - `:authorize` - Global authorization function `fn object, ctx -> :all | :none | [fields] end`
  - `:authorize_with_info` - Authorization with path info `fn object, ctx, info -> ... end`
  - `:node_resolver` - Default node resolver `fn type_module, id, ctx -> result end`

  """

  @doc """
  Configures global defaults for GreenFairy.
  """
  defmacro __using__(opts) do
    quote do
      @__green_fairy_config__ unquote(opts)

      # Store configuration for runtime access
      def __green_fairy_global_config__ do
        @__green_fairy_config__
      end

      # Make authorize function available
      if unquote(opts[:authorize]) do
        def __global_authorize__(object, ctx) do
          auth_fn = unquote(opts[:authorize])
          auth_fn.(object, ctx)
        end

        def __global_authorize__(object, ctx, _info) do
          __global_authorize__(object, ctx)
        end
      end

      if unquote(opts[:authorize_with_info]) do
        def __global_authorize__(object, ctx, info) do
          auth_fn = unquote(opts[:authorize_with_info])
          auth_fn.(object, ctx, info)
        end
      end

      # Default implementations if no authorize is provided
      unless unquote(opts[:authorize]) || unquote(opts[:authorize_with_info]) do
        def __global_authorize__(_object, _ctx), do: :all
        def __global_authorize__(_object, _ctx, _info), do: :all
      end

      @before_compile GreenFairy.Config
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Store the node resolver in the relay options if provided
      if @__green_fairy_config__[:node_resolver] do
        # Merge with existing relay options if present
        if Module.get_attribute(__MODULE__, :__relay_node_opts__) do
          @__relay_node_opts__ Keyword.merge(
                                 @__relay_node_opts__,
                                 node_resolver: @__green_fairy_config__[:node_resolver]
                               )
        end
      end
    end
  end

  @doc """
  Composes two authorization results.

  Returns the intersection of allowed fields when both allow access.

  ## Examples

      compose_auth(:all, :all)           #=> :all
      compose_auth(:all, [:id, :name])   #=> [:id, :name]
      compose_auth([:id, :name], :all)   #=> [:id, :name]
      compose_auth(:none, :all)          #=> :none
      compose_auth(:all, :none)          #=> :none
      compose_auth([:id, :name], [:id])  #=> [:id]

  """
  def compose_auth(:none, _), do: :none
  def compose_auth(_, :none), do: :none
  def compose_auth(:all, result), do: result
  def compose_auth(result, :all), do: result

  def compose_auth(fields1, fields2) when is_list(fields1) and is_list(fields2) do
    # Intersection of both field lists
    fields1
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(fields2))
    |> MapSet.to_list()
  end

  @doc """
  Checks if a schema has global authorization configured.
  """
  def has_global_auth?(schema) do
    function_exported?(schema, :__global_authorize__, 2) ||
      function_exported?(schema, :__global_authorize__, 3)
  end

  @doc """
  Runs global authorization for an object.

  Returns the authorization result from the schema's global authorize function,
  or `:all` if no global authorization is configured.
  """
  def run_global_auth(schema, object, ctx, info \\ nil) do
    cond do
      info && function_exported?(schema, :__global_authorize__, 3) ->
        schema.__global_authorize__(object, ctx, info)

      function_exported?(schema, :__global_authorize__, 2) ->
        schema.__global_authorize__(object, ctx)

      true ->
        :all
    end
  end
end
