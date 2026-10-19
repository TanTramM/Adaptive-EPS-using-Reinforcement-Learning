#!/bin/bash
# PATIENT job runner (2026-10-17): like job_lib.sh run_job, but it never gives up because of a shortage of resources.
#   source tools/jobs/job_lib_patient.sh ; run_job_patient <tag> "<matlab expression>" "<ok marker in the log>" ["<failure marker in the log>"]
# Why: other frames (and the user's own programs) share the 32 GB machine, and guard_ram.ps1 stops the newest MATLAB when free RAM falls below 3 GB. run_job gives up after 8 tries.
# What this one does:
#  - waits (no limit) until the memory headroom is at least START_GB (default 6: one MATLAB takes about 2.3 GB and the guard stops at 3 GB free) before every start;
#  - a MATLAB that ends WITHOUT the ok marker and WITHOUT a MATLAB error (killed by the guard, crash 0xffffffff, closed by hand) is not a failure of the job: wait with a growing pause
#    (60 s, 120 s ... at most 10 min) and start again; the solvers resume from their checkpoint files and every evaluation is cached in a csv, so no work is lost;
#  - a MATLAB that ends with a genuine MATLAB error (log has "Exit Status: 0x00000001" or the failure marker) counts as a real failure; after MAX_REAL_FAIL (default 3) of them the job stops
#    with <tag>_failed.txt and the supervisor stops, so a bug is reported instead of repeated for hours;
#  - markers: <tag>_done.txt, <tag>_failed.txt; log of every try <tag>_try<k>.log; one status line in <tag>_status.txt (time, try, state) for monitoring. All in scratch/jobs (not committed).
# NEVER kill MATLAB by name (other frames); the leftover process of a finished job is stopped by its unique -batch text (kill_job.ps1), as in run_job.
source "$(dirname "${BASH_SOURCE[0]}")/job_lib.sh"
START_GB=${PATIENT_START_GB:-6}
MAX_REAL_FAIL=${MAX_REAL_FAIL:-3}

status() { echo "$(date '+%Y-%m-%d %H:%M:%S') try=$2 $3" > "$S/${1}_status.txt"; }

run_job_patient() {
  local tag=$1 expr=$2 marker=$3 failmark=${4:-__no_failure_marker__}
  [ -f "$S/${tag}_done.txt" ] && return 0
  local i=0 real=0 pause=60
  while true; do
    i=$((i + 1))
    status "$tag" "$i" "waiting for memory (need ${START_GB} GB headroom, now $(free_gb))"
    wait_mem
    status "$tag" "$i" "running"
    export TEMP='D:\MatlabTemp' TMP='D:\MatlabTemp'
    "/c/Program Files/MATLAB/R2023a/bin/matlab" -softwareopengl -batch "run('$REPO/Model/setup_paths.m'); $expr" > "$S/${tag}_try$i.log" 2>&1
    KILLMARK="$expr" powershell -NoProfile -ExecutionPolicy Bypass -File "$JOBS_DIR/kill_job.ps1"
    if grep -q "$marker" "$S/${tag}_try$i.log"; then
      echo done > "$S/${tag}_done.txt"; status "$tag" "$i" "DONE"; return 0
    fi
    # MATLAB/Simulink can terminate with the Windows heap-corruption status
    # after many simulations even when RAM headroom is healthy.  CSV/checkpoint
    # caching makes an immediate clean process restart safe; do not let this
    # known process-level crash inherit the growing resource-pressure backoff.
    if grep -q "Exit Status: 0xc0000374, Heap corruption" "$S/${tag}_try$i.log"; then
      status "$tag" "$i" "heap corruption; cached work kept, restarting in 60 s"
      sleep 60
      pause=60
      continue
    fi
    if grep -q "$failmark" "$S/${tag}_try$i.log" || grep -q "Exit Status: 0x00000001" "$S/${tag}_try$i.log"; then
      real=$((real + 1)); status "$tag" "$i" "real MATLAB error $real of $MAX_REAL_FAIL"
      if [ "$real" -ge "$MAX_REAL_FAIL" ]; then echo failed > "$S/${tag}_failed.txt"; status "$tag" "$i" "FAILED (see ${tag}_try$i.log)"; return 1; fi
      sleep 30
    else
      status "$tag" "$i" "interrupted (killed or no memory), waiting ${pause} s"
      sleep "$pause"; pause=$((pause * 2)); [ "$pause" -gt 600 ] && pause=600
    fi
  done
}
