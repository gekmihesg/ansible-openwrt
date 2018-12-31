#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    checksum_algorithm=checksum_algo=checksum/str//sha1
    get_checksum/bool//true
    get_md5/bool//true
    get_mime/bool//true
    path/str/r
"
RESPONSE_VARS="
    charset/str
    checksum/str
    ctime/int
    dev/int
    executable/bool
    exists/bool
    gid/int
    gr_name/str
    inode/int
    isblk/bool
    ischr/bool
    isdir/bool
    isfifo/bool
    isgid/bool
    islnk/bool
    isreg/bool
    issock/bool
    isuid/bool
    lnk_source/str
    md5/str
    mime_type/str
    mode/str
    mtime/int
    nlink/int
    pw_name/str
    readable/bool
    rgrp/bool
    roth/bool
    rusr/bool
    size/int
    uid/int
    wgrp/bool
    woth/bool
    writeable/bool
    wusr/bool
    xgrp/bool
    xoth/bool
    xusr/bool
"

init() {
    local var
    for var in $RESPONSE_VARS; do eval "${var%%/*}=\"\""; done
    RESPONSE_VARS="path/str $RESPONSE_VARS"
}

parse_priv() {
    local priv="$1"
    local part="$2"
    local octal="0"
    [ -z "${priv#-??}" ] || { eval "r$part=\"1\""; octal=$((octal + 4)); }
    [ -z "${priv#?-?}" ] || { eval "w$part=\"1\""; octal=$((octal + 2)); }
    [ -z "${priv#??[-ST]}" ] || { eval "x$part=\"1\""; octal=$((octal + 1)); }
    mode="$mode$octal"
    [ -z "${priv#??[-x]}" ] || high=$((high + high_mod))
    high_mod=$((high_mod / 2))
}

main() {
    local var privs _IFS tmp
    [ ! -h "$path" -o -z "$follow" ] || {
        lnk_source="$path"
        path="$(readlink -f "$path")" || :
    }
    [ -n "$path" -a -e "$path" -o -h "$path" ] || {
        exists="0"
        return 0
    }
    for var in $RESPONSE_VARS; do
        _IFS="$IFS"; IFS="/"; set -- $var; IFS="$_IFS"
        [ "${2#b}" = "$2" ] || eval "$1=\"0\""
    done
    exists="1"
    charset="unknown"
    mime_type="unknown"
    set -- $(ls -lid "$path")
    inode="$1"
    privs="$2"
    nlink="$3"
    pw_name="$4"
    gr_name="$5"
    size="$6"
    set -- $(ls -lidn "$path")
    uid="$4"
    gid="$5"
    [ ! -x "$path" ] || executable="1"
    [ ! -r "$path" ] || readable="1"
    [ ! -w "$path" ] || writeable="1"
    case "$privs" in
        d*) isdir="1";;
        l*) islnk="1";;
        s*) issock="1";;
        c*) ischr="1";;
        b*) isblk="1";;
        p*) isfifo="1";;
        -*)
            [ "$readable" != "1" ] || {
                [ -z "$get_md5" ] || md5="$(md5 "$path")"
                [ -z "$get_checksum" ] ||
                    checksum="$(dgst "$checksum_algorithm" "$path")" ||
                    [ "$checksum_algorithm" = "sha1" ] ||
                    fail "Could not hash file '$path' with algorithm '$checksum_algorithm'."
            }
            isreg="1";;
    esac
    mtime="$(date -r "$path" +%s)"
    ctime="$mtime"
    atime="$mtime"
    [ "$(id -u)" -ne "$uid" ] || isuid="1"
    [ "$(id -g)" -ne "$gid" ] || isgid="1"
    high="0"; high_mod=4
    privs="${privs#?}"; parse_priv "${privs%??????}" usr
    privs="${privs#???}"; parse_priv "${privs%???}" grp
    privs="${privs#???}"; parse_priv "$privs" oth
    mode="$high$mode"
}

cleanup() {
    json_set_namespace result
    json_add_object stat
    _exit_add_vars $RESPONSE_VARS
    json_close_object
    json_set_namespace params
    RESPONSE_VARS=""
}
