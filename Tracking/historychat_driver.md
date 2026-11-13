# History_Chat DRIVER - Nhật ký khung DRIVER (người lái theo lực tay, phương án C)

## CÁCH DÙNG (dành cho phiên Claude mới)
1. Đọc file này, `Tracking/CLAUDE.md` và `Documents/Shared/KeHoach_NguoiLai.txt` (kế hoạch tự đủ, tạo bởi khung VDB_TIRE ngày 2026-11-09).
2. Cấu trúc: (1) TRẠNG THÁI HIỆN TẠI; (2) BẢN NÉN (chưa có); (3) NHẬT KÝ NGUYÊN VĂN. Nén lần cuối: chưa. Sau mỗi 10 lượt tự nén (sao lưu ra Desktop trước).
3. Khung DRIVER không sửa file của khung VDB_TIRE (Model/VDB/, Documents/Shared/3D_modelling_plan.txt, Tracking/historychat_vdb_tire.md). Chỉ commit khi người dùng bảo, chỉ commit đúng file của mình, không dùng sync_repo.sh.

---

## 1. TRẠNG THÁI HIỆN TẠI (2026-11-10, Lượt 1)

- **Vai:** khung DRIVER. Người dùng cho phép chạy một mạch D1-D7 trong đêm, không chờ duyệt từng bước; nộp hình và bảng số ở cuối.
- **D0 (ĐÃ CHỐT 2026-11-09, chép nguyên từ KeHoach_NguoiLai.txt, không đổi sau khi thấy kết quả):**
  - (a) Bộ tham số tay chính: H thả lỏng (J_h 0.130, C_h 0.35, K_h 4.17).
  - (b) Thư mục: `Model/original/PRSM/Driver/` và `Result/PRSM/Driver/`.
  - (c) Bộ cảnh: ba cảnh SSW là SLIP 'stair', SLIP 'pud', WEAVE 'lane'; 'stair' giữ nguyên không tách.
  - (d) Tiêu chí so thứ bậc giữa hai kiểu người lái (D7), so riêng từng cảnh, không gộp. Người lái cứng: RMS e_T trên cả ca ngắn. Người lái lực: Delta_y = khoảng cách ngang lớn nhất giữa quỹ đạo bản mu như ca gốc và quỹ đạo bản đối chứng mu 0.8 của cùng bộ. "Cùng chiều" khi hiệu Map - MapPID của hai đại lượng cùng dấu; "hòa" khi |A - B| / max(A, B) < 5 % ở ít nhất một đại lượng; còn lại "ngược chiều".
  - (e) Dãy độ cứng tay cho D6 (J_h, C_h, K_h): W (0.044, 0.25, 0; Lee 2018), H thả lỏng (0.130, 0.35, 4.17; Pick và Cole), H gồng (0.130, 1.08, 78.63). Không thêm điểm tự đặt.
- **Quy tắc dừng của người dùng:** test_driver hoặc phép kiểm ngược D3 lỗi thì dừng và chỉ sửa code của mình; một lần mô phỏng lẻ lỗi thì ghi lại và chạy tiếp. Không đổi tham số bộ điều khiển, cảnh, tiêu chí D0(d). TEMP sang ổ D (use_sim_tmp), Simulink.sdi.clear sau mỗi lần chạy, thư mục cache Simulink riêng.
- **Tiến độ:** D1-D7 XONG (2026-11-10, Lượt 3); chờ người dùng xem bảng D7 và hình ở Result/PRSM/Driver/ rồi quyết. Chưa commit (chỉ commit khi người dùng bảo; file của khung: Model/original/PRSM/Driver/, Model/shared/data/driver.json, hai dòng sửa trong shared/setup_paths.m và shared/common/result_dir.m, Result/PRSM/Driver/, Tracking/historychat_driver.md, scratch/driver không commit).

---

## 2. BẢN NÉN CÁC LƯỢT CŨ

(chưa có)

---

## 3. NHẬT KÝ NGUYÊN VĂN (5 lượt gần nhất)

### Lượt 1 (2026-11-10) - Nhận việc, chép D0, bắt đầu D1-D7

Đọc KeHoach_NguoiLai.txt, build_closed_loop.m, make_cases.m (SSW), run_cases.m. Quyết định thiết kế (không đổi ý kế hoạch): cảnh stair, pud (của SLIP) và lane (của WEAVE) cắt từ make_cases('SSW') theo đúng mốc thời gian chain() (stair [44.5, 74], pud [80, 92], lane [29, 40]), không sửa make_cases.m; theta1_tgt = theta1 của make_cases (đúng công thức steady dry); Plant không xuất X, Y, psi nên tính psi = int gamma dt, X, Y từ v và psi (quy ước ghi lại ở D5).

