#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    enabled/bool
    name/str/r
    pattern/str
    state/str
"
RESPONSE_VARS="name enabled state"

is_running() {
    [ -z "$pattern" ] || { pgrep -f "$pattern" >/dev/null 2>&1; return $?; }
    "$init_script" running >/dev/null 2>&1
}

is_enabled() {
    ! "$init_script" enabled >/dev/null 2>&1 || echo 1
}

set_enabled() {
    local status result
    status="$(is_enabled)"
    [ "$enabled" = "$status" ] || {
        changed
        [ -n "$_ansible_check_mode" ] || {
            [ -n "$enabled" ] && action="enable" || action="disable"
            result="$("$init_script" "$action" 2>&1)"
            status="$(is_enabled)"
            [ "$enabled" = "$status" ] ||
                fail "Unable to $action service $name: $result"
        }
    }
    case "$status" in
        1) enabled="yes";;
        *) enabled="no";;
    esac
}

set_state() {
    local action result running
    is_running && running="y" || running=""
    case "$state" in
        started) [ -n "$running" ] || action="start";;
        stopped) [ -z "$running" ] || action="stop";;
        restarted|reloaded) action="${state%ed}";;
        *) fail "Unknown action $action";;
    esac
    [ -z "$action" ] || {
        changed
        [ -n "$_ansible_check_mode" ] ||
            result="$("$init_script" "$action" 2>&1)" ||
            fail "Unable to $action service $name: $result"
    }
}

main() {
    init_script="/etc/init.d/$name"
    [ -f "$init_script" ] || fail "service $name does not exist"
    [ -z "$_orig_enabled" ] || set_enabled
    [ -z "$state" ] || set_state
}
