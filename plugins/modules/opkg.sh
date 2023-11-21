#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="
    name=pkg/str/r
    state/str//present
    force/str
    update_cache/bool
    autoremove/bool
    nodeps/bool
"

query_package() {
    [ -n "$(opkg status "$1")" ]
}

install_packages() {
    local _IFS pkg
    _IFS="$IFS"; IFS=","; set -- $name; IFS="$_IFS"
    for pkg; do
        ! query_package "$pkg" || continue
        [ -n "$_ansible_check_mode" ] || {
            try opkg install$force $nodeps "$pkg"
            query_package "$pkg" || fail "failed to install $pkg: $_result"
        }
        changed
    done
}

remove_packages() {
    local _IFS pkg
    _IFS="$IFS"; IFS=","; set -- $name; IFS="$_IFS"
    for pkg; do
        query_package "$pkg" || continue
        [ -n "$_ansible_check_mode" ] || {
            try opkg remove$force $autoremove $nodeps "$pkg"
            ! query_package "$pkg" || fail "failed to remove $pkg: $_result"
        }
        changed
    done
}

main() {
    case "$state" in
        present|installed|absent|removed) :;;
        *) fail "state must be present or absent";;
    esac
    [ -z "$force" ] || {
        case "$force" in
            depends|maintainer|reinstall|overwrite|downgrade|space) :;;
            postinstall|remove|checksum|removal-of-dependent-packages) :;;
            *) fail "unknown force option";;
        esac
        force=" --force-$force"
    }
    [ -z "$autoremove" ] || {
        autoremove=" --autoremove"
    }

    [ -z "$nodeps" ] || {
        nodeps=" --nodeps"
    }

    [ -z "$update_cache" -o -n "$_ansible_check_mode" ] || try opkg update
    case "$state" in
        present|installed) install_packages;;
        absent|removed) remove_packages;;
    esac
}
