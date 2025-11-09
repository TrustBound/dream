//// HTTP status codes and conversion utilities
////
//// This module provides comprehensive HTTP status code types and utilities
//// for creating and working with HTTP status codes in Dream.

/// HTTP 1xx informational status codes
pub type Informational {
  ContinueStatus(code: Int, message: String, description: String)
  SwitchingProtocolsStatus(code: Int, message: String, description: String)
  ProcessingStatus(code: Int, message: String, description: String)
  EarlyHintsStatus(code: Int, message: String, description: String)
}

/// HTTP 2xx success status codes
pub type Success {
  OkStatus(code: Int, message: String, description: String)
  CreatedStatus(code: Int, message: String, description: String)
  AcceptedStatus(code: Int, message: String, description: String)
  NonAuthoritativeInformationStatus(
    code: Int,
    message: String,
    description: String,
  )
  NoContentStatus(code: Int, message: String, description: String)
  ResetContentStatus(code: Int, message: String, description: String)
  PartialContentStatus(code: Int, message: String, description: String)
  MultiStatusStatus(code: Int, message: String, description: String)
  AlreadyReportedStatus(code: Int, message: String, description: String)
  ImUsedStatus(code: Int, message: String, description: String)
}

/// HTTP 3xx redirection status codes
pub type Redirection {
  MultipleChoicesStatus(code: Int, message: String, description: String)
  MovedPermanentlyStatus(code: Int, message: String, description: String)
  FoundStatus(code: Int, message: String, description: String)
  SeeOtherStatus(code: Int, message: String, description: String)
  NotModifiedStatus(code: Int, message: String, description: String)
  UseProxyStatus(code: Int, message: String, description: String)
  TemporaryRedirectStatus(code: Int, message: String, description: String)
  PermanentRedirectStatus(code: Int, message: String, description: String)
}

/// HTTP 4xx client error status codes
pub type ClientError {
  BadRequestStatus(code: Int, message: String, description: String)
  UnauthorizedStatus(code: Int, message: String, description: String)
  PaymentRequiredStatus(code: Int, message: String, description: String)
  ForbiddenStatus(code: Int, message: String, description: String)
  NotFoundStatus(code: Int, message: String, description: String)
  MethodNotAllowedStatus(code: Int, message: String, description: String)
  NotAcceptableStatus(code: Int, message: String, description: String)
  ProxyAuthenticationRequiredStatus(
    code: Int,
    message: String,
    description: String,
  )
  RequestTimeoutStatus(code: Int, message: String, description: String)
  ConflictStatus(code: Int, message: String, description: String)
  GoneStatus(code: Int, message: String, description: String)
  LengthRequiredStatus(code: Int, message: String, description: String)
  PreconditionFailedStatus(code: Int, message: String, description: String)
  ContentTooLargeStatus(code: Int, message: String, description: String)
  UriTooLongStatus(code: Int, message: String, description: String)
  UnsupportedMediaTypeStatus(code: Int, message: String, description: String)
  RangeNotSatisfiableStatus(code: Int, message: String, description: String)
  ExpectationFailedStatus(code: Int, message: String, description: String)
  ImATeapotStatus(code: Int, message: String, description: String)
  MisdirectedRequestStatus(code: Int, message: String, description: String)
  UnprocessableContentStatus(code: Int, message: String, description: String)
  LockedStatus(code: Int, message: String, description: String)
  FailedDependencyStatus(code: Int, message: String, description: String)
  TooEarlyStatus(code: Int, message: String, description: String)
  UpgradeRequiredStatus(code: Int, message: String, description: String)
  PreconditionRequiredStatus(code: Int, message: String, description: String)
  TooManyRequestsStatus(code: Int, message: String, description: String)
  RequestHeaderFieldsTooLargeStatus(
    code: Int,
    message: String,
    description: String,
  )
  UnavailableForLegalReasonsStatus(
    code: Int,
    message: String,
    description: String,
  )
}

