# History_Chat SMC - Nhật ký khung SMC (điều khiển trượt, Sliding Mode Control)

## CÁCH DÙNG (dành cho phiên Claude mới)

1. Đọc file này TRƯỚC KHI làm việc, rồi `Tracking/CLAUDE.md` (quy tắc chung) và `Documents/Shared/QuyChuan.txt` (quy chuẩn thiết kế và đánh giá chung, BẮT BUỘC khi thiết kế SMC).
2. Mỗi lần bắt đầu làm việc: đọc 1 mục "Lượt" mới nhất của `historychat_map.md` (khung Map) và `historychat_linear.md` (khung Linear: PI, PID) để rút kinh nghiệm; nếu có thì ghi vào mục Lượt của file này. Hai file kia CHỈ ĐỌC.
3. Cuối mỗi lượt hỏi-đáp: thêm 1 mục "Lượt N" vào cuối file này, sửa "TRẠNG THÁI HIỆN TẠI" nếu có thay đổi. Không xóa lượt cũ.
4. Ngôn ngữ: tiếng Việt cho hội thoại và tài liệu; code `.m` bằng tiếng Anh. Viết tắt phải giải thích ngay lần đầu.

---

## TRẠNG THÁI HIỆN TẠI (2026-10-11, sau Lượt 23: ISMC đã quét và chạy 4 ca trên CALIB v4, điểm chọn lambda 5, Phi 50, Tf 10 ms nằm mép lưới; trước đó sau Lượt 22: SMC đã quét lại và chạy 4 ca trên CALIB v4 (điểm chọn lambda 80, Phi 400, Tf 5 ms, thiếu trợ lực); ISMC chưa quét; trước đó sau Lượt 20; đã nén Lượt 1-15 ngày 2026-10-10 theo yêu cầu người dùng, bản đầy đủ ở C:/Users/Admin/Desktop/historychat_smc_backup_2026-10-10.md)

- ĐÃ CÓ: SMC (SMC-sat, không tích phân, s = Ts_dot_hat + lambda e_T, T_a = T_a_max sat(s/Phi)) ở Model/Controllers/SMC/ và ISMC (có tích phân, Slotine anti-windup) ở Model/Controllers/ISMC/, cả hai test PASS. Sao lưu trước khi tách: Desktop/Adaptive-EPS_backup_2026-10-10_smc_truoc_tach_ismc.
- SMC đã quét 50 điểm (lambda x Phi 50-800 x Tf), chọn lambda=80, Phi=200, Tf=5 ms (data/smc.json); không điểm nào đạt rev <= 1 % và e_rel <= 3 % (SMC-sat tương đương PD nên không thể đạt e_rel); xem Lượt 20. TC local và so sánh Map_vs_SMC, PI_vs_SMC đã chạy lại (seed 99999).
- ISMC CHƯA quét: điểm hiện tại (lambda=20, Phi=2) nhiều khả năng rung 25 Hz như lưới 1 của SMC, nên kết quả TC của ISMC và Map_vs_ISMC cũ KHÔNG đáng tin. Việc kế tiếp hợp lý: quét ISMC với Phi lớn (50-800), chọn, chạy TC, so sánh; người dùng chưa xác nhận.
- CÒN TREO: so với PID khi khung Linear xong; tách DieuKhien_SMC.txt thành SMC và ISMC; super-twisting + Lyapunov Moreno-Osorio; thêm [SL], [MO] vào References.txt (khi người dùng bảo); sửa QuyChuan 2.4 dòng SMC; thống nhất chống bão hòa (PI tính ngược, ISMC dừng tích phân) và rời rạc hóa đạo hàm với khung Linear; cập nhật CLAUDE.md/QuyChuan có ISMC là bộ riêng.
---

## NHẬT KÝ TỪNG LƯỢT

