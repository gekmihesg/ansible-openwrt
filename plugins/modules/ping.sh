#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="data/any"
RESPONSE_VARS="ping data"

__exit() {
    [ -z "$NO_EXIT_JSON" ] || return $?
    echo -n "{\"ping\":\"$ping\""
    [ -z "$data" ] || echo -n ",\"data\":\"${data//\"/\\\"}\""
    echo "}"
}

main() {
    [ "$data" != "crash" ] ||
        { NO_EXIT_JSON="y"; echo "boom"; exit 1; }
    ping="pong"
}

[ -n "$_ANSIBLE_PARAMS" ] || {
    . "$1"
    trap __exit EXIT
    main
}
