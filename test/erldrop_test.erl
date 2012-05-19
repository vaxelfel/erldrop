%% -*- erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ts=4 sw=4 et

-module(erldrop_test).

-include_lib("eunit/include/eunit.hrl").

folder_test() ->
    Ctx = mk_ctx(),
    Path = "/" ++ rand_name(),
    %% create folder
    {ok, CreatedRaw} = erldrop:fileops_create_folder(Path, [], Ctx),
    Created = json_to_proplist(CreatedRaw),
    ?assertEqual(true, getv(<<"is_dir">>, Created)),
    ?assertEqual(0,    getv(<<"bytes">>, Created)),
    ?assertEqual(Path, b2l(getv(<<"path">>, Created))),
    %% delete folder
    {ok, DeletedRaw} = erldrop:fileops_delete(Path, [], Ctx),
    Deleted = json_to_proplist(DeletedRaw),
    ?assertEqual(true, getv(<<"is_dir">>, Deleted)),
    ?assertEqual(true, getv(<<"is_deleted">>, Deleted)),
    ?assertEqual(Path, b2l(getv(<<"path">>, Deleted))),
    ?assertEqual(true, getv(<<"is_deleted">>, Deleted)),
    ok.

upload_download_test() ->
    Ctx = mk_ctx(),
    Path = "/" ++ rand_name() ++ ".jpg",
    UploadBin = binary:copy(<<1>>, 100),
    %% upload
    {ok, PutRaw} = erldrop:files_put(Path, UploadBin, [], Ctx),
    Put = json_to_proplist(PutRaw),
    ?assertEqual(100,          getv(<<"bytes">>, Put)),
    ?assertEqual(Path,         b2l(getv(<<"path">>, Put))),
    ?assertEqual(false,        getv(<<"is_dir">>, Put)),
    ?assertEqual("image/jpeg", b2l(getv(<<"mime_type">>, Put))),
    % download
    {ok, MetadataRaw, DownloadBin} = erldrop:files_get(Path, [], Ctx),
    Metadata = json_to_proplist(MetadataRaw),
    ?assertEqual(100,          getv(<<"bytes">>, Metadata)),
    ?assertEqual(Path,         b2l(getv(<<"path">>, Metadata))),
    ?assertEqual("image/jpeg", b2l(getv(<<"mime_type">>, Metadata))),
    ?assertEqual(UploadBin, DownloadBin),
    %% cleanup
    {ok, _Deleted} = erldrop:fileops_delete(Path, [], Ctx),
    ok.

 restore_test() ->
    Ctx = mk_ctx(),
    Path = "/" ++ rand_name() ++ ".txt",
    %% upload a txt file
    OrigContent = <<"first line\n">>,
    {ok, ResRaw} = erldrop:files_put(Path, OrigContent, [], Ctx),
    Res = json_to_proplist(ResRaw),
    Rev = b2l(getv(<<"rev">>, Res)),
    %% upload new content to the same path
    NewContent = <<OrigContent/binary, "second line\n">>,
    {ok, PutRaw} = erldrop:files_put(Path, NewContent, [], Ctx),
    Put = json_to_proplist(PutRaw),
    NewRev = b2l(getv(<<"rev">>, Put)),
    ?assert(NewRev =/= Rev),
.    %% restore
    {ok, RestoredRaw} = erldrop:restore(Path, Rev, [], Ctx),
    Restored = json_to_proplist(RestoredRaw),
    RestoredRev = b2l(getv(<<"rev">>, Restored)),
    {ok,_,RestoredContent} = erldrop:files_get(Path, [{rev, RestoredRev}], Ctx),
    ?assertEqual(OrigContent, RestoredContent),
    %% cleanup
    {ok, _} = erldrop:fileops_delete(Path, [], Ctx),
    ok.

move_test() ->
    Ctx = mk_ctx(),
    Path = "/" ++ rand_name(),
    {ok, _} = erldrop:files_put(Path, <<1>>, [], Ctx),
    NewPath = Path ++ "2",
    {ok, _} = erldrop:fileops_move(Path, NewPath, [], Ctx),
    {error, 404, _} = erldrop:files_get(Path, [], Ctx),
    erldrop:fileops_delete(NewPath, [], Ctx),
    ok.

rand_name() -> [crypto:rand_uniform($a, $z) || _ <- lists:seq(1,10)].

mk_ctx() ->
    erldrop:file_to_ctx("priv/config").

getv(K, L) -> proplists:get_value(K, L).

b2l(B) -> binary_to_list(B).

json_to_proplist(Json) -> mochijson2:decode(Json, [{format, proplist}]).
