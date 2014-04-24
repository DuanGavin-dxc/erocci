%%%-------------------------------------------------------------------
%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2014, Jean Parpaillon
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
%%% Created : 18 Mar 2014 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_https).
-compile({parse_transform, lager_transform}).

-behaviour(occi_listener).

%% occi_listener callbacks
-export([start_link/2,
	 terminate/2]).

start_link(Ref, Opts) ->
    lager:info("Starting HTTPS listener ~p~n", [Opts]),
    O2 = validate_cfg(Opts),
    occi_http_common:start(O2),
    cowboy:start_https(Ref, 100, validate_cfg(O2), [{env, [{dispatch, occi_http_common:get_dispatch()}]}]).

terminate(Ref, _Reason) ->
    occi_http_common:stop(),
    cowboy:stop_listener(Ref).

%%%
%%% Priv
%%%
validate_cfg(Opts) ->
    Address = proplists:get_value(ip, Opts, {0,0,0,0}),
    Port = proplists:get_value(port, Opts, 8443),
    case proplists:is_defined(cacertfile, Opts) of
	true -> ok;
	false -> throw({missing_opt, cacertfile}) 
    end,
    case proplists:is_defined(certfile, Opts) of
	true -> ok;
	false -> throw({missing_opt, certfile}) 
    end,
    case proplists:is_defined(keyfile, Opts) of
	true -> ok;
	false -> throw({missing_opt, keyfile}) 
    end,
    [{ip, Address}, {port, Port}, {scheme, https}] ++ Opts.
