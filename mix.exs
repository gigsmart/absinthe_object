defmodule GreenFairy.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/gigsmart/green_fairy"

  def project do
    [
      app: :green_fairy,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "GreenFairy",
      description: "A cleaner DSL for GraphQL schema definitions built on Absinthe",
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      test_coverage_options: [
        threshold: 75,
        summary: [threshold: 75],
        ignore_modules: [
          # Mix tasks - tested via command line, not unit tests
          Mix.Tasks.GreenFairy.Gen,
          Mix.Tasks.GreenFairy.Gen.Type,
          Mix.Tasks.GreenFairy.Gen.Enum,
          Mix.Tasks.GreenFairy.Gen.Input,
          Mix.Tasks.GreenFairy.Gen.Interface,
          Mix.Tasks.GreenFairy.Gen.Schema,
          # Deferred definition structs - just data structures
          GreenFairy.Deferred.Definition.Arg,
          GreenFairy.Deferred.Definition.Connection,
          GreenFairy.Deferred.Definition.Enum,
          GreenFairy.Deferred.Definition.Field,
          GreenFairy.Deferred.Definition.Input,
          GreenFairy.Deferred.Definition.Interface,
          GreenFairy.Deferred.Definition.Object,
          GreenFairy.Deferred.Definition.Scalar,
          GreenFairy.Deferred.Definition.Union,
          GreenFairy.Deferred.Schema,
          # Macro-only modules
          GreenFairy.Extensions.Auth.Macros,
          # Relay macros - primarily compile-time
          GreenFairy.Relay.Node,
          GreenFairy.Relay.Mutation
        ]
      ],
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:dataloader, "~> 2.0"},
      {:ecto, "~> 3.10"},
      {:geo, "~> 3.6", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["GigSmart"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/logo.svg",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/types.md",
        "guides/authorization.md",
        "guides/relationships.md",
        "guides/cql.md",
        "guides/connections.md",
        "guides/operations.md"
      ],
      assets: %{"assets" => "assets"},
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Core DSL": [
          GreenFairy,
          GreenFairy.Type,
          GreenFairy.Interface,
          GreenFairy.Input,
          GreenFairy.Enum,
          GreenFairy.Union,
          GreenFairy.Scalar
        ],
        Operations: [
          GreenFairy.Query,
          GreenFairy.Mutation,
          GreenFairy.Subscription
        ],
        "Schema & Discovery": [
          GreenFairy.Schema,
          GreenFairy.Discovery
        ],
        "Field Helpers": [
          GreenFairy.Field.Connection,
          GreenFairy.Field.Dataloader,
          GreenFairy.Field.Loader,
          GreenFairy.Field.Middleware
        ],
        Extensions: [
          GreenFairy.Extensions.CQL,
          GreenFairy.Extensions.Auth
        ],
        Authorization: [
          GreenFairy.AuthorizedObject,
          GreenFairy.AuthorizationInfo
        ],
        Adapters: [
          GreenFairy.Adapter,
          GreenFairy.Adapters.Ecto
        ],
        "Built-ins": [
          GreenFairy.BuiltIns.Node,
          GreenFairy.BuiltIns.PageInfo,
          GreenFairy.BuiltIns.Timestampable
        ],
        Utilities: [
          GreenFairy.Naming
        ]
      ]
    ]
  end
end