/// HTTP 5xx server error status codes
pub type ServerError {
  InternalServerErrorStatus(code: Int, message: String, description: String)
  NotImplementedStatus(code: Int, message: String, description: String)
  BadGatewayStatus(code: Int, message: String, description: String)
  ServiceUnavailableStatus(code: Int, message: String, description: String)
  GatewayTimeoutStatus(code: Int, message: String, description: String)
  HttpVersionNotSupportedStatus(code: Int, message: String, description: String)
  VariantAlsoNegotiatesStatus(code: Int, message: String, description: String)
  InsufficientStorageStatus(code: Int, message: String, description: String)
  LoopDetectedStatus(code: Int, message: String, description: String)
  NotExtendedStatus(code: Int, message: String, description: String)
  NetworkAuthenticationRequiredStatus(
    code: Int,
    message: String,
    description: String,
  )
}

/// HTTP status code type that can be any of the status code categories
pub type Status {
  InformationalStatus(Informational)
  SuccessStatus(Success)
  RedirectionStatus(Redirection)
  ClientErrorStatus(ClientError)
  ServerErrorStatus(ServerError)
}

/// Convert an Informational status to a Status
pub fn convert_informational_to_status(informational: Informational) -> Status {
  InformationalStatus(informational)
}

/// Convert a Success status to a Status
pub fn convert_success_to_status(success: Success) -> Status {
  SuccessStatus(success)
}

/// Convert a Redirection status to a Status
pub fn convert_redirection_to_status(redirection: Redirection) -> Status {
  RedirectionStatus(redirection)
}

/// Convert a ClientError status to a Status
pub fn convert_client_error_to_status(client_error: ClientError) -> Status {
  ClientErrorStatus(client_error)
}

/// Convert a ServerError status to a Status
pub fn convert_server_error_to_status(server_error: ServerError) -> Status {
  ServerErrorStatus(server_error)
}

/// Create a Continue (100) status code
pub fn continue() -> Informational {
  ContinueStatus(
    code: 100,
    message: "Continue",
    description: "This interim response indicates that the client should continue the request or ignore the response if the request is already finished.",
  )
}

/// Create a Switching Protocols (101) status code
pub fn switching_protocols() -> Informational {
  SwitchingProtocolsStatus(
    code: 101,
    message: "Switching Protocols",
    description: "This code is sent in response to an Upgrade request header from the client and indicates the protocol the server is switching to.",
  )
}

/// Create a Processing (102) status code
pub fn processing() -> Informational {
  ProcessingStatus(
    code: 102,
    message: "Processing",
    description: "This code was used in WebDAV contexts to indicate that a request has been received by the server, but no status was available at the time of the response.",
  )
}

/// Create an Early Hints (103) status code
pub fn early_hints() -> Informational {
  EarlyHintsStatus(
    code: 103,
    message: "Early Hints",
    description: "This status code is primarily intended to be used with the Link header, letting the user agent start preloading resources while the server prepares a response or preconnect to an origin from which the page will need resources.",
  )
}

/// Create an OK (200) status code
pub fn ok() -> Success {
  OkStatus(
    code: 200,
    message: "OK",
    description: "The request succeeded. The result and meaning of \"success\" depends on the HTTP method: GET: The resource has been fetched and transmitted in the message body. HEAD: Representation headers are included in the response without any message body. PUT or POST: The resource describing the result of the action is transmitted in the message body. TRACE: The message body contains the request as received by the server.",
  )
}

/// Create a Created (201) status code
pub fn created() -> Success {
  CreatedStatus(
    code: 201,
    message: "Created",
    description: "The request succeeded, and a new resource was created as a result. This is typically the response sent after POST requests, or some PUT requests.",
  )
}

/// Create an Accepted (202) status code
pub fn accepted() -> Success {
  AcceptedStatus(
    code: 202,
    message: "Accepted",
    description: "The request has been received but not yet acted upon. It is noncommittal, since there is no way in HTTP to later send an asynchronous response indicating the outcome of the request. It is intended for cases where another process or server handles the request, or for batch processing.",
  )
}

/// Create a Non-Authoritative Information (203) status code
pub fn non_authoritative_information() -> Success {
  NonAuthoritativeInformationStatus(
    code: 203,
    message: "Non-Authoritative Information",
    description: "This response code means the returned metadata is not exactly the same as is available from the origin server, but is collected from a local or a third-party copy. This is mostly used for mirrors or backups of another resource. Except for that specific case, the 200 OK response is preferred to this status.",
  )
}

/// Create a No Content (204) status code
pub fn no_content() -> Success {
  NoContentStatus(
    code: 204,
    message: "No Content",
    description: "There is no content to send for this request, but the headers are useful. The user agent may update its cached headers for this resource with the new ones.",
  )
}

