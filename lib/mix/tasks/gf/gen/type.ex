defmodule Mix.Tasks.Gf.Gen.Type do
  @shortdoc "Generates an GreenFairy type module"

  @moduledoc """
  Generates an GreenFairy type module.

  ## Usage

      mix absinthe.object.gen.type User email:string:required name:string

  ## Arguments

  * `name` - The type name in PascalCase (e.g., User, BlogPost)
  * `fields` - Field specifications (see below)

  ## Field Syntax

      name:type[:modifier]

  Examples:
      email:string:required      # field :email, :string, null: false
      name:string                # field :name, :string
      age:integer                # field :age, :integer
      posts:has_many:Post        # has_many :posts, MyApp.GraphQL.Types.Post
      org:belongs_to:Organization  # belongs_to :org, MyApp.GraphQL.Types.Organization
      friends:connection:User    # connection :friends, MyApp.GraphQL.Types.User

  ## Options

  * `--implements` - Interfaces to implement (comma-separated)
  * `--no-struct` - Don't associate a backing struct
  * `--no-node` - Don't implement Node interface by default

  ## Examples

      mix absinthe.object.gen.type User email:string:required name:string
      mix absinthe.object.gen.type Post title:string body:string author:belongs_to:User
      mix absinthe.object.gen.type User --implements=Node,Timestampable
  """

  use Mix.Task

  alias Mix.Tasks.Gf.Gen

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        switches: [implements: :string, no_struct: :boolean, no_node: :boolean],
        aliases: [i: :implements]
      )

    case args do
      [] ->
        Mix.shell().error("Usage: mix absinthe.object.gen.type TypeName field:type ...")
        exit({:shutdown, 1})

      [name | field_specs] ->
        generate(name, field_specs, opts)
    end
  end

  defp generate(name, field_specs, opts) do
    fields = Enum.map(field_specs, &Gen.parse_field/1)
    path = Gen.type_path(name)

    if File.exists?(path) do
      Mix.shell().error("File already exists: #{path}")
      exit({:shutdown, 1})
    end

    content = build_content(name, fields, opts)
    Gen.write_file(path, content)

    Mix.shell().info("""

    Type #{name} created!

    Don't forget to:
    1. Add any custom resolvers
    2. Configure DataLoader sources if using relationships
    """)
  end

  defp build_content(name, fields, opts) do
    module_name = "#{Gen.graphql_namespace()}.Types.#{name}"
    struct_module = unless opts[:no_struct], do: Gen.resolve_struct_module(name)
    implements = build_implements(opts)

    {basic_fields, relationship_fields} =
      Enum.split_with(fields, fn f ->
        f.type not in [:has_many, :has_one, :belongs_to, :connection]
      end)

    """
    defmodule #{module_name} do
      use GreenFairy.Type

      #{type_declaration(name, struct_module, implements)}
        #{build_fields(basic_fields)}
        #{build_relationships(relationship_fields)}
      end
    end
    """
    |> String.trim()
    |> format_code()
  end

  defp type_declaration(name, nil, implements) do
    """
    type "#{name}" do
      #{implements}
    """
    |> String.trim_trailing()
  end

  defp type_declaration(name, struct_module, implements) do
    """
    type "#{name}", struct: #{struct_module} do
      #{implements}
    """
    |> String.trim_trailing()
  end

  defp build_implements(opts) do
    custom = parse_implements_opt(opts[:implements])

    default =
      if opts[:no_node] do
        []
      else
        Gen.default_implements()
      end

    Enum.map_join(default ++ custom, "\n    ", fn
      mod when is_atom(mod) -> "implements #{inspect(mod)}"
      str when is_binary(str) -> "implements #{Gen.resolve_interface_module(str)}"
    end)
  end

  defp parse_implements_opt(nil), do: []

  defp parse_implements_opt(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp build_fields([]), do: ""

  defp build_fields(fields) do
    Enum.map_join(fields, "\n    ", &Gen.field_to_code/1)
  end

  defp build_relationships([]), do: ""

  defp build_relationships(fields) do
    code = Enum.map_join(fields, "\n    ", &Gen.field_to_code/1)
    "\n    #{code}"
  end

  defp format_code(code) do
    case Code.format_string!(code) do
      formatted -> IO.iodata_to_binary(formatted) <> "\n"
    end
  rescue
    _ -> code <> "\n"
  end
end
