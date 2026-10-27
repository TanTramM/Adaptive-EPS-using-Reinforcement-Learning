# Adaptive C-EPS bằng Học tăng cường - Ghi chú làm việc

Luận văn Thạc sĩ (HCMUT, GVHD: TS. Phùng Thanh Huy, HV: Trần Minh Tân).
Đề tài: điều khiển trợ lực lái điện thích ứng (Adaptive C-EPS) khắc phục hiện
tượng trợ lực thừa (over-assist) khi hệ số bám mu thay đổi, dùng RL.

**THEO DÕI (3 khung chat chạy song song: Map, Linear, SMC; người dùng chốt phân vai 2026-10-09).** Thư mục `Tracking/` chỉ có các file `.md` sau: `CLAUDE.md` (file này, quy tắc chung; file `CLAUDE.md` ở gốc repo chỉ trỏ tới đây), `historychat_map.md` (nhật ký khung Map; đổi tên từ historychat_1.md ngày 2026-10-09), `historychat_linear.md` (nhật ký khung Linear: PI, PID, đổi tên từ historychat_2.md ngày 2026-10-09), `historychat_smc.md` (nhật ký khung SMC, tạo khi khung đó bắt đầu). Thêm `historychat_common.md` (nhật ký khung COMMON, người dùng chốt 2026-10-10): khung bao quát mọi mặt, không riêng bộ điều khiển nào; chứa bản NÉN kiến thức của ba khung, các vấn đề quy chuẩn đã thấy và việc treo chung; khung COMMON ghi ở đó, ba khung kia chỉ đọc file đó khi cần toàn cảnh (không bắt buộc đọc mỗi lần). Thêm `historychat_testcase.md` (khung TESTCASE, người dùng mở 2026-10-17): thiết kế ca thử, CALIB v2 trước rồi các ca chấm; mọi quyết định và bằng chứng về ca thử ghi ở đó; khung bộ điều khiển đọc file đó khi chọn lại tham số vì CALIB đã đổi. Thêm `historychat_paper.md` (khung PAPER, người dùng mở 2026-10-23): viết bài báo tiếng Anh `Documents/Paper/paper.txt`; trạng thái bài, dữ liệu dùng được, việc treo ghi ở đó (các lượt trước đó nằm trong historychat_common.md với nhãn [common_paper], Lượt 221-237). **ĐẦU MỖI PHIÊN: đọc nhật ký CỦA KHUNG MÌNH** (mục "TRẠNG THÁI HIỆN TẠI" và vài lượt cuối) trước khi làm việc. **CUỐI MỖI LƯỢT hỏi-đáp: thêm 1 mục "Lượt N" vào CHÍNH file nhật ký của khung mình** (và sửa mục "TRẠNG THÁI HIỆN TẠI" nếu có thay đổi). File của các khung kia CHỈ ĐỌC, không ghi. **MỖI LẦN BẮT ĐẦU LÀM VIỆC** (không chỉ khi trả lời câu hỏi) cũng đọc MỤC "Lượt" MỚI NHẤT (chỉ 1 mục) của nhật ký khung KIA (khung Linear đọc lượt mới nhất của khung Map và khung SMC) để xét có kinh nghiệm mới rút ra không (lỗi đã gặp, cách làm tốt, đổi tên hay sửa file dùng chung, quy ước mới); nếu có thì ghi vào mục Lượt của CHÍNH nhật ký khung mình (người dùng chốt 2026-10-08, sửa từ 5 mục xuống 1 mục). Người dùng thao tác nhiều khung cùng lúc nên các khung không được sửa chung một mục. **TỰ NÉN NHẬT KÝ SAU MỖI 10 LƯỢT (người dùng chốt 2026-10-10, mỗi khung chỉ nén file CỦA MÌNH):** file nhật ký có 3 phần theo thứ tự: TRẠNG THÁI HIỆN TẠI, BẢN NÉN (các lượt cũ gộp theo giai đoạn, kèm dòng "Nén lần cuối: Lượt N"), NHẬT KÝ NGUYÊN VĂN (đúng 5 lượt gần nhất). Sau khi ghi một mục "Lượt N", nếu N trừ số lượt ở dòng "Nén lần cuối" đạt 10 trở lên thì nén NGAY trong cùng lượt đó, theo thứ tự: (1) sao lưu bản đầy đủ ra `C:/Users/Admin/Desktop/Adaptive-EPS_backup_<ngày>_historychat_<khung>/` (file đã nằm trong git thì vẫn sao lưu); (2) giữ NGUYÊN VĂN 5 lượt cuối (chép y nguyên, không viết lại); (3) gộp mọi lượt cũ hơn (cả phần nguyên văn cũ lẫn BẢN NÉN cũ) vào BẢN NÉN, giữ quyết định, con số, tên file, lỗi đã gặp, bài học, việc còn treo, bỏ chi tiết trao đổi lặp; (4) hợp nhất TRẠNG THÁI HIỆN TẠI (một khối duy nhất, không xếp chồng nhiều khối "mới nhất"); (5) sửa dòng "Nén lần cuối: Lượt N" và ghi vào mục Lượt vừa viết là đã nén; (6) báo người dùng một dòng trong câu trả lời. File của khung khác không nén hộ.

Toàn bộ giao tiếp, tài liệu, code comment (nếu có) đều bằng **tiếng Việt**,
trừ tên biến/ký hiệu kỹ thuật giữ nguyên tiếng Anh/công thức gốc.

## Cấu trúc thư mục

Nguyên tắc: MỘT tên cho mỗi thành phần, dùng y hệt ở `Model/`, `Documents/Notes/` và `Result/` (Plant, Ref, Sensors, AssistLimit, Actuator, Map, PI, PID, SMC, RL). Phần dùng chung (PRSM, khung thử, hàm tiện ích) tách riêng khỏi phần của từng bộ điều khiển. Biến thể của một bộ điều khiển (ví dụ PI 2 bậc) KHÔNG đổi tên bộ điều khiển: là file dữ liệu riêng (`data/pi_2k.json`) và thư mục kết quả con (`Result/Controllers/PI/2K/`).