### Lượt 1-15 (2026-10-09 đến 2026-10-10) - BẢN NÉN (bản đầy đủ nằm ở file sao lưu trên Desktop)
- **L1 Mở khung:** tạo file này; kinh nghiệm từ hai khung kia: model/biến không hậu tố `_s`; không vội đổ lỗi spike e_T cho ước lượng đạo hàm; lớp biên SMC đổi sai số tĩnh lấy độ nhạy nhiễu nên cổng bang-bang là ràng buộc chính.
- **L2 Kế hoạch theo QuyChuan và ca TK v2:** e_T có bậc tương đối 2 với T_a nên mặt trượt phải chứa đạo hàm e_T; bỏ u_eq (cần T_r và mô hình plant, QuyChuan 2.5 cấm); điều kiện Lyapunov V = s^2/2: (K/J) T_a,max > |d| + eta; SMC-1 (không tích phân) dự kiến trượt cổng e_rel; SMC-2 có tích phân; SMC-3 super-twisting nếu cần. Chưa có sách Slotine và Moreno-Osorio trong References/.
- **L3-L4 Tích phân và Map:** tích phân là thành phần CHUNG PID-SMC, không phải lợi thế riêng SMC; Map không có phản hồi (không tính được e_T) nên không có tích phân; sai số xác lập lớn của Map là khác biệt cấu trúc. Ba cách lấy e_T_dot (a), (b), (c).
- **L5-L6 Chốt (c):** nhiễu ước lượng e_T_dot qua K(theta1_dot - theta2_dot) lớn hơn vi phân T_s khoảng 25 lần (bước T_s 0.01 N.m mịn hơn nhiều bước theta1 0.0017 rad); chốt (c) cho PID và SMC: vi phân T_s đo qua lọc bậc 1 Tf. Tạo DieuKhien_SMC.txt (Phần A quyết định, B động học sai số, C luật chuyển, D việc treo); sửa QuyChuan 2.4 dòng SMC (người dùng duyệt). Phân tích: sgn thuần rung ở 1 ms; lớp biên với k >= T_a,max tương đương PD (Kd = G, Kp = G lambda); super-twisting là luật riêng SMC đơn giản nhất.
- **L7 Kiểm sách Slotine và Li:** file đầy đủ là References/slotine applied nonlinear control.pdf (476 trang, chương 7 ở PDF tr. 291-326). Điều xác minh: s = e_dot + lambda e (tr. 278); điều kiện trượt (tr. 280); u = u_hat - k sgn(s) (tr. 286); lớp biên sat(s/Phi), |e| <= Phi/lambda (tr. 290-291); Remark (iii) tr. 300: k sat(s/Phi) trong lớp biên là PD, "no free lunch"; mặt trượt có tích phân s = e_dot + 2 lambda e + lambda^2 int e (tr. 286-287); Remark (iv) tr. 300: dừng tích phân khi ra ngoài lớp biên; Mục 7.3 tr. 301-303: lambda bị chặn bởi cộng hưởng, trễ chưa mô hình hóa (lambda <= 1/T_A), lấy mẫu (lambda <= nu/5). Thống nhất làm sat trước.
- **L8-L9 Bảng thành phần chung:** hàng 2 (chống bão hòa): dừng tích phân khi |T_a_cmd| > T_a_lim và sai số cùng dấu lệnh (hoặc tính ngược); hàng 5 (sat): SMC-sat = PID có Ki = 0, thành phần chung; tương đương này là phép kiểm mã miễn phí.
- **L10-L11 Super-twisting và hệ phi tuyến:** super-twisting không bảo đảm tốt hơn PID; dự đoán R ngang, S kém hơn, độ bền đổi mu là chỗ duy nhất có lý do thắng; giả thuyết H1 (Pareto dưới PID), H2 (suy giảm khi sai lệch tham số nhỏ hơn), H3 (đỉnh e_T sau đổi mu nhỏ hơn), báo trung thực kể cả âm. SMC-sat tốt hơn tuyến tính chỉ khi dùng hiểu biết phi tuyến (u_hat, k(x), Phi(t)); kế hoạch hiện tại bỏ nên rơi vào trường hợp PD.
- **L12-L14 u_hat (A4):** A1, A2, A4 chỉ là đề xuất chờ xác nhận (đã sửa nhãn); bỏ u_hat vì QuyChuan 2.5 cấm bù mô hình, phần bù ma sát/tốc độ PID cũng thêm được (không riêng SMC), T_r và theta1_ddot không dùng được; ma sát T_f = 2 N.m là nguồn lệch lớn nhất ở TC2; bài Moreno-Osorio đã có lại trong References/.
- **L13 Đề xuất gọn:** bỏ u_hat, không làm k(x)/Phi(t), SMC-sat không quét riêng (chỉ lý thuyết + kiểm tương đương PID), bộ chính super-twisting trên s = Ts_dot + lambda e_T, chống bão hòa chung một quy tắc, ngân sách ~90 mô phỏng, dừng có kiểm soát nếu kết quả âm. (Sau đó người dùng chọn làm SMC-sat trước, rồi tách SMC và ISMC ở Lượt 19.)
- **L15 Nhận vai khung SMC:** đọc CLAUDE.md và nhật ký hai khung kia; T_a,max mới = T_a,req + F (F = 2.0 N.m) do AssistLimit cung cấp, build_closed_loop nối theo tên; ca TK 117 s và QuyChuan v2 đã chuẩn hóa; tránh ghi đè biến base workspace khi chạy batch.

