#!/usr/bin/env bash
# Build weftplate inside the esp-matter Docker image.
#   ./docker-build.sh [N]   # N = loop count (default 6)
#
# Runs as the host user so build/ artifacts aren't root-owned, uses host
# networking so the component manager can fetch esp-matter's few managed deps
# (esp_delta_ota etc.) on first configure.
set -euo pipefail
N="${1:-6}"
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
    idf.py set-target esp32c6
    idf.py -D WEFTPLATE_NUM_LOOPS=$N build
  "
