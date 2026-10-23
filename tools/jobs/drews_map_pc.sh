#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/job_lib_patient.sh"
run_job_patient "d4_Map" "load_map; run_scoring_seeds('Map', 99995:99999); disp('D2_DONE')" "D2_DONE"
echo done > "$S/d4_done.txt"
