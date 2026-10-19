#!/bin/bash
# Deterministic coarse-to-fine Map grid pipeline (PhuongPhap_TimThamSo.txt 13.4).
# Start only when the three-machine-wide MATLAB slots are free.
source "$(dirname "$BASH_SOURCE")/job_lib_patient.sh"

MASTER="$S/map_grid_master_status.txt"
RUN_LOCK="$S/map_grid_pipeline_running.txt"
LOCK_DIR="$S/map_grid_pipeline.lock"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$MASTER"; }

# mkdir is atomic.  The former RUN_LOCK write was only a heartbeat and allowed
# two complete pipelines to run concurrently against the same CSV files.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    mstat "NOT STARTED: another Map grid pipeline is active (bash PID $lock_pid)"
    exit 0
  fi
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    mstat "NOT STARTED: could not acquire Map grid pipeline lock"
    exit 1
  fi
fi
echo "$$" > "$LOCK_DIR/pid"
echo "$$ $(date '+%Y-%m-%d %H:%M:%S')" > "$RUN_LOCK"
trap 'rm -f "$RUN_LOCK" "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

mstat "stage 0: Map evaluation check"
run_job_patient "map_grid_check" "xr_o=map_opt_eval([6 33.50 17.9137313433 28.13 0.38],0,''); assert(abs(xr_o.PM-45.292)<0.1); disp('MAP_GRID_CHECK_DONE')" "MAP_GRID_CHECK_DONE" || failed check

worker() {
  id=$1
  run_job_patient "map_grid_w$id" "run_map_grid($id,3); disp('MAP_GRID_WORKER_DONE')" "MAP_GRID_WORKER_DONE" || return 1
}

mstat "stage 1: Map grid, 1024 coarse points plus at most six fine layers"
pids=""
for id in 1 2 3; do worker "$id" & pids="$pids $!"; sleep 150; done
wait $pids
for id in 1 2 3; do [ -f "$S/map_grid_w${id}_done.txt" ] || failed "worker $id"; done

mstat "stage 2: Pareto selection, calib_margin, and five-seed report"
run_job_patient "map_grid_select" "select_map_pareto(true); disp('MAP_GRID_SELECT_DONE')" "MAP_GRID_SELECT_DONE" || failed selection

# The legacy DREWS definition is being redesigned.  Keep the grid/Pareto
# result, but do not score it with the superseded suite.
mstat "stage 3: legacy Map DREWS skipped (user is designing a new DREWS suite)"
mstat "ALL DONE (legacy DREWS skipped)"
echo done > "$S/map_grid_pipeline_done.txt"