```
<repo>/
  Tracking/                CLAUDE.md + nhật ký từng khung: historychat_map.md (Map), historychat_linear.md, historychat_smc.md (xem trên)
  Model/                   Simulink + MATLAB (code .m bằng TIẾNG ANH)
    setup_paths.m          NƠI DUY NHẤT biết bố cục thư mục: chạy đầu phiên MATLAB, thêm mọi thư mục code vào path
    common/                hàm dùng chung: result_dir.m, save_run_results.m, sensor_noise_vars.m
    data/                  mọi file .json (nguồn dữ liệu duy nhất): params, plant_limits, ref, sensors, actuator, và của từng bộ điều khiển
    PRSM/                  MÔI TRƯỜNG dùng chung (Plant-Ref-Sensor-Motor = mọi phần trừ bộ điều khiển; không bộ điều khiển nào sửa)
      Plant/ Ref/ Sensors/ AssistLimit/ Actuator/    mỗi phần: model KHÔNG hậu tố (Plant.mdl, Tires.mdl, Reference.mdl ...), load_<phần>.m, script/ (build_, test_, make_)
    Sim/Gates.mdl          khối MATLAB Function đo chỉ tiêu và cổng khi calib (chỉ đọc tín hiệu, KHÔNG nằm trong model thật); sinh bằng Sim/script/build_gates.m từ gates_fcn.m, test_gates.m PASS
    Sim/script/            khung thử dùng chung: build_closed_loop.m (Plant -> Sensors -> bộ điều khiển -> Actuator), make_cases.m,
                           run_cases.m(ctrl, seed), make_pair_comparisons.m, plot_compare_cases.m, calib_*.m (chạy và chấm ca CALIB)
    Controllers/<Ctrl>/    MỖI bộ điều khiển 1 thư mục cùng cấu trúc: load_<ctrl>.m, <Ctrl>.mdl, Model_<Ctrl>.mdl (vòng kín, KHÔNG hậu tố _s), script/
  Documents/
    Thesis/                CHƯƠNG LUẬN VĂN (định dạng plant.txt, sinh .docx bằng tools/txt2docx.py): plant, ref, cases (ba ca DRY, SLIP, WEAVE), (map, pi, ... khi làm),
                           và Thesis.docx/pdf tổng
    Notes/PRSM/            ghi chép suy diễn của PRSM: Cum1_CEPS, Cum2_Pacejka, Cum3_2DOF, HeThongPlant_TongHop, ThucTeHoa
    Notes/Controllers/     kế hoạch, nhật ký thử của từng bộ điều khiển (DieuKhien_<Ctrl>.txt); LyThuyet_Map.txt = lý thuyết xây dựng Map từ đầu đến cuối kèm lý luận từng bước và hỏi đáp bảo vệ (viết 2026-10-09 theo yêu cầu người dùng; Map do khung Map làm; số liệu lấy từ map.txt và Result/Controllers/Map; viết lại 2026-10-12 cho Map lead-lag theo QuyChuan v5)
    Data/                  bảng tính: Params.xlsx, params_*.csv/xlsx, Reference.xlsx (và Map.xlsx khi làm)
    Shared/                QuyChuan.txt (QUY CHUẨN thiết kế và đánh giá chung, BẮT BUỘC), Blueprint_OverAssist_RL.txt, References.txt (danh mục tài liệu tham khảo DÙNG CHUNG), PhanBien.txt
    Paper/                 bài báo TIẾNG ANH, dọn ngày 2026-10-23 (bản sao lưu: Desktop/Adaptive-EPS_backup_2026-10-23_Paper_truoc_don): `paper.txt` là NGUỒN DUY NHẤT của bài (mục 1-3 viết mới theo hướng Map-PID-MapPID plug-in; mục 4-6 giữ nguyên bản cũ Map-PI-PID của thầy, đã đánh số lại phương trình, bảng, hình, tài liệu, CHỜ viết lại khi có kết quả); `paper.docx` sinh bằng `python tools/paper2docx.py Documents/Paper/paper.txt Documents/Paper/paper.docx` (một cột, đúng khuôn v5/v6: A4, Times 12, 1.5 dòng, căn đều, phương trình OMML), hình mục 1-3 ở Figures/new/main, hình kết quả ở Figures/matlab; `Simulation Setup and Evaluation Methodology.txt` là bản nháp mục 4 mới (CALIB v2, DREWS v2) để dùng khi có kết quả; giữ file của thầy: `paper_jstt_Tan_Huy.docx`, `2026.10.13_Paper_Tan - v5-Huypt.docx/.pdf`, `v6-Huypt.docx`; ghi chú kiểm chứng `intro_review.md`, `plant_review.md`, `control_review.md`; quy tắc tạp chí `JSTT_Rules.md` (bản nộp một cột như v5/v6 là đủ). MỖI dòng phương trình một số, LIÊN TỤC toàn bài.
    Report/                báo cáo TIẾNG ANH gửi thầy (MapPID_slides.pptx, MapPID_report.txt/docx), sinh bằng tools/build_report_en.py; hình ở Result/Report/
    Archive/               old/ (bản cũ của người dùng, không sửa); Gemini_old/ đã xóa 2026-10-08 (còn trong git)
  Result/                  soi gương Model/: PRSM/{Plant,Reference}/, Controllers/<Ctrl>/<Design|Calib|Cases>/, Compare/<A>_vs_<B>/
  Figures/                 hình của bài báo và luận văn (drawio, png), đặt tên Figure_<số>_<nội dung>.<drawio|png>, số theo thứ tự trong bài (Figure_1_steering_column, Figure_2_plant, Figure_3_tire_forces, Figure_4_brush_model, Figure_5_architecture); script sinh hình trong tools/make_fig_*.py
  References/              paper tham khảo (PDF)
  tools/                   txt2docx.py, reflow_txt.ps1, export_xlsx.py (còn đường dẫn Map cũ), build_map_txt.py (sinh chương map.txt và ba hình của Map từ csv và json; viết lại 2026-10-12 theo Map lead-lag v5)
  scratch/                 script thử, file tạm - KHÔNG commit (nằm trong .gitignore)
```

Thư mục gốc chỉ có các mục trên cùng `CLAUDE.md` (trỏ tới Tracking/), `README.md`, `.gitignore`; không để script lẻ ở gốc.

- Phần chương luận văn: `Documents/Thesis/plant.txt` là NGOẠI LỆ của quy tắc độ rộng dòng: mỗi đoạn văn 1 dòng (không ngắt 180-200), không dùng gạch đầu dòng, ký hiệu trong câu viết `$latex$`; sinh `plant.docx` bằng `C:/Users/Admin/anaconda3/python.exe tools/txt2docx.py <txt> <docx>` (tiêu đề `1.`/`1.1.` -> Heading 2/3, dòng `(n) ascii` + dòng `[ latex ]` -> phương trình Word đánh số, dòng `[Hình n: chú thích | Result/.../x.png]` chèn ảnh thật, đường dẫn tính từ gốc repo; không có `| đường dẫn` thì để khung trống chờ người dùng vẽ). Tương tự `ref.txt` (Mục 1: giá trị đặt T_d,ref + T_a,max), `cases.txt` (ba ca chấm DRY, SLIP, WEAVE và ca báo cáo EDGE; đổi tên từ `TestCases.txt` ngày 2026-10-10).
- Mọi bộ điều khiển đọc T_a,max từ `ref.json` qua `load_ref.m` (một nguồn duy nhất); giới hạn T_a,max (đã gồm dự phòng F = T_f) nằm ở khối `AssistLimit`, phép chặn và trễ motor ở khối `Actuator`; bộ điều khiển KHÔNG tự chặn và không giữ bản sao bảng T_a,max, bộ nào cần giá trị này khai báo cổng vào `T_a_max`.
- Cảm biến chỉ có 2 chế độ, KHÔNG còn khái niệm mức `low`/`high`: không truyền seed = cảm biến lý tưởng; truyền một seed = có nhiễu + lượng tử + chu kỳ cập nhật (`sensor_noise_vars(seed)`, `run_test_cases(ctrl, seed)`, `tk_run(mdl, seed, vars)`).
- Seed (5 chữ số, viết `seed_00000`; người dùng chốt 2026-10-07): chọn/chỉnh tham số (ca CALIB) mỗi bộ điều khiển dùng dải riêng, CHỈ 1 seed bắt đầu từ đầu dải: Map 00000-09999, PI 10000-19999, SMC 20000-29999, MapPID 30000-39999 (thêm 2026-10-13), MapPIDLag 50000-59999 (thêm 2026-10-16; 40000-49999 để dành cho khung MapSMC), RL chưa gán. Dải 99990-99994 (người dùng chốt 2026-10-22): năm seed CHUNG để so mặt Pareto của các bộ trên CALIB v2 (không phải ca chấm DREWS; xem Documents/Shared/KeHoach_SoMatPareto.txt). Ba ca chấm DRY, SLIP, WEAVE và ca báo cáo EDGE có nhiễu: CHỈ 1 seed chấm, giống nhau cho mọi bộ điều khiển, đếm lùi từ 99999 (99999, nếu cần thêm thì 99998...). Kết quả nằm chung một thư mục `Cases/`, phân biệt chế độ cảm biến bằng token cuối tên file (`s99999` có nhiễu seed 99999, `ideal` lý tưởng; xem mục 5). QUY TẮC THÊM (người dùng chốt 2026-10-08): khi chạy DRY, SLIP, WEAVE cho MỘT bộ điều khiển riêng lẻ thì dùng seed local của bộ đó (đầu dải: PI `s10000`, Map `s00000`, SMC `s20000`); seed chung 99999 CHỈ dùng khi so sánh nhiều bộ với nhau (`make_pair_comparisons`).
- Thứ tự chạy dữ liệu PRSM: `make_plant_limits` -> `make_ref_table` -> `make_ta_max`. Đầu phiên MATLAB: `run('<repo>/Model/setup_paths.m')`.
- Quy ước đường dẫn trong code: file trong `Model/PRSM/<Phần>/script/` và `Model/Controllers/<Ctrl>/script/` tính `modelDir = fileparts(fileparts(fileparts(scriptDir)))`; file trong `Model/Sim/script/` tính `fileparts(fileparts(scriptDir))`; rồi `addpath(modelDir); setup_paths;`. Dữ liệu đọc bằng `fullfile(modelDir, 'data', ...)`, kết quả ghi bằng `result_dir(...)`; không ghi đường dẫn cứng.
- Tài liệu cũ của các bộ điều khiển đã xóa ngày 2026-10-07 (làm lại từ Map); bản sao lưu ở `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-07`, kiến thức nằm trong `historychat_map.md`.

