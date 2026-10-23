# Lịch sử repo: máy nào làm gì

File này do `tools/update_repo_history.py` cập nhật (phần tự động đọc từ git log; phần ghi chú tay ở cuối). Laptop và PC dùng chung một file qua main.

<!-- AUTO-BEGIN (tools/update_repo_history.py rewrites everything up to AUTO-END) -->

## Máy

- PC (máy bàn chính, tên máy DESKTOP-G6T192V): chạy phần lớn mô phỏng và viết bài; nhánh làm việc cuối cùng đã gộp vào main.
- laptop: chạy song song phần việc chia cho nó (MapPID, một nửa Map và PID khi so mặt Pareto chung), thường đẩy lên nhánh phụ rồi gộp.
- Commit trước 2026-10-22 chưa ghi máy (hiện "?"): lúc đó làm trên một máy; từ nay mọi commit có tag [PC] hoặc [laptop] ở đầu (tools/sync_repo.sh tự thêm).

## Lịch sử commit theo ngày (mới nhất trước; sinh tự động từ git log, 112 commit)


### 2026-10-23 (? 2, PC 17, laptop 7)

- 16:27 a98784b [PC] SSW (STEADY, SLIP, WEAVE) run on three controllers, SLIP v4, DREWS v3 plan and lock, repo_history and sync tools, cleanup of old scripts
- 12:13 2672ac7 [PC] DREWS v3 rerun on the final designs: summary tables and black-and-white figures
- 10:37 3403405 [PC] DREWS v2 all three controllers: combined long csv
- 04:36 3cc28d2 [PC] Pareto common PC: P6 report, figures, section 16, final done
- 04:35 bcd2769 [PC] Pareto common PC: DREWS v2 on final designs (P5), figures with final designs
- 04:25 a215c15 [PC] Pareto common PC: margins complete, final designs selected and written to json (P3, P4)
- 04:15 379aaa6 [laptop] Merge laptop L1 (Map tail margins)
- 04:15 b08946f [PC] Pareto common PC: P2 tail margins
- 04:02 1e53d4f [PC] Pareto common PC: P1 margin results
- 03:08 01051c6 [laptop] Pareto common (laptop): L1 Map tail margin done (17 points, 17 pass), MT_LAPTOP_DONE
- 03:02 bdeddda [PC] Pareto common PC P0: margin Mode/Rmax/Rmin/List, taillist, select; M_GO
- 02:58 ec10293 [laptop] Merge remote-tracking branch 'origin/auto/pareto-common' into auto/pareto-common-laptop
- 02:54 028de3b [?] Two-machine plan: final design picked on the common-seed fronts, then DREWS v2; prompts for two new frames
- 02:53 94dd284 [laptop] Pareto common (laptop): log L1 start
- 02:41 4b649a6 [PC] Pareto common PC: log turn 10 (overnight plan outline)
- 02:38 b690b81 [PC] Pareto common PC: stopped and cleaned unintended margin run
- 02:29 e797d04 [PC] Pareto common PC: log turn 8
- 02:22 79b6f2d [PC] Pareto common PC: log turn 7
- 02:18 33a4b40 [?] Add KeHoachMatlab.txt: run history, scripts, division of work, cleanup list
- 02:11 65e2adc [PC] Pareto common PC: status after phase 2, margin plan
- 02:05 3877408 [PC] Pareto common PC: phase 2 done, new search-flow figure
- 01:11 b37b361 [laptop] Pareto common (laptop): phase 2 (workers 7-10) done, P2_LAPTOP_DONE
- 00:38 86869a2 [laptop] Pareto common (laptop): merge P2_GO, start phase 2; log
- 00:40 14a9885 [PC] Pareto common PC: P2_GO (phase 1 complete on both machines)
- 00:40 729ace8 [laptop] Merge origin/auto/pareto-common-laptop (phase 1 Map/PID workers 7-10); marker files: laptop version
- 00:39 061ac84 [PC] Pareto common PC: phase 1 done on PC

### 2026-10-22 (? 15, PC 6, PC+laptop 1, laptop 7)

