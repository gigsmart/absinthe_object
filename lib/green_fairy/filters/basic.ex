defmodule GreenFairy.Filters.Basic do
  @moduledoc """
  Semantic filter structs for basic comparison operations.

  These filters work similarly across most adapters and represent
  common filtering operations.

  ## Supported Operations

  - `Equals` - Exact equality
  - `NotEquals` - Inequality
  - `In` - Value in list
  - `NotIn` - Value not in list
  - `Range` - Value within range (gt, gte, lt, lte)
  - `IsNil` - Null check
  - `Contains` - String/array contains
  - `StartsWith` - String prefix
  - `EndsWith` - String suffix

  """

  defmodule Equals do
    @moduledoc "Exact equality filter"
    @enforce_keys [:value]
    defstruct [:value]

    @type t :: %__MODULE__{value: any()}
  end

  defmodule NotEquals do
    @moduledoc "Inequality filter"
    @enforce_keys [:value]
    defstruct [:value]

    @type t :: %__MODULE__{value: any()}
  end

  defmodule In do
    @moduledoc "Value in list filter"
    @enforce_keys [:values]
    defstruct [:values]

    @type t :: %__MODULE__{values: [any()]}
  end

  defmodule NotIn do
    @moduledoc "Value not in list filter"
    @enforce_keys [:values]
    defstruct [:values]

    @type t :: %__MODULE__{values: [any()]}
  end

  defmodule Range do
    @moduledoc """
    Range filter with optional bounds.

    ## Fields

    - `:gt` - Greater than (exclusive)
    - `:gte` - Greater than or equal (inclusive)
    - `:lt` - Less than (exclusive)
    - `:lte` - Less than or equal (inclusive)
    - `:min` - Alias for `:gte`
    - `:max` - Alias for `:lte`

    """
    defstruct [:gt, :gte, :lt, :lte, :min, :max]

    @type t :: %__MODULE__{
            gt: any(),
            gte: any(),
            lt: any(),
            lte: any(),
            min: any(),
            max: any()
          }
  end

  defmodule IsNil do
    @moduledoc """
    Null check filter.

    ## Fields

    - `:is_nil` - `true` to match nulls, `false` to match non-nulls

    """
    @enforce_keys [:is_nil]
    defstruct [:is_nil]

    @type t :: %__MODULE__{is_nil: boolean()}
  end

  defmodule Contains do
    @moduledoc """
    Contains filter for strings or arrays.

    ## Fields

    - `:value` - The value to search for
    - `:case_sensitive` - Whether match is case-sensitive (default: false)

    """
    @enforce_keys [:value]
    defstruct [:value, case_sensitive: false]

    @type t :: %__MODULE__{
            value: any(),
            case_sensitive: boolean()
          }
  end

  defmodule StartsWith do
    @moduledoc """
    String prefix filter.

    ## Fields

    - `:value` - The prefix to match
    - `:case_sensitive` - Whether match is case-sensitive (default: false)

    """
    @enforce_keys [:value]
    defstruct [:value, case_sensitive: false]

    @type t :: %__MODULE__{
            value: String.t(),
            case_sensitive: boolean()
          }
  end

  defmodule EndsWith do
    @moduledoc """
    String suffix filter.

    ## Fields

    - `:value` - The suffix to match
    - `:case_sensitive` - Whether match is case-sensitive (default: false)

    """
    @enforce_keys [:value]
    defstruct [:value, case_sensitive: false]

    @type t :: %__MODULE__{
            value: String.t(),
            case_sensitive: boolean()
          }
  end
end
