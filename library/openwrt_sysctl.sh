#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    ignore_errors=ignoreerrors/bool
    name=key/str/r
    reload/bool//true
    state/str//present
    sysctl_file/str
    sysctl_set/bool//false
    value=val/str
"
RESPONSE_VARS="name value"

init() {
    sysctl="/sbin/sysctl"
    default_sysctl_file="/etc/sysctl.conf"
    tmp_file=""
}

sysctl_set() {
    local result
    [ "$(echo $($sysctl -n "$name"))" = "$value" ] || {
        changed
        [ -n "$_ansible_check_mode" ] ||
            result="$($sysctl -w "$name=$value" 2>/dev/null)" ||
            fail "failed to set $name to $value: $result"
    }
}

sysctl_write() {
    local found line v k
    tmp_file="$(mktemp)"
    while read line; do
        set -- $line
        [ -z "$1" -o "${1:0:1}" = "#" -o "${1/=/}" = "$1" ] || {
            k="${1%%=*}"
            [ "$k" != "$name" ] || {
                found="1"
                [ "$state" = "present" ] || { changed; continue; }
                v="${1#*=}"
                shift; while [ $# -ge 1 ]; do
                    [ "${1:0:1}" != "#" ] || break; v="$v $1"; shift
                done
                [ "$v" = "$value" ] || {
                    line="$k=$value${1:+ $*}"
                    changed
                }
            }
        }
        echo "$line" >> "$tmp_file"
    done < "$sysctl_file"
    [ "$state" != "present" -o -n "$found" ] || {
        echo "$name=$value" >> "$tmp_file"
        changed
    }
}

main() {
    local result
    [ -n "$sysctl_file" ] || sysctl_file="$default_sysctl_file"
    case "$state" in
        absent) :;;
        present)
            [ -n "$value" ] ||
                fail "value must be given with state present";;
        *) fail "state must be present or absent";;
    esac

    [ -w "$sysctl_file" ] || fail "sysctl file $sysctl_file not writeable"
    [ "$state" = "present" ] || ignore_errors="y"
    [ -n "$ignore_errors" -a -z "$sysctl_set" ] ||
        [ $($sysctl "$name" 2>/dev/null | wc -l) -eq 1 ] ||
        fail "unknown sysctl key $name"

    [ -z "$sysctl_set" ] || sysctl_set
    sysctl_write

    [ -z "$CHANGED" -o -n "$_ansible_check_mode" ] || {
        cat "$tmp_file" > "$sysctl_file"
        [ -z "$reload" -o "$state" != "present" ] ||
            result="$($sysctl -p "$sysctl_file" 2>&1)" ||
            fail "failed to reload: $result"
    }
}

cleanup() {
    [ -z "$tmp_file" ] || rm -f "$tmp_file"
}