/// Create a Reset Content (205) status code
pub fn reset_content() -> Success {
  ResetContentStatus(
    code: 205,
    message: "Reset Content",
    description: "Tells the user agent to reset the document which sent this request.",
  )
}

/// Create a Partial Content (206) status code
pub fn partial_content() -> Success {
  PartialContentStatus(
    code: 206,
    message: "Partial Content",
    description: "This response code is used in response to a range request when the client has requested a part or parts of a resource.",
  )
}

/// Create a Multi-Status (207) status code
pub fn multi_status() -> Success {
  MultiStatusStatus(
    code: 207,
    message: "Multi-Status",
    description: "Conveys information about multiple resources, for situations where multiple status codes might be appropriate.",
  )
}

/// Create an Already Reported (208) status code
pub fn already_reported() -> Success {
  AlreadyReportedStatus(
    code: 208,
    message: "Already Reported",
    description: "Used inside a `<dav:propstat>` response element to avoid repeatedly enumerating the internal members of multiple bindings to the same collection.",
  )
}

/// Create an IM Used (226) status code
pub fn im_used() -> Success {
  ImUsedStatus(
    code: 226,
    message: "IM Used",
    description: "The server has fulfilled a GET request for the resource, and the response is a representation of the result of one or more instance-manipulations applied to the current instance.",
  )
}

/// Create a Multiple Choices (300) status code
pub fn multiple_choices() -> Redirection {
  MultipleChoicesStatus(
    code: 300,
    message: "Multiple Choices",
    description: "In agent-driven content negotiation, the request has more than one possible response and the user agent or user should choose one of them. There is no standardized way for clients to automatically choose one of the responses, so this is rarely used.",
  )
}

/// Create a Moved Permanently (301) status code
pub fn moved_permanently() -> Redirection {
  MovedPermanentlyStatus(
    code: 301,
    message: "Moved Permanently",
    description: "The URL of the requested resource has been changed permanently. The new URL is given in the response.",
  )
}

/// Create a Found (302) status code
pub fn found() -> Redirection {
  FoundStatus(
    code: 302,
    message: "Found",
    description: "This response code means that the URI of requested resource has been changed temporarily. Further changes in the URI might be made in the future, so the same URI should be used by the client in future requests.",
  )
}

/// Create a See Other (303) status code
pub fn see_other() -> Redirection {
  SeeOtherStatus(
    code: 303,
    message: "See Other",
    description: "The server sent this response to direct the client to get the requested resource at another URI with a GET request.",
  )
}

/// Create a Not Modified (304) status code
pub fn not_modified() -> Redirection {
  NotModifiedStatus(
    code: 304,
    message: "Not Modified",
    description: "This is used for caching purposes. It tells the client that the response has not been modified, so the client can continue to use the same cached version of the response.",
  )
}

/// Create a Use Proxy (305) status code
pub fn use_proxy() -> Redirection {
  UseProxyStatus(
    code: 305,
    message: "Use Proxy",
    description: "Defined in a previous version of the HTTP specification to indicate that a requested response must be accessed by a proxy. It has been deprecated due to security concerns regarding in-band configuration of a proxy.",
  )
}

/// Create a Temporary Redirect (307) status code
pub fn temporary_redirect() -> Redirection {
  TemporaryRedirectStatus(
    code: 307,
    message: "Temporary Redirect",
    description: "The server sends this response to direct the client to get the requested resource at another URI with the same method that was used in the prior request. This has the same semantics as the 302 Found response code, with the exception that the user agent must not change the HTTP method used: if a POST was used in the first request, a POST must be used in the second request.",
  )
}

/// Create a Permanent Redirect (308) status code
pub fn permanent_redirect() -> Redirection {
  PermanentRedirectStatus(
    code: 308,
    message: "Permanent Redirect",
    description: "This means that the resource is now permanently located at another URI, specified by the Location: HTTP Response header. This has the same semantics as the 301 Moved Permanently HTTP response code, with the exception that the user agent must not change the HTTP method used: if a POST was used in the first request, a POST must be used in the second request.",
  )
}

/// Create a Bad Request (400) status code
pub fn bad_request() -> ClientError {
  BadRequestStatus(
    code: 400,
    message: "Bad Request",
    description: "The server cannot or will not process the request due to something that is perceived to be a client error (e.g., malformed request syntax, invalid request message framing, or deceptive request routing).",
  )
}

