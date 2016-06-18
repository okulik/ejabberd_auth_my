%%%----------------------------------------------------------------------
%%% File    : ejabberd_auth_my.erl
%%% Author  : Orest Kulik <orest@nisdom.com>
%%% Purpose : My Ejabberd authentication module using external HTTP services
%%% Created : 5 May 2016 by Orest Kulik <orest@nisdom.com>
%%%----------------------------------------------------------------------

-module(ejabberd_auth_my).
-author('orest@nisdom.com').

-behaviour(ejabberd_auth).

-behaviour(ejabberd_config).

-export([start/1,
         set_password/3,
         check_password/3,
         check_password/4,
         check_password/5,
         check_password/6,
         try_register/3,
         dirty_get_registered_users/0,
         get_vh_registered_users/1,
         get_vh_registered_users/2,
         get_vh_registered_users_number/1,
         get_vh_registered_users_number/2,
         get_password/2,
         get_password_s/2,
         is_user_exists/2,
         remove_user/2,
         remove_user/3,
         plain_password_required/0,
         store_type/0,
         login/2,
         get_password/3,
         opt_type/1,
         stop/1]).

-include("ejabberd.hrl").
-include("logger.hrl").

opt_type(my_auth_opts) -> fun (V) -> V end;
opt_type(_) -> [my_auth_opts].

-spec start(binary()) -> ok.
start(Host) ->
    AuthOpts = ejabberd_config:get_option({my_auth_opts, Host}, fun(V) -> V end),
    {_, AuthHost} = lists:keyfind(host, 1, AuthOpts),
    PoolSize = proplists:get_value(connection_pool_size, AuthOpts, 10),
    Opts = proplists:get_value(connection_opts, AuthOpts, []),
    ChildMods = [fusco],
    ChildMFA = {fusco, start_link, [binary_to_list(AuthHost), Opts]},
    ?DEBUG("ejabberd_auth_my started, using ~s", [AuthHost]),

    {ok, _} = supervisor:start_child(ejabberd_sup,
                                     {{ejabberd_auth_my_sup, Host},
                                      {cuesport, start_link,
                                       [pool_name(Host), PoolSize, ChildMods, ChildMFA]},
                                      transient, 2000, supervisor, [cuesport | ChildMods]}),
    ok.

check_password(LUser, _, LServer, LCookie) ->
    ?DEBUG("check_password/4 ~s ~s ~s", [LUser, LCookie, LServer]),
    case make_req_auth(LUser, LCookie, LServer) of
        {error, _} ->
            false;
        {ok, _} ->
            true
    end.

is_user_exists(LUser, LServer) ->
    ?DEBUG("is_user_exists/2", []),
    case make_req_user(LUser, LServer) of
        {ok, _} ->
            true;
        {error, _} ->
            false
    end.

plain_password_required() ->
    erlang:error(not_implemented).

store_type() ->
    erlang:error(not_implemented).

check_password(_LUser, _LServer, _Password) ->
    erlang:error(not_implemented).

check_password(_LUser, _LServer, _Password, _Digest, _DigestGen) ->
    erlang:error(not_implemented).

check_password(_LUser, _AuthzId, _LServer, _Password, _Digest, _DigestGen) ->
    erlang:error(not_implemented).

set_password(_LUser, _LServer, _Password) ->
    erlang:error(not_implemented).

try_register(_LUser, _LServer, _Password) ->
    erlang:error(not_implemented).

dirty_get_registered_users() ->
    erlang:error(not_implemented).

get_vh_registered_users(_Server) ->
    erlang:error(not_implemented).

get_vh_registered_users(_Server, _Opts) ->
    erlang:error(not_implemented).

get_vh_registered_users_number(_Server) ->
    erlang:error(not_implemented).

get_vh_registered_users_number(_Server, _Opts) ->
    erlang:error(not_implemented).

get_password(_LUser, _LServer) ->
    erlang:error(not_implemented).

get_password_s(_User, _Server) ->
    erlang:error(not_implemented).

remove_user(_LUser, _LServer) ->
    erlang:error(not_implemented).

remove_user(_LUser, _LServer, _Password) ->
    erlang:error(not_implemented).

login(_User, _Server) ->
    erlang:error(not_implemented).

get_password(_User, _Server, _DefaultValue) ->
    erlang:error(not_implemented).

stop(_Host) ->
    ok.

make_req_auth(LUser, LCookie, LServer) ->
    Path = <<"auth">>,
    AuthOpts = ejabberd_config:get_option({my_auth_opts, LServer}, fun(V) -> V end),
    PathPrefix = case lists:keyfind(path_prefix, 1, AuthOpts) of
                     {_, Prefix} -> Prefix;
                     false -> <<"/">>
                 end,
    LUserE = list_to_binary(http_uri:encode(binary_to_list(LUser))),
    CookieE = list_to_binary(http_uri:encode(binary_to_list(LCookie))),
    Query = <<"username=", LUserE/binary, "&password=", CookieE/binary>>,
    Header = [],
    Connection = cuesport:get_worker(existing_pool_name(LServer)),
    {ok, {{Code, _Reason}, _RespHeaders, RespBody, _, _}} = fusco:request(Connection, <<PathPrefix/binary, Path/binary, "?", Query/binary>>, "GET", Header, "", 2, 5000),
    error_code(Code, RespBody).

make_req_user(LUser, LServer) ->
    Path = <<"user">>,
    AuthOpts = ejabberd_config:get_option({my_auth_opts, LServer}, fun(V) -> V end),
    PathPrefix = case lists:keyfind(path_prefix, 1, AuthOpts) of
                     {_, Prefix} -> Prefix;
                     false -> <<"/">>
                 end,
    LUserE = list_to_binary(http_uri:encode(binary_to_list(LUser))),
    Query = <<"username=", LUserE/binary>>,
    Header = [],
    Connection = cuesport:get_worker(existing_pool_name(LServer)),
    {ok, {{Code, _Reason}, _RespHeaders, RespBody, _, _}} = fusco:request(Connection, <<PathPrefix/binary, Path/binary, "?", Query/binary>>, "GET", Header, "", 2, 5000),
    error_code(Code, RespBody).

error_code(Code, RespBody) ->
  case Code of
    <<"409">> -> {error, conflict};
    <<"404">> -> {error, not_found};
    <<"401">> -> {error, not_authorized};
    <<"403">> -> {error, not_allowed};
    <<"400">> -> {error, RespBody};
    <<"204">> -> {ok, <<"">>};
    <<"201">> -> {ok, created};
    <<"200">> -> {ok, RespBody}
  end.

pool_name(Host) ->
    list_to_atom("ejabberd_auth_my_" ++ binary_to_list(Host)).

existing_pool_name(Host) ->
    list_to_existing_atom("ejabberd_auth_my_" ++ binary_to_list(Host)).

