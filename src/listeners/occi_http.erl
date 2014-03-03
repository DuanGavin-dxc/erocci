%%%-------------------------------------------------------------------
%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2013, Jean Parpaillon
%%% 
%%% This file is provided to you under the Apache License,
%%% Version 2.0 (the "License"); you may not use this file
%%% except in compliance with the License.  You may obtain
%%% a copy of the License at
%%% 
%%%   http://www.apache.org/licenses/LICENSE-2.0
%%% 
%%% Unless required by applicable law or agreed to in writing,
%%% software distributed under the License is distributed on an
%%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%%% KIND, either express or implied.  See the License for the
%%% specific language governing permissions and limitations
%%% under the License.
%%% 
%%% @doc
%%%
%%% @end
%%% Created : 25 Mar 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_http).
-compile({parse_transform, lager_transform}).

-behaviour(occi_listener).

-include("occi.hrl").

-define(TBL, ?MODULE).

% API
-export([set_cors/2,
	 add_route/2]).

%% occi_listener callbacks
-export([start_link/2,
	 terminate/1]).

start_link(Ref, Opts) ->
    application:start(cowlib),
    application:start(crypto),
    application:start(ranch),
    application:start(cowboy),
    lager:info("Starting HTTP listener ~p~n", [Opts]),
    ?TBL = ets:new(?TBL, [set, public, {keypos, 1}, named_table]),
    ets:insert(?TBL, {routes, []}),
    cowboy:start_http(Ref, 100, validate_cfg(Opts), [{env, [{dispatch, get_dispatch()}]}]).

validate_cfg(Opts) ->
    Address = proplists:get_value(ip, Opts, {0,0,0,0}),
    Port = proplists:get_value(port, Opts, 8080),
    [{ip, Address}, {port, Port}].

terminate(Ref) ->
    ets:delete(?TBL),
    cowboy:stop_listener(Ref).

% Convenience function for setting CORS headers
set_cors(Req, Methods) ->
    case cowboy_req:header(<<"origin">>, Req) of
	{undefined, Req1} -> 
	    Req1;
	{Origin, Req1} ->
	    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, Methods, Req1),
	    cowboy_req:set_resp_header(<<"access-control-allow-origin">>, Origin, Req2)
    end.

-spec add_route(atom(), {binary(), atom(), list()}) -> ok | {error, term()}.
add_route(Ref, Route) ->
    Routes = ets:lookup_element(?TBL, routes, 2),
    ets:insert(?TBL, {routes, [Route | Routes]}),
    cowboy:set_env(Ref, dispatch, get_dispatch()).

%%%
%%% Private
%%%
-define(ROUTE_QUERY,   {<<"/-/">>,                          occi_http_query,    []}).
-define(ROUTE_QUERY2,  {<<"/.well-known/org/ogf/occi/-/">>, occi_http_query,    []}).
-define(ROUTE_OCCI,    {<<"/[...]">>,                       occi_http_handler,  []}).

get_dispatch() ->
    Routes = lists:flatten([?ROUTE_QUERY,
			    ?ROUTE_QUERY2,
			    ets:lookup_element(?TBL, routes, 2),
			    ?ROUTE_OCCI]),
    cowboy_router:compile([{'_', Routes}]).