/// Create an Unauthorized (401) status code
pub fn unauthorized() -> ClientError {
  UnauthorizedStatus(
    code: 401,
    message: "Unauthorized",
    description: "Although the HTTP standard specifies \"unauthorized\", semantically this response means \"unauthenticated\". That is, the client must authenticate itself to get the requested response.",
  )
}

/// Create a Payment Required (402) status code
pub fn payment_required() -> ClientError {
  PaymentRequiredStatus(
    code: 402,
    message: "Payment Required",
    description: "This response code is reserved for future use. The initial aim for creating this code was using it for digital payment systems. However, this status code is used very rarely and no standard convention exists.",
  )
}

/// Create a Forbidden (403) status code
pub fn forbidden() -> ClientError {
  ForbiddenStatus(
    code: 403,
    message: "Forbidden",
    description: "The client does not have access rights to the content; that is, it is unauthorized, so the server is refusing to give the requested resource. Unlike 401 Unauthorized, the client's identity is known to the server.",
  )
}

/// Create a Not Found (404) status code
pub fn not_found() -> ClientError {
  NotFoundStatus(
    code: 404,
    message: "Not Found",
    description: "The server cannot find the requested resource. In the browser, this means the URL is not recognized. In an API, this can also mean that the endpoint is valid but the resource itself does not exist. Servers may also send this response instead of 403 Forbidden to hide the existence of a resource from an unauthorized client.",
  )
}

/// Create a Method Not Allowed (405) status code
pub fn method_not_allowed() -> ClientError {
  MethodNotAllowedStatus(
    code: 405,
    message: "Method Not Allowed",
    description: "The request method is known by the server but is not supported by the target resource. For example, an API may not allow calling DELETE to remove a resource.",
  )
}

/// Create a Not Acceptable (406) status code
pub fn not_acceptable() -> ClientError {
  NotAcceptableStatus(
    code: 406,
    message: "Not Acceptable",
    description: "This response is sent when the web server, after performing server-driven content negotiation, doesn't find any content that conforms to the criteria given by the user agent.",
  )
}

/// Create a Proxy Authentication Required (407) status code
pub fn proxy_authentication_required() -> ClientError {
  ProxyAuthenticationRequiredStatus(
    code: 407,
    message: "Proxy Authentication Required",
    description: "This is similar to 401 Unauthorized but authentication is needed to be done by a proxy.",
  )
}

/// Create a Request Timeout (408) status code
pub fn request_timeout() -> ClientError {
  RequestTimeoutStatus(
    code: 408,
    message: "Request Timeout",
    description: "This response is sent on an idle connection by some servers, even without any previous request by the client. It means that the server would like to shut down this unused connection. This response is used much more since some browsers, like Chrome, Firefox 27+, or IE9, use HTTP pre-connection mechanisms to speed up surfing. Also note that some servers merely shut down the connection without sending this message.",
  )
}

/// Create a Conflict (409) status code
pub fn conflict() -> ClientError {
  ConflictStatus(
    code: 409,
    message: "Conflict",
    description: "This response is sent when a request conflicts with the current state of the server.",
  )
}

/// Create a Gone (410) status code
pub fn gone() -> ClientError {
  GoneStatus(
    code: 410,
    message: "Gone",
    description: "This response is sent when the requested content has been permanently deleted from server, with no forwarding address. Clients are expected to remove their caches and links to the resource. The HTTP specification intends this status code to be used for \"limited-time, promotional services\". APIs should not feel compelled to indicate resources that have been deleted with this status code.",
  )
}

/// Create a Length Required (411) status code
pub fn length_required() -> ClientError {
  LengthRequiredStatus(
    code: 411,
    message: "Length Required",
    description: "Server rejected the request because the Content-Length header field is not defined and the server requires it.",
  )
}

/// Create a Precondition Failed (412) status code
pub fn precondition_failed() -> ClientError {
  PreconditionFailedStatus(
    code: 412,
    message: "Precondition Failed",
    description: "The client has indicated preconditions in its headers which the server does not meet.",
  )
}

/// Create a Content Too Large (413) status code
pub fn content_too_large() -> ClientError {
  ContentTooLargeStatus(
    code: 413,
    message: "Content Too Large",
    description: "Request entity is larger than limits defined by server. The server might close the connection or return an Retry-After header field.",
  )
}

