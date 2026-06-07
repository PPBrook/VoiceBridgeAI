#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")" && pwd)/build-app.sh" local "$@"
