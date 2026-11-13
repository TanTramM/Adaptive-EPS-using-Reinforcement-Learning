# Nhật ký khung WEAVE (việc B: vì sao MapPID bám kém PID ở WEAVE, tách đóng góp nhánh Map và nhánh PID)

Khung do người dùng mở 2026-11-12. Kế hoạch: `Documents/Shared/KeHoach_WEAVE_HaiNhanh.txt` (W0, W0b, W1, W2, W3). Chạy song song với khung ROBUST trên cùng PC (quy tắc: mục 9 của KeHoach_DoBenThamSo.txt). Chỉ ghi file nhật ký này, `Result/Controllers/MapPID/Cases_ssw_branch/`, `Result/Controllers/{PID,MapPID}/Cases_ssw_1ms/` (chỉ file seed mới), `Result/Compare/PID_vs_MapPID/` và script `Model/original/Controllers/MapPID/script/{run_weave_branches,analyze_weave_branches}.m`. Không commit, không dùng sync_repo.sh.

---

## TRẠNG THÁI HIỆN TẠI (2026-11-12, sau Lượt 5)

- W0, W0b, W1, W2, W3 XONG; mục 5 của KeHoach_WEAVE_HaiNhanh.txt đã điền; bản tóm tắt `Result/Compare/PID_vs_MapPID/PID_vs_MapPID_WEAVE_summary_s99999.txt`. Chưa commit (chờ người dùng bảo).
- Kết quả chính: MapPID - PID = +10.93 % +- 1.06 (5 seed); tăng khi chu kỳ ngắn dần trong cảnh sw (+7.8, +11.9, +13.0 %); nhánh Map nhỏ (u_map RMS 0.12 so với u_PID 4.05 N.m ở sw1p5) và D1-D3 đóng tối đa 0.9 % khoảng cách toàn ca; K3 (gain PID khác) chưa kiểm, có thể đề xuất chạy MapPID với bảng bằng 0.
- Việc treo: chờ lệnh commit; file mới: 2 script trong Model/original/Controllers/MapPID/script, Cases_ssw_branch, file 1 ms seed 99995-99998 của PID và MapPID (WEAVE) cùng PID_STEADY_s99995, s99996, PID_SLIP_s99995 (thừa), Result/Compare/PID_vs_MapPID, KeHoach_WEAVE_HaiNhanh.txt mục 5.

---

## BẢN NÉN

Nén lần cuối: chưa (0 lượt).

---

## NHẬT KÝ NGUYÊN VĂN (5 lượt gần nhất)

### Lượt 1 (2026-11-12) - Nhận việc, đọc kế hoạch, chưa chạy

- Đọc: CLAUDE.md, Tracking/CLAUDE.md, KeHoach_WEAVE_HaiNhanh.txt, mục 9 KeHoach_DoBenThamSo.txt, nhật ký khung VDB_TIRE (đầu file), make_cases.m (buildWEAVES, chain, assemble), export_ssw_signals.m, load_mappid.m, metrics seed 99999.
- Phát hiện cấu trúc: `S.win` có label, t0, t1; chu kỳ không lưu trong S nên lấy từ định nghĩa buildWEAVES (ctr 5 s, lane 2.5 s, sw0p3 3.333 s, sw0p8 1.25 s, sw1p5 0.6667 s, mu3 1.3333 s). Độ lệch cảnh trong ca 100 s suy từ t0 của cửa sổ (ví dụ lane_ref t0 = off + 1.8), không gõ tay.
- RMS e_T toàn ca WEAVE seed 99999 (file metrics, 'whole case'): PID 0.203429, MapPID 0.224366 (chênh +10.3 %; bài ghi 10.9 % là trung bình 5 seed).
- File 1 ms hiện có: seed 99999 của PID và MapPID (STEADY, SLIP, WEAVE). Seed 99995-99998 chưa có file 1 ms (W0b sẽ sinh).
- Việc kế: viết analyze_weave_branches.m, chạy W0.

### Lượt 2 (2026-11-12) - W0 seed 99999 xong, bắt đầu W0b; dò cấu trúc model

