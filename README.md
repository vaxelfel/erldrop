# Erlang Dropbox REST API v1 client

## Requirements
* Dropbox API key and secret

## Getting Access Tokens
gaining access to a dropbox accouunt///

    $ make start

	%% request request_token with your api credentials
	1> APIKey = "api".

	2> APISecret = "secret".

    3> {ok, ReqTokenRes} = erldrop:request_token(APIKey, APISecret).

	4> ReqToken = erldrop:token(ResTokenRes).

	5> ReqTokenSecret = erldrop:token_secret(ResTokenRes).

	%% open URL with browser to authorize access request
	6> {ok, URL} = erldrop:authorize(ReqToken, []).

	%% request access_token
	7> {ok, AccessTokenRes} = erldrop:access_token(APIKey, APISecret, ReqToken, ReqTokenSecret).

	8> AccessToken = erldrop:token(AccessTokenRes).

	9> AccessTokenSecret = erldrop:token_secret(AccessTokenRes).

	%% update config file with (priv/config)
	{api_key,          APIKey}.
	{api_secret,       APISecret}.
	{token,            AccessToken}.
	{token_secret,     AccessTokenSecret}.
	{root,             "sandbox"}. %% sandbox|dropbox depends on your API
	{signature_method, hmac_sha1}.
	{timeout,          infinity}.

## Example
Example usages.

**Note that the following examples will create side effects to your dropbox account.**

	1> Ctx = erldrop:file_to_ctx("priv/config").

	2> Content = <<1,2,3>>.

	%% upload
	3> {ok, _} = erldrop:files_put("/test.txt", Content, [], Ctx).

	%% download
	4> {ok, _, <<1,2,3>>} = erldrop:files_get("/test.txt", [], Ctx).

	%% create folder
	5> {ok, _} = erldrop:fileops_create_folder("/test_folder", [], Ctx).

Twitter [@vaxelfel](http://twitter.com/vaxelfel)

Email Shyun Yeoh <<vaxelfel@gmail.com>>