/// Create a URI Too Long (414) status code
pub fn uri_too_long() -> ClientError {
  UriTooLongStatus(
    code: 414,
    message: "URI Too Long",
    description: "The URI requested by the client is longer than the server is willing to interpret.",
  )
}

/// Create an Unsupported Media Type (415) status code
pub fn unsupported_media_type() -> ClientError {
  UnsupportedMediaTypeStatus(
    code: 415,
    message: "Unsupported Media Type",
    description: "The media format of the requested data is not supported by the server, so the server is rejecting the request.",
  )
}

/// Create a Range Not Satisfiable (416) status code
pub fn range_not_satisfiable() -> ClientError {
  RangeNotSatisfiableStatus(
    code: 416,
    message: "Range Not Satisfiable",
    description: "The range specified by the Range header field in the request cannot be fulfilled. It's possible that the range is outside the size of the target URI's data.",
  )
}

/// Create an Expectation Failed (417) status code
pub fn expectation_failed() -> ClientError {
  ExpectationFailedStatus(
    code: 417,
    message: "Expectation Failed",
    description: "This response code means the expectation indicated by the Expect request header field cannot be met by the server.",
  )
}

/// Create an I'm a Teapot (418) status code
pub fn im_a_teapot() -> ClientError {
  ImATeapotStatus(
    code: 418,
    message: "I'm a teapot",
    description: "The server refuses the attempt to brew coffee with a teapot.",
  )
}

/// Create a Misdirected Request (421) status code
pub fn misdirected_request() -> ClientError {
  MisdirectedRequestStatus(
    code: 421,
    message: "Misdirected Request",
    description: "The request was directed at a server that is not able to produce a response. This can be sent by a server that is not configured to produce responses for the combination of scheme and authority that are included in the request URI.",
  )
}

/// Create an Unprocessable Content (422) status code
pub fn unprocessable_content() -> ClientError {
  UnprocessableContentStatus(
    code: 422,
    message: "Unprocessable Content",
    description: "The request was well-formed but was unable to be followed due to semantic errors.",
  )
}

/// Create a Locked (423) status code
pub fn locked() -> ClientError {
  LockedStatus(
    code: 423,
    message: "Locked",
    description: "The resource that is being accessed is locked.",
  )
}

/// Create a Failed Dependency (424) status code
pub fn failed_dependency() -> ClientError {
  FailedDependencyStatus(
    code: 424,
    message: "Failed Dependency",
    description: "The request failed because it depended on another request and that request failed.",
  )
}

/// Create a Too Early (425) status code
pub fn too_early() -> ClientError {
  TooEarlyStatus(
    code: 425,
    message: "Too Early",
    description: "Indicates that the server is unwilling to risk processing a request that might be replayed.",
  )
}

/// Create an Upgrade Required (426) status code
pub fn upgrade_required() -> ClientError {
  UpgradeRequiredStatus(
    code: 426,
    message: "Upgrade Required",
    description: "The server refuses to perform the request using the current protocol but might be willing to do so after the client upgrades to a different protocol. The server sends an Upgrade header in a 426 response to indicate the required protocol(s).",
  )
}

/// Create a Precondition Required (428) status code
pub fn precondition_required() -> ClientError {
  PreconditionRequiredStatus(
    code: 428,
    message: "Precondition Required",
    description: "The origin server requires the request to be conditional. This response is intended to prevent the 'lost update' problem, where a client GETs a resource's state, modifies it and PUTs it back to the server, when meanwhile a third party has modified the state on the server, leading to a conflict.",
  )
}

/// Create a Too Many Requests (429) status code
pub fn too_many_requests() -> ClientError {
  TooManyRequestsStatus(
    code: 429,
    message: "Too Many Requests",
    description: "The user has sent too many requests in a given amount of time (\"rate limiting\").",
  )
}

/// Create a Request Header Fields Too Large (431) status code
pub fn request_header_fields_too_large() -> ClientError {
  RequestHeaderFieldsTooLargeStatus(
    code: 431,
    message: "Request Header Fields Too Large",
    description: "The server is unwilling to process the request because its header fields are too large. The request may be resubmitted after reducing the size of the request header fields.",
  )
}

/// Create an Unavailable For Legal Reasons (451) status code
pub fn unavailable_for_legal_reasons() -> ClientError {
  UnavailableForLegalReasonsStatus(
    code: 451,
    message: "Unavailable For Legal Reasons",
    description: "The user-agent requested a resource that cannot legally be provided, such as a web page censored by a government.",
  )
}

