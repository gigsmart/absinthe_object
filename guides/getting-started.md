# Getting Started

This guide will help you get started with GreenFairy, a cleaner DSL for defining GraphQL schemas in Elixir.

## Installation

Add `green_fairy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:green_fairy, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Define an Interface

Interfaces define a common set of fields that types can implement:

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      _, _ -> nil
    end
  end
end
```

### 2. Define a Type

Types represent your domain objects:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :first_name, :string
    field :last_name, :string

    # Computed field with resolver
    field :full_name, :string do
      resolve fn user, _, _ ->
        {:ok, "#{user.first_name} #{user.last_name}"}
      end
    end
  end
end
```

### 3. Define Input Types

Input types are used for mutations:

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :first_name, :string
    field :last_name, :string
  end
end
```

### 4. Define Queries

Query modules group related query fields:

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use GreenFairy.Query

  queries do
    field :user, :user do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.User.get/3
    end

    field :users, list_of(:user) do
      resolve &MyApp.Resolvers.User.list/3
    end
  end
end
```

### 5. Define Mutations

Mutation modules group related mutation fields:

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use GreenFairy.Mutation

  mutations do
    field :create_user, :user do
      arg :input, non_null(:create_user_input)
      resolve &MyApp.Resolvers.User.create/3
    end
  end
end
```

### 6. Assemble the Schema

The schema module auto-discovers and assembles everything:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    discover: [MyApp.GraphQL]
end
```

That's it! No `import_types`, no `query do ... end` blocks needed.

The schema automatically:
- Discovers all types, interfaces, inputs, enums under `MyApp.GraphQL`
- Imports them all
- Generates root query/mutation/subscription types from your Query/Mutation/Subscription modules

## Directory Structure

We recommend organizing your GraphQL modules like this:

```
lib/my_app/graphql/
├── schema.ex                    # Main schema module
├── types/                       # Object types
│   ├── user.ex
│   └── post.ex
├── interfaces/                  # Interface definitions
│   └── node.ex
├── inputs/                      # Input types
│   └── create_user_input.ex
├── enums/                       # Enum definitions
│   └── user_status.ex
├── queries/                     # Query modules
│   └── user_queries.ex
├── mutations/                   # Mutation modules
│   └── user_mutations.ex
└── resolvers/                   # Resolver logic
    └── user_resolver.ex
```

## Next Steps

- Learn about [Types](types.html) in detail
- Explore [Relationships and DataLoader](relationships.html)
- Set up [Connections for pagination](connections.html)
- Configure [Schema Auto-Discovery](auto-discovery.html)
