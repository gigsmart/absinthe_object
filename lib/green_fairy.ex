defmodule GreenFairy do
  @moduledoc """
  A cleaner DSL for GraphQL schema definitions built on Absinthe.

  ## Overview

  GreenFairy provides a streamlined way to define GraphQL schemas
  following SOLID principles - one module per type, with automatic
  type discovery and smart defaults.

  ## Installation

  Add `green_fairy` to your list of dependencies in `mix.exs`:

      def deps do
        [
          {:green_fairy, "~> 0.1.0"}
        ]
      end

  ## Quick Start

  ### Define a Type

      defmodule MyApp.GraphQL.Types.User do
        use GreenFairy.Type

        type "User", struct: MyApp.User do
          implements MyApp.GraphQL.Interfaces.Node

          field :id, non_null(:id)
          field :email, non_null(:string)
          field :name, :string

          # Computed field
          field :display_name, :string do
            resolve fn user, _, _ ->
              {:ok, user.name || user.email}
            end
          end

          # Relationships with DataLoader
          has_many :posts, MyApp.GraphQL.Types.Post
          belongs_to :organization, MyApp.GraphQL.Types.Organization
        end
      end

  ### Define an Interface

      defmodule MyApp.GraphQL.Interfaces.Node do
        use GreenFairy.Interface

        interface "Node" do
          field :id, non_null(:id)

          resolve_type fn
            %MyApp.User{}, _ -> :user
            %MyApp.Post{}, _ -> :post
            _, _ -> nil
          end
        end
      end

  ### Define Input Types

      defmodule MyApp.GraphQL.Inputs.CreateUserInput do
        use GreenFairy.Input

        input "CreateUserInput" do
          field :email, non_null(:string)
          field :name, :string
        end
      end

  ### Define Enums

      defmodule MyApp.GraphQL.Enums.UserRole do
        use GreenFairy.Enum

        enum "UserRole" do
          value :admin
          value :user
          value :guest
        end
      end

  ### Define Queries

      defmodule MyApp.GraphQL.Queries.UserQueries do
        use GreenFairy.Query

        queries do
          field :user, :user do
            arg :id, non_null(:id)
            resolve &MyApp.Resolvers.User.get/3
          end
        end
      end

  ### Define Mutations

      defmodule MyApp.GraphQL.Mutations.UserMutations do
        use GreenFairy.Mutation

        mutations do
          field :create_user, :user do
            arg :input, non_null(:create_user_input)
            middleware MyApp.Middleware.Authenticate
            resolve &MyApp.Resolvers.User.create/3
          end
        end
      end

  ## Available Modules

  ### Core DSL
  - `GreenFairy.Type` - Define object types
  - `GreenFairy.Interface` - Define interfaces
  - `GreenFairy.Input` - Define input types
  - `GreenFairy.Enum` - Define enums
  - `GreenFairy.Union` - Define unions
  - `GreenFairy.Scalar` - Define custom scalars

  ### Operations
  - `GreenFairy.Query` - Define query fields (grouped with mutations/subscriptions)
  - `GreenFairy.Mutation` - Define mutation fields (grouped with queries/subscriptions)
  - `GreenFairy.Subscription` - Define subscription fields (grouped with queries/mutations)
  - `GreenFairy.Operations` - Define all operations in one module

  ### Root Types (Standalone)
  - `GreenFairy.RootQuery` - Define root query module
  - `GreenFairy.RootMutation` - Define root mutation module
  - `GreenFairy.RootSubscription` - Define root subscription module

  ### Schema & Discovery
  - `GreenFairy.Schema` - Schema with auto-discovery
  - `GreenFairy.Discovery` - Type discovery utilities

  ### Field Helpers
  - `GreenFairy.Field.Connection` - Relay-style pagination
  - `GreenFairy.Field.Dataloader` - DataLoader integration
  - `GreenFairy.Field.Middleware` - Middleware helpers

  ### Built-ins
  - `GreenFairy.BuiltIns.Node` - Relay Node interface
  - `GreenFairy.BuiltIns.PageInfo` - Connection PageInfo type
  - `GreenFairy.BuiltIns.Timestampable` - Timestamp interface

  ## Features

  - **One module = one type** - SOLID principles
  - **Auto-discovery** - Types under configured namespaces are discovered automatically
  - **Smart defaults** - Map.get for basic fields, DataLoader for relationships
  - **Auto-generated resolve_type** - From `implements` + struct mapping
  - **Relay-style connections** - With custom edge fields
  - **Middleware support** - Field-level and type-level middleware
  - **Macro extensibility** - Build custom DSL extensions

  ## Recommended Directory Structure

      lib/my_app/graphql/
      ├── schema.ex                    # Main schema
      ├── types/                       # Object types
      │   ├── user.ex
      │   └── post.ex
      ├── interfaces/                  # Interfaces
      │   └── node.ex
      ├── inputs/                      # Input types
      │   └── create_user_input.ex
      ├── enums/                       # Enums
      │   └── user_role.ex
      ├── queries/                     # Query modules
      │   └── user_queries.ex
      ├── mutations/                   # Mutation modules
      │   └── user_mutations.ex
      └── resolvers/                   # Resolvers
          └── user_resolver.ex

  See the [Getting Started guide](getting-started.html) for more details.
  """
end