- Dò Model_MapPID (chỉ load_system, close_system(.,0)): bộ điều khiển nằm ở `Model_MapPID/Model_MapPID/MapPID`; Sum_Ta (Inputs `++++`) nhận bốn khối From: From11 tag `u_map` (nguồn: subsystem `Cal u_map`, cổng 1), From12 tag `u_P` (nguồn `Prod_P`), From13 tag `u_I` (nguồn `Int_uI`, DiscreteIntegrator), From14 tag `u_D` (nguồn `Sum_d`). Cal u_map = khối Disc_H (DiscreteTransferFcn, Numerator `MapPID_H_num`, Denominator `MapPID_H_den`) với đầu vào là bảng Cal T_a_map. H rời rạc Tustin 1 ms, bậc 2, hệ số DC 1. Bảng MapPID_table 17 x 1001. Vùng chết Ts0 = 0.3 nằm trong map.json design và vào bảng qua map_variables(Cal, d).
- D3 làm được trong bộ nhớ: gọi `mappid_variables(calibrate_map_cached(), d)` với d.Ts0 = 0 (cùng d như mappid_design_variables), không sửa file. D1: bỏ trường lag của d (khi đó H chỉ còn lead qua map_variables). D2: MapPID_H_num = 1, MapPID_H_den = 1.
- analyze_weave_branches.m (Model/original/Controllers/MapPID/script/): bước 'W0' xong. Cửa sổ lấy từ S.win của make_cases('SSW'): ctr, lane1, lane2, sw0p3, sw0p8, sw1p5, mu3 (lane1, lane2 là hai chu kỳ lái làn [1,3.5] và [5.5,8] s của cảnh, offset suy từ lane_ref.t0; chu kỳ lấy từ buildWEAVES).
- Kiểm toàn ca (t >= 2 s) từ file 1 ms so với cột RMS_eT_Nm của metrics seed 99999: PID 0.203429 vs 0.203429 (lệch 0.0000 %), MapPID 0.224366 vs 0.224366 (lệch -0.0000 %). ĐẠT (ngưỡng 0.1 %).
- W0 seed 99999 (RMS e_T N.m, PID -> MapPID, chênh %; biên độ T_s/T_d_ref PID | MapPID; trễ T_s sau T_d_ref ms PID | MapPID): ctr P 5 s: 0.1699 -> 0.1846 (+8.7 %), 0.971 | 0.972, 8.7 | 9.8; lane1 2.5 s: +4.0 %, 0.969 | 0.965, -4.7 | 0.9; lane2: +3.8 %, 0.967 | 0.964, -3.9 | 0.3; sw0p3 3.33 s: +7.0 %, 0.962 | 0.960, 1.6 | 3.7; sw0p8 1.25 s: 0.2833 -> 0.3186 (+12.5 %), 0.884 | 0.880, 1.9 | 4.3; sw1p5 0.667 s: 0.4685 -> 0.5273 (+12.5 %), 0.693 | 0.674, 5.3 | 10.7; mu3 1.33 s: +9.1 %, 0.898 | 0.891, 2.9 | 6.7. Toàn ca +10.3 %. Quan sát: khoảng cách RMS lớn nhất ở sw0p8 và sw1p5 (chu kỳ ngắn), biên độ hai bộ gần như bằng nhau (chênh dưới 2 điểm phần trăm), trễ của MapPID lớn hơn PID 1-5.5 ms ở sw và mu3. Chưa kết luận (cần 5 seed, W1-W3). Cột peak_dt_ms (thời điểm đỉnh |e_T| so với điểm qua 0 gần nhất) không ổn định, chưa dùng để kết luận.
- Ổ C trống 95 GB, ổ D 635 GB trước khi chạy W0b.
- Ra: Result/Compare/PID_vs_MapPID/PID_vs_MapPID_WEAVE_windows_s99999.csv và _windows_long_s99999.csv.
- Đang chạy W0b nền (scratch/run_w0b.m, log scratch/w0b.log): export_ssw_signals cho PID và MapPID, seed 99995-99998; cache D:\sim_cache\weave.

### Lượt 3 (2026-11-12) - W0b xong, W0 năm seed xong, bắt đầu W1

