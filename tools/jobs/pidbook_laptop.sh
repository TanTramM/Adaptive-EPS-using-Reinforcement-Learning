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

if [ "${1:-l3}" = "l7self" ]; then
  mstat "L7 self-help start: no PC w5-w8 after 30 minutes"
  pids=""
  for id in 5 6 7 8; do
    run_job_patient "pbl_l7_ph1_w$id" "compare_pareto_common('run',{'MapPID'},$id,8,1); disp('PBL_L7_WORKER_DONE')" "PBL_L7_WORKER_DONE" &
    pids="$pids $!"
    sleep 30
  done
  wait $pids
  for id in 5 6 7 8; do
    [ -f "$S/pbl_l7_ph1_w${id}_done.txt" ] || failed "L7 phase 1 worker $id"
  done
  mstat "L7 phase 1 ids 5-8 done; all phase-1 noise estimates available"

  for block in first second; do
    if [ "$block" = first ]; then ids="1 2 3 4"; else ids="5 6 7 8"; fi
    pids=""
    for id in $ids; do
      run_job_patient "pbl_l7_ph2_w$id" "compare_pareto_common('run',{'MapPID'},$id,8,2); disp('PBL_L7_WORKER_DONE')" "PBL_L7_WORKER_DONE" &
      pids="$pids $!"
      sleep 30
    done
    wait $pids
    for id in $ids; do
      [ -f "$S/pbl_l7_ph2_w${id}_done.txt" ] || failed "L7 phase 2 worker $id"
    done
    mstat "L7 phase 2 block $block done"
  done
  echo "PIDBOOK_MAPPID_PC_DONE $(date '+%F %T') laptop self-help" > "$REPO/Result/Compare/Pareto_common/PIDBOOK_MAPPID_PC_DONE.txt"
  echo done > "$S/pbl_l7self_done.txt"
  mstat "L7 self-help done"
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
