//// REST API guide: map errors to HTTP status codes
////
//// A create controller that turns each `Error` into a JSON response with
//// the matching status code, as shown in docs/guides/request-data.md.

import dream/context.{type AppContext}
import dream/http.{type Request, type Response, created, json_response}
import dream/http/error.{type Error, UnprocessableContent}
import dream/http/params
import gleam/json
import gleam/result
import snippets/rest_api_guide_validation.{
  type ProductData, decoder, validate_product_data,
}

pub fn create(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use data <- result.try(params.require_json(request, decoder()))
    use valid_data <- result.try(
      validate_product_data(data)
      |> result.map_error(UnprocessableContent),
    )
    create_product(services, valid_data)
  }

  case result {
    Ok(product) -> json_response(created, to_json(product))
    Error(create_error) -> error_to_response(create_error)
  }
}

fn create_product(
  services: Services,
  data: ProductData,
) -> Result(Product, Error) {
  // A real app saves the product to its database here
  Ok(Product(
    id: services.next_product_id,
    name: data.name,
    price: data.price,
    description: data.description,
  ))
}

fn error_to_response(create_error: Error) -> Response {
  json_response(
    error.to_status_code(create_error),
    error_json(error.message(create_error)),
  )
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string
}

// services.gleam, models/product.gleam and views/product_view.gleam

pub type Services {
  Services(next_product_id: Int)
}

pub type Product {
  Product(id: Int, name: String, price: Int, description: String)
}

fn to_json(product: Product) -> String {
  json.object([
    #("id", json.int(product.id)),
    #("name", json.string(product.name)),
    #("price", json.int(product.price)),
    #("description", json.string(product.description)),
  ])
  |> json.to_string
}
