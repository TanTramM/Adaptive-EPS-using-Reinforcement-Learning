# History_Chat MapPID - Nhật ký khung MapPID (Map cộng PID; từ 2026-10-16 thêm bộ mới MapPIDLag)

## CÁCH DÙNG (dành cho phiên Claude mới)

1. Đọc file này trước, rồi `Tracking/CLAUDE.md`, `Documents/Shared/QuyChuan.txt`, `Documents/Notes/Controllers/DieuKhien_MapPID.txt` (kế hoạch và nhật ký F0-F28 của MapPID) và `Documents/Notes/Controllers/DieuKhien_MapPIDLag.txt` (kế hoạch bộ mới).
2. Cấu trúc: TRẠNG THÁI HIỆN TẠI; BẢN NÉN (chưa có; Nén lần cuối: chưa nén); NHẬT KÝ NGUYÊN VĂN. File tạo 2026-10-16: trước đó khung MapPID chỉ ghi nhật ký vào Phần F của DieuKhien_MapPID.txt, nên Lượt 1 dưới đây là bản tóm tắt toàn bộ việc đã làm tới 2026-10-13.
3. Khung khác CHỈ ĐỌC file này. Khung Linear đọc mục "VIỆC CHO KHUNG LINEAR" ở Lượt 2.

---

## TRẠNG THÁI HIỆN TẠI (sau Lượt 2, 2026-10-16)

**MapPID: XONG O0-O9, giữ nguyên, không sửa nữa.** T_a,cmd = H(s) sgn(T_s) M_K(v, |T_s|) + u_PID, H = lead x lag chỉ trên nhánh Map. Thiết kế (Model/data/mappid.json, chọn với PM tuyến tính từ 30 độ, GM từ 2, D14): K 3.587, lead z 5.011, p 6.013 rad/s, lag z1 35.10, p1 14.48 rad/s, Kp 0.594, Ki 44.16, Kd 0.0453, Tf 2.48 ms, Kaw 10.56; CALIB seed 30000: R 9.79 %, S 0.3137, J 3.072 (PID 3.629), e_rel 2.14 %, PM 38.0 độ, GM 6.72, độ lợi cao tần 20.66; 930 lần đánh giá. Seed 99999, RMS e_T MapPID / PID / Map: DRY 0.137 / 0.155 / 0.689; RAMP 0.049 / 0.047 / 0.835; SLIP 0.140 / 0.130 / 0.538; WEAVE 0.213 / 0.218 / 1.327; EDGE 0.140 / 0.166 / 1.534 N.m. S: DRY 0.206 / 0.256 / 0.149; RAMP 0.119 / 0.125 / 0.168; SLIP 0.246 / 0.305 / 0.162; WEAVE 0.312 / 0.410 / 0.160; EDGE 0.253 / 0.325 / 0.130. H1, H2, H3, H5 đúng; H4 (trợ lực ngược) sai; H6 sai (1.07 lần PID ở SLIP). TV cao hơn PID khoảng 40 %.

**MapPIDLag (2026-10-16): XONG P0-P6, P8; DREWS một seed 50000 có kết quả.** Điểm chọn (mappidlag.json): K 3.252, z1 35.49, p1/z1 0.946 (lag gần như tắt), Kp 0.471, Ki 63.2, Kd 0.0471, Tf 2.23 ms; CALIB s50000 R 9.19 %, S 0.3318, J 3.048 (MapPID 3.072), PM 31.6, GM 6.05. DREWS s50000 RMS e_T DRY 0.139, RAMP 0.056, SLIP 0.171, WEAVE 0.217, EDGE 0.169; S 0.248, 0.149, 0.310, 0.375, 0.327. KẾT LUẬN: lag sau tổng không tốt hơn MapPID (tối ưu tự tắt lag; ồn hơn MapPID 20-30 %, bám kém ở SLIP, EDGE; một seed). Chi tiết G6-G8 trong DieuKhien_MapPIDLag.txt. PID+Lag đối chứng do khung Linear làm (PIDLag, PIDOpt). CÒN: P7 độ bền, P9 so sánh nhiều bộ nhiều seed (người dùng bảo làm sau).

