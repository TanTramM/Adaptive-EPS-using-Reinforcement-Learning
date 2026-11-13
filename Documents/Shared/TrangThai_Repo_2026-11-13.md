# TRẠNG THÁI REPO VÀ VIỆC ĐÃ LÀM TỪ 31/10 ĐẾN 13/11/2026

Viết ngày 2026-11-13 trên PC (DESKTOP-G6T192V), để máy khác (laptop) đọc là nắm được đề tài đang ở đâu. File này là bản tóm tắt; chi tiết đầy đủ nằm trong các nhật ký `Tracking/historychat_*.md` và các file kế hoạch được trỏ tới bên dưới. Nếu có mâu thuẫn, nhật ký của khung liên quan và `Tracking/CLAUDE.md` được ưu tiên.

---

## 1. Tóm tắt một đoạn

Luận văn thạc sĩ "Adaptive C-EPS" (HV Trần Minh Tân, GVHD TS. Phùng Thanh Huy, HCMUT). Hướng cuối cùng không dùng học tăng cường (RL): đề tài so ba bộ điều khiển trợ lực lái điện trên cột lái (C-EPS): Map (bản đồ trợ lực + khâu bù lead-lag), PID, và MapPID (giữ nguyên Map, cộng một nhánh PID song song bám mô-men mục tiêu tính từ vận tốc và gia tốc ngang). Bộ tham số đã chọn xong từ cuối tháng 10 (chọn trên mặt Pareto, năm seed chung 99990-99994), đánh giá trên ba ca STEADY, SLIP, WEAVE với năm seed 99995-99999. Từ 31/10 đến nay đã làm: kiểm chéo đối tượng bằng thư viện VDB (Vehicle Dynamics Blockset của MathWorks), hai việc "đào sâu" (độ bền theo sai lệch tham số xe ±20 % và giải thích vì sao MapPID kém PID ở WEAVE), phép tách ma sát cột lái, và VIẾT XONG LUẬN VĂN BẢN 1 HOÀN CHỈNH (115 trang). Việc còn lại chủ yếu là người dùng duyệt luận văn, điền thông tin cá nhân, và chốt vài quyết định (mục 8).

---

## 2. Trạng thái git (13/11/2026)

- Một nhánh duy nhất `main`, remote `origin` = github.com/TanTramM/Adaptive-EPS-using-Reinforcement-Learning. Laptop chỉ cần `git pull`.
- Ba commit mới nhất (đều 13/11, từ PC, KHÔNG qua `tools/sync_repo.sh`):
  - `b6be018` Thesis: complete draft (chương 6, phần đầu, phụ lục, đánh số lại tài liệu).
  - `8224d10` Thesis data, models and scripts used by the thesis (349 file: Model/shared, PRSM, ba bộ điều khiển, Model/VDB, Result dùng trong luận văn, script vẽ hình, PDF Mehrabi).
  - commit chứa chính file này cùng các nhật ký Tracking, kế hoạch Documents/Shared và báo cáo tuần 14/11.
- Commit trước đó: `6d3a8b0`, `45c5c5e` (07/11, VDB lốp), `c096537` (06/11), `a8e4b34` và `075abf5` (06/11, laptop: thử từng cổng VDB_TIRE và VDB_BODY), `e4d9320` (06/11, Plant_VDB kiểm theo rủi ro), `0334a3d` (31/10).
- CÒN CHƯA COMMIT trên PC (laptop sẽ KHÔNG có):
  - Tín hiệu thô của phép thử độ bền và phép thử ma sát: `Result/Compare/Robust/*_sig_s*.csv`, `Result/Compare/Friction/Tf0/*_sig_*.csv` (khoảng 0.6 GB; số trong luận văn không đọc các file này; chạy lại được bằng `run_robust_cases`, `run_friction_check`).
  - Tệp vị trí 3D `*_pose_*.csv`, mô hình người lái `Model/original/PRSM/Driver/`, `Result/PRSM/Driver/`, `Model/shared/data/driver.json` (khung DRIVER, không thuộc luận văn).
  - Việc dọn repo từ Lượt 85 của khung VDB_TIRE: khoảng 330 file đã xóa khỏi chỗ cũ (mã và kết quả PI, SMC, ISMC, MapOpt, MapPIDLag, script `tools/jobs/`, script hình cũ, file `*_DONE.txt` trong Pareto_common, vài file Documents/Shared) và bản sao của chúng trong `history/` (chưa track). Chưa commit vì là quyết định dọn dẹp của người dùng; trên laptop các file cũ vẫn còn ở chỗ cũ.
  - Các bản sao lưu `Documents/Thesis/draft/luanvan_backup_*.txt`.
