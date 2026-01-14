defmodule Mix.Tasks.Gf.Gen.Schema do
  @shortdoc "Generates an GreenFairy schema module"

  @moduledoc """
  Generates an GreenFairy schema module with auto-discovery.

  ## Usage

      mix absinthe.object.gen.schema
      mix absinthe.object.gen.schema MyApp.GraphQL

  ## Arguments

  * `namespace` - (optional) The GraphQL namespace to use. If not provided,
    uses the configured or inferred namespace.

  ## Examples

      mix absinthe.object.gen.schema
      mix absinthe.object.gen.schema MyApp.GraphQL
  """

  use Mix.Task

  alias Mix.Tasks.Gf.Gen

  @impl Mix.Task
  def run(args) do
    namespace =
      case args do
        [] -> Gen.graphql_namespace()
        [ns] -> Module.concat([ns])
      end

    generate(namespace)
  end

  defp generate(namespace) do
    path = Gen.schema_path()

    if File.exists?(path) do
      Mix.shell().error("File already exists: #{path}")
      exit({:shutdown, 1})
    end

    content = build_content(namespace)
    Gen.write_file(path, content)

    Mix.shell().info("""

    Schema created at #{path}!

    Your types under #{namespace} will be auto-discovered.

    To configure DataLoader, add sources to your context:

        def context(ctx) do
          loader =
            Dataloader.new()
            |> Dataloader.add_source(MyApp.Accounts, MyApp.Accounts.data())

          Map.put(ctx, :loader, loader)
        end
    """)
  end

  defp build_content(namespace) do
    """
    defmodule #{namespace}.Schema do
      @moduledoc \"\"\"
      GraphQL Schema for the application.

      Types are auto-discovered under #{namespace}.
      \"\"\"

      use GreenFairy.Schema,
        discover: [#{namespace}]

      # Configure DataLoader context
      # def context(ctx) do
      #   loader =
      #     Dataloader.new()
      #     |> Dataloader.add_source(MyApp.Accounts, MyApp.Accounts.data())
      #
      #   Map.put(ctx, :loader, loader)
      # end

      # Optionally customize the schema pipeline
      # def pipeline(config, opts) do
      #   config
      #   |> Absinthe.Pipeline.for_document(opts)
      # end
    end
    """
    |> String.trim()
    |> format_code()
  end

  defp format_code(code) do
    case Code.format_string!(code) do
      formatted -> IO.iodata_to_binary(formatted) <> "\n"
    end
  rescue
    _ -> code <> "\n"
  end
end