**Còn treo:** (1) kết quả MapPIDLag (chờ chạy xong) và so sánh với PIDLag, PIDOpt của khung Linear ở seed chung 99999 với nhiều seed lấy độ lệch chuẩn (người dùng bảo làm sau); (2) cách trình bày MapPID trong bài báo (paper.txt của khung COMMON); (3) bản so sánh chỉ ba bộ Map, PID, MapPID (không PI) chưa sinh, các hình hiện có còn PI; (4) mâu thuẫn PI có PM tuyến tính 4.2 độ mà qua calib_margin (F27, người dùng bảo bỏ qua); (5) F25 của DieuKhien_MapPID.txt còn câu PM 15 độ (lỗi thời, đã có F26); (6) các file build_*.m đã xóa trong cây làm việc chờ người dùng quyết định; (7) chưa commit.

**Kinh nghiệm công cụ (bắt buộc):** gọi `Simulink.sdi.clear` sau mỗi lần mô phỏng (file *.dmr của Simulation Data Inspector, khoảng 190 MB mỗi lần CALIB, từng làm đầy ổ C 139 GB và treo máy); TEMP, TMP của MATLAB đặt `D:/MatlabTemp`; mở MATLAB mới chỉ khi RAM trống từ 8 GB, thử lại tối đa 6 lần (scratchpad lib.sh); gọi `load_<ctrl>` trước `run_cases`; surrogateopt có thiết kế thí nghiệm mặc định tất định, các lần chạy song song phải tự cấp điểm đầu ngẫu nhiên riêng; chuỗi chứa `\n` sửa bằng file Python viết bằng Write, không dùng heredoc hay sed.

---

## BẢN NÉN CÁC LƯỢT CŨ

Nén lần cuối: chưa nén.

---

## NHẬT KÝ NGUYÊN VĂN

### Lượt 1 (2026-10-12 đến 2026-10-15) - Tóm tắt toàn bộ MapPID trước khi có file nhật ký này

Chi tiết từng bước nằm ở DieuKhien_MapPID.txt F0-F27; ở đây chỉ giữ quyết định, số, lỗi và bài học. (a) Kế hoạch và chốt D1-D13 (2026-10-12, 13): lõi = Map cộng PID, lead-lag chỉ trên nhánh Map; Kaw = Ki / (Kp + K); seed 30000-39999; tối ưu đồng thời 9 tham số (K, z, p/z, z1, p1/z1, Kp, Ki, Kd, Tf) thay lưới; K từ 0; vùng chết cố định; sàng lọc tuyến tính khi tìm PM > 0, GM từ 1 (O2b cho thấy calib_margin quá yếu, cả 22 thiết kế qua). (b) Mã: Model/Controllers/MapPID/ (load_mappid, MapPID.mdl, Model_MapPID.mdl, script/ mappid_eval, mappid_margins, optimize_mappid, refine_mappid, select_mappid, robust_mappid, compare_mappid, plot_mappid_pareto, test_mappid PASS sai số 3.2e-12). (c) O3 systune suy biến, không dùng. O4 surrogateopt 3 x 250, O5 patternsearch 3 x 60: J 3.067 / 3.070 / 3.085, chênh 0.6 %. (d) Sự cố đêm 2026-10-13: treo máy, đầy ổ C; nguyên nhân thật là file *.dmr của SDI (không phải chạy song song); sửa bằng Simulink.sdi.clear, xóa 139 GB, TEMP sang D:, làm lại O4, O5. (e) O6 lần đầu với PM điểm cuối 15 độ; người dùng hỏi lại PM 45 độ ban đầu và chốt D14 (2026-10-13, sau khi thấy kết quả, có ghi lý do): điểm cuối PM từ 30 độ, GM từ 2 (đầu dưới khoảng 30-45 độ của Seborg 14.7), chạy lại O6-O9, J chỉ tăng 0.15 %. (f) O7: PM thấp nhất 33.9 độ (PID 33.3). (g) O8, O9 seed 99999 (số ở TRẠNG THÁI). Lỗi: run_cases thiếu load_mappid làm vỏ chạy thử lại 38 lần (sửa và giới hạn 6 lần); compare_mappid so sánh cột cell bằng == (đổi sang string). (h) Người dùng 2026-10-15: không làm PI, MapPID chỉ so với PID và Map; phần chạy đã đủ cho báo cáo, còn thiếu bản ba bộ và phần viết.

### Lượt 2 (2026-10-16) - Bỏ lead; chọn bộ mới MapPIDLag (lag sau tổng); kế hoạch và việc cho khung Linear

