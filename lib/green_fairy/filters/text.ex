defmodule GreenFairy.Filters.Text do
  @moduledoc """
  Semantic filter structs for text search operations.

  These structs represent full-text search intent without adapter-specific
  implementation details.

  ## Supported Operations

  - `Fulltext` - Full-text search with optional fuzziness
  - `Match` - Simple text matching
  - `Prefix` - Prefix/autocomplete matching
  - `Phrase` - Exact phrase matching

  ## Example

      filter :search, fn query, opts ->
        %GreenFairy.Filters.Text.Fulltext{
          query: query,
          fields: opts[:fields],
          fuzziness: opts[:fuzziness] || :auto
        }
      end

  """

  defmodule Fulltext do
    @moduledoc """
    Full-text search filter with optional fuzziness and field targeting.

    ## Fields

    - `:query` - The search query string
    - `:fields` - List of fields to search (nil = all fields)
    - `:fuzziness` - Fuzziness level (`:auto`, `:none`, or integer 0-2)
    - `:operator` - How to combine terms (`:and` or `:or`)

    """
    @enforce_keys [:query]
    defstruct [:query, :fields, fuzziness: :auto, operator: :or]

    @type t :: %__MODULE__{
            query: String.t(),
            fields: [atom()] | nil,
            fuzziness: :auto | :none | 0..2,
            operator: :and | :or
          }
  end

  defmodule Match do
    @moduledoc """
    Simple text matching filter.

    ## Fields

    - `:query` - The text to match
    - `:operator` - How to combine terms (`:and` or `:or`)

    """
    @enforce_keys [:query]
    defstruct [:query, operator: :or]

    @type t :: %__MODULE__{
            query: String.t(),
            operator: :and | :or
          }
  end

  defmodule Prefix do
    @moduledoc """
    Prefix matching filter for autocomplete-style queries.

    ## Fields

    - `:value` - The prefix to match

    """
    @enforce_keys [:value]
    defstruct [:value]

    @type t :: %__MODULE__{
            value: String.t()
          }
  end

  defmodule Phrase do
    @moduledoc """
    Exact phrase matching filter.

    ## Fields

    - `:phrase` - The exact phrase to match
    - `:slop` - Number of positions tokens can be moved (default: 0)

    """
    @enforce_keys [:phrase]
    defstruct [:phrase, slop: 0]

    @type t :: %__MODULE__{
            phrase: String.t(),
            slop: non_neg_integer()
          }
  end
end
