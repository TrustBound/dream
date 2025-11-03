import dream/core/http/statuses
import gleeunit/should

// Test conversion functions
pub fn convert_informational_to_status_wraps_informational_status_test() {
  // Arrange
  let informational = statuses.continue()

  // Act
  let status = statuses.convert_informational_to_status(informational)

  // Assert
  case status {
    statuses.InformationalStatus(_) -> Nil
    _ -> should.fail()
  }
}

pub fn convert_success_to_status_wraps_success_status_test() {
  // Arrange
  let success = statuses.ok()

  // Act
  let status = statuses.convert_success_to_status(success)

  // Assert
  case status {
    statuses.SuccessStatus(_) -> Nil
    _ -> should.fail()
  }
}

pub fn convert_redirection_to_status_wraps_redirection_status_test() {
  // Arrange
  let redirection = statuses.moved_permanently()

  // Act
  let status = statuses.convert_redirection_to_status(redirection)

  // Assert
  case status {
    statuses.RedirectionStatus(_) -> Nil
    _ -> should.fail()
  }
}

pub fn convert_client_error_to_status_wraps_client_error_status_test() {
  // Arrange
  let client_error = statuses.not_found()

  // Act
  let status = statuses.convert_client_error_to_status(client_error)

  // Assert
  case status {
    statuses.ClientErrorStatus(_) -> Nil
    _ -> should.fail()
  }
}

pub fn convert_server_error_to_status_wraps_server_error_status_test() {
  // Arrange
  let server_error = statuses.internal_server_error()

  // Act
  let status = statuses.convert_server_error_to_status(server_error)

  // Assert
  case status {
    statuses.ServerErrorStatus(_) -> Nil
    _ -> should.fail()
  }
}

// Test informational status codes
pub fn continue_returns_status_with_code_100_test() {
  // Arrange & Act
  let status = statuses.continue()

  // Assert
  case status {
    statuses.ContinueStatus(code, message, _) -> {
      code |> should.equal(100)
      message |> should.equal("Continue")
    }
    _ -> should.fail()
  }
}

pub fn switching_protocols_returns_status_with_code_101_test() {
  // Arrange & Act
  let status = statuses.switching_protocols()

  // Assert
  case status {
    statuses.SwitchingProtocolsStatus(code, message, _) -> {
      code |> should.equal(101)
      message |> should.equal("Switching Protocols")
    }
    _ -> should.fail()
  }
}

pub fn processing_returns_status_with_code_102_test() {
  // Arrange & Act
  let status = statuses.processing()

  // Assert
  case status {
    statuses.ProcessingStatus(code, message, _) -> {
      code |> should.equal(102)
      message |> should.equal("Processing")
    }
    _ -> should.fail()
  }
}

pub fn early_hints_returns_status_with_code_103_test() {
  // Arrange & Act
  let status = statuses.early_hints()

  // Assert
  case status {
    statuses.EarlyHintsStatus(code, message, _) -> {
      code |> should.equal(103)
      message |> should.equal("Early Hints")
    }
    _ -> should.fail()
  }
}

// Test success status codes
pub fn ok_returns_status_with_code_200_test() {
  // Arrange & Act
  let status = statuses.ok()

  // Assert
  case status {
    statuses.OkStatus(code, message, _) -> {
      code |> should.equal(200)
      message |> should.equal("OK")
    }
    _ -> should.fail()
  }
}

pub fn created_returns_status_with_code_201_test() {
  // Arrange & Act
  let status = statuses.created()

  // Assert
  case status {
    statuses.CreatedStatus(code, message, _) -> {
      code |> should.equal(201)
      message |> should.equal("Created")
    }
    _ -> should.fail()
  }
}

pub fn accepted_returns_status_with_code_202_test() {
  // Arrange & Act
  let status = statuses.accepted()

  // Assert
  case status {
    statuses.AcceptedStatus(code, message, _) -> {
      code |> should.equal(202)
      message |> should.equal("Accepted")
    }
    _ -> should.fail()
  }
}

pub fn non_authoritative_information_returns_status_with_code_203_test() {
  // Arrange & Act
  let status = statuses.non_authoritative_information()

  // Assert
  case status {
    statuses.NonAuthoritativeInformationStatus(code, message, _) -> {
      code |> should.equal(203)
      message |> should.equal("Non-Authoritative Information")
    }
    _ -> should.fail()
  }
}

