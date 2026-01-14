defmodule GreenFairy.Input do
  @moduledoc """
  Defines a GraphQL input object type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Inputs.CreateUserInput do
        use GreenFairy.Input

        input "CreateUserInput" do
          field :email, :string, null: false
          field :first_name, :string, null: false
          field :organization_id, :id
        end
      end

  ## Authorization

  Control which input fields a user can provide:

      defmodule MyApp.GraphQL.Inputs.CreateUserInput do
        use GreenFairy.Input

        input "CreateUserInput" do
          authorize fn input, ctx ->
            if ctx[:current_user]?.admin do
              :all
            else
              [:email, :first_name, :last_name]  # Non-admins can't set role
            end
          end

          field :email, non_null(:string)
          field :first_name, non_null(:string)
          field :last_name, :string
          field :role, :string  # Only admins can set this
        end
      end

  When a user tries to provide unauthorized fields, they will be stripped
  from the input or rejected (depending on configuration).

  ## Options

  - `:description` - Description of the input type (can also use @desc)

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [input_object: 2]

      import GreenFairy.Input, only: [input: 2, input: 3, authorize: 1]

      Module.register_attribute(__MODULE__, :green_fairy_input, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_authorize_fn, accumulate: false)

      @before_compile GreenFairy.Input
    end
  end

  @doc """
  Sets up field-level authorization for this input type.

  The authorize function receives the input map and context, and returns
  which fields are allowed.

  ## Examples

      input "CreateUserInput" do
        authorize fn input, ctx ->
          if ctx[:current_user]?.admin, do: :all, else: [:email, :name]
        end

        field :email, non_null(:string)
        field :name, :string
        field :role, :string  # Admin only
      end

  ## Return Values

  - `:all` - All fields allowed
  - `:none` - No fields allowed (reject input)
  - `[:field1, :field2]` - Only these fields allowed

  """
  defmacro authorize(func) do
    quote do
      @green_fairy_authorize_fn unquote(Macro.escape(func))
    end
  end

  @doc """
  Defines a GraphQL input object type.

  ## Examples

      input "CreateUserInput" do
        field :email, :string, null: false
        field :name, :string
      end

  """
  defmacro input(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)
    env = __CALLER__

    # Transform block to extract authorize declarations
    transformed_block = transform_input_block(block, env)

    quote do
      @green_fairy_input %{
        kind: :input_object,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.input_object unquote(identifier) do
        unquote(transformed_block)
      end
    end
  end

  # Transform block to handle authorize declarations
  defp transform_input_block({:__block__, meta, statements}, env) do
    transformed = Enum.map(statements, &transform_input_statement(&1, env))
    {:__block__, meta, transformed}
  end

  defp transform_input_block(statement, env) do
    transform_input_statement(statement, env)
  end

  defp transform_input_statement({:authorize, _meta, [func]}, _env) do
    quote do
      @green_fairy_authorize_fn unquote(Macro.escape(func))
    end
  end

  defp transform_input_statement(other, _env), do: other

  @doc false
  defmacro __before_compile__(env) do
    input_def = Module.get_attribute(env.module, :green_fairy_input)
    authorize_fn = Module.get_attribute(env.module, :green_fairy_authorize_fn)

    # Generate authorization function
    authorize_impl = generate_authorize_impl(authorize_fn)

    quote do
      # Authorization implementation
      unquote(authorize_impl)

      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :input_object,
          name: unquote(input_def[:name]),
          identifier: unquote(input_def[:identifier])
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(input_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :input_object
      end
    end
  end

  # Generate the __authorize__/2 implementation
  defp generate_authorize_impl(nil) do
    quote do
      @doc """
      Determines which input fields are allowed for the given context.
      """
      def __authorize__(input, context) do
        :all
      end

      @doc """
      Filters input to only include authorized fields.
      """
      def __filter_input__(input, context) when is_map(input) do
        {:ok, input}
      end

      @doc false
      def __has_authorization__, do: false
    end
  end

  defp generate_authorize_impl(authorize_fn) do
    quote do
      @doc """
      Determines which input fields are allowed for the given context.
      """
      def __authorize__(input, context) do
        auth_fn = unquote(authorize_fn)
        auth_fn.(input, context)
      end

      @doc """
      Filters input to only include authorized fields.

      Returns `{:ok, filtered_input}` or `{:error, {:unauthorized_fields, fields}}`.
      """
      def __filter_input__(input, context) when is_map(input) do
        case __authorize__(input, context) do
          :all ->
            {:ok, input}

          :none ->
            {:error, :unauthorized}

          allowed_fields when is_list(allowed_fields) ->
            input_fields = Map.keys(input)
            unauthorized = input_fields -- allowed_fields

            if Enum.empty?(unauthorized) do
              {:ok, input}
            else
              {:error, {:unauthorized_fields, unauthorized}}
            end
        end
      end

      @doc false
      def __has_authorization__, do: true
    end
  end
end
