# Nhật ký khung VDB_TIRE (thử đổi từng cổng một của khối lốp VDB)

Khung do người dùng mở 2026-11-06. Việc: thử đổi từng cổng một của khối lốp VDB (Combined Slip Wheel 2DOF, cấu hình S2) trong `Model/PRSM_VDB/Analyze/VDBTire.mdl`, khẳng định hoặc bác bảng ánh xạ cổng VDB <-> Tires (KeHoach_Plant_VDB.txt 12.9 phần B, kể cả 27 ô ScaleFctrs). Chạy tự động theo `Documents/Shared/ChayTu_VDB_IO.txt` (mục 8 riêng cho khung này). Chỉ ghi: `Model/PRSM_VDB/Analyze/script/run_vdb_io_tire.m`, `Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_tire_*`, file này. Tự commit đúng các file đó (không dùng sync_repo.sh).

---

## TRẠNG THÁI HIỆN TẠI (2026-11-07, sau Lượt 5)

- **CHẨN ĐOÁN LỆCH XONG (Lượt 4-5).** Đã có SSW seed 99999 của Map, PID, MapPID trên ba bản Plant: gốc, VDBTireLag (độ trễ lốp, T_r theo PT 17), VDBTireLagMz (có M_z). Phần lệch lớn của PID, MapPID nằm trong ba giây T_a chạm giới hạn: STEADY 9 s (đánh lái nhanh, do M_z/trail), SLIP 67 s và 87 s (mu tăng lại, do độ trễ lốp). Bỏ ba giây đó: PID, MapPID lệch +1 đến +7 %; Map STEADY +13 % khi có M_z (lệch đều, Map không có phản hồi). Thứ bậc các bộ không đổi.
- Báo cáo tiếng Việt: `Documents/Report/VDB_tire_baocao.docx`, sinh bằng `tools/build_report_vdb_vi.py` (hình `Result/Report/VDB/VDBvi_*.png`); bản tiếng Anh cũ `VDB_tire_report.docx` giữ nguyên, chưa cập nhật phân tích mới.
- Chờ người dùng (và thầy) chọn: (A) so sánh chính dùng VDBTireLag, bản có M_z làm phép thử độ nhạy; hoặc (B) dùng bản có M_z và giải thích PT (17) đơn giản hóa trail.

### Trạng thái trước Lượt 4 (2026-11-07, sau Lượt 3)

- **KHỐI LỐP VDB TẠM CHỐT (2026-11-07).** Model/ đã tái cấu trúc (shared, original, VDB; xem Tracking/CLAUDE.md). Bản lốp dùng: `Model/VDB/Blocks/Tires_VDBLagMz.slx` (độ trễ lốp thật + T_r từ M_z của lốp, hệ số trail khớp có ràng buộc vật lý, `data/vdb_trail_fit.json`), Plant `Model/VDB/Plants/Plant_VDBTireLagMz.slx`, vòng kín `Model/VDB/temp_test/<Ctrl>/Model_<Ctrl>_VDBTireLagMz.slx`.
- Hệ số: QBZ1 11.78, QCZ1 1.083, QEZ1 -3.03, QDZ1 0.0487 (t(0) = t_0); ràng buộc QBZ1 6-12, QCZ1 1.05-1.29, QEZ1 -4..0 lấy từ Pacejka [2] Bảng 4.2, A3.1 và lốp thư viện. Hở mạch T_s lệch 1.65 / 2.03 / 1.47 % (ngưỡng 3 %).
- SSW seed 99999, RMS e_T Plant -> VDB: Map 1.058->1.193, 0.690->0.680, 1.451->1.501; PID 0.249->0.304, 0.205->0.170, 0.203->0.214; MapPID 0.250->0.305, 0.197->0.171, 0.224->0.237. Kết quả ở `Model/VDB/temp_test/<Ctrl>/Result/`.
- Báo cáo gửi thầy (tiếng Anh): `Documents/Report/VDB_tire_report.docx`, sinh bằng `tools/build_report_vdb.py`, hình ở `Result/Report/VDB/`.
- Luận văn = bài báo + mục VDB ở cuối chương 5; khác biệt PT (17) (dạng tuyến tính của [4]) với mô hình chổi (3.13) của [2] viết ở mục đó, không sửa plant.txt.
- Việc treo: thay thân 2DOF bằng thân VDB 3DOF (đã dựng, lệch dưới 0.03 %); nối F_z của thân vào lốp (chuyển tải); chạy ba bộ trên xe VDB đầy đủ; ghi chú phản biện điểm 5-8 (GhiChu_VDB_Tire_KhuatMat.txt) còn gác.

