defmodule Absinthe.Object.Query do
  @moduledoc """
  Defines query fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Queries.UserQueries do
        use Absinthe.Object.Query

        queries do
          field :user, MyApp.GraphQL.Types.User do
            arg :id, :id, null: false
            resolve &MyApp.Resolvers.User.get/3
          end

          field :users, list_of(MyApp.GraphQL.Types.User) do
            resolve &MyApp.Resolvers.User.list/3
          end
        end
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import Absinthe.Object.Query, only: [queries: 1]
      import Absinthe.Object.Field.Connection, only: [connection: 2, connection: 3]

      Module.register_attribute(__MODULE__, :absinthe_object_queries, accumulate: false)

      @before_compile Absinthe.Object.Query
    end
  end

  @doc """
  Defines query fields.

  ## Examples

      queries do
        field :user, :user do
          arg :id, :id, null: false
          resolve &Resolver.get_user/3
        end
      end

  """
  defmacro queries(do: block) do
    quote do
      @absinthe_object_queries true

      # Store the block for later extraction by the schema
      def __absinthe_object_query_fields__ do
        unquote(Macro.escape(block))
      end

      # Define queries object that can be imported
      object :absinthe_object_queries do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_queries = Module.get_attribute(env.module, :absinthe_object_queries)

    quote do
      @doc false
      def __absinthe_object_definition__ do
        %{
          kind: :queries,
          has_queries: unquote(has_queries || false)
        }
      end

      @doc false
      def __absinthe_object_kind__ do
        :queries
      end
    end
  end
end
