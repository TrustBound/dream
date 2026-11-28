//// The secret key that signs share links. The type is opaque: code
//// outside this module can sign with the key, but it cannot read the key.

import gleam/bit_array
import gleam/crypto
import gleam/string

pub opaque type SigningKey {
  SigningKey(bytes: BitArray)
}

/// A shorter key is too easy to guess.
pub const minimum_length = 32

/// Why a text cannot be a signing key. The error holds the length of the
/// text, never the text.
pub type SigningKeyError {
  TooShort(length: Int)
}

/// The signing key from `text`, when it has `minimum_length` characters or
/// more.
pub fn new(text: String) -> Result(SigningKey, SigningKeyError) {
  let length = string.length(text)
  case length >= minimum_length {
    True -> Ok(SigningKey(bytes: bit_array.from_string(text)))
    False -> Error(TooShort(length:))
  }
}

/// The HMAC-SHA256 signature of `message`, as lowercase hex.
pub fn sign(key: SigningKey, message: String) -> String {
  crypto.hmac(bit_array.from_string(message), crypto.Sha256, key.bytes)
  |> bit_array.base16_encode
  |> string.lowercase
}
