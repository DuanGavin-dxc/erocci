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
%%% @doc use EEP1108 format ofr JSON internal representation
%%% http://www.erlang.org/eeps/eep-0018.html
%%%
%%% @end
%%% Created :  7 Oct 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_parser_xml).
-compile({parse_transform, lager_transform}).

-behaviour(gen_fsm).

-include("occi.hrl").
-include("occi_parser.hrl").
-include_lib("exmpp/include/exmpp_xml.hrl").

%% API
-export([load_extension/1,
	 parse_action/2,
	 parse_entity/2,
	 parse_user_mixin/1,
	 parse_collection/1]).

%% gen_fsm callbacks
-export([init/1, handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

%% States
-export([init/3, 
	 resource/3,
	 extension/3,
	 kind/3,
	 eof/3, 
	 attribute_spec/3,
	 mixin/3,
	 action_spec/3,
	 attr_type/3]).

-define(SERVER, ?MODULE).
-define(PARSER_OPTIONS,
	[{engine, expat},
	 {names_as_atom, true},
	 {check_nss, xmpp},
	 {check_elems, xmpp},
	 {emit_endtag, true},
	 {root_depth, none},
	 {max_size, infinity}]).

-record(state, {
	  request     = #occi_request{}     :: occi_request(),
	  collection                        :: occi_collection(),
	  entity      = undefined           :: term(),
	  entity_id   = undefined           :: uri(),
	  mixin       = undefined           :: term(),
	  action      = undefined           :: occi_action(),
	  prefixes,
	  extension                         :: occi_extension(),
	  kind                              :: occi_kind(),
	  attribute                         :: occi_attr(),
	  type}).

%%%===================================================================
%%% API
%%%===================================================================
load_extension(Path) ->
    {ok, Data} = file:read_file(Path),
    parse_extension(Data).

parse_extension(Data) ->
    case parse_full(Data, #state{}) of
	{ok, #occi_extension{}=Ext} ->
	    lager:info("Loaded extension: ~s~n", [occi_extension:get_name(Ext)]),
	    Ext;
	{error, Reason} ->
	    lager:error("Error loading extension: ~p~n", [Reason]),
	    {error, parse_error};
	_ ->
	    {error, {parse_error, not_an_extension}}
    end.

parse_action(Data, Action) ->
    case parse_full(Data, #state{action=Action}) of
	{error, Reason} ->
	    {error, {parse_error, Reason}};
	{ok, #occi_request{action=#occi_action{}=Action2}} ->
	    {ok, Action2};
	_ ->
	    {error, {parse_error, not_an_action}}
    end.    

parse_entity(Data, #occi_resource{}=Res) ->
    lager:debug("### DATA: ~p~n", [Data]),
    case parse_full(Data, #state{entity=Res}) of
	{error, Reason} ->
	    {error, {parse_error, Reason}};
	{ok, #occi_request{entities=[#occi_resource{}=Res2]}} ->
	    {ok, Res2};
	_ ->
	    {error, {parse_error, not_an_entity}}
    end;

parse_entity(Data, #occi_link{}=Link) ->
    case parse_full(Data, #state{entity=Link}) of
	{error, Reason} ->
	    {error, {parse_error, Reason}};
	{ok, #occi_request{entities=[#occi_link{}=Link2]}} ->
	    {ok, Link2};
	_ ->
	    {error, {parse_error, not_an_entity}}
    end;

parse_entity(Data, #occi_entity{id=Id}) ->
    case parse_full(Data, #state{entity_id=Id}) of
	{error, Reason} ->
	    {error, {parse_error, Reason}};
	{ok, #occi_request{entities=[#occi_resource{}=Res2]}} ->
	    {ok, Res2};
	{ok, #occi_request{entities=[#occi_link{}=Link2]}} ->
	    {ok, Link2};
	_ ->
	    {error, {parse_error, not_an_entity}}
    end.

parse_user_mixin(Data) ->
    case parse_full(Data) of
	{error, Reason} ->
	    {error, {parse_error, Reason}};
	{ok, #occi_request{mixins=[#occi_mixin{id=Id}=Mixin]}} ->
	    {ok, Mixin#occi_mixin{id=Id#occi_cid{class=usermixin}}};
	Err ->
	    lager:error("Invalid request: ~p~n", [Err]),
	    {error, {parse_error, Err}}
    end.

parse_collection(Data) ->
    case parse_full(Data) of
	{error, Reason} ->
	    {error, {parse_error, Reason}};
	{ok, #occi_request{collection=Coll}} ->
	    {ok, Coll}
    end.

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================
init(#parser{}=Parser) ->
    {ok, init, Parser#parser{stack=[init]}}.

-define(occi_ns, 'http://schemas.ogf.org/occi').
-define(xmlschema_ns, 'http://www.w3.org/2001/XMLSchema').

-define(extension, #xmlel{ns=?occi_ns, name=extension}).
-define(extensionEnd, #xmlendtag{ns=?occi_ns, name=extension}).

-define(resource, #xmlel{ns=?occi_ns, name=resource}).
-define(resourceEnd, #xmlendtag{ns=?occi_ns, name=resource}).

-define(categories, #xmlel{ns=?occi_ns, name=categories}).
-define(categoriesEnd, #xmlendtag{ns=?occi_ns, name=categories}).

-define(kind, #xmlel{ns=?occi_ns, name=kind}).
-define(kindEnd, #xmlendtag{ns=?occi_ns, name=kind}).

-define(mixin, #xmlel{ns=?occi_ns, name=mixin}).
-define(mixinEnd, #xmlendtag{ns=?occi_ns, name=mixin}).

-define(action, #xmlel{ns=?occi_ns, name=action}).
-define(actionEnd, #xmlendtag{ns=?occi_ns, name=action}).

-define(parent, #xmlel{ns=?occi_ns, name=parent}).
-define(parentEnd, #xmlendtag{ns=?occi_ns, name=parent}).

-define(depends, #xmlel{ns=?occi_ns, name=depends}).
-define(dependsEnd, #xmlendtag{ns=?occi_ns, name=depends}).

-define(applies, #xmlel{ns=?occi_ns, name=applies}).
-define(appliesEnd, #xmlendtag{ns=?occi_ns, name=applies}).

-define(attribute, #xmlel{ns=?occi_ns, name=attribute}).
-define(attributeEnd, #xmlendtag{ns=?occi_ns, name=attribute}).

-define(simpleType, #xmlel{ns=?xmlschema_ns, name=simpleType}).
-define(simpleTypeEnd, #xmlendtag{ns=?xmlschema_ns, name=simpleType}).

-define(simpleDef, #xmlel{ns=?xmlschema_ns}).
-define(simpleDefEnd, #xmlendtag{ns=?xmlschema_ns}).

init(E=?extension, _From, #parser{state=State}=Ctx) ->
    Ext = make_extension(E, State),
    push(extension, 
	 ?set_state(Ctx, State#state{extension=Ext, prefixes=load_prefixes(E#xmlel.declared_ns)}));
init(E=?resource, _From, #parser{state=State}=Ctx) ->
    case make_resource(E, State) of
	#state{}=State2 ->
	    push(resource, ?set_state(Ctx, State2#state{prefixes=load_prefixes(E#xmlel.declared_ns)}));
	{error, Err} ->
	    {reply, {error, Err}, eof, Ctx}
    end;
init(E, _From, Ctx) ->
    other_event(E, Ctx, init).

resource(E=?kind, _From, 
	 #parser{state=#state{entity=#occi_resource{cid=undefined}=Res}=State}=Ctx) ->
    case make_related(E, State) of
	{undefined, _} ->
	    {reply, {error, invalid_cid}, eof, Ctx};
	{_, undefined} ->
	    {reply, {error, invalid_cid}, eof, Ctx};
	{Scheme, Term} ->
	    Cid = #occi_cid{class=kind, scheme=Scheme, term=Term},
	    case catch occi_category_mgr:get(Cid) of
		{error, Err} ->
		    {reply, {error, Err}, eof, Ctx};
		#occi_kind{parent=#occi_cid{term=resource}}=Kind ->
		    Res2 = occi_resource:set_cid(Res, Kind),
		    {reply, ok, resource, ?set_state(Ctx, State#state{entity=Res2})};
		#occi_kind{} ->
		    {reply, {error, invalid_cid}, eof, Ctx}
	    end
    end;
resource(E=?kind, _From, 
	 #parser{state=#state{entity=#occi_resource{cid=#occi_cid{scheme=Scheme, term=Term, class=kind}}}=State}=Ctx) ->
    case make_related(E, State) of
	{undefined, _} ->
	    {reply, {error, invalid_cid}, eof, Ctx};
	{_, undefined} ->
	    {reply, {error, invalid_cid}, eof, Ctx};
	{Scheme, Term} ->
	    {reply, ok, resource, Ctx};
	_ ->
	    {reply, {error, invalid_cid}, eof, Ctx}
    end;
resource(?kindEnd, _From, Ctx) ->
    {reply, ok, resource, Ctx};
resource(E=?mixin, _From, 
	 #parser{state=#state{entity=#occi_resource{cid=undefined}=Res}=State}=Ctx) ->
    case make_related(E, State) of
	{undefined, _} ->
	    {reply, {error, invalid_cid}, eof, Ctx};
	{_, undefined} ->
	    {reply, {error, invalid_cid}, eof, Ctx};
	{Scheme, Term} ->
	    Cid = #occi_cid{class=mixin, scheme=Scheme, term=Term},
	    case catch occi_category_mgr:get(Cid) of
		{error, Err} ->
		    {reply, {error, Err}, eof, Ctx};
		#occi_mixin{}=Mixin ->
		    Res2 = occi_resource:add_mixin(Res, Mixin),
		    {reply, ok, resource, 
		     ?set_state(Ctx, State#state{entity=Res2})}
	    end
    end;
resource(?mixinEnd, _From, Ctx) ->
    {reply, ok, resource, Ctx};
resource(E=?attribute, _From, 
	 #parser{state=#state{entity=#occi_resource{}=Res}=State}=Ctx) ->
	case make_attribute(E, State) of
	    {ok, Key, Val} ->
		try occi_resource:set_attr_value(Res, Key, Val) of
		    #occi_resource{}=Res2 ->
			{reply, ok, resource,
			 ?set_state(Ctx, State#state{entity=Res2})}
		catch
		    Err ->
			{reply, {error, Err}, eof, Ctx}
		end;
	    {error, Err} ->
		{reply, {error, Err}, eof, Ctx}
	end;	
resource(?attributeEnd, _From, Ctx) ->
    {reply, ok, resource, Ctx};
resource(?resourceEnd, _From, #parser{state=#state{request=Req, entity=Res}}=Ctx) ->
    {reply, {eof, occi_request:add_entity(Req, Res)}, eof, Ctx};
resource(E, _From, Ctx) ->
    other_event(E, Ctx, resource).

extension(E=?kind, _From, #parser{state=State}=Ctx) ->
    Kind = make_kind(E, State),
    push(kind, ?set_state(Ctx, State#state{kind=Kind}));
extension(E=?mixin, _From, #parser{state=State}=Ctx) ->
    Mixin = make_mixin(E, State),
    push(mixin, ?set_state(Ctx, State#state{mixin=Mixin}));
extension(E=?simpleType, _From, #parser{state=State}=Ctx) ->
    Id = to_atom(get_attr_value(E, <<"name">>)),
    push(attr_type, ?set_state(Ctx, State#state{type=#occi_type{id=Id}}));
extension(?extensionEnd, _From, #parser{state=#state{extension=Ext}=State}=Ctx) ->
    {reply, {eof, Ext}, eof, ?set_state(Ctx, State#state{extension=undefined})};
extension(E, _From, Ctx) ->
    other_event(E, Ctx, extension).

kind(E=?parent, _From, #parser{state=#state{kind=Kind}=State}=Ctx) ->
    case catch make_related(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	{Scheme, Term} ->
	    {reply, ok, kind, 
	     ?set_state(Ctx, State#state{kind=occi_kind:set_parent(Kind, Scheme, Term)})}
    end;
kind(_E=?parentEnd, _From, Ctx) ->
    {reply, ok, kind, Ctx};
kind(E=?attribute, _From, #parser{state=State}=Ctx) ->
    case catch make_attr_spec(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	AttrSpec -> 
	    push(attribute_spec, 
		 ?set_state(Ctx, State#state{attribute=AttrSpec}))
    end;
kind(E=?action, _From, #parser{state=State}=Ctx) ->
    case catch make_action(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, State};
	Action ->
	    push(action_spec, 
		 ?set_state(Ctx, State#state{action=Action}))
    end;
kind(_E=?kindEnd, _From, #parser{state=#state{extension=Ext, kind=Kind}=State}=Ctx) ->
    pop(?set_state(Ctx, State#state{kind=undefined, 
				    extension=occi_extension:add_kind(Ext, Kind)}));
kind(E, _From, Ctx) ->
    other_event(E, Ctx, kind).

mixin(E=?depends, _From, #parser{state=#state{mixin=Mixin}=State}=Ctx) ->
    case catch make_related(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	{Scheme, Term} ->
	    {reply, ok, mixin, 
	     ?set_state(Ctx, State#state{mixin=occi_mixin:add_depends(Mixin, Scheme, Term)})}
    end;
mixin(_E=?dependsEnd, _From, Ctx) ->
    {reply, ok, mixin, Ctx};
mixin(E=?applies, _From, #parser{state=#state{mixin=Mixin}=State}=Ctx) ->
    case catch make_related(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	{Scheme, Term} ->
	    {reply, ok, mixin, 
	     ?set_state(Ctx, State#state{mixin=occi_mixin:add_applies(Mixin, Scheme, Term)})}
    end;
mixin(_E=?appliesEnd, _From, Ctx) ->
    {reply, ok, mixin, Ctx};
mixin(E=?attribute, _From, #parser{state=State}=Ctx) ->
    case catch make_attr_spec(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	Attr -> 
	    push(attribute_spec, 
		 ?set_state(Ctx, State#state{attribute=Attr}))
    end;
mixin(E=?action, _From, #parser{state=State}=Ctx) ->
    case catch make_action(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	Action ->
	    push(action_spec, ?set_state(Ctx, State#state{action=Action}))
    end;
mixin(_E=?mixinEnd, _From, #parser{state=#state{extension=Ext, mixin=Mixin}=State}=Ctx) ->
    pop(?set_state(Ctx, State#state{mixin=undefined,
				    extension=occi_extension:add_mixin(Ext, Mixin)}));
mixin(E, _From, Ctx) ->
    other_event(E, Ctx, mixin).

attribute_spec(_E=?attributeEnd, _From, 
	       #parser{stack=[_Cur,Prev|_Stack], state=#state{attribute=A}=State}=Ctx) ->
    case occi_attribute:get_type_id(A) of
	undefined ->
	    {reply, {error, {undefined_type, occi_attribute:get_id(A)}}, eof, Ctx};
	_ ->
	    State2 = case Prev of
			 kind -> 
			     Ref = State#state.kind,
			     State#state{kind=occi_kind:add_attribute(Ref, A)};
			 mixin -> 
			     Ref = State#state.mixin,
			     State#state{mixin=occi_mixin:add_attribute(Ref, A)};
			 action_spec -> 
			     Ref = State#state.action,
			     State#state{action=occi_action:add_attribute(Ref, A)}
		     end,
	    pop(?set_state(Ctx, State2#state{attribute=undefined}))
	end;
attribute_spec(_E=?simpleType, _From, #parser{state=State}=Ctx) ->
    push(attr_type, ?set_state(Ctx, State#state{type=#occi_type{}}));
attribute_spec(E, _From, Ctx) ->
    other_event(E, Ctx, attribute_spec).

action_spec(E=?attribute, _From, #parser{state=State}=Ctx) ->
    case catch make_attr_spec(E, State) of
	{error, Reason} ->
	    {reply, {error, Reason}, eof, Ctx};
	AttrSpec -> 
	    push(attribute_spec, ?set_state(Ctx, State#state{attribute=AttrSpec}))
    end;
action_spec(_E=?actionEnd, _From, 
	    #parser{stack=[_Cur,Prev|_Stack], state=#state{action=A}=State}=Ctx) ->
    State2 = case Prev of
		 kind -> 
		     State#state{kind=occi_kind:add_action(State#state.kind, A)};
		 mixin -> 
		     State#state{mixin=occi_mixin:add_action(State#state.mixin, A)}
	     end,
    pop(?set_state(Ctx, State2#state{action=undefined}));
action_spec(E, _From, Ctx) ->
    other_event(E, Ctx, action_spec).

attr_type(_E=?simpleTypeEnd, _From, 
	  #parser{stack=[_Cur,Prev|_Stack], state=#state{type=Type, extension=Ext}=State}=Ctx) ->
    case Prev of
	extension ->
	    Ext2 = occi_extension:add_type(Ext, Type),
	    pop(?set_state(Ctx, State#state{type=undefined, extension=Ext2}));
	attribute_spec ->
	    Attr = occi_attribute:set_type_id(State#state.attribute, 
					      get_attr_type(Type#occi_type.id)),
	    pop(?set_state(Ctx, State#state{type=undefined, attribute=Attr}))
    end;
attr_type(_E=?simpleDef, _From, Ctx) ->
    {reply, ok, attr_type, Ctx};
attr_type(_E=?simpleDefEnd, _From, Ctx) ->
    {reply, ok, attr_type, Ctx};
attr_type(E, _From, Ctx) ->
    other_event(E, Ctx, attr_type).

eof(_Event, _From, State) ->
    {reply, ok, eof, State}.

%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%-------------------------------------------------------------------
handle_event(stop, _, State) ->
    {stop, normal, State};
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%% @spec handle_info(Info,StateName,State)->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
    ok.

%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
parse_full(Data) ->
    parse_full(Data, #state{request=#occi_request{}}).

parse_full(<<>>, _) ->
    {error, invalid_request};
parse_full(Data, Ctx) ->
    P = start(Ctx),
    Res = parse(P, Data),
    stop(P),
    Res.

-spec parse(parser(), binary()) -> parser_result().
parse(#parser{src=#parser{id=Src}}=P, Data) ->
    Parser0 = #parser{sink=P},
    try exmpp_xml:parse_final(Src, Data) of
	done ->
	    send_events(Parser0, []);
	Events ->
	    send_events(Parser0, Events)
    catch
	Err ->
	    {error, Err}
    end.

start(Ctx) ->
    Parser = #parser{state=Ctx},
    case gen_fsm:start(?MODULE, Parser, []) of
	{ok, Ref} ->
	    Src = #parser{id=exmpp_xml:start_parser(?PARSER_OPTIONS)},
	    Parser#parser{id=Ref, src=Src};
	Err -> 
	    lager:error("Error starting xml parser: ~p~n", [Err])
    end.

stop(#parser{id=Ref, src=#parser{id=Src}}) ->
    exmpp_xml:stop_parser(Src),
    gen_fsm:send_all_state_event(Ref, stop).

send_events(_P, []) ->
    {error, {parse_error, incomplete}};
send_events(#parser{}=P, [E|T]) ->
    lager:debug("send_event: ~p~n", [lager:pr(E, ?MODULE)]),
    case occi_parser:send_event(E, ok, P) of
	{reply, {error, Err}, _, _} ->
	    {error, Err};
	ok ->
	    send_events(P, T);
	{reply, {eof, Result}, _, _} ->
	    {ok, Result}
    end.

get_attr_value(XmlEl, Name) ->
    case get_attr_value(XmlEl, Name, undefined) of
	undefined ->
	    throw({error, {einval, 
			   io_lib:format("Missing attribute: ~s", [Name])}});
	Val -> Val
    end.

get_attr_value(#xmlel{}=XmlEl, Name, Default) ->
    case exmpp_xml:get_attribute_node(XmlEl, Name) of
	undefined -> Default;
	Attr -> Attr#xmlattr.value
    end.

to_atom(Val) when is_binary(Val) ->
    list_to_atom(binary_to_list(Val));
to_atom(Val) when is_atom(Val) ->
    Val.

push(Next, #parser{stack=undefined}=Ctx) ->
    push(Next, Ctx#parser{stack=[]});
push(Next, #parser{stack=Stack}=Ctx) ->
    {reply, ok, Next, Ctx#parser{stack=[Next|Stack]}}.

pop(#parser{stack=[]}=Ctx) ->
    {reply, {error, stack_error}, eof, Ctx};
pop(#parser{stack=[_Cur,Previous|Stack]}=Ctx) ->
    {reply, ok, Previous, Ctx#parser{stack=[Previous|Stack]}}.

make_extension(E, _State) ->
    Name = to_atom(get_attr_value(E, <<"name">>, undefined)),
    Version = to_atom(get_attr_value(E, <<"version">>, undefined)),
    lager:info("Load extension: ~s v~s~n", [Name, Version]),
    occi_extension:new(Name, Version).

make_resource(E, #state{entity_id=undefined, entity=#occi_resource{id=undefined}=Res}=State) ->
    case get_attr_value(E, <<"id">>, undefined) of
	undefined ->
	    State;
	Id ->
	    State#state{entity=occi_resource:set_id(Res, Id)}
    end;
make_resource(E, #state{entity_id=undefined, entity=#occi_resource{id=Id}}=State) ->
    case get_attr_value(E, <<"id">>, undefined) of
	undefined ->
	    State;
	Id ->
	    State;
	_ ->
	    {error, invalid_id}
    end;
make_resource(E, #state{entity_id=Id}=State) ->
    case get_attr_value(E, <<"id">>, undefined) of
	undefined ->
	    State#state{entity_id=undefined, entity=occi_resource:new(Id)};
	Id ->
	    State#state{entity_id=undefined, entity=occi_resource:new(Id)};
	_ ->
	    {error, invalid_id}
    end.

make_kind(E, #state{extension=Ext}) ->
    Scheme = to_atom(get_attr_value(E, <<"scheme">>, Ext#occi_extension.scheme)),
    Term = to_atom(get_attr_value(E, <<"term">>)),
    lager:info("Load kind: ~s~s~n", [Scheme, Term]),
    Kind = occi_kind:new(Scheme, Term),
    Title = get_attr_value(E, <<"title">>, undefined),
    occi_kind:set_title(Kind, Title).

make_mixin(E, #state{extension=Ext}) ->
    Scheme = to_atom(get_attr_value(E, <<"scheme">>, Ext#occi_extension.scheme)),
    Term = to_atom(get_attr_value(E, <<"term">>)),
    lager:info("Load mixin: ~s~s~n", [Scheme, Term]),
    Mixin = occi_mixin:new(Scheme, Term),
    Title = get_attr_value(E, <<"title">>, undefined),
    occi_mixin:set_title(Mixin, Title).

make_attr_spec(E, State) ->
    Name = get_attr_value(E, <<"name">>),
    Type = get_attr_type(get_attr_value(E, <<"type">>, undefined), 
			 State),
    lager:debug("Load attribute spec: ~s~n", [Name]),
    Attr = occi_attribute:new(Name),
    Attr2 = occi_attribute:set_type_id(Attr, Type),
    Title = get_attr_value(E, <<"title">>, undefined),
    occi_attribute:set_title(Attr2, Title).

make_attribute(E, _State) ->
    case get_attr_value(E, <<"name">>, undefined) of
	undefined ->
	    {error, invalid_attribute};
	Name ->
	    case get_attr_value(E, <<"value">>, undefined) of
		undefined ->
		    {error, invalid_attribute};
		Val ->
		    {ok, to_atom(Name), Val}
	    end
    end.

make_action(E, _State) ->
    Scheme = to_atom(get_attr_value(E, <<"scheme">>)),
    Term = to_atom(get_attr_value(E, <<"term">>)),
    lager:debug("Load action spec: ~s~s~n", [Scheme, Term]),
    Action = occi_action:new(Scheme, Term),
    Title = get_attr_value(E, <<"title">>, undefined),
    occi_action:set_title(Action, Title).

make_related(E, _State) ->
    {to_atom(get_attr_value(E, <<"scheme">>)),
     to_atom(get_attr_value(E, <<"term">>))}.

% Return a dict with prefix->ns_as_atom key/value
-spec load_prefixes([{xmlname(), string()}]) -> term().
load_prefixes(NS) ->
    load_prefixes(NS, []).

load_prefixes([], Acc) ->
    dict:from_list(Acc);
load_prefixes([{Name, Prefix}|Tail], Acc) ->
    load_prefixes(Tail, [{Prefix, Name}|Acc]).

get_attr_type(undefined, _State) ->
    undefined;
get_attr_type(Type, #state{prefixes=P}) ->
    {Ns, Name} = resolve_ns(Type, P),
    get_attr_type({Ns, Name}).

resolve_ns(Bin, Dict) ->
    case string:tokens(binary_to_list(Bin), ":") of
	[Ns, Name] ->
	    case catch dict:fetch(Ns, Dict) of
		{badarg, _} ->
		    throw({error, {parse_error, unknown_ns}});
		Val ->
		    {Val, list_to_atom(Name)}
	    end;
	[_Name] ->
	    throw({error, {parse_error, unknown_ns}})
    end.

get_attr_type({?occi_ns, _}) ->
    string;
get_attr_type({?xmlschema_ns, integer}) ->
    integer;
get_attr_type({?xmlschema_ns, string}) ->
    string;
get_attr_type({?xmlschema_ns, float}) ->
    float;
get_attr_type({?xmlschema_ns, _}) ->
    string;
get_attr_type(undefined) ->
    string.

other_event(E, Ctx, StateName) ->
    case is_ws(E) of
	true ->
	    {reply, ok, StateName, Ctx};
	false ->
	    occi_parser:parse_error(E, Ctx)
    end.

is_ws(#xmlcdata{cdata = <<  "\n", Bin/binary >>}=E) ->
    is_ws(E#xmlcdata{cdata=Bin});
is_ws(#xmlcdata{cdata = <<  "\t", Bin/binary >>}=E) ->
    is_ws(E#xmlcdata{cdata=Bin});
is_ws(#xmlcdata{cdata = <<  " ", Bin/binary >>}=E) ->
    is_ws(E#xmlcdata{cdata=Bin});
is_ws(#xmlcdata{cdata = <<>>}) ->
    true;
is_ws(_) ->
    false.
