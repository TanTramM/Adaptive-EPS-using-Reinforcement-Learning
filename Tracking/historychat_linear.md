# History_Chat LINEAR (PI, PID) - Nhật ký khung Linear

## CÁCH DÙNG (dành cho phiên Claude mới)
1. Đọc file này TRƯỚC KHI làm việc, sau đó đọc `Tracking/CLAUDE.md`, `Documents/Shared/QuyChuan.txt` (bản 6, 2026-10-17, CALIB v2) và `Documents/Shared/PhuongPhap_TimThamSo.txt` mục 13 (quét lưới thích nghi + Pareto, thay KeHoach_ChonNhieuSeed.txt cho PID).
2. Cấu trúc file: (1) TRẠNG THÁI HIỆN TẠI; (2) BẢN NÉN các lượt cũ; (3) NHẬT KÝ NGUYÊN VĂN 5 lượt gần nhất. Nén lần cuối: Lượt 171 (2026-11-09). Bản sao lưu đầy đủ: `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-11-09_historychat_linear/historychat_linear.md` (bản trước đó: `..._2026-10-18_historychat_linear`).
3. Sau mỗi lượt: thêm 1 mục "Lượt N" vào cuối file và cập nhật TRẠNG THÁI HIỆN TẠI. Sau mỗi 10 lượt: tự nén.
4. Ngôn ngữ: tiếng Việt cho giao tiếp và tài liệu; code `.m` bằng tiếng Anh.

---

## 1. TRẠNG THÁI HIỆN TẠI (2026-11-09, sau Lượt 171)

- **Vai:** khung 2 = Linear, nay chỉ còn một bộ chính tên **PID** (người dùng chốt 2026-10-18: không còn PIDOpt; PI bỏ khỏi so sánh). Phiên 2026-11-09: người dùng mở lại khung, chưa giao việc mới.
- **PID chính thức (xong 2026-10-19, theo PhuongPhap_TimThamSo.txt mục 13):** quét lưới thích nghi 4 biến + Pareto (R, S), bỏ surrogateopt/patternsearch; 561 điểm, 168 mô phỏng CALIB v2, 114 qua cổng (PM >= 30, GM >= 2, e_rel <= 10 %), 30 điểm Pareto; chọn J = R x S nhỏ nhất: Kp 3.5026, Ki 111.32, Kd 0.10812, Tf 1.4402 ms (đã ghi `Model/data/pid.json`); seed 10000: R 2.922 %, S 0.8505, J 2.4855, PM 48.5, GM 3.83; năm seed 10001-10005: J 2.4879 +- 0.0809, e_rel lớn nhất 1.85 %, calib_margin 0.713/1.022. DREWS năm seed 99995-99999 xong (11 tệp/seed, `Result/Controllers/PID/Cases/`). Người dùng (khung Map, Lượt 461) đã chạy DREWS v2 Map/PID: PID RMS e_T DRY 0.31, RAMP 0.04, SLIP 0.07, EDGE 0.10, WEAVE 0.18 N.m; S 0.35-1.06; TV 253-311; trợ lực ngược DRY 13.5 %, WEAVE 25.5 %; T_a đỉnh 104 % T_a,max. Câu chuyện chốt: Map êm bám kém, PID bám tốt ồn, MapPID khắc phục cả hai.
- **Mã:** `Model/Controllers/PID/script`: pid_grid_spec, run_pid_grid, select_pid_pareto (mục 13), pid_u2x/pid_x2u/optimize_pid/refine_pid/select_pid (đường surrogateopt cũ, không dùng nữa); dùng chung `Model/common/grid_search.m`, `select_pareto.m` (khung Map đã sửa tương thích ngược: spec.coarseLevels, centerFcn, erelMax = Inf, keepTsCtrl), đánh giá `pidlag_eval('PID', ...)` (PM 30, GM 2, e_max 10 %), pipeline `tools/jobs/grid_pipeline.sh PID [rest]`. `pidMargin` nạp `load_pid.m` trước `calib_margin` (lỗi khởi tạo đã sửa Lượt 168). Sao lưu: surrogateopt ở `Desktop/Adaptive-EPS_backup_2026-10-19_PID_surrogateopt`, e_max 5 % ở `..._2026-10-18_PID_emax5`, PIDOpt+PID cũ ở `..._2026-10-18_PIDOpt_PID`. PID lưới cũ (Kp 1.5, Ki 32, Kd 0.025, Tf 2.5 ms, CALIB v1) giữ ở `design_grid` của pid.json; PIDLag chỉ chạy lại khi người dùng bảo.
- **Quy chuẩn:** QuyChuan v6, CALIB v2 (140 s, 68 cửa sổ, R trung bình nhân ba nhóm); chọn J = R x S; calib_margin (R không tăng quá 2 lần khi độ lợi x2 hoặc trễ +1 ms) giữ làm cổng an toàn (người dùng chốt 2026-10-22 ở khung Map); bang-bang và trợ lực ngược chỉ báo cáo.
- **CHƯA LÀM / treo:** (1) cập nhật `Documents/Notes/Controllers/DieuKhien_Linear.txt` (còn nói CALIB v1); (2) so sánh theo cặp, Pareto ở seed chung (5 seed 99990-99994) với Map, MapPID; (3) Tf PID 1.44 ms gần biên dưới 1 ms (= chu kỳ điều khiển), đã nêu, chưa xử lý; (4) chỉnh QuyChuan 5.2 câu "Mất ổn định = R tăng hơn gấp đôi" thành "không đạt độ dư" (việc của COMMON, khung Map khuyên, chưa sửa); (5) PIDLag, PID lưới cũ chỉ chạy lại khi người dùng bảo.
- **Git (kiểm 2026-11-09):** thay đổi PID đã được commit (không còn chưa commit). Có hai khung mới đụng PID: `historychat_pidbook_pc.md` và `historychat_pidbook_laptop.md` (commit dae597b "PID book redesign code, test_pid PASS", e087803 PIDBOOK_PC_DONE); chưa đọc, cần đọc trước khi làm gì với PID, vì có thể PID đã được thiết kế lại.

