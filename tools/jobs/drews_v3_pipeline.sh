#!/bin/bash
# DREWS v3 (five cases of 100 s, Documents/Shared/KeHoach_DREWS_v3.txt) for the FINAL designs of Map, PID and MapPID, seeds 99995-99999, results in Result/Controllers/<Ctrl>/Cases_v3.
# One MATLAB job per (controller, seed); at most NJOBS at the same time (default 4). Resumable: run_scoring_seeds skips a seed whose metrics file exists,
# run_job_patient restarts a MATLAB that was killed. Needs guard_ram.ps1 running. usage: bash tools/jobs/drews_v3_pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
NJOBS=${NJOBS:-4}
one() { c=$1; l=$2; s=$3
  run_job_patient "d5_${c}_$s" "$l; run_scoring_seeds('$c', $s); disp('D5_DONE')" "D5_DONE"; }
n=0
for c in Map MapPID PID; do
  case $c in Map) l=load_map;; MapPID) l=load_mappid;; PID) l=load_pid;; esac
  for s in 99995 99996 99997 99998 99999; do
    while [ "$(jobs -rp | wc -l)" -ge "$NJOBS" ]; do sleep 20; done
    one $c $l $s &
    sleep 60
  done
done
wait
echo done > "$S/d5_all_done.txt"; log "DREWS v3 done (Map, MapPID, PID)"