### Trạng thái cũ (2026-11-06, sau Lượt 2)

- XONG phần chạy và báo cáo: 49 mã ca; 31 ca có tiêu chí (31 ĐẠT, 0 KHÔNG ĐẠT, 0 KHÔNG PHÂN BIỆT), 18 ca chỉ ghi nhận (14 ô ScaleFctrs có tác dụng, TC33, TC34, TC35a, TC35b). TCW1, TCW2 trên S2 (SLIP, WEAVE): lệch 0.
- Dòng ánh xạ 12.9 B khẳng định bằng đo trực tiếp: Vx, Vy, Info.Alpha, Fext/Fz, Fy theo tải, ScaleFctrs ô 3 = mu, Fy x2 ra cầu, trễ 1.5915 ms, YawRate và Gnd không tác dụng, Prs không đổi Fy, T_r của S2 (dây nối), hệ số Fy gộp. Bác một phần: giả định "Kappa gần 0 suốt ca" (Kappa(0) = 0.0212). Không dòng nào bị bác hoàn toàn.
- Điểm đáng ghi: (1) TC33, TC34 kỳ vọng "Fy giảm do trượt kết hợp" bị bác vì RBY1 = 0 trong vdb_tire_config.m (Fy không đổi); (2) camber đổi Mx, Mz không đổi Fy; (3) 15 trong 27 ô ScaleFctrs có tác dụng ở điểm L1 (ô 1, 6 đổi Fy khoảng 4.5-4.7 %; ô 4 đổi 1.2e-3 khi 0.1).
- Báo cáo: `Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_tire_report.txt` (cùng `_cases.csv`, `_summary.csv`, `_map.csv`, `_scale27.csv`, `_summary.png`). Việc ghép vào 12.9, 12.10, DoiChieu_Plant_VDB.txt là của khung COMMON.
- Máy: DESKTOP-KH7N3BB (không phải PC) nên thẻ commit [laptop]; không có ổ D, cache lốp ở thư mục tạm hệ thống (cache_tire).

---

## BẢN NÉN

Nén lần cuối: Lượt 0

(chưa có)

---

## NHẬT KÝ NGUYÊN VĂN

### Lượt 1 (2026-11-06) - Bắt đầu
Đọc ChayTu_VDB_IO.txt, KeHoach_Plant_VDB.txt 12.2, 12.9, 12.10, build_vdb_io.m, load_vdb_io_defaults.m, vdb_tire_config.m, load_vdb_params.m, check_vdb_tire.m, build_vdb_s2.m, compare_vdb_s2.m, make_plant_baseline.m. Nhận xét: hostname không phải PC, không có ổ D, không có baseline .mat.

