#!/usr/bin/env bash
# Flash the already-built weftplate firmware to a C6.
#   ./docker-flash.sh [PORT] [TRANSPORT]   # default /dev/ttyACM0, thread
#
# Flashes the image from build/<TRANSPORT>, as built by docker-build.sh.
set -euo pipefail
PORT="${1:-/dev/ttyACM0}"
TRANSPORT="${2:-thread}"
if ! [[ "$TRANSPORT" =~ ^(thread|wifi)$ ]]; then
  echo "error: transport must be thread or wifi (got '$TRANSPORT')" >&2; exit 1
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$HERE/build/$TRANSPORT/flasher_args.json" ]]; then
  echo "error: no $TRANSPORT build found; run ./docker-build.sh N $TRANSPORT first" >&2; exit 1
fi
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
    idf.py -B build/$TRANSPORT -p $PORT flash
  "