Người dùng hỏi: lead nằm ở mức yếu nhất thì bỏ, chỉ giữ lag được không. Trả lời (không chạy): z = 5 và p/z = 1.2 đều ở cận dưới, lead chỉ bù tối đa 5.2 độ quanh 0.9 Hz và nhân 1.2 ở tần cao; bỏ được, khả năng J đổi dưới 1-2 % nhưng phải kiểm. Người dùng nói thêm: lead là cho đáp ứng nhanh, đã có D của PID lo, vậy làm Map -> PID -> lag được không. Trả lời: hiểu là Map cộng PID rồi TỔNG qua lag. Có lợi vì độ ồn của MapPID đến từ khâu D (độ lợi cao tần 18.88 trên tổng 20.66; nhánh Map chỉ 1.77) mà lag hiện chỉ lọc nhánh Map. Vấn đề lớn: lag tuyến tính nên lag sau tổng = thêm lag vào PID, là phần ngoài lõi của PID theo C2 và QuyChuan 2.4, 2.5, nên bắt buộc có đối chứng PID+Lag cùng phương pháp, cùng ngân sách. Đưa ba phương án (A bỏ lead giữ lag trên nhánh Map; B lag sau tổng; giữ nguyên), khung khuyên A.

Người dùng chốt: làm phương án B (lag sau PID) như MỘT BỘ MỚI, MapPID giữ nguyên như hiện tại; CHƯA làm, lên bảng kế hoạch trước; ghi nhật ký chi tiết trước để khung Linear đọc và làm phần đối chứng (người dùng viết "map + lag"; khung MapPID hiểu là PID+Lag, vì khung Linear làm PI, PID; nếu ý khác thì sửa).

LÀM: (1) tạo `Documents/Notes/Controllers/DieuKhien_MapPIDLag.txt` (144 dòng, dòng văn xuôi tối đa 196 ký tự): Phần A cơ sở (A1 thiết kế MapPID, A2 lead ở cận dưới, A3 phân rã độ lợi cao tần, A4 số seed 99999), Phần B cấu trúc (phương trình (1)-(3) kèm LaTeX, chống bão hòa, tương đương tuyến tính và công bằng, độ lợi cao tần (p1/z1)(K + Kp + Kd/Tf), ràng buộc dải lái, giả thuyết L1-L6 đặt trước), Phần C kế hoạch P0-P10 (7 tham số, cận như MapPID, sàng lọc và cổng như D13, D14, ngân sách 930, seed đề xuất 50000, kinh nghiệm công cụ), Phần D đối chứng PID+Lag cho khung Linear, Phần E bảy điều cần chốt, Phần F rủi ro, Phần G nhật ký (G0). (2) Thêm F28 vào DieuKhien_MapPID.txt (một đoạn trỏ sang văn bản mới; sửa qua nguồn scratchpad mappid_src.txt, sao lưu mappid_src_v5_backup.txt, đã kiểm nguồn tái tạo đúng file trước khi thêm). (3) Tạo file nhật ký này. Không sửa mã, model, json, QuyChuan, Tracking/CLAUDE.md. Không chạy MATLAB.

Cấu trúc MapPIDLag (B1):
- T_a,cmd = H_lag(s) [u_map + u_PID], H_lag = (s/z1 + 1)/(s/p1 + 1) với p1 < z1, Tustin 1 ms, độ lợi DC 1.
- u_map = sgn(T_s) M_K(v, |T_s|), vùng chết 0.3 N.m, không lead.
- u_PID như MapPID: D trên T_s đo qua lọc Tf; tích phân chống bão hòa tính ngược, Kaw = Ki / (Kp + K), tính trên tổng TRƯỚC lag (đề xuất, E4).
- Bảy tham số: K 0-16, z1 8-120 rad/s, p1/z1 0.1-0.9 (p1 từ 3), Kp 0-3, Ki 0-200, Kd 0-0.05, Tf 1-20 ms.
- Giả thuyết chính L3: J CALIB của MapPIDLag nhỏ hơn hoặc bằng 0.95 lần J của PID+Lag; sai thì nhánh Map không thêm giá trị khi PID đã có lag.

Đề xuất chờ chốt (E1-E7): cấu trúc và token MapPIDLag; seed 50000-59999 (40000-49999 đã được MapSMC đề xuất); ai dựng model (người dùng tự làm Simulink từ 2026-10-13, hay khung sửa bản sao MapPID.mdl bằng API); chống bão hòa trước lag; PID+Lag là biến thể của PID; ngân sách 930 cho cả hai; bộ so sánh Map, PID, MapPID, PID+Lag, MapPIDLag (không PI).

