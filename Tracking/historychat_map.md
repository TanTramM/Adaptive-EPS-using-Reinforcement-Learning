# History_Chat (khung Map) - Lịch sử trò chuyện dự án Adaptive C-EPS bằng RL

### Lượt 454 (2026-10-21) - Map2 Dense runner, checkpoint và phục hồi

Theo KeHoach_Map2_Dense, đã tạo manifest Map2_Dense_v1 gồm 306 cặp Map2 và baseline legacy tại `Result/Controllers/Map/Calib_v2/TwoParamDense/`; giữ nguyên Map5/map.json/MapPID/DREWS. Preflight K=5, g=0.707106781187 đã tổng hợp hợp lệ và chạy đủ nominal seed0, nominal/gainx2/delay+1ms seed1; checkpoint ghi R0=23.6990 %, e_rel0=71.7933 %, ratio gain=0.91044, ratio delay=1.00098 (trượt e_rel, không bị giả định là crash). Tạo `run_map2_dense.m`, `finalize_map2_dense.m`, `tools/jobs/start_map2_dense.ps1`: worker ghi CSV riêng sau từng cặp hoàn chỉnh, retry đúng worker tối đa hai lần, theo dõi RAM/heartbeat và chỉ merge/chọn sau khi mọi worker DONE. Lỗi launcher đầu tiên do `Start-Process` tách biểu thức `-batch` chứa khoảng trắng khiến MATLAB thoát trước log/checkpoint; đã dừng riêng supervisor sở hữu các process đó, sửa quote `-batch`, khởi động lại và xác minh 5 MATLAB có CPU tăng liên tục, RAM trống khoảng 30--32 %. Không có task nào bị ghi rejection do lỗi launcher. Tự shutdown máy đã bị môi trường chặn vì rủi ro mất công việc ngoài phạm vi; không dùng workaround. Chưa có báo cáo cuối và chưa thay cổng.

**BÀN GIAO MỚI 2026-10-21:** Người dùng giao khung Map thực hiện
[KeHoach_Map2_Dense.md](../Documents/Notes/Controllers/KeHoach_Map2_Dense.md).
Đọc toàn bộ kế hoạch khi nhận prompt để triển khai Map2 phủ rộng, đánh giá sáu
ràng buộc và vận hành RAM80–90%. Chưa launch ở lượt lập kế hoạch; ghi chú tiếp
nhận nằm gần cuối file. Chỉ dẫn Map5/watchdog cũ không tự mở lại cho đợt này.

## CÁCH DÙNG (dành cho phiên Claude mới)

1. Đọc file này TRƯỚC KHI làm bất cứ việc gì, sau đó đọc `Tracking/CLAUDE.md` (quy tắc làm việc) và `Documents/Shared/QuyChuan.txt` (quy chuẩn thiết kế và đánh giá chung, bản 3 ngày 2026-10-10).
2. Cấu trúc file: (a) TRẠNG THÁI HIỆN TẠI (tổng hợp để tiếp tục việc); (b) BẢN NÉN các lượt cũ theo giai đoạn (đã cô đọng, giữ quyết định, con số, bài học, lỗi đã gặp); (c) NHẬT KÝ NGUYÊN VĂN của 5 lượt gần nhất. Bản đầy đủ trước khi nén (349 mục, 530 KB) nằm ở `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-10_historychat_map/historychat_map.md` và trong git (commit 389508f). Bản trước lần nén thứ hai: .../historychat_map_truoc_nen2.md, trước lần thứ ba: .../historychat_map_truoc_nen3.md, trước lần thứ tư: .../historychat_map_truoc_nen4.md, trước lần thứ năm: Desktop/Adaptive-EPS_backup_2026-10-13_historychat_map/historychat_map_truoc_nen5.md (cùng thư mục).
3. QUY TẮC CẬP NHẬT: sau MỖI lượt hỏi-đáp, thêm 1 mục "Lượt N" vào cuối file (và sửa TRẠNG THÁI HIỆN TẠI nếu có thay đổi). QUY TẮC NÉN (người dùng chốt 2026-10-10, ghi ở Tracking/CLAUDE.md): khi số lượt mới kể từ lần nén cuối đạt 10, nén ngay sau khi ghi lượt đó (sao lưu trước, giữ nguyên văn 5 lượt cuối, gộp phần còn lại vào BẢN NÉN, cập nhật dòng "Nén lần cuối").
4. Ngôn ngữ giao tiếp và tài liệu: tiếng Việt; code `.m` (tên hàm, biến, comment): tiếng Anh. Mọi từ viết tắt phải giải thích ngay lần đầu. Câu trả lời tự chứa, có số cụ thể, không viện dẫn "làm ở lượt N"; chỉ làm khi người dùng bảo (câu hỏi, đề xuất, đồng ý không phải lệnh); không commit/push nếu không được yêu cầu; phạm vi gọn.

---

## TRẠNG THÁI HIỆN TẠI (cập nhật sau Lượt 446, 2026-10-20)

**Bàn giao tự động qua đêm:** Map grid đã xong, selector vẫn kiểm `calib_margin` (khoảng J-rank 108 lúc 00:58), chưa có pick/JSON mới. `tools/jobs/publish_map_when_ready.ps1` chờ pipeline DONE và xác minh pick/JSON/Pareto/năm seed rồi tự push nhánh `automation/map-s2-ready`; trạng thái ở `scratch/jobs/map_handoff_desktop/`. Laptop đang chạy S1; cần khung laptop nhận commit cơ chế trên main và khởi chạy `continue_mappid_overnight.ps1` ngay để tự chờ S1 → fetch bộ Map đã xác minh → S2 → Select. Không có kết nối điều khiển laptop từ desktop. Hướng dẫn và lệnh launch ở `tools/jobs/MAPPID_LAPTOP.md`. DREWS cũ bỏ qua. Không thể hứa chắc hạn buổi sáng khi chưa có Map qua cổng.

**Vai:** khung Map (chat 1 trong 3 khung song song: Map, Linear = PI/PID, SMC). Chỉ ghi file này; đọc 1 lượt mới nhất của historychat_linear.md và historychat_smc.md mỗi lần làm việc để rút kinh nghiệm (chỉ ghi vào file của mình).

**Đề tài:** luận văn thạc sĩ HCMUT (HV Trần Minh Tân, GVHD TS. Phùng Thanh Huy): điều khiển trợ lực lái điện thích ứng (Adaptive C-EPS) khắc phục over-assist (trợ lực thừa khi hệ số bám mu giảm), cuối cùng dùng RL (nay: SMC và ISMC thay RL trong luận văn). Báo cáo thầy mỗi thứ 7 10h.

**Map hiện tại (lead-lag, một K, một khâu bù chung; bỏ 2K):** T_a,map = sgn(T_s) x M(v, |T_s|), vùng chết Ts0 = 0.3 N.m, độ dốc chặn K_max = 6; khâu bù lead (z 33.50, p 600.11 rad/s) nhân lag (z1 28.13, p1 10.69 rad/s), Tustin 1 ms thành MỘT khối bậc hai độ lợi DC 1 (Map_H_num, Map_H_den; khối Disc_H). Đọc T_s và v. Số cũ (K 6.75, lead 59.82/1665.96, K_stab 9.5) thuộc Map lead đơn cũ, không còn dùng.

**Tên mới theo QuyChuan bản 3 (2026-10-10, người dùng chốt):** ca TK -> CALIB (ca thiết kế chung 117 s, 19 cửa sổ); TC1-TC6 -> ba ca chấm DRY (mu 0.8, 129 s), SLIP (mu đổi khi cua: pud, up, down; 63 s), WEAVE (lái liên tục: slal, lane, ice; 61 s); tk_* -> calib_*, test_cases -> make_cases, run_test_cases -> run_cases, TK_* trong json -> CALIB_*; kết quả `Result/Controllers/<Ctrl>/{Design,Calib,Cases}`. Các mục lịch sử (nén và nguyên văn) giữ tên cũ TK, TC1-TC6 khi nói về thời điểm đó. "calibration" trong map.json là điểm đặc tính tĩnh đường khô, KHÁC ca CALIB.

**MAP LEAD-LAG (2026-10-11 và 2026-10-12): Bước 0-6 XONG với quy tắc chốt (J = R x S cộng ràng buộc dải lái); còn so sánh seed 99999 chờ khung PI, PID, SMC.**
1. QUY CHUẨN HIỆN HÀNH (v5, người dùng chốt phương án A ngày 2026-10-11): cổng chỉ còn ổn định có độ dư (calib_margin: ổn định và tỉ số R <= 2 khi độ lợi x2 hoặc trễ +1 ms; tiêu chí 'không số' đã bị người dùng trả về cổng cũ, Linear Lượt 153; map.txt, LyThuyet_Map, README còn câu 'không số' cần sửa) rồi e_rel <= 5 % (9 cửa sổ static); bang-bang và trợ lực ngược CHỈ BÁO CÁO; chọn cực tiểu J = R x S (common/pick_by_balance.m, a = 1; độ nhạy a 0.5, 2 và quy tắc 5 % cũ) CỘNG ràng buộc dải lái (QuyChuan 6.2): khâu lọc hoặc làm chậm giữ độ lợi >= 0.707 (-3 dB) tại 2 Hz (Map: khâu lag; PID: Tf; SMC: lớp biên). PM >= 45 chỉ là công cụ thiết kế. Đã ghi QuyChuan 6.2, 9.5, nhật ký thay đổi, Tracking/CLAUDE.md, DieuKhien_Map A6 và B11.
2. ĐIỂM CHỌN HIỆN HÀNH (map.json, Cases/ và select_map.m khớp): g_min 0.7, K 6: lead (33.50, 600.11), lag (28.13, 10.69) rad/s; CALIB: R 27.05 %, S 0.2492, TV 92.5, J 6.743, e_rel 3.17 %, rev 0.21 %, bang-bang delta 0.000 (hai seed), qua calib_margin. Bốn ca (RMS e_T N.m, S, TV): DRY 0.689, 0.150, 78; SLIP 0.538, 0.161, 95; WEAVE 1.327, 0.160, 47; EDGE 1.535, 0.129, 22; vũng nước -86.8 %; EDGE 0.4 g 99.7 / 56.8 / 52.5 %. Đối chứng lead đơn K 6 (R 25.85 %, S 0.4098, J 10.6). Điểm J thuần (g_min 0.25, K 5.8) và điểm quy tắc 5 % (g_min 0.7, K 8.5; bản K 8 sao lưu Desktop/.../Cases_0p7_K8, map_0p7_K8.json) chỉ báo cáo độ nhạy.
3. PHÁT HIỆN: J = R x S không có cực tiểu bên trong với Map (J giảm đơn điệu theo g_min tới cận lag p1 >= 3 rad/s) nên cần ràng buộc dải lái; cửa sổ static của CALIB chỉ ở 20, 60, 100 km/h nên cổng e_rel không thấy DRY v40a0p3r +13.0 % của K 6 (K 8: +0.5 %): đã báo khung COMMON trong nhật ký thay đổi QuyChuan.
4. BƯỚC 6 ĐÃ LÀM (Lượt 414, 2026-10-12): map.json (x_design_note), map.txt và map.docx qua tools/build_map_txt.py (viết lại, sinh thêm Map_bode.png, Map_CALIB_pick_s00000.png, Map_CALIB_pareto_s00000.png), LyThuyet_Map.txt (Phần 2, 5-9 viết lại; 3.4, 4.3, 4.6 sửa; Phần 10 cập nhật), hai docx dàn ý qua tools/build_outline_docx.py (bỏ bảng và hình so sánh cũ), DieuKhien_Map.txt (B12), Tracking/CLAUDE.md (hai câu về map.txt và build_map_txt.py). Đã xóa (sao lưu Desktop/Adaptive-EPS_backup_2026-10-12_Map_lam_lai_tai_lieu) 10 script lead đơn: design_map, run_step5, test_step3, test_step5, sweep_stability, map_bangbang_scan, plot_step5, plot_step3, design_lead, knee_point; và kết quả cũ Map_step3_*, Map_stability_lead_sweep.csv, Map_design_compare.png, Calib/Map_CALIB_metrics_s00000.png. map_k_accuracy.m nay ghi Map_K_for_accuracy_<tol>pct.csv (file cũ Map_K_for_accuracy.csv bị khóa, không xóa được). test_map, test_step2, test_leadlag_design PASS.
5. CÒN TREO: (a) so sánh seed 99999 với PI, PID, SMC, ISMC (Result/Compare/Map_vs_* là của Map cũ; dàn ý docx đã bỏ chúng); (b) khung PI, PID, SMC, ISMC kiểm ràng buộc dải lái trên điểm đã chọn (QuyChuan 9.5); (c) COMMON: người dùng đã bác thêm cửa sổ static 40 km/h vào CALIB (2026-10-11), ca RAMP được thêm làm ca báo cáo; Map RAMP đã chạy (Lượt 412). Chưa commit.
6. LƯU Ý: lệnh rm hàng loạt kèm cd bị kiểm tra an toàn chặn: xóa từng nhóm file bằng đường dẫn tuyệt đối. Chạy MATLAB nền rồi đọc file kết quả; `run()` trên file hàm không đối số vẫn chạy được.
7. GÓI GỬI THẦY (Lượt 415-418): Documents/Paper/resource/ chỉ để chạy ca thử và sinh hình: Model/ (Map.mdl, Model_Map.mdl, load_map.m, 11 script, PRSM, Sim, common, data), README.md (setup_paths, load_map, test_map, run_cases('Map', 0), bảng số đối chiếu), reference_results/ (Map_metrics_s00000.csv và năm hình resp). reproduce_map.m (6 giai đoạn) vẫn nằm trong repo, không trong gói.
8. MAPOPT (Phần M của DieuKhien_MapOpt.txt; Lượt 421-425): lần chạy 2 (PM >= 30 và GM >= 2 áp ngay lúc tìm, điểm đầu từ lần 1) XONG 2026-10-17 07:55 bằng tools/jobs/mapopt_run2.sh (job_lib_patient.sh: chờ bộ nhớ, tự chạy lại khi bị guard_ram dừng). Điểm chọn (CALIB v1): K 6.06, lead z 38.71 p 385.2, lag z1 46.16 p1 11.74, PM 30.1, J trung bình seed 1-5 5.630 (Map cũ 6.743, lần 1 6.294); DREWS seed 0 bám ngang Map cũ, S thấp hơn 35-50 %, TV thấp hơn 60-65 %. Chi tiết: DieuKhien_MapOpt.txt Phần N3. Chưa đạt M5(c): J tốt nhất ba chuỗi 5.86, 5.64, 7.13. KẾT QUẢ NÀY LÀ CỦA CALIB v1 (xem mục 9).
9. CALIB v2 (khung TESTCASE, Lượt 10, 2026-10-18; QuyChuan phiên bản 6; CHƯA CHẠY LẠI MAP/MAPOPT): CALIB 140 s, chín khối tốc độ 20-100 km/h bước 10, 68 cửa sổ (26 static, 26 trans, 14 sine từ 40 km/h, 2 mu); R = trung bình nhân ba nhóm (static, dyn, mu) với sàn 1 %; cổng e_rel <= 5 % trên 26 cửa sổ static; không còn nhóm small và ext. result_dir(ctrl, 'Calib') nay là Result/Controllers/<Ctrl>/Calib_v2; thư mục Calib trên đĩa giữ CALIB v1, gọi bằng 'CalibV1'. HỆ QUẢ cho Map: (a) Result/Controllers/MapOpt/Calib (lần 2, v1) và Calib_run1 (lần 1, v1), mapopt.json design và design_run1, Cases và Cases_run1, Result/Controllers/Map/Calib, map.json design: TẤT CẢ là v1, không so được với v2; (b) khung TESTCASE đo: cổng e_rel 5 % trên v2 cần K khoảng 12 trở lên (Map thiết kế K 6 không còn qua cổng), nên phải thiết kế lại lead và lag để giữ PM >= 30, hộp K của MapOpt (0.1-16) vẫn chứa K 12; (c) mã Map đã bỏ nhóm small, ext khỏi run_calib_sweep; reproduce_map.m dùng 'CalibV1'; (d) select_mapopt, test_mapopt_run2, mapopt_run1_points tính Calib_run1 từ fileparts(result_dir('MapOpt', 'Calib')) nên vẫn đúng thư mục Controllers/MapOpt/Calib_run1 nhưng đó là dữ liệu v1; chạy MapOpt trên v2 phải coi là chạy MỚI (Calib_v2 rỗng), không dùng điểm đầu v1 mà chưa kiểm; (e) tài liệu Map còn mô tả CALIB v1 và 9 cửa sổ static: Documents/Thesis/map.txt và map.docx, tools/build_map_txt.py (TESTCASE đã ghi), LyThuyet_Map.txt, Documents/Paper/resource/README.md, DieuKhien_Map.txt; (f) lệch so với kế hoạch cần người dùng xác nhận (TESTCASE): sin chỉ từ 40 km/h, bậc mu ở 0.3 g, lắng 3 s mỗi mức (Map ở 30-50 km/h chưa lắng hết).
10. VIỆC TREO (không làm khi chưa được bảo): chạy lại MapOpt trên CALIB v2 (tối ưu đồng thời, ba chuỗi, chọn trên seed 1-5, DREWS), thêm 150 lần mỗi chuỗi nếu ba chuỗi chưa hội tụ, DREWS năm seed 99999-99995, so với PIDOpt và MapPIDOpt, viết lại chương Map theo MapOpt.
11. MAP TỪ ĐÂY LÀ BẢN DUY NHẤT, không dùng tên MapOpt. Kế hoạch hiện hành ở `PhuongPhap_TimThamSo.txt` mục 13 đã đổi ngày 2026-10-19: bỏ `surrogateopt` và `patternsearch`, tìm lại bằng quét lưới tất định đủ 5 biến trên CALIB v2 với `e_max = 10 %`, lọc Pareto rồi chọn cực tiểu J (hòa 3 % lấy PM lớn nhất), kiểm năm seed chỉ để báo cáo và chấm DREWS seed 99995--99999. Map và PID độc lập về thiết kế nên được chạy song song sau khi công cụ chung xuất hiện, với tổng tối đa ba MATLAB; chỉ MapPID phải chờ cả hai bộ đã chọn. Lần `surrogateopt` e_max 10 % đã bị COMMON dừng an toàn; csv/checkpoint còn giữ nhưng không được dùng làm kết quả mới.
12. Hạ tầng chung đã có và Map đã có wrapper: `map_grid_spec.m`, `run_map_grid.m`, `select_map_pareto.m`, `tools/jobs/map_grid_pipeline.sh`. PID đang chiếm cả ba MATLAB cho lưới thô (Lượt 166 Linear), vì vậy Map chưa khởi động để không vượt giới hạn RAM; khi có slot sẽ sao lưu/dọn kết quả surrogateopt theo 13.2 rồi chạy pipeline Map.
13. PID đã xong 561 điểm lưới nhưng dừng ở chọn vì `calib_margin` báo `Motor_lag/Numerator` không hợp lệ; lỗi này thuộc khung Linear. Map đã sao lưu rồi dọn 3 CSV và 3 checkpoint surrogateopt ra Desktop/Adaptive-EPS_backup_2026-10-19_Map_surrogateopt, qua kiểm `map_opt_eval` với PM 45.292 và bắt đầu lưới thô 1024 điểm lúc 09:46 ngày 2026-10-19. Worker 1 chạy trước, worker 2/3 lệch 150 s; theo dõi `scratch/jobs/map_grid_*_status.txt`.
14. Lúc 10:42, Map đang ở lưới thô: 595/1024 thiết kế khác nhau đã được đánh giá, 29 thiết kế qua sàng tuyến tính nên đã mô phỏng CALIB, 8 thiết kế qua đủ c1-c4. Worker 1 và 2 đang chạy; worker 3 chờ RAM (khoảng trống 3 GB, cần 6 GB). Cảnh báo algebraic loop khi Delay_ctrl bằng 0 là cảnh báo Simulink cũ, không phải lỗi dừng.
15. Lúc 11:14, Map có 1021/1024 thiết kế thô, 60 mô phỏng CALIB và 14 điểm qua c1-c4. Worker 2 bị dừng vì thiếu RAM và sẽ tự thử lại sau 600 s; worker 3 đang chạy ba điểm còn thiếu. Chưa lưới mịn/Pareto/chọn.

