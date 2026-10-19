#!/bin/bash
# Deterministic coarse-to-fine grid pipeline (PhuongPhap_TimThamSo.txt 13).
# Usage: bash tools/jobs/grid_pipeline.sh PID [all|rest]
# PID: 4^4 = 256 coarse points, then at most six 3^4 fine layers; three
# resumable workers, Pareto selection, five-seed report, and DREWS scoring.
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
CTRL=${1:-PID}
PHASE=${2:-all}
if [ "$CTRL" != PID ]; then echo "grid_pipeline: controller $CTRL is not configured yet"; exit 2; fi

MASTER="$S/pid_grid_master_status.txt"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$MASTER"; }
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

if [ "$PHASE" = all ]; then
  mstat "stage 0: PID evaluation check"
  run_job_patient "pid_grid_check" "xr_o=pidlag_eval('PID',[1.365 52.09 0.04636 0.002882],10000,''); assert(abs(xr_o.R-5.386384)<1e-3); disp('PID_GRID_CHECK_DONE')" "PID_GRID_CHECK_DONE" || failed check

  worker() {
    id=$1
    run_job_patient "pid_grid_w$id" "run_pid_grid($id,3); disp('PID_GRID_WORKER_DONE')" "PID_GRID_WORKER_DONE" || return 1
  }
  mstat "stage 1: PID grid, 256 coarse points plus at most six fine layers"
  pids=""
  for id in 1 2 3; do worker "$id" & pids="$pids $!"; sleep 150; done
  wait $pids
  for id in 1 2 3; do [ -f "$S/pid_grid_w${id}_done.txt" ] || failed "worker $id"; done
fi

mstat "stage 2: Pareto selection, calib_margin, and five-seed report"
run_job_patient "pid_grid_select" "select_pid_pareto(true); disp('PID_GRID_SELECT_DONE')" "PID_GRID_SELECT_DONE" || failed selection

mstat "stage 3: PID DREWS scoring seeds 99995-99999"
run_job_patient "pid_grid_score" "run('$REPO/Model/Controllers/PID/load_pid.m'); run_scoring_seeds('PID',99995:99999); disp('PID_GRID_SCORE_DONE')" "PID_GRID_SCORE_DONE" || failed scoring

mstat "ALL DONE"
echo done > "$S/pid_grid_pipeline_done.txt"
