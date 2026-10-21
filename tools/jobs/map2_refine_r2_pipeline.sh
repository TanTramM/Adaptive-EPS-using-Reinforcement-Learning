#!/bin/bash
# Second fine-grid pass of the Map (K, g_min) grid with the centre rule R2 (safe pairs only), requested by the user on 2026-10-21 (PhuongPhap_TimThamSo.txt 14.4).
# Why: the first pass used R1 (all gates, calib_margin not included), so every fine layer was centred on K 8-11 where all 22 pairs with e_rel <= 10 % fail calib_margin;
# the safe region (K 5.5 - 7.3) had the coarse grid only. Gates are NOT changed. Reuses every stored row (csv); needs the same worker count as the first pass.
# Usage: bash tools/jobs/map2_refine_r2_pipeline.sh [nWorkers=4]
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
export PATIENT_START_GB=3.5
NW=${1:-4}
MASTER="$S/map2r2_master_status.txt"; LOCK_DIR="$S/map2r2_pipeline.lock"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$MASTER"; }
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then mstat "NOT STARTED: another pipeline is active"; exit 0; fi
  rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true; mkdir "$LOCK_DIR" 2>/dev/null || exit 1
fi
echo "$$" > "$LOCK_DIR/pid"; trap 'rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

worker() { id=$1; run_job_patient "map2r2_w$id" "run_map2_grid($id,$NW,'R2'); disp('MAP2_GRID_WORKER_DONE')" "MAP2_GRID_WORKER_DONE\|MAP2_GRID_R3_STOP" || return 1; }
mstat "stage 1: fine layers with centre rule R2, $NW workers"
pids=""
for id in $(seq 1 "$NW"); do worker "$id" & pids="$pids $!"; [ -f "$S/map2r2_w${id}_done.txt" ] || sleep 60; done
wait $pids
for id in $(seq 1 "$NW"); do [ -f "$S/map2r2_w${id}_done.txt" ] || failed "worker $id"; done

mstat "stage 2: Pareto selection, five-seed report, map.json (previous map.json: Desktop/Adaptive-EPS_backup_2026-10-21_Map_truoc_grid2/map_after_first_select_R1.json)"
run_job_patient "map2r2_select" "select_map2_pareto(true); disp('MAP2_SELECT_DONE')" "MAP2_SELECT_DONE" || failed selection
mstat "stage 3: load_map and test_map"
run_job_patient "map2r2_test" "run('$REPO/Model/Controllers/Map/load_map.m'); test_map; disp('MAP2_TEST_DONE')" "MAP2_TEST_DONE" || failed test_map
mstat "ALL DONE (DREWS not run)"; echo done > "$S/map2r2_pipeline_done.txt"