**Số liệu so sánh seed 99999:** CHƯA có cho Map lead-lag. Các bảng cũ (Map lead đơn: RMS e_T TC1 0.644 ... TV 325...) đã bỏ khỏi dàn ý; chạy `run_cases('Map', 99999)` và `make_pair_comparisons` khi PI, PID, SMC chốt điểm.

**Tài liệu đã sinh lại (2026-10-12):** `Documents/Thesis/map.txt`, `map.docx`, `dan_y_luan_van.docx`, `dan_y_bai_bao.docx`, `Documents/Notes/Controllers/LyThuyet_Map.txt`, `DieuKhien_Map.txt` (B12).

**Seed:** Map local 00000-09999 (dùng 00000), PI/PID 10000, SMC 20000, seed chung chấm khi so nhiều bộ 99999; chạy ca của MỘT bộ riêng lẻ dùng seed local, chỉ so sánh nhiều bộ mới dùng 99999 (rồi xóa các file *_s99999.* sinh ra trong Cases của từng bộ).

**Quy tắc người dùng đã đặt (tóm tắt, đầy đủ ở Tracking/CLAUDE.md và QuyChuan.txt):** code `.m` tiếng Anh, tài liệu tiếng Việt; không hậu tố `_s`/`_old`; `build_*` dạng `build_x(overwrite)`; test dò cổng theo tên, đáp án tính độc lập; `.txt` trong Documents dòng văn xuôi 180-200 ký tự; mỗi công thức có dòng LaTeX; giải thích viết tắt lần đầu; không tự mở rộng phạm vi; không sửa Thesis.docx trừ khi được bảo; sao lưu ra Desktop trước khi xóa hay đổi tên hàng loạt (Model/Controllers và Result/Controllers từng chưa vào git; nay tracking đã có trong git); sao chép trích dẫn phải đối chiếu PDF gốc.

**Công cụ:** MATLAB R2023a: `"/c/Program Files/MATLAB/R2023a/bin/matlab" -softwareopengl -batch "run('<ĐƯỜNG DẪN TUYỆT ĐỐI>\Model\setup_paths.m'); ..."`, đường dẫn tuyệt đối, nạp load_<ctrl> trước khi chạy; lỗi heap corruption khi thoát MATLAB vô hại nếu dữ liệu đã ghi. Python: `C:/Users/Admin/anaconda3/python.exe -I -X utf8` (python -I bỏ qua PYTHONIOENCODING nên cần -X utf8); python-docx 1.2.0; ghi file bằng công cụ Write, KHÔNG dùng heredoc cho chuỗi có `\n`, gạch ngược, ngoặc; đo độ rộng dòng bằng ký tự, không bằng byte; nhật ký lớn đọc bằng grep tiêu đề rồi Read với offset/limit; không có pdftoppm, dùng PyMuPDF (anaconda) để trích PDF.

---

## BẢN NÉN CÁC LƯỢT CŨ (Lượt 1-415)

Nén lần cuối: Lượt 431 (2026-10-19). Lượt 427-431 nằm nguyên văn ở cuối file. Mọi chi tiết cũ hơn: xem các bản sao lưu ở mục CÁCH DÙNG.

### Giai đoạn 1 - Dựng PRSM (Plant, Ref, Sensors, Actuator) và tài liệu (Lượt 1-60, 88-111, 125-133)

