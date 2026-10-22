# Nhật ký khung PARETO-PC (PC, chạy không người)

Vai: viết duy nhất mã so mặt Pareto (Model/Sim/script/compare_pareto_common.m, tools/make_fig_pareto_common.py), chạy Map và PID, gộp MapPID từ laptop, vẽ hình và bảng.
Tài liệu kế hoạch: Documents/Shared/KeHoach_SoMatPareto.txt (BẢN 2). Nhánh: auto/pareto-common. Không push main.

### Lượt 1 - Khởi động, mã, kiểm 2.3 (2026-10-22)
- Lỗi quy trình: worktree dùng chung với khung COMMON; COMMON đã commit kế hoạch bản 2 (ed9e724) lên chính nhánh auto/pareto-common, tôi lỡ `git branch -f` về main nên mất tham chiếu; đã khôi phục bằng `git merge --ff-only ed9e724`. origin/main chưa có ed9e724, nhưng nhánh của tôi có.
- Viết compare_pareto_common.m (lệnh candidates, check, run, margin, front, status) theo bản 2: tập chung = simulated=1 và c1,c2,c3<=0; hai mặt (an toàn, đủ cổng); margin chỉ cho điểm trên mặt, lặp loại; csv worker; chạy tiếp được nhờ cache của hàm đánh giá.
- Lỗi mã đã sửa: (1) đường dẫn pick csv của Map nằm ở Grid2; (2) công cụ shell diễn giải `\n` trong chuỗi python nên fprintf bị cắt dòng: sửa bằng Edit; (3) check chạy cả ba bộ trong một MATLAB bị heap corruption: chạy từng bộ một.
- Kiểm 2.3: tập dự tuyển Map 149, PID 168, MapPID 211 đúng. Điểm chọn chạy lại không cache: Map R 12.05278142 S 0.4398394343 (sai lệch 3e-10, 5e-11); PID R 2.922458093 S 0.8504937088 (1e-11, 5e-11); MapPID R 2.421503133 S 0.7925522414 (2e-10, 5e-11); Map block của mọi điểm MapPID = map.json (độ lệch 3.6e-12). PASS.
- Pha 1 (mặt của tập dự tuyển ở seed tìm): Map 75, PID 46, MapPID 38 (tổng 159).
