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

-module(occi_http_handler).
-compile({parse_transform, lager_transform}).

-include("occi.hrl").

%% REST Callbacks
-export([init/3, 
	 rest_init/2,
	 allowed_methods/2,
	 allow_missing_post/2,
	 resource_exists/2,
	 delete_resource/2,
	 content_types_provided/2,
	 content_types_accepted/2]).

%% Callback callbacks
-export([to_uri_list/2,
	 to_json/2,
	 to_xml/2,
	 from_json/2]).

-record(content_type, {parser   :: atom(),
		       renderer :: atom(),
		       mimetype :: binary()}).

-define(ct_plain,    #content_type{parser=occi_parser_plain, renderer=occi_renderer_plain, 
				   mimetype="text/plain"}).
-define(ct_occi,     #content_type{parser=occi_parser_occi, renderer=occi_renderer_occi, 
				   mimetype="text/occi"}).
-define(ct_uri_list, #content_type{parser=occi_parser_uri_list, renderer=occi_renderer_uri_list, 
				   mimetype="text/uri-list"}).
-define(ct_json,     #content_type{parser=occi_parser_json, renderer=occi_renderer_json, 
				   mimetype="application/json"}).
-define(ct_xml,      #content_type{parser=occi_parser_xml, renderer=occi_renderer_xml, 
				   mimetype="application/xml"}).