pub fn no_content_returns_status_with_code_204_test() {
  // Arrange & Act
  let status = statuses.no_content()

  // Assert
  case status {
    statuses.NoContentStatus(code, message, _) -> {
      code |> should.equal(204)
      message |> should.equal("No Content")
    }
    _ -> should.fail()
  }
}

pub fn reset_content_returns_status_with_code_205_test() {
  // Arrange & Act
  let status = statuses.reset_content()

  // Assert
  case status {
    statuses.ResetContentStatus(code, message, _) -> {
      code |> should.equal(205)
      message |> should.equal("Reset Content")
    }
    _ -> should.fail()
  }
}

pub fn partial_content_returns_status_with_code_206_test() {
  // Arrange & Act
  let status = statuses.partial_content()

  // Assert
  case status {
    statuses.PartialContentStatus(code, message, _) -> {
      code |> should.equal(206)
      message |> should.equal("Partial Content")
    }
    _ -> should.fail()
  }
}

pub fn multi_status_returns_status_with_code_207_test() {
  // Arrange & Act
  let status = statuses.multi_status()

  // Assert
  case status {
    statuses.MultiStatusStatus(code, message, _) -> {
      code |> should.equal(207)
      message |> should.equal("Multi-Status")
    }
    _ -> should.fail()
  }
}

pub fn already_reported_returns_status_with_code_208_test() {
  // Arrange & Act
  let status = statuses.already_reported()

  // Assert
  case status {
    statuses.AlreadyReportedStatus(code, message, _) -> {
      code |> should.equal(208)
      message |> should.equal("Already Reported")
    }
    _ -> should.fail()
  }
}

pub fn im_used_returns_status_with_code_226_test() {
  // Arrange & Act
  let status = statuses.im_used()

  // Assert
  case status {
    statuses.ImUsedStatus(code, message, _) -> {
      code |> should.equal(226)
      message |> should.equal("IM Used")
    }
    _ -> should.fail()
  }
}

// Test redirection status codes
pub fn multiple_choices_returns_status_with_code_300_test() {
  // Arrange & Act
  let status = statuses.multiple_choices()

  // Assert
  case status {
    statuses.MultipleChoicesStatus(code, message, _) -> {
      code |> should.equal(300)
      message |> should.equal("Multiple Choices")
    }
    _ -> should.fail()
  }
}

pub fn moved_permanently_returns_status_with_code_301_test() {
  // Arrange & Act
  let status = statuses.moved_permanently()

  // Assert
  case status {
    statuses.MovedPermanentlyStatus(code, message, _) -> {
      code |> should.equal(301)
      message |> should.equal("Moved Permanently")
    }
    _ -> should.fail()
  }
}

pub fn found_returns_status_with_code_302_test() {
  // Arrange & Act
  let status = statuses.found()

  // Assert
  case status {
    statuses.FoundStatus(code, message, _) -> {
      code |> should.equal(302)
      message |> should.equal("Found")
    }
    _ -> should.fail()
  }
}

pub fn see_other_returns_status_with_code_303_test() {
  // Arrange & Act
  let status = statuses.see_other()

  // Assert
  case status {
    statuses.SeeOtherStatus(code, message, _) -> {
      code |> should.equal(303)
      message |> should.equal("See Other")
    }
    _ -> should.fail()
  }
}

pub fn not_modified_returns_status_with_code_304_test() {
  // Arrange & Act
  let status = statuses.not_modified()

  // Assert
  case status {
    statuses.NotModifiedStatus(code, message, _) -> {
      code |> should.equal(304)
      message |> should.equal("Not Modified")
    }
    _ -> should.fail()
  }
}

pub fn use_proxy_returns_status_with_code_305_test() {
  // Arrange & Act
  let status = statuses.use_proxy()

  // Assert
  case status {
    statuses.UseProxyStatus(code, message, _) -> {
      code |> should.equal(305)
      message |> should.equal("Use Proxy")
    }
    _ -> should.fail()
  }
}

pub fn temporary_redirect_returns_status_with_code_307_test() {
  // Arrange & Act
  let status = statuses.temporary_redirect()

  // Assert
  case status {
    statuses.TemporaryRedirectStatus(code, message, _) -> {
      code |> should.equal(307)
      message |> should.equal("Temporary Redirect")
    }
    _ -> should.fail()
  }
}

pub fn permanent_redirect_returns_status_with_code_308_test() {
  // Arrange & Act
  let status = statuses.permanent_redirect()

  // Assert
  case status {
    statuses.PermanentRedirectStatus(code, message, _) -> {
      code |> should.equal(308)
      message |> should.equal("Permanent Redirect")
    }
    _ -> should.fail()
  }
}

