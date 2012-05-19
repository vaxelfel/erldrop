%% -*- erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ts=4 sw=4 et

%% erldrop: dropbox REST API v1 client
%%
%% The MIT License
%%
%% Copyright (c) 2012 Shyun Yeoh <vaxelfel@gmail.com>
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%% -------------------------------------------------------------------

%% @doc
%% Dropbox REST API v1 erlang client.
%%
%% == Function Convention ==
%% <ul>
%% <li> Every REST API endpoint has a corresponding underscore joined erlang
%% function, e.g. /account/info => account_info. </li>
%% <li>Visit <a href="https://www.dropbox.com/developers/reference/api">
%% Dropbox REST API</a> for detailed documentation. </li>
%% <li >Required parameters for an API call are implemented as function
%% parameters while optional ones are passed in as key-value list. </li>
%% </ul>
%%

-module(erldrop).

%% Authentication
-export([request_token/2, request_token/3,
         authorize/1, authorize/2,
         access_token/4]).

%% Dropbox Accounts
-export([account_info/2]).

%% Files and Metadata
-export([files_get/3, files_put/4, metadata/3, delta/2, revisions/3,
         restore/4, search/4, shares/3, media/3, copy_ref/2, thumbnails/3]).

%% File Operations
-export([fileops_copy/4, fileops_create_folder/3, fileops_delete/3,
         fileops_move/4]).

%% Context Manipulation
-export([ctx_to_file/2, file_to_ctx/1]).

%% Util
-export([start_deps/0, token/1, token_secret/1]).

-define(API_URL,     "https://api.dropbox.com/1").
-define(CONTENT_URL, "https://api-content.dropbox.com/1").
-define(AUTH_URL,    "https://www.dropbox.com/1").

-ifdef(DEBUG).
-define(dbg(Hdr, X), io:format("=== ~p ===~n ~p~n", [Hdr, X])).
-else.
-define(dbg(_Hdr, _X), ok).
-endif.

-opaque ctx()            :: dict().
-type params()           :: [{atom(), number() | string()}].
-type http_status_code() :: integer().
-type json()             :: binary(). %% json response body
-type err_msg()          :: json().   %% error message returned by dropbox
-type data()             :: binary(). %% downloaded content
-type resp()             :: {ok, json()}
                          | {ok, json(), data()}
                          | {error, term()}
                          | {error, http_status_code(), err_msg()}.

%%%===================================================================
%%% Authentication API
%%%===================================================================
-spec request_token(ApiKey :: string(), ApiSecret :: string()) -> resp().
request_token(ApiKey, ApiSecret) ->
    request_token(ApiKey, ApiSecret, []).

-spec request_token(string(), string(), Options) -> resp() when
      Options :: [{timeout, infinity | pos_integer()}
               | {signature_method, hmac_sha1 | plaintext | hmac_rsa1}].
request_token(ApiKey, ApiSecret, Options) ->
    Proplist =
        [ {api_key, ApiKey}
        , {api_secret, ApiSecret}
        | Options],
    Ctx = proplist_to_ctx(Proplist),
    URL = url(?API_URL, ["oauth", "request_token"], []),
    post(URL, [], Ctx).

-spec authorize(string()) -> resp().
authorize(Token) -> authorize(Token, []).

-spec authorize(string(), Options) -> {ok, URL::string()} when
      Options :: [{oauth_callback, string()}
               | {locale, string()}].
authorize(Token, Options) ->
    Params = [{token, Token}| Options],
    {ok, url(?AUTH_URL, ["oauth", "authorize"], Params)}.

-spec access_token(ApiKey :: string(), ApiSecret :: string(), Token :: string(),
                   TokenSecret :: string()) -> resp().
access_token(ApiKey, ApiSecret, Token, TokenSecret) ->
    Proplist =
        [ {api_key, ApiKey}
        , {api_secret, ApiSecret}
        , {token, Token}
        , {token_secret, TokenSecret}
        ],
    Ctx = proplist_to_ctx(Proplist),
    URL = url(?API_URL, ["oauth", "access_token"], []),
    post(URL, [], Ctx).

%%%===================================================================
%%% Dropbox Accounts API
%%%===================================================================
-spec account_info(params(), ctx()) -> resp().
account_info(OptParams, Ctx) ->
    URL = url(?API_URL, ["account", "info"], OptParams),
    get(URL, OptParams, Ctx).

%%%===================================================================
%%% File And Metadata API
%%%===================================================================
-spec files_get(string(), params(), ctx()) -> resp().
files_get(Path, OptParams, Ctx) ->
    URL = url(?CONTENT_URL, ["files", root(Ctx), Path], OptParams),
    get(URL, OptParams, Ctx).

-spec files_put(string(), binary(), params(), ctx()) -> resp().
files_put(Path, Content, OptParams, Ctx) ->
    URL = url(?CONTENT_URL, ["files_put", root(Ctx), Path], OptParams),
    put(URL, OptParams, Content, Ctx).

