#!/bin/bash
# Helpers to run long MATLAB jobs in the background on the shared 32 GB machine (written 2026-10-17 from the MapPID frame's scratchpad scripts; use as is).
#   source tools/jobs/job_lib.sh ; run_job <tag> "<matlab expression>" "<text that appears in the log when the job is done>"
# AUTO-RESUME MECHANISM (2026-10-17): the job waits as long as it takes until the machine has memory (headroom.ps1 >= START_GB, default 5 GB), starts MATLAB, and when MATLAB dies
# (killed by the RAM guard, out of memory, crash) it waits for memory again and restarts it; up to MAX_TRIES (default 400) restarts, about a week. Every long function resumes
# from its checkpoint or csv, so a restart loses at most one evaluation. A finished stage leaves <tag>_done.txt and is skipped when the whole pipeline is started again, so after
# a reboot or a closed terminal the same command continues where it stopped.
# Files in scratch/jobs (not committed): <tag>_try<k>.log, <tag>_done.txt, <tag>_failed.txt, resume.log (one line per start, wait and kill, to see why a job is late).
# - kills the process of the same job if it stays alive after MATLAB returned (heap corruption at exit leaves 2 GB) by its unique -batch text (kill_job.ps1).
# NEVER kill MATLAB by name: other frames run jobs on the same machine (this happened on 2026-10-16). The machine holds about 3 MATLAB at once.
JOBS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$JOBS_DIR/../.." && pwd -W 2>/dev/null || (cd "$JOBS_DIR/../.." && pwd))"
S="$REPO/scratch/jobs"; mkdir -p "$S"
START_GB=${START_GB:-5}
MAX_TRIES=${MAX_TRIES:-400}

free_gb() { powershell -NoProfile -ExecutionPolicy Bypass -File "$JOBS_DIR/headroom.ps1" | tr -d '\r'; }
log() { echo "$(date '+%F %T') $*" >> "$S/resume.log"; }
wait_mem() {
  local waited=0
  while [ "$(free_gb)" -lt "$START_GB" ]; do
    [ $waited -eq 0 ] && log "$1 waits for memory (headroom $(free_gb) GB, needs $START_GB)"
    waited=1; sleep 45
  done
  [ $waited -eq 1 ] && log "$1 memory available (headroom $(free_gb) GB)"
}

run_job() {
  tag=$1; expr=$2; marker=$3
  if [ -f "$S/${tag}_done.txt" ]; then return 0; fi
  rm -f "$S/${tag}_failed.txt"
  for i in $(seq 1 "$MAX_TRIES"); do
    wait_mem "$tag"
    export TEMP='D:\MatlabTemp' TMP='D:\MatlabTemp'
    log "$tag start try $i"
    "/c/Program Files/MATLAB/R2023a/bin/matlab" -softwareopengl -batch "run('$REPO/Model/setup_paths.m'); $expr" > "$S/${tag}_try$i.log" 2>&1
    KILLMARK="$expr" powershell -NoProfile -ExecutionPolicy Bypass -File "$JOBS_DIR/kill_job.ps1"
    if grep -q "$marker" "$S/${tag}_try$i.log"; then echo done > "$S/${tag}_done.txt"; log "$tag done (try $i)"; return 0; fi
    log "$tag try $i ended without the done text (killed or crashed); will wait for memory and resume"
    sleep 30
  done
  echo failed > "$S/${tag}_failed.txt"; log "$tag FAILED after $MAX_TRIES tries"; return 1
}