init(_Transport, _Req, []) -> 
    {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Opts) ->
    {ok, cowboy_req:set_resp_header(<<"server">>, ?HTTP_SERVER_ID, Req), #occi_node{}}.

allowed_methods(Req, State) ->
    Methods = [<<"GET">>, <<"DELETE">>, <<"OPTIONS">>, <<"POST">>, <<"PUT">>],
    << ", ", Allow/binary >> = << << ", ", M/binary >> || M <- Methods >>,
    {Methods, occi_http:set_cors(Req, Allow), State}.

content_types_provided(Req, State) ->
    {[
      {{<<"text">>,            <<"uri-list">>,  []}, to_uri_list},
      {{<<"application">>,     <<"json">>,      []}, to_json},
      {{<<"application">>,     <<"occi+json">>, []}, to_json},
      {{<<"application">>,     <<"xml">>,       []}, to_xml},
      {{<<"application">>,     <<"occi+xml">>,  []}, to_xml}
     ],
     Req, State}.

content_types_accepted(Req, State) ->
    {[
      {{<<"application">>,     <<"json">>,      []}, from_json},
      {{<<"application">>,     <<"occi+json">>, []}, from_json}
     ],
     Req, State}.

allow_missing_post(Req, State) ->
    case cowboy_req:method(Req) of
	{<<"POST">>, _} ->
	    {false, Req, State};
	{<<"PUT">>, _} ->
	    {true, Req, State}
    end.

resource_exists(Req, State) ->
    {Path, _} = cowboy_req:path(Req),
    Id = occi_uri:parse(Path),
    case occi_store:find(#occi_node{id=#uri{path=Id#uri.path}, recursive=true, _='_'}) of
	{ok, []} ->
	    {false, Req, State};
	{ok, [#occi_node{type=occi_collection, objid=#occi_cid{class=kind}}=Node]} ->
	    case cowboy_req:method(Req) of
		{<<"PUT">>, _} ->
		    {ok, Req2} = cowboy_req:reply(405, Req),
		    {halt, Req2, State};
		{_, _} ->
		    lager:debug("Resource: ~p~n", [lager:pr(Node, ?MODULE)]),
		    {true, Req, Node}
	    end;
	{ok, [#occi_node{}=Node]} ->
	    lager:debug("Resource: ~p~n", [lager:pr(Node, ?MODULE)]),
	    {true, Req, Node}
    end.

delete_resource(Req, #occi_node{id=Id}=Node) ->
    case occi_store:delete(Node) of
	{error, undefined_backend} ->
	    lager:debug("Internal error deleting node: ~p~n", [lager:pr(Id, ?MODULE)]),
	    {ok, Req2} = cowboy_req:reply(500, Req),
	    {halt, Req2, Node};
	{error, Reason} ->
	    lager:debug("Error deleting node: ~p~n", [Reason]),
	    {false, Req, Node};
	ok ->
	    {true, Req, Node}
    end.
    
to_uri_list(Req, #occi_node{}=Node) ->
    render(Req, Node, ?ct_uri_list).

to_json(Req, #occi_node{}=Node) ->
    render(Req, Node, ?ct_json).

to_xml(Req, #occi_node{}=Node) ->
    render(Req, Node, ?ct_xml).

from_json(Req, #occi_node{type=occi_collection, objid=#occi_cid{class=kind}}=State) ->
    save_resource(Req, State, ?ct_json);

from_json(Req, #occi_node{type=occi_collection, objid=#occi_cid{class=mixin}}=State) ->
    case cowboy_req:method(Req) of
	{<<"PUT">>, _} ->
	    save_collection(Req, State, ?ct_json);
	{<<"POST">>, _} ->
	    update_collection(Req, State, ?ct_json)
    end;

from_json(Req, #occi_node{type=occi_resource}=State) ->
    update_resource(Req, State, ?ct_json);

from_json(Req, #occi_node{type=undefined}=State) ->
    save_resource(Req, State, ?ct_json).

%%%
%%% Private
%%%
render(Req, State, #content_type{renderer=Renderer}) ->
    case occi_store:load(State) of
	{ok, Node} ->
	    {[Renderer:render(Node), "\n"], Req, Node};
	{error, Err} ->
	    lager:error("Error loading object: ~p~n", [Err]),
	    {ok, Req2} = cowboy_req:reply(500, Req),
	    {halt, Req2, State}
    end.

save_resource(Req, State, #content_type{renderer=Renderer, parser=Parser, mimetype=MimeType}) ->
    {ok, Body, Req2} = cowboy_req:body(Req),
    case prepare_resource(Req, State) of
	#occi_resource{}=Res -> 
	    case Parser:parse_resource(Body, Res) of
		{error, {parse_error, Err}} ->
		    lager:debug("Error processing request: ~p~n", [Err]),
		    {ok, Req3} = cowboy_req:reply(400, Req2),
		    {false, Req3, State};
		{error, Err} ->
		    lager:debug("Internal error: ~p~n", [Err]),
		    {ok, Req3} = cowboy_req:reply(500, Req2),
		    {false, Req3, State};	    
		{ok, #occi_resource{}=Res2} ->
		    Node = create_resource_node(Req2, Res2),
		    case occi_store:save(Node) of
			ok ->
			    RespBody = Renderer:render(Node),
			    Req3 = cowboy_req:set_resp_header(<<"content-type">>, MimeType, Req2),
			    {true, cowboy_req:set_resp_body([RespBody, "\n"], Req3), State};
			{error, Reason} ->
			    lager:debug("Error creating resource: ~p~n", [Reason]),
			    {ok, Req3} = cowboy_req:reply(500, Req2),
			    {halt, Req3, State}
		    end
	    end;
	error ->
	    {ok, Req3} = cowboy_req:reply(409, Req2),
	    {halt, Req3, State}
    end.

update_resource(Req, State, #content_type{renderer=Renderer, parser=Parser, mimetype=MimeType}) ->
    {ok, Body, Req2} = cowboy_req:body(Req),
    case occi_store:load(State) of
	{ok, #occi_node{data=Res}=Node} ->
	    case Parser:parse_resource(Body, Res) of
		{error, {parse_error, Err}} ->
		    lager:debug("Error processing request: ~p~n", [Err]),
		    {ok, Req3} = cowboy_req:reply(400, Req2),
		    {false, Req3, State};
		{error, Err} ->
		    lager:debug("Internal error: ~p~n", [Err]),
		    {ok, Req3} = cowboy_req:reply(500, Req2),
		    {false, Req3, State};	    
		{ok, #occi_resource{}=Res2} ->
		    Node2 = occi_node:set_data(Node, Res2),
		    case occi_store:update(Node2) of
			ok ->
			    RespBody = Renderer:render(Node2),
			    Req3 = cowboy_req:set_resp_header(<<"content-type">>, MimeType, Req2),
			    {true, cowboy_req:set_resp_body([RespBody, "\n"], Req3), State};
			{error, Reason} ->
			    lager:debug("Error creating resource: ~p~n", [Reason]),
			    {ok, Req3} = cowboy_req:reply(500, Req2),
			    {halt, Req3, State}
		    end
	    end;	    
	{error, Err} ->
	    lager:error("Error loading object: ~p~n", [Err]),
	    {ok, Req2} = cowboy_req:reply(500, Req),
	    {halt, Req2, State}
    end.

save_collection(Req, #occi_node{objid=Cid}=State, #content_type{parser=Parser}) ->
    {ok, Body, Req2} = cowboy_req:body(Req),
    case Parser:parse_collection(Body) of
	{error, {parse_error, Err}} ->
	    lager:debug("Error processing request: ~p~n", [Err]),
	    {ok, Req3} = cowboy_req:reply(400, Req2),
	    {halt, Req3, State};
	{error, Err} ->
	    lager:debug("Internal error: ~p~n", [Err]),
	    {ok, Req3} = cowboy_req:reply(500, Req2),
	    {halt, Req3, State};	    
	{ok, #occi_collection{}=C} ->
	    Coll = occi_collection:new(Cid, occi_collection:get_entities(C)),
	    case occi_store:save(State#occi_node{type=occi_collection, data=Coll}) of
		ok ->
		    {true, Req, State};
		{error, {no_such_entity, Uri}} ->
		    lager:debug("Invalid entity: ~p~n", [occi_uri:to_string(Uri)]),
			    {false, Req2, State};
		{error, Reason} ->
		    lager:debug("Error saving collection: ~p~n", [Reason]),
		    {ok, Req3} = cowboy_req:reply(500, Req2),
		    {halt, Req3, State}
	    end
    end.

update_collection(Req, #occi_node{type=occi_collection, objid=Cid}=State, #content_type{parser=Parser}) ->
    {ok, Body, Req2} = cowboy_req:body(Req),
    case Parser:parse_collection(Body) of
	{error, {parse_error, Err}} ->
	    lager:debug("Error processing request: ~p~n", [Err]),
	    {ok, Req3} = cowboy_req:reply(400, Req2),
	    {halt, Req3, State};
	{error, Err} ->
	    lager:debug("Internal error: ~p~n", [Err]),
	    {ok, Req3} = cowboy_req:reply(500, Req2),
	    {halt, Req3, State};	    
	{ok, #occi_collection{}=C} ->
	    Coll = occi_collection:new(Cid, occi_collection:get_entities(C)),
	    Node = State#occi_node{type=occi_collection, data=Coll},
	    case occi_store:update(Node) of
		ok ->
		    {true, Req, State};
		{error, {no_such_entity, Uri}} ->
		    lager:debug("Invalid entity: ~p~n", [lager:pr(Uri, ?MODULE)]),
		    {false, Req2, State};
		{error, Reason} ->
		    lager:debug("Error updating collection: ~p~n", [Reason]),
		    {ok, Req3} = cowboy_req:reply(500, Req2),
		    {halt, Req3, State}
	    end
    end.

prepare_resource(_Req, #occi_node{type=occi_collection, objid=Cid}) ->
    Kind = occi_category_mgr:get(Cid),
    occi_resource:new(Kind);

prepare_resource(Req, #occi_node{type=undefined}) ->
    {Path, _} = cowboy_req:path(Req),
    Id = occi_uri:parse(Path),
    occi_resource:set_id(occi_resource:new(), occi_config:to_url(Id)).

create_resource_node(Req, #occi_resource{id=undefined}=Res) ->
    {Prefix, _} = cowboy_req:path(Req),
    Id = occi_config:gen_id(Prefix),
    occi_node:new(Id, occi_resource:set_id(Res, Id));
create_resource_node(_Req, #occi_resource{}=Res) ->
    occi_node:new(occi_resource:get_id(Res), Res).
