# Global IDs

GreenFairy provides a flexible Global ID system for Relay Object Identification. Global IDs uniquely identify objects across your entire schema, encoding both the type and local ID.

## Overview

Global IDs are used for:
- The Relay `node(id: ID!)` query
- The `expose :id` type macro
- Any field requiring globally unique identification

## Default Implementation

By default, GreenFairy uses Base64 encoding following the Relay specification:

```elixir
# Format: Base64("TypeName:localId")
GreenFairy.GlobalId.encode("User", 123)
#=> "VXNlcjoxMjM="

GreenFairy.GlobalId.decode("VXNlcjoxMjM=")
#=> {:ok, {"User", "123"}}
```

## Custom GlobalId Implementation

Implement the `GreenFairy.GlobalId` behaviour to use custom encoding:

```elixir
defmodule MyApp.HashidsGlobalId do
  @behaviour GreenFairy.GlobalId

  @impl true
  def encode(type_name, id) when is_atom(type_name) do
    encode(atom_to_type_name(type_name), id)
  end

  def encode(type_name, id) when is_binary(type_name) do
    # Use Hashids for shorter, URL-safe IDs
    Hashids.encode(hashids(), [type_index(type_name), id])
  end

  @impl true
  def decode(global_id) do
    case Hashids.decode(hashids(), global_id) do
      {:ok, [type_index, local_id]} ->
        {:ok, {index_to_type(type_index), local_id}}
      _ ->
        {:error, :invalid_global_id}
    end
  end

  defp hashids do
    Hashids.new(salt: "my-secret-salt", min_len: 8)
  end

  defp type_index("User"), do: 1
  defp type_index("Post"), do: 2
  defp type_index("Comment"), do: 3
  # ...

  defp index_to_type(1), do: "User"
  defp index_to_type(2), do: "Post"
  defp index_to_type(3), do: "Comment"
  # ...

  defp atom_to_type_name(atom) do
    atom |> Atom.to_string() |> Macro.camelize()
  end
end
```

## Configuring GlobalId

### Per-Schema Configuration

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    query: MyApp.GraphQL.RootQuery,
    repo: MyApp.Repo,
    global_id: MyApp.HashidsGlobalId
end
```

### Application-Wide Configuration

```elixir
# config/config.exs
config :green_fairy,
  global_id: MyApp.HashidsGlobalId
```

## API Reference

### GreenFairy.GlobalId Behaviour

```elixir
@callback encode(type_name :: atom() | String.t(), id :: any()) :: String.t()
@callback decode(global_id :: String.t()) :: {:ok, {String.t(), any()}} | {:error, term()}
```

### Module Functions

| Function | Description |
|----------|-------------|
| `encode(type, id)` | Encodes using configured implementation |
| `decode(global_id)` | Decodes, returns `{:ok, {type, id}}` |
| `decode!(global_id)` | Decodes, raises on error |
| `decode_id(global_id)` | Decodes and parses integer IDs |
| `type(global_id)` | Extracts just the type name |
| `local_id(global_id)` | Extracts just the local ID |
| `default()` | Returns the configured implementation |

### Usage Examples

```elixir
alias GreenFairy.GlobalId

# Encoding
GlobalId.encode("User", 123)
#=> "VXNlcjoxMjM=" (or custom encoding)

GlobalId.encode(:user_profile, 42)
#=> "VXNlclByb2ZpbGU6NDI=" (atoms converted to PascalCase)

# Decoding
GlobalId.decode("VXNlcjoxMjM=")
#=> {:ok, {"User", "123"}}

GlobalId.decode!("VXNlcjoxMjM=")
#=> {"User", "123"}

# Parse integer IDs
GlobalId.decode_id("VXNlcjoxMjM=")
#=> {:ok, {"User", 123}}  # Note: integer, not string

# Extract parts
GlobalId.type("VXNlcjoxMjM=")
#=> {:ok, "User"}

GlobalId.local_id("VXNlcjoxMjM=")
#=> {:ok, "123"}
```

## Integration Points

### Node Resolution

The `node_field` macro uses GlobalId to resolve nodes:

```elixir
queries do
  node_field()  # Uses configured GlobalId for decoding
end
```

### Type Expose

The `expose :id` macro uses GlobalId for ID decoding:

```elixir
type "User", struct: MyApp.User do
  expose :id  # Decodes GlobalId before fetching
end
```

### Manual Resolution

Use GlobalId in custom resolvers:

```elixir
field :transfer_ownership, :item do
  arg :item_id, non_null(:id)
  arg :new_owner_id, non_null(:id)

  resolve fn _, args, ctx ->
    with {:ok, {"Item", item_id}} <- GlobalId.decode_id(args.item_id),
         {:ok, {"User", user_id}} <- GlobalId.decode_id(args.new_owner_id) do
      MyApp.Items.transfer(item_id, user_id)
    end
  end
end
```

## Best Practices

1. **Keep encoding stable** - Changing encoding breaks existing client IDs
2. **Use integer parsing** - Use `decode_id/1` when you need integer IDs
3. **Handle errors gracefully** - Always pattern match decode results
4. **Test with edge cases** - Test with special characters, long IDs, etc.

## Backwards Compatibility

`GreenFairy.Relay.GlobalId` delegates to the new system for backwards compatibility:

```elixir
# Both work identically
GreenFairy.Relay.GlobalId.encode("User", 123)
GreenFairy.GlobalId.encode("User", 123)
```
