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
-export([init/3, 
	 allowed_methods/2,
	 content_types_provided/2,
	 content_types_accepted/2]).
-export([to_plain/2, to_occi/2, to_uri_list/2, to_json/2,
	 from_plain/2, from_occi/2, from_uri_list/2, from_json/2]).

-include("occi.hrl").

init(_Transport, _Req, []) -> 
    {upgrade, protocol, cowboy_rest}.

allowed_methods(Req, Ctx) ->
    {[<<"HEAD">>, <<"GET">>, <<"PUT">>, <<"DELETE">>, <<"POST">>], Req, Ctx}.

content_types_provided(Req, Ctx) ->
    {[
      {<<"*/*">>, to_plain},
      {<<"text/plain">>, to_plain},
      {<<"text/occi">>, to_occi},
      {<<"text/uri-list">>, to_uri_list},
      {<<"application/occi+json">>, to_json}
     ],
     Req, Ctx}.

content_types_accepted(Req, Ctx) ->
    {[
      {<<"*/*">>, from_plain},      
      {<<"text/plain">>, from_plain},
      {<<"text/occi">>, from_occi},
      {<<"text/uri-list">>, from_uri_list},
      {<<"application/occi+json">>, from_json}
     ],
     Req, Ctx}.

to_plain(Req, Ctx) ->
    Categories = occi_store:get_categories(),
    Body = occi_renderer_plain:render(Categories),
    {Body, Req, Ctx}.

to_occi(Req, Ctx) ->
    Categories = occi_store:get_categories(),
    Req2 = cowboy_req:set_resp_header(<<"Category">>, occi_renderer_occi:render(Categories), Req),
    Body = <<"OK\n">>,
    {Body, Req2, Ctx}.

to_uri_list(Req, Ctx) ->
    Categories = occi_store:get_categories(),
    Body = [occi_renderer_uri_list:render(Categories), "\n"],
    {Body, Req, Ctx}.

to_json(Req, Ctx) ->
    Categories = occi_store:get_categories(),
    Body = [occi_renderer_json:render(Categories), "\n"],
    {Body, Req, Ctx}.

from_plain(Req, Ctx) ->
    {ok, Req, Ctx}.

from_occi(Req, Ctx) ->
    {ok, Req, Ctx}.

from_uri_list(Req, Ctx) ->
    {ok, Req, Ctx}.

from_json(Req, Ctx) ->
    {ok, Req, Ctx}.
