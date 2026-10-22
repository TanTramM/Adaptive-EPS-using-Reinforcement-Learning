# Nhật ký khung PARETO-PC (PC, chạy không người)

Vai: viết duy nhất mã so mặt Pareto (Model/Sim/script/compare_pareto_common.m, tools/make_fig_pareto_common.py), chạy Map và PID, gộp MapPID từ laptop, vẽ hình và bảng.
Tài liệu kế hoạch: Documents/Shared/KeHoach_SoMatPareto.txt (BẢN 2). Nhánh: auto/pareto-common. Không push main.

### Lượt 1 - Khởi động, mã, kiểm 2.3 (2026-10-22)
- Lỗi quy trình: worktree dùng chung với khung COMMON; COMMON đã commit kế hoạch bản 2 (ed9e724) lên chính nhánh auto/pareto-common, tôi lỡ `git branch -f` về main nên mất tham chiếu; đã khôi phục bằng `git merge --ff-only ed9e724`. origin/main chưa có ed9e724, nhưng nhánh của tôi có.
- Viết compare_pareto_common.m (lệnh candidates, check, run, margin, front, status) theo bản 2: tập chung = simulated=1 và c1,c2,c3<=0; hai mặt (an toàn, đủ cổng); margin chỉ cho điểm trên mặt, lặp loại; csv worker; chạy tiếp được nhờ cache của hàm đánh giá.
- Lỗi mã đã sửa: (1) đường dẫn pick csv của Map nằm ở Grid2; (2) công cụ shell diễn giải `\n` trong chuỗi python nên fprintf bị cắt dòng: sửa bằng Edit; (3) check chạy cả ba bộ trong một MATLAB bị heap corruption: chạy từng bộ một.
- Kiểm 2.3: tập dự tuyển Map 149, PID 168, MapPID 211 đúng. Điểm chọn chạy lại không cache: Map R 12.05278142 S 0.4398394343 (sai lệch 3e-10, 5e-11); PID R 2.922458093 S 0.8504937088 (1e-11, 5e-11); MapPID R 2.421503133 S 0.7925522414 (2e-10, 5e-11); Map block của mọi điểm MapPID = map.json (độ lệch 3.6e-12). PASS.
- Pha 1 (mặt của tập dự tuyển ở seed tìm): Map 75, PID 46, MapPID 38 (tổng 159).

### Lượt 2 - Chạy Map và PID, tiến độ chậm (2026-10-22, 15:25)
- Pipeline tools/jobs/pareto_pc_pipeline.sh chạy từ 11:57 (4 worker 'run' cho {'Map','PID'}, guard_ram bật). Sau 3.5 giờ mới có khoảng 172 trên 745 đánh giá Map (149 điểm x 5 seed), chưa xong pha 1 Map. Nguyên nhân: mỗi đánh giá Map ban đầu mất khoảng 100 s, nay 500-550 s ở các điểm pha 1 (R lớn, mô phỏng chậm); CPU chỉ 38 %, RAM còn 8.6 GB nên không phải thiếu tài nguyên mà do mô phỏng chậm. Ước lượng thô còn nhiều chục giờ cho toàn bộ 528 điểm, vượt xa ước lượng 4-5 giờ của kế hoạch (25-35 s mỗi mô phỏng, không đúng với Map).
- Lỗi thực thi: worker 1 chạy lại 6 lần, worker 2 và 4 hai lần (heap corruption, MATLAB bị dừng); cache csv giữ nguyên công việc. Không đổi số worker (4) và không đổi quy tắc.
- Laptop: PHASE1_DONE.txt đã có trên origin/auto/pareto-common-laptop (13:28).

### Lượt 3 - Sửa đổi A theo người dùng: tập đánh giá theo dải nhiễu, 6 worker (2026-10-22, 16:30)
- Người dùng hỏi vì sao chạy lâu: đo thời gian thật trong csv: Map 100-570 s mỗi đánh giá (K nhỏ chậm; lưới tìm cũ cũng 600-700 s mỗi điểm), PID khoảng 10 s, MapPID khoảng 47 s; nhiễu seed của Map nhỏ (R, S lệch khoảng 0.3 %). Đề xuất A (cùng luật 3 sigma cho ba bộ, giữ 5 seed, thêm worker) và B (3 seed); người dùng chọn A. Ghi vào KeHoach_SoMatPareto.txt mục 3 (Sửa đổi A).
- Mã: runPhase chia theo vị trí trong danh sách pha và bỏ qua điểm đủ năm seed; bandInfo (sigma trung vị trên pha 1, luật loại trội vững); cột in_set; kiểm độ nhạy trong 'front'. Lỗi mã sửa: A.valid dùng [R;S] so với simulated sai kích thước (chưa từng chạy trước đó).
- Dừng pipeline cũ (4 worker, lệnh run mặc định hai pha) bằng cách dừng đúng tiến trình pareto_pc_pipeline và các MATLAB 'run' của nó; công việc nằm trong csv. Pipeline mới tools/jobs/pareto_pc_pipeline.sh (PARETO_NW=6): pha 1 cho PID rồi Map, pha 2 theo dải, rồi các vòng margin và front.
- Laptop: pha 2 MapPID xong 15:51 (211 điểm x 5 seed); còn margin.
