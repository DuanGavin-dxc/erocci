%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%% @copyright 2013 Jean Parpaillon.
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

%% @doc occi startup code
-module(occi).
-author('Jean Parpaillon <jean.parpaillon@free.fr>').

-include("occi_log.hrl").

-export([start/0, 
	 stop/0,
	 config/1]).
-export([ensure_started/1,
	 ensure_all_started/1]).

%% @spec start() -> ok
%% @doc Start the occi server.
start() ->
    ?info("Starting erocci framework"),
    application:start(erocci_core).

%% @spec stop() -> ok
%% @doc Stop the occi server.
stop() ->
    ?info("Stopping erocci framework"),
    application:stop(erocci_core).

config(Cfg) ->
    occi_config:load(Cfg).

ensure_started(App) ->
    ensure_all_started(App).

ensure_all_started(App) ->
    case application:start(App) of
	ok ->
	    ok;
	{error, {already_started, App}} ->
	    ok;
	{error, {not_started, Dep}} ->
	    case ensure_all_started(Dep) of
		ok ->
		    ensure_all_started(App);
		{error, Err} ->
		    {error, Err}
	    end
    end.

