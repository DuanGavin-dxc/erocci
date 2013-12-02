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
%%% Created : 19 Aug 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_extension).
-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").

-export([new/2,
	 get_name/1,
	 get_version/1,
	 get_categories/1,
	 get_kinds/1,
	 get_mixins/1,
	 get_actions/1,
	 add_kind/2,
	 add_mixin/2,
	 add_type/2,
	 check_types/1]).

new(Name, Version) ->
    #occi_extension{name=Name, 
		    version=Version,
		    kinds=[],
		    mixins=[],
		    types=dict:new()}.

get_name(#occi_extension{name=Name}) ->
    Name.

get_version(#occi_extension{version=Version}) ->
    Version.

get_categories(#occi_extension{}=Ext) ->
    lists:flatten([get_kinds(Ext), get_mixins(Ext), get_actions(Ext)]).

get_kinds(#occi_extension{kinds=Kinds}) ->
    Kinds.

get_mixins(#occi_extension{mixins=Mixins}) ->
    Mixins.

get_actions(#occi_extension{}=Ext) ->
    lists:flatten([
		   lists:map(fun (Kind) -> occi_kind:get_actions(Kind) end,
			     get_kinds(Ext)),
		   lists:map(fun (Mixin) -> occi_mixin:get_actions(Mixin) end,
			     get_mixins(Ext))
		  ]).

add_type(#occi_extension{types=Types}=Ext, #occi_type{id=Id}=Type) ->
    Ext#occi_extension{types=dict:store(Id, Type, Types)}.

add_kind(#occi_extension{kinds=Kinds}=Ext, Kind) ->
    Ext#occi_extension{kinds=[Kind|Kinds]}.

add_mixin(#occi_extension{mixins=Mixins}=Ext, Mixin) ->
    Ext#occi_extension{mixins=[Mixin|Mixins]}.

check_types(#occi_extension{types=Types}=Ext) ->
    lager:info("Check kind types"),
    Kinds = lists:map(fun (Kind) -> 
			      occi_kind:set_types_check(Kind, Types)
		      end, Ext#occi_extension.kinds),
    lager:info("Check mixin types"),
    Mixins = lists:map(fun (Mixin) ->
			       occi_mixin:set_types_check(Mixin, Types)
		       end, Ext#occi_extension.mixins),
    lager:info("Done checking types"),
    Ext#occi_extension{kinds=Kinds, mixins=Mixins}.