### Lượt 2 (2026-11-10) - D1 đến D3 xong (test_driver PASS, kiểm ngược D3 PASS cho Map và MapPID); D5, D6 đang chạy nền

LÀM (mọi file mới, không sửa Plant, Model_<Ctrl>, build_closed_loop, json bộ điều khiển): `Model/shared/data/driver.json` (ba bộ W, H_relaxed, H_tense, mỗi bộ có trường ref), `Model/original/PRSM/Driver/load_driver.m`, `Driver.slx`, `Model_Map_DriverC.slx`, `Model_MapPID_DriverC.slx`, và `script/`: build_driver, test_driver, build_closed_loop_driver (copy của Model_<ctrl> rồi thay From Workspace theta1 bằng Driver; thêm cổng ra gamma, theta2_dot và log_theta1, log_gamma, log_theta2_dot; StopFcn rỗng), make_driver_cases, hand_force, driver_sim, check_driver_backward, run_driver_cases, driver_analyze, driver_env (TEMP sang D:\sim_tmp_driver_<tag>, thư mục cache Simulink riêng). SỬA FILE DÙNG CHUNG (kế hoạch cho phép, ghi vì là file chung): `shared/setup_paths.m` thêm 'Driver' vào danh sách phần PRSM; `shared/common/result_dir.m` thêm 'Driver' vào nhánh PRSM (result_dir('Driver') = Result/PRSM/Driver).
KẾT QUẢ: D2 `[Driver] TEST PASS`, sai số lớn nhất so với ode45 độc lập 8.4e-11 rad (cả ba bộ W, H_relaxed, H_tense); lần đầu ngưỡng 1e-4 tương đối trượt (9.8e-6 rad) vì nội suy tuyến tính đầu ra Simulink, đã sửa test so ở đúng các điểm thời gian của Simulink (lỗi của test, không phải của khối). D3 cảnh pud_orig, cảm biến lý tưởng, T_d = J theta1_ddot + C theta1_dot + K theta1 + T_s lấy từ Model gốc: Map lệch theta1 lớn nhất 2.3e-5 rad (theta1 cực đại 0.304), MapPID 1.3e-4 rad; PASS (ngưỡng 1e-3 của biên độ). Hình `Result/PRSM/Driver/<Ctrl>_pud_orig_check_ideal.png`.
QUYẾT ĐỊNH THIẾT KẾ: ba cảnh stair, pud, lane cắt từ make_cases('SSW') tại mốc chain() (stair [44.5, 74] s của SLIP, pud [80, 92] s của SLIP, lane [29, 40] s của WEAVE), đã kiểm trong code (a_y đích 0 tại điểm cắt, tốc độ và mu đầu cảnh, có đoạn mu thấp); không sửa make_cases.m. theta1_tgt = theta1 của make_cases. Plant không xuất X, Y, psi nên dùng góc hướng đi chi = int(a_y/v), psi = int gamma, beta = chi - psi, X, Y từ chi (khớp cách tính tim đường D3, a_y của Plant tính bằng m/s^2). Tiêu chí định nghĩa TRƯỚC khi chạy D5 (ghi trong đầu driver_analyze.m): dao động khi RMS của theta1 - movmean(theta1, 0.4 s) trên t >= 2 s vượt 0.002 rad; Delta_y = max_t |e_y(orig) - e_y(mu08)|; RMS e_T chấm trên t >= 2 s như run_cases; đoạn giữ cua = mẫu có |a_y đích| >= 0.9 max. Không chép delta_f vào file vị trí (Plant không xuất).
ĐANG CHẠY: `scratch/driver/run_all.sh` (nền, tối đa 4 lần mở MATLAB, tiếp từ checkpoint Result/PRSM/Driver/Driver_runs_s99999.mat), 48 lần mô phỏng ngắn (12 người lái cứng + 36 người lái lực), lỗi lẻ ghi vào Driver_run_errors_s99999.txt. Sau đó: driver_analyze(99999) cho D4, D5, D6, D7.

### Lượt 3 (2026-11-10) - D4 đến D7 xong: 48 lần chạy đủ, không lần nào lỗi; bảng thứ bậc D7 hỗn hợp

