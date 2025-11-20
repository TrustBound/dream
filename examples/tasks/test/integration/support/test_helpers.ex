defmodule TestHelpers do
  @moduledoc """
  Shared test helper functions used across step definitions.
  """

  @doc """
  Parses a Cucumber datatable into a map of key-value pairs.
  """
  def parse_datatable(datatable) do
    rows = Map.get(datatable, :raw, [])

    Enum.reduce(rows, %{}, fn row, acc ->
      case row do
        [key, value] -> Map.put(acc, key, value)
        _ -> acc
      end
    end)
  end

  @doc """
  Parses a Cucumber datatable into form-encoded data for HTTP requests.
  """
  def datatable_to_form_data(datatable) do
    rows = Map.get(datatable, :raw, [])

    Enum.map(rows, fn [key, value] ->
      "#{URI.encode_www_form(key)}=#{URI.encode_www_form(value)}"
    end)
    |> Enum.join("&")
  end
end
