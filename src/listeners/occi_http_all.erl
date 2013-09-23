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
%% @doc Example webmachine_resource.

-module(occi_http_all).

%% REST Callbacks
-export([init/3, 
	 rest_init/2,
	 resource_exists/2,
	 allow_missing_post/2,
	 allowed_methods/2,
	 content_types_provided/2,
	 content_types_accepted/2]).

%% Callback callbacks
-export([to_plain/2, to_occi/2, to_uri_list/2, to_json/2,
	 from_json/2]).

-include("occi.hrl").

-record(state, {resource = undefined :: any()}).

init(_Transport, _Req, []) -> 
    {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Opts) ->
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"HEAD, GET, PUT, POST, OPTIONS, DELETE">>, Req),
    Req3 = case cowboy_req:header(<<"origin">>, Req1) of
	       {undefined, Req2} ->
		   Req2;
	       {Origin, Req2} ->
		   cowboy_req:set_resp_header(<<"access-control-allow-origin">>, Origin, Req2)
	   end,
    {ok, Req3, #state{}}.

allow_missing_post(_Req, _State) ->
    false.

allowed_methods(Req, State) ->
    {[<<"HEAD">>, <<"GET">>, <<"PUT">>, <<"DELETE">>, <<"POST">>], Req, State}.

content_types_provided(Req, State) ->
    {[
      {{<<"text">>,          <<"plain">>,     []}, to_plain},
      {{<<"text">>,          <<"occi">>,      []}, to_occi},
      {{<<"text">>,          <<"uri-list">>,  []}, to_uri_list},
      {{<<"application">>,   <<"json">>,      []}, to_json},
      {{<<"application">>,   <<"occi+json">>, []}, to_json}
     ],
     Req, State}.

content_types_accepted(Req, State) ->
    {[
      {{<<"application">>, <<"json">>, []}, from_json},
      {{<<"application">>, <<"occi+json">>, []}, from_json}
     ],
     Req, State}.

resource_exists(Req, State) ->
    {Path, Req1} = cowboy_req:path_info(Req),
    case occi_store:is_valid_path(Path) of
	false ->
	    {false, Req1, State};
	{collection, Mod} ->
	    {true, Req1, State#state{resource={collection, Mod}}};
	{entity, Backend, ObjId} ->
	    {true, Req1, State#state{resource={entity, Backend, ObjId}}}
    end.

to_plain(Req, State) ->
    Body = case State#state.resource of
	       {collection, _Mod} ->
		   [];
	       {entity, _Backend, _ObjId} ->
		   <<"OK">>
	   end,
    {Body, Req, State}.

to_occi(Req, State) ->
    Req2 = case State#state.resource of
	       {category, Uri, Mod} ->
		   Type = occi_type:get_category(Uri, Mod),
		   cowboy_req:set_resp_header(<<"Category">>, occi_renderer_occi:render(Type), Req);
	       {entity, _Backend, _ObjId} ->
		   Req
	   end,
    {<<"OK\n">>, Req2, State}.

to_uri_list(Req, State) ->
    Obj = occi_store:load(State#state.resource),
    Body = [occi_renderer_uri_list:render(Obj), <<"\n">>],
    {Body, Req, State}.

to_json(Req, State) ->
    Obj = occi_store:load(State#state.resource),
    {occi_renderer_json:render(Obj), Req, State}.

from_json(Req, State) ->
    {ok, Req, State}.
