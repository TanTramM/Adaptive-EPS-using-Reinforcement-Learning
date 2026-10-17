#!/bin/bash
# MapPIDOpt pipeline of DieuKhien_MapPID.txt Part H: build check, plants cache, three search chains (surrogateopt 250 then patternsearch 60), selection (20 best x 5 seeds),
# DREWS at the local seed 30000. Auto-resumes (job_lib.sh); start again with the same command to continue after any interruption.
# usage: bash tools/jobs/mappidopt_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib.sh"
run_job "mpo_check" "build_closed_loop('MapPIDOpt'); test_mappidopt; check_mappidopt; disp('MPO_CHECK_DONE')" "MPO_CHECK_DONE" || exit 1
chain() { id=$1
  run_job "mpo_o4_$id" "optimize_mappidopt($id, 250)" "optimize_mappidopt($id) DONE" || return 1
  run_job "mpo_o5_$id" "refine_mappidopt($id, 60)" "refine_mappidopt($id) DONE" || return 1
  echo chain_done > "$S/mpo_chain_$id.txt"; }
pids=""
for id in 1 2 3; do chain $id & pids="$pids $!"; sleep 150; done
wait $pids
run_job "mpo_o6" "select_mappidopt(true); disp('SELECT_DONE')" "SELECT_DONE" || exit 1
run_job "mpo_o8" "run_mappidopt_cases; disp('CASES_DONE')" "CASES_DONE" || exit 1
echo pipeline_done > "$S/mpo_pipeline_done.txt"; log "MapPIDOpt pipeline done"
