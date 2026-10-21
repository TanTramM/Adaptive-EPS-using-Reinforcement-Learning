#!/bin/bash
# Two-variable Map grid (K, g_min) pipeline (PhuongPhap_TimThamSo.txt 14.8): check -> workers run_map2_grid -> select -> five-seed report -> load_map, test_map.
# Does NOT run DREWS (run_scoring_seeds): the user redesigns DREWS (2026-10-21). Resumable: finished stages leave scratch/jobs/map2_*_done.txt.
# Usage: bash tools/jobs/map2_grid_pipeline.sh [nWorkers=4]   (3 to 5; keep the same number when resuming: points are shared by index modulo nWorkers)
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
export PATIENT_START_GB=3.5       # RAM stays below about 90 % (guard_ram.ps1 stops the newest MATLAB below 10 % free)
NW=${1:-4}

MASTER="$S/map2_master_status.txt"
LOCK_DIR="$S/map2_pipeline.lock"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$MASTER"; }
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then mstat "NOT STARTED: another Map2 pipeline is active (bash PID $lock_pid)"; exit 0; fi
  rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true
  mkdir "$LOCK_DIR" 2>/dev/null || { mstat "NOT STARTED: could not acquire lock"; exit 1; }
fi
echo "$$" > "$LOCK_DIR/pid"
trap 'rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

mstat "stage 0: Map2 evaluation check (K 6.687, g_min 0.7071, to scratch only)"
run_job_patient "map2_check" "test_map2_grid(true); disp('MAP2_CHECK_DONE')" "MAP2_CHECK_DONE" || failed check

worker() {
  id=$1
  run_job_patient "map2_w$id" "run_map2_grid($id,$NW); disp('MAP2_GRID_WORKER_DONE')" "MAP2_GRID_WORKER_DONE\|MAP2_GRID_R3_STOP" || return 1
}
mstat "stage 1: Map2 grid, 169 coarse pairs plus at most six fine layers, $NW workers"
pids=""
for id in $(seq 1 "$NW"); do
  worker "$id" & pids="$pids $!"
  [ -f "$S/map2_w${id}_done.txt" ] || sleep 90
done
wait $pids
for id in $(seq 1 "$NW"); do [ -f "$S/map2_w${id}_done.txt" ] || failed "worker $id"; done
if grep -q "MAP2_GRID_R3_STOP" "$S"/map2_w*_try*.log 2>/dev/null; then
  mstat "STOPPED: case R3 (no pair passes the safety gates), see Result/Controllers/Map/Calib_v2/Grid2/Map_CALIB_grid2_R3_s00000.csv"; exit 3
fi

mstat "stage 2: Pareto selection, five-seed report, map.json (backup in Desktop/Adaptive-EPS_backup_2026-10-21_Map_truoc_grid2)"
run_job_patient "map2_select" "select_map2_pareto(true); disp('MAP2_SELECT_DONE')" "MAP2_SELECT_DONE" || failed selection

mstat "stage 3: load_map and test_map on the new map.json"
run_job_patient "map2_test" "run('$REPO/Model/Controllers/Map/load_map.m'); test_map; disp('MAP2_TEST_DONE')" "MAP2_TEST_DONE" || failed test_map

mstat "ALL DONE (DREWS not run)"
echo done > "$S/map2_pipeline_done.txt"
