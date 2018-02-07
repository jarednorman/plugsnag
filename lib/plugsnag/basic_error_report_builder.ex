defmodule Plugsnag.BasicErrorReportBuilder do
  @moduledoc """
  Error report builder that adds basic context to the ErrorReport.
  """
  @default_filter_parameters params: ~w(password)
  @behaviour Plugsnag.ErrorReportBuilder

  def build_error_report(error_report, conn) do
    %{error_report | metadata: build_metadata(conn)}
  end

  defp build_metadata(conn) do
    conn =
      conn
      |> Plug.Conn.fetch_query_params

    %{
      request: %{
        request_path: conn.request_path,
        method: conn.method,
        port: conn.port,
        scheme: conn.scheme,
        query_string: conn.query_string,
        params: filter(:params, conn.params),
        req_headers: collect_headers(conn, :req),
        resp_headers: collect_headers(conn, :resp),
        client_ip: format_ip(conn.remote_ip)
      }
    }
  end

  defp collect_headers(conn, type) do
    headers = Enum.reduce(Map.get(conn, :"#{type}_headers"), %{}, fn({header, _}, acc) ->
      Map.put(acc, header, apply(Plug.Conn, :"get_#{type}_header", [conn, header]) |> List.first)
    end)
    filter(:headers, headers)
  end

  defp filters_for(:headers) do
    do_filters_for(:headers) |> Enum.map(&String.downcase/1)
  end

  defp filters_for(field), do: do_filters_for(field)

  defp do_filters_for(field) do
    Application.get_env(:plugsnag, :filter, @default_filter_parameters)
    |> Keyword.get(field, [])
  end

  defp filter(field, data), do: do_filter(data, filters_for(field))

  defp do_filter(%{__struct__: mod} = struct, _params_to_filter) when is_atom(mod), do: struct
  defp do_filter(%{} = map, params_to_filter) do
    Enum.into map, %{}, fn {k, v} ->
      if is_binary(k) && String.contains?(k, params_to_filter) do
        {k, "[FILTERED]"}
      else
        {k, do_filter(v, params_to_filter)}
      end
    end
  end
  defp do_filter([_|_] = list, params_to_filter), do: Enum.map(list, &do_filter(&1, params_to_filter))
  defp do_filter(other, _params_to_filter), do: other

  defp format_ip(ip) do
    ip
    |> Tuple.to_list
    |> Enum.join(".")
  end
end
