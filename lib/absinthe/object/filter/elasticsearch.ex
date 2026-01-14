defmodule Absinthe.Object.Filter.Elasticsearch do
  @moduledoc """
  Filter implementations for Elasticsearch.

  This module provides filter implementations that build Elasticsearch
  query DSL. Filters are added to a bool query structure.

  ## Query Structure

  Filters build on a bool query structure:

      %{
        "query" => %{
          "bool" => %{
            "must" => [...],
            "filter" => [...],
            "should" => [...],
            "must_not" => [...]
          }
        }
      }

  Most filters are added to the `filter` clause for better caching.

  """

  use Absinthe.Object.Filter.Impl,
    adapter: Absinthe.Object.Adapters.Elasticsearch

  alias Absinthe.Object.Filters.{Geo, Text, Basic}

  # ===========================================================================
  # Geo Filters
  # ===========================================================================

  filter_impl Geo.Near do
    def apply(_adapter, %{point: point, distance: dist, unit: unit}, field, query) do
      {lng, lat} = extract_coordinates(point)
      distance_str = format_distance(dist, unit)

      filter = %{
        "geo_distance" => %{
          "distance" => distance_str,
          to_string(field) => %{"lat" => lat, "lon" => lng}
        }
      }

      {:ok, append_filter(query, filter)}
    end

    defp extract_coordinates(%{coordinates: {lng, lat}}), do: {lng, lat}
    defp extract_coordinates(%{lng: lng, lat: lat}), do: {lng, lat}
    defp extract_coordinates(%{lon: lng, lat: lat}), do: {lng, lat}

    defp format_distance(dist, :meters), do: "#{dist}m"
    defp format_distance(dist, :kilometers), do: "#{dist}km"
    defp format_distance(dist, :miles), do: "#{dist}mi"
  end

  filter_impl Geo.WithinDistance do
    def apply(adapter, %{point: point, distance: dist, unit: unit}, field, query) do
      # Delegate to Near
      Absinthe.Object.Filter.apply(
        adapter,
        %Geo.Near{point: point, distance: dist, unit: unit},
        field,
        query
      )
    end
  end

  filter_impl Geo.WithinBounds do
    def apply(_adapter, %{bounds: bounds}, field, query) do
      filter = %{
        "geo_bounding_box" => %{
          to_string(field) => format_bounds(bounds)
        }
      }

      {:ok, append_filter(query, filter)}
    end

    defp format_bounds(%{top_left: tl, bottom_right: br}) do
      %{
        "top_left" => format_point(tl),
        "bottom_right" => format_point(br)
      }
    end

    defp format_bounds(%{coordinates: coords}) when is_list(coords) do
      # Polygon bounds - use envelope
      {min_lng, min_lat, max_lng, max_lat} = calculate_envelope(coords)

      %{
        "top_left" => %{"lat" => max_lat, "lon" => min_lng},
        "bottom_right" => %{"lat" => min_lat, "lon" => max_lng}
      }
    end

    defp format_point(%{coordinates: {lng, lat}}), do: %{"lat" => lat, "lon" => lng}
    defp format_point(%{lat: lat, lng: lng}), do: %{"lat" => lat, "lon" => lng}
    defp format_point(%{lat: lat, lon: lng}), do: %{"lat" => lat, "lon" => lng}

    defp calculate_envelope(coords) do
      coords
      |> List.flatten()
      |> Enum.reduce({nil, nil, nil, nil}, fn
        {lng, lat}, {nil, nil, nil, nil} ->
          {lng, lat, lng, lat}

        {lng, lat}, {min_lng, min_lat, max_lng, max_lat} ->
          {min(lng, min_lng), min(lat, min_lat), max(lng, max_lng), max(lat, max_lat)}
      end)
    end
  end

  # ===========================================================================
  # Text Filters
  # ===========================================================================

  filter_impl Text.Fulltext do
    def apply(_adapter, %{query: search_query, fields: fields, fuzziness: fuzz, operator: op}, _field, query) do
      must_clause = %{
        "multi_match" => %{
          "query" => search_query,
          "fields" => fields || ["*"],
          "fuzziness" => format_fuzziness(fuzz),
          "operator" => to_string(op)
        }
      }

      {:ok, append_must(query, must_clause)}
    end

    defp format_fuzziness(:auto), do: "AUTO"
    defp format_fuzziness(:none), do: 0
    defp format_fuzziness(n) when is_integer(n), do: n
  end

  filter_impl Text.Match do
    def apply(_adapter, %{query: match_query, operator: op}, field, query) do
      must_clause = %{
        "match" => %{
          to_string(field) => %{
            "query" => match_query,
            "operator" => to_string(op)
          }
        }
      }

      {:ok, append_must(query, must_clause)}
    end
  end

  filter_impl Text.Prefix do
    def apply(_adapter, %{value: prefix}, field, query) do
      filter = %{
        "prefix" => %{
          to_string(field) => prefix
        }
      }

      {:ok, append_filter(query, filter)}
    end
  end

  filter_impl Text.Phrase do
    def apply(_adapter, %{phrase: phrase, slop: slop}, field, query) do
      must_clause = %{
        "match_phrase" => %{
          to_string(field) => %{
            "query" => phrase,
            "slop" => slop
          }
        }
      }

      {:ok, append_must(query, must_clause)}
    end
  end

  # ===========================================================================
  # Basic Filters
  # ===========================================================================

  filter_impl Basic.Equals do
    def apply(_adapter, %{value: value}, field, query) do
      filter = %{"term" => %{to_string(field) => value}}
      {:ok, append_filter(query, filter)}
    end
  end

  filter_impl Basic.NotEquals do
    def apply(_adapter, %{value: value}, field, query) do
      clause = %{"term" => %{to_string(field) => value}}
      {:ok, append_must_not(query, clause)}
    end
  end

  filter_impl Basic.In do
    def apply(_adapter, %{values: values}, field, query) do
      filter = %{"terms" => %{to_string(field) => values}}
      {:ok, append_filter(query, filter)}
    end
  end

  filter_impl Basic.NotIn do
    def apply(_adapter, %{values: values}, field, query) do
      clause = %{"terms" => %{to_string(field) => values}}
      {:ok, append_must_not(query, clause)}
    end
  end

  filter_impl Basic.Range do
    def apply(_adapter, range, field, query) do
      range_params =
        %{}
        |> maybe_put("gt", range.gt)
        |> maybe_put("gte", range.gte || range.min)
        |> maybe_put("lt", range.lt)
        |> maybe_put("lte", range.lte || range.max)

      filter = %{"range" => %{to_string(field) => range_params}}
      {:ok, append_filter(query, filter)}
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  filter_impl Basic.IsNil do
    def apply(_adapter, %{is_nil: true}, field, query) do
      clause = %{"exists" => %{"field" => to_string(field)}}
      {:ok, append_must_not(query, clause)}
    end

    def apply(_adapter, %{is_nil: false}, field, query) do
      filter = %{"exists" => %{"field" => to_string(field)}}
      {:ok, append_filter(query, filter)}
    end
  end

  filter_impl Basic.Contains do
    def apply(_adapter, %{value: value}, field, query) do
      filter = %{"wildcard" => %{to_string(field) => "*#{value}*"}}
      {:ok, append_filter(query, filter)}
    end
  end

  filter_impl Basic.StartsWith do
    def apply(_adapter, %{value: value}, field, query) do
      filter = %{"prefix" => %{to_string(field) => value}}
      {:ok, append_filter(query, filter)}
    end
  end

  filter_impl Basic.EndsWith do
    def apply(_adapter, %{value: value}, field, query) do
      filter = %{"wildcard" => %{to_string(field) => "*#{value}"}}
      {:ok, append_filter(query, filter)}
    end
  end

  # ===========================================================================
  # Query Building Helpers
  # ===========================================================================

  defp append_filter(query, filter) do
    update_in(query, [Access.key("query", %{}), Access.key("bool", %{}), Access.key("filter", [])], fn
      filters when is_list(filters) -> filters ++ [filter]
      nil -> [filter]
    end)
  end

  defp append_must(query, clause) do
    update_in(query, [Access.key("query", %{}), Access.key("bool", %{}), Access.key("must", [])], fn
      clauses when is_list(clauses) -> clauses ++ [clause]
      nil -> [clause]
    end)
  end

  defp append_must_not(query, clause) do
    update_in(query, [Access.key("query", %{}), Access.key("bool", %{}), Access.key("must_not", [])], fn
      clauses when is_list(clauses) -> clauses ++ [clause]
      nil -> [clause]
    end)
  end
end
