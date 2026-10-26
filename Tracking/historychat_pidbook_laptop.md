# Nhật ký PIDBOOK-LAPTOP

- Vai: khung PIDBOOK-LAPTOP chạy không người trên laptop, phụ trách MapPID và các bước chung cuối theo mục 6.1-6.3.
- Tài liệu điều khiển: `Tracking/CLAUDE.md`, `Documents/Shared/KeHoach_PID_Sach.txt`, `Documents/Shared/KeHoach_SoMatPareto.txt`, và `Tracking/historychat_common.md` Lượt 240-247.
- Nguyên tắc: chỉ làm trên `main`; không dùng kết quả lần chạy cũ để lập luận cho thiết kế mới; không sửa file của Map/PID hay các file dùng chung bị cấm.

## Trạng thái hiện tại

- Bước 0: hoàn tất. Đã `git fetch origin`, `git checkout main`, `git pull`; cờ `PIDBOOK_PLAN_PUSHED.txt` đã có trên `origin/main` nên điều kiện chờ L0 thỏa ngay. Không có nhánh cục bộ khác `main`, do đó không có commit cục bộ chưa đẩy cần bảo toàn.
- L1: hoàn tất; chuẩn bị commit/push mốc lưu trữ rồi thực hiện L2.

## Nhật ký từng bước

### Bước 0 / L0 - Đồng bộ và chờ kế hoạch (2026-10-27)

- Lần chạy đầu trong sandbox bị từ chối ghi `.git/FETCH_HEAD` và `.git/index.lock`; chạy lại với quyền ghi metadata Git được người dùng phê duyệt thì thành công.
- `main` fast-forward từ `fdc5b06` lên `b24c77e`; cờ `Result/Compare/Pareto_common/PIDBOOK_PLAN_PUSHED.txt` có ngay sau pull, vì vậy vòng chờ nền đạt điều kiện thoát tức thời.
- `git branch -vv` chỉ có `main`; không xóa nhánh nào.

### L1 - Lưu kết quả MapPID cũ (2026-10-27)

- Đã kiểm kê nguồn trước khi chuyển: `Calib_v2/PlugPlay`, `Cases_ssw`, `ParetoCommon_MapPID_*` và các file chung ba bộ `ParetoCommon_fronts_*`, `ParetoCommon_table_*`, `ParetoCommon_select*`, `*.png`.
- Chỉ chuyển file vào thư mục con `Legacy_2026-10-27` cùng chỗ; không xóa, không chạm `Result/Controllers/Map/**`, `ParetoCommon_Map_*` hoặc kết quả PID.
- Đã chuyển 11 file PlugPlay, 24 file SSW, 17 file riêng MapPID ở Pareto chung và 8 file chung ba bộ. Kiểm `git status` không có thay đổi nào dưới `Result/Controllers/Map/`, `Result/Controllers/PID/` hoặc `ParetoCommon_Map_*`.