## Làm một bộ điều khiển: nơi đặt code, loại script, dựng model, đặt tên (người dùng yêu cầu ghi ngày 2026-10-10 để khung chat mới hiểu ngay)

**1. Nơi đặt (mỗi thứ đúng MỘT chỗ):**
- Code của bộ `<Ctrl>` (Map, PI, PID, SMC, RL): `Model/Controllers/<Ctrl>/` gồm `load_<ctrl>.m` (nạp biến), `<Ctrl>.mdl` (khối bộ điều khiển), `Model_<Ctrl>.mdl` (vòng kín chạy được), `script/` (MỌI script khác của bộ đó). Không để script lẻ ngoài `script/`, không để ở gốc repo.
- Dữ liệu: `Model/data/<ctrl>.json` là nguồn duy nhất của bộ (trường `calibration`, `design`...); mô hình Simulink và script chỉ ĐỌC từ đó, không giữ bản sao. Kết quả: `Result/Controllers/<Ctrl>/<Design|Calib|Cases>/`.
- Hàm dùng chung nhiều bộ: `Model/common/` (không chứa gì riêng một bộ) hoặc `Model/Sim/script/` (khung thử). Hàm chỉ của một bộ nằm trong `script/` của bộ đó (ví dụ `map_params.m`, `pi_margins.m`); chỉ đưa ra chung khi bộ thứ hai cần, và báo trong nhật ký.
- Môi trường dùng chung, không bộ nào sửa: `Model/PRSM/<Plant|Ref|Sensors|AssistLimit|Actuator>/`.
- Tài liệu: `Documents/Notes/Controllers/DieuKhien_<Ctrl>.txt` (kế hoạch và nhật ký thử), `LyThuyet_<Ctrl>.txt` (lý thuyết, nếu có), chương luận văn `Documents/Thesis/<ctrl>.txt` (chữ thường; sinh `.docx` bằng `tools/txt2docx.py`; số liệu trong chương sinh từ csv bằng `tools/build_<ctrl>_txt.py`, không gõ tay).
- Tạm: `scratch/` hoặc thư mục scratchpad của phiên, không commit. `Model/Controllers/` và `Result/Controllers/` hiện CHƯA vào git, nên xóa là không khôi phục được: sao lưu ra `C:/Users/Admin/Desktop/Adaptive-EPS_backup_<ngày>_<mô tả>` trước khi xóa hay đổi tên hàng loạt.

**2. Loại script (tên file = tên hàm, tiếng Anh, `snake_case`, dạng `<động từ>_<đối tượng>`):**
- `load_<ctrl>.m`: SCRIPT (không phải hàm) nạp biến vào base workspace, tiền tố biến là tên bộ (`Map_table`, `PI_Kp`), chạy các `load_` của PRSM cần thiết. Chạy trước khi dựng hay mô phỏng.
- `build_<x>.m`: dựng `.mdl` bằng API, dạng `name = build_x(overwrite)`; `overwrite=false` không ghi đè (sinh `<tên>_1`), `true` chỉ khi người dùng nói rõ.
- `test_<x>.m`: kiểm MỘT thứ, tự chứa, tính đáp án độc lập (đọc thẳng `params.json`, không lấy giá trị tính sẵn ở base workspace), cổng tìm THEO TÊN, in `[<Tên>] TEST PASS`; mỗi model đúng một file test.
- `calibrate_`, `design_`, `select_`: tính điểm hiệu chỉnh, chọn tham số theo quy tắc chung (mục dưới). `run_<...>_sweep`, `scan_`: quét lưới, ghi từng dòng ra csv để chạy tiếp được (resumable). `plot_`, `make_`: hình, bảng, file dữ liệu. Hàm phụ chỉ dùng trong một file đặt cuối file đó.
- Đầu mỗi script: `scriptDir = fileparts(mfilename('fullpath')); modelDir = ...; addpath(modelDir); setup_paths;` (số lớp `fileparts` xem mục cấu trúc), đọc dữ liệu bằng `fullfile(modelDir, 'data', ...)`, ghi kết quả bằng `result_dir(...)`; không ghi đường dẫn cứng.

**3. Dựng model, theo thứ tự:**
1. `load_<ctrl>` nạp biến. 2. `build_<ctrl>` sinh `<Ctrl>.mdl`: subsystem gốc tên đúng tên bộ; cổng vào đọc THEO TÊN trong số `T_s, theta1, theta2_dot, v, gamma, a_y, T_a_lim, T_a_max` (chỉ khai báo cổng cần dùng, cổng không khai báo được nối Terminator); cổng ra duy nhất `T_a`; theo "Quy tắc dựng model Simulink" bên dưới. 3. `test_<ctrl>`: so Simulink với phép tính độc lập. 4. `build_closed_loop('<Ctrl>')` sinh `Model_<Ctrl>.mdl` (Plant -> Sensors -> bộ -> AssistLimit -> Actuator, có `StopFcn` lưu kết quả). 5. Chạy: `calib_run(mdl, seed, vars)` trên ca CALIB (tham số truyền bằng `setVariable`, không đổi model), `run_cases(ctrl, seed)` trên DRY, SLIP, WEAVE, `make_pair_comparisons` để so nhiều bộ. KHÔNG có hậu tố `_s` ở bất kỳ model nào (bỏ 2026-10-09).

**4. Script phụ dùng chung (dùng lại, đừng viết lại):** `Model/setup_paths.m` (path, nơi duy nhất biết bố cục); `common/result_dir.m` (đường dẫn kết quả), `save_run_results.m`, `pick_model_name.m` (tên model không ghi đè), `pick_by_tolerance.m` (quy tắc chọn: R trong 5 % rồi S nhỏ nhất), `sensor_noise_vars.m` (seed -> nhiễu cảm biến), `sensor_tag.m` (seed -> token `ideal`/`s00000` trong tên file); `Sim/script/`: `make_cases.m` (ca CALIB và DRY, SLIP, WEAVE, EDGE), `calib_run.m` (chạy CALIB, trả R, S, e_rel...), `calib_score.m` và `calib_block_scores.m` (tính điểm), `calib_bangbang.m` (cổng không bang-bang), `calib_margin.m` (dự trữ ổn định bằng mô phỏng), `gates_fcn.m` + `build_gates.m` + `Gates.mdl` (đo chỉ tiêu trong mô phỏng), `run_cases.m`, `make_pair_comparisons.m`, `plot_compare_cases.m`, `build_closed_loop.m`, `test_calib.m`; `tools/`: `txt2docx.py`, `reflow_txt.ps1`, `export_xlsx.py` (đường dẫn Map cũ, sửa khi dùng).

