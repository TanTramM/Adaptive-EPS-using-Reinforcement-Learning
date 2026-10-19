# Bàn giao MapPID sang laptop — 2026-10-19

## Chỉ dẫn cho khung chat MapPID mới

Người dùng đã ủy quyền chạy MapPID trên laptop, tự chẩn đoán/sửa lỗi và ghi lịch sử. Khi nhận câu “đọc lịch sử các file tracking, bạn là khung chat mappid, làm theo hướng dẫn”, đọc `CLAUDE.md`, `Tracking/CLAUDE.md`, trạng thái và các lượt cuối `Tracking/historychat_mappid.md`, tài liệu này, cùng mục 13 của `Documents/Shared/PhuongPhap_TimThamSo.txt`. Bắt đầu công việc theo hướng dẫn dưới đây; không yêu cầu người dùng nhắc lại lệnh. Quyết định mới về lịch chạy trong tài liệu này thay khóa cũ chờ cả hai pick trước S1.

Laptop có MATLAB và toolbox cùng phiên bản desktop. Desktop tiếp tục Map; laptop sở hữu MapPID. Không khởi chạy Map/PID trên laptop. DREWS cũ đã bị hủy theo yêu cầu người dùng; hoàn tất ở bước chọn Pareto MapPID. Không tự chạy bộ DREWS mới đang được thiết kế.

## Chuẩn bị và chạy S1 ngay

1. Xác nhận repo đã nhận đầy đủ commit bàn giao. Không dùng bản mã cũ chỉ có surrogateopt. Các file mới không tự theo `git push` nếu chưa được add/commit.
2. Tại gốc repo chạy kiểm tra không mô phỏng:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/jobs/start_mappid_laptop.ps1 -Stage S1 -CheckOnly
   ```

3. Sau preflight, khởi chạy supervisor ở cửa sổ ẩn, lấy PID để giám sát:

   ```powershell
   $script = (Resolve-Path 'tools/jobs/start_mappid_laptop.ps1').Path
   $job = Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $script + '"'),'-Stage','S1') -WindowStyle Hidden -PassThru
   $job.Id
   ```

Runner tự tìm `matlab.exe` trên PATH hoặc thư mục R2023a mặc định, tự tính gốc repo và tạo TEMP/TMP dưới thư mục tạm Windows; không cần ổ D hoặc tên tài khoản Admin. Nếu MATLAB cài chỗ khác, thêm `-MatlabExe '...\bin\matlab.exe'` khi gọi runner. Không cần Git Bash để chạy runner laptop.

Mặc định một worker `run_mappid_grid('S1',1,1)`, chờ không còn MATLAB engine khác và còn ít nhất 6 GB headroom trước mỗi lần launch. Máy nên để dành cho tác vụ này; không tự mở thêm MATLAB từ khung khác. Giữ một worker trong toàn bộ một xuất phát khi resume để tránh đổi cách chia lưới. Không sửa `nWorkers` giữa chừng. Nếu RAM không đủ, kiểm tra RAM/pagefile và ứng dụng đang mở; không tự hạ ngưỡng RAM để ép chạy.

S1 chỉ cần PID đã chọn: `Model/data/pid.json` và `Result/Controllers/PID/Calib_v2/PID_CALIB_pick_s10000.csv`. Vẫn cần các JSON PRSM/Map hiện hành để nạp mô hình/calibration, nhưng không cần Map pick cho S1. `mappid_grid_start.m` đã tách guard đúng từng hướng. Runner kiểm helper trước tìm kiếm; không chạy precheck hard-code số CALIB cũ `check_mappid_grid_eval` vì đó là phép tái lập thiết kế lịch sử, không phải điều kiện S1.

## Giám sát, phục hồi và ghi lịch sử

- PID supervisor được trả về lúc launch; xác nhận process thực tế còn sống. Trạng thái/log: `scratch/jobs/mappid_laptop/`; CSV cache: `Result/Controllers/MapPID/Calib_v2/MapPID_CALIB_S1*_w1_s30000.csv`.
- Kiểm CPU, log và delta CSV định kỳ; phân biệt mô phỏng dài, đồng bộ và tiến trình đã chết. Không chỉ dựa vào dòng `running`. Runner dùng file lock độc quyền để ngăn hai supervisor laptop.
- Crash/heap corruption giữ cache và retry sau 60 giây. Lỗi exit 1 thật dừng sau ba lần; đọc cả stdout/stderr, sửa nguyên nhân, ghi lịch sử rồi gọi lại cùng stage. Không xóa CSV hay đổi seed. Runner chỉ dừng engine mồ côi có đúng batch expression của chính nó.
- File `.done` trong scratch ghi stage đã hoàn tất có success marker. Nếu chủ động đổi mã/phương pháp/đầu vào sau khi stage đã xong, phải đánh giá tính hợp lệ của cache và marker; không tự coi marker cũ là kết quả cho phương pháp mới.
- Nếu agent bị ngắt nhưng supervisor còn sống, tiếp tục theo dõi supervisor đó, không launch thêm. Nếu chỉ supervisor chết còn MATLAB engine sống, kiểm tra đúng cây process và xử lý nó trước khi resume.
- Mỗi lượt cập nhật `Tracking/historychat_mappid.md` theo quy tắc tracking; ghi lỗi/cách sửa và bằng chứng phục hồi. Không sửa log của khung Map/PID.

## S2 và Pareto sau khi desktop chọn Map xong

S1 hoàn tất tạo `Result/Controllers/MapPID/Calib_v2/MapPID_CALIB_S1_summary.mat`. Sau đó kiểm tra Map desktop đã chọn và được commit/push; nhận đúng cặp `Model/data/map.json` và `Result/Controllers/Map/Calib_v2/Map_CALIB_pick_s00000.csv`. Không lấy Map json tạm rồi giả là kết quả đã chọn. `git pull` có thể xung đột vì laptop có kết quả/log mới; đọc `git status`, bảo toàn thay đổi laptop, không reset/checkout cưỡng bức. Chỉ cập nhật dữ liệu Map cần thiết nếu pull toàn bộ có xung đột, ghi rõ nguồn commit.

Khi có đủ Map pick, chạy lần lượt (supervisor S1 đã thoát):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/jobs/start_mappid_laptop.ps1 -Stage S2
powershell -NoProfile -ExecutionPolicy Bypass -File tools/jobs/start_mappid_laptop.ps1 -Stage Select
```

