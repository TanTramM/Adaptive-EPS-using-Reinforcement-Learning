# History_Chat VDB_BODY - Nhật ký khung VDB_BODY (thử đổi từng cổng một của khối thân VDB)

Quy ước: đọc Tracking/CLAUDE.md và Documents/Shared/ChayTu_VDB_IO.txt trước. Khung này chỉ ghi: Model/PRSM_VDB/Analyze/script/run_vdb_io_body.m, Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_body_*, file này.

---

## TRẠNG THÁI HIỆN TẠI (2026-11-06, sau Lượt 2: đã chạy xong, đã viết báo cáo, chuẩn bị commit)

- XONG: ca gốc G0, G1 ĐẠT; 22 cặp (ca, gốc) có chấm: ĐẠT 14, KHÔNG ĐẠT 7 (chỉ do FzF, FzR), KHÔNG PHÂN BIỆT 1 (BC1); BC10 chỉ ghi nhận. Mọi đầu ra chuyển động ĐẠT (21/22, BC1 không phân biệt).
- Báo cáo: Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_body_report.txt; csv: Plant_VDB_IO_body_cases.csv, Plant_VDB_IO_body_verify.csv; hình Plant_VDB_IO_body_summary.png.
- PHÁT HIỆN: F1 FzF, FzR có chuyển tải dọc (h = 0.35 m, L = 2.68 m, dấu của m*ax_b âm); F2 VDB theo ydot' = Fy/m - xdot*r, dạng Plant lệch 0.287 ở dốc BC2 (BC1 không phân biệt); F3 xdot_o vô tác dụng; F4 FzF, FzR là tải một bánh; F5 Fz ngoài cộng vào tải theo b/(a+b); F6 lệch giả do cách đo ở BC2 (góc dốc, xử lý bỏ ±2 ms).
- Việc treo (của khung COMMON): ghép vào KeHoach_Plant_VDB.txt 12.9, 12.10; sửa dòng "FzF, FzR bằng ca gốc" và "xdot_o".

---

## BẢN NÉN

Nén lần cuối: Lượt 0

---

## NHẬT KÝ NGUYÊN VĂN

### Lượt 1 (2026-11-06) - bắt đầu
- Đọc ChayTu_VDB_IO.txt, KeHoach_Plant_VDB.txt 12.2, 12.9, 12.10. Máy hostname DESKTOP-KH7N3BB (không phải PC) nên commit gắn [laptop]. Không có ổ D: use_sim_tmp rơi về thư mục tạm hệ thống; ổ C còn khoảng 35 GB (> 20 GB).
- B2: VDBBody.mdl chạy 1 s được; cổng vào WhlAngF, xdotin, FExt, MExt; cổng ra Info, xdot, ydot, psi, r, FzF, FzR: khớp 12.9.

### Lượt 2 (2026-11-06) - chạy, kiểm độc lập, báo cáo
- Viết run_vdb_io_body.m (ca BC1-BC14 trên G0, G1; ODE ode45 RelTol 1e-10 làm đáp án; đối chứng âm tính trong script; csv ghi từng dòng; chế độ {'verify'} và {'plot'}). Lỗi gặp: gán struct vào mảng rỗng `[]` (dùng repmat(struct,0,1)); ký tự CR lẫn vào chuỗi MATLAB khi sửa file bằng Python (ghi file bằng newline='' và chr(13) bỏ CR).
- Kết quả: G0, G1 ĐẠT; ĐẠT 14, KHÔNG ĐẠT 7, KHÔNG PHÂN BIỆT 1 trên 22 cặp. BC2 lần đầu KHÔNG ĐẠT (xdot 1.3e-5) là lệch giả do nội suy cắt góc dốc (kiểm bằng mẫu gốc 3.6e-15, và lệch tỉ lệ MaxStep); bỏ ±2 ms quanh góc rồi ĐẠT. Bảy ca KHÔNG ĐẠT còn lại chỉ ở FzF, FzR, đã giải thích bằng mô hình chuyển tải dọc khớp 1e-3 N.
- Bài học: kiểm trường hợp ca có dốc thì bỏ mẫu quanh góc, không chỉ một mẫu như bậc; đầu ra "không dùng" vẫn có thể phản ứng với cổng vào (FzF, FzR).
- Commit [laptop] chỉ các file của khung (mục 6 ChayTu_VDB_IO.txt).

### Lượt 3 (2026-11-11) - khởi động KeHoach_VDB_ThanXe.txt (chế độ tiết kiệm token)
- Đã sửa build_plant_variants.m (thêm Plant_VDBTireLagBody) và build_temp_test.m (thêm tag VDBTireLagBody); viết run_vdb_body_all.sh, check_tirelagbody_wiring.m (V3c, lỗi nếu hiệu lệch T_s > 0.1 điểm %), summarize_vdb_body.m trong Model/VDB/temp_test/script/. V0 chạy thử đạt. Khởi động script nền một lần; tiến độ ở Model/VDB/temp_test/Summary/VDB_body_progress.txt. Chưa commit.

### Lượt 4 (2026-11-11) - xong KeHoach_VDB_ThanXe.txt (V0-V5)
- Lần chạy đầu hỏng V1, V2, V3b vì setup_paths không thêm temp_test/script và Plants/script vào path; thêm addpath vào SETUP của run_vdb_body_all.sh rồi chạy lại (không đổi tham số, ca, cấu hình).
- V3c đạt: hiệu lệch T_s (TireLagBody - TireLag) = -0.0001 điểm % (ngưỡng 0.1). Số hai dãy ở Summary/VDB_body_wiring_s99999.txt.
- Kết quả (seed 99999, RMS_eT đổi % so với mốc, Map/PID/MapPID): VDBBody ≤0.1 % mọi ca; VDBTireBody ≤1.4 %; VDBTireLagBody STEADY +1.1/+0.7/+1.2, SLIP -0.9/-7.6/-2.7, WEAVE +1.5/+3.6/+5.0 (gần như trùng VDBTireLag). Thứ bậc giữ ở 10/12 ô, hòa ở SLIP của VDBTireLag và VDBTireLagBody (PID và MapPID chênh dưới 5 %). Bảng: Model/VDB/temp_test/Summary/VDB_body_summary_s99999.csv, _rank_, .txt. Chưa commit.