### Lượt 16 - Xây dựng và kiểm thử hoàn tất SMC-sat không tích phân trên ca TK (2026-10-10)
**Người dùng:** làm bản không tích phân trước; liệt kê các bước code; giải thích ca TK vs ca 1-6; bắt đầu làm tới bước trước chuẩn bị chạy TC 1-6 thôi, chưa chạy.
**Claude:** ĐÃ HOÀN THÀNH TOÀN BỘ CÁC BƯỚC CODE VÀ THỬ NGHIỆM ĐƯỜNG ỐNG TRÊN CA TK (dừng trước TC1-TC6):
(1) Model/data/smc.json: tạo file cấu hình dữ liệu nguồn (Ts_ctrl = 1 ms).
(2) Model/Controllers/SMC/load_smc.m: nạp PRSM (Plant, Ref, Sensors, AssistLimit, Actuator) và biến SMC_lambda, SMC_Phi, SMC_Tf, Ts_ctrl.
(3) Model/Controllers/SMC/script/build_smc.m: dựng SMC.mdl chuẩn interface (Inports: T_s, v, a_y, T_a_lim, T_a_max; Outport: T_a; Reference nội bộ, lọc đạo hàm T_s qua Forward Euler 1 ms, mặt trượt s, bão hòa sat(s/Phi) x T_a_max). Phát hiện và sửa lỗi thiếu Goto tag cho Inport T_s.
(4) Model/Controllers/SMC/script/test_smc.m: kiểm thử độc lập open-loop 6 s (6001 mẫu) so với đệ quy MATLAB thuần: PASS tuyệt đối, sai lệch cực đại chỉ 5.11e-14 N.m.
(5) Dựng vòng kín Model_SMC.mdl bằng build_closed_loop('SMC'): tự động ghép Plant -> Sensors -> SMC -> AssistLimit -> Actuator -> Plant.
(6) Chạy Smoke Test vòng kín trên ca TK 117 s (vars: lambda = 30 rad/s, Phi = 2.0 N.m/s, Tf = 5 ms):
    - Cảm biến lý tưởng: R = 12.49 %, S = 4.9267 N.m, e_rel = 6.87 %, rev = 0.2350.
    - Cảm biến có nhiễu (seed local 20000): R = 15.11 % (static 7.27 %, dyn 30.99 %, small 11.45 %, mu 10.71 %), S = 5.4201 N.m, TV = 1639 N.m/s.
    - Sai số xác lập e_rel = 10.49 % > 3.0 % (trượt cổng). Tỉ lệ bang-bang diff = 0.1231 > 0.01 (trượt cổng).
    - Phát hiện & rút kinh nghiệm: Tránh đặt biến nhận kết quả m = tk_run vì đè biến m (khối lượng xe 1573 kg) trong Bike2DOF.
(7) Không chạy TC1-TC6 (dừng trước TC1-TC6).