Có thể chạy ẩn tương tự S1 và giám sát theo PID. `Select` yêu cầu summary hoàn tất của cả S1 lẫn S2, gộp mọi tag để chọn Pareto, kiểm `calib_margin`, báo năm seed CALIB 30001–30005 và ghi `Model/data/mappid.json`. Năm seed CALIB là một phần chọn tham số, vẫn chạy; không phải DREWS. Kiểm output pick/JSON/log selector trước khi báo hoàn tất. Không tuyên bố chọn xong chỉ từ file summary hoặc marker.

Lệnh `-Stage All` chỉ dùng sau khi đã có Map pick; nó chạy/resume S1, S2 rồi Select. Lệnh cũ `mappid_grid_pipeline.sh` mặc định đã bị chặn để supervisor desktop không tự launch thêm MapPID khi Map pick xuất hiện. Không bật `MAPPID_ALLOW_LEGACY_PIPELINE` trong luồng bàn giao này.

## Các file phải có trong commit chuyển máy

Giữ toàn bộ `Model/` (models, `setup_paths`, PRSM, Sim, common và JSON), tài liệu phương pháp/tracking; đặc biệt các script grid mới của MapPID, `Model/common/grid_search.m`, `Model/common/select_pareto.m`, PID json đã chọn và PID pick. Runner và tài liệu này nằm trong `tools/jobs/`. Các file đó đều trong repo và không bị `.gitignore` chặn, nhưng nhiều file ban đầu còn untracked nên cần add/commit.

Không sao chép marker/lock/log `scratch/` của desktop sang laptop. Không cần backup Desktop, MATLAB binaries hay cache build `slprj`. Không cần CSV đang quét của Map để chạy S1. Sau này chuyển kết quả MapPID từ laptop về bằng commit/push các CSV/summary/JSON và lịch sử cần thiết; không commit scratch. Giữ nguồn dữ liệu một chỗ trong `Model/data` và `Result`, không tạo bản sao JSON riêng trong gói bàn giao.

Tài liệu đã chuẩn bị trên desktop; laptop phải kiểm tra môi trường và theo dõi lần chạy thật. Preflight file không chứng minh mô phỏng đã chạy hoặc toàn bộ toolboxes tương thích.
