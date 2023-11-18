#!/bin/bash

help() {
    echo "--- Help ---"
    echo "> DESC: utillty to help setup git hooks (branch & commit naming violation checks, incremental checkstyle, etc) for a java git repository"
    echo "> CMD: $0 <path to java git repository>"
    echo "> EX: $0 jzcommon-corelib" 
}

[[ -z "$1" ]] && help
[[ ! -d "$1" ]] && echo "> $1 is not exist or is not a directory" && help && exit 1
[[ ! -d "$1/.git" ]] && echo "> $1 is not a git repository" && help && exit 1

GIT_MISS_CONFIGURED_MSG="> WARN: this git repository may not be properly configured"
HOOK_SCRIPTS_PATH=$(dirname "$(readlink -f "$0")")/git-hooks
GIT_HOOKS_PATH="$1/.git/hooks"
[[ -f "$GIT_HOOKS_PATH" ]] && echo "> WTF: $1 is a file???" && echo "$GIT_MISS_CONFIGURED_MSG" && echo "--> EXIT" && exit 1
[[ ! -d "$GIT_HOOKS_PATH" ]] && echo "> WARN: $1/.git/hooks is not exist or is not a directory" && echo "$GIT_MISS_CONFIGURED_MSG" && echo "> WARN: create directory $GIT_HOOKS_PATH" && echo mkdir -p "$GIT_HOOKS_PATH"
chmod +x -R "$HOOK_SCRIPTS_PATH"
cp -v "$HOOK_SCRIPTS_PATH"/* "$GIT_HOOKS_PATH"
