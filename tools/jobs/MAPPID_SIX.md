# Independent Map(2) / MapPID(6), 2026-10-20

This profile supersedes the MapPID nine-variable search for new runs requested
on 2026-10-20. Existing Map(5), MapPID(9), laptop S1 and their caches are preserved.
Do not combine their CSV files with this profile. Do not launch the old S2 watcher.

Entry point: `Model/Controllers/MapPID/script/run_mappid_six.m`.
Supervisor: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/jobs/start_mappid_six.ps1 -Stage All -MaxWorkers 5`.
Desktop `All` runs Map2, S2, waits for laptop S1, then selects the combined design.
Laptop runs `-Stage S1` with this NEW six-variable runner, then commits/pushes
SixParam/S1*.csv and S1_summary.mat. Its existing nine-variable S1 is not accepted.
Start `tools/jobs/sync_mappid_six.ps1` hidden on desktop: every 900 seconds fetch
origin/main and fast-forward if incoming files do not overlap local modifications
or untracked files. Conflicts/divergence are logged and deferred, never reset or
stashed automatically. Monitor `scratch/jobs/mappid_six/sync.log`.
Run supervisors hidden when starting from a chat. Only one supervisor owns this
profile at a time. Do not start a second copy on the laptop against these outputs.

## Search fixed before execution

- Map: `[K, g_min]`, K=5..16 logarithmic, g_min=1/sqrt(2)..1 linear.
- MapPID: `[K, g_min, Kp, Ki, Kd, Tf]`. K=0 or 0.1..16; PID bounds and off
  states are identical to the previous nine-variable method.
- For each pair (K,g_min), `design_leadlag` chooses the lead/lag poles and zeros
  with the original deterministic inner design: 68 linear plants, four slopes,
  PM>=45 degrees, GM>=2, minimum high-frequency gain, PM tie breaker, coarse/fine
  grids. g_min is the minimum lag gain at exactly 2 Hz. g_min=1 disables lag.
  K=0 bypasses compensator synthesis and disables Map exactly.
- The inner design is based on the standalone Map plant, independently of PID
  gains. Its output defines the two-parameter family; MapPID is screened again
  with the complete PID+Map controller. Count inner candidates and CALIB runs
  separately when reporting computational cost.
- Outer gates unchanged: PM>=30 degrees, GM>=2, lag gain>=1/sqrt(2) at 2 Hz,
  e_rel<=10%, CALIB v2, gain x2 and delay+1ms margin ratios<=2.
- Grid coarse: 4 levels per free variable; fine: 3 levels, up to six fine layers,
  halve h when the centre is unchanged, stop h<0.02. Use the common grid_search.
- S1: selected PID, K=0, g_min=1. Blocks A=[1,2], B=[3,4,5,6]; A,B,A,B,A,B.
- S2: independently selected Map(2), PID at its near-off lower bounds; B,A,B,A,B,A.
- Stop each start after two consecutive unchanged block scans or six scans.
- Merge both starts for Pareto selection and original margin gates; five seeds
  are reporting only. Legacy DREWS remains disabled.

## Isolated files

- Map: `Result/Controllers/Map/Calib_v2/TwoParam/`
- MapPID: `Result/Controllers/MapPID/Calib_v2/SixParam/`
- Parameter CSVs contain exactly 2 or 6 leading parameter columns.
- Successful selections: `selected.json` and `selection.mat` in each directory.
- Compensator cache: `TwoParam/Compensators/`, atomic per-pair MAT files.
- Runtime: `scratch/jobs/mappid_six/status.txt`, `events.log`, per-worker logs.
- No old Map pick is required. Map calibration is computed without publishing.
- Standard map.json/mappid.json are not overwritten. After completion load this
  profile using `run_mappid_six('loadmap')` or `run_mappid_six('load')` before
  simulating Model_Map or Model_MapPID. Existing load_map/load_mappid still load
  their standard JSON designs, not these isolated selections.

`-Stage Map`, `S1`, `S2`, `Select` support explicit resumption; `All` performs
check/smoke, Map grid/selection, S2, wait for laptop S1, final selection. A Map selection with no
passing margin is reported as a blocker, not retried indefinitely; S1 is still
allowed to run independently on the laptop but S2 waits for a valid Map(2) selection. Never substitute
a nominal-only Map pick or relax gates silently.

Worker count is chosen from available RAM (up to MaxWorkers). Reserve 10% of
physical RAM and consider commit headroom. If the reserve is crossed, stop only
this supervisor's process trees, retain CSVs, reduce worker count and resume.
RAM occupancy depends on current work; do not allocate filler memory to reach
80%. Worker repartitioning is safe because each layer uses all per-tag CSVs.
Selection also uses a RAM-sized margin pool (up to MaxWorkers minus its client).
Only the client writes rejection caches and consumes worker results in ranking
order. `test_mappid_six_selector` verifies a real two-worker rejection/fallback
using synthetic data in a separate temporary directory; it does not simulate
the plant or modify a real pick. Run this test while grid workers are stopped.

Record scientific blockers and any code repairs in Tracking/historychat_mappid.md.