## 2. BẢN NÉN CÁC LƯỢT CŨ (Lượt 5 - 166)

Nén lần cuối: Lượt 171 (2026-11-09). Bản chi tiết cũ lưu tại thư mục sao lưu trên Desktop.

### Giai đoạn 1: Khung ban đầu và tái cấu trúc PRSM (Lượt 5 - 86)
- Giải thích seed và cảm biến; hiện tượng bang-bang do độ lợi cao tần; xây dựng PRSM dùng chung (Plant, Ref, Sensors, AssistLimit, Actuator) không hậu tố `_s`.
- Tách vai: Khung này phụ trách Linear (PI, PID). Dừng kế hoạch RL.

### Giai đoạn 2: Thiết kế ca TK và quy chuẩn so sánh (Lượt 87 - 116)
- Xây dựng ca TK (117 s, 19 cửa sổ); thứ tự cổng cứng 5.6; gán $T_{a,max} = T_{a,req} + F$ với $F = T_f = 2.0\text{ N.m}$ ở AssistLimit.
- Nhận dạng cộng hưởng cột lái 6.17 Hz chặn băng thông PI. Xây dựng P0-P3 của PI.

### Giai đoạn 3: Hoàn thành PI và PID theo ca TK cũ (Lượt 117 - 122)
- Quét thô PI 103 điểm, phát hiện $e_{rel}$ ở 20 km/h không thể $< 3\%$ do ma sát khô $T_f = 2\text{ N.m}$; chọn $K_p = 1.25, K_i = 3.0, K_{aw} = 2.4$ (quy tắc dự phòng 5.6).
- Xây dựng PID trong `Model/Controllers/PID/`, quét 455 điểm, chọn $K_p = 1.5, K_i = 3, K_d = 0.015, T_f = 3.5\text{ ms}$. Chạy TC1-TC6 cũ.

