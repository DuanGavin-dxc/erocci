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

-module(occi_http_query).
-compile({parse_transform, lager_transform}).

-export([init/3, 
	 rest_init/2,
	 allowed_methods/2,
	 content_types_provided/2
	]).
-export([to_plain/2, to_occi/2, to_uri_list/2, to_json/2,
	 from_plain/2, from_occi/2, from_uri_list/2, from_json/2]).

-include("occi.hrl").

init(_Transport, _Req, []) -> 
    {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Opts) ->
    Req1 = occi_http:set_cors(Req),
    {ok, Req1, []}.

allowed_methods(Req, Ctx) ->
    {[<<"HEAD">>, <<"GET">>, <<"PUT">>, <<"DELETE">>, <<"POST">>, <<"OPTIONS">>], Req, Ctx}.

content_types_provided(Req, Ctx) ->
    {[
      {{<<"text">>,          <<"plain">>,     []}, to_plain},
      {{<<"text">>,          <<"occi">>,      []}, to_occi},
      {{<<"application">>,   <<"occi+json">>, []}, to_json},
      {{<<"application">>,   <<"json">>,      []}, to_json}
     ],
     Req, Ctx}.

to_plain(Req, Ctx) ->
    Categories = occi_category_mgr:get_categories(),
    Actions = occi_category_mgr:get_actions(),
    Body = occi_renderer_plain:render_capabilities(lists:flatten([Categories|Actions])),
    {Body, Req, Ctx}.

to_occi(Req, Ctx) ->
    Categories = lists:flatten(occi_category_mgr:get_categories(),
			       occi_category_mgr:get_actions()),
    Req2 = cowboy_req:set_resp_header(<<"category">>, 
				      occi_renderer_occi:render_capabilities(Categories), Req),
    Body = <<"OK\n">>,
    {Body, Req2, Ctx}.

to_uri_list(Req, Ctx) ->
    Categories = occi_category_mgr:get_categories(),
    Body = [occi_renderer_uri_list:render_capabilites(Categories), "\n"],
    {Body, Req, Ctx}.

to_json(Req, Ctx) ->
    Categories = occi_category_mgr:get_categories(),
    Body = [occi_renderer_json:render_capabilities(Categories), "\n"],
    {Body, Req, Ctx}.

from_plain(Req, Ctx) ->
    {ok, Req, Ctx}.

from_occi(Req, Ctx) ->
    {ok, Req, Ctx}.

from_uri_list(Req, Ctx) ->
    {ok, Req, Ctx}.

from_json(Req, Ctx) ->
    {ok, Req, Ctx}.
