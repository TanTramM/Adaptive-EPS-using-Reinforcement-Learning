#!/bin/bash
# SSW (three cases STEADY, SLIP, WEAVE of 100 s, make_cases('SSW'), Documents/Shared/KeHoach_SSW.txt) for the FINAL designs of Map, PID and MapPID.
# Phase 1: three NEW local seeds per controller (Map 01001-01003, PID 11001-11003, MapPID 31001-31003); phase 2: three NEW common seeds 99987-99989
# for the comparison. No seed here was used by any earlier process. csv only, results in Result/Controllers/<Ctrl>/Cases_ssw.
# One MATLAB job per controller and phase (local first, then common). Resumable: run_scoring_seeds skips a seed whose metrics file exists.
# Needs guard_ram.ps1 running. usage: bash tools/jobs/ssw_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
one() { c=$1; l=$2; loc=$3
  run_job_patient "ssw_${c}_local" "$l; run_scoring_seeds('$c', [$loc], 'SSW'); disp('SSW_DONE')" "SSW_DONE"
  run_job_patient "ssw_${c}_common" "$l; run_scoring_seeds('$c', [99987 99988 99989], 'SSW'); disp('SSW_DONE')" "SSW_DONE"; }
one Map load_map "1001 1002 1003" &
sleep 30
one PID load_pid "11001 11002 11003" &
sleep 30
one MapPID load_mappid "31001 31002 31003" &
wait
echo done > "$S/ssw_all_done.txt"; log "SSW done (Map, PID, MapPID; local and common seeds)"
