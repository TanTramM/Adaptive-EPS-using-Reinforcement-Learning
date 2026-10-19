#!/bin/bash
# Map on CALIB v2 by PhuongPhap_TimThamSo.txt 13.2 (2026-10-18): check, three surrogateopt chains of 250 evaluations (e_max 10 %, no patternsearch), selection on seeds 1-5, DREWS on the scoring seeds 99995-99999.
# usage: bash tools/jobs/map_opt_pipeline.sh     (safe to start again at any time: finished stages are skipped, solvers resume from their checkpoint files)
# RAM: job_lib_patient.sh waits for 6 GB headroom before every MATLAB start and restarts a MATLAB stopped by guard_ram.ps1 (no limit); only a genuine MATLAB error stops it.
# Monitoring: scratch/jobs/map_master_status.txt (stage), scratch/jobs/map_*_status.txt (one line per job).
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
M="$S/map_master_status.txt"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$M"; }
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

mstat "stage 0: check of the evaluation (test_map_opt)"
run_job_patient "map_check" "test_map_opt; disp('MAP_CHECK_DONE')" "MAP_CHECK_DONE" || failed map_check

chain() { id=$1
  run_job_patient "map_o4_$id" "optimize_map($id, 250)" "optimize_map($id) DONE" || return 1
  echo chain_done > "$S/map_chain_$id.txt"; }
mstat "stage 1: search, three chains (each starts when memory allows)"
pids=""
for id in 1 2 3; do chain $id & pids="$pids $!"; sleep 150; done
wait $pids
for id in 1 2 3; do [ -f "$S/map_chain_$id.txt" ] || failed "chain $id"; done

mstat "stage 2: selection (20 best distinct designs, seeds 1-5, calib_margin)"
run_job_patient "map_o6" "select_map_multiseed(true); disp('SELECT_DONE')" "SELECT_DONE" || failed map_o6
mstat "stage 3: DREWS on seeds 99995-99999"
run_job_patient "map_o8" "evalin('base', 'run(''$REPO/Model/Controllers/Map/load_map.m'')'); run_scoring_seeds('Map', 99995:99999); disp('CASES_DONE')" "CASES_DONE" || failed map_o8
mstat "ALL DONE (check, search, selection, DREWS seeds 99995-99999)"
echo master_done > "$S/map_master_done.txt"