**5. Đặt tên file, thư mục, biến:**
- **QUY TẮC ĐẶT TÊN (người dùng chốt 2026-10-10, áp dụng cho MỌI file, hình, thư mục kết quả và script):**
  - **Token** (mỗi token viết liền, KHÔNG chứa `_`; `_` chỉ để ngăn cách các token): bộ điều khiển `Map`, `PI`, `PID`, `SMC`, `ISMC`, `MapPID`, `MapPIDLag`, `RL`; phần PRSM `Plant`, `Ref`, `Sensors`, `AssistLimit`, `Actuator`; **ca thử VIẾT HOA**: `CALIB` (ca chọn tham số, không chấm điểm), `DRY` (chính xác tĩnh trên đường khô, mu = 0.8), `SLIP` (mu đổi khi đang cua), `WEAVE` (lái liên tục: lượn, chuyển làn, mặt trơn), `EDGE` (vùng cực trên 0.3 g, đường khô; CHỈ BÁO CÁO, không là cổng, thêm 2026-10-11), `RAMP` (đổi vận tốc khi đang cua, đường khô; CHỈ BÁO CÁO, thêm 2026-10-11; bộ năm ca gọi tắt DREWS = DRY, RAMP, SLIP, EDGE, WEAVE); **cảm biến**: `ideal` (không seed) hoặc `s` + seed 5 chữ số (`s00000`, `s10000`, `s99999`; hàm `sensor_tag.m`); điều kiện số viết `0p8`, `v60`, `mu0p3`, `a0p2`.
  - **Cảnh và cửa sổ trong ca** (chữ thường, tối đa 5 ký tự): SLIP có `down` (mu giảm khi cua 0.3 g ở 100 km/h; 0.35 g trước 2026-10-11), `pud` (vũng nước khi đổi làn), `up` (mu tăng); RAMP có `lo`, `mid`, `hi` (a_y 0.15, 0.225, 0.275 g), cửa sổ `<cảnh>_dn` (giảm tốc độ) và `<cảnh>_up` (tăng lại); WEAVE có `slal` (lượn), `lane` (chuyển làn), `ice` (sin trên mu 0.2); cửa sổ đặt `<cảnh>_pre`, `<cảnh>_in`, `<cảnh>_post`; DRY đặt `v<km/h>a<g>` kèm chiều `l`/`r`, ví dụ `v40a0p2r`; riêng CALIB v2 (140 s, người dùng chốt 2026-10-17, thay CALIB v1 117 s) dùng `static_v<km/h>_a<g>` (1 s cuối của mỗi mức giữ cua 0.1-0.3 g, vào cổng e_rel và nhóm static), `trans_v<km/h>_a<g>` (dốc + 1 s đầu, nhóm dyn), `sine_v<km/h>_f0p5` và `sine_v<km/h>_f1` (sin qua 0 tại 0.5 và 1 Hz, từ 40 km/h, nhóm dyn), `mu_drop`, `mu_rise` (nhóm mu); các hàm chấm điểm dựa vào tiền tố này; không còn `ext_*` và `small_*`.
  - **Tên file kết quả**: `<Chủ>_<CA>_<nội dung>[_<cảnh>]_<sens>.<đuôi>`; `<Chủ>` là bộ điều khiển, phần PRSM, hoặc so sánh `<A>_vs_<B>`; bỏ `<CA>` khi kết quả không gắn với ca (đồ thị Bode); bỏ `<sens>` khi không chạy mô phỏng. Token `<nội dung>` (chữ thường, ngắn): `resp` (hình đáp ứng 6 ô theo thời gian), `sig` (bảng tín hiệu), `metrics` (bảng chỉ tiêu), `cmp` (hình so sánh T_s, e_T, T_a của nhiều bộ), `bars` (cột RMS e_T và TV), `runs`, `summary` (bảng nhiều lần chạy), `zoom` (phóng một cảnh), `sweep` (bảng quét tham số, hậu tố tùy chọn như `grid1`), `fine` (quét mịn), `pareto`, `pick` (điểm chọn và các cổng), `sens` (độ nhạy), `gates`, `bangbang`, `bode`. Ví dụ: `Map_SLIP_resp_s00000.png`, `PI_DRY_sig_ideal.csv`, `PID_WEAVE_metrics_s10000.csv`, `Map_vs_PI_SLIP_cmp_s99999.png`, `Map_vs_PI_bars_s99999.png`, `SMC_CALIB_sweep_s20000.csv`, `PI_CALIB_pick_s10000.csv`, `PI_bode_mu0p8.png`.
  - **Thư mục kết quả**: `Result/Controllers/<Ctrl>/Design/` (phân tích không cần chạy ca: hiệu chỉnh, Bode, biên ổn định), `Calib_v2/` (quét và chọn tham số trên CALIB v2, từ 2026-10-17; trong code vẫn gọi `result_dir(ctrl, 'Calib')`, hàm này trả về `Calib_v2`; thư mục `Calib/` trên đĩa giữ kết quả CALIB v1, chỉ để tái lập bài báo cũ, gọi bằng `result_dir(ctrl, 'CalibV1')`, không ghi vào, không đọc để chọn tham số), `Cases/` (DRY, SLIP, WEAVE, mọi chế độ cảm biến trong cùng thư mục, phân biệt bằng token `<sens>`), `Result/Compare/<A>_vs_<B>/` (luôn `s99999`).
  - **Script** (tên file = tên hàm, `snake_case`, dạng `<động từ>_<đối tượng>`, tiếng Anh; trong code tên ca là chuỗi HOA như `'SLIP'`, còn tên hàm và biến viết thường): `make_cases.m` (sinh ca, trước là `test_cases.m`), `run_cases.m` (chạy ba ca chấm điểm và ca EDGE, trước là `run_test_cases.m`), `calib_run.m`, `calib_score.m`, `calib_block_scores.m`, `calib_bangbang.m`, `calib_margin.m` (trước là `tk_*.m`), `test_calib.m` (kiểm thử ca CALIB, trước là `test_tk.m`). Trường dữ liệu trong `data/*.json` đổi `TK_*` thành `CALIB_*`.
  - **Bảng đổi tên cũ sang mới** (nhật ký `Tracking/historychat_*.md`, `Documents/Notes/Controllers/DieuKhien_*.txt` và các ghi chép lịch sử GIỮ tên cũ, không sửa): TK -> CALIB; TC1 -> DRY; TC3, TC4, TC6 -> các cảnh `down`, `pud`, `up` của SLIP; TC5 và các đoạn lái của TC2 -> các cảnh `ice`, `slal`, `lane` của WEAVE; TC2 (hành trình 150 s) bỏ khỏi phần chấm điểm; `TestCases/`, `TestCases_noise/seed_NNNNN/`, `Sweep/` -> `Cases/`, `Calib/`. Các file phân tích cũ trong `Design/` của Map (`Map_step2_*`, `Map_step3_*`, `Map_calibration_*`) giữ tên cũ cho tới lần sinh lại.
- Biến thể của một bộ (một bậc, hai bậc) là trường trong file `.json` hoặc thư mục con, KHÔNG phải bộ mới và không thêm hậu tố `_s`, `_old`, `_new`, `_v2` vào tên model hay file.
- Tên khối Simulink theo "Quy tắc dựng model Simulink" bên dưới; tên cổng là tên tín hiệu vật lý (`T_s`, `v`, `T_a`).
- Code và comment trong `.m` bằng tiếng Anh; `.txt`, `.md`, hội thoại bằng tiếng Việt.

**6. Kinh nghiệm công cụ (đã gặp thật, Windows):**
- MATLAB gọi nền: `"/c/Program Files/MATLAB/R2023a/bin/matlab" -softwareopengl -batch "run('<đường dẫn TUYỆT ĐỐI>\Model\setup_paths.m'); ..."`; `run()` đổi thư mục hiện tại nên không dùng đường dẫn tương đối. Có hình thì dùng `-softwareopengl` và `Visible off`. Lỗi heap corruption khi thoát MATLAB vô hại nếu dữ liệu đã ghi. Không đặt biến vòng lặp trùng tên biến base workspace của model (từng đè `c`, độ dốc của ma sát). Với `fsolve`, kiểm phần dư thật chứ không tin cờ hội tụ, và dùng phần dư không thứ nguyên.
- Python: `C:/Users/Admin/anaconda3/python.exe -I` với `PYTHONIOENCODING=utf-8`; ghi file UTF-8 bằng công cụ Write, không dùng heredoc cho chuỗi có `\n`, dấu gạch ngược hay ngoặc (shell làm sai chuỗi). Đo độ rộng dòng `.txt` bằng ký tự (Python), không bằng `awk` (đếm byte).
- Nhật ký lớn: đọc bằng `grep` tiêu đề rồi `Read` với `offset`/`limit`.

## Quy tắc chọn tham số và so sánh các bộ điều khiển (người dùng chốt 2026-10-08, áp dụng cho MỌI bộ)

**BẮT BUỘC: mỗi lần thiết kế hoặc chỉnh một bộ điều khiển (Map, PI, PID, SMC, RL) phải đọc và tuân theo `Documents/Shared/QuyChuan.txt` (quy chuẩn thiết kế và đánh giá chung, phiên bản 6, 2026-10-17: ca CALIB v2 140 s (chín khối tốc độ 20-100 km/h bước 10: bậc giữ cua 0.1-0.3 g, sin qua 0 từ 40 km/h, bậc mu), R là trung bình nhân ba nhóm static, dyn, mu với sàn 1 %, ba ca chấm DRY, SLIP, WEAVE và hai ca báo cáo RAMP, EDGE, cổng ổn định đo bằng mô phỏng, thứ tự cổng; kết quả CALIB cũ là CALIB v1 và không so được với v2); mục này chỉ là bản tóm tắt, nếu mâu thuẫn thì QuyChuan.txt ưu tiên. Mục nào trong đó đánh dấu [CẦN CHỐT] phải được người dùng chốt số trước khi dùng.**