-spec metadata(string(), params(), ctx()) -> resp().
metadata(Path, OptParams, Ctx) ->
    URL = url(?API_URL, ["metadata", root(Ctx), Path], OptParams),
    get(URL, OptParams, Ctx).

-spec delta(params(), ctx()) -> resp().
delta(OptParams, Ctx) ->
    URL = url(?API_URL, ["delta"], []),
    post(URL, OptParams, Ctx).

-spec revisions(string(), params(), ctx()) -> resp().
revisions(Path, OptParams, Ctx) ->
    URL = url(?API_URL, ["revisions", root(Ctx), Path], OptParams),
    get(URL, OptParams, Ctx).

-spec restore(string(), string(), params(), ctx()) -> resp().
restore(Path, Rev, OptParams, Ctx) ->
    Params = [{rev, Rev} | OptParams],
    URL = url(?API_URL, ["restore", root(Ctx), Path], []),
    post(URL, Params, Ctx).

-spec search(string(), string(), params(), ctx()) -> resp().
search(Path, Query, OptParams, Ctx) ->
    Params = [{'query', Query} | OptParams],
    URL = url(?API_URL, ["search", root(Ctx), Path], Params),
    get(URL, Params, Ctx).

-spec shares(string(), params(), ctx()) -> resp().
shares(Path, OptParams, Ctx) ->
    URL = url(?API_URL, ["shares", root(Ctx), Path], []),
    post(URL, OptParams, Ctx).

-spec media(string(), params(), ctx()) -> resp().
media(Path, OptParams, Ctx) ->
    URL = url(?API_URL, ["media", root(Ctx), Path], []),
    post(URL, OptParams, Ctx).

-spec copy_ref(string(), ctx()) -> resp().
copy_ref(Path, Ctx) ->
    URL = url(?API_URL, ["copy_ref", root(Ctx), Path], []),
    get(URL, [], Ctx).

-spec thumbnails(string(), params(), ctx()) -> resp().
thumbnails(Path, OptParams, Ctx) ->
    URL = url(?CONTENT_URL, ["thumbnails", root(Ctx), Path], OptParams),
    get(URL, OptParams, Ctx).

%%%===================================================================
%%% File Operations API
%%%===================================================================
-spec fileops_copy(string(), string(), params(), ctx()) -> resp().
fileops_copy(FromPath, ToPath, OptParams, Ctx) ->
    URL = url(?API_URL, ["fileops", "copy"], []),
    Params = [{root, root(Ctx)}, {from_path, FromPath},
              {to_path, ToPath}|OptParams],
    post(URL, Params, Ctx).

-spec fileops_create_folder(string(), params(), ctx()) -> resp().
fileops_create_folder(Path, OptParams, Ctx) ->
    URL = url(?API_URL, ["fileops", "create_folder"], []),
    Params = [{root, root(Ctx)}, {path, Path}|OptParams],
    post(URL, Params, Ctx).

-spec fileops_delete(string(), params(), ctx()) -> resp().
fileops_delete(Path, OptParams, Ctx) ->
    URL = url(?API_URL, ["fileops", "delete"], []),
    Params = [{root, root(Ctx)}, {path, Path} | OptParams],
    post(URL, Params, Ctx).

-spec fileops_move(string(), string(), params(), ctx()) -> resp().
fileops_move(FromPath, ToPath, OptParams, Ctx) ->
    URL = url(?API_URL, ["fileops", "move"], []),
    Params = [{root, root(Ctx)}, {from_path, FromPath},
              {to_path, ToPath} | OptParams],
    post(URL, Params, Ctx).

%%%===================================================================
%%% Context Manipulation API
%%%===================================================================
-spec file_to_ctx(string()) -> ctx().
%% @doc config file to context
file_to_ctx(File) ->
    proplist_to_ctx(file_consult(File)).

%% @doc save context to file
-spec ctx_to_file(ctx(), string()) -> ok.
ctx_to_file(Ctx, File) ->
    consult_write(ctx_to_list(Ctx), File).

%%%===================================================================
%%% Util
%%%===================================================================
start_deps() ->
    application:start(crypto),
    application:start(public_key),
    application:start(ssl),
    application:start(inets).

token(Res) -> oauth:token(oauth:uri_params_decode(b2l(Res))).

token_secret(Res) -> oauth:token_secret(oauth:uri_params_decode(b2l(Res))).

%%%===================================================================
%%% Internal
%%%==================================================================
%% helpers
proplist_to_ctx(Proplist) ->
    Specs = ctx_specs(),
    dict:from_list([ctx_tuple(Spec, Proplist) || Spec <- Specs]).

%% http request hanlding
post(URL, Params, Ctx) ->
    OAuthHdr = [oauth_header("POST", URL, Params, Ctx)],
    Body = oauth:uri_params_encode(Params),
    Req = {URL, OAuthHdr, "application/x-www-form-urlencoded", Body},
    req(post, Req, Ctx).

