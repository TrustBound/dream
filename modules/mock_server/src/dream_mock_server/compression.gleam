//// Compression helpers for mock server endpoints (wraps zlib FFI)

@external(erlang, "compression_ffi", "gzip_compress")
pub fn gzip_compress(data: BitArray) -> BitArray

@external(erlang, "compression_ffi", "deflate_compress")
pub fn deflate_compress(data: BitArray) -> BitArray

@external(erlang, "compression_ffi", "gzip_compress_chunks")
pub fn gzip_compress_chunks(chunks: List(BitArray)) -> List(BitArray)

@external(erlang, "compression_ffi", "deflate_compress_chunks")
pub fn deflate_compress_chunks(chunks: List(BitArray)) -> List(BitArray)