// Test client error status codes
pub fn bad_request_returns_status_with_code_400_test() {
  // Arrange & Act
  let status = statuses.bad_request()

  // Assert
  case status {
    statuses.BadRequestStatus(code, message, _) -> {
      code |> should.equal(400)
      message |> should.equal("Bad Request")
    }
    _ -> should.fail()
  }
}

pub fn unauthorized_returns_status_with_code_401_test() {
  // Arrange & Act
  let status = statuses.unauthorized()

  // Assert
  case status {
    statuses.UnauthorizedStatus(code, message, _) -> {
      code |> should.equal(401)
      message |> should.equal("Unauthorized")
    }
    _ -> should.fail()
  }
}

pub fn payment_required_returns_status_with_code_402_test() {
  // Arrange & Act
  let status = statuses.payment_required()

  // Assert
  case status {
    statuses.PaymentRequiredStatus(code, message, _) -> {
      code |> should.equal(402)
      message |> should.equal("Payment Required")
    }
    _ -> should.fail()
  }
}

pub fn forbidden_returns_status_with_code_403_test() {
  // Arrange & Act
  let status = statuses.forbidden()

  // Assert
  case status {
    statuses.ForbiddenStatus(code, message, _) -> {
      code |> should.equal(403)
      message |> should.equal("Forbidden")
    }
    _ -> should.fail()
  }
}

pub fn not_found_returns_status_with_code_404_test() {
  // Arrange & Act
  let status = statuses.not_found()

  // Assert
  case status {
    statuses.NotFoundStatus(code, message, _) -> {
      code |> should.equal(404)
      message |> should.equal("Not Found")
    }
    _ -> should.fail()
  }
}

pub fn method_not_allowed_returns_status_with_code_405_test() {
  // Arrange & Act
  let status = statuses.method_not_allowed()

  // Assert
  case status {
    statuses.MethodNotAllowedStatus(code, message, _) -> {
      code |> should.equal(405)
      message |> should.equal("Method Not Allowed")
    }
    _ -> should.fail()
  }
}

pub fn not_acceptable_returns_status_with_code_406_test() {
  // Arrange & Act
  let status = statuses.not_acceptable()

  // Assert
  case status {
    statuses.NotAcceptableStatus(code, message, _) -> {
      code |> should.equal(406)
      message |> should.equal("Not Acceptable")
    }
    _ -> should.fail()
  }
}

pub fn proxy_authentication_required_returns_status_with_code_407_test() {
  // Arrange & Act
  let status = statuses.proxy_authentication_required()

  // Assert
  case status {
    statuses.ProxyAuthenticationRequiredStatus(code, message, _) -> {
      code |> should.equal(407)
      message |> should.equal("Proxy Authentication Required")
    }
    _ -> should.fail()
  }
}

pub fn request_timeout_returns_status_with_code_408_test() {
  // Arrange & Act
  let status = statuses.request_timeout()

  // Assert
  case status {
    statuses.RequestTimeoutStatus(code, message, _) -> {
      code |> should.equal(408)
      message |> should.equal("Request Timeout")
    }
    _ -> should.fail()
  }
}

pub fn conflict_returns_status_with_code_409_test() {
  // Arrange & Act
  let status = statuses.conflict()

  // Assert
  case status {
    statuses.ConflictStatus(code, message, _) -> {
      code |> should.equal(409)
      message |> should.equal("Conflict")
    }
    _ -> should.fail()
  }
}

pub fn gone_returns_status_with_code_410_test() {
  // Arrange & Act
  let status = statuses.gone()

  // Assert
  case status {
    statuses.GoneStatus(code, message, _) -> {
      code |> should.equal(410)
      message |> should.equal("Gone")
    }
    _ -> should.fail()
  }
}

pub fn length_required_returns_status_with_code_411_test() {
  // Arrange & Act
  let status = statuses.length_required()

  // Assert
  case status {
    statuses.LengthRequiredStatus(code, message, _) -> {
      code |> should.equal(411)
      message |> should.equal("Length Required")
    }
    _ -> should.fail()
  }
}

pub fn precondition_failed_returns_status_with_code_412_test() {
  // Arrange & Act
  let status = statuses.precondition_failed()

  // Assert
  case status {
    statuses.PreconditionFailedStatus(code, message, _) -> {
      code |> should.equal(412)
      message |> should.equal("Precondition Failed")
    }
    _ -> should.fail()
  }
}

