# Nhật ký khung PARETO-LAPTOP

Vai: khung chạy trên laptop (32 GB), chạy pha 1 và pha 2 và margin cho MapPID (182 điểm) trong so mặt Pareto ba bộ trên CALIB v2, seed chung 99990-99994. Tài liệu kế hoạch: Documents/Shared/KeHoach_SoMatPareto.txt (mục 0, 2.3-2.6, 3). Không viết mã so sánh (PC viết, nhánh auto/pareto-common, CODE_READY.txt); không push main.

## TRẠNG THÁI HIỆN TẠI
- Chờ CODE_READY.txt trên origin/auto/pareto-common (vòng chờ nền, tối đa 5 giờ).

### Lượt 1 - Khởi động (2026-10-22)
- git pull origin main xong, tới d32eef8 (kế hoạch bản có mục 3). Commit ed9e724 nêu trong lệnh KHÔNG có trong repo local/origin; coi bản kế hoạch có mục 3 là Bản 2, ghi để người dùng biết.
- Dừng guard_ram.ps1 cũ (PID 27580). Hai MATLAB đang chạy (18672, 20264) là máy chủ ngôn ngữ MATLAB của VS Code, không phải pipeline; giữ nguyên. Không có timer/tác vụ nào khác. RAM trống 14.2/31.6 GB.

### Lượt 2 - Kiểm môi trường trong lúc chờ (2026-10-22)
- MATLAB R2023a chạy được (MATLAB_TEMP = TEMP = TMP = C:\MatlabTemp). mappid_eval cho điểm đã chọn trong mappid.json ở seed 30000: R 2.421503133 (sai lệch tương đối 1.6e-10), S 0.7925522414 (5e-11) so với MapPID_CALIB_pick_s30000.csv; x khớp tuyệt đối. VERIFY PASS. Một mô phỏng mất 80 s (lần đầu gồm nạp), cần ước lại thời gian ở lô lớn.
- Lưu ý: lệnh bao nohup ... & rồi thoát làm chết vòng chờ; chạy script chờ trực tiếp bằng run_in_background (scratch/wait_code_ready.sh, 5 phút/lần, 5 giờ).

### Lượt 3 - CODE_READY, bắt đầu pha 1 (2026-10-22)
- CODE_READY.txt (11:56) trên origin/auto/pareto-common, commit 376cd0a; SHA-256 compare_pareto_common.m 7102adf6... Kế hoạch đã là Bản 2 (ed9e724 nằm trên nhánh pareto-common; MapPID dự tuyển 211 điểm, pha 1 = 38 điểm). Tạo nhánh auto/pareto-common-laptop từ origin/auto/pareto-common.
- Viết tools/jobs/pareto_laptop_pipeline.sh (phase1|phase2|margin; 4 worker; job_lib_patient; margin lặp vòng + 'front' tới khi không còn điểm treo). Bật guard_ram.ps1 (PID 5868), MATLAB_TEMP=C:\MatlabTemp. Chạy phase1.

### Lượt 4 - Xong pha 1 (2026-10-22 12:38)
- Pha 1 MapPID: 38 điểm x 5 seed = 190 mô phỏng, 4 worker, khoảng 43 phút (khoảng 50 s/mô phỏng khi chạy 4 song song). Worker 4 bị dừng một lần (try 2 lúc 12:07, job_lib_patient tự chạy lại); csv có 194 dòng dữ liệu, 4 dòng trùng do chạy lại, hàm đọc bỏ trùng. Tạo PHASE1_DONE.txt, commit, push; chạy pha 2 (173 điểm).
