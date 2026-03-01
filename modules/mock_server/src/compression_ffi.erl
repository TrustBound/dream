-module(compression_ffi).

-export([gzip_compress/1, deflate_compress/1, gzip_compress_chunks/1,
         deflate_compress_chunks/1]).

gzip_compress(Data) when is_binary(Data) ->
    zlib:gzip(Data).

deflate_compress(Data) when is_binary(Data) ->
    zlib:compress(Data).

%% Compress each item and return a list of gzip-compressed chunks
%% that together form one valid gzip stream.
gzip_compress_chunks(DataList) when is_list(DataList) ->
    Z = zlib:open(),
    ok = zlib:deflateInit(Z, default, deflated, 31, 8, default),
    Chunks = lists:map(
        fun(Data) ->
            Bin = ensure_binary(Data),
            iolist_to_binary(zlib:deflate(Z, Bin, sync))
        end, DataList),
    Final = iolist_to_binary(zlib:deflate(Z, <<>>, finish)),
    zlib:deflateEnd(Z),
    zlib:close(Z),
    Chunks ++ [Final].

%% Compress each item and return a list of deflate-compressed chunks
%% that together form one valid deflate/zlib stream.
deflate_compress_chunks(DataList) when is_list(DataList) ->
    Z = zlib:open(),
    ok = zlib:deflateInit(Z),
    Chunks = lists:map(
        fun(Data) ->
            Bin = ensure_binary(Data),
            iolist_to_binary(zlib:deflate(Z, Bin, sync))
        end, DataList),
    Final = iolist_to_binary(zlib:deflate(Z, <<>>, finish)),
    zlib:deflateEnd(Z),
    zlib:close(Z),
    Chunks ++ [Final].

ensure_binary(Bin) when is_binary(Bin) -> Bin;
ensure_binary(List) when is_list(List) -> list_to_binary(List).