pub fn content_too_large_returns_status_with_code_413_test() {
  // Arrange & Act
  let status = statuses.content_too_large()

  // Assert
  case status {
    statuses.ContentTooLargeStatus(code, message, _) -> {
      code |> should.equal(413)
      message |> should.equal("Content Too Large")
    }
    _ -> should.fail()
  }
}

pub fn uri_too_long_returns_status_with_code_414_test() {
  // Arrange & Act
  let status = statuses.uri_too_long()

  // Assert
  case status {
    statuses.UriTooLongStatus(code, message, _) -> {
      code |> should.equal(414)
      message |> should.equal("URI Too Long")
    }
    _ -> should.fail()
  }
}

pub fn unsupported_media_type_returns_status_with_code_415_test() {
  // Arrange & Act
  let status = statuses.unsupported_media_type()

  // Assert
  case status {
    statuses.UnsupportedMediaTypeStatus(code, message, _) -> {
      code |> should.equal(415)
      message |> should.equal("Unsupported Media Type")
    }
    _ -> should.fail()
  }
}

pub fn range_not_satisfiable_returns_status_with_code_416_test() {
  // Arrange & Act
  let status = statuses.range_not_satisfiable()

  // Assert
  case status {
    statuses.RangeNotSatisfiableStatus(code, message, _) -> {
      code |> should.equal(416)
      message |> should.equal("Range Not Satisfiable")
    }
    _ -> should.fail()
  }
}

pub fn expectation_failed_returns_status_with_code_417_test() {
  // Arrange & Act
  let status = statuses.expectation_failed()

  // Assert
  case status {
    statuses.ExpectationFailedStatus(code, message, _) -> {
      code |> should.equal(417)
      message |> should.equal("Expectation Failed")
    }
    _ -> should.fail()
  }
}

pub fn im_a_teapot_returns_status_with_code_418_test() {
  // Arrange & Act
  let status = statuses.im_a_teapot()

  // Assert
  case status {
    statuses.ImATeapotStatus(code, message, _) -> {
      code |> should.equal(418)
      message |> should.equal("I'm a teapot")
    }
    _ -> should.fail()
  }
}

pub fn misdirected_request_returns_status_with_code_421_test() {
  // Arrange & Act
  let status = statuses.misdirected_request()

  // Assert
  case status {
    statuses.MisdirectedRequestStatus(code, message, _) -> {
      code |> should.equal(421)
      message |> should.equal("Misdirected Request")
    }
    _ -> should.fail()
  }
}

pub fn unprocessable_content_returns_status_with_code_422_test() {
  // Arrange & Act
  let status = statuses.unprocessable_content()

  // Assert
  case status {
    statuses.UnprocessableContentStatus(code, message, _) -> {
      code |> should.equal(422)
      message |> should.equal("Unprocessable Content")
    }
    _ -> should.fail()
  }
}

pub fn locked_returns_status_with_code_423_test() {
  // Arrange & Act
  let status = statuses.locked()

  // Assert
  case status {
    statuses.LockedStatus(code, message, _) -> {
      code |> should.equal(423)
      message |> should.equal("Locked")
    }
    _ -> should.fail()
  }
}

pub fn failed_dependency_returns_status_with_code_424_test() {
  // Arrange & Act
  let status = statuses.failed_dependency()

  // Assert
  case status {
    statuses.FailedDependencyStatus(code, message, _) -> {
      code |> should.equal(424)
      message |> should.equal("Failed Dependency")
    }
    _ -> should.fail()
  }
}

pub fn too_early_returns_status_with_code_425_test() {
  // Arrange & Act
  let status = statuses.too_early()

  // Assert
  case status {
    statuses.TooEarlyStatus(code, message, _) -> {
      code |> should.equal(425)
      message |> should.equal("Too Early")
    }
    _ -> should.fail()
  }
}

pub fn upgrade_required_returns_status_with_code_426_test() {
  // Arrange & Act
  let status = statuses.upgrade_required()

  // Assert
  case status {
    statuses.UpgradeRequiredStatus(code, message, _) -> {
      code |> should.equal(426)
      message |> should.equal("Upgrade Required")
    }
    _ -> should.fail()
  }
}

pub fn precondition_required_returns_status_with_code_428_test() {
  // Arrange & Act
  let status = statuses.precondition_required()

  // Assert
  case status {
    statuses.PreconditionRequiredStatus(code, message, _) -> {
      code |> should.equal(428)
      message |> should.equal("Precondition Required")
    }
    _ -> should.fail()
  }
}

