#!/bin/bash
# PC pipeline of the common-seed Pareto comparison (KeHoach_SoMatPareto.txt 2.2 step 5): 'run' for Map and PID with 4 workers, then rounds of 'margin' + 'front' until no margin is pending.
# Safe to restart: every evaluation is cached in the csv of its worker, finished stages leave scratch/jobs/<tag>_done.txt.
export MATLAB_TEMP='D:\MatlabTemp'
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
CTRLS="${PARETO_CTRLS:-{'Map','PID'}}"
NAME="${PARETO_NAME:-pcpc}"
echo "$(date '+%F %T') pipeline start ($CTRLS)" > "$S/${NAME}_master.txt"
pids=""
for id in 1 2 3 4; do
  run_job_patient "${NAME}_run_w$id" "compare_pareto_common('run',$CTRLS,$id,4); disp('PARETO_RUN_DONE')" "PARETO_RUN_DONE" &
  pids="$pids $!"; sleep 90
done
wait $pids
for id in 1 2 3 4; do [ -f "$S/${NAME}_run_w${id}_done.txt" ] || { echo "run worker $id failed" >> "$S/${NAME}_master.txt"; exit 1; }; done
echo "$(date '+%F %T') run done" >> "$S/${NAME}_master.txt"
for round in 1 2 3 4 5 6 7 8; do
  pids=""
  for id in 1 2 3 4; do
    rm -f "$S/${NAME}_margin_r${round}_w${id}_done.txt"
    run_job_patient "${NAME}_margin_r${round}_w$id" "compare_pareto_common('margin',$CTRLS,$id,4); disp('PARETO_MARGIN_DONE')" "PARETO_MARGIN_DONE" &
    pids="$pids $!"; sleep 30
  done
  wait $pids
  run_job_patient "${NAME}_front_r${round}" "r = compare_pareto_common('front',$CTRLS); disp(['PENDING=' num2str(r.pending)]); disp('PARETO_FRONT_DONE')" "PARETO_FRONT_DONE"
  if grep -q "PENDING=0" "$S/${NAME}_front_r${round}_try1.log" 2>/dev/null || grep -q "PENDING=0" "$S/${NAME}_front_r${round}_try"*.log; then
    echo "$(date '+%F %T') margin converged in round $round" >> "$S/${NAME}_master.txt"; echo done > "$S/${NAME}_pipeline_done.txt"; exit 0
  fi
done
echo "not converged after 8 rounds" >> "$S/${NAME}_master.txt"; exit 1
