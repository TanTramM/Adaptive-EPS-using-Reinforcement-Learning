#!/bin/bash
# One command for BOTH machines (PC and laptop): pull main, rebuild Tracking/repo_history.md, commit everything with a [PC] / [laptop] tag, push to main.
# usage (repo root, Git Bash): bash tools/sync_repo.sh "what was done" ["optional note for the history file: what was run, where the results are"]
# The machine comes from the host name (PC = DESKTOP-G6T192V, anything else = laptop). Work directly on main, no side branches.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")/.."
msg="$1"; note="$2"
[ -z "$msg" ] && { echo 'usage: bash tools/sync_repo.sh "message" ["note"]'; exit 1; }
if [ "$(hostname)" = "DESKTOP-G6T192V" ]; then m=PC; else m=laptop; fi
py=python; command -v python >/dev/null 2>&1 || py=python3
[ -x "/c/Users/Admin/anaconda3/python.exe" ] && py=/c/Users/Admin/anaconda3/python.exe
git checkout main
git add -A && git commit -q -m "[$m] $msg" || echo "nothing to commit before the pull"
git pull --rebase origin main
if [ -n "$note" ]; then "$py" tools/update_repo_history.py --note "$note" --machine "$m"; else "$py" tools/update_repo_history.py; fi
git add -A && git commit -q -m "[$m] repo_history updated" || true
git push origin main
echo "pushed main from $m"