pub fn too_many_requests_returns_status_with_code_429_test() {
  // Arrange & Act
  let status = statuses.too_many_requests()

  // Assert
  case status {
    statuses.TooManyRequestsStatus(code, message, _) -> {
      code |> should.equal(429)
      message |> should.equal("Too Many Requests")
    }
    _ -> should.fail()
  }
}

pub fn request_header_fields_too_large_returns_status_with_code_431_test() {
  // Arrange & Act
  let status = statuses.request_header_fields_too_large()

  // Assert
  case status {
    statuses.RequestHeaderFieldsTooLargeStatus(code, message, _) -> {
      code |> should.equal(431)
      message |> should.equal("Request Header Fields Too Large")
    }
    _ -> should.fail()
  }
}

pub fn unavailable_for_legal_reasons_returns_status_with_code_451_test() {
  // Arrange & Act
  let status = statuses.unavailable_for_legal_reasons()

  // Assert
  case status {
    statuses.UnavailableForLegalReasonsStatus(code, message, _) -> {
      code |> should.equal(451)
      message |> should.equal("Unavailable For Legal Reasons")
    }
    _ -> should.fail()
  }
}

// Test server error status codes
pub fn internal_server_error_returns_status_with_code_500_test() {
  // Arrange & Act
  let status = statuses.internal_server_error()

  // Assert
  case status {
    statuses.InternalServerErrorStatus(code, message, _) -> {
      code |> should.equal(500)
      message |> should.equal("Internal Server Error")
    }
    _ -> should.fail()
  }
}

pub fn not_implemented_returns_status_with_code_501_test() {
  // Arrange & Act
  let status = statuses.not_implemented()

  // Assert
  case status {
    statuses.NotImplementedStatus(code, message, _) -> {
      code |> should.equal(501)
      message |> should.equal("Not Implemented")
    }
    _ -> should.fail()
  }
}

pub fn bad_gateway_returns_status_with_code_502_test() {
  // Arrange & Act
  let status = statuses.bad_gateway()

  // Assert
  case status {
    statuses.BadGatewayStatus(code, message, _) -> {
      code |> should.equal(502)
      message |> should.equal("Bad Gateway")
    }
    _ -> should.fail()
  }
}

pub fn service_unavailable_returns_status_with_code_503_test() {
  // Arrange & Act
  let status = statuses.service_unavailable()

  // Assert
  case status {
    statuses.ServiceUnavailableStatus(code, message, _) -> {
      code |> should.equal(503)
      message |> should.equal("Service Unavailable")
    }
    _ -> should.fail()
  }
}

pub fn gateway_timeout_returns_status_with_code_504_test() {
  // Arrange & Act
  let status = statuses.gateway_timeout()

  // Assert
  case status {
    statuses.GatewayTimeoutStatus(code, message, _) -> {
      code |> should.equal(504)
      message |> should.equal("Gateway Timeout")
    }
    _ -> should.fail()
  }
}

pub fn http_version_not_supported_returns_status_with_code_505_test() {
  // Arrange & Act
  let status = statuses.http_version_not_supported()

  // Assert
  case status {
    statuses.HttpVersionNotSupportedStatus(code, message, _) -> {
      code |> should.equal(505)
      message |> should.equal("HTTP Version Not Supported")
    }
    _ -> should.fail()
  }
}

pub fn variant_also_negotiates_returns_status_with_code_506_test() {
  // Arrange & Act
  let status = statuses.variant_also_negotiates()

  // Assert
  case status {
    statuses.VariantAlsoNegotiatesStatus(code, message, _) -> {
      code |> should.equal(506)
      message |> should.equal("Variant Also Negotiates")
    }
    _ -> should.fail()
  }
}

pub fn insufficient_storage_returns_status_with_code_507_test() {
  // Arrange & Act
  let status = statuses.insufficient_storage()

  // Assert
  case status {
    statuses.InsufficientStorageStatus(code, message, _) -> {
      code |> should.equal(507)
      message |> should.equal("Insufficient Storage")
    }
    _ -> should.fail()
  }
}

pub fn loop_detected_returns_status_with_code_508_test() {
  // Arrange & Act
  let status = statuses.loop_detected()

  // Assert
  case status {
    statuses.LoopDetectedStatus(code, message, _) -> {
      code |> should.equal(508)
      message |> should.equal("Loop Detected")
    }
    _ -> should.fail()
  }
}

