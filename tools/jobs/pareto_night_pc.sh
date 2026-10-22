#!/bin/bash
# PC night chain of KeHoachMatlab.txt 10.3, steps P1 and P2 (margin of the fronts of the common-seed Pareto comparison), 6 workers (ids 1-6).
#   P1: near range, rounds of margin + front until nothing is pending in scope: (a) PID and Map, Mode full; (b) Map, Mode safe, R_tb <= 20; (c) PID, Mode both.
#   P2: Map tail list (ParetoCommon_Map_tail_list.csv, written once in P0 and shared with the laptop), worker ids 1-6 of 10 (the laptop runs 7-10); one round.
# Safe to restart: every margin result is cached in the csv of its worker, finished pipelines leave scratch/jobs/<name>_pipeline_done.txt.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd -W)"
PIPE="$HERE/pareto_pc_pipeline.sh"
LOGM="$HERE/../../scratch/jobs/pcnight_master.txt"
mkdir -p "$(dirname "$LOGM")"
say() { echo "$(date '+%F %T') $*" >> "$LOGM"; }
run() {   # run <name> <ctrls> <margin args> <nw> <ids> <one round>
  local name=$1
  [ -f "$HERE/../../scratch/jobs/${name}_pipeline_done.txt" ] && { say "$name already done"; return 0; }
  say "$name start"
  PARETO_NAME="$name" PARETO_CTRLS="$2" PARETO_MARGIN_ARGS="$3" PARETO_NW="$4" PARETO_IDS="$5" PARETO_ONE_ROUND="$6" PARETO_SKIP_RUN=1 bash "$PIPE"
  local rc=$?
  say "$name exit $rc"
  return $rc
}
LIST="$REPO/Result/Compare/Pareto_common/ParetoCommon_Map_tail_list.csv"
LIST="${LIST//\\//}"
run pcP1a "{'PID','Map'}" ",'Mode','full'" 6 "1 2 3 4 5 6" "" || exit 1
run pcP1b "{'Map'}" ",'Mode','safe','Rmax',20" 6 "1 2 3 4 5 6" "" || exit 1
run pcP1c "{'PID'}" ",'Mode','both'" 6 "1 2 3 4 5 6" "" || exit 1
echo "$(date '+%F %T') P1 done" > "$HERE/../../scratch/jobs/pcnight_P1_done.txt"
run pcP2 "{'Map'}" ",'List','$LIST'" 10 "1 2 3 4 5 6" 1 || exit 1
echo "$(date '+%F %T') P2 done" > "$HERE/../../scratch/jobs/pcnight_P2_done.txt"
say "P1 and P2 done"
