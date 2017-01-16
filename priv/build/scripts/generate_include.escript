#!/usr/bin/env escript
%% -*- mode: erlang; erlang-indent-level: 4; indent-tabs-mode: nil -*-
%% -------------------------------------------------------------------
%%
%% Copyright (c) 2017 Basho Technologies, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%
% Based (very loosely) on priv/build/plugins/header_generator.erl from the
% upstream original. That one was a Rebar2 plugin, and made assumptions about
% the current directory and relative paths that all go out the window with
% Rebar3.
%
% This is a standalone escript, suitable for invocation as a post-compile shell
% hook in Rebar3. As such it doesn't have access to Rebar's functions, so it
% doesn't use mustache templating, and determines file paths from the location
% of the script and source beam at runtime.
%

%
% In Rebar3, LibDirs should be:
%   [
%       <project>/_checkouts/hamcrest
%       <project>/_build/<profile(s)>/lib/hamcrest
%   ]
% We'll use the first one that exists.
%
main(LibDirs) ->
    log(debug, "LibDirs = ~p~n", [LibDirs]),

    BeamSub = filename:join("ebin", "hamcrest_matchers.beam"),
    HInSub  = filename:join(["priv", "build", "templates", "hamcrest.hrl.src"]),
    HOutSub = filename:join("include", "hamcrest.hrl"),
    Require = [BeamSub, HInSub],

    LibDir = case find_lib_dir(LibDirs, Require) of
        false ->
            log(error,
                "Hamcrest directory not found, or required files missing: ~p~n",
                [Require]),
            erlang:halt(1);
        Dir ->
            log(debug, "LibDir = ~p~n", [Dir]),
            Dir
    end,
    Beam    = filename:join(LibDir, BeamSub),
    HeadIn  = filename:join(LibDir, HInSub),
    HeadOut = filename:join(LibDir, HOutSub),

    Update  = case filelib:last_modified(HeadOut) of
        0 ->
            true;
        HOutDT ->
            HOutTS  = calendar:datetime_to_gregorian_seconds(HOutDT),

            HOutTS < calendar:datetime_to_gregorian_seconds(filelib:last_modified(Beam))
            orelse
            HOutTS < calendar:datetime_to_gregorian_seconds(filelib:last_modified(HeadIn))
    end,
    RC = if
        Update ->
            catch do_update(HeadOut, Beam, HeadIn);
        true ->
            log(info, "~s is up to date.~n", [filename:basename(HeadOut)]),
            0
    end,
    erlang:halt(RC).

do_update(HeadOut, Beam, HeadIn) ->
    BeamMod = case filelib:ensure_dir(HeadOut) of
        ok ->
            case code:load_abs(filename:rootname(Beam)) of
                {module, Mod} ->
                    Mod;
                {error, LoadErr} ->
                    log(error, "~s: ~p~n", [Beam, LoadErr]),
                    erlang:throw(1)
            end;
        {error, DirErr} ->
            log(error, "~s: ~p~n", [HeadOut, file:format_error(DirErr)]),
            erlang:throw(1)
    end,
    Exports = lists:filter(
        fun({module_info, _}) ->
                false;
            (_) ->
                true
        end, BeamMod:module_info(exports)),
    Imports = [io_lib:format("~s/~b", [F, A]) || {F, A} <- lists:sort(Exports)],

    case file:read_file(HeadIn) of
        {ok, HSrcBin} ->
            HOutData = io_lib:format("~s-import(~s, [~n    ~s~n]).~n",
                [HSrcBin, BeamMod, string:join(Imports, ",\n    ")]),
            log(info, "Updating ~s~n", [filename:basename(HeadOut)]),
            case file:write_file(HeadOut, HOutData) of
                ok ->
                    0;
                {error, WErr} ->
                    log(error, "~s: ~p~n", [HeadOut, file:format_error(WErr)]),
                    1
            end;
        {error, RErr} ->
            log(error, "~s: ~p~n", [HeadIn, file:format_error(RErr)]),
            1
    end.

find_lib_dir([LibDir | LibDirs], Required) ->
    case check_lib_files(Required, LibDir) of
        true ->
            LibDir;
        _ ->
            find_lib_dir(LibDirs, Required)
    end;
find_lib_dir([], _) ->
    false.

check_lib_files([File | Files], LibDir) ->
    case filelib:is_regular(filename:join(LibDir, File)) of
        true ->
            check_lib_files(Files, LibDir);
        _ ->
            false
    end;
check_lib_files([], _) ->
    true.

%
% Try to look kind of like Rebar3, but I'm not bothering with colors.
%
log(error, Fmt, Args) ->
    io:format(standard_error, "===> Error: " ++ Fmt, Args);
log(warn, Fmt, Args) ->
    case os:getenv("QUIET") of
        false ->
            io:format(standard_error, "===> Warning: " ++ Fmt, Args);
        _ ->
            ok
    end;
log(info, Fmt, Args) ->
    case os:getenv("QUIET") of
        false ->
            io:format("===> " ++ Fmt, Args);
        _ ->
            ok
    end;
log(debug, Fmt, Args) ->
    case os:getenv("DEBUG") of
        false ->
            ok;
        _ ->
            io:format("===> " ++ Fmt, Args)
    end.
