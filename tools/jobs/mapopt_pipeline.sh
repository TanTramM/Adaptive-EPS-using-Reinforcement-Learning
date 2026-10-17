#!/bin/bash
# MapOpt pipeline of DieuKhien_MapOpt.txt: three search chains (surrogateopt 250 then patternsearch 60), then selection, then DREWS at seed 0.
# usage: bash tools/jobs/mapopt_pipeline.sh [suffix]   suffix '' = run 1 (functions optimize_mapopt(k, 250)); for run 2 pass the argument the functions expect (see Part M of the notes).
source "$(dirname "${BASH_SOURCE[0]}")/job_lib.sh"
sfx=${1:-}
chain() { id=$1
  run_job "mo${sfx}_o4_$id" "optimize_mapopt($id, 250${sfx:+, '$sfx'})" "optimize_mapopt($id) DONE" || exit 1
  run_job "mo${sfx}_o5_$id" "refine_mapopt($id, 60${sfx:+, '$sfx'})" "refine_mapopt($id) DONE" || exit 1
  echo chain_done > "$S/mo${sfx}_chain_$id.txt"; }
pids=""
for id in 1 2 3; do chain $id & pids="$pids $!"; sleep 150; done
wait $pids
run_job "mo${sfx}_o6" "select_mapopt(true${sfx:+, '$sfx'}); disp('SELECT_DONE')" "SELECT_DONE" || echo "select failed" >> "$S/mo${sfx}_errors.txt"
run_job "mo${sfx}_o8" "run_mapopt_cases; disp('CASES_DONE')" "CASES_DONE" || echo "cases failed" >> "$S/mo${sfx}_errors.txt"
echo master_done > "$S/mo${sfx}_master_done.txt"
