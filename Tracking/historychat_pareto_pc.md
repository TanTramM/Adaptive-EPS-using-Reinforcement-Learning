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

### Lượt 7 - Giải thích hai lựa chọn của kế hoạch margin (2026-10-23)
- Người dùng hỏi hai lựa chọn là gì, lợi hại, nên chọn cái nào. Trả lời: (1) thêm tùy chọn sắp theo R và giới hạn R vào lệnh 'margin' (chỉ đổi thứ tự và phạm vi, luật không đổi; bảng R <= 20 % chính thức sau khoảng 1 giờ); (2) có chạy đuôi Map R > 20 % (47 điểm, ~30 giờ CPU) hay không. Gợi ý: làm (1); (2) chạy sau khi đã có bảng, trên cả hai máy nếu laptop rảnh, không thì PC chạy một mình qua đêm. Chưa chạy gì, chờ người dùng chốt.

### Lượt 8 - Đề xuất lọc e_rel trước khi chạy margin (2026-10-23)
- Người dùng hỏi có lọc e_rel trước để bớt điểm Map phải kiểm margin không. Đo từ dữ liệu: mặt đủ cổng chỉ chứa điểm qua e_rel nên margin của điểm trượt e_rel không bao giờ ảnh hưởng mặt đủ cổng. Số điểm qua e_rel: Map 17/80 trong tập (tối đa 1.9 giờ CPU, trong đó 12 điểm mặt 1.3 giờ), PID 60/105 (2.9 giờ, 22 điểm mặt 1.2 giờ). Mặt an toàn của Map (72 điểm, 34.6 giờ) gồm phần lớn điểm trượt e_rel. Điểm Map đã chọn (e_rel 26 %) chỉ nằm trên mặt an toàn, không nằm trên mặt đủ cổng.
- Đề xuất: sắp thứ tự, không bỏ: (1) margin cho điểm qua e_rel (mặt đủ cổng, kết luận chính); (2) mặt an toàn Map R <= 20 % (25 điểm); (3) đuôi R > 20 % nếu còn thời gian. Chờ người dùng chốt.

### Lượt 9 - Dừng và dọn lần chạy margin ngoài ý muốn (2026-10-23, 02:40)
- Phát hiện: pipeline pcG (khởi động 02:05 từ lệnh người dùng đã chặn, không đặt PARETO_STOP_AFTER) vẫn sống, chạy lại pha 1-2 rồi từ 02:17 chạy margin với 6 worker MATLAB. Lượt 5 ghi "pipeline đã dừng" là SAI (lúc 02:10 chỉ kiểm danh sách MATLAB, pipeline đang ở bước kiểm nên chưa có MATLAB). Bài học: kiểm cả tiến trình bash của pipeline, không chỉ MATLAB, trước khi báo đã dừng.
- Người dùng yêu cầu dừng hết và dọn. Đã dừng đúng các tiến trình margin và pipeline bằng scratch/kill_pcG.ps1 (không đụng hai MATLAB của VS Code). Đã xóa ParetoCommon_PID_margin_w1-6 và ParetoCommon_Map_margin_w3,4,6 (file mới, chưa commit), trả Result/Compare/Pareto_common về đúng commit (markers phase1_done, Map_points csv), xóa scratch/jobs/pcG_*. MapPID margin csv (đã commit) giữ nguyên. Không còn tiến trình MATLAB của dự án.
- Mã sửa dở, CHƯA commit: compare_pareto_common.m ('margin' nhận 'Mode' và 'Rmax', chạy theo R_tb tăng dần) và pareto_pc_pipeline.sh (PARETO_SKIP_RUN, PARETO_MARGIN_ARGS, điều kiện hội tụ theo phạm vi). Chưa kiểm bằng chạy. Chờ người dùng chốt trước khi chạy margin (lựa chọn A hoặc B ở Lượt 8).