- Trên laptop: không có ổ D (cache Simulink để ở thư mục tạm), có thể không có Word (cần cho `docx2pdf_word.py`), đường dẫn Python và MATLAB có thể khác.

---

## 3. Các file quan trọng nhất

| Việc | File |
|---|---|
| Quy tắc chung, cấu trúc thư mục, đặt tên | `Tracking/CLAUDE.md` (file `CLAUDE.md` ở gốc trỏ tới đây) |
| Luận văn (nguồn duy nhất) | `Documents/Thesis/luanvan.txt` |
| Luận văn đã dựng | `Documents/Thesis/luanvan.docx`, `luanvan.pdf` (115 trang) |
| Dàn ý, kế hoạch từng chương, nguồn đã kiểm, chỗ là lựa chọn | `Documents/Thesis/DanY_LuanVan.md` |
| Nhật ký khung viết luận văn và VDB (đọc mục TRẠNG THÁI HIỆN TẠI) | `Tracking/historychat_vdb_tire.md` (tới Lượt 100) |
| Quy chuẩn thiết kế và đánh giá | `Documents/Shared/QuyChuan.txt` |
| Kế hoạch đã chạy sau 31/10 | `Documents/Shared/KeHoach_Plant_VDB.txt`, `KeHoach_VDB_ThanXe.txt`, `KeHoach_DoBenThamSo.txt`, `KeHoach_WEAVE_HaiNhanh.txt`, `KeHoach_MaSatCotLai.txt`, `KeHoach_NguoiLai.txt`, `3D_modelling_plan.txt` |
| Bài báo tiếng Anh (chỉ để tham khảo, hội đồng không xem) | `Documents/Paper/paper.txt` |
| Báo cáo thầy 14/11 | `Documents/Report/Week1411_baocao.docx` |

---

## 4. Dòng thời gian từ 31/10 đến 13/11

