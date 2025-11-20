//// Product domain type
////
//// Pure domain type - no serialization logic.

pub type Product {
  Product(id: Int, name: String, price: Float, stock: Int)
}