### Lượt 10 - Outline kế hoạch chạy đêm 16 giờ (2026-10-23, 02:55)
- Người dùng đi ngủ, muốn sau 16 giờ các bộ có tham số để chạy DREWS so sánh; yêu cầu outline trước, chưa chạy.
- Ghi nhận: ba điểm đã chọn đã có trong map.json (commit 2026-10-22 00:48), pid.json (10-19), mappid.json (10-22 02:23); Cases_v2 và DREWS_v2_summary của cả ba có sẵn (thời gian file 10-22 10:46 là lúc checkout, chưa xác nhận chạy sau khi json chốt). Margin tối đa: Map <= 80 điểm trong tập (~38 giờ CPU nếu tất cả lên mặt), PID <= 105 (rẻ); 6 worker PC đủ trong khoảng 7-8 giờ.
- Đề xuất: chỉ PC chạy (không đồng bộ laptop ban đêm), một pipeline tự động ba phạm vi: (1) Mode full, (2) Map safe Rmax 20 và PID safe, (3) phần còn lại; rồi front, hình, bảng, báo cáo, commit. Hai câu chờ người dùng: DREWS dùng điểm đã chọn hay chọn lại trên mặt chung; laptop có dùng không.

### Lượt 11 - Người dùng chốt chọn thiết kế cuối trên mặt seed chung; kế hoạch hai máy và prompt (2026-10-23, 03:15)
- Người dùng làm rõ: chưa từng chốt khóa điểm; ý định là chạy hết các phần chọn tham số rồi mới chọn. Ràng buộc "không đổi điểm đã chọn" là do COMMON viết trong KeHoach_SoMatPareto (0(g)). Người dùng "ok" (1) chọn thiết kế cuối bằng J = R_tb x S_tb nhỏ nhất trên mặt đã qua margin (mặt đủ cổng nếu không rỗng, không thì mặt an toàn có nhãn; hòa 3 % lấy PM lớn nhất), (2) ghi đè design trong ba json (sao lưu, design_pre_pareto, test PASS) rồi chạy DREWS v2.
- Đã viết KeHoachMatlab.txt mục 10 (quy tắc chọn 10.1, mã cần sửa 10.2, bảng chia việc P0-P6 cho PC và L1 cho laptop, tín hiệu M_GO.txt, MT_LAPTOP_DONE.txt, SELECT_DONE.txt..., quy tắc vận hành 10.4) và mục 11 (prompt cho hai khung mới); thêm Sửa đổi B vào cuối KeHoach_SoMatPareto.txt. Laptop chỉ làm đuôi Map theo danh sách cố định (id 7-10 của 10), mọi vòng lặp do PC làm.
- Mã margin dở (Mode, Rmax, SKIP_RUN, MARGIN_ARGS) VẪN chưa commit; khung PC mới hoàn thiện ở bước P0. Ghi chú: các dòng Sửa đổi A (mục 3 của KeHoach_SoMatPareto) dài 230-267 ký tự, chưa ngắt lại.

### Lượt 12 - P0: hoàn thiện mã margin, taillist, select; kiểm khô (2026-10-23, khung PARETO-PC chạy tự động)
- Đọc Tracking/CLAUDE.md, KeHoachMatlab.txt (mục 10, 11), nhật ký. Thư mục làm việc có thay đổi của khung khác (Tracking/CLAUDE.md, historychat_common/map, Documents/Paper, các file bị xóa): không đụng, chỉ git add đúng đường dẫn.
- Mã compare_pareto_common.m: 'margin' thêm 'Rmin', 'List' (chia theo vị trí trong file, bỏ điểm đã có margin); lệnh 'taillist' (ghi ParetoCommon_Map_tail_list.csv); lệnh 'select' (10.1: mặt đủ cổng nếu không rỗng, không thì mặt an toàn nhãn "safe, fails e_rel"; J min, hòa 3 % lấy PM lớn nhất; báo điểm mặt kia, điểm tạm cũ, quy tắc 5 % cũ; writeJson sao lưu ra Desktop/Adaptive-EPS_backup_2026-10-23_json_truoc_pareto, giữ design_pre_pareto, dựng struct bằng map2_grid_spec/pid_grid_spec/hàm MapPID). aggregate thêm cột PM, GM (từ csv đánh giá). Pipeline: PARETO_CTRLS, PARETO_ONE_ROUND.
- Kiểm khô: margin Rmax 0 in "0 of 0" (không mô phỏng); front: Map pending 72/12, PID 35/22, MapPID xong (48/48, 1 trượt): đúng số lúc 02:10; taillist 47 điểm (R_tb 28.7-118.6); select khô trên MapPID chạy được (mặt đủ cổng, J 2.0895, điểm tạm cũ J 2.112 nằm trên cả hai mặt). Lần chạy MATLAB thứ hai in "Heap corruption" khi thoát sau khi ghi xong (vô hại, đã biết).
- Lỗi quy trình: heredoc `<<'EOF'` chứa chuỗi MATLAB bị shell làm hỏng: viết script vá bằng công cụ Write.
- Bật guard_ram.ps1. Push M_GO.txt cho laptop.

