#!/bin/sh

PARAMS="
    path/str//
    prefix/str//ansible
    state/str//file
    suffix/str
"
# Note: suffix is ignored.

RESPONSE_VARS="path"

main() {
    local mktemp_cmd="mktemp"
    case "${state}" in
        file) : ;;
        directory) mktemp_cmd="${mktemp_cmd} -d" ;;
        *) fail "unknown state option";;
    esac
    if [ -z "${path}" ]; then
        path="/tmp"
    fi
    mktemp_cmd="${mktemp_cmd} -p ${path}"
    if [ -n "${prefix}" ]; then
        mktemp_cmd="${mktemp_cmd} ${prefix}XXXXXX"
    fi
    if [ -n "${_ansible_check_mode}" ]; then
        changed
        return
    fi
    # Run mktemp, directing stdout and stderr to different variables.
    {
        IFS=$'\n\027' read -r -d $'\027' stderr;
        IFS=$'\n\027' read -r -d $'\027' stdout;
    } <<EOF
$( (printf $'\027%s\027' "$(${mktemp_cmd})" 1>&2) 2>&1)
EOF
    # Return the result.
    if [ -z "${stdout}" ]; then
        unset path
        fail "${stderr}"
    fi
    changed
    path="${stdout}"
}