/// Create an Internal Server Error (500) status code
pub fn internal_server_error() -> ServerError {
  InternalServerErrorStatus(
    code: 500,
    message: "Internal Server Error",
    description: "The server has encountered a situation it does not know how to handle.",
  )
}

/// Create a Not Implemented (501) status code
pub fn not_implemented() -> ServerError {
  NotImplementedStatus(
    code: 501,
    message: "Not Implemented",
    description: "The request method is not supported by the server and cannot be handled. The only methods that servers are required to support (and therefore that must not return this code) are GET and HEAD.",
  )
}

/// Create a Bad Gateway (502) status code
pub fn bad_gateway() -> ServerError {
  BadGatewayStatus(
    code: 502,
    message: "Bad Gateway",
    description: "This error response means that the server, while working as a gateway to get a response needed to handle the request, got an invalid response.",
  )
}

/// Create a Service Unavailable (503) status code
pub fn service_unavailable() -> ServerError {
  ServiceUnavailableStatus(
    code: 503,
    message: "Service Unavailable",
    description: "The server is not ready to handle the request. Common causes are a server that is down for maintenance or that is overloaded. Note that together with this response, a user-friendly page explaining the problem should be sent. This response should be used for temporary conditions and the Retry-After HTTP header should, if possible, contain the estimated time before the recovery of the service. The webmaster must also take care about the caching-related headers that are sent along with this response, as these temporary condition responses should usually not be cached.",
  )
}

/// Create a Gateway Timeout (504) status code
pub fn gateway_timeout() -> ServerError {
  GatewayTimeoutStatus(
    code: 504,
    message: "Gateway Timeout",
    description: "This error response is given when the server is acting as a gateway and cannot get a response in time.",
  )
}

/// Create an HTTP Version Not Supported (505) status code
pub fn http_version_not_supported() -> ServerError {
  HttpVersionNotSupportedStatus(
    code: 505,
    message: "HTTP Version Not Supported",
    description: "The HTTP version used in the request is not supported by the server.",
  )
}

/// Create a Variant Also Negotiates (506) status code
pub fn variant_also_negotiates() -> ServerError {
  VariantAlsoNegotiatesStatus(
    code: 506,
    message: "Variant Also Negotiates",
    description: "The server has an internal configuration error: the chosen variant resource is configured to engage in transparent content negotiation itself, and is therefore not a proper end point in the negotiation process.",
  )
}

/// Create an Insufficient Storage (507) status code
pub fn insufficient_storage() -> ServerError {
  InsufficientStorageStatus(
    code: 507,
    message: "Insufficient Storage",
    description: "The method could not be performed on the resource because the server is unable to store the representation needed to successfully complete the request.",
  )
}

/// Create a Loop Detected (508) status code
pub fn loop_detected() -> ServerError {
  LoopDetectedStatus(
    code: 508,
    message: "Loop Detected",
    description: "The server detected an infinite loop while processing the request.",
  )
}

/// Create a Not Extended (510) status code
pub fn not_extended() -> ServerError {
  NotExtendedStatus(
    code: 510,
    message: "Not Extended",
    description: "Further extensions to the request are required for the server to fulfill it.",
  )
}

/// Create a Network Authentication Required (511) status code
pub fn network_authentication_required() -> ServerError {
  NetworkAuthenticationRequiredStatus(
    code: 511,
    message: "Network Authentication Required",
    description: "Indicates that the client needs to authenticate to gain network access.",
  )
}

// Status helper functions - return Status directly

/// Create an OK (200) status
pub fn ok_status() -> Status {
  convert_success_to_status(ok())
}

/// Create a Created (201) status
pub fn created_status() -> Status {
  convert_success_to_status(created())
}

/// Create an Accepted (202) status
pub fn accepted_status() -> Status {
  convert_success_to_status(accepted())
}

/// Create a No Content (204) status
pub fn no_content_status() -> Status {
  convert_success_to_status(no_content())
}

/// Create a Not Found (404) status
pub fn not_found_status() -> Status {
  convert_client_error_to_status(not_found())
}

/// Create a Bad Request (400) status
pub fn bad_request_status() -> Status {
  convert_client_error_to_status(bad_request())
}

