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
    seperator=""
    echo '{"changed":false,"ansible_facts":{'
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
