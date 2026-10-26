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