- **31/10** (commit `0334a3d`): bài báo `paper.txt` đủ mục 1-6 (khung PAPER), bản rút gọn `paper_v3.txt` 8 364 từ cho thầy. Tham số ba bộ đã chốt từ lần chạy PIDBOOK 27/10: Map K_max 6.77 (chọn trên mặt "safe", e_rel 26.2 %), PID K_p 2.90 T_i 34.2 ms T_d 23.3 ms N 19.3, MapPID K_p 2.08 T_i 24.0 ms T_d 23.3 ms N 14.2.
- **04-05/11**: thầy nhận xét nội dung "mới miễn cưỡng", cần ghép một "hệ chuẩn mô phỏng", đào sâu và có phần trực quan. Khung COMMON (Lượt 248-259) chọn kiểm chéo bằng VDB thay CarSim (không có giấy phép), lập kế hoạch `KeHoach_Plant_VDB.txt`, làm thử demo.
- **06/11**: thầy chốt "Thử cái 2 trước (VDB thay Plant). Ổn thì thêm cái 1 (bộ điều khiển khác)". Chạy đêm kế hoạch Plant_VDB (N0-N10), kiểm theo rủi ro (mục 11), bảng ánh xạ cổng VDB với Plant (mục 12). Hai khung VDB_BODY và VDB_TIRE chạy trên laptop thử đổi từng cổng: VDB_TIRE 31/31 ca chấm ĐẠT, VDB_BODY 14/22 ĐẠT (các ca không đạt chỉ do FzF, FzR). Tái cấu trúc `Model/` thành `shared/`, `original/`, `VDB/` (bảng đổi đường dẫn trong Tracking/CLAUDE.md).
- **07/11** (commit `45c5c5e`, `6d3a8b0`): lốp VDB thực tế hóa (độ trễ lực ngang σ = 0.609 m; bản M_z khớp vệt bánh có ràng buộc), chạy SSW ba bộ, báo cáo `VDB_tire_report.docx` (Anh) và `VDB_tire_baocao.docx` (Việt). Người dùng chốt: luận văn = nội dung bài báo + phần VDB.
- **07-09/11**: bàn có nên thay lốp Plant bằng lốp VDB hay lốp đo của Pacejka (Table A3.1): KHÔNG thay, giữ lốp Plant, khối lốp VDB chỉ bật độ trễ; bản có M_z không độc lập (khớp theo phương trình vệt bánh của chính Plant) nên chỉ nêu ở giới hạn. Dựng thử 3D (Unreal trong VDB) nhưng hai xe gần như trùng quỹ đạo vì góc vô-lăng cho trước.
- **09-10/11**: kế hoạch người lái theo lực tay (phương án C, `KeHoach_NguoiLai.txt`); khung DRIVER chạy xong D1-D7 (48 lần chạy). Kết luận: người lái lực tay đo trôi vòng hở, không trả lời câu hỏi đề tài; người dùng KHÔNG đưa mô hình người lái vào hướng chính. Khối Dynamic Steering của VDB đặt trợ lực trước thanh xoắn nên không dùng trực tiếp được.
- **11/11**: kế hoạch thân xe VDB (`KeHoach_VDB_ThanXe.txt`), khung VDB_BODY chạy xong: cùng giả thiết thì trùng Plant (vòng kín lệch ≤ 0.06 % với thân, ≤ 1.35 % với lốp cùng thân); thêm độ trễ lốp đổi E_RMS từ −7.7 % đến +5.0 %, thứ hạng giữ ở 10/12 ô. Đây là kiểm chứng cài đặt, không phải xác thực.
- **11-12/11**: bàn bộ điều khiển thứ tư (chấm 10 phương án, MapSTA điểm cao nhất); người dùng BỎ bộ thứ tư (nặng, kết quả chưa chắc). Thay bằng hai việc đào sâu, chạy song song trên PC:
  - Việc A, khung ROBUST (`KeHoach_DoBenThamSo.txt`): tám nhóm tham số xe ±20 %, 17 biến thể. Map đứng cuối ở mọi điều kiện; PID và MapPID giữ sai lệch tĩnh ≤ 0.56 % ở STEADY khi Map tới 92 %; E_RMS của PID, MapPID ở SLIP tăng tới 71.7 % và 76.6 % khi khối lượng +20 %.
  - Việc B, khung WEAVE (`KeHoach_WEAVE_HaiNhanh.txt`): MapPID kém PID 10.93 ± 1.06 % ở WEAVE; nhánh Map rất nhỏ; ba phép chẩn đoán (bỏ lag, bỏ lead và lag, vùng chết bằng 0) chỉ đóng tối đa 0.9 % khoảng cách; giả thuyết K3 (hệ số PID của MapPID khác PID riêng) chưa kiểm.
  - Dọn repo (đồ cũ chuyển vào `history/`, chưa commit); báo cáo thầy 14/11 `Week1411_baocao.docx`.
- **12-13/11**: viết luận văn từ đầu theo `DanY_LuanVan.md`: chương 1 (mở đầu từ thực tiễn, theo cách bài mẫu `References/luan_van_UP6.pdf`), chương 2 (mô hình hóa, mỗi công thức dẫn từ sách kèm số trang), chương 3 (ba bộ điều khiển, giới hạn tĩnh của Map), chương 4 (chọn tham số), chương 5 (kết quả, gồm 5.6 giải thích WEAVE, 5.7 độ bền tham số, 5.8 VDB ở mục cuối). Hình vẽ lại bằng MATLAB.
- **13/11**: khung ROBUST chạy thêm phép tách ma sát cột lái (`KeHoach_MaSatCotLai.txt`, Map với T_f = 0): ma sát khô là nguyên nhân của sai số tĩnh 26.2 % của Map ở CALIB (còn 6.0 % khi bỏ ma sát) và của độ lệch đổi dấu +11.6 %/−9.3 % ở SLIP (còn +1.5 %/+0.6 %). Viết vào mục 3.2, 3.6, 4.5, 4.6, 5.3, 5.9. Rồi hoàn thiện luận văn (chương 6, phần đầu, phụ lục, đánh số lại tài liệu) và commit, push.