Mục tiêu: kết quả so sánh không phụ thuộc vào việc người làm chọn ngưỡng nào. Giải thích chi tiết và ví dụ số: `Documents/Notes/Controllers/DieuKhien_PI.txt`, mục A9 và B4.

- **Chỉ tiêu:** R (RMS của e_T, độ bám) và S (RMS của T_a sau lọc cao qua 5 Hz, độ ồn) đo trên ca CALIB (`calib_run.m`), cùng seed local của bộ điều khiển, trên tín hiệu THẬT. Mỗi bộ quét tham số cho ra một mặt Pareto (R, S).
- **Cổng chung cho mọi bộ, đặt trước khi chạy:** ổn định, PM >= 45 độ ở mọi giao cắt độ lợi, GM >= 2 (PM, GM tuyến tính tính trên hai mặt đường k_r = 30 và 0 nay chỉ để báo cáo; cổng ổn định đo bằng mô phỏng, QuyChuan 5.2), sai số xác lập e_rel <= 10 % (đổi từ 5 % ngày 2026-10-18, người dùng chốt, tìm lại cả Map, PID, MapPID, xem Documents/Shared/PhuongPhap_TimThamSo.txt mục 13; 5 % từ 3 % ngày 2026-10-11; đo bằng mô phỏng, lớn nhất trên 26 cửa sổ static 0.1-0.3 g của CALIB v2; 0.35-0.4 g chỉ báo cáo qua ca EDGE). Không thêm hay đổi cổng sau khi đã thấy kết quả; nếu buộc phải đổi thì ghi trung thực lý do và thời điểm.
- **Kết luận chính của một phép so sánh = so cả mặt Pareto**, không chọn điểm: mặt của A nằm hẳn dưới mặt của B thì A tốt hơn với mọi quy tắc chọn; hai mặt cắt nhau thì báo "A tốt hơn khi ưu tiên êm, B khi ưu tiên bám" kèm điểm cắt; dải S không chồng nhau thì nói thẳng là không so trực tiếp được.
- **Điểm chạy DRY, SLIP, WEAVE của mỗi bộ (QuyChuan 6.2 phiên bản 5, người dùng chốt 2026-10-11; thay quy tắc 5 % cũ):** trong các điểm đạt cổng cứng (ổn định có độ dư, e_rel) và ràng buộc dải lái, chọn điểm cực tiểu J = R x S (hàm `Model/common/pick_by_balance.m`, a = 1; báo độ nhạy a = 0.5, 2 và quy tắc cũ `pick_by_tolerance.m`). Ràng buộc dải lái: khâu lọc hoặc làm chậm trong bộ điều khiển giữ độ lợi >= 0.707 (-3 dB) tại 2 Hz (dải lái 0.2-2 Hz, Nguyen 2025); Map = khâu lag, PID = Tf của khâu D, SMC = lớp biên hoặc bộ lọc. Lý do: J đơn lẻ làm Map chậm đi (không có cực tiểu bên trong).
- **Bang-bang: CHỈ BÁO CÁO, không còn là cổng (người dùng chốt 2026-10-11, QuyChuan 5.4):** báo f lý tưởng, f có nhiễu, Delta (trung bình hai seed), độ phân tán seed, S_cmd và TV cho điểm đã chọn (`Model/Sim/script/calib_bangbang.m`); điểm chọn không đổi vì J = R x S đã phạt độ ồn.
- **Ngưỡng hòa:** chênh lệch nhỏ hơn mức đặt trước (mặc định 5 %, hoặc độ lệch giữa các seed) thì coi là ngang nhau, không nói bộ nào hơn.
- **Cùng công sức thiết kế:** cùng cổng, lưới quét mịn tương đương, cùng cách chọn seed (1 seed local đầu dải), chỉnh trên CALIB rồi chấm trên DRY, SLIP, WEAVE, báo số tham số chỉnh của mỗi bộ.
- **Không thêm phần ngoài lõi cho bộ nào:** không lọc đo T_s, không notch, không feedforward theo góc/tốc độ vô-lăng (người dùng chốt: quá phức tạp). Nguyên tắc: thứ gì Map làm được thì PID/PI cũng được làm, và ngược lại. Bộ lọc bậc 1 BÊN TRONG khâu D của PID (hằng số Tf) là một phần của khâu D, được phép (dùng để chống bang-bang); Map có sẵn tương đương trong khâu lead (s/z + 1)/(s/p + 1) có cực p, nên không cần đối ứng riêng.
- **Số bậc/lập lịch theo vận tốc** (PI_2K; Map đã bỏ bản hai bậc ngày 2026-10-09 vì suy biến thành một bậc): chỉ giữ nếu bản nhiều bậc đạt cổng "đáng giá" đặt trước: R giảm ít nhất 5 % mà S không tăng so với bản một bậc của chính bộ đó. Hai bộ có quyền như nhau.

## Triết lý làm việc (QUAN TRỌNG - áp dụng cho MỌI việc, không riêng vật lý)

**"Làm tới đâu thêm tới đó, không thêm trước".** Không tự ý mở rộng, không
suy diễn/code trước phần chưa được yêu cầu, không thêm tính năng/giải thích
"phòng khi cần sau". Nếu phát hiện một phần còn thiếu logic hoặc bị hoãn vô
lý, NÊU RA để hỏi, không tự ý làm luôn.

## Quy ước 1 file "cụm" vật lý (Cum1/2/3, và các file tương tự sau này)

Mỗi file cụm có đúng 2 phần:

1. **Phần suy diễn** (đầu file): suy đầy đủ từ nguyên lý vật lý gốc (động
   năng + Lagrange, hoặc Newton trực tiếp) - dùng để NGƯỜI VIẾT tự kiểm
   chứng, KHÔNG chép nguyên vào luận văn.
2. **"KẾT QUẢ ĐƯA VÀO LUẬN VĂN"** (cuối file): bản rút gọn, chia thành đúng
   vài "Mục" nhỏ, mỗi Mục là 1 bước logic độc lập (vd Mục 1: PT tổng quát,
   Mục 2: khai triển 1 số hạng, Mục 3: ghép biến trạng thái). Đây là phần
   thực sự dùng khi viết luận văn.

Quy tắc bắt buộc trong phần "KẾT QUẢ":
- Mọi công thức có toán tử/ký hiệu đều kèm 1 dòng LaTeX trong ngoặc vuông
  `[ ... ]` ngay dưới dòng ASCII, để dán trực tiếp vào Word (Insert Equation,
  chế độ nhập LaTeX, Word 2016+). Không bỏ sót dòng LaTeX cho bất kỳ công
  thức nào xuất hiện trong phần này.
- Phân biệt rõ 2 loại ký hiệu: **THAM SỐ THÔ** (lấy thẳng từ Bảng 3.1, không
  khai triển thêm được, giữ nguyên xuyên suốt kể cả bản khai triển đầy đủ) và
  **KÝ HIỆU GỘP** (do chính file định nghĩa, vd J_total, B_total - khai triển
  được và bị thay thế khi khai triển).
- Mọi đại lượng được TÍNH RA trong cụm đó (kể cả đại lượng trung gian dùng ở
  bước suy diễn khác, như a_y ở Cụm 3) đều phải xuất hiện thành 1 phương
  trình riêng trong "KẾT QUẢ" nếu nó còn được dùng ở chỗ khác (cụm khác, hoặc
  bước điều khiển sau) - không được để "biến mất" chỉ vì nó là bước trung
  gian trong suy diễn.
- Đầu mỗi file: khai báo rõ biến trạng thái (nếu có), đầu vào/đầu ra, và một
  đoạn ngắn nêu cụm này khớp vào đâu trong vòng lặp 3 cụm (input lấy từ cụm
  nào, output đưa sang cụm nào).
- Không lặp lại suy diễn đã có ở cụm khác (vd phương trình hình học delta_f
  chỉ xuất hiện ở Cụm 2 - nơi nó THỰC SỰ được dùng - dù về mặt cơ khí nó phát
  sinh từ Cụm 1).

## Quy tắc diễn đạt (trả lời và tài liệu)

