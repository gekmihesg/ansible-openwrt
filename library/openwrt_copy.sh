#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    backup/bool
    dest/str/r
    directory_mode/str
    force=thirsty/bool//true
    original_basename=_original_basename/str
    src/str
    validate/str
    $FILE_PARAMS
"
RESPONSE_VARS="src dest md5sum=md5sum_src checksum backup_file"

init() {
    md5sum_src=""
    checksum=""
    backup_file=""
}

main() {
    local tmp _IFS
    [ -e "$src" ] || fail "Source $src not found"
    [ -r "$src" ] || fail "Source $src not readable"
    [ ! -d "$src" ] || fail "Remote copy does not support recursive copy of directory: $src"

    checksum_src="$(dgst sha1 "$src")" || :
    md5sum_src="$(md5 "$src")"
    md5sum_dest=""

    [ -z "$original_basename" -o "${dest%/}" = "$dest" ] || {
        dest="$dest/$original_basename"
        tmp="$(dirname -- "$dest")"
        [ -d "$tmp" ] || {
            _IFS="$IFS"; IFS="/"; set -- $tmp; IFS="$_IFS"
            tmp="$mode"; mode="$directoy_mode"
            local d
            local p=""
            for d; do
                [ -n "$d" ] || continue
                p="$p/$d"
                [ ! -d "$p" ] || continue
                try mkdir "$p"
                set_file_attributes "$p"
            done
            mode="$tmp"
        }
    }

    [ ! -d "$dest" ] || {
        dest="${dest%/}"
        [ -z "$original_basename" ] &&
            dest="$dest/$(basename -- "$src")" ||
            dest="$dest/$original_basename"
    }

    tmp="$(dirname -- "$dest")"
    [ -e "$dest" ] && {
        [ ! -h "$dest" -o -z "$follow" ] || dest="$(realpath "$dest")"
        [ -n "$force" ] || fail "file already exists"
        [ ! -r "$dest" ] || md5sum_dest="$(md5 "$dest")"
    } || [ -d "$tmp" ] || fail "Destination directory $tmp does not exist"
    [ -w "$tmp" ] || fail "Destination $tmp not writeable"

    [ "$md5sum_src" = "$md5sum_dest" -a ! -h "$dest" ] || {
        [ -n "$_ansible_check_mode" ] || {
            [ -z "$backup" ] || backup_file="$(backup_local "$dest")"
            [ ! -h "$dest" ] || { rm -f -- "$dest"; touch -- "$dest"; }
            [ -z "$validate" ] || {
                [ "${validate/%s/}" != "$validate" ] ||
                    fail "validate must contain %s: $validate"
                tmp="$($(printf "$validate" "$src") 2>&1)" ||
                    fail "failed to validate: $tmp"
            }
            try 'cat -- "$src" > "$dest"'
        }
        changed
    }

    [ -n "$_ansible_check_mode" ] || set_file_attributes "$dest"
}