### Lượt 13 - P1 xong (2026-10-23, 04:02)
- Chuỗi tools/jobs/pareto_night_pc.sh (6 worker, id 1-6): pcP1a (PID và Map, Mode full) 03:03-03:41, hội tụ sau 4 vòng; pcP1b (Map, safe, Rmax 20) 03:41-03:54, 3 vòng; pcP1c (PID, both) 03:54-04:02. Nhanh hơn ước lượng 1-1.5 giờ. Guard RAM dừng MATLAB 3 lần lúc khởi động (RAM 5 GB trống với 6 MATLAB), worker tự chạy lại, không mất kết quả. Cảnh báo "transport delay ... algebraic loop" của Model_PID là quen thuộc, vô hại.
- P2 (đuôi Map, List, id 1-6 trên 10) bắt đầu 04:02.

### Lượt 14 - P2 xong; laptop L1 xong; gộp (2026-10-23, 04:16)
- P2 (đuôi Map, id 1-6 trên 10) xong 04:15 (14 phút, mô phỏng margin nhanh hơn ước lượng nhiều). Laptop: MT_LAPTOP_DONE (17 điểm, 17 pass, ghi giờ laptop 03:08). Gộp origin/auto/pareto-common-laptop.

### Lượt 15 - P3, P4: margin xong, chọn thiết kế cuối, ghi json (2026-10-23, 04:40)
- P3: gộp origin/auto/pareto-common-laptop sạch (chỉ csv margin w7-w10); pcP3 (6 worker) hội tụ vòng 1 (04:15-04:18). 'front': pending 0 cả hai mặt cho ba bộ. Số liệu: Map 149 ứng viên, 80 trong tập, 17 qua e_rel, mặt an toàn 58 (20 trượt margin), mặt đủ cổng RỖNG (cả 17 điểm qua e_rel đều trượt margin); PID 168/105/60, mặt an toàn 35, đủ cổng 22, 0 trượt; MapPID 211/118/117, an toàn 48, đủ cổng 48, 1 trượt.
- P4 (select, ghi json): Map = mặt an toàn, nhãn "safe, fails e_rel", K 6.77455395, g_min 0.707106781 (TRÙNG điểm tạm cũ), R_tb 12.07 S_tb 0.4397 J 5.308; PID = mặt đủ cổng, Kp 3.50257675 Ki 111.317364 Kd 0.108116388 Tf 0.00120006484, R_tb 3.00 S_tb 0.847 J 2.539 (điểm tạm cũ khác ở Tf 0.00144: ở seed chung không ổn định, R=Inf ở 3 trong 5 seed, J 18.6, không nằm trên mặt nào); MapPID = mặt đủ cổng, Kp 1.48352279 Ki 73.68063 Kd 0.0469733968 Tf 0.0020740482, R_tb 2.729 S_tb 0.7656 J 2.0895 (điểm tạm cũ J 2.112, hơn 1 %, cùng trên mặt). Sao lưu json ra Desktop/Adaptive-EPS_backup_2026-10-23_json_truoc_pareto; design cũ trong design_pre_pareto. load + test PASS: Map, PID, MapPID.
- Sửa mã: in báo cáo khi mặt kia rỗng (hàm iff). Lỗi quy trình: gọi test bằng ${c^^} sai tên thư mục (Map/MapPID) và dấu gạch ngược: dùng scratch/p4_test.m.