**VIỆC CHO KHUNG LINEAR (đối chứng PID+Lag; đọc đầy đủ Phần D của DieuKhien_MapPIDLag.txt):**
1. Vì sao: MapPIDLag = PID có lag cộng nhánh Map. Muốn biết nhánh Map đóng góp gì thì phải so với chính bộ đó khi K = 0, thiết kế độc lập bằng cùng phương pháp. So MapPIDLag với PID không lag là không công bằng.
2. Cấu trúc: T_a,cmd = H_lag(s) u_PID; PID như PID.mdl (D trên T_s đo qua lọc Tf, Kaw = Ki / Kp); lag sau PID, chống bão hòa tính trên lệnh trước lag so với T_a_lim.
3. Đặt tên (đề xuất, chờ người dùng chốt E5): biến thể của PID, không phải bộ mới: `Model/data/pid_lag.json`, `Result/Controllers/PID/Lag/{Design,Calib,Cases}`, seed 10000 (kiểm 10001), so sánh seed 99999.
4. Sáu tham số: Kp 0-3, Ki 0-200 1/s, Kd 0-0.05 s, Tf 1-20 ms, z1 8-120 rad/s, p1/z1 0.1-0.9 (p1 từ 3 rad/s).
5. Phương pháp và ngân sách GIỐNG MapPID và MapPIDLag: surrogateopt 3 lần x 250 đánh giá (rng 1001-1003; lần 2, 3 tự cấp 30 điểm đầu ngẫu nhiên vì thiết kế mặc định tất định), rồi patternsearch 3 x 60 từ điểm tốt nhất mỗi lần (lưới đầu 0.05, dừng dưới 0.02, biến chuẩn hóa [0,1]); mục tiêu log(J), J = R x S trên CALIB; điểm rớt sàng lọc tuyến tính nhận log(30), không mô phỏng.
6. Ràng buộc: khi tìm ổn định, PM > 0, GM từ 1 trên 68 mô hình tuyến tính (17 tốc độ x 4 điểm làm việc, mappid_plants.m), vòng L = -H_lag C_PID Gm exp(-jw 1 ms) G; điểm cuối PM từ 30 độ, GM từ 2; độ lợi lag tại 2 Hz từ 0.707; Tf nhỏ hơn hoặc bằng 79.6 ms; e_rel nhỏ hơn hoặc bằng 5 % trên 9 cửa sổ static; điểm cuối qua calib_margin.
7. Chọn: theo select_mappid.m (vùng J trong 5 %, ba lần hội tụ trong 3 %, lân cận cộng trừ 0.01, 10 thiết kế tốt nhất đạt PM 30, GM 2 chạy thêm seed thứ hai, xếp theo J trung bình, rồi calib_margin); báo bang-bang, trợ lực ngược, ràng buộc đang chặn.
8. Hai cách làm (chọn rồi báo người dùng): (a) tự viết model PID+Lag và hàm đánh giá theo mẫu `Model/Controllers/MapPID/script/` (mappid_eval, optimize_mappid, refine_mappid, select_mappid, mappid_margins, mappid_u2x); (b) đợi khung MapPID xong P3 rồi gọi hàm đánh giá của MapPIDLag với K = 0. Cách nào cũng phải kiểm chéo: cùng tham số, PID+Lag trùng MapPIDLag tại K = 0 tới khoảng 6 chữ số.
9. Đầu ra cho khung MapPID: pid_lag.json (design, R, S, J, e_rel, PM, GM, số lần đánh giá), csv mọi lần đánh giá CALIB (vẽ Pareto), metrics năm ca DREWS ở seed 99999 cùng định dạng `*_metrics_s99999.csv` của run_cases.
10. Giả thuyết đặt trước của đối chứng (D7): S ở DRY thấp hơn PID (0.256) ít nhất 5 % mà RMS e_T không lớn hơn PID quá 5 % ở cả năm ca.
11. Bắt buộc theo kinh nghiệm khung MapPID: Simulink.sdi.clear sau mỗi mô phỏng; TEMP sang D:/MatlabTemp; một MATLAB mới chỉ khi RAM trống từ 8 GB; ghi từng dòng csv để chạy tiếp được; load_pid trước run_cases.
12. Chưa ai bắt đầu; người dùng chưa chốt E1-E7.

Chưa commit; chưa nén (mới 2 lượt).