### Giai đoạn 4: Chuyển sang QuyChuan v4, bỏ cổng rev và mở rộng lưới (Lượt 123 - 131)
- QuyChuan v4: Đổi tên ca (CALIB, DRY, SLIP, WEAVE, EDGE), tách cửa sổ 0.4g thành `ext_*`, nâng cổng $e_{rel} \le 5\%$.
- Lượt 126: Bỏ cổng trợ lực ngược $rev \le 1\%$ thành chỉ báo cáo vì vi phạm có hệ thống do trễ pha khi lái sin.
- Phát hiện quan trọng (Lượt 129): Khâu D gỡ trần cộng hưởng nên biên ổn định tuyến tính của PID rộng hơn PI rất nhiều ($K_p$ gấp 3-4 lần, $K_i$ tới hàng trăm). Lưới cũ $K_i \le 8$ chặn oan PID. Quét rộng PID lên $K_i = 100$ cho $R = 8.9\%$, $S = 0.411\text{ N.m}$.

### Giai đoạn 5: Bàn luận độ ồn, quy tắc $J = R \times S$ và nguồn chuẩn (Lượt 132 - 146)
- Nhận định $K_i = 100$ ($T_i = 25\text{ ms}$) là quá cao, đánh đổi bám lấy ồn quá mức ($S$ tăng gấp đôi để lấy chút $R$).
- Tìm nguồn sách Seborg (Table 12.7 Z-N: $T_i \ge P_u/2 = 42.5\text{ ms}$, tương đương $K_i \le 43.8$).
- Đề xuất quy tắc không thứ nguyên $J = R \times S$ để cân bằng bám và êm. Thống nhất chuyển sang QuyChuan v5.

### Giai đoạn 6: Cổng dự trữ, PIDOpt và PIDLag trên CALIB v1, rồi CALIB v2 (Lượt 147 - 156)
- Lượt 147-151 (2026-10-11): đọc QuyChuan Phần 9 (VIỆC CỦA LINEAR a-e); bỏ cổng bang-bang (chỉ báo cáo; người dùng chốt, đây là lần đổi cổng thứ ba sau khi thấy kết quả, điểm chọn không đổi); thêm ràng buộc dải lái (Tf <= 79.6 ms, không loại điểm nào của lưới), hàm Model/common/selection_sensitivity.m; chạy DREWS seed local 10000 cho PI (Kp 1.08, Ki 14.4: RMS e_T DRY 0.243, RAMP 0.072, SLIP 0.219, WEAVE 0.375, EDGE 0.302) và PID lưới (0.152, 0.046, 0.136, 0.217, 0.166); nén lần 5.
- Lượt 152-153 (2026-10-12): cài tiêu chí mất ổn định không số theo QuyChuan 9.4 như lệnh (lỗi: coi đề xuất của COMMON là đã duyệt); người dùng chốt phương án 1: trả calib_margin.m về cổng cũ (R tăng hơn 2 lần = mất ổn định), sửa QuyChuan 9.4 và dòng VIỆC CỦA LINEAR (a) thành KHÔNG ĐỔI. Bài học: mục đề xuất trong QuyChuan Phần 9 chưa là lệnh.
- Lượt 154-156 (2026-10-16): đọc khung MapPID; dựng PIDOpt (4 biến) và PIDLag (6 biến, lag Tustin, chống bão hòa sau lag) dùng chung mã Model/Controllers/PIDLag/script (pidlag_eval, pidlag_margins, pidlag_variables, build_pidlag, optimize/refine/select_pidlag, test_pidlag PASS); chạy qua đêm (MATLAB bị tắt vì RAM, tiếp từ csv; checkpoint chuỗi PIDLag 3 hỏng thì chuyển *_corrupt.bak). CALIB v1: PIDOpt J 3.420 (Kp 1.32, Ki 52, Kd 0.0365, Tf 2.94 ms), PIDLag J 3.37 (lag không thêm gì), PID cũ 3.61.
- Bài học công cụ: đặt tên biến script có tiền tố xr_ (biến m, c, s, i, R từng đè biến model); heredoc bash dài làm cụt file nên dùng công cụ Write; sed -i làm hỏng file UTF-8; script run_job cần đường dẫn kiểu Windows cho MATLAB; run_cases cần chạy load_<ctrl> trước (nếu không báo biến motor_wm đã bị xóa).


