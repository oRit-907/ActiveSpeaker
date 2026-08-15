#!/usr/bin/env sh
#
# Runs the three specs. Needs lua5.4 and nothing else - the specs stub the
# natives themselves, so none of this needs a running FiveM server.
#
#   sh tests/run.sh
#
set -e

cd "$(dirname "$0")"

LUA="${LUA:-lua5.4}"

if ! command -v "$LUA" >/dev/null 2>&1; then
    echo "no $LUA on PATH - install lua5.4, or set LUA to your interpreter"
    exit 1
fi

status=0

for spec in config_spec.lua client_spec.lua server_spec.lua; do
    echo "--- $spec"

    if ! "$LUA" "$spec"; then
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    echo "\nall specs passed"
else
    echo "\nsome specs failed"
fi

exit "$status"
