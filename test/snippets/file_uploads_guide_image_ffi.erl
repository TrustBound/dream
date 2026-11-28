-module(file_uploads_guide_image_ffi).
-export([resize/3]).

%% Dream ships no image library. This stub stands in for a call to
%% ImageMagick or a similar library, and always returns an error.
resize(_Content, _Width, _Height) ->
    {error, nil}.
