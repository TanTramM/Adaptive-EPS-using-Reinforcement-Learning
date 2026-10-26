# Nhật ký PIDBOOK-LAPTOP

- Vai: khung PIDBOOK-LAPTOP chạy không người trên laptop, phụ trách MapPID và các bước chung cuối theo mục 6.1-6.3.
- Tài liệu điều khiển: `Tracking/CLAUDE.md`, `Documents/Shared/KeHoach_PID_Sach.txt`, `Documents/Shared/KeHoach_SoMatPareto.txt`, và `Tracking/historychat_common.md` Lượt 240-247.
- Nguyên tắc: chỉ làm trên `main`; không dùng kết quả lần chạy cũ để lập luận cho thiết kế mới; không sửa file của Map/PID hay các file dùng chung bị cấm.

## Trạng thái hiện tại

- Bước 0: hoàn tất. Đã `git fetch origin`, `git checkout main`, `git pull`; cờ `PIDBOOK_PLAN_PUSHED.txt` đã có trên `origin/main` nên điều kiện chờ L0 thỏa ngay. Không có nhánh cục bộ khác `main`, do đó không có commit cục bộ chưa đẩy cần bảo toàn.
- L1: hoàn tất và đã push commit `9c7040e`.
- L2: hoàn tất, `test_mappid` PASS; chuẩn bị commit/push mã.
- L3: hoàn tất. Lưới dừng theo hội tụ của `grid_search` ở 545 điểm; 225 điểm được mô phỏng/qua cổng tuyến tính.
- L4: hoàn tất, chọn tạm `(K,Ti,Td,N)=(2.08008382306, 0.02398259906, 0.02331802644, 13.65279781)`; margin PASS.
- L5: chuẩn bị push toàn bộ lưới, kết quả chọn tạm và cờ bàn giao cho PC.
- L5: hoàn tất và push commit `2dd90b8`.
- L6: bắt đầu đánh giá seed chung MapPID, id 1-4/8, hai pha theo Sửa đổi A.

## Nhật ký từng bước

### Bước 0 / L0 - Đồng bộ và chờ kế hoạch (2026-10-27)

- Lần chạy đầu trong sandbox bị từ chối ghi `.git/FETCH_HEAD` và `.git/index.lock`; chạy lại với quyền ghi metadata Git được người dùng phê duyệt thì thành công.
- `main` fast-forward từ `fdc5b06` lên `b24c77e`; cờ `Result/Compare/Pareto_common/PIDBOOK_PLAN_PUSHED.txt` có ngay sau pull, vì vậy vòng chờ nền đạt điều kiện thoát tức thời.
- `git branch -vv` chỉ có `main`; không xóa nhánh nào.

### L1 - Lưu kết quả MapPID cũ (2026-10-27)

- Đã kiểm kê nguồn trước khi chuyển: `Calib_v2/PlugPlay`, `Cases_ssw`, `ParetoCommon_MapPID_*` và các file chung ba bộ `ParetoCommon_fronts_*`, `ParetoCommon_table_*`, `ParetoCommon_select*`, `*.png`.
- Chỉ chuyển file vào thư mục con `Legacy_2026-10-27` cùng chỗ; không xóa, không chạm `Result/Controllers/Map/**`, `ParetoCommon_Map_*` hoặc kết quả PID.
- Đã chuyển 11 file PlugPlay, 24 file SSW, 17 file riêng MapPID ở Pareto chung và 8 file chung ba bộ. Kiểm `git status` không có thay đổi nào dưới `Result/Controllers/Map/`, `Result/Controllers/PID/` hoặc `ParetoCommon_Map_*`.

### L2 - Tham số hóa lại MapPID theo sách và kiểm thử (2026-10-27)

- `mappid_u2x`/`mappid_x2u`: bốn tọa độ tự do là `(K, Ti, Td, N)` theo đúng hộp mục 2.3, rồi đổi sang các cột tương thích `(Kp, Ki, Kd, Tf)` bằng `Kp=K`, `Ki=K/Ti`, `Kd=K*Td`, `Tf=Td/N`. Map tiếp tục khóa theo `map.json`.
- `mappid_eval`: kiểm `Kd*Ki < Kp^2` tương đương `Td < Ti` ngay đầu hàm; điểm vi phạm được ghi `simulated=0`, `c1=1`, không nạp plant, không tính margin và không mô phỏng.
- `mappid_variables`: đổi sang `Kaw=sqrt(Ki/Kd)`; không đổi tín hiệu chống bão hòa, vẫn dùng sai lệch sau giới hạn của lệnh tổng.
- `mappid.json`: chuyển thiết kế chính thức cũ vào `legacy.design_before_pidbook_2026_10_27`; trước khi có thiết kế mới, loader dùng Map khóa và PID bằng 0. Script chọn sẽ ghi đồng thời `(K,Ti,Td,N)` và `(Kp,Ki,Kd,Tf)`.
- `test_mappid`: nghiệm tham chiếu tự tính `Kaw=1/sqrt(Ti*Td)`, có đoạn giới hạn dương 2-3 s và âm 4-5 s.
- Hai lần gọi MATLAB trong sandbox không chạy được do môi trường, lỗi nguyên văn lần 1: `Unable to create preferences folder in MathWorks\\MATLAB\\R2023a. Preferences folder location must be a valid full path.`; sau khi đặt `MATLAB_PREFDIR`, lỗi lần 2: `Previously accessible file "C:\\Program Files\\MATLAB\\R2023a\\toolbox\\local\\pathdef.m" is now inaccessible.` và `Unrecognized function or variable 'run'.` Đây là lỗi quyền đọc cài đặt, không phải lỗi mã.
- Chạy lại MATLAB ngoài sandbox với `MATLAB_TEMP`, `TEMP`, `TMP`, `MATLAB_PREFDIR` trên ổ C và `guard_ram.ps1` nền (10% RAM) thành công: `test_mappid_grid_helpers: PASS`; cổng `Td/Ti` vi phạm PASS; ba ca Map-only, PID-only, Map+PID đều khớp nghiệm độc lập với sai số lớn nhất lần lượt `2.92e-12`, `7.11e-15`, `3.45e-12` N.m; kết thúc `TEST PASS`.
- Ổ C còn 43.91 GB trước khi chạy, lớn hơn ngưỡng dừng 15 GB; không có MATLAB khác khi bắt đầu.

