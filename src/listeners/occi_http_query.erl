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
	 content_types_provided/2,
	 content_types_accepted/2
	]).
-export([to_plain/2, 
	 to_occi/2,
	 to_uri_list/2,
	 to_json/2,
	 to_xml/2]).
-export([from_json/2]).

-include("occi.hrl").

-record(state, {}).

init(_Transport, _Req, []) -> 
    {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Opts) ->
    Req1 = occi_http:set_cors(Req),
    {ok, Req1, #state{}}.

allowed_methods(Req, Ctx) ->
    {[<<"HEAD">>, <<"GET">>, <<"DELETE">>, <<"POST">>, <<"OPTIONS">>], Req, Ctx}.

content_types_provided(Req, Ctx) ->
    {[
      {{<<"text">>,          <<"plain">>,     []}, to_plain},
      {{<<"text">>,          <<"occi">>,      []}, to_occi},
      {{<<"text">>,          <<"uri-list">>,  []}, to_uri_list},
      {{<<"application">>,   <<"occi+json">>, []}, to_json},
      {{<<"application">>,   <<"json">>,      []}, to_json},
      {{<<"application">>,   <<"xml">>,       []}, to_xml},
      {{<<"application">>,   <<"occi+xml">>,  []}, to_xml}
     ],
     Req, Ctx}.

content_types_accepted(Req, State) ->
    {[
      {{<<"application">>,     <<"json">>,      []}, from_json},
      {{<<"application">>,     <<"occi+json">>, []}, from_json}
     ],
     Req, State}.

to_plain(Req, Ctx) ->
    {K, M, A} = get_categories(),
    Body = occi_renderer_plain:render_capabilities(K, M, A),
    {Body, Req, Ctx}.

to_occi(Req, Ctx) ->
    {K, M, A} = get_categories(),
    Req2 = cowboy_req:set_resp_header(<<"category">>, 
				      occi_renderer_occi:render_capabilities(K, M, A), Req),
    Body = <<"OK\n">>,
    {Body, Req2, Ctx}.

to_uri_list(Req, Ctx) ->
    {K, M, A} = get_categories(),
    Body = [occi_renderer_uri_list:render_capabilities(K, M, A), "\n"],
    {Body, Req, Ctx}.

to_json(Req, Ctx) ->
    {K, M, A} = get_categories(),
    Body = [occi_renderer_json:render_capabilities(K, M, A), "\n"],
    {Body, Req, Ctx}.

to_xml(Req, Ctx) ->
    {K, M, A} = get_categories(),
    Body = [occi_renderer_xml:render_capabilities(K, M, A), "\n"],
    {Body, Req, Ctx}.

from_json(Req, State) ->
    {ok, Body, Req2} = cowboy_req:body(Req),
    case occi_parser_json:parse_user_mixin(Body) of
	{error, Reason} ->
	    lager:debug("Error processing request: ~p~n", [Reason]),
	    {true, cowboy_req:reply(400, Req2), State};
	{ok, undefined} ->
	    lager:debug("Empty request~n"),
	    {true, cowboy_req:reply(400, Req2), State};
	{ok, #occi_mixin{}=Mixin} ->
	    case occi_category_mgr:register_user_mixin(Mixin) of
		ok ->
		    RespBody = occi_renderer_json:render_mixin(Mixin),
		    {true, cowboy_req:set_resp_body([RespBody, "\n"], Req2), State};
		{error, Reason} ->
		    lager:debug("Error creating resource"),
		    throw({error, Reason})
	    end
    end.

%%%
%%% Private
%%%
get_categories() ->
    { occi_category_mgr:find(#occi_cid{scheme='_', term='_', class=kind}),
      occi_category_mgr:find(#occi_cid{scheme='_', term='_', class=mixin}),
      occi_category_mgr:find(#occi_cid{scheme='_', term='_', class=action}) }.
