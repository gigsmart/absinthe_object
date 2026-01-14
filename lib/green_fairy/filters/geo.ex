defmodule GreenFairy.Filters.Geo do
  @moduledoc """
  Semantic filter structs for geographic operations.

  These structs represent the *intent* of a geo filter without any
  adapter-specific implementation. The `GreenFairy.Filter` protocol
  dispatches to the appropriate adapter to apply the actual filter.

  ## Supported Operations

  - `Near` - Find records within a distance of a point
  - `WithinDistance` - Alias for Near with explicit distance
  - `WithinBounds` - Find records within a bounding box
  - `Intersects` - Find records that intersect a geometry

  ## Example

      # In a scalar definition
      filter :near, fn point, opts ->
        %GreenFairy.Filters.Geo.Near{
          point: point,
          distance: opts[:distance] || 1000,
          unit: :meters
        }
      end

  """

  defmodule Near do
    @moduledoc """
    Filter for finding records within a distance of a point.

    ## Fields

    - `:point` - The center point (typically a `Geo.Point` struct)
    - `:distance` - The maximum distance
    - `:unit` - Distance unit (`:meters`, `:kilometers`, `:miles`)

    """
    @enforce_keys [:point]
    defstruct [:point, :distance, unit: :meters]

    @type t :: %__MODULE__{
            point: Geo.Point.t() | map(),
            distance: number() | nil,
            unit: :meters | :kilometers | :miles
          }
  end

  defmodule WithinDistance do
    @moduledoc """
    Filter for finding records within an explicit distance of a point.
    Similar to `Near` but requires distance to be specified.
    """
    @enforce_keys [:point, :distance]
    defstruct [:point, :distance, unit: :meters]

    @type t :: %__MODULE__{
            point: Geo.Point.t() | map(),
            distance: number(),
            unit: :meters | :kilometers | :miles
          }
  end

  defmodule WithinBounds do
    @moduledoc """
    Filter for finding records within a bounding box or polygon.

    ## Fields

    - `:bounds` - The bounding geometry (polygon, box, etc.)
    - `:srid` - Spatial reference ID (default: 4326 for WGS84)

    """
    @enforce_keys [:bounds]
    defstruct [:bounds, srid: 4326]

    @type t :: %__MODULE__{
            bounds: Geo.Polygon.t() | map(),
            srid: integer()
          }
  end

  defmodule Intersects do
    @moduledoc """
    Filter for finding records that intersect a geometry.

    ## Fields

    - `:geometry` - The geometry to test intersection against

    """
    @enforce_keys [:geometry]
    defstruct [:geometry]

    @type t :: %__MODULE__{
            geometry: Geo.geometry() | map()
          }
  end
end
