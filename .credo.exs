%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/"
        ]
      },
      plugins: [],
      requires: [],
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          #
          ## Consistency Checks
          #
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          #
          ## Design Checks
          #
          # Disabled for now - we intentionally use fully qualified module names
          # in quoted expressions to avoid polluting the caller's namespace
          # {Credo.Check.Design.AliasUsage,
          #  [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Design.TagTODO, [exit_status: 0]},

          #
          ## Readability Checks
          #
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, [files: %{excluded: ["test/"]}]},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          #
          ## Refactoring Opportunities
          #
          {Credo.Check.Refactor.Apply,
           [
             files: %{
               excluded: [
                 # Dynamic function calls in code generation
                 "lib/green_fairy/type.ex",
                 "lib/green_fairy/cql.ex",
                 "lib/green_fairy/cql/operator_input.ex"
               ]
             }
           ]},
          {Credo.Check.Refactor.CondStatements,
           [
             files: %{
               excluded: [
                 # CQL filter input has simple cond used for clarity
                 "lib/green_fairy/extensions/cql/filter_input.ex"
               ]
             }
           ]},
          # Allow slightly higher complexity for compile-time code generation with macros
          {Credo.Check.Refactor.CyclomaticComplexity,
           [
             max_complexity: 15,
             files: %{
               excluded: [
                 # CQL code generation is inherently complex
                 "lib/green_fairy/extensions/cql.ex",
                 "lib/green_fairy/cql.ex",
                 "lib/green_fairy/cql/scalars/string/",
                 "lib/green_fairy/field/connection.ex",
                 "lib/green_fairy/type.ex",
                 "lib/green_fairy/adapters/ecto.ex"
               ]
             }
           ]},
          {Credo.Check.Refactor.FunctionArity,
           [
             files: %{
               excluded: [
                 # CQL code generation passes many params for clarity
                 "lib/green_fairy/extensions/cql.ex",
                 "lib/green_fairy/cql.ex"
               ]
             }
           ]},
          {Credo.Check.Refactor.LongQuoteBlocks,
           [
             files: %{
               excluded: [
                 # CQL code generation uses long quote blocks for clarity
                 "lib/green_fairy/cql.ex"
               ]
             }
           ]},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting,
           [
             files: %{
               excluded: [
                 # Relay node macro has deep nesting for query resolution
                 "lib/green_fairy/relay/node.ex",
                 # Code generation modules have nested quote blocks
                 "lib/green_fairy/field/connection.ex",
                 "lib/green_fairy/field/connection_aggregate.ex",
                 "lib/green_fairy/field/association.ex",
                 "lib/green_fairy/query.ex",
                 "lib/green_fairy/schema.ex",
                 "lib/green_fairy/type.ex",
                 "lib/green_fairy/cql.ex",
                 "lib/green_fairy/cql/scalar_mapper.ex",
                 "lib/green_fairy/cql/adapters/elasticsearch.ex",
                 "lib/green_fairy/adapters/ecto.ex",
                 "test/support/"
               ]
             }
           ]},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          #
          ## Warnings
          #
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},
          # Re-enabled with exclusions for controlled atom creation in compile-time code
          {Credo.Check.Warning.UnsafeToAtom,
           [
             files: %{
               excluded: [
                 # These modules create atoms from known schema fields, not user input
                 "lib/green_fairy/extensions/cql.ex",
                 "lib/green_fairy/extensions/cql/filter_input.ex",
                 "lib/green_fairy/naming.ex",
                 "lib/green_fairy/authorization_info.ex",
                 # Compile-time code generation for types and connections
                 "lib/green_fairy/field/connection.ex",
                 "lib/green_fairy/deferred/schema.ex",
                 "lib/green_fairy/deferred/compiler.ex",
                 "lib/green_fairy/adapter.ex",
                 "lib/green_fairy/filter/impl.ex",
                 "lib/green_fairy/type.ex",
                 # Relay modules create atoms from type names at compile time
                 "lib/green_fairy/relay/node.ex",
                 "lib/green_fairy/relay/mutation.ex",
                 # Mix tasks create atoms from module names at compile time
                 "lib/mix/tasks/",
                 # Test files - atom creation is controlled
                 "test/"
               ]
             }
           ]}
        ],
        disabled: [
          #
          ## Consistency Checks - disabled
          #
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},

          #
          ## Readability Checks - disabled
          #
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},

          #
          ## Refactoring Opportunities - disabled
          #
          {Credo.Check.Refactor.ABCSize, []},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.VariableRebinding, []},

          #
          ## Warnings - disabled
          #
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MixEnv, []}
        ]
      }
    }
  ]
}