- W0b: export_ssw_signals chạy cả ba ca nên quá chậm (khoảng 2 phút/ca); đã dừng sau khi nó sinh PID_STEADY_s99995, s99996, PID_SLIP_s99995, PID_WEAVE_s99995 (thừa, giữ) và thay bằng `scratch/run_w0b.m` chỉ chạy ca WEAVE, cùng mã runCase, cùng tên file `<Ctrl>_WEAVE_sig1ms_s<seed>.csv` trong Cases_ssw_1ms, seed 99995-99998 của PID và MapPID (độc lập, ghi nhận lệch so với kế hoạch: không dùng export_ssw_signals cho STEADY, SLIP vì không cần). Cache D:\sim_cache\weave, close_system(.,0). Lỗi đã gặp: load_pid ghi đè biến `c` của script gọi (đúng cảnh báo trong CLAUDE.md), nên dùng tiền tố `wk_`.
- W0 năm seed (99995-99999), kiểm toàn ca: RMS e_T từ file 1 ms khớp cột metrics cả 10 cặp (lệch 0.0000 %). Toàn ca MapPID - PID: +10.93 % +- 1.06 (độ lệch chuẩn qua seed), khớp số 10.9 % của bài.
- Theo cửa sổ (trung bình qua 5 seed; chênh RMS e_T MapPID so với PID, %): ctr (P 5 s) +10.5 +- 2.0; lane1 (2.5 s) +6.1 +- 2.6; lane2 +2.2 +- 5.8; sw0p3 (3.33 s) +7.8 +- 1.3; sw0p8 (1.25 s) +11.9 +- 0.9; sw1p5 (0.667 s) +13.0 +- 0.7; mu3 (1.33 s) +9.0 +- 0.2. Chênh biên độ T_s/T_d_ref (MapPID - PID, điểm phần trăm): từ -0.04 đến -1.65 (MapPID biên độ thấp hơn, lớn nhất ở sw1p5). Chênh độ trễ T_s sau T_d_ref (ms): ctr 0.4 +- 0.6, lane 5.1 và 4.7, sw0p3 2.1, sw0p8 2.5, sw1p5 5.3, mu3 3.7; độ lệch chuẩn qua seed nhỏ (0.07-0.3) trừ lane (0.5-1.0).
- Ra: PID_vs_MapPID_WEAVE_windows_5seeds.csv, _5seeds_per_seed.csv, _windows_s99999.csv, _windows_long_s99999.csv trong Result/Compare/PID_vs_MapPID/.
- Quy tắc đọc W3 đặt TRƯỚC khi chạy: một phép chẩn đoán Dk "góp phần" nếu RMS e_T của Dk thấp hơn MapPID quá 5 % (ngưỡng hòa) trong cửa sổ hoặc toàn ca; báo thêm tỉ lệ khoảng cách MapPID-PID đã đóng.
- Đang chạy W1 nền (run_weave_branches('W1'), log scratch/w1.log).

### Lượt 4 (2026-11-12) - W1 và W2 xong, bắt đầu W3