- Đề tài khung bài toán (Seborg): MV = T_a, CV = T_s = K(theta1 - theta2), DV đo: theta1, v; DV không đo: mu; T_d (mô-men tay) KHÔNG phải đầu vào, chỉ là kết quả tính ra; sai số e_T = T_s - T_d,ref(v, a_y) tra bảng 4 của [7] (5 tốc độ 20-100 km/h x a_y 0.1-0.4 g). Tài xế động học: góc lái theta1 là ĐẦU VÀO của Plant (như Multi-Map [6], Lee [1] mục IV.A); đã kiểm chứng nếu T_d là đầu vào thì ở xác lập T_s = T_d và T_a không đổi được CV. Phạm vi chỉ over-assist, không xét độ êm ở thời điểm đó. Bộ điều khiển chỉ được đọc T_s, theta1, theta2, theta2_dot, v, gamma, a_y; KHÔNG đọc mu, beta, T_d.
- Plant (4 trạng thái theta2, theta2_dot, beta, gamma; đầu vào theta1, T_a, v, mu): Cụm 1 thanh xoắn K = 143.24 + cột lái J_col = 0.11, C_col = 1.35, ma sát khô T_f = 2 N.m (tanh(c theta2_dot), c = 100); Cụm 2 lốp Pacejka Magic Formula (D = mu F_zf, B = C_alpha/(C D)), T_r = K_tr F_yf; Cụm 3 xe đạp 2 bậc tự do. Nguồn tham số: Lee [1] Table III (xác nhận T_f = 2 qua ảnh chụp), Rajamani [5] (m 1573, Iz 2873, l_f 1.1, l_r 1.58), Pacejka [3], Multi-Map [6], Road Identification [7], Ren-Deng [8]. Kỹ thuật bắt buộc: `MaxStep = 0.01` với tanh(c x) dốc; Goto/From local. Đã sửa: nhãn C1/C2 là damping không phải ma sát nhớt; T_a,max không lấy từ Bảng 5 [7]; bỏ F_zf, F_zr khỏi Params.xlsx (biến tính); đổi J1/C1 -> J_sw/C_sw, J2/C2 -> J_col/C_col; áp C_alpha = 160000 sau khi phát hiện hiểu sai cấp (Lượt 94); lốp sau cũng Magic Formula; bỏ xấp xỉ góc nhỏ ở lý thuyết rồi quay lại giả thiết góc nhỏ (theo sách) và tính giới hạn a_y theo v, mu bằng tiêu chí e_p = 0; thêm caster (tách theo phản biện, PhanBien.txt, Lượt 126-128).
- Tài liệu: Documents/Thesis/plant.txt (+docx, định dạng mỗi đoạn một dòng, phương trình `(n) ascii` + `[ latex ]`), ref.txt (giá trị đặt T_d,ref và T_a,max, Bảng 2 theo bước v/mu mịn), TestCases.txt; tools/txt2docx.py; Documents/Shared/{QuyChuan.txt, Blueprint_OverAssist_RL.txt, References.txt, PhanBien.txt}; Documents/Notes/PRSM/{Cum1_CEPS, Cum2_Pacejka, Cum3_2DOF, HeThongPlant_TongHop, ThucTeHoa}; Documents/Data/*.xlsx. Cấu trúc thư mục soi gương Model/ và Result/ (Lượt 98, 246-247, 133).
- Cảm biến (Lượt 153-164): chỉ 2 chế độ (lý tưởng; có nhiễu + lượng tử + chu kỳ cập nhật riêng; KHÔNG còn mức low/high); khối Sensors v2 với Quantizer; Reference chấm điểm; seed nhiễu `sensor_noise_vars(seed)`. Chu kỳ chung 1 ms (Lượt 140, 148-151): Map không chạy được ở 10 ms vì không đủ dự trữ pha cho cột lái cộng hưởng ~6 Hz; ZN không dùng được ở 1 ms nên dùng pidtune (Lượt 146-152).
- T_a,max: ban đầu ước lượng từ Plant (Lượt 44-46, 69-74: biên a_y theo (v, mu) bằng e_p = 0), đưa về Ref (Lượt 133); làm lại ở Lượt 334 theo quy tắc T_a,max = T_a,req + F với F = T_f (Slotine-Li 7.1.3 và 7.5; Nguyen et al. pt 14); giới hạn nằm ở khối AssistLimit, chặn và trễ motor (100 Hz) ở Actuator; bộ điều khiển KHÔNG tự chặn, chỉ khai báo cổng T_a_max nếu cần.
- Đã dựng và bỏ: PID thuần bằng ZN (Lượt 43), SMC (Lượt 36-40, 64-66, 80-84; SMC-sat không tích phân và SMC_KI có tích phân, chuyển sang khung SMC), Map baseline cũ (Lượt 60-62, 111-124: kịch bản TC1-TC6 dựng cho Map, K_max 18 rồi 6/8 hai bậc).

### Giai đoạn 2 - RL (Lượt 134-224) rồi tạm dừng

- Quyết định: RL thuần không lai Map (Lượt 139); chu kỳ 1 ms; quan sát có lịch sử mẫu D = 5 ms, n_hist = 5 (Lượt 171-173); xây bậc 1 (Lượt 175-176), Train1 chạy qua đêm (180-181), Train2 với tích phân rò (182-193), thang thí nghiệm bậc 1b với train_mu, chạy song song nhiều seed và biến thể gamma 0.99 (196-211), cách C (hành động gia số) không học được, actor kẹt +0.2 (216-220). Người dùng nhắc nhiều lần: CHƯA chốt gì mà Claude đã chạy mô phỏng RL (Lượt 166-169) nên xóa toàn bộ code, model RL và làm lại từ đầu; quy tắc "chỉ làm khi được bảo".
- Bài học kỹ thuật: RL gặp sai số tĩnh cấu trúc vì không có tích phân (Lượt 212-215); câu hỏi "RL có thắng PID ở khắc phục trợ lực thừa không" (222); thu hẹp phạm vi chỉ Plant, Ref, Map, RL (199). Cuối cùng RL bị dừng (Lượt 145 tạm dừng, 221 nhìn lại, 224) và kế hoạch đề tài chuyển sang SMC và ISMC thay RL (người dùng, khung SMC); mọi bộ điều khiển (Map, PI, PI_2K, PID, SMC, RL) và kết quả bị xóa ngày 2026-10-07 (Lượt 245), sao lưu ở C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-07.

### Giai đoạn 3 - PI/PID, quy chuẩn so sánh và seed (Lượt 225-300)

- Phân vai khung (Lượt 227-230): khung Map giữ Map, khung kia làm PI/PID (nay Linear), khung SMC làm SMC; Map từng chốt hai bậc K_max 8 (đến 60 km/h) / 6 (từ 65 km/h) + một lead mỗi bậc rồi trở về một bậc. Cộng hưởng cột lái khoảng 6.2 Hz (omega_n 39.7 rad/s, zeta 0.155, đỉnh |G| 2.70 = 8.6 dB tại 38.7 rad/s, G(0) = 0.827) chặn Kp của PI qua GM >= 2 (Lượt 250-255; đã đính chính công thức Kp_max sai ở Lượt 250); băng thông ~ omega_c = Ki x G(0) (Ki trần ~8); PI_2K suy biến thành PI (kết quả âm, B1: cộng hưởng không phụ thuộc v); PID có thêm D trên T_s đo với lọc bậc 1 Tf (Lượt 264-271).
- QUY TẮC CHỌN THAM SỐ (Lượt 262-282, người dùng chốt 2026-10-08): chỉ tiêu R (độ bám) và S (RMS T_a sau lọc cao qua 5 Hz = độ ồn) trên ca thiết kế; cổng cứng đặt trước (ổn định, PM >= 45, GM >= 2, e_rel <= 3 %, không bang-bang <= 1 %); KHÔNG dùng S_max chung (Lượt 266-268); điểm chạy TC = các điểm R trong 5 % so với R nhỏ nhất CỦA CHÍNH BỘ, chọn S nhỏ nhất (`pick_by_tolerance.m`); kết luận chính = so cả mặt Pareto; ngưỡng hòa 5 %; cùng công sức thiết kế; không lọc đo/notch/feedforward; bộ nhiều bậc chỉ giữ nếu R giảm >= 5 % mà S không tăng. Công cụ chung mới: Model/common/pick_by_tolerance.m, Model/Sim/script/{tk_bangbang, tk_block_scores}.m.
- Seed (Lượt 243, 258-259, 283): seed 5 chữ số; chọn tham số 1 seed đầu dải của mỗi bộ (Map 00000, PI/PID 10000, SMC 20000); ca chấm 1 seed chung 99999; chạy bộ riêng lẻ dùng seed local, 99999 chỉ khi so sánh. Lỗi đã gặp: hiểu "seed riêng" thành seed_00001/chạy bằng seed chung (Lượt 258), khung Linear cũng từng mắc: đọc lại quy tắc seed trước khi chạy ca.
- Lượt 272-281: lưới tham số là tập giá trị thử, điểm chọn nằm biên lưới thì phải mở rộng; nâng cổng e_rel 3 % lên 5 % không đổi điểm chọn của PI/PID trên dữ liệu có sẵn; lưới PID (Kp, Ki, Kd, Tf) do phán đoán kỹ thuật không có kiểm độ nhạy; liệt kê thiên kiến khi so PID với Map (PID đọc a_y qua T_d,ref và có tích phân nên ca đổi mu Map thua theo cấu trúc; công sức chỉnh PID nhiều hơn). Giữ 6 TC (Lượt 276-279: đề xuất báo cáo 3 nhóm mu không đổi / mu đổi / hỗn hợp, người dùng quyết giữ 6 TC). BÀI HỌC LỚN (Lượt 281): quy chuẩn phải định nghĩa THỦ TỤC ĐO bằng MỘT hàm dùng chung, không chỉ con số; hai khung dùng hai định nghĩa e_rel khác nhau (Map: giải tích 0.1-0.3 g từ 40 km/h; PI/PID: đo mô phỏng cửa sổ 0.35 g) -> viết QuyChuan.txt (Lượt 282).
- Lượt 285-300 (khung Linear/SMC chuyển dần, khung Map bàn): ca TK dùng chung cho mọi bộ để công bằng (RL ngoại lệ, tập huấn luyện tách rời); đề xuất TK có 4 bậc 0.1-0.4 g; Gates.mdl = khối MATLAB Function đo chỉ tiêu và cổng (gates_fcn.m, build_gates.m), chỉ đọc tín hiệu, không nằm trong model thật; cổng nằm ở script chọn tham số chứ không ở khối Simulink; Map vẫn bang-bang dù không có D vì bang-bang = nhiễu x độ lợi tần số cao của cả bộ (Map K x p/z ~ 188, PID Kp + Kd/Tf = 9.2, PI 0.26); Map thuần không lead chỉ ổn định với k <= 0.51 trong khi K_acc 5.75-13, nên cần lead.

### Giai đoạn 4 - Lead, lead-lag và chốt Map 1K chỉ lead (Lượt 301-334)

- Lead: H(s) = (s/z + 1)/(s/p + 1), p > z, DC gain 1 nên không đổi độ chính xác tĩnh; cặp (z, p) là hàm của K, tìm bằng phân tích tuyến tính (lưới 36 z từ 8-400 rad/s log x 40 p/z từ 1.5-120; chọn hf gain K x p/z nhỏ nhất qua PM >= 45 và GM >= 2 trên 4 điểm làm việc); K >= 10 không cặp nào đạt. Tại K 6.75 không lead: cắt 101 rad/s, pha -186.7, PM -6.7 (mất ổn định, thiếu ~1.2 ms); có lead (z 59.82, p 1665.96): cắt 161 rad/s, pha lead +64.1, PM 45.2; dự trữ trễ thêm = PM/omega_c = 4.9 ms (5 ms mất ổn định); lead tương đương 6.95 ms đi trước. Công thức rời rạc Tustin 1 ms: y[k] = b0 x[k] + b1 x[k-1] - a1 y[k-1], a = 2000, b0 = (a/z + 1)/(a/p + 1), b1 = (1 - a/z)/(a/p + 1), a1 = (1 - a/p)/(a/p + 1); với (59.82, 1666): y[k] = 0.0911 y[k-1] + 15.65 x[k] - 14.74 x[k-1]. Nhiễu trên lệnh theo K (K 5/6/6.75/7/8/9.5): 0.66/1.02/1.28/1.41/1.89/2.81 N.m so T_a,max 6.5-7.8; ngưỡng bang-bang 1 % cắt giữa K 6.75 (0.62-0.93 %) và 7.0-7.25. PM 45 là quy ước Lee [1] III.D, không phải định lý; công thức khuếch đại tại tần số cắt 1/|1 + L| = 1/(2 sin(PM/2)) (PM 45: 1.31).
- Lead-lag (Lượt 316-318, người dùng yêu cầu thử): lead-lag 1K (K 10, lead z 38.3 p 952, lag z1 25 p1 8.75) cho R 0.947, S 0.339, TV 140, e_rel 5.0 % so với lead-only 6.75 R 1.164, S 0.504, TV 333, e_rel 55.8 % (R -18.7 %, S -32.7 %); nhưng người dùng chốt (Lượt 327): Map chính thức = 1K chỉ lead, đơn giản, chừa chỗ cải tiến cho các bộ khác; luận văn ghi [1] dùng lead-lag, ta dùng dạng đơn giản (rủi ro bị hỏi: đối chứng yếu hơn mức có thể đạt). Map_2K suy biến (K thấp = cao = 6.75); Lượt 328: xóa Map_2K, đổi tên Map, bỏ hậu tố `_s` ở MỌI model/script (sao lưu 58 MB trước), 329: đổi historychat_1.md -> historychat_map.md. Lượt 330, 333: hai lần dọn sạch Map (chờ khung Linear chốt ca TK v2 và làm lại T_a,max), sao lưu ở Desktop (..._Map_truoc_clean, ..._Map_buoc1).
- Bài học giao tiếp (Lượt 324): người dùng muốn câu trả lời TỰ CHỨA, đi theo một ví dụ số liền mạch, KHÔNG viện dẫn số lượt/bước của nhật ký. Lượt 313: lee2018.pdf mục III.A (lead-lag sau bản đồ, pt 16), III.D (PM > 45, một lead tối đa ~55 độ), thiết kế ở v = 0.
- Lượt 335: thêm vào Tracking/CLAUDE.md mục "Làm một bộ điều khiển: nơi đặt code, loại script, dựng model, đặt tên" (load_ / build_ / test_ / calibrate_ ..., Model/data/<ctrl>.json là nguồn duy nhất, script phụ dùng chung).

### Giai đoạn 5 - Làm lại Map từ đầu theo lộ trình 6 bước (Lượt 331-347)

- Ca thiết kế mới (khung Linear chốt, Lượt 331): CALIB (cũ TK) 117 s, ba khối 20/60/100 km/h, a_y 0.1-0.4 g (20 km/h chỉ 0.1/0.15/0.18 g), tổng 19 cửa sổ; R gộp trung bình đều bốn nhóm static/dyn/small/mu chuẩn hóa theo T_d,ref; e_rel lớn nhất trên 11 cửa sổ static; thứ tự cổng 5.6. Bước 1 (Lượt 332, 334): lưới v 20:5:100, a_y 0.1-0.4 bước 0.005 g, trạng thái xác lập xe 2 bậc tự do suy từ a_y (đảo Magic Formula bằng fzero), test_calibration PASS; làm lại sau khi T_a,max đổi.
- Bước 2 (Lượt 338): bảng M(|T_s|) với vùng chết 0.3 N.m, chặn độ dốc K_max, K_acc(v) quét K 0.25:0.25:20 để |e_T%| <= 3 % trong 0.1-0.3 g. Bước 3 (339): tuyến tính hóa Plant bằng sai phân trung tâm, 4 điểm làm việc (thẳng/cua mạnh x mu 0.8/0.2), map_margins (PM, GM, HF), design_lead, K_stab = 9.5. Bước 4 (340): Map.mdl, Model_Map.mdl, load_map.m, build_map.m, test_map PASS (sai số xác lập < 2e-14 N.m trên 96 điểm). Bước 5 (341): quét K 3-10, 4 cổng cứng, mặt Pareto, pick_by_tolerance 5 %, test_step5 PASS 6/6 -> K_max 6.75. Lượt 336-337, 342: nhận vai/đọc trí nhớ/kiểm tra tiến độ (chỉ đọc); phát hiện K_max = K_acc và rev 1.09 % sát ngưỡng.
- Bước 6 (Lượt 343-347): TC1-TC6 seed local 00000 chạy xong (Result/Controllers/Map/TestCases_noise/seed_00000, nay gọi Cases); so sánh seed 99999 với PI (344), SMC và ISMC (345): PI bám tốt hơn Map ở 5/6 ca và êm hơn 2-90 lần; SMC, ISMC bám tốt hơn nhiều nhưng RMS T_a ~ 7 N.m ~ T_a,max và TV ~ 2000 N.m/s (bang-bang, chưa kiểm tk_bangbang); Map-PID chờ Linear. Số liệu ở mục TRẠNG THÁI. Lượt 346: dàn ý luận văn và bài báo (docx) từ dàn ý người dùng, phát hiện e_rel 57.12 %, cảnh báo ghi vào docx (commit 63bcc49). Lượt 347: PI trùng màu Map trong hình so sánh (plot_compare_cases.m đặt PI xanh = Map, make_pair_comparisons.m không có PI nên xám); sửa PI = vàng đậm [0.8 0.6 0] ở cả hai file, chạy lại ba compare, dựng lại docx, commit 3e1bb2a và push.
- Lượt 348 (nhận định ngoài dán vào, hỏi "Map hiện đang như vậy đúng không"): xác nhận khớp số liệu: Map là bản ứng viên, chưa chốt, ba điểm nghi (e_rel 57 %, K_max = K_acc, yếu hơn PI) đúng; độ lợi cao tần 188 = 6.75 x 27.85; chưa kiểm TC1 giữ cua < 3 %. Đồng ý tách: sửa lỗi đo/cài đặt thì được và phải làm trước khi viết bài; đổi cấu trúc hay nới ràng buộc sau khi thấy Map thua PI chỉ hợp lệ khi quét cả ba bộ với công sức tương đương và ghi trung thực "đổi sau kết quả". Đề xuất: Map hiện tại là bản ứng viên, kiểm xong lỗi e_rel và cực p của lead (một lần, theo lưới đặt trước) rồi mới tuyên bố đóng băng.

### Giai đoạn 6 - Rà soát cổng, độ dốc K, phạm vi a_y và quyết định lead-lag (Lượt 349-384, 2026-10-10 đến 2026-10-11)

- Map 2K suy biến (K thấp = K cao = 6.75, không qua cổng "đáng giá" R giảm >= 5 % mà S không tăng) chỉ đúng trong lưới đã quét; K_acc(v) giải tích: 20 km/h 7.5, 25: 13, 30: 8, 35: 7.25, 40-55: 6.75, 60: 6.25, 65: 5.5, 70-75: 5.25, 80-90: 5.5, 95-100: 5.75. Giữ 1K (QuyChuan 6.5). Tên mới theo QuyChuan bản 3 (CALIB, DRY, SLIP, WEAVE; Result/Controllers/<Ctrl>/{Design,Calib,Cases}) nằm ở mục TRẠNG THÁI.
- Số liệu quét K trên CALIB (seed 00000), K = 3/4/5/6/6.75/7/7.5/8/8.5/9/9.5: R 71.2/54.1/40.4/33.7/32.19/31.87/31.31/30.88/30.63/30.59/30.83 %; S 0.228/0.270/0.327/0.420/0.477/0.509/0.550/0.620/0.694/0.807/0.941 N.m; e_rel (lớn nhất 11 cửa sổ static) 136.5/111.0/85.4/62.6/57.1/55.8/53.1/51.2/49.6/48.0/46.4 %; trợ lực ngược 0.42/0.65/0.76/0.94/1.09/1.17/1.26/1.47/1.77/2.40/3.42 %; PM 45.1-46.1 độ. R_static giảm 33.3 -> 23.1 % khi K 6 -> 9.5 chủ yếu nhờ hai cửa sổ 0.4 g.
- e_rel giải tích theo cửa sổ (đường khô, T_s,eq của vòng kín với bảng chặn độ dốc): ở các cửa sổ 0.1-0.3 g (9 cửa sổ: 20 km/h 0.1/0.15/0.18 g; 60 và 100 km/h 0.1/0.2/0.3 g) giá trị lớn nhất theo K: 3: 66.8 %, 4: 38.2, 4.5: 24.6, 5: 14.7, 5.5: 5.0, 6: 3.17, 6.25: 2.78, 6.5: 2.42, 6.75: 2.08, 9.5: 0.14. Hai cửa sổ 0.4 g (60 và 100 km/h): K 6: 59.7/60.7 %, 6.75: 53.8/50.6, 9.5: 42.3/37.5, 15: 24.3/20.0, 30: 10.4/8.5 (còn 10 % ở K = 30 vì độ dốc cần > 30). Giá trị đo mô phỏng cao hơn giải tích khoảng 10 % (6.75: 57.1 so 53.8). Ngưỡng 3 % đòi K >= khoảng 6.25, 5 % đòi K >= khoảng 5.5, 10 % đòi K >= khoảng 5.2 (gần như bỏ cổng). Dấu e_rel dương = tay lái nặng hơn mong muốn (M thấp hơn giá trị hiệu chỉnh).
- Cơ chế sai số tĩnh: map_table dựng M(k+1) = min(T_a,cal(k+1), M(k) + K x dT_s) từ vùng chết đi lên; đoạn có độ dốc cần > K thì M tụt sau giá trị hiệu chỉnh, K tăng thì phần thiếu giảm; đoạn có độ dốc tự nhiên < K thì M đi qua đúng điểm hiệu chỉnh (e_rel = 0 ở nhiều cửa sổ bất kể K). Bảng được dựng offline bằng tính ngược T_a,cal = T_r - T_d,ref (cân bằng tĩnh cột lái, ma sát khô nuốt dải +-T_f nên lấy tâm dải); lúc chạy Map chỉ đọc T_s và v. Hai biên của K không đến từ tính ngược: K_acc (sàn) từ sai số tĩnh vòng kín khi bảng bị chặn độ dốc (map_k_accuracy), K_stab = 9.5 (trần) từ tuyến tính hóa Plant + lead (PM >= 45, GM >= 2); CALIB chọn K giữa hai biên bằng R, S và các cổng. Chọn bảng bằng mô phỏng thay cho tính ngược: không khuyên (ma sát khô gây trễ kiểu hysteresis, tốn mô phỏng, thêm tham số).
- Cổng: mục đích (chống thiên lệch, đặt trước, loại điểm không dùng được); thứ tự QuyChuan 5.6: ổn định và độ dư > không trợ lực ngược (<= 1 %) > không bang-bang (<= 1 %) > độ chính xác (<= 3 %). Con số 3 % tự chọn, không có nguồn ngoài (gốc là ràng buộc K_acc của Map, sau thành cổng chung); QuyChuan bắt báo độ nhạy 3 và 5 %. PHÁT HIỆN trong design_map.m: gate_acc = (K >= 6.75) là điều kiện giải tích, KHÔNG phải e_rel đo; mặc định revMax = 1.5 (dòng 34) trong khi QuyChuan 4.6 và 5.5 chốt 1 % (cải chính câu nói trước đây "1.5 %"). Trợ lực ngược (gates_fcn): tỉ lệ mẫu chấm điểm (từ 2 s, toàn 117 s CALIB) có |T_s| >= 0.5 N.m và T_a ngược dấu T_s (0.94 % ~ 1.1 s); cơ chế (suy luận): lead cho thành phần như đạo hàm, T_a đổi dấu chốc lát khi T_s đổi nhanh hoặc nhiễu được khuếch đại gần vùng chết; K tăng thì độ lợi cao tần K x p/z tăng nên trợ lực ngược tăng. Hai cổng 3 % và 1 % chỉ để lại khe rất hẹp quanh K = 6.25-6.3 (lưới chỉ có K = 6 và 6.75, chưa biết có điểm nào qua cả hai). PI trong pi.json: e_rel 3.25 %, trợ lực ngược 4.51 % (cũng vượt). Đề nghị đo trước số lần, độ lớn đỉnh của trợ lực ngược (K = 6, 6.75, PI) rồi hạ nó từ cổng cứng xuống chỉ tiêu báo cáo nếu là xung nhỏ.
- Vùng a_y: Plant đạt a_y tối đa 0.80 g từ 45 km/h (đường khô); 20 km/h chỉ 0.20 g, 25: 0.31, 30: 0.44, 35: 0.59, 40: 0.73 (hình học lái). Bán kính cua và góc vô-lăng (n_st = 16, góc bánh xe = góc vô-lăng / 16): 60 km/h 0.3 g: 94 m, 32 độ vô-lăng, 2.0 độ bánh xe; 100 km/h 0.4 g: 197 m, 21 độ, 1.3 độ; 30 km/h 0.4 g: 18 m, 146 độ, 9.1 độ; giả thiết góc nhỏ áp cho góc bánh xe và góc trượt lốp, không cho góc vô-lăng. Lái thường chủ yếu < 0.3 g (kiến thức chung); a_y thật có thể tới mu x g (0.8-1 g).
- T_d,ref: Bảng 4 trong dự án = Table 4 của Li và Xia 2012 (Road Identification BP-NN), bài đó ghi "một số cơ quan đề xuất... dựa trên nhiều thí nghiệm" không dẫn nguồn (có thể liên quan Zong 2007, chưa kiểm). Phẳng ở 0.3-0.4 g (60 km/h tăng 2.8 -> 2.9; 100 km/h 3.3 -> 3.4): Ren và Deng 2014 (đã có trong References, 22 lái xe, 3 xe) đo 40 km/h a_y 0.25/0.35/0.45/0.5 g = 2.25/2.353/2.43/2.53 N.m, kết luận tăng chậm dần tiến tới hằng số; bảng của ta ở 0.35 g khớp (2.35 so 2.353). Định luật Stevens (Nguyen et al., ANFIS-FOC, phương trình (3)): a_y = b/(1 + c v^k) x |T_d|^n; (b, c, k, n) = (0.2675, 2.7646, 0.4442, 4.5357); đảo T_d = ((1 + c v^k) a_y/b)^(1/n) với v m/s, a_y m/s^2: gần bảng từ 60-100 km/h (lệch 0.1-0.3 N.m), lệch nhiều ở 20 km/h (2.04-2.77 so 1.0-1.8); n = 4.54 nên T_d ~ a_y^0.22 phẳng dần: phẳng là tính chất của dạng lũy thừa. Không tìm thấy bảng thứ hai công bố; hai bài MDPI 2025 và HAL bị chặn truy cập tự động, bài 2013 (Journal of South China University of Technology 41(8):74-79) chỉ thấy tóm tắt.
- Phạm vi đánh giá (đề xuất, chưa chốt): bỏ vùng 0.4 g khỏi cổng và khỏi R (R_static cũng phải bỏ hai cửa sổ 0.4 g, nếu không vùng cực vẫn kéo K lên), giữ cửa sổ 0.4 g trong CALIB chỉ để đo chỉ tiêu riêng e_ext (có dấu, theo cửa sổ); ba ca chấm cắt xuống 0.3 g (chỉ cảnh down của SLIP 0.35 g phải hạ); thêm ca thứ tư cho vùng cực (tên đề xuất EDGE: a_y 0.35 và 0.4 g giữ ổn định ở 40, 60, 100 km/h cộng đoạn sin tới 0.4 g, không đổi mu, chỉ báo cáo: e_rel có dấu, RMS e_T, S, TV, đỉnh T_a so T_a,max, trợ lực ngược). KHÔNG cắt bảng T_d,ref, ref.json và T_a,max (T_a,max tính tại a_y tối đa hợp lệ tới 0.4 g, ví dụ 30 km/h: T_r 9.917, T_d,ref 2.113, T_a,req 7.804, T_a,max 9.804): cắt sẽ phải tính lại T_a,max và chạy lại mọi bộ, giữ như dữ liệu nguồn và khả năng phần cứng. Đổi cổng sau khi thấy kết quả phải ghi ngày, lý do và áp cho mọi bộ; hai khung Linear và SMC dùng chung nên cần báo. Đã bác: trung bình có trọng số 90/10 cho e_rel (K 6/6.75/9.5 cho 6.7/5.6/4.0 %, phần lớn do 10 % x lỗi 0.4 g, hai tham số chọn sau khi thấy kết quả, che cửa sổ xấu); 2K theo a_y (ngưỡng T_s theo a_y phụ thuộc v, K_high không vượt K_stab = 9.5, tăng toàn bộ K từ 6.75 lên 9.5 chỉ giảm R 4.2 % < 5 %, và CALIB bỏ 0.4 g thì không có ca để chọn K_high).
- R, S, e_rel: R (%) = trung bình đều của bốn R_g (static, dyn, small, mu), R_g = 100 x RMS(e_T)/trung bình |T_d,ref| trên các cửa sổ nhóm; S (N.m) = RMS của T_a sau lọc cao 5 Hz (bỏ 2 s đầu); e_rel = 100 x |trung bình e_T|/trung bình |T_d,ref| trên TỪNG cửa sổ static, lấy lớn nhất. R là chỉ tiêu xếp hạng, e_rel là cổng; một bộ có thể có e_rel nhỏ mà R lớn (Map K 6.75: e_rel 0-2 % ở 0.1-0.3 g, R 32 % vì nhóm dyn ~74 %).
- LPF và lead-lag: cực lọc thông thấp đứng riêng không giúp (cực <= 2000 rad/s không đạt PM 45 độ, cực 4000 rad/s nhiễu lệnh 1.54 so 1.38 N.m ở K = 7; số cũ). Người dùng chốt hướng (2026-10-11): làm theo bài báo [1], lead-lag là Map chính. Lag cùng dạng (s/z1 + 1)/(s/p1 + 1) với p1 < z1 (ví dụ z1 25, p1 8.75 rad/s, độ lợi cao tần 0.35); lead (38.3, 952) hoặc (59.82, 1666); độ lợi DC của cả hai bằng 1 nên không đổi sai số xác lập. Trên mô hình tuyến tính tại 60 km/h, 0.2 g, bốn điểm làm việc của map_op_points: không bù K 6.75 PM -6.5 độ (mất ổn định); lead K 6.75 PM 45.2, GM 4.56; lead-lag K 10 PM 45.4, GM 4.85. Độ lợi cao tần K x p/z: 188 (lead) so 10 x 24.9 x 0.35 = 87 (lead-lag); nhiễu T_s (0.0104 N.m) ra lệnh T_a: 1.46 so 0.75 N.m. Độ lợi và pha của lead (59.82, 1666) tại 3/40/160/1000 rad/s: 1.00 (+2.8 độ, sớm 16 ms), 1.20 (+32, sớm 14), 2.84 (+64, sớm 7), 14.4 (+56, sớm 1); lag (25, 8.75): 0.95 (-12.1, trễ 70 ms), 0.40 (-20, trễ 9), 0.35 (-5.8, trễ 0.6), 0.35 (-0.9); lead-lag: 0.96 (trễ 45 ms), 0.58 (+24), 1.50 (+61), 6.31 (+41). Lag rút độ lợi cao tần nhưng giữ pha tại tần số cắt vì hai khâu ở hai dải tần khác nhau (không "huề" hoàn toàn); chưa bỏ nhiễu, chỉ thu nhỏ. Cái giá: trợ lực trễ khoảng 45 ms với tay lái 0.5 Hz. Ví dụ thời gian (người lái quay trong 200 ms, mở vòng T_s cuối 1.0): T_s cuối 0.140 (lead) và 0.099 (lead-lag); sau 20 ms T_s 0.219 và 0.320; sau 50 ms 0.114 và 0.083; lúc ngừng quay (210 ms) T_a đổi dấu xuống -2.8 và -2.9 N.m vài ms (cơ chế trợ lực ngược); đỉnh lệnh 7.1 và 5.7 N.m. Lead-lag K 10 cũ (CALIB cũ): R -18.7 %, S -32.7 %, TV -58 %, e_rel 0.35 g từ 55.8 xuống 5.0 %, nhưng ở 0.4 g vẫn khoảng 40 % vì sai số tĩnh chỉ phụ thuộc K (cải chính nhận định "lag giải được vùng cực"). Sửa nhỏ so với câu trả lời miệng: lag trễ 0.6 ms (không phải 1.4 ms) tại 160 rad/s. Khâu bù đã được ghi thành LÝ THUYẾT, QUY TRÌNH VÀ CÁCH ĐƯA VÀO BÀI BÁO/LUẬN VĂN ở Phần 10 của Documents/Notes/Controllers/LyThuyet_Map.txt.
- Việc sửa nếu lead-lag thành Map chính (danh sách ở Lượt 383 cũ, nay là Bước A-G của Phần 10 LyThuyet_Map.txt): design_lead.m, map_margins.m, map_noise_gain.m (thêm lag), map_variables.m (bậc hai), build_map.m, test_map.m, design_map.m, run_step5.m, plot_step*.m, map.json (z1, p1, K_stab mới), tài liệu (QuyChuan mục 2 và 6.7, LyThuyet_Map, map.txt, hai docx); chạy lại bước 3-6; sao lưu rồi xóa Calib/ và Cases/ của bản chỉ lead; code Map_LL cũ ở C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-09_Map_truoc_clean; lưới lag đặt trước z1 {15, 25, 40, 60} x p1/z1 {0.7, 0.5, 0.35, 0.25}.

### Giai đoạn 7 - Chốt lead-lag, quy chuẩn bản 4 và Bước 0-2 của Map mới (Lượt 385-395, 2026-10-11)

- Lý thuyết lead-lag đã giải thích và ghi vào Documents/Notes/Controllers/LyThuyet_Map.txt Phần 10 (Lượt 385-389): độ lợi DC (hệ số khuếch đại khi tín hiệu vào không đổi) của lead và lag đều bằng 1 nên sai số xác lập chỉ do K quyết định; công thức H(s) = (s/z + 1)/(s/p + 1), lead p > z (độ lợi cao tần p/z), lag p1 < z1 (độ lợi cao tần p1/z1); Tustin 1 ms; độ lợi |H(jw)| bắt đầu rời 1 quanh z (bằng căn 2 tại w = z), ngừng đổi quanh p; pha dương = đầu ra đi trước, dời thời gian = pha[độ]/(360 f); lead khuếch đại nhiễu (độ lợi tới 27.9, 14.4 tại 1000 rad/s), lag rút độ lợi cao tần nhưng giữ pha tại tần số cắt vì hai khâu ở hai dải tần khác nhau (không "huề"); lead-lag chỉ thu nhỏ nhiễu chứ chưa bỏ; cách đưa vào bài báo (đầy đủ) và luận văn (rút gọn); Phần 10 còn có quy trình Bước A-G và ví dụ thời gian.
- Kiểm tra phần ca thử do khung COMMON làm (Lượt 390): đúng ý (CALIB nhãn ext_* ngoài R và cổng, SLIP down 0.3 g, ca EDGE bốn ca, test_calib PASS 30 kiểm); EDGE của Map ở s00000: e_rel có dấu 38.5 % (40 km/h, 0.35 g), 81.8 % (0.4 g), 16.5 % và 51.3 % (60 km/h), 16.5 % và 43.9 % (100 km/h), sin 11.5 %. Khung COMMON cập nhật QuyChuan phiên bản 4 và Tracking/CLAUDE.md lúc 01:25; ext_ = tiền tố của cửa sổ 0.4 g (aExt = 0.3 g), chỉ báo cáo qua m.eextSigned (Lượt 392); tôi bổ sung chỗ còn thiếu (Lượt 393: EDGE, e_rel đo bằng mô phỏng trên 9 cửa sổ, lý do và "đổi sau khi thấy kết quả" trong nhật ký thay đổi, danh sách bộ phải chọn lại thêm SMC, ISMC).
- Quyết định của người dùng khi làm lại Map (Lượt 391-398): khung này chỉ làm Map; lead-lag đầy đủ là Map chính, bản chỉ lead giữ làm đối chứng; QuyChuan mục 2.4 (lõi Map có lag) và 6.7 (báo riêng số K đã mô phỏng và số bộ (z, p, z1, p1) đã xét) sửa ngày 2026-10-11 (Bước 0, kèm sao lưu Map ra Desktop/Adaptive-EPS_backup_2026-10-11_Map_truoc_leadlag); e_rel đổi 3 % -> 5 % (QuyChuan 5.3, báo độ nhạy 3 % và 10 %; cả hai tự chọn, thay đổi sau khi thấy Map không đạt); bang-bang giữ 1 %; trợ lực ngược đo trước khi quyết (số đo trên lead-only không kết luận được cho lead-lag, vì là tính chất của cả bộ; ví dụ tuyến tính T_a đổi dấu -2.80 và -2.91 N.m ở cả hai); ngưỡng hòa 5 % (QuyChuan 6.4) là mức chênh dưới đó coi là ngang nhau và cũng là dung sai R của quy tắc chọn, KHÔNG liên quan ngưỡng e_rel 5 % (lập luận "trùng số" đã rút lại).
- Đặc tả và công cụ (Lượt 396-399): Documents/Notes/Controllers/DieuKhien_Map.txt (A1-A9 đặt trước khi chạy: cấu trúc, K là tham số duy nhất chọn bằng mô phỏng, (z, p, z1, p1) tính offline theo K, 68 mô hình tuyến tính (17 tốc độ x 4 điểm làm việc), độ dốc k = K x {0.25, 0.5, 0.75, 1}, cổng PM >= 45, GM >= 2, lưới lead z 5-500 rad/s x p/z 1.2-300 với p <= 3142 rad/s, lag z1 8-120 x p1/z1 0.1-0.9 với p1 >= 3 rad/s, hai giai đoạn thô 24 x 25 x 8 x 6 rồi mịn 9 giá trị mỗi tham số); code mới: map_margins_batch.m (đánh giá hàng loạt), design_leadlag.m (hai giai đoạn, loại sớm theo mô hình khó nhất, tham số bandGain = [g_min, 12.57 rad/s]), sweep_leadlag.m (chạy nền, ghi từng dòng Map_design_leadlag.csv), test_leadlag_design.m PASS 14 kiểm; map_margins.m và map_noise_gain.m nhận thêm lag (test_step3 vẫn PASS). Lỗi gặp: R.HF ra NaN do 0 x NaN (đã sửa).
- PHÁT HIỆN thiết kế (Lượt 398): tiêu chí "độ lợi tần số cao nhỏ nhất" suy biến khi lag tự do (dồn lag vào cận lưới p1/z1 = 0.1, p1 = 3.1 rad/s; lead-lag khả thi tới K = 30, tần số cắt tụt xuống 71-116 rad/s). Sửa bằng ràng buộc vật lý: độ lợi của khâu lag tại 2 Hz (12.57 rad/s; QuyChuan 4.2 coi lệnh lái dưới khoảng 2 Hz) không nhỏ hơn g_min. Người dùng chọn cách B (Lượt 399): g_min là tham số quét thứ hai trên CALIB, mức {1.0 (không lag = lead đơn), 0.9, 0.8, 0.7, 0.6}; đề xuất trước đó của tôi (cố định 0.9) chỉ vì chi phí, mức 0.9 không có cơ sở.
- KẾT QUẢ Bước 2 (Lượt 400, 68 mô hình, 933 400 ứng viên đã xét, khoảng 5900 s, kiểm độc lập PM nhỏ nhất 45.00 độ, mọi điểm chọn không ở cận lưới): K lớn nhất khả thi (K đầu tiên không khả thi): lead đơn 8.0 (8.5) (KHÔNG phải 9.5 của bản cũ: bản cũ chọn p = 6415 vượt Nyquist 3142 rad/s, không thực hiện được bằng Tustin 1 ms), g_min 0.9: 10 (11), 0.8: 12 (13), 0.7: 14 (15), 0.6: 16 (17). Tại K = 6.5, g_min 1.0/0.9/0.8/0.7/0.6: nhiễu lệnh 0.421/0.282/0.215/0.168/0.133 N.m, độ lợi cao tần 164.4/95.4/65.2/46.9/35.3, tần số cắt 164/135/122/112/104 rad/s. Cùng nhiễu khoảng 0.3 N.m: lead đơn K 5.5-6, 0.9 K 7, 0.8 K 8.5, 0.7 K 10, 0.6 K 11 (sai số xác lập chỉ do K nên lag cho cùng nhiễu với K lớn hơn, đổi lại tần số cắt thấp hơn và đáp ứng động chậm hơn: CALIB mới cho biết). Hình Map_design_compare.png. Ghi B7, B8 vào DieuKhien_Map.txt. Kế hoạch Bước 4 (B8, chờ người dùng xác nhận): 29 cặp (g_min, K) thô (lead đơn K 6-8; 0.9: 6-10; 0.8: 6-10, 12; 0.7: 6-10, 12, 14; 0.6: 6-10, 12, 14, 16), mịn thêm 10-15 cặp, tổng khoảng 40-45 cặp; mỗi cặp 4 mô phỏng (có nhiễu, lý tưởng, độ lợi x2, trễ +1 ms). K = 5 và 5.5 bỏ vì e_rel giải tích 9 cửa sổ tại K = 5.5 vừa đúng 5.0 % và đo mô phỏng cao hơn khoảng 10 %.

### Giai đoạn 8 - Bước 1-5 của Map lead-lag, bỏ cổng trợ lực ngược, quét vượt cận tuyến tính (Lượt 396-405, 2026-10-11)

- Bước 1-2 (Lượt 396-400): lưới lead z 5-500 rad/s, p/z 1.2-300, p <= 3142 rad/s; lag z1 8-120, p1/z1 0.1-0.9, p1 >= 3 rad/s; hai giai đoạn thô-mịn; tiêu chí độ lợi cao tần nhỏ nhất suy biến khi lag tự do nên thêm ràng buộc độ lợi lag tại 2 Hz >= g_min (cách B: g_min là tham số quét thứ hai). Kết quả 68 mô hình: K lớn nhất khả thi lead đơn 8.0 (không phải 9.5 cũ vì p cũ 6415 > Nyquist 3142), g_min 0.9/0.8/0.7/0.6: 10/12/14/16. g_min cần vì PM, GM, nhiễu tuyến tính không đo độ bám trong dải lái (Lượt 401).
- Bước 3 (Lượt 402): map_variables.m ghép lead x lag thành khối rời rạc bậc 2 (Tustin 1 ms, DC 1, design.lag tùy chọn); load_map.m in lag; test_map.m thêm kiểm (3) lead-lag, kiểm (2) so bộ bù của map.json, StopTime nay 8 s (cực lag chậm nhất 3.13 rad/s); PASS.
- Bước 4 (Lượt 402): run_calib_sweep.m (4 mô phỏng CALIB mỗi cặp: nhiễu seed 0, lý tưởng, độ lợi x2, trễ +1 ms; csv chạy tiếp được; sau thêm compK, outCsv, cột comp_K) và select_map.m. CALIB cũ sao lưu Desktop/Adaptive-EPS_backup_2026-10-11_Map_truoc_leadlag/Calib_cu. 37 cặp (29 thô + 8 mịn). Người dùng (theo khung kia) bỏ cổng trợ lực ngược: chỉ báo cáo; đã sửa select_map, design_map (gate_rev = true), test_step5, DieuKhien_Map A6, câu lỗi thời trong QuyChuan. Chọn theo quy tắc cũ (R trong 5 % rồi S): g_min 0.7, K 8, lead (37.03, 834.88), lag (28.13, 10.69), R 25.63 %, S 0.2824, TV 137.5, e_rel 0.68 %, rev 0.23 %; lead đơn K 6: R 25.85, S 0.4098, e_rel 3.17 %.
- Bước 5 (Lượt 403): bốn ca seed 0 của điểm 0.7, K 8 (Cases cũ sao lưu Cases_cu; bản này sau đó sao lưu Cases_0p7_K8 và map_0p7_K8.json): RMS e_T DRY 0.628, SLIP 0.530, WEAVE 1.325, EDGE 1.253 N.m; S giảm 40-54 %, TV giảm 65-70 % so lead đơn cũ; vũng nước -86.9 %; EDGE 0.4 g 61.9/45.4/38.4 %.
- Kiểm lời khung Linear (Lượt 404): nguyên tắc cùng luật đúng nhưng số Map lỗi thời (K_stab 9.5 cũ; PM/GM đã chỉ báo cáo từ v4). Nếu đặt cổng rev 0.5 % thì điểm chọn cũ nhảy sang 0.65, K 9.
- Quét K vượt cận tuyến tính theo v5 9.5 (Lượt 405): 12 cặp (lead đơn K 10-40 với bộ bù K 8; g_min 0.7 K 16-40 với bộ bù K 14; 0.6 K 20, 30 với bộ bù K 16), file Map_CALIB_sweepbeyondA/B_s00000.csv; không cặp nào mất ổn định; R phẳng (lead đơn 24.40-24.82 %, 0.7: 25.39-25.40 %), S tăng; lead đơn rớt bang-bang 1 % từ K 10. Lần chạy đầu bị ngắt ở giao diện nhưng vẫn chạy ra file trùng (đã chuyển ra Desktop, kết quả giống hệt: mô phỏng tái lập được).

### Giai đoạn 9 - Chọn lại Map theo QuyChuan v5, ràng buộc dải lái, làm lại tài liệu, gói gửi thầy (Lượt 406-415, 2026-10-11 đến 2026-10-12)

- Kiểm lời COMMON (Lượt 406): cực tiểu J = R x S trên các cặp cũ là g_min 0.6, K 6 (J 6.31) đúng; "55 cặp" tính trùng (49 cặp khác nhau; file trùng Map_CALIB_sweepbeyond_s00000.csv chuyển ra Desktop).
- Chọn lại theo v5 (Lượt 407): select_map.m viết lại (gộp bảng chính và beyond A, B, J, calib_margin cho 5 điểm đầu, độ nhạy, bang-bang hai seed, ghi map.json); lưới mở rộng g_min 0.5, 0.4, 0.3, 0.25 (qLim 0.05 cho 0.25), K 5.75, 5.8, 6.5: 73 cặp, 68 qua e_rel. J giảm gần đơn điệu theo g_min tới cận p1 >= 3 rad/s (1.0: 10.6 ... 0.7: 6.74 ... 0.25: 5.11), không có cực tiểu bên trong; điểm J thuần g_min 0.25, K 5.8 (R 37.73 %, S 0.1354, vũng nước -122 %). K bị e_rel chặn: 5.5: 8.61 %, 5.75: 5.02 %, 5.8: 4.62 %, 6: 3.16 %.
- Hỏi đáp (Lượt 408-410): Map chậm đi thì bám kém (R +47 %, S -52 %, J -29 %); quy tắc 5 % cũ bị bỏ vì dồn PID về Ki 100, nhảy theo một điểm cực trị, 5 % không có nguồn; ba phương án A (J + ràng buộc -3 dB tại 2 Hz), B (R trong JND 10 % rồi S), C (J trong R <= 1.1 R nhỏ nhất); gợi ý A. Nén lần bốn ở Lượt 410.
- Phương án A (Lượt 411): select_map thêm lag_gain_2Hz, g_band; chọn g_min 0.7, K 6 (lead 33.50/600.11, lag 28.13/10.69, độ lợi lag 2 Hz 0.710; R 27.05 %, S 0.2492, TV 92.5, J 6.743, e_rel 3.17 %, rev 0.21 %, bang-bang delta 0, calib_margin qua: tỉ số 0.78, 1.00); độ nhạy a 0.5 và 2 cùng điểm; không ràng buộc ra 0.25/5.8; quy tắc 5 % ra 0.7/8.5; lead đơn K 6 (R 25.85, S 0.4098, J 10.6). QuyChuan 6.2 viết lại, 9.5, nhật ký thay đổi (lần thứ tư đổi quy tắc sau khi thấy kết quả), Tracking/CLAUDE.md, DieuKhien_Map B11. PHÁT HIỆN: DRY v40a0p3r +13.0 % (K 8: +0.5 %) vì CALIB không có cửa sổ static 40 km/h; người dùng bác thêm cửa sổ 40 km/h.
- Năm ca DREWS seed 0 (Lượt 412): RMS e_T DRY 0.689, RAMP 0.835, SLIP 0.538, WEAVE 1.327, EDGE 1.535 N.m; S 0.150, 0.170, 0.161, 0.160, 0.129; TV 78, 115, 95, 47, 22; vũng nước -86.8 %; RAMP dn +15/+31/+47 %, up -20/-7/-6 %; EDGE 0.4 g 99.7/56.8/52.5 %.
- Hỏi đáp (Lượt 413): QuyChuan v5 gồm những gì (trả lời đầu thiếu RAMP, đã nhận); kết quả Map không cần chạy lại, chỉ còn so sánh seed 99999.
- Làm lại đồ cũ (Lượt 414): sao lưu Desktop/Adaptive-EPS_backup_2026-10-12_Map_lam_lai_tai_lieu; xóa 10 script lead đơn (design_map, run_step5, test_step3, test_step5, sweep_stability, map_bangbang_scan, plot_step5, plot_step3, design_lead, knee_point) và kết quả cũ (Map_step3_*, Map_stability_lead_sweep.csv, Map_design_compare.png, Calib/Map_CALIB_metrics_s00000.png); map.json thêm x_design_note; map_k_accuracy ghi Map_K_for_accuracy_<tol>pct.csv (file cũ bị khóa), plot_step2 dùng K của map.json và 5 %; tools/build_map_txt.py viết lại (năm ca, ba hình Map_bode.png, Map_CALIB_pick_s00000.png, Map_CALIB_pareto_s00000.png), map.txt, map.docx, LyThuyet_Map Phần 2-10, dàn ý docx (bỏ so sánh cũ), DieuKhien_Map B12. Số công sức (6.7): 18 K, 73 cặp, 292 mô phỏng CALIB, 103 thiết kế tuyến tính, 1 630 706 khâu ứng viên. K_acc(40 km/h, 5 %) = 6.25 > 6. test_map, test_step2, test_leadlag_design PASS.
- Gói gửi thầy (Lượt 415): Documents/Paper/resource/ (Model đủ để chạy Map), test_map từ gói PASS; các lượt 416-418 thu gọn lại (xem nguyên văn).

### Giai đoạn 10 - Gói tái lập, MapOpt, CALIB v2 và chuyển sang tìm Map duy nhất (Lượt 416-426, 2026-10-12 đến 2026-10-18)

- Lượt 416-418 hoàn thiện rồi thu gọn `Documents/Paper/resource/`: README cuối chỉ hướng dẫn `setup_paths`, `load_map`, `test_map`, `run_cases('Map', 0)`; gói giữ model, 11 script cần chạy ca, một bảng metrics và năm hình DREWS tham chiếu. `reproduce_map.m` vẫn ở repo nhưng bị bỏ khỏi gói. Bài học: phải sao lưu csv trước khi thử quy trình chạy tiếp; `taskkill MATLAB` từng tắt cả MATLAB của người dùng nên không được lặp lại.
- Lượt 419 quyết định không đưa 15 hình đáp ứng đầy đủ (5 ca x 3 bộ) vào bài báo; chỉ nên có tối đa một hình phóng cảnh vũng nước SLIP và một hình DRY/RAMP, còn hình đầy đủ để ở phụ lục hoặc gói resource.
- Lượt 420 phân tích tối ưu đồng thời: chỉ chứng minh được cực tiểu cục bộ trong hộp và trên CALIB; J có thể chạy tới biên làm chậm, nên phải giữ ràng buộc dải lái, kiểm nhiều seed và công bằng ngân sách giữa các bộ. Đây là cơ sở cho chuỗi MapOpt sau đó, nhưng từ 2026-10-19 phương pháp `surrogateopt` đã bị thay bằng quét lưới.
- Lượt 421-425 làm MapOpt hai lần trên CALIB v1. Lần 1 có J trung bình 6.294 nhưng sàng PM/GM quá lỏng. Lần 2 áp PM >= 30, GM >= 2 ngay lúc tìm, dùng `job_lib_patient.sh` để chờ RAM và tự chạy lại; hoàn tất 2026-10-17 07:55, chọn K 6.06, lead 38.7/385, lag 46.2/11.74, PM 30.1, J trung bình seed 1-5 là 5.630; DREWS seed 0 bám ngang Map cũ nhưng S thấp hơn 35-50 % và TV thấp hơn 60-65 %. Ba chuỗi chưa hội tụ tốt (J tốt nhất 5.86/5.64/7.13). Kết quả này thuộc CALIB v1, không dùng cho thiết kế hiện hành.
- Lượt 426 tiếp nhận CALIB v2: 140 s, 68 cửa sổ, 26 static, R là trung bình nhân ba nhóm; `result_dir(ctrl,'Calib')` trỏ `Calib_v2`, còn `CalibV1` chỉ để tái lập. Mọi kết quả Map/MapOpt trước đó là v1; Map K 6 không còn qua cổng chính xác trên v2, nên phải thiết kế lại từ đầu. Tài liệu Map cũ vẫn mô tả CALIB v1 và cần viết lại sau khi chốt kết quả mới.

### Bài học và lỗi đã gặp (tổng hợp)
- Chạy thử một chuỗi quét 'chạy tiếp được' trên dữ liệu thật có thể ghi thêm dòng nếu lưới mặc định khác lưới gốc (Lượt 417: thêm g_min 0.9 K 10.5): sao lưu csv trước khi chạy thử; taskkill MATLAB tắt cả cửa sổ người dùng đang mở.
- Lệnh rm với biến shell bị kiểm tra an toàn chặn: dùng "${P:?}/..." hoặc đường dẫn tuyệt đối. Chuỗi Python có ' %' trong định dạng % phải gõ '%%'; heredoc không trích dẫn làm hỏng \n (dùng chr(10) hoặc <<'EOF').
- Đề xuất ghi ở QuyChuan Phần 9 chưa được người dùng chốt thì chưa phải quy tắc (Linear Lượt 153: calib_margin 'không số' đã bị trả về cổng R <= 2).

- Chỉ làm khi được bảo (câu hỏi, đề xuất, đồng ý không phải lệnh); đừng chạy mô phỏng khi chưa chốt lựa chọn (Lượt 166); không commit thay người dùng; trước khi xóa phải xem mục tiêu và sao lưu (Model/Controllers từng chưa vào git).
- Đọc lại quy tắc seed (Tracking/CLAUDE.md, QuyChuan 3.3) TRƯỚC khi chạy ca; chạy MATLAB nền bằng đường dẫn tuyệt đối với `-softwareopengl`; không đặt biến vòng lặp trùng tên biến base workspace của model; với fsolve kiểm phần dư thật.
- Số "tay" phải kiểm lại bằng tính độc lập (đã đính chính nhiều lần: Kp_max Lượt 250-251; "Map chỉ hiệu chỉnh tới 0.3 g" Lượt 286: 0.3 g là lựa chọn thiết kế, không phải giới hạn dữ liệu; rev ngưỡng 1 %, không phải 1.5 %, Lượt 350).
- Định nghĩa chỉ tiêu phải đi kèm MỘT hàm đo dùng chung (bài học e_rel hai định nghĩa).
- Trước khi nói một ngưỡng hay con số của quy chuẩn phải đọc lại QuyChuan và code (trợ lực ngược là 1 %, không phải 1.5 %; cổng độ chính xác trong design_map.m là điều kiện giải tích, không phải e_rel đo); sau khi tính một bảng số mới phải so lại với các số đã nói (lag trễ 0.6 ms, không phải 1.4 ms).
- Khi cho một tham số tự do vào tiêu chí tối thiểu hóa, cận lưới có thể quyết định kết quả (lag dồn vào cận): phải thử trên vài mô hình trước khi chạy quét lớn và đặt ràng buộc vật lý; chọn bằng đo (CALIB) tốt hơn đặt tay một mức (Lượt 398-399).
- Nhật ký phải được ghi mỗi lượt và nén đúng hạn: đã nén muộn ở Lượt 400 (đáng lẽ Lượt 399) vì đếm lượt từ lần nén cuối chưa kiểm sau mỗi lượt.
- Quy tắc chọn không thứ nguyên (J = R x S) có thể không có cực tiểu bên trong khi bộ điều khiển có khâu làm chậm: phải xem đường J theo tham số trước khi tin điểm chọn (Lượt 407).
- Lệnh nohup bị người dùng ngắt ở giao diện vẫn có thể đã chạy: kiểm file kết quả trước khi chạy lại (Lượt 405-406).
- Đổi cổng, ca thử hay phạm vi sau khi thấy kết quả phải ghi ngày và lý do, áp cho MỌI bộ, báo hai khung kia; chọn ngưỡng sao cho một bộ cụ thể qua cổng là chỉnh cho bộ đó.
- Bảng TC4 trợ lực thừa chỉ có nghĩa ở cửa sổ during_puddle (T_d,ref ~ 0 ở hai cửa sổ kia làm phần trăm vô nghĩa); nhật ký là bản cô đọng, mọi con số, quyết định, tên file được giữ.

---

## NHẬT KÝ NGUYÊN VĂN (5 lượt gần nhất)

### Lượt 427 (2026-10-18) - Map là bản duy nhất, tìm tham số bằng phương pháp tối ưu trên CALIB v2 (bắt đầu chạy)
Người dùng: bản MapOpt đã nằm trong git, coi như dọn hết, nay chỉ còn Map; tìm tham số Map bằng phương pháp tối ưu, chạy có ràng buộc RAM (khung khác chạy đồng thời), xong chạy DREWS cũ (DREWS làm lại sau). ĐÃ LÀM: sao lưu Desktop/Adaptive-EPS_backup_2026-10-18_Map_truoc_tim_opt_v2 (Result Map + map.json). Chuyển lớp tối ưu của MapOpt sang Map (Model/Controllers/Map/script/): map_opt_eval (PM >= 30, GM >= 2 ngay lúc tìm, e_rel <= 5 % trên 26 cửa sổ static, dải lái lag >= 0.707, mô hình Model_Map), map_opt_plants, map_opt_margins, map_u2x, map_x2u, optimize_map(runId, maxEvals), refine_map, select_map_multiseed(writeJson; giữ thiết kế cũ ở design_v1), test_map_opt. Không điểm đầu từ kết quả v1. Kết quả vào Result/Controllers/Map/Calib_v2/Map_CALIB_opt<k>_s00000.csv. Kiểm tra PASS: thiết kế cũ (K 6) có PM 45.292, GM 5.674 khớp map.json, nhưng trên CALIB v2 e_rel 45 % nên bị loại. Chạy: tools/jobs/map_opt_pipeline.sh (job_lib_patient: chờ 6 GB, tự chạy lại khi bị guard_ram dừng; ba chuỗi surrogateopt 250 + patternsearch 60, chọn trên seed 1-5, DREWS seed 0); trạng thái scratch/jobs/map_master_status.txt. Chưa commit.

### Lượt 428 (2026-10-18) - Kết quả tìm tham số Map trên CALIB v2: tìm xong, bước chọn dừng vì cổng e_rel ở seed 1-5
Lần 1 (K hộp 0.1-16, 250 lần): 0 thiết kế hợp lệ vì e_rel <= 5 % cần K > 8 (tốt nhất K 8.15, e_rel 5.27 %), nên đổi hộp K thành 7-16 (map_u2x, map_x2u) và chạy lại. Lần 2 xong 04:45 (3 chuỗi surrogateopt 250 + patternsearch 60): chuỗi 1 K 11.23, z 61.4, p/z 14.3, z1 35.5, p1/z1 0.317, R 6.72 %, S 0.386, TV 93.5, J 2.593, e_rel 4.999 %, PM 30.02, GM 6.68; chuỗi 2 K 12.30 J 2.689; chuỗi 3 K 12.38 J 2.661. Cả ba nằm sát hai cổng (e_rel 5 %, PM 30). Thiết kế Map cũ (K 6) trên CALIB v2: R 14.45 %, S 0.418, e_rel 45 %. map_o6 (select_map_multiseed) DỪNG: 20 thiết kế tốt nhất có J trung bình seed 1-5 từ 2.595, nhưng e_rel lớn nhất ở seed 1-5 là 5.6-5.8 % (> 5 %), không thiết kế nào qua cổng tại mọi seed chọn. Nguyên nhân: tìm ở seed 0 với ràng buộc e_rel <= 5 % nên nghiệm nằm đúng mép, nhiễu seed khác cộng thêm khoảng 0.7 %. CHƯA đổi gì; chờ người dùng chọn (đề xuất: ràng buộc lúc tìm e_rel <= 4 % để có dự trữ, cổng chọn vẫn 5 % ở mọi seed). DREWS chưa chạy.

### Lượt 429 (2026-10-18 17:30) - Chạy lại Map từ đầu theo PhuongPhap_TimThamSo.txt mục 13.2 (e_max 10 %, chỉ surrogateopt)
Người dùng bảo đọc tài liệu thiết kế tham số và chạy lại toàn bộ theo hướng dẫn cho bộ Map, nhớ guard RAM. Đọc xong PhuongPhap_TimThamSo.txt (13.0, 13.2). Kết quả lần e_max 5 % (Lượt 428: ba chuỗi J 2.593/2.689/2.661, bước chọn trượt cổng 5 % ở seed 1-5) KHÔNG dùng nữa. LÀM (bước A): sao lưu ra Desktop/Adaptive-EPS_backup_2026-10-18_Map_emax5 (Calib_v2, ckpt, map.json, Cases seed 9999x, scratch_jobs) rồi xóa Map_CALIB_* ở Calib_v2, checkpoint ở D:/MatlabTemp/map_ckpt, file map_* ở scratch/jobs, DREWS Map seed 99995-99999 cũ (bản v1). (Bước B) sửa: map_opt_eval erelMax 10, optimize_map eMax 10 (ràng buộc c4), select_map_multiseed erelMax 10 và pool chỉ file opt, cận dưới K 7 thành 5 (map_u2x, map_x2u), map_opt_pipeline.sh bỏ refine_map, DREWS bằng run_scoring_seeds('Map', 99995:99999). Giữ nguyên CALIB v2, J = R*S, PM 30, GM 2, lag 0.707, ba chuỗi x 250 lần, nhóm top 20 với delta 0.02. Guard RAM (tools/jobs/guard_ram.ps1) đang chạy sẵn (ram_log.csv cập nhật mỗi 20 s) cùng job_lib_patient.sh (chờ 6 GB). Lúc bắt đầu không có việc PID hay MapPID đang chạy, nên khởi động Map ngay theo lệnh người dùng (tài liệu muốn PID trước, rồi Map). Bắt đầu 17:30. Chưa commit.

### Lượt 430 (2026-10-19) - Nhận khung Map, đọc đầy đủ lịch sử và quy chuẩn liên quan
Người dùng giao khung này đảm nhiệm phần Map và yêu cầu đọc lịch sử Map, `CLAUDE.md` và các file tracking liên quan. ĐÃ ĐỌC: `CLAUDE.md`, `Tracking/CLAUDE.md`, toàn bộ `Tracking/historychat_map.md`, lượt mới nhất của Linear (Lượt 163) và SMC (Lượt 24), `Tracking/historychat_testcase.md` (Lượt 10--11), `Documents/Shared/QuyChuan.txt` và `Documents/Shared/PhuongPhap_TimThamSo.txt` mục 13. Không chạy MATLAB, không dừng/đổi job nền, không sửa mã hay kết quả. Nắm quy trình hiện hành của Map: CALIB v2, e_max 10 %, ba chuỗi surrogateopt 250 lần, chọn năm seed và DREWS năm seed; không dùng các số CALIB v1 hoặc lần e_max 5 % để kết luận.

### Lượt 431 (2026-10-19) - Bắt đầu phần Map theo mục 13 mới: quét lưới + Pareto
Người dùng bảo đọc `Documents/Shared/PhuongPhap_TimThamSo.txt` mục 13 và làm phần của bộ Map. ĐỌC LẠI và phát hiện mục 13 đã được COMMON viết lại ở Lượt 168 ngày 2026-10-19, thay hoàn toàn kế hoạch `surrogateopt`: Map phải quét lưới đủ 5 biến, lưới thô 4^5 = 1024 điểm, lưới mịn tối đa 243 điểm mỗi lưới, chọn trên Pareto theo J và chấm DREWS năm seed. Kiểm tra hiện trạng: lần `surrogateopt` e_max 10 % đã bị COMMON dừng an toàn; còn ba csv và checkpoint chạy tiếp được nhưng mục 13 mới cấm dùng; `map_opt_eval.m` đã có PM >= 30, GM >= 2, lag gain >= 0.707 và e_max 10 %; `map_u2x.m`/`map_x2u.m` đã dùng K = 5--16. CHƯA dọn hay chạy Map vì hai điều kiện bắt buộc chưa có: PID chưa chọn xong theo lưới mới, và ba công cụ chung `Model/common/grid_search.m`, `Model/common/select_pareto.m`, `tools/jobs/grid_pipeline.sh` do khung Linear chịu trách nhiệm ở mục 13.1 hiện chưa tồn tại. Không viết bản riêng để tránh lệch chuẩn; đang chờ đúng hai điều kiện này rồi sẽ sao lưu/dọn theo 13.2 và chạy 1024 điểm thô bằng tối đa ba MATLAB. ĐÃ NÉN NHẬT KÝ: sao lưu `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-19_historychat_map/historychat_map_truoc_nen6.md`, gộp Lượt 416-426 vào BẢN NÉN và giữ nguyên văn Lượt 427-431.

### Lượt 432 (2026-10-19) - Đính chính thứ tự quét Map và PID
Người dùng hỏi vì sao phải chờ Linear hoàn thành và có chạy song song được không. Đính chính: Map không cần thiết kế PID để quét hoặc chọn; điều kiện phụ thuộc PID rồi Map trong mục 13.0 chỉ cần giữ cho MapPID (MapPID lấy hai thiết kế đã chọn làm hai điểm xuất phát) và để quản lý RAM. Map và PID được chạy song song sau khi `grid_search.m`, `select_pareto.m`, `grid_pipeline.sh` có mặt, miễn tổng số MATLAB không quá ba; có thể chia worker giữa hai bộ thay vì mỗi pipeline tự mở ba tiến trình. Lý do chưa chạy hiện tại chỉ là hạ tầng dùng chung chưa tồn tại, không phải chờ kết quả PID.

### Lượt 433 (2026-10-19) - Nhận hạ tầng chung, chuẩn bị chạy lưới Map
Người dùng xác nhận khung Linear đã tạo xong hạ tầng. KIỂM: `Model/common/grid_search.m` và `select_pareto.m` đã có; Linear đang chạy lưới PID với ba MATLAB (worker 1--3), nên không mở thêm MATLAB cho Map. LÀM PHẦN MAP KHÔNG TỐN MATLAB: thêm `map_grid_spec.m` (năm biến K, z, p/z, z1, p1/z1; K 5--16; seed tìm 0, seed báo cáo 1--5; PM 30, GM 2, e_max 10), `run_map_grid.m`, `select_map_pareto.m`, và `tools/jobs/map_grid_pipeline.sh` (kiểm một thiết kế biết trước, ba worker lưới 1024 điểm thô, Pareto + calib_margin + báo cáo năm seed, DREWS 99995--99999). Chưa sao lưu/dọn hoặc chạy Map để không làm mất kết quả surrogateopt trước khi có slot và không vượt giới hạn ba MATLAB. Kiểm tra cú pháp bash bằng lệnh `bash -n` không thực hiện được từ PowerShell vì bash không nằm trên PATH của shell hiện tại; chưa chạy MATLAB kiểm cú pháp vì ba slot đang được PID dùng.

### Lượt 434 (2026-10-19) - PID dừng ở chọn; Map dọn surrogateopt và bắt đầu lưới thô
Người dùng hỏi tiến độ. KIỂM: PID hoàn tất ba worker với 561 điểm khác nhau (w1/w2/w3 = 185/175/201) nhưng pipeline dừng 02:35 ở `select_pareto`: mọi ứng viên gọi `calib_margin` đều báo setting `Model_PID/.../Motor_lag/Numerator` không hợp lệ, nên không có điểm qua cổng mô phỏng; đây là lỗi Linear, không sửa ở khung Map. Ba slot MATLAB được nhả. LÀM MAP theo mục 13.2: sao lưu 3 csv `Map_CALIB_opt1..3_s00000.csv`, 3 checkpoint ở D:/MatlabTemp/map_ckpt, map.json và marker cũ ra `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-19_Map_surrogateopt/`; sau khi kiểm bản sao, xóa đúng 9 file nguồn để không nối surrogateopt cũ. Khởi động `map_grid_pipeline.sh`: hai lần Start-Process đầu dùng sai đường dẫn Git Bash nên thoát trước status; kiểm trace xác định đường dẫn /c/... đúng, bước kiểm sau đó PASS (PM 45.292), worker 1 vào lưới Map thô 1024 điểm lúc 09:46; worker 2/3 sẽ mở lệch 150 s. Không có kết quả lưới để chọn ở thời điểm ghi.

### Lượt 435 (2026-10-19) - Tiến độ lưới thô Map
Người dùng hỏi tiến độ. KIỂM lúc 10:42: pipeline Map ở stage 1; worker 1 chạy từ 09:46, worker 2 được tự chạy lại lần 3 và đang chạy từ 10:19, worker 3 chờ RAM vì khoảng trống 3 GB thấp hơn ngưỡng 6 GB. Hai CSV hiện có 975 dòng, tương ứng 595 thiết kế khác nhau sau loại dòng trùng; 29 thiết kế đã mô phỏng CALIB và 8 qua c1-c4. Lưới thô chưa hoàn tất nên chưa tính tâm/lưới mịn, chưa có Pareto hay thiết kế chọn. Log chỉ có cảnh báo quen thuộc Delay_ctrl = 0 có thể tạo algebraic loop; không có MATLAB error hay worker failed của Map.

### Lượt 436 (2026-10-19) - Lưới thô Map gần hoàn tất
Người dùng hỏi tiến độ. KIỂM lúc 11:14: 1626 dòng CSV, tương ứng 1021/1024 thiết kế thô khác nhau; 60 thiết kế đã qua sàng lọc tuyến tính để mô phỏng CALIB, 14 qua đủ bốn cổng. Worker 1 vẫn chạy/chờ đồng bộ, worker 3 chạy từ 11:10 để tiếp tục phần chưa có; worker 2 lần thử 5 bị dừng do thiếu RAM và job patient đang chờ 600 s trước khi tự khởi động lại. Chưa có worker Map nào failed, nhưng thiếu ba điểm nên chưa thể khép lưới thô, tính tâm hoặc sang lưới mịn.

### Lượt 437 (2026-10-19) - Watchdog bền vững cho Map Grid
Người dùng yêu cầu MATLAB phải tiếp tục chạy tới khi xong, tự phục hồi lỗi và ghi lịch sử. ĐÃ THÊM `tools/jobs/watch_map_grid.ps1`: kiểm tra mỗi 30 s, ghi trạng thái/sự kiện tại `scratch/jobs/map_grid_watchdog_status.txt` và `map_grid_watchdog_events.txt`, thoát sạch khi có marker hoàn tất, chỉ khởi động lại pipeline sau 8 phút không có MATLAB worker lớn và không có pipeline lock. Không xoá CSV/checkpoint nên lần chạy lại tái sử dụng phần đã làm. `map_grid_pipeline.sh` được thêm lock vòng đời `map_grid_pipeline_running.txt`; watchdog tuyệt đối không kill MATLAB để không ảnh hưởng khung khác. Lỗi heap `0xc0000374` vẫn được `job_lib_patient.sh` tự retry/backoff. Lúc triển khai vẫn có MATLAB Map đang chạy nên watchdog không chạy chồng.

### Lượt 438 (2026-10-19 19:24) - Phát hiện và tự phục hồi MATLAB Map treo
KIỂM CPU delta 15 s của ba MATLAB Map đối chiếu với worker w1/w2/w3: 0--0.031 s, trong khi CSV/log không đổi từ 12:26; xác nhận treo, không phải đang mô phỏng dài. Đã dừng chính xác ba PID Map 30176, 44500, 89992 (không đụng MATLAB khác). `job_lib_patient.sh` nhận đây là interrupted, giữ nguyên CSV/checkpoint và chuyển cả ba worker sang chờ 60 s rồi retry tự động. Đây là can thiệp phục hồi lần đầu của watchdog; cần kiểm tra MATLAB mới chạy sau backoff.

### Lượt 439 (2026-10-19 19:27) - Không chạy DREWS Map cũ
Người dùng xác nhận đang thiết kế bộ DREWS mới và không cần DREWS cũ. KIỂM: lưới Map vẫn stage 1, chưa có Pareto/chọn năm seed; không có log MATLAB scoring hay kết quả DREWS. Pipeline đã thay stage 3 bằng `legacy Map DREWS skipped`, tạo marker `map_grid_score_done.txt` với nội dung skip; sau khi lưới và chọn hoàn tất, pipeline chỉ kết thúc, không gọi `run_scoring_seeds('Map',99995:99999)`. Không thay đổi bất kỳ file nào của bộ DREWS mới.

### Lượt 440 (2026-10-19 19:38) - Ước lượng thời gian Map Grid còn lại
Sau phục hồi, CSV có 2,199 dòng và khoảng 456 thiết kế Map khác nhau đã cache; lưới thô còn xấp xỉ 568/1,024 điểm. Hai worker đang mô phỏng, worker 1 vừa retry sau heap corruption. Với tốc độ mới đo và phần còn lại gồm lưới thô, tối đa sáu lớp mịn và chọn năm seed (DREWS cũ đã bỏ), ước lượng thực tế khoảng 5--8 giờ, tức khoảng 00:40--03:40 ngày 2026-10-20 nếu không thêm crash/RAM wait. Đây là dải dự báo, không phải mốc chắc chắn vì chi phí CALIB và retry heap biến thiên.

### Lượt 441 (2026-10-19 21:19) - Tiến độ Map Grid
KIỂM: pipeline vẫn stage 1, 2,788 dòng CSV tương ứng 690 thiết kế Map khác nhau đã cache, tăng 234 thiết kế so với 19:38 và xấp xỉ 67% lưới thô 1,024 điểm. Worker 2 và 3 đang chạy; worker 1 retry lần 7 đang chờ headroom RAM 6 GB (hiện 3 GB), không phải failed. Chưa có worker grid hay chọn Pareto hoàn tất; DREWS cũ vẫn bị bỏ qua theo Lượt 439.

### Lượt 442 (2026-10-19 21:53) - Tăng Map từ ba lên năm worker
Người dùng xác nhận chỉ còn khung Map chạy và muốn tận dụng RAM tối đa với buffer nhỏ. Đo từ guard: RAM trống 9.9 GB, ba MATLAB dùng working set khoảng 2.6 GB, máy có 24 logical processors. Đã chuyển pipeline từ 3 lên 5 worker, giảm thời gian khởi động lệch từ 150 s xuống 60 s, hạ ngưỡng `job_lib_patient` từ 6 xuống 4 GB và guard từ 3 xuống 2 GB. Dừng đúng cây pipeline Map cũ PID 110188 cùng guard cũ PID 103312, sau đó mở lại cả hai; không xoá CSV/checkpoint nên cache 690 thiết kế được giữ nguyên và phân chia lại phần chưa làm theo năm worker. Lúc 21:58 đủ w1--w5 đều `running`; lúc 21:58:44 năm MATLAB dùng 10.16 GB và còn 4.29 GB RAM trống, cao hơn guard 2 GB; watchdog báo HEALTHY.

### Lượt 443 (2026-10-19 22:14) - Kiểm tra các khung đang chạy/dừng
KIỂM: Map grid pipeline vẫn hoạt động với 5 worker; w2 và w5 đang chạy MATLAB, w1/w3/w4 đang chờ headroom 2--3 GB để tự vào lại, không có marker `map_grid_*_failed.txt`. PID grid đã `ALL DONE` lúc 10:59, gồm cả chọn và scoring theo pipeline PID. MapPID supervisor vẫn sống nhưng báo `PID_pick=ready, Map_pick=pending`, tức đang chờ Map là đúng phụ thuộc, không phải crash. `failed_init_pid_grid_select_failed.txt` là marker lỗi cũ của lần khởi tạo PID, còn pipeline PID cuối đã hoàn tất; trạng thái MapOpt `map_o4_1` ngày 18/10 là log cũ, không có tiến trình `map_opt` hiện tại và không thuộc phương pháp grid mới. Watchdog Map vẫn HEALTHY.

### Lượt 444 (2026-10-19 22:46--23:09) - Sửa chọn Map: workspace, crash và retry bền vững
Theo yêu cầu người dùng, `mapMargin` nay nạp `load_map.m` vào base workspace bằng `evalin('base', 'run(load_map_path)')` một lần mỗi phiên MATLAB, trước `calib_margin`; lỗi `Actuator/Motor_lag/Numerator` đã hết. Dừng riêng select MATLAB cũ đang lặp lỗi, rồi chạy lại stage 2; cả năm worker grid đã DONE nên restart chọn không chạy lại lưới. Phát hiện một ứng viên làm MATLAB R2023a crash (`0xffffffff`) khi margin; thêm `Timeout=90` s ở `calib_run.m` và cơ chế Common `margin_inflight`: nếu MATLAB chết giữa một margin, retry ghi chính xác điểm đó vào `Map_CALIB_margin_failures_s00000.csv` và bỏ qua nó, không lặp vô hạn. Lúc 23:05 selection retry mới chạy đúng, đã skip điểm crash và các failure cache; rank 1--5 đều chạy `calib_margin` thật nhưng bị loại vì gain-margin 3.59--3.60 > 2.00. Chưa được tạo `Map_CALIB_pick_s00000.csv` hay ghi `map.json` mới vì chưa có ứng viên nào qua gate thực; selector vẫn đang tiếp tục các rank còn lại, không có lỗi workspace/crash-loop.
### Lượt 445 (2026-10-20 00:21) - Trạng thái selector Map
Kiểm tra mới nhất: Map grid đã hoàn tất; selector Pareto vẫn đang chạy trong MATLAB (try=1, watchdog HEALTHY, log cập nhật lúc 00:21). Log đã tới khoảng J-rank 64; các ứng viên hiện tại bị loại bởi `calib_margin` do gain-margin khoảng 3.59--3.61 vượt gate 2.00, không phải selector bị dừng. Chưa có `Map_CALIB_pick_s00000.csv`, marker done/failed, hoặc `map.json` mới; `Model/data/map.json` hiện vẫn là bản cũ. DREWS Map cũ không chạy theo yêu cầu.

### Lượt 446 (2026-10-20) - Tự push Map và laptop tự tiếp tục S2 qua đêm
Người dùng ủy quyền triển khai và push cơ chế tự bàn giao sau khi Map xong; laptop hiện chạy S1. Đã tạo ba script PowerShell: common kiểm Git/byte/hash/pick-json, publisher chờ Map pipeline DONE rồi kiểm cổng margin và năm file bàn giao, consumer chờ S1 nhả khóa và có summary/done rồi fetch nhánh riêng, giữ S1, nhận đúng Map và chạy S2 rồi Select. Publisher dùng index riêng/commit-tree nên không kéo các sửa bài báo hay index người dùng vào commit dữ liệu; không đổi HEAD khi tự publish. Consumer không merge toàn repo có kết quả S1, chỉ nhập payload đã xác minh, kiểm mã MATLAB không lệch, lưu commit nguồn và bản trước thay; có khóa chặn trùng, retry mạng, kiểm S1 summary không đổi, kiểm MapPID pick/JSON trước all.done. Đã cập nhật MAPPID_LAPTOP.md. Kiểm thử hai repo Git giả cục bộ PASS: push/fetch, giữ nguyên S1, thứ tự S2→Select, PNG không hỏng byte, all.done; không chạy MATLAB giả làm bằng chứng khoa học. Test tìm thấy và đã sửa giới hạn đường dẫn Windows. Muốn tự tiếp tục laptop phải bật watcher một lần; desktop không có quyền truy cập từ xa vào máy đó. Chưa thể đảm bảo xong sáng vì Map vẫn chưa qua chọn và thời gian S1/S2 phụ thuộc mô phỏng.

### Lượt 447 (2026-10-20) - Chính sách RAM PC Map
Người dùng yêu cầu dùng 90--95 % RAM, chừa khoảng 10 % buffer, chỉ PC này. Đo quyền hệ thống: máy có 31.86 GB, dùng 22.42 GB (70.4 %), còn 9.44 GB; MATLAB selector Map chỉ private 2.01 GB nhưng dùng 10.53 CPU-giây trong 10 giây và log tiến từ J-rank 108 lên 122. Nút thắt hiện tại là `select_pareto` kiểm `calib_margin` tuần tự để giữ thứ tự Pareto, không phải guard RAM; không chạy selector song song vì có thể sai thứ tự chọn/ghi chung cache. Guard đã kill ở 2 GB trống, cho phép dùng tới 93.7 % RAM. Đã đặt riêng `PATIENT_START_GB=2` trong `map_grid_pipeline.sh`, để các retry/launch Map PC được phép bắt đầu với cùng reserve 2 GB (6.3 %); laptop runner không bị đổi và vẫn giữ 6 GB. Không ép MATLAB cấp phát RAM vô ích vì không làm selector nhanh hơn và tăng rủi ro heap crash.
### Lượt 448 (2026-10-20 02:05) - Tiến độ chọn Map
Kiểm mới nhất: stage 2 selector Map vẫn chạy, watchdog báo HEALTHY với một MATLAB worker và pipeline lock còn hiệu lực; publisher tự bàn giao báo WAIT_MAP. Log đã tới J-rank 210; ứng viên mới vẫn bị `calib_margin` loại vì gain ratio khoảng 3.60 vượt ngưỡng 2.00. Chưa có Map pick, marker done/failed hay `map.json` mới. MATLAB đang tiếp tục mô phỏng, không treo và không có crash marker.


### Watchdog Map (2026-10-20 03:25:09)
Watchdog detected map_grid_select_failed.txt; it will restart the Map pipeline after the idle guard and preserve completed work.


### Watchdog Map (2026-10-20 03:33:09)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 03:41:40)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 03:50:10)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 03:58:40)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:07:11)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:15:41)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:24:11)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:32:42)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:41:12)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:49:42)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 04:58:13)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:06:43)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:15:13)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:23:44)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:32:14)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:40:44)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:49:15)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 05:57:45)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:06:15)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:14:46)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:23:16)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:31:46)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:40:17)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:48:47)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 06:57:17)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:05:48)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:14:18)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:22:48)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:31:19)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:39:49)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:48:19)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 07:56:50)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:05:20)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:13:50)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:22:21)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:30:51)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:39:21)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:47:52)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 08:56:22)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 09:04:52)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 09:13:23)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 09:21:53)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 09:30:23)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.
### Lượt 449 (2026-10-20 03:24) - Selector Map song song hoàn tất nhưng không có điểm qua margin
Theo yêu cầu tăng tốc bằng RAM PC, đã tạo pool `calib_margin` độc lập, ban đầu ba rồi sáu worker; pool chạy được, worker dùng calibration override chỉ đọc để không ghi đè `map.json`. Phiên song song đi tới J-rank 467 và selector đã duyệt hết pool khả thi. Kết quả dừng có chủ ý với `select_pareto:noMargin`: không có thiết kế nào qua `calib_margin`; các điểm cuối gain ratio 3.001--3.136, vẫn cao hơn gate 2.00. `map_grid_select_failed.txt` được tạo lúc 03:24; không có pick hay JSON mới. Đây không phải thiếu RAM, treo, lỗi JSON hay lỗi pool; tăng song song chỉ rút thời gian kiểm, không thay đổi cổng/chọn. Watchdog đang idle và sẽ chỉ restart pipeline sau grace period, nhưng cùng dữ liệu sẽ lặp lại `noMargin`; cần chẩn đoán/phương án Map thay vì retry mù.
### Lượt 450 (2026-10-20) - Vì sao Map cũ có điểm chọn nhưng grid mới không có
Đối chiếu dữ liệu và lịch sử, không chạy lại mô phỏng: thiết kế đang lưu trong map.json là CALIB v1 ngày 2026-10-11, K=6, R=27.05394 %, e_rel=3.16677 %, margin gain=0.78119 và delay=1.00045. Khi tiếp nhận CALIB v2, Lượt 427-428 đã đo cùng thiết kế K=6 có R=14.45 %, e_rel khoảng 45 %, nên không còn qua chính xác. V2 dùng 140 s, 26 cửa sổ static và R trung bình nhân ba nhóm static/dyn/mu; vì calib_margin lấy R_gain/R_nom, đổi cách đo R cũng đổi phép kiểm dù ngưỡng 2 giữ nguyên. Bản surrogateopt v2 trước grid cũng chưa có lựa chọn hoàn tất: lần e_max 5 % dừng ở kiểm seed, lần e_max 10 % bị dừng khi đổi phương pháp. Cache hiện có 467 dòng ratio_gain hữu hạn, nhỏ nhất 3.001274; còn một dòng Inf/Inf chưa phân biệt được lỗi kỹ thuật với bất ổn. Vì vậy chỉ kết luận pool grid hiện tại chưa cho điểm được selector chấp nhận; chưa chứng minh Map không có nghiệm hoặc mọi rejection đều là vật lý. Lượt 449 đã kết luận loại trừ lỗi kỹ thuật quá chắc; cần tái lập cùng thiết kế và kiểm cache trước kết luận bản chất bộ Map.

### Lượt 451 (2026-10-20) - Phân tích nguyên nhân và hướng tháo phụ thuộc MapPID
Người dùng yêu cầu phân tích và đề xuất, chưa triển khai thay quy chuẩn/tìm lại. Đọc trực tiếp grid và cache: có 467 thiết kế đạt c1-c4; K=8.118--16, R danh định=6.531--7.891 %, e_rel=4.494--7.267 %, nên điểm mới không bị loại vì chính xác >10 %; thất bại là ratio_gain nhỏ nhất 3.001274. Điểm J tốt nhất: K=8.94427, z=107.7217, p/z=15.4949, z1=11.2228, p1/z1=0.603128, R=6.770565 %, S=0.4228494, e_rel=5.342145 %, J=2.862929. map_table dùng giới hạn độ dốc K; lead/lag có DC=1, nên hạn chế bám tĩnh do bảng/K/vùng chết không được xóa bằng đổi bù; cửa sổ static hữu hạn vẫn có thể chứa quá độ. calib_margin ratio đánh giá suy giảm bám chứ chưa tách sai lệch tĩnh khỏi dao động/mất ổn định. grid_search chọn tâm theo J danh định, chưa dùng margin nên không bảo đảm lấy mẫu đủ vùng robust. Đề xuất tái lập vài điểm cùng seed bằng phiên sạch, kiểm R từng nhóm và dạng tín hiệu, sau đó tìm lưới bổ sung có margin trong điều kiện chọn tâm nếu cần (đổi quy trình phải ghi nhận). Để tháo S2 nếu Map riêng không có nghiệm được xác minh: có thể đề xuất dùng Map danh định đạt c1-c4 làm điểm khởi tạo, công khai Map standalone chưa qua margin, bắt MapPID cuối qua toàn bộ cổng; đây là sửa điều kiện S2 mục 13.5 nên cần người dùng chốt, không tạo pick hay map.json cuối giả. Không thay mã/seed/cổng hay chạy lại MATLAB trong lượt phân tích.


### Watchdog Map (2026-10-20 09:38:54)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.


### Watchdog Map (2026-10-20 09:47:24)
Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained.

### Bàn giao theo yêu cầu người dùng (2026-10-21) - Đợt Map2 phủ rộng do khung Map thực hiện

Người dùng yêu cầu khung Map tiếp nhận kế hoạch tại
`Documents/Notes/Controllers/KeHoach_Map2_Dense.md`: đọc toàn bộ rồi triển khai
và chạy trong phạm vi Map khi nhận prompt bàn giao. Lưới306 cặp (17x17 + hàngK6)
và một baseline cực/zero Map cũ riêng, đánh giá nominal + cả hai stress kể cả
điểm trượt e_rel, báo sáu mức vi phạm, chọn khả thi hoặc ghi ứng viên thoả hiệp
minimax minh bạch. Giữ cổng, PRSM, CALIB và seed; RAM mục tiêu80–90%, reserve10%,
retry/cache/lock theo kế hoạch. Không chạy MapPID hay DREWS. Bản ghi bàn giao này
được thêm theo chỉ đạo trực tiếp, không phải kết quả chạy mới của khung Map.
Khung Map tự ghi Lượt kế tiếp/trạng thái khi tiếp nhận; tại lúc bàn giao chưa
khởi động đợt dense. Map bài báo K6 vừa kiểm lại seed0/1 đều qua margin nhưng
e_rel45.06/45.45% trượt10%; chi tiết nguồn trong kế hoạch và MapPID Lượt56.

### Lượt 455 (2026-10-21) - Khởi chạy Map2 Dense và kiểm soát phục hồi

Đã đọc toàn bộ `KeHoach_Map2_Dense.md`, lịch sử Map và quy ước; chỉ chạy Map2 `(K,g_min)`, không chạy MapPID/DREWS và không ghi `map.json`. Manifest cố định gồm 306 điểm Map2 cộng baseline legacy đã được tạo tại `Result/Controllers/Map/Calib_v2/TwoParamDense`. Preflight điểm K=5, g_min=0.707106781187 hoàn tất đủ nominal seed0, nominal/gain x2/delay +1 ms seed1; checkpoint chứng minh đường chạy stress vẫn chạy sau khi e_rel trượt. Full run đang có năm MATLAB worker độc lập, mỗi worker ghi CSV riêng sau từng điểm hoàn chỉnh. Lỗi quote launcher ban đầu làm MATLAB thoát ngay đã được sửa trước khi có dữ liệu lưới; một worker sau đó mất process và supervisor đã khởi động lại đúng worker, không xóa cache. Cảnh báo algebraic loop khi delay=0 là cảnh báo Simulink đã biết, không phải rejection. RAM thực tế đang dùng khoảng 70 %, còn gần 30 % trống; không tạo tải giả chỉ để ép lên 90 % vì sẽ giảm độ ổn định. Đã mở rộng finalizer để xuất bảng synthesis/nominal/stress/constraints/Pareto/JSON/MAT, báo cáo Markdown và đo độc lập seed1--5 cho điểm chọn cùng tối đa bốn đại diện; mọi output vẫn chờ lưới hoàn tất mới được kết luận. `map.json` giữ nguyên.

### Lượt 456 (2026-10-21) - Sửa checkpoint schema khi worker Map2 resume

Trong khi giám sát Map2 Dense, worker 3 hoàn tất được điểm thứ nhất rồi dừng ở hàng kế tiếp với `tabular/vertcat`: CSV resume do `readtable` tạo `key` kiểu `string` và cờ kiểu `double`, còn `struct2table` của phép đo mới tạo `char`/`logical`. Đây là lỗi checkpoint/schema, không phải rejection hay lỗi mô phỏng; điểm đã xong vẫn giữ trong `Map2_Dense_measurements_w3.csv`. Đã sửa `run_map2_dense.m` để chuẩn hóa `key` và năm cờ trước mỗi lần nối bảng, ghi bằng chứng vào `Map2_Dense_execution_errors.csv`; retry kế tiếp sẽ đọc code mới và tiếp tục cùng phân vùng/cache. Không đổi gate, lưới, MapPID, DREWS hay `map.json`.

### Lượt 457 (2026-10-21) - Thay supervisor Map2 bị mất bằng kiểm chứng manifest toàn cục

Sau khi worker 3 resume thành công và checkpoint lên 17/307, kiểm tra process cho thấy supervisor gốc không còn sống dù bốn MATLAB vẫn tính và heartbeat guardian/postflight guardian còn sống. Vì supervisor cũ dùng handle process không phản ánh đúng child MATLAB, nếu để nguyên nó sẽ không gọi finalizer khi lưới xong. Đã thêm và chạy `tools/jobs/resume_map2_dense_supervisor.ps1`: không dừng/động vào MATLAB hiện có; mỗi 120 s đối chiếu toàn bộ key trong CSV với `Map2_Dense_manifest.csv`, ghi `verified/missing` vào status, và chỉ gọi finalizer khi đủ chính xác 307 key duy nhất. Trạng thái đầu: verified=17/307, missing=290. Guardian heartbeat hiện có vẫn phụ trách hồi phục worker stale; postflight vẫn xác minh output sau COMPLETE. Không đổi gate, dữ liệu, MapPID/DREWS/map.json.

### Lượt 458 (2026-10-21) - Phục hồi song song 54 key Map2 Dense còn thiếu

Lúc 10:45 kiểm chứng manifest cho thấy 253/307 key: w1=62, w3=61, w4=61, w5=61 đã xong, w2 chỉ 8/62 nên còn thiếu đúng 54 key. Hai recovery w2 trước đó dừng native ở lần thứ ba, guardian ghi `UNRESOLVED` theo giới hạn retry; không có bằng chứng rejection vật lý. Sau audit khi không còn MATLAB lưới khác, đã dừng chỉ các guardian cũ (không có worker sống), tạo `Map2_Dense_resume_manifest.csv` 54 key còn thiếu, mở rộng runner nhận manifest/output tag riêng, và chạy `watch_map2_dense_resume.ps1` với 5 lô rời 11/11/11/11/10 key. Mỗi lô checkpoint riêng `measurements_resume_w*.csv`; finalizer và supervisor manifest nay đọc cả checkpoint cũ + resume, chỉ chốt khi đủ 307 key duy nhất. Năm MATLAB mới đã khởi động đồng thời lúc 10:48. Không đổi lưới/gate/MapPID/DREWS/map.json.

### Lượt 452 (2026-10-20) - Chẩn đoán vùng vận hành 80 % trước khi đổi Map
Theo quyết định người dùng: giữ nguyên lưới/cache stress, không tăng K chỉ để cứu vùng biên. Đã tạm dừng watchdog Map PID 110340 vì nó restart selector noMargin mỗi 8 phút và có thể cạnh tranh CSV; không xóa dữ liệu. Thêm `analyze_map_operating_windows.m`, chỉ đọc thiết kế/cache và mô phỏng bốn ứng viên đại diện (low K 8.118, điểm J danh định K 8.944, điểm K9 finite-stress và minimum cached gain ratio K16) ở nominal/gain x2; không ghi map.json/pick hay đổi gate. Báo cáo chi tiết `Map_CALIB_window_diagnosis_s00000.csv` và tổng hợp cùng tên `_summary_` tại Map/Calib_v2. Vùng normal80 được khai báo trước khi đọc số: đường khô, 30--90 km/h, không có bước mu; 54/68 cửa sổ = 79.4 %, còn v20, v100, mu là boundary/robustness. Kết quả: điểm J danh định vẫn tốt nhất khi cân bằng error/smoothness trong normal80 (RMS e 1.302 N.m, S 0.423 N.m; K9 giảm RMS xuống 1.225 nhưng S tăng 0.859; K16 RMS 1.180 nhưng S 1.012). Khi gain x2, lỗi nổi bật nằm ngay normal80: static v30 a=0.1 g over-assist khoảng -26.5 đến -27.0 %, trans v80--90 a=0.1 g khoảng +26 %, không phải EDGE. Gain làm R toàn CALIB từ 6.77 lên 24.39 % ở điểm J leader (x3.60); tăng K đến 16 chỉ giảm chút các lỗi này, đồng thời tăng S gần 2.4 lần. Boundary v20 trans vẫn rất lớn ~130--135 % danh định, nhưng không phải lý do để ép K cao. Kết luận: bằng chứng hiện có ủng hộ giữ gain thấp-trung bình và sửa cơ chế bám/robustness ở mô-men nhỏ, không tăng K. Chưa có Map standalone qua calib_margin nên chưa tạo pick/map.json và chưa mở MapPID S2; bước tiếp cần một biến thể Map có feedback/bù sai lệch nhỏ hoặc quyết định dùng Map J-leader chỉ làm khởi tạo minh bạch cho MapPID, nhưng không thay chuẩn chọn ngầm.

### Lượt 459 (2026-10-21) - Map hai biến (K, g_min) lưới 13 mức theo mục 14 PhuongPhap_TimThamSo: xong, thiết kế "an toàn, trượt e_rel"
Làm đúng mục 14 (thiết kế mù: không dùng CALIB v1, K 6, Map5 grid, TwoParam, TwoParamDense; chỉ cache tuyến tính Map_plants.mat là hàm của Plant). Sao lưu trước ở Desktop/Adaptive-EPS_backup_2026-10-21_Map_truoc_grid2 (Calib_v2, map.json, grid_search gốc). Code mới (Model/Controllers/Map/script): map2_u2x, map2_x2u, map2_eval, map2_grid_spec (centerFcn R1/R2/R3, marginFcn đọc csv), run_map2_grid (bắt R3), select_map2_pareto, report_map2_grid, test_map2_grid; tools/jobs/map2_grid_pipeline.sh (4 worker, guard_ram.ps1 bật, không DREWS). Sửa dùng chung tương thích ngược PID: grid_search.m (spec.coarseLevels, spec.centerFcn tùy chọn, mặc định như cũ); select_pareto.m (erelMax = Inf bỏ cổng c4; ruleText, designNote, keepTsCtrl tùy chọn; sửa lỗi khi điểm chọn nằm ngoài mặt Pareto vì dự phòng margin). Kiểm bộ đánh giá tại K 6.687, g_min 0.7071: R 12.4208, S 0.43645, e_rel 28.185, ratio_gain 1.868 (khớp kỳ vọng, ratio_delay 3.38 nên trượt margin). Lưới chạy 12:25-17:31: 186 cặp (169 thô + 17 mịn thêm), 55 tổng hợp hỏng (K >= 12.8), 0 trượt tuyến tính, 131 mô phỏng, 22 qua e_rel, 77 qua margin, 0 qua cả hai. Quy tắc tâm: R1 ở cả 5 lớp mịn (tâm cuối K 8.99, g_min 0.7071, J 3.13, h cuối 0.0104). LỖI VÀ CÁCH SỬA: (1) test lần đầu ghi csv sai đường dẫn scratch (fileparts hai lớp), sửa một lớp; (2) select_pareto lỗi `frontOrder == []` khi điểm chọn ngoài mặt Pareto, sửa một dòng; (3) select_pareto bỏ Ts_ctrl khỏi map.json làm load_map hỏng, thêm spec.keepTsCtrl cho Map, khôi phục map.json từ bản sao lưu rồi ghi lại; (4) PHÁT HIỆN: ba dòng seed 0 của worker 1 ở K 9.65 (g_min 0.707, 0.794, 0.891) bị hỏng (S 1.49, 1.02, 7.26 so với 0.469, 0.526, 0.624 khi chạy lại trong tiến trình mới; e_rel giống hệt; margin 3.13, 6.74, 0.243 "đạt" sai so với 3.63 trượt). Nguyên nhân chưa rõ (dòng chạy chậm 400-460 s ở lớp thô, không có dấu hiệu RAM). Đã thay đúng ba dòng bằng giá trị chạy lại (bản gốc scratch/Map_CALIB_grid2_w1_before_fix.csv), không đổi tập qua e_rel. Chưa kiểm lại 128 dòng mô phỏng còn lại; các cặp K 5.48 lân cận biến thiên trơn nên khó hỏng. (5) KHOẢNG TRỐNG CỦA KẾ HOẠCH: R1 (14.4) không xét margin nên tâm lưới mịn rơi vào vùng K 8-11 (e_rel 5 %) trong đó cả 22 cặp đều trượt calib_margin (gain x2: tỉ số 3.6 > 2), nên lưới mịn không làm mịn vùng an toàn (K 5.5-7.3, chỉ có lưới thô). Chọn (14.5) vì vậy rơi vào nhánh erelMax = Inf (đã diễn giải "qua đủ cổng" = e_rel VÀ margin): thiết kế chọn K 5.4772, g_min 0.7492, lead (z 37.03, p 591.22), lag (z1 25.53, p1 11.75); R 16.366 %, S 0.4161, J 6.8095, TV 97.7, e_rel 57.87 % (cửa sổ static_v30_apos0p30g, dấu dương = thiếu trợ lực), PM 45.30, GM 5.66, HF 40.2, ratio_gain 1.354, ratio_delay 1.000; năm seed 1-5: J 6.8129 +- 0.0104, e_rel lớn nhất 58.19 %; không ở cận hộp (K, g_min nằm trong). Nhãn "an toàn, trượt e_rel" trong map.json design.x_design_note. load_map và test_map PASS ([Map] TEST PASS). Báo cáo: Result/Controllers/Map/Calib_v2/Grid2/Map_CALIB_grid2_report_s00000.csv, Map_CALIB_grid2_safe_s00000.png, Map_CALIB_pareto_s00000.png. Không chạy DREWS, MapPID, PID; không sửa PRSM, CALIB, gate; chưa commit. Việc chờ người dùng: (a) quyết định có làm mịn vùng an toàn bằng tâm R2 (cổng an toàn + margin, J nhỏ nhất) cho khoảng K 5.5-7.3 không (đổi quy tắc tâm sau khi thấy dữ liệu, nên chưa tự làm); (b) có kiểm lại toàn bộ 131 dòng mô phỏng trong tiến trình mới không; (c) chưa nén nhật ký (lần nén cuối Lượt 431, đã quá hạn).

### Lượt 460 (2026-10-22) - Làm mịn lưới Map2 với tâm R2 (người dùng đồng ý) và hình đánh đổi e_rel / margin
Người dùng thấy e_rel 57.9 % quá lớn (bản K 6 cũ chỉ 45 % trên CALIB v2) nên đồng ý bước 1 và 2, bàn cổng sau. ĐỔI QUY TẮC SAU KHI THẤY DỮ LIỆU (ghi trung thực, 2026-10-21 23:12): tâm lưới mịn đổi từ R1 sang R2 (cổng an toàn c1-c3 và pass_margin, J nhỏ nhất) vì R1 không xét margin nên lớp mịn đầu bị đặt ở K 8-11, nơi cả 22 cặp qua e_rel đều trượt calib_margin; cổng KHÔNG đổi. Cài: map2_grid_spec(centreRule), run_map2_grid(id, n, 'R2'), tools/jobs/map2_refine_r2_pipeline.sh (dùng lại mọi dòng csv, 4 worker, cùng guard_ram). Sao lưu trước: Desktop/Adaptive-EPS_backup_2026-10-21_Map_truoc_grid2/map_after_first_select_R1.json và Grid2_after_first_select_R1. Chạy 23:12-00:35; guard dừng MATLAB 8 lần ở 23:20-23:41 (RAM các khung khác), worker tự chạy lại, không mất dòng. Tâm theo R2 đi dần lên: K 5.477/0.749 (J 6.81) -> 6.311/0.738 -> 6.311/0.727 -> 6.311/0.717 -> 6.311/0.707 (J 5.92) -> 6.775/0.707 (J 5.30); 6 lớp mịn, h cuối 0.0208. Tổng 204 cặp (169 thô + 35 mịn thêm), 55 tổng hợp hỏng, 0 trượt tuyến tính, 149 mô phỏng, 22 qua e_rel, 93 qua margin, 0 qua cả hai (nên chọn vẫn theo nhánh erelMax = Inf, nhãn "an toàn, trượt e_rel"). THIẾT KẾ CHỌN MỚI (ghi đè map.json, bản trước trong thư mục sao lưu): K 6.7746, g_min 0.7071 (ở cận dưới hộp g_min), lead z 33.50 p 673.27, lag z1 28.13 p1 10.69 (lead z và lag giống Map K 6 cũ, chỉ p và K khác); CALIB seed 0: R 12.053 %, S 0.4398, J 5.301, TV 123.1, e_rel 26.04 % (static_v30_apos0p30g, dấu dương = thiếu trợ lực), PM 45.49, GM 5.24, HF 51.7, ratio_gain 1.929 (sát ngưỡng 2), ratio_delay 1.000; năm seed 1-5: J 5.3137 +- 0.0129, e_rel lớn nhất 26.52 % (26.53 26.19 26.22 25.91 26.03). load_map và test_map PASS. So với lần chọn đầu (K 5.477: R 16.37, e_rel 57.9, J 6.81) tốt hơn mọi mặt. Báo cáo cập nhật: Result/Controllers/Map/Calib_v2/Grid2/Map_CALIB_grid2_report_s00000.csv (trường centre_rules_worker1 chỉ ghi các lớp đầu của lần chạy R1), Map_CALIB_grid2_safe_s00000.png, Map_CALIB_pareto_s00000.png; hình mới tools/make_fig_map2_tradeoff.py -> Map_CALIB_grid2_tradeoff_s00000.png (K theo e_rel và theo ratio_gain, 149 cặp): e_rel <= 10 % chỉ khi K >= khoảng 7.8 nhưng ratio_gain 2.3-4.2, cả hai không thỏa cùng lúc. Lưu ý: ba dòng hỏng của worker 1 đã sửa ở Lượt 459; 146 dòng còn lại chưa chạy lại độc lập. Không chạy DREWS, MapPID, PID; chưa commit. Việc chờ: bàn cổng margin (ratio_gain tính trên R tương đối, phạt thiết kế tốt danh định; đổi cổng phải áp cho PID, MapPID, báo COMMON).
