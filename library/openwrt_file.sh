#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    diff_peek/str
    force/bool//false
    original_basename/str
    path=dest=name/str/r
    recurse/bool//false
    src/str
    state/str
    $FILE_PARAMS
"
RESPONSE_VARS="state path appears_binary/bool"

init() {
    appears_binary=""
}

get_state() {
    local state
    state="$(ls -ld -- "$1" 2>/dev/null)" && {
            case "${state:0:1}" in
                l) state="link";;
                d) state="directory";;
                *) set -- $state; [ "$2" -gt 1 ] &&
                    state="hard" || state="file";;
            esac
            echo "$state"
        } || { echo "absent"; }
}

get_inode() {
    set -- $(ls -id -- "$1")
    echo "$1"
}

main() {
    [ -z "$diff_peek" ] || {
        appears_binary="0"
        hexdump -e '16/1 " %02x" " \n"' -c 8192 -- "$path" 2>/dev/null |
            grep -q " 00 " && appears_binary="1" || :
        exit 0
    }

    prev_state="$(get_state "$path")"
    [ -n "$state" ] ||
        case "$prev_state" in
            absent) [ -z "$recurse" ] && state="file" || state="directory";;
            *) state="$prev_state";;
        esac

    [ -n "$src" -o "$state" != "link" -a "$state" != "hard" ] || {
        [ "$state" != "link" -o -z "$follow" ] ||
            fail "src and dest are required for creating links"
        src="$(realpath "$path")"
    }

    [ "$state" = "link" -o "$state" = "absent" -o ! -d "$path" ] || {
        basename="$original_basename"
        [ -n "$basename" -o -z "$src" ] || basename="$(basename -- "$src")"
        [ -z "$basename" ] && path="$path/$basename"
    }

    [ -z "$recurse" -o "$state" = "directory" ] ||
        fail "recurse options requires state to be directory"

    [ "$state" = "$prev_state" ] && state_change="" || state_change="y"

    case "$state" in
        absent)
            [ ! -e "$path" ] || changed
            [ -n "$_ansible_check_mode" ] ||
                result="$(rm -rf -- "$path" 2>&1)" ||
                fail "removing failed: $result";;
        file)
            [ -z "$state_change" -o -z "$follow" -o "$prev_state" != "link" ] || {
                path="$(realpath "$path")"
                prev_state="$(get_state "$path")"
            }

            [ "$prev_state" = "file" -o "$prev_state" = "hard" ] ||
                fail "file ($path) is $prev_state, cannot continue"
            set_file_attributes "$path";;
        directory)
            [ -z "$follow" -o "$prev_state" != "link" ] || {
                path="$(realpath "$path")"
                prev_state="$(get_state "$path")"
            }

            [ -e "$path" ] || changed
            case "$prev_state" in
                absent)
                    [ -n "$_ansible_check_mode" ] || {
                        oIFS="$IFS"; IFS="/"; set -- $path; IFS="$oIFS"
                        path=""
                        for p; do
                            [ -n "$p" ] || continue
                            path="$path/$p"
                            [ ! -e "$path" ] || continue
                            result="$(mkdir -p -- "$path" 2>&1)" ||
                                fail "error creating $path: $result"
                            changed
                            set_file_attributes "$path"
                        done
                    };;
                directory) set_file_attributes "$path" "$recurse";;
                *) fail "$path already exists as a $prev_state";;
            esac;;
        link|hard)
            is_abs "$src" && abssrc="$src" || {
                [ ! -h "$path" -a -d "$path" ] && abs="$path/$src" ||
                    abssrc="$(dirname "$path")/$src"
            }
            [ -e "$abssrc" ] && {
                [ ! -d "$abssrc" -o "$state" != "hard" ] ||
                    fail "src is a directory, cannot hard link $abssrc"
            } || {
                [ "$state" != "hard" ] ||
                    fail "src file does not exist, cannot hard link $abssrc"
                [ -n "$force" ] ||
                    fail "src file does not exist, use force=yes if you want to link $abssrc"
            }

            if [ "$prev_state" = "absent" ]; then
                changed
            elif [ "$prev_state" != "$state" -a -z "$force" ]; then
                fail "refusing to convert between $prev_state and $state for $path"
            elif [ "$prev_state" = "link" ]; then
                [ "$state" = "link" -a "$(readlink "$path")" = "$src" ] ||
                    changed
            elif [ "$prev_state" = "hard" ]; then
                [ "$state" = "hard" -a "$(get_inode "$path")" = "$(get_inode "$abssrc")" ] || {
                    [ -n "$force" ] ||
                        fail "cannot link, different hard link exists at destination"
                    changed
                }
            elif [ "$prev_state" = "directory" ]; then
                [ -z "$(find "$path" -mindepth 1 -maxdepth 1 2>/dev/null)" ] ||
                    fail "the directory $path is not empty refusing to convert it"
                changed
            else
                changed
            fi

            [ -n "$_ansible_check_mode" ] || {
                [ -z "$CHANGED" ] || {
                    [ "$state" = "hard" ] && flags="" || flags="-s"
                    [ "$prev_state" = "absent" ] ||
                        result="$(rm -rf -- "$path" 2>&1)" ||
                        fail "error replacing $path: $result"
                    result="$(ln $flags -- "$src" "$path" 2>&1)" ||
                        fail "error while linking $path to $src: $result"
                }
                set_file_attributes "$path"
            };;
        touch)
            [ -n "$follow" -a "$prev_state" = "link" ] || {
                path="$(realpath "$path")"
                [ -n "$_ansible_check_mode" ] || {
                    result="$(touch -- "$path" 2>&1)" ||
                        fail "error touching $path: $result"
                    set_file_attributes "$path"
                }
                changed
            };;
    esac
}