- W1 (run_weave_branches('W1'), seed 99999): lần chạy đầu ra tên file `..._ideal` vì `load_mappid` chạy trong phạm vi hàm đã ghi đè biến `seed` bằng [] (load_sensors.m dòng 10), nên cảm biến lý tưởng; may bị bắt bởi lỗi không thấy file cũ. Sửa: nạp bằng `evalin('base', 'run(...)')`, đọc biến base bằng evalin. Bài học: KHÔNG chạy các load_*.m trong phạm vi hàm (chúng ghi đè `seed`, `c`...).
- Khối nguồn của bốn dây vào Sum_Ta (đã ghi ở Lượt 2): u_map = `Cal u_map` cổng 1, u_P = `Prod_P`, u_I = `Int_uI`, u_D = `Sum_d`; T_a_cmd = cổng ra `Sum_Ta`. Bật DataLogging trên cổng ra các khối này và SignalLogging on, chỉ trong bộ nhớ; close_system(.,0). Thêm cột T_s_meas (cảm biến, vùng chết nhìn thấy giá trị này).
- Kiểm: (a) max|u_map + u_P + u_I + u_D - T_a_cmd| = 0 N.m (ngưỡng 1e-9); (b) max|T_s - file 1 ms cũ seed 99999| = 5.1e-15 N.m (e_T 4.9e-15, T_a 5.3e-15; ngưỡng 1e-9). ĐẠT, việc bật ghi không đổi lời giải. Ra: Result/Controllers/MapPID/Cases_ssw_branch/MapPID_WEAVE_branch_s99999.csv (100001 dòng).
- W2 (analyze_weave_branches('W2')): ghi PID_vs_MapPID_WEAVE_branch_windows_s99999.csv, _branch_crossings_s99999.csv (từng điểm qua 0 của T_d_ref khớp, đoạn +-0.3 chu kỳ nằm trọn trong cửa sổ) và _branch_crossings_mean_s99999.csv; ba hình _zoom_sw1p5_, _zoom_lane_, _zoom_mu3_ (png). Hình đầu: chú giải ra màu đen do renderer; đã đặt Renderer painters, cần vẽ lại.
- Số W2 (MapPID, seed 99999, RMS N.m): u_map nhỏ so với PID ở mọi cửa sổ: ctr 0.06 vs 1.90; lane1 1.01 vs 2.93; lane2 0.98 vs 2.99; sw0p3 0.33 vs 2.46; sw0p8 0.25 vs 3.18; sw1p5 0.12 vs 4.05; mu3 0.43 vs 3.96 (u_PID = u_P + u_I + u_D, trong đó u_I 1.7-3.6 lớn nhất). Tỉ lệ thời gian |T_s đo| < 0.3 N.m: ctr 10.9 %, lane 2.7 %, sw0p3 6.3 %, sw0p8 8.6 %, sw1p5 9.6 %, mu3 5.3 %; độ dài trung bình một lần vào vùng chết quanh điểm qua 0: 50, 38-41, 72, 44, 20, 34 ms. Tỉ lệ thời gian hai nhánh ngược dấu 51-65 %, nhưng RMS phần ngược dấu (min của hai biên độ) nhỏ ở cửa sổ có u_map nhỏ (sw1p5 0.096, sw0p8 0.196) và lớn ở lane (0.70). Độ trễ thành phần cơ bản của u_map sau T_s (khớp sin, ms): 15 (sw1p5), 23 (sw0p8), 29 (sw0p3), 22 (mu3), 29-30 (lane); T_s sau T_d_ref: 10.7, 4.3, 3.7, 6.7. Độ trễ cơ bản của u_PID so với T_s không dùng được (u_PID do tích phân chi phối, vài trăm ms).
- Ghi chú đọc: u_map chỉ đóng góp RMS nhỏ ở cửa sổ chu kỳ ngắn (sw1p5), nơi khoảng cách PID-MapPID lớn nhất (+13 %); cần W3 để biết bỏ lag, bỏ cả H, bỏ vùng chết có đổi khoảng cách không.
- Đang chạy W3 nền (run_weave_branches('W3'), log scratch/w3.log).

### Lượt 5 (2026-11-12) - W3 xong, tóm tắt, điền mục 5 kế hoạch

- W3 (run_weave_branches('W3'), seed 99999): bảng dựng lại trong bộ nhớ trùng biến load_mappid (lệch 0). D1 đặt MapPID_H_num/den = lead-only Tustin (num [15.287 -14.784], den [1 -0.4963]; bảng không đổi); D2 đặt H = 1; D3 thay MapPID_table bằng bản dựng với Ts0 = 0 (cùng điểm gãy). Không sửa file; restore biến sau mỗi lần. RMS e_T toàn ca (t >= 2): PID 0.2034, MapPID 0.2244, D1 0.2223 (-0.9 %), D2 0.2230 (-0.6 %), D3 0.2238 (-0.3 %). Theo quy tắc đặt trước ở Lượt 3 (giảm quá 5 % so với MapPID): chỉ D1 ở lane1 (-6.6 %) và lane2 (-7.2 %). Ở sw0p8, sw1p5: D1 -2.9, -1.9 %; D2 -0.7, 0.0 %; D3 +0.3, +0.4 %. D3 làm được bằng biến trong bộ nhớ nên không cần bỏ.
- Hình W2 vẽ lại: chú giải bằng tiêu đề tô màu TeX (renderer phần mềm vẽ sai màu chú giải).
- Ra: Result/Compare/PID_vs_MapPID/PID_vs_MapPID_WEAVE_diag_s99999.csv, MapPID_WEAVE_diag_{D1,D2,D3}_s99999.csv ở Cases_ssw_branch/, PID_vs_MapPID_WEAVE_summary_s99999.txt, mục 5 của KeHoach_WEAVE_HaiNhanh.txt.
- Bài học: (1) load_*.m ghi đè biến của nơi gọi (seed, c), nên nạp bằng evalin('base') hoặc script cấp base, dùng biến tiền tố riêng; (2) kiểm tên file kết quả (`ideal` thay vì `s99999`) bắt được lỗi cảm biến ngầm; (3) export_ssw_signals chạy cả ba ca (khoảng 2 phút/ca), chỉ cần một ca thì viết vòng riêng.
- Câu hỏi còn mở (không nằm trong kế hoạch, đề xuất cho người dùng): chạy MapPID với nhánh Map tắt để kiểm K3.
