defmodule GreenFairy.Enum do
  @moduledoc """
  Defines a GraphQL enum type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Enums.UserStatus do
        use GreenFairy.Enum

        enum "UserStatus" do
          value :active
          value :inactive
          value :pending, as: "PENDING_APPROVAL"
        end
      end

  ## Options

  - `:description` - Description of the enum type (can also use @desc)

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [enum: 2, enum: 3]

      import GreenFairy.Enum, only: [enum: 2, enum: 3]

      Module.register_attribute(__MODULE__, :green_fairy_enum, accumulate: false)

      @before_compile GreenFairy.Enum
    end
  end

  @doc """
  Defines a GraphQL enum type.

  ## Examples

      enum "UserStatus" do
        value :active
        value :inactive
        value :pending, as: "PENDING_APPROVAL"
      end

  """
  defmacro enum(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)

    quote do
      @green_fairy_enum %{
        kind: :enum,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.enum unquote(identifier) do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    enum_def = Module.get_attribute(env.module, :green_fairy_enum)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :enum,
          name: unquote(enum_def[:name]),
          identifier: unquote(enum_def[:identifier])
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(enum_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :enum
      end
    end
  end
end