### Lượt 16 - P5: DREWS v2 trên thiết kế cuối (2026-10-23, 04:36)
- Map: design KHÔNG đổi (cùng K, g_min) nên Cases_v2 và DREWS_v2_Map_summary giữ nguyên (summarize cho ra y hệt). PID và MapPID: sao lưu Cases_v2 cũ ra Desktop/Adaptive-EPS_backup_2026-10-23_Cases_v2_truoc_pareto, chuyển file cũ vào Cases_v2/pre_pareto/, chạy tools/jobs/drews_final_pc.sh (run_scoring_seeds 99995:99999, hai bộ song song) 04:2x-04:34, mỗi seed khoảng 1 phút; summarize_drews_v2.py cho ba bộ.
- Tóm tắt (trung bình năm seed, tổng ca): RMS e_T DRY / SLIP / WEAVE: Map 1.163 / 0.501 / 1.452; PID 0.308 / 0.074 / 0.184; MapPID 0.317 / 0.081 / 0.223. S: Map 0.200 / 0.187 / 0.245; PID 0.647 / 0.558 / 1.055; MapPID 0.406 / 0.366 / 0.631. Map: e_rel +14.9 % (DRY v25a0p25r) và +23-47 % ở EDGE 0.35-0.38 g: đúng nhãn "an toàn, trượt e_rel". Lỗi: lần chạy cuối của MATLAB báo heap corruption khi thoát sau D2_DONE (vô hại).

### Lượt 17 - P6 xong (2026-10-23, 04:50)
- make_fig_pareto_common.py (thêm sao = thiết kế cuối) cho ParetoCommon_safe.png, ParetoCommon_full.png, hai bảng csv; viết mục 16 vào Documents/Shared/PhuongPhap_TimThamSo.txt (quy tắc, số điểm, thiết kế cuối, so điểm cũ, hai bảng S theo mức R, kết luận, DREWS, giới hạn); trỏ kết quả từ KeHoach_SoMatPareto.txt; thêm mục 7.0 vào KeHoachMatlab.txt. FINAL_DONE.txt. Chưa sửa dòng 6 và mục 13.6 của PhuongPhap_TimThamSo.txt (trỏ tới mục 14-16) và chưa xem lại Fig_search_flow_grid: còn treo.
- Toàn bộ P0-P6 xong khoảng 2 giờ sau M_GO, dư nhiều so với mốc 19:00.

### Lượt 18 - DREWS v2 cho cả ba bộ, gộp csv (2026-10-23, 10:40)
- Người dùng muốn DREWS cho cả ba bộ lưu csv để vẽ. Chạy lại Map (design không đổi; bản cũ chuyển vào Cases_v2/pre_rerun/) bằng tools/jobs/drews_map_pc.sh: kết quả giống hệt bản cũ (summary Map không đổi). Viết tools/combine_drews_v2.py: gộp 15 file metrics (3 bộ x 5 seed 99995-99999) thành Result/Compare/DREWS_v2_summary/DREWS_v2_all_runs.csv (540 dòng, cột Ctrl, Seed, Case, Window + chỉ tiêu).

### Lượt 12 - Chạy lại DREWS v3 từ đầu cho ba bộ, tóm tắt và hình trắng đen (2026-10-23, 12:20)
- Phát hiện lúc kiểm: khung khác (COMMON) đã chốt DREWS v3 lúc 11:34 (DREWS_v3_LOCKED.txt, mã băm make_cases và run_cases khớp) và đã chạy ba bộ xong ở Cases_v3. Chưa commit các file v3 của khung đó. Người dùng bảo xóa kết quả khung kia và chạy lại.
- Làm: sao lưu Cases_v3 (3 bộ), DREWS_v3_summary và file trạng thái d5_* ra Desktop/Adaptive-EPS_backup_2026-10-23_DREWS_v3_khung_kia; xóa Cases_v3, DREWS_v3_summary, scratch/jobs/d5*; chạy tools/jobs/drews_v3_pipeline.sh (15 job, 4 song song, thiết kế cuối commit a215c15): 11:56-12:12, mỗi bộ đủ 5 seed x 55 file, một lần heap corruption khi thoát (vô hại, csv đã ghi) và một job chạy lại; không sửa mã.
- Chạy tools/summarize_drews_v3.py (ra DREWS_v3_<Ctrl>_summary, all_runs, slip_delta). File DREWS_v3_windows.csv (bảng cửa sổ, không phụ thuộc kết quả) bị xóa nhầm cùng thư mục, sinh lại bằng scratch/export_v3_windows.m, giống từng byte bản sao lưu. Chạy tools/make_fig_drews_v3_bw.py: 7 hình trắng đen ở Figures/new/main/matlab (Fig_DRY/RAMP/SLIP/EDGE/WEAVE_bw, Fig_SLIP_delta_bw, Fig_DREWS_bars_bw); đã xem DRY, SLIP, WEAVE, delta, bars: không lỗi bố cục.
- Kết quả chính (thiết kế cuối): RMS e_T toàn ca Map 0.89/0.46/0.41/0.95/1.52, PID 0.10/0.06/0.07/0.10/0.19, MapPID 0.12/0.07/0.08/0.11/0.26 (DRY/RAMP/SLIP/EDGE/WEAVE); S Map 0.13-0.32, MapPID 0.36-0.67, PID 0.51-1.06. Delta SLIP cửa sổ sâu nhất: Map -5.22 % (stair mu 0.32), -3.56 % (ramp mu 0.29), -2.21 % (pud); PID và MapPID trong +-0.11 % (trong độ lệch seed).

