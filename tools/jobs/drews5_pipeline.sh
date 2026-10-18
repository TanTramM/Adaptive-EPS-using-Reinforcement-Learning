#!/bin/bash
# DREWS on the five scoring seeds 99995-99999 for the controllers of the report (run_scoring_seeds skips a seed whose metrics file exists). Auto-resumes (job_lib.sh).
# usage: bash tools/jobs/drews5_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib.sh"
one() { c=$1; l=$2
  run_job "d5_$c" "$l; run_scoring_seeds('$c', 99995:99999); disp('D5_DONE')" "D5_DONE"; }
pids=""
one MapOpt load_mapopt & pids="$pids $!"; sleep 90
one PIDOpt load_pidopt & pids="$pids $!"
wait $pids
one MapPID load_mappid
echo done > "$S/d5_all_done.txt"; log "DREWS 5 seeds done"