- 23:33 7e74177 [laptop] Pareto common (laptop): phase 1 of Map and PID (workers 7-10) done, P1_LAPTOP_DONE
- 23:07 72f17c8 [PC] Pareto common PC: paused by user request
- 23:04 6dfbe4e [PC] Pareto common PC: log, stopped duplicate ids 7-10
- 22:59 72b660a [PC] Pareto common PC: progress, take ids 7-10 locally
- 18:16 500874a [PC] Pareto common PC: stop for two-machine Map run; pipeline ids and sync points; csv snapshot
- 18:13 6daeff8 [laptop] Pareto common (laptop): pipeline honours MATLAB_TEMP from the environment (no D drive on the laptop); log
- 17:38 d7f1a70 [laptop] Merge origin/auto/pareto-common-laptop (MapPID 211 points x 5 seeds, margin, MAPPID_DONE)
- 17:38 c8aa6c4 [PC] Pareto common PC: progress snapshot (PID phase 1, Map)
- 17:05 de36752 [laptop] Pareto common (laptop): MapPID margin done, MAPPID_DONE; fix aggregate size error in compare_pareto_common.m line 162
- 16:29 51cf326 [?] Pareto common: amendment A (noise-band set, 6 workers), code and plan
- 15:51 914aa71 [laptop] Pareto common (laptop): MapPID phase 2 done (211 points x 5 seeds), log
- 15:24 29effb6 [PC] Pareto common PC: partial Map results, pipeline script, log
- 12:38 94e2bff [laptop] Pareto common (laptop): MapPID phase 1 done (38 points x 5 seeds), pipeline script, log
- 11:56 376cd0a [?] Pareto common: compare_pareto_common.m, figure script, check 2.3 PASS, CODE_READY
- 11:29 ed9e724 [?] Plan v2: background-script waiting for cross-machine handoff
- 11:27 d91d3b8 [laptop] common log: laptop waiting mechanism for Pareto comparison
- 11:26 7a76e92 [?] Plan v2 content (previous commit kept v1 text by mistake): one candidate rule for all controllers
- 11:25 70c2b36 [?] Plan v2: common-seed Pareto comparison with one candidate rule for all three controllers
- 11:16 d32eef8 [PC+laptop] Plan: split common-seed Pareto comparison across PC (Map, PID) and laptop (MapPID)
- 11:13 fa93734 [?] Plan: common-seed Pareto front comparison of Map, PID, MapPID on CALIB v2 (seeds 99990-99994)
- 02:50 6f9d9c0 [?] MapPID plug-in: DREWS v2 seeds 99995-99999 done, summary, log
- 02:41 cfe11f7 [?] Merge origin/auto/drews-v2 (DREWS v2 locked) into auto/mappid-plug
- 02:41 c615d4b [?] MapPID plug-in: D and C done, report, log
- 02:23 55587d3 [?] MapPID plug-in: grid P1B1 done (598 points) and PID block chosen; fix run_mappid_plug_dc
- 01:33 6e5bfe4 [?] DREWS v2: PID and Map run on seeds 99995-99999 (Cases_v2), summary, log
- 01:12 e8cdefd [?] DREWS v2: five 60 s scoring cases, new report-only metrics, lock file (cases frozen)
- 00:57 091da63 [?] MapPID plug-in (PhuongPhap 15): run, select, check, D/C scripts, pipeline; MATLAB_TEMP override
- 00:53 f1ad837 [?] Plans for overnight runs: MapPID plug-in on fixed Map (section 15), DREWS v2 overnight operation
- 00:48 abdd4c1 [?] update 22-10

### 2026-10-20 (? 9, laptop 1)

- 23:13 b7d62bb [?] MapPID: hand off stopped S1 attempt and resilient runner
- 11:06 00aa4ac [?] Audit complete Map2 margin failure and avoid empty margin pools
- 10:57 abade76 [?] Preserve completed independent Map2 grid and verified recovery history
- 10:40 10b6c46 [?] Recover native MATLAB crashes per worker without stopping healthy peers
- 10:34 f761c97 [?] Use RAM-sized ordered margin pools and verify six-variable selection
- 10:25 14ee16f [?] Validate six-variable handoff provenance and clean orphaned batch engines
- 10:21 43f52af [?] Record five-worker launch and report six-variable starting regions
- 10:19 42ad506 [?] Add independent Map2 and MapPID6 search with resumable desktop handoff
- 02:18 54b1264 [?] Automate desktop S2 with ten percent RAM reserve
- 01:03 d2ef81d [laptop] Automate desktop Map handoff and laptop S1 to S2 continuation

### 2026-10-19 (? 2)

- 23:08 d895168 [?] MapPID: make S2 handoff resumable
- 19:45 9c2f161 [?] update mappid scan

### 2026-10-18 (? 4)

- 17:20 fc52156 [?] MapPID: state before the restart from scratch (e_max 5 percent, 250 evaluations per chain, partial extension to 450 of chain 1; patternsearch dropped from selection pool)
- 10:41 44eb6fd [?] Logs: common turns 94-102, MapPID log; rule: write the log before committing
- 10:37 979abfd [?] Remove stray Fig4_pareto copies from the repo root (the maintained version is Figures/matlab/Fig4_pareto_package)
- 10:37 9625465 [?] CALIB v2 runs: Map, PID, MapPID tuned with the common optimisation method; paper/intro drafts, new figures, references

