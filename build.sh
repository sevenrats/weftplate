#!/usr/bin/env bash
# Build the weftplate firmware for a given number of dry-contact loops (1-6)
# and transport (thread or wifi).
#
#   ./build.sh [N] [TRANSPORT]     # N = number of switches (default 6),
#                                  # TRANSPORT = thread|wifi (default thread)
#   ./build.sh 4 wifi flash        # build for 4 loops over Wi-Fi, then flash + monitor
#
# Each transport builds into its own directory, build/<TRANSPORT>.
# Requires ESP-IDF + esp-matter exported in the shell (idf.py on PATH).
set -euo pipefail

N="${1:-6}"
TRANSPORT="${2:-thread}"
ACTION="${3:-build}"

if ! [[ "$N" =~ ^[1-6]$ ]]; then
  echo "error: switch count must be 1-6 (got '$N')" >&2
  exit 1
fi

if ! [[ "$TRANSPORT" =~ ^(thread|wifi)$ ]]; then
  echo "error: transport must be thread or wifi (got '$TRANSPORT')" >&2
  exit 1
fi

if ! command -v idf.py >/dev/null 2>&1; then
  echo "error: idf.py not found. Source ESP-IDF and esp-matter first:" >&2
  echo "  . \$IDF_PATH/export.sh && . \$ESP_MATTER_PATH/export.sh" >&2
  exit 1
fi

echo "Building weftplate for $N loop(s) over $TRANSPORT on esp32c6..."

# Pass the loop count and transport as CMake cache defines (read in
# main/CMakeLists.txt and the top-level CMakeLists.txt). EXTRA_CPPFLAGS does not
# reliably reach the compile.
IDF=(idf.py -B "build/$TRANSPORT" -D IDF_TARGET=esp32c6
     -D WEFTPLATE_NUM_LOOPS="$N" -D WEFTPLATE_TRANSPORT="$TRANSPORT")
case "$ACTION" in
  build)  "${IDF[@]}" build ;;
  flash)  "${IDF[@]}" build flash monitor ;;
  *)      echo "unknown action '$ACTION' (use build|flash)" >&2; exit 1 ;;
esac