### Giai đoạn 7: PIDOpt hộp rộng, PID trên CALIB v2, rồi quét lưới Pareto (Lượt 157 - 166, 2026-10-16 đến 2026-10-19)
- Lượt 157-158: tổng kết seed 99999 CALIB v1: MapPID êm hơn PIDOpt/PIDLag 20-25 % (S DRY 0.206 so với 0.259-0.267) với độ bám ngang; Map thuần êm nhất nhưng bám kém 3-9 lần. PIDOpt dùng surrogateopt + patternsearch trực tiếp trên CALIB (không systune). Người dùng chốt so Map, PID, MapPID cùng ràng buộc (PM >= 30, GM >= 2, bỏ Ti >= Pu/2) và cùng phương pháp tối ưu; dựng MapOpt (Model/Controllers/MapOpt, J 5.739 so với Map lưới 6.743); commit fbd74d4. Lưu ý trùng tên MapOpt với kế hoạch của khung MapPID (hai bản cùng thư mục), chờ người dùng quyết định. Bài học: không đặt biến script tên m, c, s, i (đè biến model), dùng tiền tố xr_.
- Lượt 159-160: PIDOpt làm lại theo phương pháp MapPID (hộp rộng thang log Kp 1e-3-30, Ki 0.1-2000, Kd 0 hoặc 1e-4-2, Tf 1-79.6 ms; 1 + 5 seed, top 20): hội tụ J 3.4195, không ở biên hộp, chọn Kp 1.365, Ki 52.09, Kd 0.04636, Tf 2.88 ms; viết select_pidopt riêng vì select_multiseed.m chưa có (sau đó có, chưa đối chiếu). Lượt 160 cập nhật lịch sử theo CALIB v2 (140 s, 68 cửa sổ, QuyChuan v6) mà không chạy gì.
- Lượt 161-162: dọn PIDOpt (sao lưu rồi xóa), chỉ còn PID; chạy phương pháp chung trên CALIB v2: J 2.457/2.459/2.455, chọn Kp 3.58, Ki 117.6, Kd 0.0860, Tf 1.053 ms, J_bar 2.4821; DREWS cũ seed 10000 RMS e_T DRY 0.1159, RAMP 0.0430, SLIP 0.1094, WEAVE 0.1425, EDGE 0.1146. Giải thích vì sao không lấy luôn hạng 1 seed 10000: top 20 chỉ trải 2.4 % J, nhỏ hơn sigma_J 3.3 %; J ở seed tìm kiếm lạc quan; 5 seed cho cổng e_rel và quy tắc hòa. Lỗi gặp: run_cases cần chạy load_pid trước.
- Lượt 163-164: người dùng đổi sang mục 13.1 (e_max 10 %, 200 lần mỗi chuỗi), sao lưu kết quả e_max 5 %; ba chuỗi surrogateopt xong 00:19 ngày 2026-10-19; rồi người dùng giao phụ trách khung PID, đọc lịch sử các khung, chưa chọn/mở rộng trước khi chốt phương pháp chung.
- Lượt 165-166: mục 13 mới thay hẳn surrogateopt: quét lưới tất định 4^4 = 256 điểm thô cộng tối đa sáu lưới mịn 3^4, lọc c1-c4 (PM >= 30, GM >= 2, e_max 10 %), Pareto (R, S), chọn J với hòa 3 % lấy PM lớn nhất, calib_margin, báo cáo năm seed, DREWS 99995-99999. Viết grid_search.m, select_pareto.m, pid_grid_spec.m, run_pid_grid.m, select_pid_pareto.m, grid_pipeline.sh; sửa pidlag_eval (PMmin 30, GMmin 2); guard_ram.ps1 ghi NA khi CIM không đọc được thay vì giết MATLAB; sửa race ở ranh giới hai lớp lưới (tâm chỉ tính trên các lớp worker đã hoàn tất). Ba worker mở cách nhau 150 s.