---

## 5. Luận văn: hiện trạng

- 115 trang: phần đầu 19 trang (đánh số La Mã), thân 96 trang (đánh số từ 1).
- Bố cục: bìa, phụ bìa, trang Nhiệm vụ (trống), lời cam đoan, lời cảm ơn, tóm tắt tiếng Việt, abstract, mục lục, danh mục hình, bảng, ký hiệu, viết tắt; Chương 1 Tổng quan; 2 Mô hình hóa; 3 Chiến lược điều khiển; 4 Chọn tham số; 5 Kết quả đánh giá (5.1-5.9); 6 Kết luận và hướng phát triển; danh mục công trình; tài liệu tham khảo [1]-[28]; Phụ lục A (cửa sổ chấm), B (kết quả theo seed và theo biến thể), C (cách tái lập); lý lịch trích ngang.
- Tài liệu tham khảo ĐÃ ĐÁNH SỐ LẠI theo thứ tự xuất hiện (13/11). Mọi số [n] trong nhật ký cũ và ghi chú trước 13/11 là SỐ CŨ; bảng đổi nằm trong `DanY_LuanVan.md` (ví dụ Lee 2018 IEEE TCST cũ [1] nay [2], Pacejka cũ [12] nay [17], Rajamani cũ [13] nay [16], Åström-Hägglund cũ [14] nay [24], Mehrabi cũ [15] nay [3]).
- Cách dựng lại docx, pdf (cần Word):
  - `python tools/txt2docx.py Documents/Thesis/luanvan.txt Documents/Thesis/luanvan.docx --thesis`
  - `python tools/docx2pdf_word.py Documents/Thesis/luanvan.docx Documents/Thesis/luanvan.pdf --fields --save-docx` (`--fields` cập nhật mục lục, danh mục; `--save-docx` ghi lại docx đã cập nhật).
  - Phần đầu viết bằng các dòng chỉ thị `@@...` trong luanvan.txt (`@@SECTION`, `@@TOC`, `@@LOF`, `@@LOT`, `@@TAB`, `@@W`...), xem đầu `tools/txt2docx.py`.
- Số liệu trong chữ sinh bằng script, không gõ tay: `tools/make_ch5_numbers.py` (ra `Documents/Thesis/figures/ch5_numbers.csv`), bảng phụ lục bằng `tools/make_thesis_back.py`, đánh số tài liệu bằng `tools/renumber_thesis_refs.py`, hình bằng `tools/make_fig_thesis_ch<n>.m`.
- Ô trống người dùng phải điền: chuyên ngành, mã số (phụ bìa), bản Nhiệm vụ luận văn của Phòng Đào tạo, ngày ký cam đoan, lý lịch trích ngang.

---

## 6. Kết quả chính (để không phải tra lại)

- MapPID giảm E_RMS của Map 4.24 lần (STEADY), 3.51 lần (SLIP), 6.54 lần (WEAVE), không cần ước lượng hệ số bám. Cái giá: S (độ ồn mô-men trợ lực) tăng từ 0.20-0.29 lên 0.48-0.76 N·m.
- So với PID: MapPID bám ngang ở STEADY, tốt hơn 4.6 % ở SLIP, kém 10.9 % ở WEAVE; S thấp hơn 8.9 %, 1.6 %, 15.1 %.
- Map lệch +32.3 % ở mức giữ cua mạnh nhất (phần lớn do giới hạn độ dốc K_max), −13.9 % ở μ = 0.24 (trợ lực thừa). MapPID giữ sai lệch trong 0.43 % ở STEADY.
- CALIB: e_rel,max Map 26.2 % (do ma sát cột lái; 6.0 % khi T_f = 0), PID 2.1 %, MapPID 1.8 %.
- Độ bền ±20 %: Map cuối ở 27/27 điều kiện. VDB: trùng đối tượng tự viết trong 0.06 % và 1.35 %; độ trễ lốp đổi E_RMS −7.7 % đến +5.0 %.
- Cố ý KHÔNG đưa vào luận văn: E_RMS của PID, MapPID khi T_f = 0 (xe không ma sát không có thật; PID, MapPID kém hơn ở SLIP +27 %, +33 %, chưa rõ cơ chế); kết quả STEADY của phép ma sát (không rõ ràng); bản lốp có M_z; mô hình người lái; video 3D.

