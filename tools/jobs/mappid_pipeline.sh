#!/bin/bash
# MapPID pipeline of DieuKhien_MapPID.txt Part H on CALIB v2: build check, plants cache, three search chains (surrogateopt 450 = MATLAB default max(200, 50 x 9) for 9 variables, then 600 after the pre-registered extension of +150 (rule H9, chains differ by more than 3 %), no patternsearch per the COMMON decision of 2026-10-18, seed 30000), selection
# (20 best x 5 seeds 30001-30005), DREWS on the five scoring seeds 99995-99999 (run_scoring_seeds); e_max 10 % (PhuongPhap_TimThamSo.txt 13.3). Auto-resumes (job_lib.sh): start again with the same command after any interruption.
# usage: bash tools/jobs/mappid_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib.sh"
run_job "mp_check" "load_mappid; test_mappid; mappid_plants(); disp('MP_CHECK_DONE')" "MP_CHECK_DONE" || exit 1
chain() { id=$1
  run_job "mp_o4_$id" "optimize_mappid($id, 600)" "optimize_mappid($id) DONE" || return 1
  echo chain_done > "$S/mp_chain_$id.txt"; }
pids=""
for id in 1 2 3; do chain $id & pids="$pids $!"; sleep 150; done
wait $pids
run_job "mp_o6" "select_mappid(true); disp('SELECT_DONE')" "SELECT_DONE" || exit 1
run_job "mp_o8" "load_mappid; run_scoring_seeds('MapPID', 99995:99999); disp('CASES_DONE')" "CASES_DONE" || exit 1
echo pipeline_done > "$S/mp_pipeline_done.txt"; log "MapPID pipeline done"