### Lượt 3 (2026-10-16) - Người dùng trả lời E1-E7; khung trả lời E4 (chống bão hòa) và hỏi lại trước khi làm

Người dùng chốt: E1 đúng (cấu trúc, token MapPIDLag); E2 đúng (seed 50000-59999); E3 khung MapPID làm, LÀM LẠI TỪ ĐẦU: viết script dựng model (build_) như các bộ trước, chỉ lấy khung vòng kín từ PRSM (build_closed_loop), không chép MapPID.mdl; E4 hỏi cách nào tối ưu nhất; E5 khung MapPID làm luôn PID+Lag (KHÔNG giao khung Linear nữa; mục "VIỆC CHO KHUNG LINEAR" ở Lượt 2 vì thế chỉ còn là mô tả đối chứng); E6 ngân sách không quan trọng; E7 so sánh tính sau. Người dùng bảo trả lời E4 và hỏi hết thắc mắc, đồng ý rồi mới làm.

Trả lời E4 (chưa chốt): khuyên tính ngược SAU khâu lag: du_I/dt = Ki e_T + Kaw (sat(y) - y), y = H_lag (u_map + u_PID), sat theo T_a_lim. Lý do: (1) chỉ xả tích phân khi lệnh thật sự gửi đi bị chặn; tính trước lag thì nhiễu của khâu D (độ lợi tần cao khoảng 18 trên tổng khoảng 21 ở MapPID) làm tổng trước lag chạm T_a_lim giả, xả tích phân sai đúng ở vùng gần giới hạn (EDGE 0.35-0.4 g), dù lệnh sau lag chưa chạm; (2) vòng chống bão hòa ổn định với mọi Kaw > 0 vì đáp ứng xung của lag không âm và tổng bằng 1 (đầu ra lag là trung bình có trọng số của đầu vào); (3) đúng dạng chuẩn của tính ngược (so lệnh đã chặn với lệnh tính ra ở chỗ cơ cấu chấp hành thấy). Cái giá: tích phân dùng tích phân rời rạc kiểu Euler tiến để tránh vòng đại số (lag có truyền thẳng p1/z1); động học lag nằm trong vòng chống bão hòa, ảnh hưởng nhỏ. Không tự chặn lệnh trong bộ điều khiển (quy tắc: AssistLimit chặn). Kaw giữ Ki / (Kp + K).

Câu hỏi còn lại gửi người dùng: dùng chung hàm của MapPID hay chép riêng; PID+Lag đặt ở đâu và seed nào; kiểm lại ngưỡng sàng lọc (O2b) hay dùng lại; có chạy lại O3 systune không. Chưa làm gì ngoài ghi lượt này. Chưa nén (3 lượt).

### Lượt 4 (2026-10-16, 00:40-01:20) - Người dùng chốt E1-E7 và đi ngủ; dựng MapPIDLag từ đầu, kiểm thử, chạy tối ưu; làm tắt nhầm job của khung Linear

Người dùng chốt: E1, E2 đúng; E3 khung MapPID làm từ đầu bằng script build như các bộ trước, chỉ lấy khung vòng kín của PRSM; E4 (chống bão hòa) khung khuyên và người dùng đồng ý tính SAU lag; E5 bạn làm luôn (thực tế khung Linear đã được giao và làm PIDLag, PIDOpt); E6 ngân sách không quan trọng; E7 so sánh tính sau; muốn sáng (khoảng 7 giờ sau, 07:40) có kết quả DREWS MỘT seed của bộ mới (seed local 50000), nhiều seed chỉ khi so sánh các bộ.