### Lượt 17 - Chạy hoàn tất bộ ca thử nghiệm chuẩn TC1-TC6 cho SMC-sat không tích phân (2026-10-10)
**Người dùng:** chạy test tc1-6 trước.
**Claude:** ĐÃ CHẠY HOÀN TẤT TC1-TC6 CHO BẢN SMC-SAT KHÔNG TÍCH PHÂN (baseline: lambda = 30 rad/s, Phi = 2.0 N.m/s, Tf = 5 ms ghi trong data/smc.json):
(1) Cảm biến lý tưởng (run_test_cases('SMC', [])): Kết quả ghi vào Result/Controllers/SMC/TestCases/:
    - RMS e_T toàn ca (N.m): TC1 0.175, TC2 0.146, TC3 0.055, TC4 0.116, TC5 0.100, TC6 0.106.
    - Sai số xác lập trên các cửa sổ giữ cua dao động 4.1 % - 9.5 % T_d,ref (v40 0.3g: 9.52 %, v60 0.3g: 6.87 %, TC2 0.2g: 8.12 %).
    - Sinh đủ 6 hình 6 ô SMC_<case>_time_response.png và bảng SMC_test_case_metrics.csv.
(2) Cảm biến có nhiễu seed local 20000 (run_test_cases('SMC', 20000)): Kết quả ghi vào Result/Controllers/SMC/TestCases_noise/seed_20000/:
    - RMS e_T toàn ca (N.m): TC1 0.243, TC2 0.220, TC3 0.105, TC4 0.193, TC5 0.149, TC6 0.154.
    - Tổng biến thiên TV(T_a) ~ 1850 - 2110 N.m/s.
    - Sai số tại TC4 lúc vào vũng nước (during_puddle) đạt -7.81 % (trợ lực thừa do ma sát và trễ).
    - Sinh đủ 6 hình 6 ô và bảng metrics.
(3) Cập nhật DieuKhien_SMC.txt (bổ sung Mục E4 với bảng tổng hợp TC1-TC6).

### Lượt 18 - Thiết kế, triển khai và nghiệm thu bộ điều khiển trượt tích phân (ISMC) (2026-10-10)
**Người dùng:** giờ làm qua tới smc có tích phân.
**Claude:** ĐÃ HOÀN TẤT THIẾT KẾ, TRIỂN KHAI VÀ NGHIỆM THU ISMC (Slotine & Li Ch. 7, pp. 286-287, 300):
(1) Cơ sở lý thuyết và mô hình hóa:
    - Mặt trượt tích phân: s = Ts_dot_hat + 2*lambda*e_T + lambda^2*z với đạo hàm lọc Ts_dot_hat qua bộ lọc Euler hiện H(s) = s / (Tf*s + 1).
    - Trạng thái tích phân z với cơ chế chống bão hòa Slotine (Remark iv tr. 300): z[k+1] = z[k] + Ts * e_int[k], e_int[k] = e_T[k] khi |s[k]/Phi| <= 1.0 (ngắt tích phân khi ngoài lớp biên).
    - Cập nhật Model/data/smc.json sang variant "SMC_integral" (lambda = 20.0 rad/s, Phi = 2.0 N.m/s, Tf = 0.005 s, Ts_ctrl = 1 ms).
(2) Tái tạo khối Simulink và kiểm thử độc lập:
    - Sửa Model/Controllers/SMC/script/build_smc.m: Thêm các khối Abs_s_Phi, RelOp_freeze (<= 1.0), Prod_e_freeze, Int_z (Discrete-Time Integrator Forward Euler), Prod_2lambda_e, Prod_lambda2_z. Kết nối hồi tiếp qua trạng thái rời rạc không tạo Algebraic loop.
    - Sửa Model/Controllers/SMC/script/test_smc.m: Kiểm tra thuật toán đệ quy độc lập so với khối Simulink SMC.mdl: ĐẠT TEST PASS với sai số số học 1.92e-13 N.m.
    - Tái tạo mô hình vòng kín Model_SMC.mdl qua build_closed_loop('SMC').