### 2026-10-17 (? 1)

- 10:18 e344b34 [?] Common multi-seed selection method: MapOpt run 2, MapPIDOpt, PIDOpt, DREWS on 5 scoring seeds, report

### 2026-10-16 (? 4)

- 17:38 a95a8a9 [?] Log: MapOpt name collision with the MapPID frame plan
- 17:38 fbd74d4 [?] MapOpt (Map re-optimised with the MapPID method), cross-seed CALIB table for Map, MapOpt, PID, PIDOpt, MapPID
- 15:03 83af5d9 [?] Snapshot before re-running Map, PID, MapPID with the simultaneous-optimisation method: PIDOpt, PIDLag, MapPIDLag work, QuyChuan and notes updates
- 14:51 ddb9224 [?] Paper drafts v6-v7 and figures for Map, PI, PID selected by the grid-sweep method

### 2026-10-14 (? 1)

- 02:17 2990a94 [?] add paper

### 2026-10-12 (? 1)

- 23:54 fcc3ae4 [?] Commit the work of the Map, PI, PID, SMC frames and the paper draft

### 2026-10-10 (? 6)

- 14:48 389508f [?] Snapshot before renaming CALIB/DRY/SLIP/WEAVE (work of the three frames)
- 10:26 3e1bb2a [?] Give PI its own color in compare plots, regenerate Map vs PI/SMC/ISMC comparisons and outline docx
- 09:47 63bcc49 [?] Add thesis and paper outline docx with current results
- 09:44 9bd39b0 [?] Add Architect_new.drawio: full closed-loop architecture (general controller using all measured signals)
- 09:19 d2efdcc [?] Update SMC, add ISMC, PI/Map test-case results, tracking logs
- 08:15 af84d5b [?] clean up

### 2026-10-07 (? 2)

- 23:40 1d15600 [?] Refactoring
- 01:44 343c746 [?] update pi 2k and map 2k

### 2026-10-04 (? 1)

- 23:14 89ac4aa [?] Snapshot before rebuilding the closed-loop framework (Plant -> Sensors -> controller -> Actuator)

### 2026-10-03 (? 1)

- 01:09 1ac7e2e [?] update word

### 2026-10-02 (? 4)

- 19:29 360767a [?] Compare Map, PID and SMC pairwise under combined sensor noise
- 18:40 ca91f8f [?] Compare Map/PID/SMC per test case under sensor noise (level high)
- 17:03 7949f7f [?] Add per-case Map/PID/SMC comparison charts (T_s, e_T, T_a)
- 16:47 8c8dd3d [?] update sensor

### 2026-09-29 (? 1)

- 00:28 f4c71b7 [?] update map

### 2026-09-26 (? 1)

- 03:23 9e44866 [?] update PID model

### 2026-09-24 (? 1)

- 02:35 a84f253 [?] update plant

### 2026-09-23 (? 1)

- 01:18 7d0259a [?] update cum 1 thanh xoan

### 2026-09-18 (? 2)

- 22:55 c9f89b5 [?] update doc
- 21:26 a952554 [?] update plant and ref

### 2026-09-12 (? 2)

- 02:50 7e8b075 [?] update model
- 02:50 0291112 [?] update code

### 2026-09-09 (? 1)

- 00:45 a07cdad [?] update all plant s-func

### 2026-09-08 (? 1)

- 00:38 265d7a3 [?] update s-func steering

### 2026-09-05 (? 4)

- 09:50 2c73aa6 [?] update pacejka model
- 09:07 5277025 [?] update model
- 00:37 f1f72e6 [?] update json
- 00:25 584377d [?] Update USC, TB, AM

### 2026-09-04 (? 2)

- 23:07 889ba6f [?] add references
- 20:10 cc54c7a [?] Update USC and TB

### 2026-08-27 (? 1)

- 22:54 59b8563 [?] no message

### 2026-08-22 (? 1)

- 00:33 266e4d5 [?] update note

### 2026-08-21 (? 1)

- 23:12 c8afe75 [?] init

### 2026-08-10 (? 1)

- 21:57 f5957e6 [?] Initial commit

<!-- AUTO-END -->

## Ghi chú tay (ai chạy gì, file kết quả ở đâu; thêm bằng --note)
- 2026-10-23 16:27 [PC] Gộp toàn bộ vào main, xóa nhánh phụ; thêm tools/update_repo_history.py và tools/sync_repo.sh. SSW (ba ca STEADY, SLIP, WEAVE) chạy xong trên PC: Result/Controllers/<Ctrl>/Cases_ssw/, tóm tắt Result/Compare/SSW_summary/.