- Mọi từ viết tắt hoặc thuật ngữ chuyên ngành phải được GIẢI THÍCH ngay lần đầu xuất hiện (viết đầy đủ + một câu nói nghĩa là gì), ví dụ "Ziegler-Nichols (ZN, quy tắc chỉnh PID đơn giản: ...)". Không xếp nhiều viết tắt liền nhau trong một câu; ưu tiên câu văn thường. Ký hiệu toán (K_eff, tau_c...) nêu ý nghĩa vật lý bên cạnh.

## Quy tắc định dạng file `.txt` trong `Documents/`

**Độ rộng dòng: 190 ký tự (+-10%, tức 180-200).** Người dùng đọc các file này
trong editor rộng, nên KHÔNG xuống dòng sớm ở khoảng 80 ký tự - làm vậy khiến
mỗi đoạn dài ra theo chiều dọc và trống 1 bên màn hình.
- Chỉ được xuống dòng khi dòng đã đạt **ít nhất 180** ký tự và **không quá
  200** ký tự. Ngắt ở ranh giới từ gần 190 nhất (tùy độ dài từ, miễn nằm
  trong 180-200), không cắt giữa từ, giữa ký hiệu, hay giữa công thức.
- Áp dụng cho MỌI đoạn văn xuôi trong `.txt` khi tạo mới hoặc sửa. Khi sửa
  1 đoạn có sẵn, gộp/ngắt lại cả đoạn theo quy tắc này, không để lẫn dòng
  ngắn cũ với dòng dài mới.
- KHÔNG áp dụng cho: dòng đầu mục hoặc dòng gạch ngang phân cách (`----`,
  `====`, tiêu đề mục), dòng công thức ASCII và dòng LaTeX `[ ... ]` (mỗi
  công thức giữ 1 dòng riêng như quy ước file cụm), bảng, danh sách ngắn mỗi
  mục 1 dòng, và dòng thụt lề của danh sách con (giữ thụt lề khi ngắt dòng
  tiếp theo của cùng mục).
- Dòng gạch ngang phân cách dài đúng khoảng 190 ký tự để làm thước đo trực
  quan (người dùng đã kiểm tra: dòng 190 gạch ngang vừa chạm gần cuối màn
  hình).
- Không đo bằng mắt: khi ghi file, kiểm tra lại bằng lệnh đếm độ dài dòng
  trước khi báo xong. Phải đếm KÝ TỰ, không đếm byte (tiếng Việt có dấu chiếm
  nhiều byte/ký tự) - ví dụ PowerShell: `Get-Content -Encoding UTF8 file.txt |
  ForEach-Object { $_.Length }`.

## Quy tắc lưu kết quả (`Result/`)

- Mọi kết quả (hình `.png`, bảng `.csv`, `.mat`) lưu dưới `Result/` ở thư mục gốc, bố cục soi gương `Model/`: `Result/PRSM/Plant/`, `Result/PRSM/Reference/` (kết quả của môi trường), `Result/Controllers/<Ctrl>/<mục>/` (kết quả của MỘT bộ điều khiển: Design = phân tích không cần chạy ca, Calib = quét và chọn tham số trên CALIB, Cases = chạy DRY, SLIP, WEAVE), `Result/Compare/<A>_vs_<B>/` (so sánh nhiều bộ điều khiển, ví dụ `Map_vs_PI`). Bộ điều khiển mới thêm thì tự có `Result/Controllers/<Tên>/`. Biến thể là thư mục con (`Result/Controllers/PI/2K/`).
- Tên file theo quy tắc đặt tên ở mục 5 của phần "Làm một bộ điều khiển", ví dụ `Map_SLIP_resp_s00000.png`, `Map_vs_PI_bars_s99999.png`, `Reference_Ta_max_by_speed_mu0p8.csv`; điều kiện số dùng `0p8` thay dấu chấm.
- Mọi script xuất kết quả dùng `Model/common/result_dir.m` để lấy đường dẫn (chỗ DUY NHẤT biết gốc và bố cục `Result/`) và `Model/common/save_run_results.m` để xuất tín hiệu + hình một lần chạy; KHÔNG ghi đường dẫn cứng. Model `Model_<Ctrl>.mdl` có `StopFcn` tự gọi `save_run_results` khi chạy tay (file `<Ctrl>_manual_run_*`), nên `ReturnWorkspaceOutputs = off`; script chạy model bằng `sim(Simulink.SimulationInput(tên))` để luôn nhận được đối tượng kết quả.

## Quy tắc dựng model Simulink (áp dụng cho MỌI `build_*.m` trong `Model/`)

Toàn bộ quy tắc dưới đây rút ra TỪ bản người dùng tự format tay
(`Model/PRSM/Plant/Tires.mdl`) - đó là CHUẨN phong cách. Script `build_*.m` phải
sinh ra đúng cấu trúc đó; riêng vị trí/kích thước khối thì người dùng tự sắp
lại, script chỉ cần đặt hợp lý.

Model PRSM (Plant, SteeringColumn, Tires, Bike2DOF, Reference, Sensors, AssistLimit, Actuator) sinh bằng script `build_*.m` (Simulink API) và lưu với tên CHÍNH THỨC,
KHÔNG hậu tố `_s` (quyết định 2026-10-07: người dùng không sửa model PRSM nữa; nếu sửa thì sửa thẳng trên file chính thức). Mỗi `build_*` là hàm
`name = build_x(overwrite)`: `overwrite=false` (mặc định) KHÔNG ghi đè - nếu `Tires.mdl` đã có thì sinh `Tires_1.mdl` (rồi `_2`...) qua
`Model/common/pick_model_name.m`; `overwrite=true` mới ghi đè. Chỉ chạy `overwrite=true` khi người dùng nói rõ. `build_plant` luôn sinh lại 3 cụm rồi lắp BẢN VỪA SINH (bản mới nhất) vào Plant. (Model bộ điều khiển cũng không hậu tố: `<Ctrl>.mdl`, `Model_<Ctrl>.mdl`; người dùng chốt 2026-10-09, thay cho `_s` cũ.)

**1. Phân cấp: 1 subsystem cho MỖI ĐẠI LƯỢNG CÓ TÊN trong phương trình**
- Cụm = 1 subsystem gốc (`Tires`, `SteeringColumn`).
- Trong cụm, tách subsystem con theo từng "Mục"/phương trình của file cụm
  (`SlipAngles`, `TireForces`, `AligningTorque`).
- Trong mỗi mục, tách TIẾP: mỗi đại lượng CÓ TÊN trong phương trình (`D`,
  `B`, `F_yf`, `F_yr`, `T_s`...) có 1 subsystem riêng tính ra nó.
- Đại lượng trung gian KHÔNG có tên trong phương trình (t1..t4 của Magic
  Formula) để nguyên trong subsystem, KHÔNG tách thêm.
- Tên subsystem = ĐÚNG tên đại lượng nó tính ra (`D`, `B`). Nếu tên đó trùng
  tên 1 cổng ở cùng cấp thì thêm tiền tố `Cal ` (`Cal F_yf`, `Cal F_yr` - vì
  `TireForces` đã có cổng ra tên `F_yf`, `F_yr`).

**2. Đại lượng bất biến theo thời gian: đọc thẳng, KHÔNG truyền cổng**
- Đại lượng đã tính sẵn 1 lần trong `load_derived.m` (vd `F_zf`) đặt 1 khối
  Constant NGAY TẠI subsystem cần dùng - KHÔNG tạo cổng ra rồi nối vòng qua
  nhiều cấp. Cần ở 2 nơi thì đặt 2 khối Constant riêng.

**3. Đặt tên khối**
- Cổng In/Out: tên CÓ NGHĨA, đúng tên biến vật lý (`theta2`, `alpha_f`,
  `T_s`). Đây là giao diện công khai, `test_*.m` dò theo tên này.
- Khối tính toán: CÓ đặt tên, theo mẫu:
  - `Prod_<kết quả hoặc toán hạng>`: `Prod_D`, `Prod_CD`, `Prod_u`, `Prod_lfg`
  - `Div_<kết quả>`: `Div_B`, `Div_delta_f`, `Div_lfg_v`, `Div_Ktr`
  - `Sum_<kết quả>`: `Sum_af`, `Sum_ar`, `Sum_t1`, `Sum_ep`
  - `Trig_<hàm>_<đối số>`: `Trig_atan_u`, `Trig_tan_af`, `Trig_sin_t4`
  - `Sign_<đối số>`: `Sign_af`
  - `Int_<biến trạng thái>`: `Int_x1`, `Int_x2`
