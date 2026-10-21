#!/bin/bash
# MapPID "plug-in" pipeline (PhuongPhap_TimThamSo.txt 15.3): Map block locked to map.json, PID block searched by the PID grid.
# Usage: MATLAB_TEMP='C:\MatlabTemp' bash tools/jobs/mappid_plug_pipeline.sh [N_WORKERS]
# Stages (markers in scratch/jobs/mappid_plug_*): check -> grid (N workers) -> select -> D -> C. Safe to restart: finished stages are skipped.
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
NW=${1:-4}
MASTER="$S/mappid_plug_master_status.txt"
mstat() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" > "$MASTER"; }
failed() { mstat "STOPPED: $1 failed, see scratch/jobs"; exit 1; }

mstat "stage 1: check (box round trip + one evaluation)"
run_job_patient "mappid_plug_check" "check_mappid_plug; disp('MAPPID_PLUG_CHECK_DONE')" "MAPPID_PLUG_CHECK_DONE" || failed check

mstat "stage 2: grid, $NW workers (256 coarse points + at most 6 fine layers)"
pids=""
for id in $(seq 1 "$NW"); do
  run_job_patient "mappid_plug_w$id" "run_mappid_plug($id,$NW); disp('MAPPID_PLUG_WORKER_DONE')" "MAPPID_PLUG_WORKER_DONE" &
  pids="$pids $!"; sleep 40
done
wait $pids
for id in $(seq 1 "$NW"); do [ -f "$S/mappid_plug_w${id}_done.txt" ] || failed "worker $id"; done

mstat "stage 3: selection (backup mappid.json first)"
BK="/c/Users/ADMIN/Desktop/Adaptive-EPS_backup_2026-10-22_MapPID_truoc_plug"
if [ ! -f "$BK/mappid.json" ]; then mkdir -p "$BK" && cp "$REPO/Model/data/mappid.json" "$BK/mappid.json" || failed backup; fi
run_job_patient "mappid_plug_select" "select_mappid_plug(true); disp('MAPPID_PLUG_SELECT_DONE')" "MAPPID_PLUG_SELECT_DONE" || failed selection
run_job_patient "mappid_plug_loadtest" "run('$REPO/Model/Controllers/MapPID/load_mappid.m'); test_mappid; disp('MAPPID_PLUG_LOADTEST_DONE')" "MAPPID_PLUG_LOADTEST_DONE" || failed loadtest

mstat "stage 4: D (stand-alone PID design on the locked Map)"
run_job_patient "mappid_plug_D" "run_mappid_plug_dc('D'); disp('MAPPID_PLUG_D_DONE')" "MAPPID_PLUG_D_DONE" || failed D
mstat "stage 5: C (chosen PID block on three other Maps)"
run_job_patient "mappid_plug_C" "run_mappid_plug_dc('C'); disp('MAPPID_PLUG_C_DONE')" "MAPPID_PLUG_C_DONE" || failed C

mstat "ALL DONE (D, C finished; DREWS v2 is done separately)"
echo done > "$S/mappid_plug_pipeline_done.txt"
