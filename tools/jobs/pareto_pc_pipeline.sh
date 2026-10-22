#!/bin/bash
# PC pipeline of the common-seed Pareto comparison (KeHoach_SoMatPareto.txt, amendment A of 2026-10-22):
#   stage 1: phase 1 for PID then Map; stage 2: phase 2 (points inside the noise band); stage 3: rounds of 'margin' + 'front' until no margin is pending.
# NW workers (default 6: the Map evaluations are slow and the CPU is mostly idle). Safe to restart: complete points are skipped, every evaluation is cached in the csv of its worker,
# finished stages leave scratch/jobs/<tag>_done.txt.
export MATLAB_TEMP='D:\MatlabTemp'
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
NW=${PARETO_NW:-6}                      # total number of workers across ALL machines (positions are partitioned mod NW)
IDS=${PARETO_IDS:-$(seq -s ' ' 1 $NW)}   # worker ids run by THIS machine, e.g. '1 2 3 4 5 6' on the PC and '7 8 9 10' on the laptop
STOP_AFTER=${PARETO_STOP_AFTER:-}        # 'p1' or 'p2': stop the pipeline after that stage (cross-machine sync points)
CTRLS="{'PID','Map'}"
NAME="${PARETO_NAME:-pcB}"
M="$S/${NAME}_master.txt"
echo "$(date '+%F %T') pipeline start, $NW workers" > "$M"
stage() {   # stage <tag-prefix> <matlab expression with ID placeholder> <ok marker> <delay between starts>
  local pre=$1 expr=$2 marker=$3 delay=$4 pids="" id
  for id in $IDS; do
    run_job_patient "${NAME}_${pre}_w$id" "${expr//@W@/$id}" "$marker" &
    pids="$pids $!"; sleep $delay
  done
  wait $pids
  for id in $IDS; do [ -f "$S/${NAME}_${pre}_w${id}_done.txt" ] || { echo "$pre worker $id failed" >> "$M"; exit 1; }; done
  echo "$(date '+%F %T') $pre done" >> "$M"
}
stage p1 "compare_pareto_common('run',$CTRLS,@W@,$NW,1); disp('PARETO_STAGE_DONE')" PARETO_STAGE_DONE 60
[ "$STOP_AFTER" = p1 ] && { echo "$(date '+%F %T') stopped after p1" >> "$M"; exit 0; }
stage p2 "compare_pareto_common('run',$CTRLS,@W@,$NW,2); disp('PARETO_STAGE_DONE')" PARETO_STAGE_DONE 60
[ "$STOP_AFTER" = p2 ] && { echo "$(date '+%F %T') stopped after p2" >> "$M"; exit 0; }
for round in 1 2 3 4 5 6 7 8; do
  stage "m$round" "compare_pareto_common('margin',$CTRLS,@W@,$NW); disp('PARETO_STAGE_DONE')" PARETO_STAGE_DONE 20
  run_job_patient "${NAME}_front_r${round}" "r = compare_pareto_common('front',$CTRLS); disp(['PENDING=' num2str(r.pending)]); disp('PARETO_FRONT_DONE')" "PARETO_FRONT_DONE"
  if grep -qh "PENDING=0" "$S/${NAME}_front_r${round}_try"*.log; then
    echo "$(date '+%F %T') margin converged in round $round" >> "$M"; echo done > "$S/${NAME}_pipeline_done.txt"; exit 0
  fi
done
echo "not converged after 8 rounds" >> "$M"; exit 1