### Lượt 2 (2026-11-06) - Chạy TC1-TC40, TCW1-TCW2, báo cáo, commit
- Kiểm môi trường (B2): VDBTire.mdl có 10 cổng vào (BrkPrs, AxlTrq, Vx, Vy, Camber, YawRate, Prs, Gnd, Fext, ScaleFctrs) và Info + 7 cổng ra (Omega, Fx, Fy, Fz, Mx, My, Mz), khớp 12.9; chạy 1 s được; F_z một bánh = 4548.73 N, C_alpha = 160000.
- Script `run_vdb_io_tire.m` (hàm có tham số stage: all, tc1, cells, misc, tcw, report; csv ghi từng ca, chạy lại bỏ qua ca đã có). Mọi đầu vào của mọi ca (cả ca gốc) có cùng điểm gãy tại 0.5 s để bước giải giống nhau; MaxStep 1e-4, RelTol 1e-9, AbsTol 1e-12. Mã ca: GL0, GL1 (ca gốc), TC1-TC5b, TC32 (ô 3 x 1.1, đối chứng dương), TCc<k> (TC6-TC31, ô k), TC33-TC38, TC39 (trễ), TC40 (x2 ra cầu), TCW1/2_SLIP/WEAVE.
- Lỗi gặp: (a) chuỗi tiếng Việt trong file .m bị hỏng khi MATLAB đọc (đổi sang nguồn ASCII, từ tiếng Việt ghi bằng mã ký tự khi ghi csv; lần đầu thiếu chữ H trong "GHI NHẬN", "CHẠY"); (b) ca TC6-TC38 truyền nhầm cấu trúc rỗng thay cho hàm làm lỗi "struct as an index", các dòng LỖI CHẠY đã xóa và chạy lại; (c) MATLAB sập heap một lần giữa các lệnh nối nhau, chạy lại bằng stage riêng; (d) hình lần đầu thang quá cao nên cột ĐẠT không thấy, sửa sàn trục.
- Kết quả: xem TRẠNG THÁI HIỆN TẠI và báo cáo. Fy khớp PT(10) trong 2e-12 ở mọi ca có đáp án; TC39: tau = 1.5915 ms (1/(2*pi*100 Hz)), lệch 0.097 %. TCW1, TCW2 lệch đúng 0 (cùng công thức với TireInputs, TrCalc nên chỉ kiểm dây nối).
- Bài học: mọi đầu vào cùng điểm gãy ở ca gốc làm ca "không đổi" lệch đúng 0 (TC36, TC38), nên các lệch nhỏ 1e-7 ở một số ô là tác dụng thật (qua trượt dọc dư), không phải nhiễu bước giải. Bản đo mốc baseline .mat không có trên laptop; TCW dựng đầu vào từ make_cases('SSW').
- Commit đúng file của khung (không sync_repo.sh, thẻ [laptop]).

### Lượt 3 (2026-11-06 đến 2026-11-07, PC) - Ghi chú phản biện, tái cấu trúc Model/, thực tế hóa lốp VDB, SSW ba bộ, báo cáo thầy
- Giải thích Kappa và các điểm còn vướng của khối lốp; người dùng chốt giữ nguyên Kappa ban đầu, RBY1 = 0, độ nhạy tải (nguyên tắc "giống điều kiện Plant gốc nhất"); điểm 5-8 gác. Ghi ở `Documents/Shared/GhiChu_VDB_Tire_KhuatMat.txt`.
- Tái cấu trúc `Model/` thành shared, original, VDB (sao lưu Desktop/Adaptive-EPS_backup_2026-11-06_Model_truoc_tai_cau_truc); sửa đường dẫn khoảng 190 file .m và tools; VDB gồm Blocks, Plants (5 Plant), temp_test (Map, PID, MapPID x 5 biến thể), Archive. Lỗi gặp: sed làm hỏng chuỗi `\n` trong .m (sửa tay); load_plant_vdb gán vdb_v0 sai workspace (đổi sang assignin base).
- Lốp thực tế hóa: bước 1 độ trễ (FyRelFreqLwrLim 1 rad/s, sigma 0.609 m); bước 2 T_r từ M_z. Khớp trail không ràng buộc ra QEZ1 -55 (phi lý): nguyên nhân là trail PT (17) thẳng, gãy góc, còn MF là đường chuông có độ dốc 0 tại alpha = 0; PT (17) cũng khác mô hình chổi (3.13) của Pacejka. Người dùng duyệt khớp có ràng buộc (số ở TRẠNG THÁI); kế hoạch ghi ở KeHoach_Plant_VDB.txt mục 9.
- Phát hiện: trong MF, Bt chia cho hệ số mu (lambda*_muy, Pacejka (4.E40)), nên trail co theo mu mạnh; công thức Python khớp khối MATLAB (2.38 mm so với 2.53 mm). Bản xem trước ban đầu dùng lambda' (sai) đã cho sai số 13 mm ở mu 0.3, không đúng.
- SSW seed 99999 cho Map, PID, MapPID với Plant_VDBTireLagMz; kết quả cũ (hệ số không ràng buộc) chuyển sang `unbounded_fit/`. STEADY lệch nhiều nhất (+13 / +22 / +22 %, tuyệt đối +0.135 / +0.054 / +0.055 N.m); SLIP giảm; WEAVE +3 đến +6 %; thứ bậc các bộ không đổi (PID và MapPID ở SLIP chênh dưới 5 %, hòa).
- Báo cáo thầy: `Documents/Report/VDB_tire_report.docx` (tools/build_report_vdb.py). Bài học: không tự chạy khi chưa được bảo; seed chấm là 99999 (từng chọn nhầm 99987).
- Người dùng bảo commit hết mọi thay đổi để mở trên laptop: commit và push main.