- Khối Constant: ĐỂ TÊN MẶC ĐỊNH (`Constant`, `Constant1`, ...). Chỉ đặt
  `Value` trỏ THẲNG tên biến base workspace. Mỗi lần dùng 1 tham số là 1
  khối Constant riêng, không chia sẻ.
- Khối Goto/From: ĐỂ TÊN MẶC ĐỊNH (`Goto`, `Goto1`, `From`, `From1`, ...).

**4. Goto/From**
- Dùng cho MỌI đại lượng CÓ TÊN (biến riêng) được tạo ra và dùng ở nơi khác
  trong cùng 1 cấp - KỂ CẢ khi chỉ có 1 đích đến (vd `delta_f` trong
  `SlipAngles`). BỎ HẲN quy tắc cũ "phải ≥2 đích đến mới tạo tag" - hễ đại
  lượng có tên riêng trong công thức là tạo Goto/From, không đếm số đích.
  Mục đích: mỗi phương trình đứng độc lập về hình ảnh, không có dây dài cắt
  ngang sơ đồ.
- Tag = ĐÚNG tên biến, KHÔNG thêm hậu tố (`gamma`, `v`, `beta`, `delta_f`,
  `D`, `B`, `T_s`). Không dùng `_s`, `_sig`.
- Luôn `TagVisibility = 'local'`. Nhờ local mà tag trùng tên ở các cấp khác
  nhau không va chạm.

**5. Chọn khối theo phép toán, không gom biểu thức**
- Nhân/chia: khối `Product` (chia = `Inputs='*/'`). KHÔNG dùng `Gain`.
- `sin`/`atan`/`tan`/`tanh`: khối `Trigonometric Function`. `sgn(.)`: khối
  `Sign`. `|.|`: khối `Abs`.
- Ưu tiên khối cơ bản để sơ đồ TRỰC QUAN (nhìn ra công thức). Người dùng KHÔNG
  cấm `MATLAB Function`: chỗ nào dựng bằng khối cơ bản quá phức tạp (logic
  nhiều nhánh, công thức còn đang thử nghiệm hay đổi nhiều, ví dụ hàm phần
  thưởng của RL) thì được dùng, nêu lý do trong comment của build script.

**6. Bố cục (layout) - script CŨNG phải tuân theo, không chỉ để dành cho bản
format tay**
- Kích thước khối GIỮ NGUYÊN mặc định - CHỈ dịch vị trí (`moveBlock()`),
  không kéo dãn/co khối.
- Cổng vào (Inport) mặc định ở CỘT NGOÀI CÙNG BÊN TRÁI subsystem; cổng ra
  (Outport) ở CỘT NGOÀI CÙNG BÊN PHẢI.
  - NGOẠI LỆ: nếu 1 cổng vào/tag (From) chỉ thực sự được dùng ở GIỮA hoặc
    CUỐI chuỗi tính toán (ép về cột trái sẽ ra dây rất dài), cho phép đặt
    nó gần ĐÚNG CHỖ nó được dùng thay vì ép về cột trái (vd tag `D` trong
    `Cal F_yf` - dùng ở cuối chuỗi Magic Formula, đặt gần `Prod_Fyf`, không
    đặt tận cột trái cùng `alpha_f`).
- Khối Constant KHÔNG bắt buộc dồn về 1 cột riêng - đặt SÁT khối tiêu thụ nó
  (phía trên hoặc dưới đường tín hiệu chính), để dây ngắn và đường tín hiệu
  chính không bị lệch trục (vd `F_zf` trong `D` đặt ngay dưới `Prod_D`; `C`,
  `C_alpha_f` trong `B` đặt ngay trên `Prod_CD`/`Div_B`).
- Chuỗi khối tính toán CHÍNH (nối tiếp nhau đúng thứ tự công thức) phải
  THẲNG HÀNG trên cùng 1 trục (cùng y nếu xếp ngang) - để dây nối là ĐƯỜNG
  THẲNG, không gấp khúc, trừ khi không tránh được (nhánh phụ nhập từ
  trên/dưới). Mẫu chuẩn nhất - `Cal F_yf`: `Prod_u -> Trig_atan_u ->
  Sum_t1 -> Prod_t2 -> Sum_t3 -> Trig_atan_t3 -> Prod_t4 -> Trig_sin_t4 ->
  Prod_Fyf` nằm nguyên 1 hàng ngang, không lệch.
- Cho phép kéo GIÃN KHOẢNG CÁCH giữa các khối tính toán (Product, Divide,
  Sum...) để có khoảng trống, tránh dồn khối sát nhau gây rối mắt - đây là
  đổi VỊ TRÍ, không phải đổi KÍCH THƯỚC khối (vẫn giữ mặc định).
- Chừa đủ khoảng cách dọc giữa các hàng/nhóm khối để TÊN KHỐI (label hiển
  thị cạnh khối) không đè lên khối ở hàng kế bên.
- 2+ subsystem con cùng cấp, cùng đổ vào 1 giai đoạn tiếp theo (vd
  `Cal F_yf` và `Cal F_yr` cùng ra `TireForces`), xếp THẲNG HÀNG theo nhóm:
  cùng mép trái, xếp chồng dọc cách đều nhau, cổng ra cũng thẳng hàng.
- Tránh dây cắt nhau (wire crossing) khi có thể - chọn thứ tự xếp nhánh
  vào/ra sao cho dây đi tự nhiên, không vắt qua khối khác.

**7. Bộ hàm tiện ích dùng chung (copy nguyên giữa các `build_*.m`)**
`moveBlock`, `createSubsystem`, `addInport`, `addOutport`, `addConstant`
(tên mặc định), `addGoto`, `addFrom` (tên mặc định), `addProduct`, `addSum`,
`addTrigFcn`, `addSignBlock`, `addIntegrator` (nhận tên rõ ràng).

**8. Code trong file `.m` viết bằng TIẾNG ANH** - tên hàm, tên biến, comment.
Chỉ tài liệu (`.txt`, `.md`) và hội thoại mới dùng tiếng Việt.

**9. Test: mỗi model có ĐÚNG 1 file test**
- `test_cumN.m`, `test_plant.m`, `test_reference.m`, `test_actuator.m`, `test_sensors.m` test bản chính thức (không `_s`). Mỗi file cố định 1 tên
  model, TỰ CHỨA (không phụ thuộc file thứ ba), không nhận tham số tên model (riêng `test_sensors` phần B nhận tên model vòng kín nếu có).
- Tự dò subsystem gốc + cổng THEO TÊN, KHÔNG giả định thứ tự cổng - bản
  người dùng có thể đổi thứ tự cổng khi format tay (từng gặp: `Tires.mdl` có `F_yr` là cổng 1, `F_yf` là cổng 2).
- Nghiệm đối chiếu phải tính ĐỘC LẬP ngay trong file test (đọc thẳng
  `params.json`), KHÔNG lấy giá trị đã tính sẵn ở base workspace - nếu không
  thì test không bắt được lỗi của chính `load_derived.m`.
- Hệ có số hạng phi tuyến dốc (`tanh(c*x)` với `c` lớn) PHẢI đặt `MaxStep`
  cho harness - solver bước-thay-đổi mặc định chọn bước quá lớn sau khi hệ
  ổn định, gây méo số liệu log (đã gặp thật ở Cụm 1).

## Trạng thái hiện tại

Xem mục "TRẠNG THÁI HIỆN TẠI" trong nhật ký của khung mình (`Tracking/historychat_map.md` Map, `Tracking/historychat_linear.md` Linear, hoặc `Tracking/historychat_smc.md` SMC), luôn chính xác hơn mục này. Tóm tắt (2026-10-07): đã xóa mọi bộ điều khiển và kết quả của chúng; repo chỉ còn PRSM (Plant, Ref, Sensors, Actuator, đều có test PASS) cùng khung thử `Model/Sim`, đã tổ chức lại cấu trúc như trên; bước tiếp theo là làm lại Map.

## Ghi chú khác