### L3 - Quét lưới MapPID seed 30000 (2026-10-27)

- Tạo runner riêng của laptop dùng `job_lib_patient.sh`, bốn worker, marker tách biệt `pbl_l3_w1..w4`, `MATLAB_TEMP` và preferences đều đặt trong `scratch/MatlabTemp` trên ổ C. `guard_ram.ps1` PID 2036 tiếp tục chạy nền.
- Đã dọn thư mục preferences rác `MathWorks/MATLAB/R2023a/graphicsState.bin` do lần gọi MATLAB sandbox thất bại tạo ra; đây là tệp chưa theo dõi do chính lượt này sinh, không phải dữ liệu repo.
- Mốc một giờ 04:00: lưới thô 256 điểm và ba lớp mịn 81 điểm đã hoàn tất; lớp mịn 4 đang chạy, tổng bốn CSV khoảng 521 dòng, không có worker lỗi/restart. Đẩy ảnh chụp CSV theo quy tắc ít nhất mỗi giờ; worker tiếp tục ghi phần sau.
- Hoàn tất 04:05: bốn CSV có lần lượt 140, 136, 137, 132 dòng, tổng 545; `simulated=1` và qua ba cổng tuyến tính là 225 điểm. Cả bốn marker worker DONE, không có marker FAILED; thuật toán tự dừng theo điều kiện hội tụ hiện có, không đổi số lớp hay lưới.

### L4 - Chọn tạm MapPID (2026-10-27)

- Bắt đầu `select_mappid_plug(true)` qua `job_lib_patient.sh`; quy tắc chọn, seed báo cáo 30001-30005 và margin seed 30001 giữ nguyên theo kế hoạch.
- Lần gọi đầu bằng `bash -lc` bị PowerShell tách sai chuỗi tại dấu chấm phẩy, lỗi nguyên văn: `true : The term 'true' is not recognized` và `disp : The term 'disp' is not recognized`. Chưa mở MATLAB và chưa chạm kết quả. Sửa runner nhận đối số `l4` để tránh lớp quote lồng nhau rồi chạy lại.
- Chạy lại qua runner thành công ngay lần MATLAB thứ nhất. Tổng 545 điểm, 225 mô phỏng, 151 khả thi, 36 điểm Pareto. Điểm tạm: `K=2.08008382306`, `Ti=0.0239825990561 s`, `Td=0.0233180264360 s`, `N=13.6527978129`; tương đương `Kp=2.08008382306`, `Ki=86.7330441622`, `Kd=0.0485034495753`, `Tf=0.00170793025398 s`, `Kaw=42.2869129155`.
- CALIB seed tìm: `R=2.44515775 %`, `S=0.7939389451 N.m`, `J=1.94130596464`; báo cáo năm seed: `J=2.04693500943 +/- 0.113269161715`, `e_rel,max=1.678 %`; `PM=38.822 deg`, `GM=3.118`; margin seed 30001 PASS với tỉ số gain `0.7594`, delay `1.0254`.

### L5 - Đẩy lưới và cờ bàn giao MapPID (2026-10-27)

- Tạo `Result/Compare/Pareto_common/PIDBOOK_MAPPID_GRID_DONE.txt` sau khi L3 và L4 hoàn tất; commit gồm đúng kết quả MapPID, `mappid.json`, runner và nhật ký laptop.

### L6 - Đánh giá MapPID trên seed chung (2026-10-27)

- Runner dùng bốn MATLAB patient cho id 1-4/8, chạy pha 1 trước rồi pha 2; seed/cổng/tập dự tuyển do `compare_pareto_common.m` hiện có quyết định theo `KeHoach_SoMatPareto.txt` Sửa đổi A. Laptop không sửa file dùng chung này.