### Lượt 13 - Kết quả SSW mới nhất và dọn kết quả cũ (2026-10-29)
- Người dùng: DREWS đã thay bằng SSW (STEADY, SLIP, WEAVE, seed chung 99995-99999, chạy 27/10 trên thiết kế cuối: PID sách 27/10, MapPID 27/10 17:09, Map không đổi). Tính trực tiếp từ Cases_ssw/<Ctrl>_metrics_s9999x.csv (không sửa script): cả ca R (RMS e_T, N.m) / S / J, trung bình 5 seed: STEADY Map 1.059/0.198/0.210, PID 0.250/0.565/0.141, MapPID 0.250/0.515/0.129; SLIP Map 0.690/0.203/0.140, PID 0.206/0.490/0.101, MapPID 0.196/0.482/0.095; WEAVE Map 1.451/0.290/0.420, PID 0.200/0.890/0.178, MapPID 0.222/0.756/0.168. Sai số có dấu (% T_d,ref): stair mu 0.24 Map -13.9, PID +0.13, MapPID +0.12; pud_in Map -12.6, PID -0.84, MapPID -0.51; lane_in Map -86.7 (lane_ref -76.6), PID -3.0 (ref -3.2), MapPID -2.2 (ref -2.3).
- Dọn (đã sao lưu 785 file ra Desktop/Adaptive-EPS_backup_2026-10-29_ket_qua_cu, mọi file đều đang trong git): Cases (DREWS v1), Cases_v2, Cases_v3, Cases_slip4 của Map, PID, MapPID; PID/Cases_grid; ba thư mục Legacy_2026-10-27; Result/Compare/DREWS_v2_check, DREWS_v2_summary, DREWS_v3_check, DREWS_v3_summary, SLIP_v4_summary; Figures/new/main/matlab. Chưa commit (793 mục xóa trong git status).
- KHÔNG xóa vì còn phục vụ hình bài: Result/Compare/SSW_summary (gồm fullrate, seed 99987-99989, thiết kế cũ) và Cases_ssw seed cũ (01001-3, 11001-3, 31001-3, 99987-9); mã hình mục 5 (make_fig_sec5_bw.py, make_paper_figures.m) đọc seed 99987. Bảng SSW_summary và summarize_ssw.py vẫn theo seed cũ, cần cập nhật sang 99995-99999.

### Lượt 14 - Ghi dàn ý: cách các bài ref kể kết quả, SSW mới nhất, định vị đóng góp (2026-10-29)
- Người dùng bảo ghi vào phần paper làm dàn ý. Đã tạo Documents/Paper/Outline/ghi_chu_dong_gop_va_ref_ket_qua.md (ghi chú nội bộ, không sửa paper.txt hay dan_y.txt). Nội dung: bảng kết quả của 13 bài ref (đọc toàn văn 6 bài, phần kết quả 7 bài, chưa đọc bài tổng quan); nhận định "ref không có số so sánh" lúc trước là SAI và đã rút lại; kết quả SSW mới nhất (5 seed 99995-99999); phân tích sai số trong và ngoài cửa sổ; phân biệt J trên CALIB (20 %) và trên SSW (6-9 %); đề xuất định vị đóng góp; việc treo. Chưa commit.

