#!/bin/bash
# DREWS v2 on the five scoring seeds 99995-99999 for the FINAL designs of PID and MapPID (KeHoachMatlab.txt 10.3 step P5, 2026-10-23).
# Map's design did not change, so its Cases_v2 stays. Old Cases_v2 of PID and MapPID were moved to Cases_v2/pre_pareto beforehand.
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
one() { c=$1; l=$2
  run_job_patient "d3_$c" "$l; run_scoring_seeds('$c', 99995:99999); disp('D2_DONE')" "D2_DONE"; }
pids=""
one PID load_pid & pids="$pids $!"; sleep 90
one MapPID load_mappid & pids="$pids $!"
wait $pids
echo done > "$S/d3_all_done.txt"; log "DREWS final done (PID, MapPID)"