### Lượt 4 (2026-11-07, PC) - Người dùng thấy lệch so với Plant gốc lớn: chẩn đoán nguyên nhân (chỉ đọc csv đã có, không chạy mô phỏng)
- Phân rã theo bước (Map có đủ ba biến thể): STEADY 1.058 (gốc) -> 1.058 (VDBTire) -> 1.070 (Lag) -> 1.193 (LagMz): gần hết phần lệch do bước M_z (trail); WEAVE 1.451 -> 1.452 -> 1.473 -> 1.501 (Lag và Mz mỗi bước khoảng một nửa).
- PID, MapPID: mọi cửa sổ giữ cua của STEADY gần như trùng (vd v45a0p15l 0.0203 / 0.0204); +22 % đến từ MỘT giây t = 9-10 s (25 km/h, đánh lái 0 -> -130 độ trong 1 s, T_a nằm ở T_a,max -8.07 N.m, bộ điều khiển hết quyền), giây này chiếm 80 % bình phương e_T ngay cả trên Plant gốc; T_s của VDB lớn hơn khoảng 0.75 N.m ở đó. Bỏ giây này: PID +6.1 %, MapPID +7.1 %.
- SLIP -17 %: MỘT giây t = 87-88 s, mu nhảy 0.2 -> 0.8 khi đang cua; lốp gốc không có độ trễ nên F_y và a_y nhảy tức thời (a_y 1.87 -> 7.24 m/s2, T_s đỉnh 7.05), lốp VDB có độ trễ nên đỉnh thấp hơn (5.2). Bỏ giây này: PID +1.8 %, MapPID +2.0 %.
- Map STEADY +12.9 % vẫn còn khi bỏ giây đó: Map là bảng tra không có phản hồi sai số nên T_r đổi đi thẳng vào e_T ở mọi cửa sổ cua.
- Nguyên nhân gốc đề xuất: trail MF phẳng ở alpha nhỏ, PT (17) giảm tuyến tính ngay từ 0, nên ở góc trượt nhỏ (vùng xe chạy) trail VDB lớn hơn, T_r lớn hơn. Với PID chưa tách được Lag và Mz (chưa chạy Model_PID_VDBTireLag); đề nghị người dùng cho chạy để xác nhận. Script chẩn đoán ở scratchpad (where_err.py, zoom_err.py, excl.py), không commit.
- Lượt khung kia: lượt này chưa đọc lượt mới của khung VDB_BODY.