### Lượt 15 - Kiểm dàn ý phần 4 của khung khác (Documents/Paper/Outline/dan_y_04.md) (2026-10-30)
- Đối chiếu với mã và dữ liệu. ĐÚNG: hộp PID (K 0.01-30, Ti 2 ms-10 s, Td 20-796 ms, N 8-20, pid_u2x.m), PM 30/GM 2, stress x2 và +1 ms ngưỡng 2, hai mặt safe/full, quy tắc chọn, bảng số điểm (Map 149/80/17/58/0, PID 184/134/99/44/31, MapPID 225/187/142/33/22), tham số và R, S, J, e_rel, PM, GM của ba thiết kế cuối; nhận xét S của MapPID cao hơn PID 2.2 %.
- SAI hoặc thiếu: S tính trên CẢ CA từ 2 s (calib_score.m dòng 18), không theo nhóm cửa sổ; stress không có điều kiện "mô-men trợ lực dương" (chỉ R hữu hạn, R > 0, tỉ số <= 2); 2 s bỏ là 2 s đầu của lần mô phỏng, không phải "mỗi đoạn chạy thẳng"; lưới mịn đặt tâm ở điểm khả thi J nhỏ nhất (bestCenter), không quanh "các điểm Pareto"; Map lưới thô 13 mức, không 4; K_max không có đơn vị N m (độ dốc, N.m/N.m); R dùng 3 nhóm (static, dyn = trans + sine, mu), không 4.
- Vấn đề lớn khung kia CHƯA nêu: paper.txt Eq. (34) K_aw = K_i/K_p và Eq. (39) K_aw = K_i/(K_p + K_max) không khớp mã hiện hành K_aw = sqrt(K_i/K_d) (pidlag_variables.m, mappid_variables.m, thiết kế theo sách 2026-10-27). Td của PID và MapPID cuối = 23.3 ms, sát cận dưới hộp 20 ms (u khoảng 0.04).
- Điểm 4.9 của khung kia ĐÚNG: mappid_eval chỉ kiểm độ lợi khâu lag của Map tại 2 Hz, không kiểm bộ lọc D (Tf <= 79.6 ms) và Td < Ti như pidlag_eval làm cho PID. Đo: 1/225 ứng viên MapPID có Tf 99.5 ms (góc hộp, Kp 0.01), không nằm trong tập, không trên mặt nào; 0 ứng viên vi phạm Td < Ti. Không ảnh hưởng kết quả. Đề xuất xử lý gửi người dùng, chưa sửa file.

### Lượt 16 - Kiểm các file md chính trong Documents/Paper/Outline (00-03) (2026-10-30)
- Người dùng: dan_y_04.md không dùng nữa, khung chính là các md theo mục. Chưa có md mục 4. File ghi chú ghi_chu_dong_gop_va_ref_ket_qua.md (Lượt 14) không còn trong Outline (chưa từng commit); không dựng lại (Outline chỉ chứa md từng mục).
- 03_Control_Strategy.md: khớp mã (dạng ISA K, Ti, Td, N; tau_f = Td/N; khâu D trên T_s,m; K_aw = sqrt(Ki/Kd) Eq. (38) cho cả PID và MapPID; Delta T_a = T_a,cmd - u; clip Eq. (42)). Đã đối chiếu Åström và Hägglund trong References/PID Controllers.pdf: p. 73 (ISA có zero phức, dạng nối tiếp chỉ zero thực), Sec. 3.4, Eqs. (3.9), (3.18), (3.19)-(3.21), (3.22), N 8-20 (tr. 77), T_t = sqrt(Ti Td) và Td < T_t < Ti (tr. 85): đúng. Vấn đề K_aw ở paper.txt cũ đã được sửa trong md.
- 02_System_Modeling.md: tham số khớp params.json; góc trượt hết vết 7.8 và 2.9 độ, góc lực cực đại 6.3 và 2.4 độ tính lại khớp; T_a,max 5.7, 9.8, 8.5 N.m khớp ref.json. Chưa kiểm quy tắc vết bánh trong sách Pacejka.
- 01_Introduction.md: [4] Fan bị chặn Delta <= 25 % đúng; câu Nguyen [11] về độ bám ảnh hưởng độ bền vững đúng nguyên văn; [7] Zhao đúng; [9] chủ yếu xe đỗ đúng. Cần sửa: 3.4 "[6] degraded the transient response" chỉ đúng với chiến lược bù dòng mờ của [6] (chiến lược theo mô-men cản cải thiện); 3.9 [8] chỉ dùng lốp tuyến tính trong bộ ước lượng lực thanh răng, mô phỏng và HILS chạy mô hình xe đầy đủ trên đường khô mu 0.85; 4.5 "PID is the form adopted in [7-9]" sai: [8] dùng ASMC, [9] dùng lead-lag cộng DOB, PID chỉ là bộ so sánh (và kém lead-lag: ±0.3 so với ±0.1 N.m trên xe).
- 00_Abstract.md: A5 "In all three tests, MapPID removed the steady-state error" không áp được cho WEAVE (không có cửa sổ xác lập); phần "several times below map" (3.5-6.5 lần) và "close to PID" khớp số SSW.