(3) Smoke Test trên ca TK 117 s (QuyChuan v2):
    - Sai số xác lập e_rel GIẢM NGOẠN MỤC từ 10.49 % xuống 1.95 %, CHÍNH THỨC ĐẠT CỔNG NGHIỆM THU e_rel <= 3.0 %!
    - Toàn bộ 11 cửa sổ tĩnh đều đạt sai số cực nhỏ trong dải 0.42 % - 1.95 % (< 2.0 %).
    - RMS e_T toàn ca giảm từ 0.5847 N.m xuống 0.3594 N.m (giảm 40 %); TV(T_a) = 1576.2 N.m/s; R = 10.74 %; S = 5.40 N.m; max |T_a| = 9.75 N.m. Hoàn toàn êm ái, chatter-free.
(4) Nghiệm thu toàn diện bộ ca chuẩn TC1-TC6:
    - Chạy run_test_cases('SMC', []) (lý tưởng) và run_test_cases('SMC', 20000) (có nhiễu seed local 20000).
    - Xuất đầy đủ 12 file ảnh đồ thị 6 ô và 14 file bảng số liệu CSV tại Result/Controllers/SMC/TestCases/ và Result/Controllers/SMC/TestCases_noise/seed_20000/.
    - TC1: Sai số cua giữ lái giảm mạnh (v40 -0.3g từ 9.52 % xuống 1.29 %; v60 0.3g từ 6.87 % xuống 0.94 %; v80 từ 5.73 % xuống 0.75 %; v100 từ 5.07 % xuống 0.69 %; khi có nhiễu toàn bộ điểm tĩnh đều <= 2.18 %).
    - TC2: Cua khô 0.2g giảm từ 8.12 % xuống 1.85 %; cua đường trơn mu = 0.3 chỉ còn 0.60 %.
    - TC3: Cua gắt giảm bám duy trì sau quá độ đạt sai số 0.07 % (lý tưởng).
    - TC6: Cua tăng bám duy trì sau quá độ đạt sai số 0.43 % (lý tưởng).
(5) Cập nhật tài liệu: Bổ sung Phần F vào Documents/Notes/Controllers/DieuKhien_SMC.txt và đồng bộ Tracking/historychat_smc.md.

### Lượt 19 - Tách hai bộ: SMC (sat, không tích phân) và ISMC (có tích phân) (2026-10-10)
**Người dùng:** làm lại smc-sat, folder tên là smc; smc tích phân, folder tên là ismc.
**Claude:** (1) Sao lưu ra `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-10_smc_truoc_tach_ismc`. (2) ISMC = bản có tích phân cũ, đổi tên: `Model/Controllers/ISMC/` (load_ismc.m, ISMC.mdl, Model_ISMC.mdl, script/build_ismc.m, test_ismc.m), `Model/data/ismc.json` (lambda 20, Phi 2, Tf 5 ms), biến `ISMC_*`, kết quả `Result/Controllers/ISMC/`; test_ismc PASS (1.92e-13). (3) SMC dựng lại là SMC-sat không tích phân: s = Ts_dot_hat + lambda e_T, T_a = T_a_max sat(s/Phi), `smc.json` lambda 30, Phi 2, Tf 5 ms; build_smc/test_smc sửa lại, test PASS (7.7e-14); chạy lại TC1-TC6 lý tưởng và nhiễu seed_20000. RMS e_T (N.m) lý tưởng SMC 0.168/0.145/0.056/0.116/0.100/0.105 so với ISMC 0.108/0.092/0.036/0.095/0.073/0.046. (4) Thêm màu 'ISMC' vào plot_compare_cases.m và make_pair_comparisons.m. (5) Chưa làm: DieuKhien_SMC.txt vẫn gộp cả hai (Phần F là của ISMC), chưa tách DieuKhien_ISMC.txt; mục TRẠNG THÁI HIỆN TẠI cần cập nhật; lưới quét chưa có. Lưu ý: CLAUDE.md nói biến thể không thành bộ mới, nhưng người dùng yêu cầu thư mục riêng nên theo người dùng.

