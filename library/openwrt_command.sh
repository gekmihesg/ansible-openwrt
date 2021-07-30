#!/bin/sh
# Copyright (c) 2021 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    cmd=raw_params=_raw_params/str/r
    uses_shell=_uses_shell/bool//false
    chdir/str
    executable/str
    creates/str
    removes/str
"
RESPONSE_VARS="
    start end delta cmd
    stdout/str/a stderr/str/a rc/int/a
"
SUPPORTS_CHECK_MODE=""

init() {
    stdout=""
    stderr=""
    start=""
    end=""
    delta=""
    rc="0"
    [ -n "$executable" ] || executable="/bin/sh"
    out="$(mktemp)" && err="$(mktemp)"
}

main() {
    local ts_start ts_end s_delta
    [ -z "$chdir" ] || try cd "$chdir"

    [ -z "$creates" ] || ! ls -d -- $creates >/dev/null 2>/dev/null || {
        stdout="skipped, since $creates exists"; exit 0
    }
    [ -z "$removes" ] || ls -d -- $removes >/dev/null 2>/dev/null || {
        stdout="skipped, since $removes does not exist"; exit 0
    }

    ts_start="$(date +%s)"
    [ -z "$uses_shell" ] && {
        $cmd >"$out" 2>"$err"; rc=$?; :
    } || {
        "$executable" -c "$cmd" >"$out" 2>"$err"; rc=$?; :
    }
    ts_end="$(date +%s)"
    s_delta=$((ts_end - ts_start))

    start="$(date -d "@$ts_start" "+%Y-%m-%d %H:%M:%S").000000"
    end="$(date -d "@$ts_end" "+%Y-%m-%d %H:%M:%S").000000"
    delta="$(printf "%d:%.2d:%.2d.000000" \
        $((delta / 3600)) $((delta % 3600 / 60)) $((delta % 60)))"
    stdout="$(cat "$out")"
    stderr="$(cat "$err")"
    changed
    test "$rc" -eq 0 || fail "non-zero return code"
    return 0
}

cleanup() {
    rm -f -- "$out" "$err"
}