### Lượt 5 (2026-11-07, PC) - Chạy PID, MapPID có M_z và không M_z, đánh giá chi tiết, báo cáo tiếng Việt, commit
- Người dùng: "chạy mappid và pid trên plant mới, có mz, sau đó chạy lại bản không mz, đánh giá kết quả chi tiết, viết lại report mới bằng tiếng Việt, note hết vào tracking, commit và push" (gọi qua /loop, tự điều nhịp; giữa chừng hỏi tiến độ hai lần).
- Chạy `run_ssw_temp(<PID|MapPID>, 'VDBTireLagMz'|'VDBTireLag', 99999)` (MATLAB nền, khoảng 14 phút mỗi bộ mỗi Plant). Bản có M_z chạy lại cho kết quả trùng từng chữ số với bản đã commit (git không thấy khác), nên phép chạy tái lập được.
- RMS e_T gốc -> không M_z -> có M_z: PID STEADY 0.249 -> 0.251 -> 0.304, SLIP 0.205 -> 0.189 -> 0.170, WEAVE 0.203 -> 0.211 -> 0.214; MapPID STEADY 0.250 -> 0.253 -> 0.305, SLIP 0.197 -> 0.193 -> 0.171, WEAVE 0.224 -> 0.236 -> 0.237; Map (đã có từ trước) STEADY 1.058 -> 1.070 -> 1.193, SLIP 0.690 -> 0.684 -> 0.680, WEAVE 1.451 -> 1.473 -> 1.501.
- Đánh giá: script tự tìm "giây sự kiện" (giây 1 s chiếm >= 20 % tổng |thay đổi bình phương e_T| của PID so với gốc, ở bản VDB nào cũng được): STEADY {9}, SLIP {67, 87}; cả ba giây T_a nằm sát T_a,max (8.41, 9.04, 8.63 N.m). Trên Plant gốc các giây đó đã chiếm 80 % (STEADY), 81 % (SLIP) bình phương e_T của PID. Đỉnh |T_s| PID: STEADY 9 s 5.58 / 5.67 / 6.34 (chỉ bản M_z lệch -> do trail); SLIP 87 s 7.07 / 5.31 / 5.25 (hai bản VDB như nhau -> do độ trễ lốp, lốp gốc cho a_y nhảy tức thời 1.87 -> 7.24 m/s2); SLIP 67 s 4.80 / 5.28 / 4.93 (mu 0.24 -> 0.8 khi giữ -32 độ, a_y gần 0.8 g, độ trễ làm a_y giảm chậm nên T_a ở giới hạn lâu hơn; M_z bù lại một phần vì trail MF giảm nhanh ở góc trượt lớn).
- Bỏ các giây sự kiện, RMS e_T gốc -> không M_z -> có M_z: PID STEADY 0.110 -> 0.112 -> 0.117, SLIP 0.091 -> 0.095 -> 0.095, WEAVE 0.202 -> 0.209 -> 0.213; MapPID 0.112 -> 0.116 -> 0.120, 0.096 -> 0.102 -> 0.101, 0.223 -> 0.235 -> 0.237; Map 0.925 -> 0.937 -> 1.044, 0.497 -> 0.483 -> 0.505, 1.436 -> 1.459 -> 1.485. Cửa sổ giữ cua STEADY của PID, MapPID lệch tối đa 1.1 mN.m; Map lệch trung vị +0.036 N.m chỉ khi có M_z.
- Điểm từng làm tôi lạ (đã giải thích): ở Lượt 4 bỏ riêng giây 87 s thì SLIP bản không M_z còn +18 %; nguyên nhân là sự kiện thứ hai 67 s cùng loại.
- Báo cáo tiếng Việt mới: `Documents/Report/VDB_tire_baocao.docx` (`tools/build_report_vdb_vi.py`, mọi số đọc từ csv; 6 hình VDBvi_*: method, trail, rms_bars, rms_bars_excl, STEADY_event, SLIP_event; màu ba Plant lấy theo bảng màu đã kiểm của skill dataviz, slot 1-3). Mục: mục đích, đã thay gì, trail, kết quả ba Plant, phân tích chi tiết (5.1-5.4), kết luận, đề xuất A/B và bước tiếp.
- Lỗi gặp: một chuỗi f-string mở bằng " đóng bằng ' làm script lỗi cú pháp, Word giữ bản cũ mà lệnh chạy (đã chuyển stdout về /dev/null) không báo; sửa xong chạy lại và kiểm nội dung docx. Bài học: không giấu đầu ra khi sinh file, kiểm nội dung file sau khi sinh.
- Commit đúng các file của lượt (kết quả VDBTireLag của PID, MapPID, báo cáo, hình, script, nhật ký), push main, không dùng sync_repo.sh.