---

## 3. NHẬT KÝ NGUYÊN VĂN (5 lượt gần nhất)

### Lượt 167 (2026-10-19) - Lưới PID hoàn tất; pipeline dừng ở lỗi khởi tạo calib_margin

Người dùng hỏi tiến độ. KẾT QUẢ LƯỚI: ba worker DONE lúc 02:31--02:32, cho cùng nhật ký: lưới thô 256 điểm, sáu lưới mịn; tổng 561 điểm khác nhau, 168 mô phỏng CALIB thật, 114 qua cổng c1-c4; J tốt nhất 2.48553, tại Kp = 3.5026, Ki = 111.32, Kd = 0.10812, Tf = 1.4402 ms; bước mịn cuối 0.0416667. Pipeline dừng 02:35 ở stage chọn, sau ba lần lỗi thật (không tự chạy lại nữa): `select_pareto` gọi `pidMargin` trong MATLAB mới nhưng `pidMargin` chỉ gọi `calib_margin`, không chạy `load_pid.m` để nạp PRSM/Actuator. Vì thế `Model_PID/.../Motor_lag` nhận `Numerator` không hợp lệ, calib_margin trả Inf/Inf cho mọi điểm và assert sai "No feasible design". Đây là lỗi khởi tạo, KHÔNG phải bằng chứng 114 điểm qua cổng đều không qua calib_margin. Chưa sửa/chạy lại trong lượt chỉ hỏi tiến độ; cách đúng là cho `pidMargin` nạp `load_pid.m`, kiểm một điểm, rồi chạy lại RIÊNG select và DREWS, không quét lại 561 điểm.

### Lượt 168 (2026-10-19) - Sửa khởi tạo calib_margin và chạy tiếp chọn Pareto + DREWS

Người dùng yêu cầu sửa và chạy. SỬA: trong `pid_grid_spec.m`, hàm `pidMargin` xác định `modelDir` rồi `evalin('base', run(load_pid.m))` trước khi tạo biến thiết kế và gọi `calib_margin`; thêm pha tùy chọn `rest` cho `tools/jobs/grid_pipeline.sh` để bỏ qua kiểm/lưới đã xong và chạy thẳng chọn + DREWS. KIỂM THẬT trên điểm tốt nhất lưới [3.5026, 111.32, 0.10812, 0.0014402]: lỗi `Motor_lag/Numerator` đã hết; calib_margin PASS, gain x2 R ratio 0.713151, delay +1 ms ratio 1.022954. Giữ riêng ba log lỗi cũ dưới tên `failed_init_pid_grid_select_*`. Bắt đầu `grid_pipeline.sh PID rest` lúc 09:47; hiện đang stage 2 chọn Pareto/calib_margin, sau đó tự chạy báo cáo năm seed 10001-10005 và DREWS 99995-99999. Không quét lại 561 điểm.

### Lượt 169 (2026-10-19) - Chọn Pareto hoàn tất, đang chấm DREWS năm seed

