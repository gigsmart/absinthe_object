defmodule GreenFairy.Query do
  @moduledoc """
  Defines query fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Queries.UserQueries do
        use GreenFairy.Query

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

      import GreenFairy.Query, only: [queries: 1]
      import GreenFairy.Field.Connection, only: [connection: 2, connection: 3]

      Module.register_attribute(__MODULE__, :green_fairy_queries, accumulate: false)

      @before_compile GreenFairy.Query
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
      @green_fairy_queries true

      # Store the block for later extraction by the schema
      def __green_fairy_query_fields__ do
        unquote(Macro.escape(block))
      end

      # Define queries object that can be imported
      object :green_fairy_queries do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_queries = Module.get_attribute(env.module, :green_fairy_queries)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :queries,
          has_queries: unquote(has_queries || false)
        }
      end

      @doc false
      def __green_fairy_kind__ do
        :queries
      end
    end
  end
end
