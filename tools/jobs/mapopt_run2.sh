#!/bin/bash
# MapOpt RUN 2 (DieuKhien_MapOpt.txt Part M) with the patient runner: check, three search chains (surrogateopt 250 then patternsearch 60), selection, DREWS at the local seed 0.
# usage: bash tools/jobs/mapopt_run2.sh      (safe to start again at any time: finished stages are skipped, solvers resume from their checkpoint files)
# Monitoring: scratch/jobs/mo_b_master_status.txt (stage), scratch/jobs/mo_b_*_status.txt (one line per job: waiting for memory / running / interrupted / DONE / FAILED).
# Stops (FAILED marker, no further stage) only on a genuine MATLAB error that repeated MAX_REAL_FAIL times; a lack of RAM never stops it, it waits (job_lib_patient.sh).
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
M="$S/mo_b_master_status.txt"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$M"; }
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

mstat "stage 0: check of the run-2 code (test_mapopt, test_mapopt_run2)"
run_job_patient "mo_b_check" "test_mapopt; test_mapopt_run2; disp('RUN2_CHECK_DONE')" "RUN2_CHECK_DONE" || failed mo_b_check

chain() { id=$1
  run_job_patient "mo_b_o4_$id" "optimize_mapopt($id, 250, 'b')" "optimize_mapopt($id) DONE" || return 1
  run_job_patient "mo_b_o5_$id" "refine_mapopt($id, 60, 'b')" "refine_mapopt($id) DONE" || return 1
  echo chain_done > "$S/mo_b_chain_$id.txt"; }
mstat "stage 1: search, three chains (each starts when memory allows)"
pids=""
for id in 1 2 3; do chain $id & pids="$pids $!"; sleep 150; done
wait $pids
for id in 1 2 3; do [ -f "$S/mo_b_chain_$id.txt" ] || failed "chain $id"; done

mstat "stage 2: selection (20 best distinct designs, seeds 1-5, calib_margin)"
run_job_patient "mo_b_o6" "select_mapopt(true, 'b'); disp('SELECT_DONE')" "SELECT_DONE" || failed mo_b_o6
mstat "stage 3: DREWS at the local seed 0"
run_job_patient "mo_b_o8" "run_mapopt_cases; disp('CASES_DONE')" "CASES_DONE" || failed mo_b_o8
mstat "ALL DONE (check, search, selection, DREWS seed 0)"
echo master_done > "$S/mo_b_master_done.txt"