pub fn not_extended_returns_status_with_code_510_test() {
  // Arrange & Act
  let status = statuses.not_extended()

  // Assert
  case status {
    statuses.NotExtendedStatus(code, message, _) -> {
      code |> should.equal(510)
      message |> should.equal("Not Extended")
    }
    _ -> should.fail()
  }
}

pub fn network_authentication_required_returns_status_with_code_511_test() {
  // Arrange & Act
  let status = statuses.network_authentication_required()

  // Assert
  case status {
    statuses.NetworkAuthenticationRequiredStatus(code, message, _) -> {
      code |> should.equal(511)
      message |> should.equal("Network Authentication Required")
    }
    _ -> should.fail()
  }
}

// Test helper status functions
pub fn ok_status_returns_success_status_test() {
  // Arrange & Act
  let status = statuses.ok_status()

  // Assert
  case status {
    statuses.SuccessStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(200)
}

pub fn created_status_returns_success_status_test() {
  // Arrange & Act
  let status = statuses.created_status()

  // Assert
  case status {
    statuses.SuccessStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(201)
}

pub fn accepted_status_returns_success_status_test() {
  // Arrange & Act
  let status = statuses.accepted_status()

  // Assert
  case status {
    statuses.SuccessStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(202)
}

pub fn no_content_status_returns_success_status_test() {
  // Arrange & Act
  let status = statuses.no_content_status()

  // Assert
  case status {
    statuses.SuccessStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(204)
}

pub fn not_found_status_returns_client_error_status_test() {
  // Arrange & Act
  let status = statuses.not_found_status()

  // Assert
  case status {
    statuses.ClientErrorStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(404)
}

pub fn bad_request_status_returns_client_error_status_test() {
  // Arrange & Act
  let status = statuses.bad_request_status()

  // Assert
  case status {
    statuses.ClientErrorStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(400)
}

pub fn unauthorized_status_returns_client_error_status_test() {
  // Arrange & Act
  let status = statuses.unauthorized_status()

  // Assert
  case status {
    statuses.ClientErrorStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(401)
}

pub fn forbidden_status_returns_client_error_status_test() {
  // Arrange & Act
  let status = statuses.forbidden_status()

  // Assert
  case status {
    statuses.ClientErrorStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(403)
}

pub fn internal_server_error_status_returns_server_error_status_test() {
  // Arrange & Act
  let status = statuses.internal_server_error_status()

  // Assert
  case status {
    statuses.ServerErrorStatus(_) -> Nil
    _ -> should.fail()
  }
  statuses.to_code(status) |> should.equal(500)
}

// Test to_code function
pub fn to_code_with_informational_status_returns_code_test() {
  // Arrange
  let status = statuses.convert_informational_to_status(statuses.continue())

  // Act
  let code = statuses.to_code(status)

  // Assert
  code |> should.equal(100)
}

pub fn to_code_with_success_status_returns_code_test() {
  // Arrange
  let status = statuses.convert_success_to_status(statuses.ok())

  // Act
  let code = statuses.to_code(status)

  // Assert
  code |> should.equal(200)
}

pub fn to_code_with_redirection_status_returns_code_test() {
  // Arrange
  let status =
    statuses.convert_redirection_to_status(statuses.moved_permanently())

  // Act
  let code = statuses.to_code(status)

  // Assert
  code |> should.equal(301)
}

pub fn to_code_with_client_error_status_returns_code_test() {
  // Arrange
  let status = statuses.convert_client_error_to_status(statuses.not_found())

  // Act
  let code = statuses.to_code(status)

  // Assert
  code |> should.equal(404)
}

pub fn to_code_with_server_error_status_returns_code_test() {
  // Arrange
  let status =
    statuses.convert_server_error_to_status(statuses.internal_server_error())

  // Act
  let code = statuses.to_code(status)

  // Assert
  code |> should.equal(500)
}

pub fn to_code_with_all_status_types_returns_correct_codes_test() {
  // Test various status codes to ensure to_code works for all types
  statuses.to_code(
    statuses.convert_informational_to_status(statuses.switching_protocols()),
  )
  |> should.equal(101)
  statuses.to_code(statuses.convert_success_to_status(statuses.created()))
  |> should.equal(201)
  statuses.to_code(statuses.convert_redirection_to_status(statuses.found()))
  |> should.equal(302)
  statuses.to_code(
    statuses.convert_client_error_to_status(statuses.bad_request()),
  )
  |> should.equal(400)
  statuses.to_code(
    statuses.convert_server_error_to_status(statuses.bad_gateway()),
  )
  |> should.equal(502)
}
