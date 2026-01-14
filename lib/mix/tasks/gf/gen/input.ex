defmodule Mix.Tasks.Gf.Gen.Input do
  @shortdoc "Generates an GreenFairy input module"

  @moduledoc """
  Generates an GreenFairy input type module.

  ## Usage

      mix absinthe.object.gen.input CreateUserInput email:string:required name:string

  ## Arguments

  * `name` - The input type name in PascalCase (e.g., CreateUserInput)
  * `fields` - Field specifications

  ## Field Syntax

      name:type[:modifier]

  Examples:
      email:string:required      # field :email, :string, null: false
      name:string                # field :name, :string
      organization_id:id         # field :organization_id, :id

  ## Examples

      mix absinthe.object.gen.input CreateUserInput email:string:required name:string
      mix absinthe.object.gen.input UpdatePostInput title:string body:string
  """

  use Mix.Task

  alias Mix.Tasks.Gf.Gen

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        Mix.shell().error("Usage: mix absinthe.object.gen.input InputName field:type ...")
        exit({:shutdown, 1})

      [name | field_specs] ->
        generate(name, field_specs)
    end
  end

  defp generate(name, field_specs) do
    fields = Enum.map(field_specs, &Gen.parse_field/1)
    path = Gen.input_path(name)

    if File.exists?(path) do
      Mix.shell().error("File already exists: #{path}")
      exit({:shutdown, 1})
    end

    content = build_content(name, fields)
    Gen.write_file(path, content)

    Mix.shell().info("\nInput #{name} created!")
  end

  defp build_content(name, fields) do
    module_name = "#{Gen.graphql_namespace()}.Inputs.#{name}"

    """
    defmodule #{module_name} do
      use GreenFairy.Input

      input "#{name}" do
        #{build_fields(fields)}
      end
    end
    """
    |> String.trim()
    |> format_code()
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
