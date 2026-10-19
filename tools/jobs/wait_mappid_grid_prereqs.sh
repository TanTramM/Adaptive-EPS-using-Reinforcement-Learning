#!/bin/bash
# Starts the MapPID grid only after the ordered PID and Map selections exist.
# Safe to launch once before leaving the machine unattended.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE="$REPO/scratch/jobs/mappid_grid_supervisor_status.txt"
LOCK="$REPO/scratch/jobs/mappid_grid_supervisor.lock"
PID_PICK="$REPO/Result/Controllers/PID/Calib_v2/PID_CALIB_pick_s10000.csv"
MAP_PICK="$REPO/Result/Controllers/Map/Calib_v2/Map_CALIB_pick_s00000.csv"

stamp() { date '+%Y-%m-%d %H:%M:%S'; }
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "$(stamp) already running or a stale lock exists: $LOCK" > "$STATE"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

while true; do
  if [ -f "$PID_PICK" ] && [ -f "$MAP_PICK" ]; then
    echo "$(stamp) prerequisites ready; starting mappid_grid_pipeline.sh" > "$STATE"
    "$SCRIPT_DIR/mappid_grid_pipeline.sh"
    rc=$?
    echo "$(stamp) mappid_grid_pipeline.sh exited with code $rc" > "$STATE"
    exit "$rc"
  fi
  echo "$(stamp) waiting: PID_pick=$([ -f "$PID_PICK" ] && echo ready || echo pending), Map_pick=$([ -f "$MAP_PICK" ] && echo ready || echo pending)" > "$STATE"
  sleep 60
done
