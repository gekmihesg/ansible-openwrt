#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    backrefs/bool//false
    create/bool//false
    insertafter/str
    insertbefore/str
    line=value/str
    path=dest=destfile=name/str/r
    regex=regexp/str
    state/str//present
    $FILE_PARAMS
"
RESPONSE_VARS=""

escape_slash() {
    echo "$1" | sed -e 's|^/|\\/|;:a;s|\([^\]\(\\\\\)*\)/|\1\\/|g;ta;q'
}

escape_chars() {
    echo "$1" | sed 's|['"$2"'\]|\\&|g;q'
}

get_last_match() {
    echo "$2" | sed -nre "/$1/=" | sed '$!d'
}

save_changes() {
    [ -n "$_ansible_check_mode" -o -z "$CHANGED" ] ||
        echo "$1" > "$path" 2>/dev/null ||
        fail "path $path not writeable"
}

line_present() {
    local index old new mode tmp
    
    [ -f "$path" ] && {
        old="$(cat "$path")" || fail "path $path not readable"
    } || {
        [ -n "$create" ] || fail "path $path does not exist"
        [ -n "$_ansible_check_mode" ] ||
            mkdir -p "$(dirname "$path")"
        old=""
    }

    index="$(get_last_match "$line_match" "$old")"
    [ -n "$index" ] && {
        tmp="$(echo "$old" | sed -n "${index}{p;q}")"
        [ -z "$backrefs" ] || line="$(echo "$tmp" |
            sed -re "s/$line_match/$(escape_slash "$line")/")"
        [ "$tmp" = "$line" ] || {
            new="$(echo "$old" | sed "${index}c $(escape_chars "$line")")"
            changed
        }
    } || [ -n "$backrefs" ] || {
        [ -n "${insertafter#[EB]OF}" ] && {
            index="$(get_last_match "$(escape_slash "$insertafter")" "$old")"
            mode="a"
        } || [ -z "${insertbefore#BOF}" ] || {
            index="$(get_last_match "$(escape_slash "$insertbefore")" "$old")"
            mode="i"
        }
        [ -n "$index" ] && {
            new="$(echo "$old" | sed "$index$mode $(escape_chars "$line")")"
        } || {
            [ "$insertafter" = "BOF" -o "$insertbefore" = "BOF" ] &&
                new="$line$N$old" || {
                    tmp="$(echo "$old" | sed '${/^$/d}')"
                    new="$tmp${tmp:+$N}$line"
                }
        }
        changed
    }

    [ -z "$CHANGED" ] || {
        [ -z "$_ansible_diff" ] || set_diff "$old" "$new" "$path" "$path"
        [ -n "$_ansible_check_mode" ] || save_changes "$new"
    }
}

line_absent() {
    local index new old

    [ -f "$path" ] || return 0

    old="$(cat "$path")" || fail "path $path not readable"
    index="$(get_last_match "$line_match" "$old")"
    [ -z "$index" ] || {
        new="$(echo "$old" | sed -re "/$line_match/d")"
        changed
    }

    [ -z "$_ansible_diff" ] || set_diff "$old" "$new" "$path" "$path"
    [ -n "$_ansible_check_mode" -o -z "$CHANGED" ] || save_changes "$new"
}

main() {
    case "$state" in
        absent|present) :;;
        *) fail "state must be absent or present";;
    esac
    [ -n "$regex" ] &&
        line_match="$(escape_slash "$regex")" ||
        line_match="^$(escape_chars "$line" '/')\$"
    [ ! -d "$file" ] || fail "path $path is a directory"
    case "$state" in
        present)
            [ -z "$backrefs" -o -n "$regex" ] ||
                fail "regexp is required with backrefs"
            [ -n "$line" ] || fail "line is required with state present"
            line_present;;
        absent)
            [ -n "$line" -o -n "$regex" ] ||
                fail "line or regexp is required with state absent"
            line_absent;;
    esac
    set_file_attributes "$path" "" "y"
}
