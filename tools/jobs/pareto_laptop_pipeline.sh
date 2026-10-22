#!/bin/bash
# Laptop stage runner of the common-seed Pareto comparison for MapPID (Documents/Shared/KeHoach_SoMatPareto.txt 2.3).
# Usage: MATLAB_TEMP='C:\MatlabTemp' bash tools/jobs/pareto_laptop_pipeline.sh <phase1|phase2|margin> [N_WORKERS]
# phase1/phase2: N workers run compare_pareto_common('run',{'MapPID'},id,N,<phase>); margin: rounds of margin (N workers) + 'front' until no front point is pending.
# Safe to restart: finished jobs are skipped (<tag>_done.txt in scratch/jobs), every evaluation is cached in the csv of its worker.
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
STAGE=${1:?stage}; NW=${2:-4}
failed() { echo "STOPPED: $1 failed, see scratch/jobs" > "$S/pareto_laptop_master_status.txt"; exit 1; }
case "$STAGE" in
  phase1|phase2)
    ph=${STAGE#phase}; pids=""
    for id in $(seq 1 "$NW"); do
      run_job_patient "pareto_${STAGE}_w$id" "compare_pareto_common('run',{'MapPID'},$id,$NW,$ph); disp('PARETO_WORKER_DONE')" "PARETO_WORKER_DONE" &
      pids="$pids $!"; sleep 40
    done
    wait $pids
    for id in $(seq 1 "$NW"); do [ -f "$S/pareto_${STAGE}_w${id}_done.txt" ] || failed "$STAGE worker $id"; done
    ;;
  margin)
    for round in 1 2 3 4 5 6 7 8; do
      pids=""
      for id in $(seq 1 "$NW"); do
        run_job_patient "pareto_margin_r${round}_w$id" "compare_pareto_common('margin',{'MapPID'},$id,$NW); disp('PARETO_MARGIN_DONE')" "PARETO_MARGIN_DONE" &
        pids="$pids $!"; sleep 40
      done
      wait $pids
      for id in $(seq 1 "$NW"); do [ -f "$S/pareto_margin_r${round}_w${id}_done.txt" ] || failed "margin round $round worker $id"; done
      run_job_patient "pareto_front_r${round}" "compare_pareto_common('front',{'MapPID'}); disp('PARETO_FRONT_DONE')" "PARETO_FRONT_DONE" || failed "front round $round"
      if grep -q "front: 0 margin results still pending" "$S/pareto_front_r${round}_try1.log" 2>/dev/null; then break; fi
    done
    ;;
esac
echo "$STAGE done $(date)" > "$S/pareto_laptop_${STAGE}_complete.txt"
