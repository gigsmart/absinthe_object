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

### 1. Define a Type

Types represent your domain objects. Fields are automatically resolved from the backing struct:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Types

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string

    # Associations are automatically batch-loaded
    field :posts, list_of(Types.Post)
  end
end
```

No resolvers needed - GreenFairy automatically maps fields to struct keys and batch-loads associations.

### 2. Define Input Types

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :name, :string
  end
end
```

### 3. Define Queries

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use GreenFairy.Query

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Inputs

  queries do
    field :user, Types.User do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.User.get/3
    end
  end
end
```

### 4. Define Mutations

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use GreenFairy.Mutation

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Inputs

  mutations do
    field :create_user, Types.User do
      arg :input, non_null(Inputs.CreateUserInput)
      resolve &MyApp.Resolvers.User.create/3
    end
  end
end
```

### 5. Assemble the Schema

The schema auto-discovers everything under the specified namespace:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    discover: [MyApp.GraphQL],
    repo: MyApp.Repo
end
```

That's it! No `import_types`, no `query do ... end` blocks needed.

## What's Automatic

GreenFairy handles common patterns automatically:

- **Field Resolution** - Struct keys are auto-resolved, no explicit resolvers needed
- **Association Loading** - Uses DataLoader to batch-load related records
- **Type Discovery** - Types are found by walking the schema graph from your operations
- **CQL Filtering** - Filter and order inputs are generated for types with `:struct` option
- **Interface Resolution** - Types with `implements` are auto-resolved by struct

## Directory Structure

```
lib/my_app/graphql/
├── schema.ex           # Main schema
├── types/              # Object types
├── interfaces/         # Interfaces
├── inputs/             # Input types
├── enums/              # Enums
├── queries/            # Query modules
├── mutations/          # Mutation modules
└── resolvers/          # Resolver logic (only for operations)
```

## Next Steps

- [Types Overview](types.md) - All type kinds
- [Object Types](object-types.md) - Detailed type guide
- [Connections](connections.md) - Pagination
- [CQL](cql.md) - Filtering
