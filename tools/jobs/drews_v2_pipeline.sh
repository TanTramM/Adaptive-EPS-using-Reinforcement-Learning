#!/bin/bash
# DREWS v2 on the five scoring seeds 99995-99999 for PID and Map (2026-10-22; MapPID runs on the laptop). Results: Result/Controllers/<Ctrl>/Cases_v2.
# Resumable: run_scoring_seeds skips a seed whose metrics file exists; run_job_patient restarts a MATLAB that was killed. Needs guard_ram.ps1 running.
# usage: bash tools/jobs/drews_v2_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
one() { c=$1; l=$2
  run_job_patient "d2_$c" "$l; run_scoring_seeds('$c', 99995:99999); disp('D2_DONE')" "D2_DONE"; }
pids=""
one PID load_pid & pids="$pids $!"; sleep 90
one Map load_map & pids="$pids $!"
wait $pids
echo done > "$S/d2_all_done.txt"; log "DREWS v2 done (PID, Map)"
