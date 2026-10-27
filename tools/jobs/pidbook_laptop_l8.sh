#!/bin/bash
# PIDBOOK-LAPTOP L8-L9 (KeHoach_PID_Sach.txt 6.3): margin rounds for MapPID on the common-seed fronts, then the final design (select, writeJson) for MapPID only.
export MATLAB_TEMP="C:\\Users\\ADMIN\\Desktop\\git\\Adaptive-EPS-using-Reinforcement-Learning\\scratch\\MatlabTemp"
export MATLAB_PREFDIR="$MATLAB_TEMP\\prefs"
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
MASTER="$S/pidbook_laptop_master.txt"
mstat() { echo "$(date '+%F %T') $1" >> "$MASTER"; }
failed() { mstat "STOPPED: $1"; exit 1; }
mstat "L8 start: margin MapPID, 4 workers, rounds until no front point is pending"
for round in 1 2 3 4 5 6 7 8; do
  pids=""
  for id in 1 2 3 4; do
    run_job_patient "pbl_l8_r${round}_w$id" "compare_pareto_common('margin',{'MapPID'},$id,4); disp('PBL_L8_WORKER_DONE')" "PBL_L8_WORKER_DONE" &
    pids="$pids $!"; sleep 20
  done
  wait $pids
  for id in 1 2 3 4; do [ -f "$S/pbl_l8_r${round}_w${id}_done.txt" ] || failed "L8 round $round worker $id"; done
  run_job_patient "pbl_l8_front_r${round}" "r = compare_pareto_common('front',{'MapPID'}); disp(['PENDING=' num2str(r.pending)]); disp('PBL_L8_FRONT_DONE')" "PBL_L8_FRONT_DONE" || failed "L8 front round $round"
  mstat "L8 round $round done: $(grep -h 'PENDING=' "$S/pbl_l8_front_r${round}_try"*.log | tail -1)"
  if grep -qh "PENDING=0" "$S/pbl_l8_front_r${round}_try"*.log; then
    echo done > "$S/pbl_l8_done.txt"; mstat "L8 done (margin converged in round $round)"; break
  fi
done
[ -f "$S/pbl_l8_done.txt" ] || failed "L8 not converged after 8 rounds"
mstat "L9 start: select MapPID only (writeJson true)"
run_job_patient "pbl_l9_select" "compare_pareto_common('select',{'MapPID'},true); disp('PBL_L9_SELECT_DONE')" "PBL_L9_SELECT_DONE" || failed "L9 select"
run_job_patient "pbl_l9_test" "run('$REPO/Model/Controllers/MapPID/load_mappid.m'); test_mappid; disp('PBL_L9_TEST_DONE')" "PBL_L9_TEST_DONE" || failed "L9 load/test"
echo done > "$S/pbl_l9_done.txt"; mstat "L9 done"
