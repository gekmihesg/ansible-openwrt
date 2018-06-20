#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

NO_EXIT_JSON="1"

add_ubus_fact() {
    set -- ${1//\// }
    local json="$($ubus call "$2" "$3" 2>/dev/null)" || return
    echo -n "$seperator\"$1\":$json"
    seperator=","
}

main() {
    ubus="/bin/ubus"
    seperator=","
    echo '{"changed":false,"ansible_facts":'
    dist="OpenWRT"
    dist_version="NA"
    dist_release="NA"
    test -f /etc/openwrt_release && {
        . /etc/openwrt_release
        dist="${DISTRIB_ID:-$dist}"
        dist_version="${DISTRIB_RELEASE:-$dist_version}"
        dist_release="${DISTRIB_CODENAME:-$dist_release}"
    } || test ! -f /etc/os-release || {
        . /etc/os-release
        dist="${NAME:-$dist}"
        dist_version="${VERSION_ID:-$dist_version}"
    }
    dist_major="${dist_version%%.*}"
    json_set_namespace facts
    json_init
    json_add_string ansible_distribution "$dist"
    json_add_string ansible_distribution_major_version "$dist_major"
    json_add_string ansible_distribution_release "$dist_release"
    json_add_string ansible_distribution_version "$dist_version"
    json_add_string ansible_os_family OpenWRT
    dist_facts="$(json_dump)"
    json_cleanup
    json_set_namespace result
    echo "${dist_facts%\}*}"
    for fact in \
            info/system/info \
            devices/network.device/status \
            services/service/list \
            board/system/board \
            wireless/network.wireless/status \
            ; do
        add_ubus_fact "openwrt_$fact"
    done
    echo "$seperator"'"openwrt_interfaces":{'
    seperator=""
    for net in $($ubus list); do
        [ "${net#network.interface.}" = "$net" ] ||
            add_ubus_fact "${net##*.}/$net/status"
    done
    echo '}}}'
}

[ -n "$_ANSIBLE_PARAMS" ] || main
