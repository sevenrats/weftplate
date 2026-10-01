#!/usr/bin/env bash
# Flash the already-built weftplate firmware to a C6 on /dev/ttyACM0.
#   ./docker-flash.sh [PORT]   # default /dev/ttyACM0
set -euo pipefail
PORT="${1:-/dev/ttyACM0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="espressif/esp-matter:release-v1.5_idf_v5.4.1"
DIALOUT_GID="$(getent group dialout | cut -d: -f3)"
docker run --rm \
  --network host \
  --user "$(id -u):$(id -g)" \
  --group-add "$DIALOUT_GID" \
  -e HOME=/tmp \
  --device "$PORT" \
  -v "$HERE":/project \
  "$IMAGE" bash -lc "
    set -e
    . \$IDF_PATH/export.sh >/dev/null
    . \$ESP_MATTER_PATH/export.sh >/dev/null
    cd /project
    idf.py -p $PORT flash
  "