---

## 7. Các khung chat và nhật ký

Mỗi khung chỉ ghi nhật ký của mình; khung khác chỉ đọc. Khung đang dùng sau 31/10:

| Khung | Nhật ký | Việc | Trạng thái |
|---|---|---|---|
| VDB_TIRE | `historychat_vdb_tire.md` | lốp VDB, rồi định hướng chung và VIẾT LUẬN VĂN | tới Lượt 100 (13/11); khung chính hiện nay |
| VDB_BODY | `historychat_vdb_body.md` | thân xe VDB | xong (Lượt 4, 11/11) |
| ROBUST | `historychat_robust.md` | độ bền ±20 %, phép ma sát T_f = 0 | xong (Lượt 5, 13/11) |
| WEAVE | `historychat_weave.md` | giải thích MapPID kém PID ở WEAVE | xong (Lượt 5, 12/11) |
| DRIVER | `historychat_driver.md` | người lái lực tay | xong, không dùng (Lượt 3, 10/11) |
| COMMON | `historychat_common.md` | kế hoạch Plant_VDB | dừng ở Lượt 281 (06/11) |
| PAPER | `historychat_paper.md` | bài báo | dừng 31/10 |

Các khung cũ (Map, Linear, MapPID, SMC, MapSMC, PIDBOOK, PARETO, TESTCASE) thuộc giai đoạn chọn tham số trước 31/10.

---

## 8. Việc còn treo và quyết định chờ người dùng

1. Duyệt luận văn bản 1; điền các ô trống (mục 5).
2. Tên đề tài: đề tài đăng ký có "học tăng cường", luận văn không có RL; đang dùng tên làm việc "Trợ lực lái điện cột lái với nhánh phản hồi mô-men ghép song song bản đồ trợ lực" (dòng đầu luanvan.txt). Cần hỏi thầy và Phòng Đào tạo.
3. Mẫu trình bày của trường (lề, cỡ chữ, kiểu trích dẫn) chưa có; đang dùng bố cục thường gặp.
4. Lời cam đoan: câu cuối và có cần khai báo dùng công cụ AI không.
5. Có chạy phép thử K3 (MapPID với bảng Map bằng 0, WEAVE, năm seed) không, hay để là hướng phát triển (luận văn đang để là hướng phát triển).
6. Có commit việc dọn repo và các tín hiệu thô chưa commit không (mục 2).
7. Còn mở về kỹ thuật: ở cửa sổ CALIB 30 km/h 0.30 g, ma sát làm lệch khoảng 0.40 N·m, lớn hơn công thức tĩnh T_f/(1+K_max) = 0.26 N·m; cơ chế phần dư chưa tách (luận văn không nêu con số chặn này).

---

## 9. Quy tắc làm việc cần nhớ (tóm tắt, đầy đủ trong Tracking/CLAUDE.md và bộ nhớ của Claude)

- Trả lời và viết tài liệu bằng tiếng Việt; giải thích viết tắt ở lần đầu.
- Chỉ làm khi người dùng bảo rõ; câu hỏi không phải lệnh làm. Commit chỉ khi được bảo; khung VDB_TIRE không dùng `sync_repo.sh`.
- Kiểm mọi trích dẫn trong PDF gốc ở `References/` (tên file là tiêu đề bài, không phải tên tác giả); ghi số trang.
- Không lập luận từ kết quả các lần chạy trước; mọi lựa chọn mới cần nguồn, lý thuyết hoặc kế hoạch viết trước khi chạy.
- Hình luận văn vẽ bằng MATLAB; mở rộng ngoài bài báo phải có lý luận và nguồn; không chắc thì không nêu.
- `Documents/*.txt` ngắt dòng 180-200 ký tự (riêng luanvan.txt mỗi đoạn một dòng).
- Cuối mỗi lượt ghi một mục "Lượt N" vào nhật ký của chính khung; nén sau mỗi 10 lượt (khung VDB_TIRE nén lần cuối ở Lượt 95, lần tới ở Lượt 105).
