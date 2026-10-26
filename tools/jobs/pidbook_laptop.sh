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