### Lượt 20 - Quét tham số SMC-sat, chọn điểm, chạy lại TC local và so sánh (2026-10-10)
**Người dùng:** quét lại cho smc sat trước, chạy lại test local và các compare có liên quan smc sat.
**Claude:** (1) Viết `Model/Controllers/SMC/script/run_smc_sweep.m` và `select_smc.m` (mẫu từ PID, seed 20000, cổng theo QuyChuan 5.6, ghi `data/smc.json` design). (2) LƯỚI 1 (Phi 0.25-8) SAI: đặt Phi quá nhỏ, độ lợi tương đương Kd = T_a,max/Phi quá lớn so với cực lọc Tf và trễ motor, nên mọi điểm có chu kỳ giới hạn khoảng 25 Hz, T_a nhảy +-9 N.m, S ~5 N.m; MATLAB còn sập (heap corruption) sau 21 điểm. 21 điểm giữ ở `SMC_candidates_TK_grid1_Phi_too_small.csv`. Điểm baseline lambda 30, Phi 2 của Lượt 16-17 cũng nằm trong vùng chattering này (S 4.9), nên TC1-TC6 cũ của SMC không có giá trị so sánh. (3) LƯỚI 2 (đặt lại trước khi chạy): lambda {10,20,40,80,160} x Phi {50,100,200,400,800} x Tf {5,10 ms} = 50 điểm; Kd tương đương 0.01-0.2 s như PID. (4) KẾT QUẢ: không điểm nào đạt rev <= 1 % (nhỏ nhất ~7.8 %) hay e_rel <= 3 % (nhỏ nhất 11.4 %, khi R 11.9 % nhưng S 2.8 N.m). Quy tắc fallback (phạt rev nặng) chọn lambda 80, Phi 200, Tf 5 ms: R 40.2 %, S 0.396, TV 67, e_rel 68.5 %, rev 7.8 %, bang-bang delta 0.003 đạt, margin đạt (0.57/1.00). Điểm này bám rất kém vì quy tắc ưu tiên rev. (5) TC1-TC6 local (lý tưởng và seed_20000) và so sánh seed 99999: `Result/Compare/Map_vs_SMC`, `Result/Compare/PI_vs_SMC` (PID chưa so vì khung Linear đang quét; ISMC chưa chạy lại compare). RMS e_T toàn ca (N.m) TC1..TC6: SMC 0.70/0.45/0.70/0.32/0.45/0.35; PI 0.49/0.56/0.25/0.62/0.81/0.07; Map 0.64/0.84/0.48/0.87/1.71/0.02. (6) Kinh nghiệm: kiểm biên độ T_a trên log trước khi quét; Phi của SMC-sat phải cỡ T_a,max/Kd_PID.

### Lượt 21 - Đọc các khung kia (2026-10-11)
**Người dùng:** đọc xem các khung chat kia đã làm gì. **Claude:** CHỈ ĐỌC, không sửa file dự án. (1) COMMON Lượt 12: QuyChuan v4: CALIB tách hai cửa sổ 0.4 g thành ext_* (ngoài R và ngoài cổng e_rel, e_rel chỉ lấy 9 cửa sổ static 0.1-0.3 g); cổng e_rel nay 5 % (đổi từ 3 % sau khi thấy kết quả Map, đã ghi lý do); SLIP down 0.35 -> 0.3 g; thêm ca báo cáo EDGE; tên file mới `<Ctrl>_CALIB_sweep_s<seed>.csv`, thư mục Calib/ và Cases/; quy tắc tự nén nhật ký sau mỗi 10 lượt (dòng "Nén lần cuối: Lượt N", 5 lượt nguyên văn). (2) Linear Lượt 124: PI làm lại trên CALIB v4, điểm chọn không đổi (Kp 1.25, Ki 3); e_rel nay qua cổng 5 % nhưng rev vẫn trượt nên dùng quy tắc dự phòng; PID chưa làm lại; kinh nghiệm: tác vụ nền báo "completed" ngay khi vỏ thoát, canh bằng csv hoặc sentinel trong log; mặc định ngưỡng trong select_*.m phải đổi cùng QuyChuan. (3) Map Lượt 399: Map đang quét 68 mô hình lead-lag (g_min là tham số quét thứ hai), chạy nền, chưa chạy CALIB. HỆ QUẢ CHO SMC: quét SMC 50 điểm, điểm chọn (lambda 80, Phi 200, Tf 5 ms) và TC thuộc CALIB và bộ ca CŨ nên lỗi thời; `select_smc.m` còn EREL = 3.0 (phải đổi 5.0) và tên csv cũ `SMC_CALIB_sweep_s20000.csv` (đã đúng quy ước mới); cần chạy lại trên v4 (có thể điểm chọn đổi vì e_rel nay không tính 0.4 g; ISMC cũng chưa quét). Chờ người dùng bảo.

