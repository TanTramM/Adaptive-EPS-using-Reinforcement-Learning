# Nhật ký khung VDB_TIRE (thử đổi từng cổng một của khối lốp VDB)

Khung do người dùng mở 2026-11-06. Việc: thử đổi từng cổng một của khối lốp VDB (Combined Slip Wheel 2DOF, cấu hình S2) trong `Model/PRSM_VDB/Analyze/VDBTire.mdl`, khẳng định hoặc bác bảng ánh xạ cổng VDB <-> Tires (KeHoach_Plant_VDB.txt 12.9 phần B, kể cả 27 ô ScaleFctrs). Chạy tự động theo `Documents/Shared/ChayTu_VDB_IO.txt` (mục 8 riêng cho khung này). Chỉ ghi: `Model/PRSM_VDB/Analyze/script/run_vdb_io_tire.m`, `Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_tire_*`, file này. Tự commit đúng các file đó (không dùng sync_repo.sh).

---

## TRẠNG THÁI HIỆN TẠI (2026-11-06, sau Lượt 2)

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
