defmodule GreenFairy.Mutation do
  @moduledoc """
  Defines mutation fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Mutations.UserMutations do
        use GreenFairy.Mutation

        mutations do
          field :create_user, MyApp.GraphQL.Types.User do
            arg :input, MyApp.GraphQL.Inputs.CreateUserInput, null: false

            middleware MyApp.Middleware.Authenticate
            resolve &MyApp.Resolvers.User.create/3
          end

          field :update_user, MyApp.GraphQL.Types.User do
            arg :id, :id, null: false
            arg :input, MyApp.GraphQL.Inputs.UpdateUserInput, null: false

            resolve &MyApp.Resolvers.User.update/3
          end
        end
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import GreenFairy.Mutation, only: [mutations: 1]

      Module.register_attribute(__MODULE__, :green_fairy_mutations, accumulate: false)

      @before_compile GreenFairy.Mutation
    end
  end

  @doc """
  Defines mutation fields.

  ## Examples

      mutations do
        field :create_user, :user do
          arg :input, :create_user_input, null: false
          resolve &Resolver.create_user/3
        end
      end

  """
  defmacro mutations(do: block) do
    quote do
      @green_fairy_mutations true

      # Store the block for later extraction by the schema
      def __green_fairy_mutation_fields__ do
        unquote(Macro.escape(block))
      end

      # Define mutations object that can be imported
      object :green_fairy_mutations do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_mutations = Module.get_attribute(env.module, :green_fairy_mutations)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :mutations,
          has_mutations: unquote(has_mutations || false)
        }
      end

      @doc false
      def __green_fairy_kind__ do
        :mutations
      end
    end
  end
end
