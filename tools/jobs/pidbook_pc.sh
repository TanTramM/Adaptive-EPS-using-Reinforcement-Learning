#!/bin/bash
# PIDBOOK-PC pipeline (Documents/Shared/KeHoach_PID_Sach.txt 6.3, steps P3-P9). Resumable: finished stages leave scratch/jobs/<tag>_done.txt.
# usage: bash tools/jobs/pidbook_pc.sh   (guard_ram.ps1 must be running)
export MATLAB_TEMP="D:\MatlabTemp"
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
CD="Result/Compare/Pareto_common"
M="$S/pidbook_master.txt"
mstat() { echo "$(date '+%F %T') $1" >> "$M"; }
failed() { mstat "STOPPED: $1"; push_mine "[PC] pidbook stopped: $1"; exit 1; }

push_mine() {   # git add ONLY the paths of the PC (KeHoach_PID_Sach 6.1), commit, pull --rebase, push
  cd "$REPO"
  git add -A -- Model/Controllers/PID Model/Controllers/PIDLag/script/pidlag_variables.m Model/Controllers/PIDLag/script/pidlag_eval.m Model/data/pid.json \
    Result/Controllers/PID "$CD"/ParetoCommon_PID_* "$CD"/Legacy_2026-10-27/ParetoCommon_PID_* "$CD"/ParetoCommon_MapPID_w[5-8]_* \
    "$CD"/PIDBOOK_PC_* "$CD"/PIDBOOK_MAPPID_PC_* tools/jobs/pidbook_pc.sh Tracking/historychat_pidbook_pc.md 2>/dev/null
  git diff --cached --quiet || git commit -q -m "${1:-[PC] pidbook progress}

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
  git pull -q --rebase --autostash origin main >> "$S/pidbook_git.log" 2>&1 || { git rebase --abort 2>/dev/null; mstat "git pull conflict (see pidbook_git.log)"; }
  git push -q origin main >> "$S/pidbook_git.log" 2>&1 || mstat "git push failed"
}
restore_shared() {   # files of the shared 'front'/'select' commands belong to the laptop: put back / remove after our run
  cd "$REPO"
  for f in ParetoCommon_fronts_safe.csv ParetoCommon_fronts_full.csv ParetoCommon_select.csv ParetoCommon_select_report.csv; do
    p="$CD/$f"
    if [ -n "$1" ] && [ -f "$p" ]; then cp "$p" "$CD/ParetoCommon_PID_${f#ParetoCommon_}"; fi
    if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then git checkout -- "$p" 2>/dev/null; else rm -f "$p"; fi
  done
}
( while true; do sleep 3000; push_mine "[PC] pidbook hourly csv push"; done ) &
HOURLY=$!
trap 'kill $HOURLY 2>/dev/null' EXIT

mstat "pipeline start"
# --- pid.json: move the old designs to 'legacy' (not read), idempotent
run_job_patient pb_json "J=jsondecode(fileread('$REPO/Model/data/pid.json')); if ~isfield(J,'legacy'), L=struct(); for f={'design','design_grid','design_emax5','design_pre_pareto'}, if isfield(J,f{1}), L.(f{1})=J.(f{1}); J=rmfield(J,f{1}); end, end, J.legacy=L; J.x_note_book='2026-10-27: design is written by the book redesign (KeHoach_PID_Sach.txt: K, Ti, Td, N); older designs are under legacy and are NOT read'; fid=fopen('$REPO/Model/data/pid.json','w'); fprintf(fid,'%s',jsonencode(J,'PrettyPrint',true)); fclose(fid); end; disp('PB_JSON_DONE')" PB_JSON_DONE || failed json
# --- P3 (one MATLAB) then worker 4 of the grid; workers 1-3 start now (max 4 MATLAB at once)
( run_job_patient pb_p3 "run('$REPO/scratch/pidbook/p3_map_check.m')" P3_DONE; mstat "P3 finished"
  run_job_patient pid_grid_w4 "run_pid_grid(4,4); disp('PID_GRID_WORKER_DONE')" PID_GRID_WORKER_DONE ) &