### Lượt 17 - Sửa dan_y_04.md theo mã (cổng, Pareto, tìm kiếm) (2026-10-30)
- Người dùng: không còn dùng khung PAPER; dan_y_04.md là dàn ý mục 4 cần sửa. Đã sửa: 2 s đầu của lần mô phỏng; 4 loại cửa sổ gộp 3 nhóm R; S trên cả ca; e_rel_max lớn nhất qua cửa sổ và năm seed; cổng cấu trúc PID (Td < Ti, tau_f <= 79.6 ms) và khoảng trống ở mappid_eval kèm số đã kiểm (1/225, 0); sàng lọc tuyến tính 68 mô hình (và 5 độ dốc cho MapPID) chạy trước mô phỏng; stress không có điều kiện dấu mô-men, chỉ ở seed 99990 cho điểm trên mặt, nguồn Seborg; lưới thô 4 mức (PID, MapPID) và 13 mức (Map), lưới mịn quanh điểm khả thi J nhỏ nhất, hStart, quy tắc tâm Map; Td sát cận dưới; tập ứng viên, pha 1, pha 2 dải 3 sigma; nhãn cột bảng 4.6; đơn vị K_max; mục 4.9 ghi đã kiểm. Đã kiểm thời gian bậc mu (6 s thấp, giữ 4 s) đúng.

## Lượt 18 (2026-10-30) - Kiểm cổng chọn của ba bộ (ý Codex về τ_f)

- Người dùng hỏi các bộ có cùng cổng chọn không (ý Codex: PID có cổng τ_f ≤ 79.6 ms, MapPID chưa). Đọc mã map2_eval, pidlag_eval, mappid_eval.
- Giống nhau: PM ≥ 30°, GM ≥ 2 trên 68 mô hình (MapPID thêm 5 độ dốc), e_rel ≤ 10 %, calib_margin, J = R·S. Dải lái: Map và MapPID qua khâu lag 2 Hz, PID qua τ_f.
- Codex đúng: mappid_eval không kiểm τ_f của nhánh PID (1/225 ứng viên vượt, không trên mặt cuối). Tôi SAI ở Lượt 17: mappid_eval CÓ kiểm T_d < T_i (K_d·K_i < K_p², đầu hàm). Đã sửa dan_y_04.md 4.4.1 và 4.9. Chưa commit.

## Lượt 19 (2026-10-30) - Đồng bộ cổng τ_f cho MapPID (bước 1 và 2)

- Bước 1: thêm cổng τ_f ≤ 79.6 ms (độ lợi 1/sqrt(1+(4π·Tf)²) ≥ 0.707) vào mappid_eval.m, đặt TRƯỚC bước đọc csv, cờ c = [0 0 1 0], giống pidlag_eval.m. Chưa chạy lại gì.
- Bước 2 (đọc csv, không mô phỏng): Tf = 99.5 ms chỉ có ở 16 điểm góc lưới thô (4/luồng, Calib_v2/PlugPlay/P1B1_w1-4); 15 điểm không mô phỏng (bị loại tuyến tính hoặc Td<Ti); 1 điểm (Kp 0.01, Ki 0.001) mô phỏng, e_rel 26 % nên J = Inf, không thể là tâm lưới mịn. Lưới mịn (pareto, pareto_check, pick) 0 vi phạm. Tập đánh giá 187 điểm và hai mặt cuối (33 safe, 22 full): 0 vi phạm, Tf lớn nhất trên mặt 29 ms; 0 điểm vi phạm Td<Ti; margin_done và margin_pass đều 1 cho mọi điểm trên hai mặt.
- Kết luận: kết quả không đổi, không cần chạy lại. Đã sửa dan_y_04.md 4.4.1 và 4.9. Chưa commit.
