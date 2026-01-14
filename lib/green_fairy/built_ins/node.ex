defmodule GreenFairy.BuiltIns.Node do
  @moduledoc """
  Built-in Relay Node interface.

  This interface provides the standard Relay Global Object Identification
  pattern with a globally unique ID field.

  ## Usage

  Types can implement this interface:

      defmodule MyApp.GraphQL.Types.User do
        use GreenFairy.Type
        import GreenFairy.Relay.Field

        type "User", struct: MyApp.User do
          implements GreenFairy.BuiltIns.Node

          global_id :id  # Generates globally unique ID
          field :email, :string
        end
      end

  ## With Custom Node Resolution

  For the `node(id: ID!)` query to work, define a node resolver:

      type "User", struct: MyApp.User do
        implements GreenFairy.BuiltIns.Node

        node_resolver fn id, _ctx ->
          MyApp.Accounts.get_user(id)
        end

        global_id :id
        field :email, :string
      end

  """

  use GreenFairy.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)

    resolve_type fn
      %{__struct__: struct}, %{schema: schema} ->
        # Try to find the type that has this struct
        find_type_for_struct(struct, schema)

      _, _ ->
        nil
    end
  end

  @doc """
  Finds the GraphQL type identifier for a given Elixir struct.

  This uses the GreenFairy.Registry to look up types by their struct.
  """
  def find_type_for_struct(struct, schema) do
    # First try the registry
    case GreenFairy.Registry.type_for_struct(struct) do
      {:ok, identifier} ->
        identifier

      :error ->
        # Fall back to scanning schema types
        schema.__absinthe_types__()
        |> Enum.find_value(&match_struct_type(&1, schema, struct))
    end
  end

  defp match_struct_type({identifier, _}, schema, struct) do
    case Absinthe.Schema.lookup_type(schema, identifier) do
      %{__private__: private} = _type ->
        case Keyword.get(private, :__green_fairy_struct__) do
          ^struct -> identifier
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