- Người dùng tự dán công thức LaTeX vào Word: đừng chỉnh trực tiếp `Documents/Thesis/Thesis.docx` trừ khi được yêu cầu rõ ràng.
- Khi trích dẫn số liệu/claim từ 1 nguồn (paper, hay câu trả lời AI khác như
  Gemini), luôn kiểm tra lại trong file PDF gốc ở `References/` trước khi xác
  nhận đúng - không nhận trích dẫn theo lời kể lại nếu chưa đọc thấy trong
  nguồn.
- **MỘT NHÁNH `main`, MỘT FILE LỊCH SỬ MÁY (người dùng chốt 2026-10-23):** repo chỉ còn nhánh `main` (không nhánh phụ `auto/*`, cả PC lẫn laptop làm trực tiếp trên main). `Tracking/repo_history.md` ghi máy nào làm gì (phần trên sinh tự động từ git log, phần dưới ghi chú tay). Cả hai máy cập nhật bằng MỘT lệnh ở gốc repo (Git Bash): `bash tools/sync_repo.sh "việc đã làm" ["ghi chú: chạy gì, kết quả ở đâu"]`: nó pull main, thêm tag `[PC]` hoặc `[laptop]` (theo tên máy; PC = DESKTOP-G6T192V, còn lại là laptop) vào commit, tạo lại repo_history.md bằng `tools/update_repo_history.py`, rồi push main. Vẫn ghi `historychat_*.md` TRƯỚC khi chạy lệnh này (quy tắc ghi nhật ký trước commit).
- **QUY TẮC VIẾT BÀI BÁO TIẾNG ANH `Documents/Paper/paper.txt` (người dùng chốt 2026-10-26, áp dụng cho MỌI phần viết tiếp):** (1) tiếng Anh chuyên nghiệp ở mức IELTS band 7.5 (người dùng đổi 2026-10-26, trước đó chốt 6.5 nhưng nghe quá đơn giản): từ vựng kỹ thuật chính xác, liên từ rõ (since, whereas, provided, owing to), câu mạch lạc, không dài dòng, không nén nhiều ý trong một câu, không quá hoa mỹ hay hàn lâm; giữ nguyên thuật ngữ kỹ thuật chuẩn (assist map, lead-lag compensator, PID, torsion bar). (2) KHÔNG khẳng định mạnh hoặc rủi ro: không "any", "always", "prove", "best", "novel", không nói quá điều số liệu chưa cho thấy; kết luận chỉ nói điều dữ liệu hỗ trợ và nêu giới hạn (một xe mô phỏng, chưa kiểm chứng với số đo); nói "tham số được chỉnh cho từng xe" chứ không nói quy trình đã kiểm trên nhiều xe. (3) Abstract KHÔNG CÓ SỐ LIỆU (thầy yêu cầu), không ký hiệu toán, không trích dẫn, tối đa 250 từ; thứ tự: bối cảnh và động lực, giới hạn của map, đề xuất, mô tả ba bộ Map, PID, MapPID (MapPID = Map + nhánh PID song song, chỉ chỉnh tham số PID), kết quả theo xu hướng, giới hạn. Văn bản Abstract hiện tại là bản đã chốt, chỉ sửa khi người dùng bảo. (4) Câu khai báo Generative AI cuối bài GIỮ NGUYÊN "language editing only" (người dùng chốt 2026-10-26), không đề nghị sửa; việc giảm điểm công cụ dò AI làm theo bộ quy tắc "VIẾT NHƯ NGƯỜI" ở mục kế tiếp (người dùng chốt 2026-10-28, thay cho câu cũ "không viết lại chỉ để qua công cụ dò AI"). (5) CHỈ sửa đúng mục người dùng yêu cầu, không tự rà hay cập nhật mục khác. (6) CHỈ sửa `paper.txt`; KHÔNG sinh `paper_Tan_Huy.docx` hay `.pdf` cho tới khi người dùng nói "gen"; khi được bảo gen: `python tools/paper2docx.py Documents/Paper/paper.txt Documents/Paper/paper_Tan_Huy.docx`, rồi xuất pdf và kiểm pdf.

- **QUY TẮC "VIẾT NHƯ NGƯỜI" KHI VIẾT TIẾNG ANH (người dùng chốt 2026-10-28; MỖI LẦN viết hay sửa văn bản tiếng Anh cho bài báo đều phải làm theo, cùng với quy tắc band 7.5 ở mục trên):** mục tiêu là văn học thuật do một người viết giỏi viết, điểm dò AI thấp (Copyleaks), không nói chuyện phiếm. Bản gốc của người dùng, giữ nguyên ý: Act as a skilled human writer; counter the typical signs of AI writing to raise perplexity and burstiness; sound academic, not conversational. (1) Trộn câu ngắn, trực tiếp với câu dài nhiều mệnh đề; không để các câu và đoạn có cùng cấu trúc; trộn câu đơn, ghép, phức; dùng cả liên từ đẳng lập (and, so) và phụ thuộc (although, because). (2) Không lạm dụng mệnh đề phân từ hiện tại: tối đa 1 cấu trúc như vậy trong 500 từ. (3) Không viết tắt kiểu nói (contractions), không tiếng lóng, không cụm động từ (phrasal verbs), không thành ngữ; dùng chữ đơn giản, súc tích. (4) Trộn câu chủ động và bị động. (5) Thay các động từ nghe như AI (enhance, boost, elevate, ensure, crucial) bằng chữ thường dùng; không phóng đại, không kịch tính. (6) Đổi cách mở câu, không lặp từ hay cụm từ gần nhau. (7) Tránh liệt kê ba thứ: bỏ một mục nếu nghĩa không đổi, hoặc tách thành hai câu (danh sách kỹ thuật bắt buộc như P, I, D hoặc tên công thức thì được giữ). (8) Không nói điều gì đó KHÔNG phải là gì trước khi nói nó là gì (tránh "rather than", "it is not about X, it is about Y"); chỉ nêu sự thật điều đã làm, không kể điều không xảy ra hay không dùng. (9) Không dùng cụm "extends beyond". (10) Dùng meta-discourse khi cần ("as mentioned earlier", "to summarise"); không tóm tắt hay kết luận lại ở cuối mỗi đoạn, không giải thích thừa. (11) Độ dài đoạn không đều nhau; tách đoạn dài khi cần. (12) Không viết khẳng định lớn, rỗng (kiểu "X reshaped the industry"); ưu tiên sự kiện và số liệu, tránh lặp ý. (13) Không mở đầu bằng khái quát chung chung ("X has long been a concern..."); mở bằng bằng chứng hay sự kiện cụ thể có trích dẫn. (14) Không ẩn dụ, không câu mở gây chú ý, không tạo hồi hộp. Ghi chú áp dụng: Abstract vẫn không số liệu, ≤250 từ; các quy tắc này không thay đổi nội dung kỹ thuật, ký hiệu hay số liệu.

- **KHÔNG LẬP LUẬN DỰA TRÊN CÁC LẦN CHẠY TRƯỚC (người dùng chốt 2026-10-27):** kết quả các lần chạy trước (số liệu, lưới cũ, điểm đã chọn cũ, thứ bậc các bộ, tham số cũ như K_d hay tau_f đã chọn) chỉ để RÚT KINH NGHIỆM cho người làm (biết rủi ro, biết chỗ cần kiểm), KHÔNG được dùng làm căn cứ chọn thiết kế mới và KHÔNG được đưa vào bài báo hay luận văn như một lập luận. Mọi lựa chọn trong thiết kế mới phải có căn cứ ĐỘC LẬP: nguồn tài liệu (sách, bài báo), lý thuyết, hoặc kết quả của chính lần chạy mới theo kế hoạch viết TRƯỚC khi chạy. Bài chỉ báo cáo số của lần chạy chính thức (code và seed theo kế hoạch); không viết kiểu "lần trước điểm K_d = 0 không được chọn nên bỏ nó", "thiết kế cũ có T_d > 0 nên giữ", hay dùng số cũ để biện minh. Khi trả lời người dùng về phương án mới, được nêu rủi ro rút từ kinh nghiệm nhưng phải ghi rõ đó là kinh nghiệm, không phải lập luận, và không đưa vào văn bản bài. Hệ quả cho việc tìm tham số: lưới, cổng, quy tắc chọn, seed chốt trong kế hoạch trước khi chạy, không điều chỉnh theo kết quả đã thấy của lần chạy cũ.
