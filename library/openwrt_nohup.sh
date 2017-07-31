#!/bin/sh
# Copyright (c) 2017 Markus Weippert
# GNU General Public License v3.0 (see https://www.gnu.org/licenses/gpl-3.0.txt)

PARAMS="command=cmd/str/r delay/int//0"
SUPPORTS_CHECK_MODE=""

main() {
    try /sbin/start-stop-daemon -Sbqp /dev/null -x /bin/sh -- -c \
        "sleep $delay; $command"
    changed
}
