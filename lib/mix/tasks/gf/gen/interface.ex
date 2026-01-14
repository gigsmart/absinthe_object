defmodule Mix.Tasks.Gf.Gen.Interface do
  @shortdoc "Generates an GreenFairy interface module"

  @moduledoc """
  Generates an GreenFairy interface module.

  ## Usage

      mix absinthe.object.gen.interface Node id:id:required

  ## Arguments

  * `name` - The interface name in PascalCase (e.g., Node, Timestampable)
  * `fields` - Field specifications

  ## Field Syntax

      name:type[:modifier]

  Examples:
      id:id:required             # field :id, :id, null: false
      inserted_at:datetime       # field :inserted_at, :datetime

  ## Options

  * `--implements` - Other interfaces to implement (comma-separated)

  ## Examples

      mix absinthe.object.gen.interface Node id:id:required
      mix absinthe.object.gen.interface Timestampable inserted_at:datetime updated_at:datetime
      mix absinthe.object.gen.interface Resource id:id:required url:string:required --implements=Node
  """

  use Mix.Task

  alias Mix.Tasks.Gf.Gen

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        switches: [implements: :string],
        aliases: [i: :implements]
      )

    case args do
      [] ->
        Mix.shell().error("Usage: mix absinthe.object.gen.interface InterfaceName field:type ...")
        exit({:shutdown, 1})

      [name | field_specs] ->
        generate(name, field_specs, opts)
    end
  end

  defp generate(name, field_specs, opts) do
    fields = Enum.map(field_specs, &Gen.parse_field/1)
    path = Gen.interface_path(name)

    if File.exists?(path) do
      Mix.shell().error("File already exists: #{path}")
      exit({:shutdown, 1})
    end

    content = build_content(name, fields, opts)
    Gen.write_file(path, content)

    Mix.shell().info("""

    Interface #{name} created!

    Types implementing this interface will automatically have resolve_type generated.
    """)
  end

  defp build_content(name, fields, opts) do
    module_name = "#{Gen.graphql_namespace()}.Interfaces.#{name}"
    implements = build_implements(opts)

    """
    defmodule #{module_name} do
      use GreenFairy.Interface

      interface "#{name}" do
        #{implements}#{build_fields(fields)}
      end
    end
    """
    |> String.trim()
    |> format_code()
  end

  defp build_implements(opts) do
    case parse_implements_opt(opts[:implements]) do
      [] ->
        ""

      interfaces ->
        Enum.map_join(interfaces, "\n    ", fn str ->
          "implements #{Gen.resolve_interface_module(str)}"
        end) <> "\n\n    "
    end
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

  defp format_code(code) do
    case Code.format_string!(code) do
      formatted -> IO.iodata_to_binary(formatted) <> "\n"
    end
  rescue
    _ -> code <> "\n"
  end
end
