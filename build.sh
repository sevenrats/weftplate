#!/usr/bin/env bash
# Build the weftplate firmware for a given number of dry-contact loops (1-6).
#
#   ./build.sh [N]        # N = number of switches to expose (default 6)
#   ./build.sh 4 flash    # build for 4 loops, then flash + monitor
#
# Requires ESP-IDF + esp-matter exported in the shell (idf.py on PATH).
set -euo pipefail

N="${1:-6}"
ACTION="${2:-build}"

if ! [[ "$N" =~ ^[1-6]$ ]]; then
  echo "error: switch count must be 1-6 (got '$N')" >&2
  exit 1
fi

if ! command -v idf.py >/dev/null 2>&1; then
  echo "error: idf.py not found. Source ESP-IDF and esp-matter first:" >&2
  echo "  . \$IDF_PATH/export.sh && . \$ESP_MATTER_PATH/export.sh" >&2
  exit 1
fi

echo "Building weftplate for $N loop(s) on esp32c6..."
idf.py set-target esp32c6 >/dev/null

# Pass the loop count to the firmware as a CMake cache define (read in
# main/CMakeLists.txt). EXTRA_CPPFLAGS does not reliably reach the compile.
case "$ACTION" in
  build)  idf.py -D WEFTPLATE_NUM_LOOPS="$N" build ;;
  flash)  idf.py -D WEFTPLATE_NUM_LOOPS="$N" build flash monitor ;;
  *)      echo "unknown action '$ACTION' (use build|flash)" >&2; exit 1 ;;
esac
