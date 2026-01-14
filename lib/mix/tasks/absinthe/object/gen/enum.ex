defmodule Mix.Tasks.Absinthe.Object.Gen.Enum do
  @shortdoc "Generates an Absinthe.Object enum module"

  @moduledoc """
  Generates an Absinthe.Object enum type module.

  ## Usage

      mix absinthe.object.gen.enum UserStatus active inactive pending

  ## Arguments

  * `name` - The enum type name in PascalCase (e.g., UserStatus)
  * `values` - Enum values (snake_case)

  ## Examples

      mix absinthe.object.gen.enum UserStatus active inactive pending suspended
      mix absinthe.object.gen.enum PostVisibility public private unlisted
  """

  use Mix.Task

  alias Mix.Tasks.Absinthe.Object.Gen

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        Mix.shell().error("Usage: mix absinthe.object.gen.enum EnumName value1 value2 ...")
        exit({:shutdown, 1})

      [name | values] when values != [] ->
        generate(name, values)

      [_name] ->
        Mix.shell().error("Please provide at least one enum value")
        exit({:shutdown, 1})
    end
  end

  defp generate(name, values) do
    path = Gen.enum_path(name)

    if File.exists?(path) do
      Mix.shell().error("File already exists: #{path}")
      exit({:shutdown, 1})
    end

    content = build_content(name, values)
    Gen.write_file(path, content)

    Mix.shell().info("\nEnum #{name} created!")
  end

  defp build_content(name, values) do
    module_name = "#{Gen.graphql_namespace()}.Enums.#{name}"

    """
    defmodule #{module_name} do
      use Absinthe.Object.Enum

      enum "#{name}" do
        #{build_values(values)}
      end
    end
    """
    |> String.trim()
    |> format_code()
  end

  defp build_values(values) do
    values
    |> Enum.map(fn val -> "value :#{val}" end)
    |> Enum.join("\n    ")
  end

  defp format_code(code) do
    case Code.format_string!(code) do
      formatted -> IO.iodata_to_binary(formatted) <> "\n"
    end
  rescue
    _ -> code <> "\n"
  end
end
