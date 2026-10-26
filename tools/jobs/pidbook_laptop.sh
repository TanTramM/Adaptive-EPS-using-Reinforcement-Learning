#!/bin/bash
# PIDBOOK-LAPTOP runner for the long MATLAB stages in KeHoach_PID_Sach.txt 6.3.
# The root frame advances the inter-machine gates and final shared steps; this
# runner provides the patient, resumable four-worker L3 grid stage.
export MATLAB_TEMP="C:\\Users\\ADMIN\\Desktop\\git\\Adaptive-EPS-using-Reinforcement-Learning\\scratch\\MatlabTemp"
export MATLAB_PREFDIR="$MATLAB_TEMP\\prefs"
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"

MASTER="$S/pidbook_laptop_master.txt"
mstat() { echo "$(date '+%F %T') $1" >> "$MASTER"; }
failed() { mstat "STOPPED: $1"; exit 1; }

if [ "${1:-l3}" = "l4" ]; then
  mstat "L4 start: provisional selection, seeds 30001-30005, margin 30001"
  run_job_patient "pbl_l4" "select_mappid_plug(true); disp('PBL_L4_DONE')" "PBL_L4_DONE" || failed "L4 selection"
  mstat "L4 done"
  exit 0
fi

if [ "${1:-l3}" = "l6" ]; then
  for phase in 1 2; do
    mstat "L6 phase $phase start: MapPID ids 1-4 of 8"
    pids=""
    for id in 1 2 3 4; do
      run_job_patient "pbl_l6_ph${phase}_w$id" "compare_pareto_common('run',{'MapPID'},$id,8,$phase); disp('PBL_L6_WORKER_DONE')" "PBL_L6_WORKER_DONE" &
      pids="$pids $!"
      sleep 30
    done
    wait $pids
    for id in 1 2 3 4; do
      [ -f "$S/pbl_l6_ph${phase}_w${id}_done.txt" ] || failed "L6 phase $phase worker $id"
    done
    mstat "L6 phase $phase done"
  done
  echo done > "$S/pbl_l6_done.txt"
  exit 0
fi

mstat "L3 start: MapPID grid seed 30000, four workers"
pids=""
for id in 1 2 3 4; do
  run_job_patient "pbl_l3_w$id" "run_mappid_plug($id,4); disp('PBL_L3_WORKER_DONE')" "PBL_L3_WORKER_DONE" &
  pids="$pids $!"
  sleep 30
done
wait $pids
for id in 1 2 3 4; do
  [ -f "$S/pbl_l3_w${id}_done.txt" ] || failed "L3 worker $id"
done
mstat "L3 done"
echo done > "$S/pbl_l3_done.txt"
