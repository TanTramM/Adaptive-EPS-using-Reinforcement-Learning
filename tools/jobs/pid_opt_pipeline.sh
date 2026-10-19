#!/bin/bash
# PID on CALIB v2 by the common method, PhuongPhap_TimThamSo.txt 13.1 (2026-10-18): e_max 10 %, surrogateopt only, 200 evaluations per chain (MATLAB default max(200, 50 x 4)).
# usage: bash tools/jobs/pid_opt_pipeline.sh search   check + three search chains (seed 10000); then compare the three best J (must differ < 3 %, else run "extend")
#        bash tools/jobs/pid_opt_pipeline.sh extend   +150 evaluations per chain (350 in total, from the checkpoint), at most once
#        bash tools/jobs/pid_opt_pipeline.sh rest     selection (top 20, seeds 10001-10005, calib_margin) and DREWS: old cases at the local seed 10000, then the scoring seeds 99999-99995
# RAM: job_lib_patient.sh waits for 6 GB headroom before every MATLAB start and restarts a MATLAB stopped by guard_ram.ps1 (solvers resume from checkpoint / csv cache).
# Monitoring: scratch/jobs/pid_master_status.txt (stage), scratch/jobs/p_*_status.txt and pid_*_status.txt (one line per job).
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
M="$S/pid_master_status.txt"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$M"; }
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }
PHASE=${1:-search}

if [ "$PHASE" = search ] || [ "$PHASE" = extend ]; then
  N=200; TAG=p_o4; [ "$PHASE" = extend ] && { N=350; TAG=p_o5; }
  if [ "$PHASE" = search ]; then
    mstat "stage 0: check of the evaluation (R 5.386384 for a known design)"
    run_job_patient "pid_check" "xr_o = pidlag_eval('PID', [1.365 52.09 0.04636 0.002882], 10000, ''); assert(abs(xr_o.R - 5.386384) < 1e-3, 'PID eval differs'); disp('PID_CHECK_DONE')" "PID_CHECK_DONE" || failed pid_check
  fi
  chain() { id=$1
    run_job_patient "${TAG}_$id" "optimize_pid($id, $N)" "optimize_pid($id) DONE" || return 1
    echo chain_done > "$S/${TAG}_chain_$id.txt"; }
  mstat "stage 1 ($PHASE, $N evaluations): three chains, each starts when memory allows"
  pids=""
  for id in 1 2 3; do chain $id & pids="$pids $!"; sleep 150; done
  wait $pids
  for id in 1 2 3; do [ -f "$S/${TAG}_chain_$id.txt" ] || failed "chain $id"; done
  mstat "search ($PHASE) DONE: compare the best J of the three chains"
  echo done > "$S/pid_${PHASE}_done.txt"
elif [ "$PHASE" = rest ]; then
  mstat "stage 2: selection (20 best distinct designs, seeds 10001-10005, calib_margin)"
  run_job_patient "pid_sel" "select_pid(true); disp('SELECT_DONE')" "SELECT_DONE" || failed pid_sel
  mstat "stage 3: DREWS (old cases) at the local seed 10000"
  run_job_patient "pid_cases" "run('$REPO/Model/Controllers/PID/load_pid.m'); run_cases('PID', 10000); disp('CASES_DONE')" "CASES_DONE" || failed pid_cases
  mstat "stage 4: scoring seeds 99999-99995 (five cases each)"
  run_job_patient "pid_score" "run('$REPO/Model/Controllers/PID/load_pid.m'); run_scoring_seeds('PID', 99995:99999); disp('SCORE_DONE')" "SCORE_DONE" || failed pid_score
  mstat "ALL DONE (selection, DREWS seed 10000, scoring seeds)"
  echo done > "$S/pid_rest_done.txt"
fi
