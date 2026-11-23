//// Tests for dream/servers/mist/request module.
////
//// convert_metadata() takes a mist request. The tests build one with a
//// test connection from fixtures/mist_connection, so they need no server.

import dream/http/request.{
  Connect, Delete, Head, Options, Other, Patch, Put, Trace,
}
import dream/servers/mist/request as mist_request
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/mist_connection
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import mist

pub fn tests() -> TestSuite {
  describe("request", [
    group("convert_metadata", [
      it("converts PUT, DELETE, PATCH, OPTIONS and HEAD", fn() {
        // Arrange
        let methods = [
          http.Put,
          http.Delete,
          http.Patch,
          http.Options,
          http.Head,
        ]

        // Act
        let converted = list.map(methods, converted_method)

        // Assert
        converted
        |> should()
        |> be_equal([Put, Delete, Patch, Options, Head])
        |> or_fail_with("Each method should keep its meaning")
      }),
      it("converts CONNECT and TRACE to themselves", fn() {
        // Arrange
        let methods = [http.Connect, http.Trace]

        // Act
        let converted = list.map(methods, converted_method)

        // Assert
        converted
        |> should()
        |> be_equal([Connect, Trace])
        |> or_fail_with("CONNECT and TRACE should not become GET")
      }),
      it("converts any other method to Other with the name as sent", fn() {
        // Arrange
        let methods = [http.Other("PURGE"), http.Other("purge")]

        // Act
        let converted = list.map(methods, converted_method)

        // Assert
        converted
        |> should()
        |> be_equal([Other("PURGE"), Other("purge")])
        |> or_fail_with("Another method should keep its exact name")
      }),
      it("has no remote address when the socket is closed", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request = mist_connection.request(connection, http.Get, "/", [])

        // Act
        let #(converted, _request_id) = mist_request.convert_metadata(request)

        // Assert
        converted.remote_address
        |> should()
        |> be_equal(option.None)
        |> or_fail_with("A closed socket has no peer address")
      }),
      it("reports a client on the IPv6 loopback as ::1", fn() {
        // Arrange
        let connection = mist_connection.ipv6_connection()

        // Act
        let remote_address = result.map(connection, connected_remote_address)

        // Assert
        remote_address
        |> should()
        |> be_equal(Ok(option.Some("::1")))
        |> or_fail_with("The IPv6 loopback address is ::1")
      }),
      it("reports an IPv4 client of an IPv6 socket as its IPv4 address", fn() {
        // Arrange
        let connection = mist_connection.ipv4_mapped_connection()

        // Act
        let remote_address = result.map(connection, connected_remote_address)

        // Assert
        remote_address
        |> should()
        |> be_equal(Ok(option.Some("127.0.0.1")))
        |> or_fail_with("The socket layer gives a mapped client as IPv4")
      }),
    ]),
    group("format_ip_address", [
      it("writes an IPv4 address in dotted decimal", fn() {
        // Arrange
        let address = mist.IpV4(192, 0, 2, 33)

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("192.0.2.33")
        |> or_fail_with("IPv4 is four decimal numbers with dots")
      }),
      it("compresses the run of zero groups in a client address", fn() {
        // Arrange
        let address = mist.IpV6(0x2601, 0x282, 0xa00, 0xb38, 0, 0, 0, 0x421d)

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("2601:282:a00:b38::421d")
        |> or_fail_with("The zero groups should become ::")
      }),
      it("writes an address without zero groups in full, in lower case", fn() {
        // Arrange
        let address =
          mist.IpV6(
            0x2001,
            0xDB8,
            0x85A3,
            0x1234,
            0x5678,
            0x8A2E,
            0x370,
            0x7334,
          )

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("2001:db8:85a3:1234:5678:8a2e:370:7334")
        |> or_fail_with("Each group is lower case with no leading zeros")
      }),
      it("does not compress a single zero group", fn() {
        // Arrange
        let address = mist.IpV6(0x2001, 0xdb8, 0, 1, 1, 1, 1, 1)

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("2001:db8:0:1:1:1:1:1")
        |> or_fail_with("RFC 5952 4.2.2: one zero group stays 0")
      }),
      it("compresses the longest run of zero groups", fn() {
        // Arrange
        let address = mist.IpV6(0x2001, 0, 0, 1, 0, 0, 0, 1)

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("2001:0:0:1::1")
        |> or_fail_with("RFC 5952 4.2.3: the longest run becomes ::")
      }),
      it("compresses the first of two equal runs of zero groups", fn() {
        // Arrange
        let address = mist.IpV6(0x2001, 0xdb8, 0, 0, 1, 0, 0, 1)

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("2001:db8::1:0:0:1")
        |> or_fail_with("RFC 5952 4.2.3: the first of equal runs becomes ::")
      }),
      it("writes the unspecified address as ::", fn() {
        // Arrange
        let address = mist.IpV6(0, 0, 0, 0, 0, 0, 0, 0)

        // Act
        let text = mist_request.format_ip_address(address)

        // Assert
        text
        |> should()
        |> be_equal("::")
        |> or_fail_with("All zero groups become ::")
      }),
    ]),
  ])
}

fn converted_method(method: http.Method) -> request.Method {
  let connection = mist_connection.closed_connection(<<>>)
  let request = mist_connection.request(connection, method, "/", [])
  let #(converted, _request_id) = mist_request.convert_metadata(request)
  converted.method
}

fn connected_remote_address(
  connection: #(mist.Connection, mist_connection.Socket),
) -> option.Option(String) {
  let #(server_end, client_end) = connection
  let request = mist_connection.request(server_end, http.Get, "/", [])
  let #(converted, _request_id) = mist_request.convert_metadata(request)
  mist_connection.close_socket(client_end)
  converted.remote_address
}
