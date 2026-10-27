# Nhật ký khung PIDBOOK-PC (PC DESKTOP-G6T192V, chạy không người qua đêm, bắt đầu 2026-10-27 tối)

Vai: khung PIDBOOK-PC. Làm các bước P0-P9 của mục 6.3 và phần giúp MapPID ở 6.4 trong `Documents/Shared/KeHoach_PID_Sach.txt` (thiết kế lại khâu PID theo sách Åström-Hägglund, chạy lại bằng code mới).
Đọc kèm: Tracking/CLAUDE.md (một nhánh main; KHÔNG lập luận dựa trên lần chạy trước), Documents/Shared/KeHoach_SoMatPareto.txt (Sửa đổi A và B), historychat_common.md Lượt 240-247.
Chỉ sửa và commit file của PC (mục 6.1). Nhật ký này chỉ khung PIDBOOK-PC ghi.

## TRẠNG THÁI HIỆN TẠI
(cập nhật ở cuối mỗi mục)

## NHẬT KÝ

### Bước P0 (2026-10-27 tối)
- git pull origin main (đã mới nhất), commit "[PC] PID book redesign plan and paper edits" (kế hoạch, paper.txt, References.txt, Tracking/*.md, các file paper_ENG/VN), tạo cờ Result/Compare/Pareto_common/PIDBOOK_PLAN_PUSHED.txt, push main (commit b24c77e). Ổ C trống 114 GB, ổ D 657 GB.

### Bước P1
- Chuyển (git mv, không xóa) kết quả cũ của PID sang Legacy_2026-10-27/ cùng chỗ: Result/Controllers/PID/Calib_v2, Result/Controllers/PID/Cases_ssw, và 37 file ParetoCommon_PID_* trong Result/Compare/Pareto_common. Không đụng file của Map và MapPID.

### Bước P2 (code PID theo mục 6.2)
- pid_u2x.m / pid_x2u.m: u (4 chiều) -> (K, Ti, Td, N) theo hộp mục 2.3 (K 0.01-30, Ti 2 ms-10 s, Td 20-796 ms, N 8-20, thang log) -> (Kp = K, Ki = K/Ti, Kd = K Td, Tf = Td/N); x2u làm ngược lại.
- pidlag_variables.m: với ctrl = 'PID', K_aw = sqrt(Ki/Kd) (= 1/sqrt(Ti Td)); PIDOpt, PIDLag giữ Ki/Kp. load_pid.m dùng cùng công thức (bỏ trường Kaw trong json).
- pidlag_eval.m (ctrl = 'PID'): kiểm Td < Ti (Kd Ki < Kp^2) ở đầu; vi phạm thì ghi dòng simulated = 0, c = [0 0 1 0], không mô phỏng. Thêm cùng cờ c3 cho cổng dải lái của QuyChuan 6.2 (Tf = Td/N <= 79.6 ms, độ lợi >= 0.707 tại 2 Hz). LÝ DO: kế hoạch mục 2.3 viết cận Td 796 ms với lý do "Td/N <= 79.6 ms ở N = 8", nhưng 796/8 = 99.5 ms; góc hộp (Td lớn, N nhỏ) vi phạm chính cổng đó. Giữ nguyên hộp, thi hành cổng bằng cờ (không đổi lưới, hộp). Laptop (mappid_eval) có thể chưa có cổng này: góc hộp khác nhau giữa hai bộ, báo ở bảng sáng.
- pid_grid_spec.m đã là 4 biến (Kp, Ki, Kd, Tf), mức thô [0 1/3 2/3 1] (N = 8, 10.9, 14.7, 20), 3^4 điểm mỗi lớp mịn: không cần đổi.
- test_pid.m: K_aw = sqrt(Ki/Kd); bộ khung thử nối T_a_lim = bão hòa(±1.2 N.m) của T_a trễ một mẫu nên chạm giới hạn thật (4894 trên 6001 mẫu); kiểm lim = sat(T_a trễ). KẾT QUẢ: TEST PASS, sai lệch lớn nhất 1.78e-15 N.m.

### Bước P3 (kiểm tất định Map, xong 03:00)
- CALIB, điểm thiết kế của map.json (K = Kmax = 6.77455, g_min = 0.707107) ở seed 99990, chạy lại map2_eval: R 12.09111, S 0.4398256, TV 122.919, e_rel 26.0406 trùng file cũ (sai lệch tương đối R 1.9e-10, S 1.8e-11).
- SSW Map seed 99987 chạy lại (sao lưu thư mục Cases_ssw, chạy, so, khôi phục): 34 dòng, sai lệch lớn nhất trên mọi ô số = 0. Kết luận: mô phỏng của Map tất định, số cũ của Map dùng được. Git của Map sạch (không file Map nào đổi).

### Bước P4 bắt đầu (02:55)
- Pipeline tools/jobs/pidbook_pc.sh chạy nền (pid.json: thiết kế cũ chuyển vào trường legacy; worker lưới 1-3 từ 02:55, worker 4 sau P3). Phát hiện: marker pid_grid_w[1-3]_done.txt của lần cũ làm run_job_patient bỏ qua worker, đã xóa trước khi worker chạy.

### Bước P4 xong (03:33)
- Lưới PID seed 10000, 4 worker, thô 4^4 = 256 điểm rồi 6 lớp mịn: 434 điểm đánh giá (khác nhau), 184 điểm được mô phỏng, 111 điểm đạt mọi cổng (tuyến tính + e_rel), J = R x S nhỏ nhất 2.46772. Các điểm còn lại bị loại trước mô phỏng (Td >= Ti, Tf > 79.6 ms hoặc không qua cổng PM, GM). Không lỗi thực thi.

### Bước P5 xong (03:45)
- select_pid_pareto(true): 434 đánh giá, 184 mô phỏng, 111 khả thi, 34 điểm Pareto; điểm chọn tạm J = 2.49667 (R 3.11044 %, S 0.802673 N.m), PM 49.14 độ, GM 6.24. Báo cáo năm seed 10001-10005: J 2.54897 +- 0.08173, e_rel lớn nhất 1.958 %; margin ratio gain 0.693, delay 1.041 (cổng margin ở seed 10001 đạt). Điểm tạm đã ghi vào pid.json; thiết kế cũ chỉ còn trong trường legacy.
- Cảnh báo Simulink về khối Delay_ctrl (vòng đại số) trong log là cảnh báo cũ, vô hại.

### Bước P6 pha 1 và pha 2 xong (04:28 và 05:47)
- compare_pareto_common('run', {'PID'}, id, 4, pha) id 1-4, seed chung 99990-99994: pha 1 (điểm trên mặt Pareto ở seed tìm) xong 04:28, pha 2 (điểm còn lại trong dải nhiễu) xong 05:47, không worker nào lỗi. Tiếp theo: các vòng margin + front tới khi hết điểm chờ.

### Bước P6 margin và P7 xong (06:12)
- Tập đánh giá chung: 184 điểm dự tuyển, 134 trong dải nhiễu (sigma_R 0.011, sigma_S 0.0043), 99 qua e_rel ở seed chung. Vòng margin 1 hội tụ ngay (PENDING = 0): mặt an toàn 44 điểm, mặt đủ cổng 31 điểm, KHÔNG điểm nào trượt calib_margin. Mặt thay đổi 0 điểm khi dùng mọi điểm đã đánh giá thay vì tập dải nhiễu (kiểm độ nhạy).
- P7 compare_pareto_common('select', {'PID'}, true): mặt dùng = đủ cổng ("full"); thiết kế cuối (J = R_tb x S_tb nhỏ nhất, hòa 3 % lấy PM lớn nhất): Kp 2.90376, Ki 84.9065, Kd 0.0677100, Tf 1.21127 ms, tức theo sách K = 2.9038, Ti = 34.2 ms, Td = 23.3 ms, N = 19.25, Td/Ti = 0.682, K_aw = 35.41. R_tb 3.2241 %, S_tb 0.77815 N.m, J 2.5089, PM 50.78 độ, GM 6.22, e_rel lớn nhất 2.09 %, margin ratio gain 0.698, delay 1.029. Không nằm trên biên hộp nào (Td 23.3 ms so với cận dưới 20 ms, N 19.25 so với cận trên 20, Td/Ti 0.68 so với 1): ràng buộc Td < Ti không hoạt động.
- Điểm chọn tạm ở P5 (seed tìm) không còn trên mặt nào ở seed chung (R_tb 3.3314, S_tb 0.79889, J 2.6614); quy tắc cũ 5 % trên mặt đủ cổng cho R_tb 2.4202, S_tb 1.245 (chỉ để báo cáo).
- pid.json: bổ sung K, Ti, Td, N và sửa Kaw = sqrt(Ki/Kd) cho điểm cuối (select_pareto, compare select ghi Kaw = Ki/Kp; load_pid bỏ qua trường đó). File ParetoCommon_PID_select*.csv ghi ở namespace PID (bản dùng chung ParetoCommon_select*.csv được khôi phục như cũ vì thuộc laptop).

### Bước P8 xong (06:18)
- run_scoring_seeds('PID', [99987 99988 99989 11001 11002 11003], 'SSW'): 6 seed xong (48-58 s mỗi seed), load_pid in đúng thiết kế mới (Kp 2.904, Ki 84.91, Kd 0.06771, Tf 1.211 ms, Kaw 35.41). Kết quả ở Result/Controllers/PID/Cases_ssw/ (PID_metrics_s*.csv và PID_<ca>_sig_s*.csv). Tóm tắt toàn ca (RMS e_T N.m / S N.m), seed chung 99987-99989: STEADY 0.251 / 0.565-0.570; SLIP 0.206-0.207 / 0.489-0.495; WEAVE 0.198-0.200 / 0.885-0.896. Seed riêng 11001-11003 cùng cỡ (STEADY 0.251-0.254, SLIP 0.206-0.207, WEAVE 0.195-0.201). Dải phân tán giữa các seed nhỏ.

### Bước P9 bắt đầu (06:18)
- Cờ PIDBOOK_MAPPID_GRID_DONE.txt của laptop đã có trên main; pipeline chạy compare_pareto_common('run', {'MapPID'}, id, 8, pha) với id 5-8 (4 worker), pha 1 rồi pha 2.
