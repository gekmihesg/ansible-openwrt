#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    src=path/str/r
"
RESPONSE_VARS="source=src content encoding"

init() {
    content=""
    encoding=""
}

main() {
    [ -e "$src" ] || fail "file not found: $src"
    [ -r "$src" ] || fail "file not readable: $src"
    try base64 "$src"
    content="$_result"
    encoding="base64"
}
