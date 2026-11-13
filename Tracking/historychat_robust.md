# Nhật ký khung ROBUST (việc A: độ bền của Map, PID, MapPID khi tham số Plant sai lệch)

Khung do người dùng mở 2026-11-12. Kế hoạch: `Documents/Shared/KeHoach_DoBenThamSo.txt` (tự đủ). Chạy song song với khung WEAVE (việc B) trên cùng PC. Chỉ ghi nhật ký, thư mục `Result/Compare/Robust/` và script `Model/shared/Sim/script/{robust_variants,check_robust_variables,run_robust_cases,summarize_robust,plot_robust}.m`. KHÔNG commit cho tới khi người dùng bảo (không dùng sync_repo.sh).

Đã chốt (người dùng theo đề xuất): mức +-20 % chung mọi nhóm; đổi m thì đổi Iz cùng tỉ lệ; BỎ biến thể gộp; 5 seed 99995-99999 cho biến thể sát ngưỡng hòa, làm SAU CÙNG.

---

## TRẠNG THÁI HIỆN TẠI (2026-11-13, sau Lượt 5)

- Lượt 5: xong kiểm ma sát khô T_f = 0 (KeHoach_MaSatCotLai.txt, mục 6 đã điền; kết quả Result/Compare/Friction/). Chưa commit.

- XONG việc A (Lượt 4). R0-R3 đạt, 17 biến thể seed 99999, 5 seed cho 9 biến thể. Báo cáo ở mục 10 của KeHoach_DoBenThamSo.txt; kết quả ở Result/Compare/Robust/. Chưa commit (chờ lệnh người dùng).

## BẢN NÉN

Nén lần cuối: chưa nén.

## NHẬT KÝ NGUYÊN VĂN

### Lượt 1 (2026-11-12) - Khởi động khung, viết script, chuẩn bị R0
Đọc CLAUDE.md, Tracking/CLAUDE.md, KeHoach_DoBenThamSo.txt hết (kể cả mục 9), mẫu historychat_vdb_tire.md, lượt mới nhất khung khác chưa cần (chưa có khung WEAVE ghi). Ổ trống trước khi chạy: C 95 GB, D 635 GB. Cache Simulink riêng D:\sim_cache\robust, TEMP D:\sim_tmp\robust. Biến thể dự kiến: nom + 16 (Tf, Jcol, Ccol, Mass, Calpha, Trail, Caster, Motor, mỗi nhóm p20 và m20), seed 99999. Bắt đầu chạy R0.

### Lượt 2 (2026-11-12) - R0, R1 đạt; bắt đầu 16 biến thể
R0 PASS (Result/Compare/Robust/Robust_R0_variables.txt, mọi biến lệch < 1e-12). Chạy nom 01:26-01:37 (Map 161 s, PID 218 s, MapPID 222 s, tổng khoảng 10 phút), R1 PASS: metrics nom trùng Cases_ssw s99999 sai số tương đối 0 (Robust_R1.txt). Ước lượng 16 biến thể x 3 bộ khoảng 16 x 10 phút = 2,7 giờ. Ổ trống: C 91,8 GB, D 635 GB. Bắt đầu 01:40, bốn phiên MATLAB nối nhau (Tf+Jcol+Ccol+Mass, Calpha+Trail+Caster+Motor chia hai nửa). Cảnh báo "transport delay zero" của Delay_ctrl vô hại (có sẵn ở mọi lần chạy).

### Lượt 3 (2026-11-12) - 16 biến thể xong (51 file), R2-R3 PASS, bảng và hình; bắt đầu 4 seed phụ
Chạy 16 biến thể 01:39-02:56 (hai đợt: đợt đầu MATLAB sập heap 0xc0000374 giữa chừng nhiều lần, chạy lặp run_robust_cases('all') cho tới đủ 51 csv; script bỏ qua phần có sẵn). R2 PASS (mọi biến thể khác nom), R3 PASS (đủ hàng). Bảng: Robust_summary/rank_s99999.csv, Robust_summary_s99999.txt; hình: Robust_tornado_<CASE>, Robust_bias_STEADY, Robust_worst_<CASE>. Quy tắc chọn biến thể chạy thêm (đặt theo kế hoạch mục 2: thứ hạng đổi so với nom, hoặc hai bộ kề nhau chênh 5-7 %): Calpham20, Calphap20, Casterp20, Jcolm20, Massm20, Tfp20, Trailm20, Trailp20, thêm nom làm cơ sở; seed 99995-99998 (99999 đã có), 9 x 3 x 4 = 108 lần chạy, ước lượng 2-3 giờ. Ổ C còn 86 GB.

### Lượt 4 (2026-11-12) - Xong việc A: 5 seed, mục 10 kế hoạch
Seed phụ 99995-99998 cho nom và 8 biến thể (108 file) xong 05:21; gộp ra Robust_seeds_summary.csv/.txt (trung bình 5 seed, thứ hạng, Delta so với nom, sd/mean). Kết quả không đổi kết luận: Map cuối ở STEADY và SLIP, SLIP có MapPID < PID ở 4 biến thể, WEAVE PID < MapPID < Map ở mọi biến thể. Mục 10 của KeHoach_DoBenThamSo.txt đã điền. Chưa commit, chờ người dùng.

### Lượt 5 (2026-11-13) - Kiểm ma sát khô T_f = 0 (KeHoach_MaSatCotLai)
R0 PASS (lệch 0). Phần A: 15 lần Tf0 (Map, PID, MapPID x 99995-99999). Phần B: CALIB Map 99990-99994, tái lập 26.2365 (lệch 2e-6 so Bảng 4.5). Q1 giải thích được (ramp hết đổi dấu, chênh tĩnh <= 0.53); Q2 KHÔNG theo quy tắc (mức 85 km/h xấu đi 0.59 -> 2.35); Q3 do ma sát (cửa sổ static_v30_apos0p30g, 26.0 -> 6.0 %); Q4 ở mục 6 kế hoạch. Nhãn CALIB có dạng static_v30_apos0p30g. Điểm chốt thêm trước khi thấy số ghi ở mục 6. Không đổi quy tắc đọc. Chưa commit.