Người dùng hỏi tiến độ. SELECT DONE lúc 10:39: 561 điểm đánh giá, 168 mô phỏng thật, 114 khả thi, 30 điểm Pareto. Thiết kế chọn: Kp = 3.5026, Ki = 111.32, Kd = 0.10812, Tf = 1.4402 ms; tại seed 10000 có R = 2.92246 %, S = 0.850494 N.m, J = 2.48553, PM = 48.544 độ, GM = 3.826. Báo cáo seed 10001-10005: J trung bình 2.48786, sigma 0.0808568, e_rel lớn nhất 1.849 % (qua cổng 10 %); calib_margin ratio gain/delay = 0.713/1.022, PASS. Đã ghi `PID_CALIB_pareto_s10000.csv/.png`, `PID_CALIB_pick_s10000.csv`, `PID_CALIB_pareto_check_s10001-s10005.csv` và design mới vào `Model/data/pid.json`. Pipeline sang stage 3 lúc 10:39: chấm DREWS seed 99995-99999; đang ở seed 99995, DRY đã xong với RMS e_T 0.115 N.m.

### Lượt 170 (2026-10-19) - PID hoàn tất toàn bộ mục 13.3 tới DREWS năm seed

Người dùng hỏi tiến độ. `pid_grid_master_status.txt` ghi ALL DONE lúc 10:59:25; marker `pid_grid_pipeline_done.txt` tồn tại. `pid_grid_score` hoàn tất ở try 2: try 1 gặp `Exit Status 0xc0000374, Heap corruption` sau khi đã ghi một phần ca; `run_scoring_seeds` bỏ qua các seed/file đã có và try 2 chạy tiếp thành công. Kiểm file: mỗi seed 99995, 99996, 99997, 99998, 99999 có đủ 11 tệp trong `Result/Controllers/PID/Cases/`, gồm `PID_metrics_s<seed>.csv` và tín hiệu/hình của năm ca. Guard RAM PID (PID 103592) đã dừng sau khi pipeline hoàn tất. Kết quả chọn giữ như Lượt 169; phần PID theo mục 13.3 đã xong.

### Lượt 171 (2026-11-09) - Người dùng mở lại khung 2 (Linear); đọc nhật ký, nén lần 6

Người dùng chỉ nói "đây là khung 2", chưa giao việc. ĐÃ ĐỌC: TRẠNG THÁI và Lượt 157-170 của chính nhật ký; Lượt 455-461 của khung Map (mới nhất 461, 2026-10-22). KINH NGHIỆM RÚT RA TỪ KHUNG MAP: (1) khung Map sửa `grid_search.m` và `select_pareto.m` dùng chung theo hướng tương thích ngược (coarseLevels, centerFcn, erelMax = Inf, keepTsCtrl), PID nên chạy lại `test` hoặc so một điểm nếu chạy lại lưới; (2) người dùng chốt GIỮ cổng calib_margin, e_rel là cổng chất lượng; (3) ba dòng seed 0 của một worker Map bị hỏng không rõ nguyên nhân (S lệch 3 lần, margin "đạt" sai), nên khi dùng lại CSV lưới của PID cần chú ý rằng dòng chạy rất chậm có thể sai; PID đã có ba worker khớp cùng kết quả nên rủi ro thấp; (4) QuyChuan 5.2 nên đổi câu "Mất ổn định" thành "không đạt độ dư" (việc của COMMON). Không có việc mới cho PID nên không chạy MATLAB, không sửa mã. Git: `git log` cho thấy PID đã commit, kèm hai khung mới pidbook_pc, pidbook_laptop (commit "PID book redesign", test_pid PASS); chưa đọc nhật ký hai khung đó. ĐÃ NÉN NHẬT KÝ (Lượt 171, cách lần trước 10 lượt): sao lưu ra Desktop/Adaptive-EPS_backup_2026-11-09_historychat_linear, gộp Lượt 157-166 vào BẢN NÉN (Giai đoạn 7), giữ nguyên văn Lượt 167-171, hợp nhất TRẠNG THÁI HIỆN TẠI (Tracking/CLAUDE.md nay còn nhiều khung mới: VDB_BODY, VDB_TIRE, PAPER, TESTCASE, nhưng không đổi phần việc của Linear).