get(URL, Params, Ctx) ->
    OAuthHdr = [oauth_header("GET", URL, Params, Ctx)],
    Req = {URL, OAuthHdr},
    req(get, Req, Ctx).

put(URL, Params, Content, Ctx) ->
    OAuthHdr = [oauth_header("PUT", URL, Params, Ctx)],
    Req = {URL, OAuthHdr, "application/octet-stream", Content},
    req(put, Req, Ctx).

req(Method, Req, Ctx) ->
    Timeout = {timeout, ctx_fetch(timeout, Ctx)},
    HttpOptions = [{autoredirect, false}, Timeout],
    Resp = httpc:request(Method, Req, HttpOptions, [{body_format, binary}]),
    ?dbg(context, dict:to_list(Ctx)),
    ?dbg(request, Req),
    ?dbg(response, Resp),
    handle_resp(Resp).

oauth_header(Method, URL, Params, Ctx) ->
    SignedParams = sign(Method, URL, Params, Ctx),
    oauth:header(SignedParams).

sign(Method, URI, Params, Ctx) ->
    Consumer = consumer(Ctx),
    Token = ctx_fetch(token, Ctx),
    TokenSecret = ctx_fetch(token_secret, Ctx),
    oauth:sign(Method, URI, Params, Consumer, Token, TokenSecret).

handle_resp({ok, {{_HttpVsn, StatusCode, _Reason}, Hdrs, Body}}) ->
    case StatusCode of
        200  -> mk_ok_resp(Hdrs, Body);
        _    -> {error, StatusCode, Body}
    end;
handle_resp({error, Reason}) ->
    {error, Reason}.

mk_ok_resp(Hdrs, Body) ->
    case get_metadata(Hdrs) of
        undefined -> {ok, Body};
        Metadata  -> {ok, Metadata, Body}
    end.

get_metadata(Hdrs) ->
    getv("x-dropbox-metadata", Hdrs).

consumer(Ctx) ->
    [ApiKey, ApiSecret, SignMethod] =
        ctx_fetch([api_key, api_secret, signature_method], Ctx),
    {ApiKey, ApiSecret, SignMethod}.

url(Base, Paths, Params) ->
    oauth:uri(url_path(Base, Paths), Params).

url_path(Base, Paths0) ->
    Paths = lists:concat([string:tokens(P, "/") || P <- Paths0]),
    url_join([Base| [http_uri:encode(P) || P <- Paths]]).

url_join(Ps) -> string:join(Ps, "/").

root(Ctx) -> ctx_fetch(root, Ctx).

ctx_fetch(Keys, Ctx) when is_list(Keys) -> [ctx_fetch(K, Ctx) || K <- Keys];
ctx_fetch(Key, Ctx) ->
    case dict:find(Key, Ctx) of
        false -> error({invalid_ctx_key, Key});
        {ok, Value} -> Value
    end.

ctx_to_list(Ctx) -> dict:to_list(Ctx).

file_consult(File) ->
    {ok, Proplist} = file:consult(File),
    Proplist.

consult_write(Proplist, File) ->
    file:write_file(File, [io_lib:fwrite("~p.\n", [P]) || P <- Proplist]).

-spec getv(any(), list()) -> any().
getv(K, L) -> proplists:get_value(K, L).

-spec b2l(binary()) -> list().
b2l(B) -> binary_to_list(B).

-spec ctx_specs() -> [{KeyName      :: atom(),
                       IsRequired   :: boolean(),
                       DefaultValue :: any() | undefined,
                       VerifyFun    :: function()}].
ctx_specs() ->
    [ {api_key, true, undefined, fun erlang:is_list/1}
    , {api_secret, true, undefined, fun erlang:is_list/1}
    , {token, false, "", fun erlang:is_list/1}
    , {token_secret, false, "", fun erlang:is_list/1}
    , {root, false, "sandbox",
       fun(X) -> lists:member(X, ["sandbox", "dropbox"]) end}
    , {signature_method, false, hmac_sha1,
       fun(X) -> lists:member(X, [plaintext, hmac_sha1, rsa_sha1]) end}
    , {timeout, false, infinity,
       fun(X) -> X == infinity orelse (is_number(X) andalso X >= 0) end}
    ].

ctx_tuple(Spec = {Key, IsRequired, Default, _VerifyF}, Proplist) ->
    case lists:keysearch(Key, 1, Proplist) of
        {value, {Key, Value}} -> verify(Key, Value, Spec);
        false -> case IsRequired of
                     true   -> error({missing_config_key, Key});
                     false  -> {Key, Default}
                 end
    end.

verify(Key, Value, {_,_,_,VerifyF}) ->
    case VerifyF(Value) of
        true  -> {Key, Value};
        false -> error({ctx_type_error, Key})
    end.
