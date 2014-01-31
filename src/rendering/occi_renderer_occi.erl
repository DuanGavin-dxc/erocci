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
%%% Created : 18 Mar 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_renderer_occi).
-compile({parse_transform, lager_transform}).

-behaviour(occi_renderer).

-include("occi.hrl").

%% API
-export([render/1]).

%%%===================================================================
%%% API
%%%===================================================================
render(#occi_node{type=occi_query, data={Kinds, Mixins, Actions}}) ->
    occi_renderer:join(
      lists:map(fun (Cat) ->
			occi_renderer_text:render(Cat, "")
		end, Kinds ++ Mixins ++ Actions),
      <<", ">>);

render(#occi_node{type=occi_collection, data=Coll}) ->
    occi_renderer:join([ occi_uri:to_iolist(Id) || Id <- occi_collection:get_entities(Coll) ], <<", ">>).
