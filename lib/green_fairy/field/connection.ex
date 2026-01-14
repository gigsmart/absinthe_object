defmodule GreenFairy.Field.Connection do
  @moduledoc """
  Connection support for Relay-style pagination.

  This module provides macros for defining connections with
  auto-generated Connection and Edge types.

  ## Usage

      type "User", struct: MyApp.User do
        connection :friends, MyApp.GraphQL.Types.User do
          edge do
            field :friendship_date, :datetime
          end
          field :total_count, :integer
        end
      end

  """

  @doc """
  Generates a connection field with auto-generated Connection and Edge types.

  ## Options

  - `:node` - The node type identifier (defaults to the type_module's identifier)
  - `:resolve` - Custom resolver function

  """
  defmacro connection(field_name, type_module_or_opts \\ [], do: block) do
    {type_module, opts} =
      case type_module_or_opts do
        opts when is_list(opts) -> {nil, opts}
        module -> {module, []}
      end

    quote do
      require GreenFairy.Field.Connection

      GreenFairy.Field.Connection.__define_connection__(
        unquote(field_name),
        unquote(type_module),
        unquote(opts),
        unquote(Macro.escape(block))
      )
    end
  end

  @doc false
  defmacro __define_connection__(field_name, type_module, opts, block) do
    env = __CALLER__

    type_identifier =
      if type_module do
        type_module = Macro.expand(type_module, env)
        type_module.__green_fairy_identifier__()
      else
        opts[:node]
      end

    connection_name = :"#{field_name}_connection"
    edge_name = :"#{field_name}_edge"

    # Parse the block to extract edge definition and extra fields
    {edge_block, connection_fields} = parse_connection_block(block)

    # Store the connection definition for deferred generation in __before_compile__
    connection_def = %{
      field_name: field_name,
      type_identifier: type_identifier,
      connection_name: connection_name,
      edge_name: edge_name,
      edge_block: edge_block,
      connection_fields: connection_fields
    }

    quote do
      # Store connection definition for deferred type generation
      @green_fairy_connections unquote(Macro.escape(connection_def))

      # Only emit the field reference inline - types are generated in __before_compile__
      field unquote(field_name), unquote(connection_name) do
        arg :first, :integer
        arg :after, :string
        arg :last, :integer
        arg :before, :string
      end
    end
  end

  @doc """
  Generates the edge and connection object types from stored connection definitions.

  Called from Type.__before_compile__ to generate types at module top-level.
  """
  def generate_connection_types(connections) do
    Enum.flat_map(connections, fn conn ->
      edge_type = generate_edge_type(conn)
      connection_type = generate_connection_type(conn)
      [edge_type, connection_type]
    end)
  end

  defp generate_edge_type(conn) do
    edge_name = conn.edge_name
    type_identifier = conn.type_identifier
    edge_block = conn.edge_block

    quote do
      Absinthe.Schema.Notation.object unquote(edge_name) do
        field :node, unquote(type_identifier)
        field :cursor, non_null(:string)
        unquote(edge_block)
      end
    end
  end

  defp generate_connection_type(conn) do
    connection_name = conn.connection_name
    edge_name = conn.edge_name
    connection_fields = conn.connection_fields

    quote do
      Absinthe.Schema.Notation.object unquote(connection_name) do
        field :edges, list_of(unquote(edge_name))
        field :page_info, non_null(:page_info)
        unquote(connection_fields)
      end
    end
  end

  # Parse the connection block to extract edge definition and extra connection fields
  @doc false
  def parse_connection_block(nil), do: {nil, nil}

  def parse_connection_block({:__block__, _, statements}) do
    {edge_blocks, other_statements} =
      Enum.split_with(statements, fn
        {:edge, _, _} -> true
        _ -> false
      end)

    edge_block =
      case edge_blocks do
        [{:edge, _, [[do: block]]} | _] -> block
        [{:edge, _, [_, [do: block]]} | _] -> block
        _ -> nil
      end

    connection_fields =
      case other_statements do
        [] -> nil
        stmts -> {:__block__, [], stmts}
      end

    {edge_block, connection_fields}
  end

  def parse_connection_block({:edge, _, [[do: block]]}) do
    {block, nil}
  end

  def parse_connection_block(other) do
    {nil, other}
  end

  @doc """
  Creates a connection result from a list of items.

  ## Examples

      GreenFairy.Field.Connection.from_list(users, args)

  """
  def from_list(items, args, opts \\ []) do
    cursor_fn = Keyword.get(opts, :cursor_fn, &default_cursor/2)
    first = Map.get(args, :first)
    last = Map.get(args, :last)
    after_cursor = Map.get(args, :after)
    before_cursor = Map.get(args, :before)

    # Apply cursor-based filtering
    items =
      items
      |> maybe_filter_after(after_cursor, cursor_fn)
      |> maybe_filter_before(before_cursor, cursor_fn)

    total = length(items)

    # Apply pagination limits
    {items, has_previous, has_next} =
      case {first, last} do
        {nil, nil} ->
          {items, false, false}

        {first, nil} when is_integer(first) ->
          has_next = total > first
          {Enum.take(items, first), false, has_next}

        {nil, last} when is_integer(last) ->
          has_previous = total > last
          items = Enum.take(items, -last)
          {items, has_previous, false}

        {first, last} when is_integer(first) and is_integer(last) ->
          # First takes precedence
          has_next = total > first
          {Enum.take(items, first), false, has_next}
      end

    # Build edges with cursors
    edges =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        %{
          node: item,
          cursor: cursor_fn.(item, idx)
        }
      end)

    # Build page info
    page_info = %{
      has_next_page: has_next,
      has_previous_page: has_previous,
      start_cursor: List.first(edges)[:cursor],
      end_cursor: List.last(edges)[:cursor]
    }

    {:ok, %{edges: edges, page_info: page_info}}
  end

  @doc """
  Creates a connection result from an Ecto query.

  This function handles cursor-based pagination for Ecto queries.
  """
  def from_query(query, repo, args, opts \\ []) do
    cursor_fn = Keyword.get(opts, :cursor_fn, &default_cursor/2)
    _first = Map.get(args, :first)
    _last = Map.get(args, :last)
    _after_cursor = Map.get(args, :after)
    _before_cursor = Map.get(args, :before)

    # Note: Cursor-based query filtering could be implemented here
    # For now, fetching all and using from_list
    items = repo.all(query)
    from_list(items, args, cursor_fn: cursor_fn)
  end

  # Default cursor function using Base64 encoding of index
  defp default_cursor(_item, idx) do
    Base.encode64("cursor:#{idx}")
  end

  defp maybe_filter_after(items, nil, _cursor_fn), do: items

  defp maybe_filter_after(items, cursor, cursor_fn) do
    items
    |> Enum.with_index()
    |> Enum.drop_while(fn {item, idx} -> cursor_fn.(item, idx) != cursor end)
    |> Enum.drop(1)
    |> Enum.map(fn {item, _idx} -> item end)
  end

  defp maybe_filter_before(items, nil, _cursor_fn), do: items

  defp maybe_filter_before(items, cursor, cursor_fn) do
    items
    |> Enum.with_index()
    |> Enum.take_while(fn {item, idx} -> cursor_fn.(item, idx) != cursor end)
    |> Enum.map(fn {item, _idx} -> item end)
  end
end