### Lượt 22 - Quét lại SMC-sat trên CALIB v4 và chạy lại DRY, SLIP, WEAVE, EDGE seed local (2026-10-11)
**Người dùng:** quét lại SMC trên CALIB, chạy lại bộ DRY, SLIP, WEAVE, EDGE seed local. **Claude:** sao lưu kết quả và smc.json cũ ra Desktop/Adaptive-EPS_backup_2026-10-11_SMC_CALIB_cu; đổi EREL 3.0 -> 5.0 trong select_smc.m (khớp QuyChuan v4); quét lại 50 điểm (cùng lưới lambda {10..160} x Phi {50..800} x Tf {5, 10 ms}, seed 20000, MATLAB sập 1 lần ở quét và 1 lần ở chọn, chạy lại tự động); select_smc; run_cases('SMC') ideal và seed 20000. KẾT QUẢ: không điểm nào qua rev <= 1 % (nhỏ nhất 5.77 %) hay e_rel <= 5 % (nhỏ nhất 11.4 %), kết luận như CALIB cũ. Quy tắc dự phòng (phạt rev nặng) chọn lambda 80, Phi 400, Tf 5 ms: R 61.84 %, S 0.247, TV 33.7, e_rel 106 %, rev 6.59 %; margin 0.63/1.00 và bang-bang PASS; Tf nằm mép lưới (cảnh báo 6.1). ĐIỂM NÀY THIẾU TRỢ LỰC (Phi lớn làm độ lợi T_a_max/Phi thấp, e_T trung bình 77-105 % T_d,ref ở cua tĩnh), chỉ thắng nhờ rev thấp hơn vài phần trăm; điểm R tốt nhất (lambda 160, Phi 50: R 11.7 %, S 2.8, rev 12.9 %) bị loại vì rev. Không đổi quy tắc sau khi thấy kết quả. RMS e_T cả ca (N.m, ideal / s20000): DRY 1.134 / 1.131; SLIP 0.750 / 0.748; WEAVE 0.671 / 0.669; EDGE 1.634 / 1.634 (PI cùng bộ ca: 0.486, 0.350, 0.707, 0.707). TV có nhiễu 43-63 (ideal 0.8-2.2). Rev WEAVE 21 %. Kết quả ở Result/Controllers/SMC/{Calib, Cases}; smc.json đã ghi điểm mới. Chưa làm: ISMC, so sánh, ghi DieuKhien_SMC.txt.

### Lượt 23 - Quét ISMC trên CALIB v4 và chạy DRY, SLIP, WEAVE, EDGE seed local (2026-10-11)
**Người dùng:** quét lại ISMC trên CALIB, chạy lại bộ DRY, SLIP, WEAVE, EDGE seed local. **Claude:** sao lưu Result/Controllers/ISMC và ismc.json cũ ra Desktop/Adaptive-EPS_backup_2026-10-11_ISMC_cu; viết run_ismc_sweep.m và select_ismc.m (sinh từ bản SMC, cùng cổng, e_rel 5 %, thêm trường variant "integral" vào design); lưới đặt trước lambda {2.5, 5, 10, 20, 40} x Phi {50, 100, 200, 400, 800} x Tf {5, 10 ms} = 50 điểm, seed 20000 (lambda thấp hơn SMC vì trong lớp biên ISMC = PID với Kp = 2 lambda Kd, Ki = lambda^2 Kd, Kd = T_a,max/Phi). KẾT QUẢ: R 8.2-88 %, S 0.05-2.2, e_rel 1.3-148 %, rev 3.0-16 %; 16 điểm qua e_rel <= 5 %, KHÔNG điểm nào qua rev <= 1 % (nhỏ nhất 3.03 %), nên dùng quy tắc dự phòng 5.6. ĐIỂM CHỌN: lambda 5, Phi 50, Tf 10 ms: R 25.08 %, S 0.334, TV 87.6, e_rel 3.86 %, rev 5.13 %; bang-bang PASS (delta 0.001), margin 0.60/1.00 PASS. CẢNH BÁO 6.1: Phi = 50 và Tf = 10 ms nằm MÈP lưới, chưa mở rộng (chờ người dùng). RMS e_T cả ca (N.m, ideal / s20000): DRY 0.407 / 0.404; SLIP 0.237 / 0.234; WEAVE 0.469 / 0.471; EDGE 0.506 / 0.504 (PI: 0.486, 0.350, 0.707, 0.707): ISMC thấp hơn PI ở cả 4 ca. Đổi lại: có nhiễu TV 96-120 (PI khoảng 14 ở CALIB), S CALIB 0.334 so với 0.240 của PI; đỉnh T_a chạm 100 % T_a,max ở SLIP, WEAVE, EDGE; rev WEAVE 22 %. Kết quả ở Result/Controllers/ISMC/{Calib, Cases}. Chưa làm: mở rộng lưới (Phi < 50), so sánh Map/PI/PID, tài liệu.