LỖI CỦA TÔI (đã sửa): lần chạy đầu của run_driver_cases dừng sau 6 lần rigid của Map vì biến `raw` (và `modelDir`) bị các script load_* chạy trong hàm ghi đè; sửa bằng đổi tên `drvJson` và chạy load_* bằng evalin('base'); các lần rigid đã xong giữ nguyên nhờ checkpoint. Hình đầu có dải mu thấp làm trục y thành ±1000, sửa YLimInclude 'off' rồi sinh lại. Heap corruption lúc thoát MATLAB là lỗi đã biết, dữ liệu đã ghi. Không có lần mô phỏng lẻ nào lỗi (Driver_run_errors_s99999.txt không tồn tại). Chạy 00:19-00:51, driver_analyze(99999) sau đó.
FILE (Result/PRSM/Driver/): Driver_test_theta1.png/csv (D2), <Ctrl>_pud_orig_check_ideal.png/csv (D3), Driver_D4_hand_force_centre_line.png (D4), Driver_D5_table_s99999.csv, Driver_D5_D6_table_s99999.csv (đủ ba bộ tay), Map_vs_MapPID_DRIVER{stair,pud,lane}_path_s99999.png, Map_vs_MapPID_DRIVER_theta1err_mu08_s99999.png (kiểm công thức lực tay), Map_vs_MapPID_DRIVER_stiffness_s99999.png (D6), Driver_D7_ranking_s99999.csv, <Ctrl>_DRIVER<cảnh>_pose_<orig|mu08>_s99999.csv (bộ H thả lỏng; không có delta_f), Driver_runs_s99999.mat (toàn bộ tín hiệu).
KẾT QUẢ D7 (tiêu chí D0(d), không đổi): H_relaxed: stair NGƯỢC chiều (RMS e_T cứng Map 0.855 / MapPID 0.205; Delta_y 11.2 / 12.6 m), pud CÙNG chiều (1.206 / 0.455; 2.96 / 2.40 m), lane NGƯỢC chiều (1.268 / 0.193; 0.34 / 0.39 m). W (K_h 0): cả ba cảnh ngược chiều (Delta_y Map 38.6, 6.6, 0.08 m; MapPID 61.9, 19.6, 11.1 m; MapPID kém hơn). H_tense: stair HÒA (Delta_y 12.9 / 13.2), pud và lane cùng chiều (2.12 / 1.51; 0.18 / 0.14 m). Người lái cứng cho MapPID thấp hơn Map ở cả ba cảnh (62-85 %). Khác biệt vị trí Map so với MapPID (H_relaxed) 9.6, 4.0, 6.8 m, vượt xa ngưỡng 0.5 m của kế hoạch 3D.
LƯU Ý ĐỌC KẾT QUẢ (trung thực): (1) Delta_y đo tối đa trên cả cảnh nên gồm cả phần trôi sau khi mu trở lại 0.8 (stair: MapPID lệch -8 m ở cuối cảnh), không chỉ phần do mu; không đổi định nghĩa. (2) Cờ dao động theo ngưỡng 0.002 rad bật ở hầu hết các lần (17 trên 18 dòng): ngưỡng không phân biệt được, nên dùng số RMS thay vì cờ (Theta1HF_rms trong bảng). (3) Bộ W với tay không cứng làm theta1 trôi rất lớn (Map stair theta1 cực đại 4.9 rad, MapPID 6.3 rad): xe/vô-lăng mất kiểm soát vòng hở, nên kết luận ở K_h = 0 chỉ là mốc của quét. (4) Kiểm công thức lực tay (mu 0.8): max |theta1 - theta1_tgt| ở đoạn giữ cua với H_relaxed: Map stair 0.129 rad, pud 0.059, lane 0.083; MapPID 0.067, 0.028, 0.379 (lane MapPID đáng chú ý: theta1 cực đại 0.62 so với đích 0.26 rad); H_tense nhỏ hơn nhiều (0.0176, 0.0136, 0.0140 Map; 0.0086, 0.0096, 0.0126 MapPID). Lệch lớn ở H_relaxed một phần do T_s thực không bằng T_d,ref (e_T), vì vòng hở thả theta1 theo T_s. (5) Xu hướng D6: K_h tăng thì Delta_y giảm mạnh và RMS e_T của người lái lực tiến gần giá trị người lái cứng (đúng dự đoán, kế hoạch ghi CHƯA kiểm). Người dùng xem hình/bảng rồi quyết có làm phần vẽ hay chỉnh ca. Chưa commit.
