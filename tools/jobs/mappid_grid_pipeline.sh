#!/bin/bash
# MapPID alternating-block deterministic grid (PhuongPhap_TimThamSo.txt 13.5).
# Start only after the PID and Map grid selections exist. Safe to restart.
# Execution was handed to the laptop; the existing desktop prerequisite
# supervisor must not launch a second independent MapPID search.
if [ "${MAPPID_ALLOW_LEGACY_PIPELINE:-0}" != 1 ]; then
  echo 'MapPID handed to laptop: use tools/jobs/start_mappid_laptop.ps1 (see MAPPID_LAPTOP.md).'
  exit 0
fi
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
MASTER="$S/mappid_grid_master_status.txt"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$MASTER"; }
LOCK_DIR="$S/mappid_grid_pipeline.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    mstat "NOT STARTED: another MapPID grid pipeline is active (bash PID $lock_pid)"
    exit 0
  fi
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    mstat "NOT STARTED: could not acquire MapPID grid pipeline lock"
    exit 1
  fi
fi
echo "$$" > "$LOCK_DIR/pid"
trap 'rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

PID_PICK="$REPO/Result/Controllers/PID/Calib_v2/PID_CALIB_pick_s10000.csv"
MAP_PICK="$REPO/Result/Controllers/Map/Calib_v2/Map_CALIB_pick_s00000.csv"
[ -f "$PID_PICK" ] || failed "PID grid selection is not finished"
[ -f "$MAP_PICK" ] || failed "Map grid selection is not finished"

mstat "stage 0: reproduce one pre-grid MapPID evaluation"
run_job_patient "mappid_grid_check" "check_mappid_grid_eval; disp('MAPPID_GRID_CHECK_DONE')" "MAPPID_GRID_CHECK_DONE" || failed check

run_start() {
  start=$1
  pids=""
  for id in 1 2 3; do
    tag="mappid_grid_${start}_w${id}"
    run_job_patient "$tag" "run_mappid_grid('$start',$id,3); disp('MAPPID_GRID_WORKER_DONE')" "MAPPID_GRID_WORKER_DONE" &
    pids="$pids $!"
    sleep 150
  done
  wait $pids
  for id in 1 2 3; do [ -f "$S/mappid_grid_${start}_w${id}_done.txt" ] || return 1; done
}

mstat "stage 1: S1 alternating grid from selected PID"
run_start S1 || failed S1
mstat "stage 2: S2 alternating grid from selected Map"
run_start S2 || failed S2

mstat "stage 3: Pareto selection over S1 and S2, calib_margin, five-seed report"
run_job_patient "mappid_grid_select" "select_mappid_pareto(true); disp('MAPPID_GRID_SELECT_DONE')" "MAPPID_GRID_SELECT_DONE" || failed selection

# The user is redesigning DREWS.  Finish the deterministic grid/Pareto
# selection only; scoring must wait for the replacement suite.
mstat "stage 4: legacy MapPID DREWS skipped (new DREWS suite pending)"
mstat "ALL DONE (legacy DREWS skipped)"
echo done > "$S/mappid_grid_pipeline_done.txt"