/// Create an Unauthorized (401) status
pub fn unauthorized_status() -> Status {
  convert_client_error_to_status(unauthorized())
}

/// Create a Forbidden (403) status
pub fn forbidden_status() -> Status {
  convert_client_error_to_status(forbidden())
}

/// Create an Internal Server Error (500) status
pub fn internal_server_error_status() -> Status {
  convert_server_error_to_status(internal_server_error())
}

/// Extract the numeric HTTP status code from a Status value
pub fn to_code(status: Status) -> Int {
  case status {
    InformationalStatus(info) -> {
      case info {
        ContinueStatus(code, _, _) -> code
        SwitchingProtocolsStatus(code, _, _) -> code
        ProcessingStatus(code, _, _) -> code
        EarlyHintsStatus(code, _, _) -> code
      }
    }
    SuccessStatus(success) -> {
      case success {
        OkStatus(code, _, _) -> code
        CreatedStatus(code, _, _) -> code
        AcceptedStatus(code, _, _) -> code
        NonAuthoritativeInformationStatus(code, _, _) -> code
        NoContentStatus(code, _, _) -> code
        ResetContentStatus(code, _, _) -> code
        PartialContentStatus(code, _, _) -> code
        MultiStatusStatus(code, _, _) -> code
        AlreadyReportedStatus(code, _, _) -> code
        ImUsedStatus(code, _, _) -> code
      }
    }
    RedirectionStatus(redirect) -> {
      case redirect {
        MultipleChoicesStatus(code, _, _) -> code
        MovedPermanentlyStatus(code, _, _) -> code
        FoundStatus(code, _, _) -> code
        SeeOtherStatus(code, _, _) -> code
        NotModifiedStatus(code, _, _) -> code
        UseProxyStatus(code, _, _) -> code
        TemporaryRedirectStatus(code, _, _) -> code
        PermanentRedirectStatus(code, _, _) -> code
      }
    }
    ClientErrorStatus(error) -> {
      case error {
        BadRequestStatus(code, _, _) -> code
        UnauthorizedStatus(code, _, _) -> code
        PaymentRequiredStatus(code, _, _) -> code
        ForbiddenStatus(code, _, _) -> code
        NotFoundStatus(code, _, _) -> code
        MethodNotAllowedStatus(code, _, _) -> code
        NotAcceptableStatus(code, _, _) -> code
        ProxyAuthenticationRequiredStatus(code, _, _) -> code
        RequestTimeoutStatus(code, _, _) -> code
        ConflictStatus(code, _, _) -> code
        GoneStatus(code, _, _) -> code
        LengthRequiredStatus(code, _, _) -> code
        PreconditionFailedStatus(code, _, _) -> code
        ContentTooLargeStatus(code, _, _) -> code
        UriTooLongStatus(code, _, _) -> code
        UnsupportedMediaTypeStatus(code, _, _) -> code
        RangeNotSatisfiableStatus(code, _, _) -> code
        ExpectationFailedStatus(code, _, _) -> code
        ImATeapotStatus(code, _, _) -> code
        MisdirectedRequestStatus(code, _, _) -> code
        UnprocessableContentStatus(code, _, _) -> code
        LockedStatus(code, _, _) -> code
        FailedDependencyStatus(code, _, _) -> code
        TooEarlyStatus(code, _, _) -> code
        UpgradeRequiredStatus(code, _, _) -> code
        PreconditionRequiredStatus(code, _, _) -> code
        TooManyRequestsStatus(code, _, _) -> code
        RequestHeaderFieldsTooLargeStatus(code, _, _) -> code
        UnavailableForLegalReasonsStatus(code, _, _) -> code
      }
    }
    ServerErrorStatus(error) -> {
      case error {
        InternalServerErrorStatus(code, _, _) -> code
        NotImplementedStatus(code, _, _) -> code
        BadGatewayStatus(code, _, _) -> code
        ServiceUnavailableStatus(code, _, _) -> code
        GatewayTimeoutStatus(code, _, _) -> code
        HttpVersionNotSupportedStatus(code, _, _) -> code
        VariantAlsoNegotiatesStatus(code, _, _) -> code
        InsufficientStorageStatus(code, _, _) -> code
        LoopDetectedStatus(code, _, _) -> code
        NotExtendedStatus(code, _, _) -> code
        NetworkAuthenticationRequiredStatus(code, _, _) -> code
      }
    }
  }
}