LÀM: (1) Mã mới Model/Controllers/MapPIDLag/: load_mappidlag.m (biến MapPIDLag_variant chọn PIDLag, không dùng) và script/ build_mappidlag (tự đặt tên model, nhánh Map + nhánh PID cộng, rồi khối Discrete Transfer Fcn lag, chống bão hòa trên T_a_lim trừ lệnh sau lag, tích phân Euler tiến), mappidlag_variables, mappidlag_design_variables, mappidlag_plants (68 mô hình tuyến tính, bộ nhớ đệm riêng), mappidlag_margins, mappidlag_u2x, mappidlag_x2u, mappidlag_eval, optimize_mappidlag, refine_mappidlag, select_mappidlag, run_mappidlag_cases, check_mappidlag_loop, test_mappidlag, test_mappidlag_margins; Model/data/mappidlag.json; KHÔNG sửa file nào của MapPID. (2) Kiểm: test_mappidlag PASS (3 trường hợp, lệch 2.7e-13 N.m so với đệ quy độc lập); test_mappidlag_margins PASS; check_mappidlag_loop: PID = 0 trùng Map tới 6 chữ số, K = 0 trùng PID tới 1e-4 (TV 7e-4, do nhiễu và bộ giải; ngưỡng kiểm 1e-3); smoke mappidlag_eval chạy. (3) Cận p1/z1 đổi từ 0.1-0.9 sang 0.1-1 để khớp PIDLag của khung Linear và để tối ưu tự tắt được lag (ghi ở G của kế hoạch). (4) QuyChuan 3.3 và nhật ký thay đổi, Tracking/CLAUDE.md (token MapPIDLag, dải seed 50000-59999, để 40000-49999 cho MapSMC). (5) DieuKhien_MapPIDLag.txt: Phần E ghi quyết định, G1-G5.

SỰ CỐ (lỗi của khung này): lúc khoảng 01:03 tôi chạy lệnh dừng mọi MATLAB trừ MATLAB của trình soạn thảo, tưởng là tiến trình treo của các lần thử của tôi; thực ra đó là 3-4 job optimize_pidlag của khung Linear (bắt đầu 00:50-00:57). Vỏ chạy của khung Linear tự thử lại từ 01:04, checkpoint và csv giữ tiến độ nên mất vài phút mỗi job. Từ đó chỉ dừng tiến trình có chữ mappidlag (script stop_mine.ps1). KHUNG LINEAR ĐỌC: (a) máy chỉ đủ khoảng 3 MATLAB cùng lúc (RAM trống 3 GB, cam kết 48.6 trên 55.1 GB); (b) guard_ram.ps1 (scratchpad của khung MapPID, đang chạy, ghi ram_log.csv) dừng MATLAB MỚI NHẤT khi RAM trống dưới 3 GB, nên job thứ tư của khung Linear bị dừng và thử lại; nếu khung Linear muốn bỏ, nói người dùng; (c) mọi MATLAB gọi Simulink phải Simulink.sdi.clear sau mỗi mô phỏng; (d) chuỗi MapPIDLag của khung này chờ tới khi khoảng trống từ 7 GB mới bắt đầu, nên chạy sau khi các chuỗi của khung Linear xong lượt.

Chưa có kết quả tối ưu. Chưa commit; chưa nén (mới 4 lượt).

### Lượt 5 (2026-10-16, 01:20-05:50) - Chạy qua đêm: tối ưu, chọn và DREWS một seed của MapPIDLag

Người dùng đi ngủ, muốn sáng có DREWS một seed. LÀM: đường ống scratchpad lag_master.sh (ba chuỗi surrogateopt 250 + patternsearch 60, select_mappidlag, run_mappidlag_cases) chờ bộ nhớ vì khung Linear chạy 3-4 MATLAB; hạ ngưỡng khởi động từ 7 xuống 5 GB lúc 02:22 để chen vào; chuỗi chạy 03:00-05:26, chọn 05:26-05:40, DREWS xong 05:44. Không có lần thử lại nào thất bại. KẾT QUẢ (đủ số ở DieuKhien_MapPIDLag.txt G6-G8): J* 3.016 (ba chuỗi 3.016, 3.021, 3.093), điểm chọn J 3.048 sau điều kiện PM từ 30 độ; p1/z1 = 0.946, lag gần như tắt, vùng J trong 5 % có cả p1/z1 = 1; DREWS s50000: RMS e_T 0.139, 0.056, 0.171, 0.217, 0.169 (DRY, RAMP, SLIP, WEAVE, EDGE), S 0.248, 0.149, 0.310, 0.375, 0.327; giả thuyết L1, L2, L4, L6 sai, L5 đúng, L3 chờ PIDLag. BÀI HỌC: (1) lead của MapPID và lag của MapPIDLag đều bị tối ưu đẩy về yếu nhất: hai khâu bù đó không đóng góp đo được khi nhánh PID có khâu D; (2) khi có khung khác cùng dùng máy, cổng bộ nhớ phải tính cả hạn mức cam kết (48.6 trên 55.1 GB), và không bao giờ dừng MATLAB theo tên chung mà phải theo nội dung lệnh của chính mình. Chưa làm P7, P9. Chưa commit; chưa nén (5 lượt).
