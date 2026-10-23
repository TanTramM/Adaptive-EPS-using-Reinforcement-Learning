#!/bin/bash
# SLIP v4 alone (make_cases('SLIP_V4'), 100 s, 2026-10-23) for the FINAL designs of Map, PID and MapPID, seeds 99995-99999, results in Result/Controllers/<Ctrl>/Cases_slip4.
# One MATLAB job per controller (five seeds in a row, the case is short). Resumable: run_scoring_seeds skips a seed whose metrics file exists.
# Needs guard_ram.ps1 running. usage: bash tools/jobs/slip4_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
for c in Map MapPID PID; do
  case $c in Map) l=load_map;; MapPID) l=load_mappid;; PID) l=load_pid;; esac
  run_job_patient "s4_${c}" "$l; run_scoring_seeds('$c', [99995 99996 99997 99998 99999], 'SLIP4'); disp('S4_DONE')" "S4_DONE" &
  sleep 30
done
wait
echo done > "$S/s4_all_done.txt"; log "SLIP v4 done (Map, MapPID, PID)"