P34=$!
pids=""
for id in 1 2 3; do run_job_patient "pid_grid_w$id" "run_pid_grid($id,4); disp('PID_GRID_WORKER_DONE')" PID_GRID_WORKER_DONE & pids="$pids $!"; sleep 40; done
wait $pids $P34
for id in 1 2 3 4; do [ -f "$S/pid_grid_w${id}_done.txt" ] || failed "P4 grid worker $id"; done
mstat "P4 done"; push_mine "[PC] PID grid (seed 10000) done"
# --- P5
run_job_patient pb_select "select_pid_pareto(true); disp('PB_SELECT_DONE')" PB_SELECT_DONE || failed "P5 select"
mstat "P5 done"; push_mine "[PC] PID provisional selection and five-seed report"
# --- P6: phases 1 and 2 on the common seeds (id 1-4 of 4), then margin rounds (as pareto_pc_pipeline.sh)
for ph in 1 2; do
  pids=""
  for id in 1 2 3 4; do run_job_patient "pb_p6_ph${ph}_w$id" "compare_pareto_common('run',{'PID'},$id,4,$ph); disp('PARETO_STAGE_DONE')" PARETO_STAGE_DONE & pids="$pids $!"; sleep 30; done
  wait $pids
  for id in 1 2 3 4; do [ -f "$S/pb_p6_ph${ph}_w${id}_done.txt" ] || failed "P6 phase $ph worker $id"; done
  mstat "P6 phase $ph done"; push_mine "[PC] PID common-seed phase $ph"
done
conv=0
for round in 1 2 3 4 5 6 7 8; do
  pids=""
  for id in 1 2 3 4; do run_job_patient "pb_m${round}_w$id" "compare_pareto_common('margin',{'PID'},$id,4); disp('PARETO_STAGE_DONE')" PARETO_STAGE_DONE & pids="$pids $!"; sleep 20; done
  wait $pids
  run_job_patient "pb_front_r$round" "r = compare_pareto_common('front',{'PID'}); disp(['PENDING=' num2str(r.pending)]); disp('PARETO_FRONT_DONE')" PARETO_FRONT_DONE
  restore_shared
  mstat "P6 margin round $round done"; push_mine "[PC] PID margin round $round"
  if grep -qh "PENDING=0" "$S/pb_front_r${round}_try"*.log; then conv=1; break; fi
done
[ $conv = 1 ] || failed "P6 margin not converged after 8 rounds"
# --- P7
run_job_patient pb_select_final "compare_pareto_common('select',{'PID'},true); disp('PB_SELFINAL_DONE')" PB_SELFINAL_DONE || failed "P7 select"
restore_shared copy
mstat "P7 done"; push_mine "[PC] PID final design chosen on the common-seed front"
# --- P8: SSW (seed 99987-99989 common, 11001-11003 local)
run_job_patient pb_ssw "run('$REPO/Model/Controllers/PID/load_pid.m'); run_scoring_seeds('PID',[99987 99988 99989 11001 11002 11003],'SSW'); disp('PB_SSW_DONE')" PB_SSW_DONE || failed "P8 SSW"
mstat "P8 done"; push_mine "[PC] PID SSW done"
# --- P9: help MapPID (6.4): wait for the laptop grid flag (at most 2 h), then ids 5-8 of 8
t0=$(date +%s)
while [ ! -f "$REPO/$CD/PIDBOOK_MAPPID_GRID_DONE.txt" ]; do
  git pull -q --rebase --autostash origin main >> "$S/pidbook_git.log" 2>&1
  [ -f "$REPO/$CD/PIDBOOK_MAPPID_GRID_DONE.txt" ] && break
  [ $(( $(date +%s) - t0 )) -gt 7200 ] && { mstat "P9: no MAPPID_GRID_DONE flag after 2 h, stopped waiting"; break; }
  sleep 180
done
if [ -f "$REPO/$CD/PIDBOOK_MAPPID_GRID_DONE.txt" ]; then
  mstat "P9 start"
  for ph in 1 2; do
    pids=""
    for id in 5 6 7 8; do run_job_patient "pb_p9_ph${ph}_w$id" "compare_pareto_common('run',{'MapPID'},$id,8,$ph); disp('PARETO_STAGE_DONE')" PARETO_STAGE_DONE & pids="$pids $!"; sleep 30; done
    wait $pids
    push_mine "[PC] MapPID common-seed phase $ph ids 5-8"
  done
  ok=1; for ph in 1 2; do for id in 5 6 7 8; do [ -f "$S/pb_p9_ph${ph}_w${id}_done.txt" ] || ok=0; done; done
  if [ $ok = 1 ]; then echo "PIDBOOK_MAPPID_PC_DONE $(date '+%F %T') PC" > "$REPO/$CD/PIDBOOK_MAPPID_PC_DONE.txt"; mstat "P9 done"; else mstat "P9 incomplete"; fi
fi
echo "PIDBOOK_PC_DONE $(date '+%F %T') PC" > "$REPO/$CD/PIDBOOK_PC_DONE.txt"
mstat "ALL DONE"; push_mine "[PC] PIDBOOK_PC_DONE"