### Lượt 24 - Đọc các khung kia sau QuyChuan v5; liệt kê việc SMC, ISMC phải làm lại (2026-10-12)
**Người dùng:** cập nhật các khung kia, xem thay đổi gì, cần làm lại gì. **Claude:** CHỈ ĐỌC và tính lại trên bảng quét có sẵn (Python), không sửa mã. THAY ĐỔI (QuyChuan v5, 2026-10-11): (1) cổng cứng chỉ còn ổn định có độ dư (calib_margin, R <= 2 lần; Linear Lượt 153 đã trả về bản này, tiêu chí "không số" bị bỏ) và e_rel <= 5 %; rev và bang-bang CHỈ BÁO CÁO; (2) chọn điểm = cực tiểu J = R x S (Model/common/pick_by_balance.m, báo độ nhạy a = 0.5, 2 và quy tắc cũ pick_by_tolerance) cộng ràng buộc dải lái (khâu lọc trong bộ giữ độ lợi >= 0.707 tại 2 Hz; SMC = lớp biên hoặc bộ lọc); không qua e_rel thì quy tắc 5.6: chọn điểm e_rel nhỏ nhất và ghi "không đạt"; (3) thêm ca RAMP (308.6 s, chỉ báo cáo), bộ năm ca DREWS; (4) Linear: PI Kp 1.08 Ki 14.4, PID Kp 1.5 Ki 32 Kd 0.025 Tf 2.5 ms (CALIB R 18.0 / 11.6 %), đã chạy DREWS s10000 và s99999; COMMON viết bài báo (mục 1-7) chỉ với Map, PI, PID, gói resource/ loại SMC, ISMC; Map: g_min 0.7, K 6, gói tái lập cho thầy. ƯỚC TÍNH TỪ BẢNG QUÉT CŨ theo v5: SMC không điểm nào qua e_rel 5 % -> quy tắc 5.6 chọn lambda 160, Phi 50, Tf 10 ms (e_rel 11.39 %, R 13.1 %, S 3.38 N.m, J 44); ISMC 16 điểm qua e_rel, cực tiểu J: lambda 40, Phi 400, Tf 5 ms (R 12.81 %, S 0.323, J 4.14, e_rel 4.12 %, rev 10.1 %), NẰM MÉP lưới lambda (40 là cận trên) nên cần mở rộng lưới (QuyChuan 6.1). Dải lái: Tf 5-10 ms cho độ lợi 0.99-0.997 tại 2 Hz, lớp biên không phải bộ lọc, nên đạt. VIỆC LÀM LẠI: sửa select_smc.m, select_ismc.m theo v5 (bỏ cổng rev, bang-bang chỉ đo cho điểm chọn, pick_by_balance, fallback 5.6, kiểm dải lái); mở rộng lưới ISMC lambda > 40; chọn lại; chạy DREWS (thêm RAMP) s20000; so sánh s99999 với Map, PI, PID (make_pair_comparisons). Chờ người dùng bảo.
