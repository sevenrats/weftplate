#!/usr/bin/env bash
# Build weftplate inside the esp-matter Docker image.
#   ./docker-build.sh [N] [TRANSPORT]   # N = loop count (default 6),
#                                       # TRANSPORT = thread|wifi (default thread)
#
# Output lands in build/<TRANSPORT>. Runs as the host user so build/ artifacts
# aren't root-owned, uses host networking so the component manager can fetch
# esp-matter's few managed deps (esp_delta_ota etc.) on first configure.
set -euo pipefail
N="${1:-6}"
TRANSPORT="${2:-thread}"
if ! [[ "$N" =~ ^[1-6]$ ]]; then
  echo "error: loop count must be 1-6 (got '$N')" >&2; exit 1
fi
if ! [[ "$TRANSPORT" =~ ^(thread|wifi)$ ]]; then
  echo "error: transport must be thread or wifi (got '$TRANSPORT')" >&2; exit 1
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="espressif/esp-matter:release-v1.5_idf_v5.4.1"
docker run --rm \
  --network host \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$HERE":/project \
  "$IMAGE" bash -lc "
    set -e
    . \$IDF_PATH/export.sh >/dev/null
    . \$ESP_MATTER_PATH/export.sh >/dev/null
    cd /project                       # export.sh cd's into esp-matter; come back
    idf.py -B build/$TRANSPORT -D IDF_TARGET=esp32c6 \
      -D WEFTPLATE_NUM_LOOPS=$N -D WEFTPLATE_TRANSPORT=$TRANSPORT build
  "
