defmodule GreenFairy.Union do
  @moduledoc """
  Defines a GraphQL union type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Unions.SearchResult do
        use GreenFairy.Union

        union "SearchResult" do
          types [:user, :post, :comment]

          resolve_type fn
            %MyApp.User{}, _ -> :user
            %MyApp.Post{}, _ -> :post
            %MyApp.Comment{}, _ -> :comment
            _, _ -> nil
          end
        end
      end

  ## Options

  - `:description` - Description of the union type (can also use @desc)

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [union: 2]

      import GreenFairy.Union, only: [union: 2, union: 3]

      Module.register_attribute(__MODULE__, :green_fairy_union, accumulate: false)

      @before_compile GreenFairy.Union
    end
  end

  @doc """
  Defines a GraphQL union type.

  ## Examples

      union "SearchResult" do
        types [:user, :post, :comment]

        resolve_type fn
          %MyApp.User{}, _ -> :user
          %MyApp.Post{}, _ -> :post
          _, _ -> nil
        end
      end

  """
  defmacro union(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)

    quote do
      @green_fairy_union %{
        kind: :union,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.union unquote(identifier) do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    union_def = Module.get_attribute(env.module, :green_fairy_union)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :union,
          name: unquote(union_def[:name]),
          identifier: unquote(union_def[:identifier])
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(union_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :union
      end
    end
  end
end
