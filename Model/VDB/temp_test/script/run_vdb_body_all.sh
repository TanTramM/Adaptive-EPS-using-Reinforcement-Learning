#!/bin/bash
# Runs the plan Documents/Shared/KeHoach_VDB_ThanXe.txt (V0..V5) in sequence, one MATLAB process per step, resumable.
# Usage: bash run_vdb_body_all.sh [V0]     (V0 = only check the files)
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd -W)"       # repo root, Windows path
RS="$(cd "$(dirname "$0")/../../../.." && pwd)"             # repo root, POSIX path
MLB="/c/Program Files/MATLAB/R2023a/bin/matlab"
TT="$RS/Model/VDB/temp_test"
SUM="$TT/Summary"; mkdir -p "$SUM"
PROG="$SUM/VDB_body_progress.txt"
ERR="$SUM/VDB_body_errors_s99999.txt"
SETUP="run('$ROOT\Model\shared\setup_paths.m'); addpath('$ROOT/Model/VDB/temp_test/script'); addpath('$ROOT/Model/VDB/Plants/script');"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$PROG"; }

ml() {  # ml <tag> <matlab command> : up to 3 attempts
  for n in 1 2 3; do
    "$MLB" -softwareopengl -batch "$SETUP $2" > "$SUM/last_$1.log" 2>&1 && return 0
    log "$1 attempt $n failed"; tail -3 "$SUM/last_$1.log" >> "$ERR"
  done
  return 1
}
csvok() { [ -s "$1" ] && [ "$(grep -c 'whole case' "$1")" -ge 3 ]; }

# V0
miss=0
for f in Plants/Plant_VDBBody.slx Plants/Plant_VDBTireBody.slx Plants/Plant_VDBTireLag.slx; do [ -f "$RS/Model/VDB/$f" ] || { log "V0 missing $f"; miss=1; }; done
for c in Map PID MapPID; do
  for t in VDBBody VDBTireBody; do [ -f "$TT/$c/Model_${c}_$t.slx" ] || { log "V0 missing Model_${c}_$t"; miss=1; }; done
  [ -f "$RS/Result/Controllers/$c/Cases_ssw/${c}_metrics_s99999.csv" ] || { log "V0 missing baseline $c"; miss=1; }
done
[ $miss = 1 ] && { log "V0 FAIL: stop"; exit 2; }
log "V0 ok"
[ "$1" = "V0" ] && exit 0

run_var() {  # run_var <tag>
  for c in Map PID MapPID; do
    f="$TT/$c/Result/${c}_$1_metrics_s99999.csv"
    if csvok "$f"; then log "$1 $c skip (metrics exist)"; continue; fi
    log "$1 $c start"
    if ml "$1_$c" "run_ssw_temp('$c','$1',99999);"; then log "$1 $c done"; else log "$1 $c FAILED after 3 attempts"; echo "$(date) $1 $c failed" >> "$ERR"; fi
  done
}

log "V1 VDBBody"; run_var VDBBody
log "V2 VDBTireBody"; run_var VDBTireBody

# V3 (a)
if [ ! -f "$RS/Model/VDB/Plants/Plant_VDBTireLagBody.slx" ]; then
  log "V3a build Plant_VDBTireLagBody"
  ml V3a "build_plant_variants(false, {'Plant_VDBTireLagBody'});" && [ -f "$RS/Model/VDB/Plants/Plant_VDBTireLagBody.slx" ] || { log "V3a FAIL: stop"; exit 3; }
fi
log "V3a ok"
# V3 (b)
if [ ! -f "$TT/Map/Model_Map_VDBTireLagBody.slx" ] || [ ! -f "$TT/PID/Model_PID_VDBTireLagBody.slx" ] || [ ! -f "$TT/MapPID/Model_MapPID_VDBTireLagBody.slx" ]; then
  log "V3b build loops"
  ml V3b "build_temp_test(false, {'VDBTireLagBody'});" && [ -f "$TT/MapPID/Model_MapPID_VDBTireLagBody.slx" ] || { log "V3b FAIL: stop"; exit 3; }
fi
log "V3b ok"
# V3 (c)
if grep -q "V3c ok" "$PROG"; then log "V3c skip (already ok)"; else
  if ml V3c "check_tirelagbody_wiring();"; then log "V3c ok: $(tail -1 "$SUM/VDB_body_wiring_s99999.txt")"; else log "V3c FAIL (T_s difference > 0.1 or error): V4 blocked"; exit 4; fi
fi

log "V4 VDBTireLagBody"; run_var VDBTireLagBody
log "V5 summary"
ml V5 "summarize_vdb_body();" && log "V5 done: ALL FINISHED" || log "V5 FAILED"
