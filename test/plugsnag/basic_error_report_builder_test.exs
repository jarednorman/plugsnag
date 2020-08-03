defmodule Plugsnag.BasicErrorReportBuilderTest do
  use ExUnit.Case
  use Plug.Test

  alias Plugsnag.BasicErrorReportBuilder
  alias Plugsnag.ErrorReport

  test "build_error_report/3 adds the appropriate fields to the error report" do
    conn = conn(:get, "/?hello=computer")

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("x-user-id", "abc123")
      |> put_resp_header("x-request-id", "42")

    error_report = BasicErrorReportBuilder.build_error_report(
      %ErrorReport{}, conn
    )


    assert error_report == %ErrorReport{
      metadata: %{
        request: %{
          request_path: "/",
          method: "GET",
          url: "http://#{conn.host}/?hello=computer",
          port: 80,
          scheme: :http,
          request_id: "42",
          query_string: "hello=computer",
          params: %{"hello" => "computer"},
          headers: %{
            "accept" => "application/json",
            "x-user-id" => "abc123"
          },
          client_ip: "127.0.0.1"
        }
      }
    }
  end

  test "filters the params defined in config" do
    Application.put_env(:plugsnag, :filter, params: ~w(password receipt))

    conn = conn(:post, "/", %{"password" => "secret", "user" => "foo", "receipt" => "DATA"})

    error_report = BasicErrorReportBuilder.build_error_report(%ErrorReport{}, conn)

    assert %ErrorReport{
      metadata: %{
        request: %{
          params: %{"password" => "[FILTERED]", "user" => "foo", "receipt" => "[FILTERED]"}
        }
      }
    } = error_report
  end

  test "filters the headers defined in config" do
    Application.put_env(:plugsnag, :filter, headers: ~w(Authorization))

    conn = conn(:post, "/", "") |> put_req_header("authorization", "Bearer SOMESECRETTOKEN")

    error_report = BasicErrorReportBuilder.build_error_report(%ErrorReport{}, conn)

    assert %ErrorReport{
      metadata: %{
        request: %{
          headers: %{"authorization" => "[FILTERED]"}
        }
      }
    } = error_report
  end

end
