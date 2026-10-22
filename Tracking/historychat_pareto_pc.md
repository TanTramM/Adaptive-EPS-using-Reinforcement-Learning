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

### Lượt 4 - Cập nhật 22:58: laptop chưa nhận phần Map, PC tự chạy id 7-10 (2026-10-22)
- Pipeline PC (id 1-6 trên 10 worker, dừng sau pha 1) từ 18:17: 5 trong 6 worker xong, worker 4 chạy lại 16 lần (heap corruption sau vài đánh giá, vẫn tiến). Map pha 1 mới khoảng 59 trên 75 điểm đủ năm seed; PID pha 1 xong. Laptop không có file Map_w7..w10 trên nhánh nên chưa nhận prompt: vị trí 7-10 (mod 10) chưa ai chạy.
- PC khởi động thêm id 7-10 (PARETO_NAME=pcD, dừng sau pha 1) để khỏi chờ. Nếu laptop bắt đầu sau này, nó trùng việc (không hỏng kết quả, chỉ phí).
- Sửa lúc 23:08: laptop thực ra ĐANG chạy id 7-10 (người dùng đưa trạng thái: worker 8 và 9 xong, worker 7 và 10 còn vài điểm Map, còn khoảng 20-60 phút); nhánh laptop chưa push csv tiến độ nên PC không thấy. Đã dừng pcD (id 7-10 trên PC, mới chạy chưa tới 10 phút, không ghi dòng nào) chỉ bằng đúng PID của nó, giữ pcC (id 1-6). Bài học: không kết luận laptop chưa chạy chỉ vì thiếu file trên nhánh; hỏi người dùng trước khi nhân đôi việc.
- Việc kế: chờ worker 4 PC xong và P1_LAPTOP_DONE.txt, gộp csv hai máy, tạo P2_GO.txt, pha 2 cả hai máy.
- 23:10: người dùng cần giải phóng máy: đã dừng pipeline pcC và MATLAB worker 4 (công việc nằm trong csv). Chạy lại: PARETO_NW=10 PARETO_IDS="4" PARETO_STOP_AFTER=p1 PARETO_NAME=pcE bash tools/jobs/pareto_pc_pipeline.sh (guard_ram.ps1 vẫn chạy).
- 23:15: người dùng đã restart máy xong, chạy lại worker 4 (PARETO_NAME=pcE, dừng sau pha 1).

### Lượt 5 - Pha 1, pha 2 xong cả hai máy; kiểm tra và lập kế hoạch margin (2026-10-23, 02:10)
- Pha 1 xong 00:46 (gộp nhánh laptop, chỉ xung đột ở 4 file đánh dấu, lấy bản laptop), P2_GO 00:40, pha 2 xong 02:02 (laptop P2_LAPTOP_DONE). Commit 3877408 đã push; nhánh laptop đã nằm trong nhánh PC.
- Lệnh margin 02:05 bị người dùng từ chối giữa chừng: commit và push đã chạy, pipeline pcG kịp chạy lại pha 1 với NW=6 (không điểm mới, chỉ ghi đè 10 file *_phase1_done.txt) rồi dừng, không có MATLAB nào còn chạy. Đã trả 10 file đánh dấu về bản commit.
- 'front' lúc 02:10: MapPID xong (mặt an toàn 48, mặt đủ cổng 48, 1 điểm trượt margin). Map: 80 điểm trong tập, 17 qua e_rel, margin chờ 72 (mặt đủ cổng 12 nằm trong 72). PID: 105 trong tập, 60 qua e_rel, margin chờ 35 (22 nằm trong 35).
- Ước lượng margin (3 lần mô phỏng mỗi điểm, thời gian lấy từ cột seconds): Map 34.6 giờ CPU, trong đó điểm R0 <= 20 % chỉ 4.8 giờ (25 điểm), 38 điểm có R0 > 50 % chiếm phần lớn; PID 1.6 giờ.
- Nhận xét: điểm có R > 20 % không thể trội hơn điểm có R <= 20 %, nên bảng ở bảy mức R (2.5-20 %) chỉ cần margin của các điểm mặt có R <= 20 %; đuôi R > 20 % chỉ ảnh hưởng hình. Đề xuất chạy margin theo thứ tự R tăng dần (không đổi luật), chờ người dùng duyệt kế hoạch chia hai máy.

### Lượt 6 - Viết Documents/Shared/KeHoachMatlab.txt (2026-10-23, 02:40)
- Người dùng yêu cầu một file tổng hợp: kế hoạch chạy từ đầu, đã chạy gì, dùng file và script nào, mô tả đủ chi tiết để khung chat mới đọc là hiểu, danh sách dọn dẹp, phân công hai máy, tiến độ. Đã tạo Documents/Shared/KeHoachMatlab.txt (9 phần: cách dùng, tổng quan, dòng thời gian, phương pháp hiện hành, từng giai đoạn kèm kết quả, bảng mã, phân công, tiến độ và kế hoạch margin, dọn dẹp, bẫy đã gặp).
- Phần dọn dẹp chỉ là ĐỀ XUẤT: phân loại theo kết quả grep xem file nào còn được file khác gọi; chưa xóa gì. Khung và máy của Linear, Map ghi "—" vì nhật ký đọc được không nêu.
- Chưa làm: mục 16 của PhuongPhap_TimThamSo.txt; chờ người dùng duyệt kế hoạch margin M1/M2.
