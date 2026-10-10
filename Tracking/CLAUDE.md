# Adaptive C-EPS bằng Học tăng cường - Ghi chú làm việc

Luận văn Thạc sĩ (HCMUT, GVHD: TS. Phùng Thanh Huy, HV: Trần Minh Tân).
Đề tài: điều khiển trợ lực lái điện thích ứng (Adaptive C-EPS) khắc phục hiện
tượng trợ lực thừa (over-assist) khi hệ số bám mu thay đổi, dùng RL.

**THEO DÕI (3 khung chat chạy song song: Map, Linear, SMC; người dùng chốt phân vai 2026-10-09).** Thư mục `Tracking/` chỉ có các file `.md` sau: `CLAUDE.md` (file này, quy tắc chung; file `CLAUDE.md` ở gốc repo chỉ trỏ tới đây), `historychat_map.md` (nhật ký khung Map; đổi tên từ historychat_1.md ngày 2026-10-09), `historychat_linear.md` (nhật ký khung Linear: PI, PID, đổi tên từ historychat_2.md ngày 2026-10-09), `historychat_smc.md` (nhật ký khung SMC, tạo khi khung đó bắt đầu). **ĐẦU MỖI PHIÊN: đọc nhật ký CỦA KHUNG MÌNH** (mục "TRẠNG THÁI HIỆN TẠI" và vài lượt cuối) trước khi làm việc. **CUỐI MỖI LƯỢT hỏi-đáp: thêm 1 mục "Lượt N" vào CHÍNH file nhật ký của khung mình** (và sửa mục "TRẠNG THÁI HIỆN TẠI" nếu có thay đổi). File của các khung kia CHỈ ĐỌC, không ghi. **MỖI LẦN BẮT ĐẦU LÀM VIỆC** (không chỉ khi trả lời câu hỏi) cũng đọc MỤC "Lượt" MỚI NHẤT (chỉ 1 mục) của nhật ký khung KIA (khung Linear đọc lượt mới nhất của khung Map và khung SMC) để xét có kinh nghiệm mới rút ra không (lỗi đã gặp, cách làm tốt, đổi tên hay sửa file dùng chung, quy ước mới); nếu có thì ghi vào mục Lượt của CHÍNH nhật ký khung mình (người dùng chốt 2026-10-08, sửa từ 5 mục xuống 1 mục). Người dùng thao tác nhiều khung cùng lúc nên các khung không được sửa chung một mục.

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
    Sim/script/            khung thử dùng chung: build_closed_loop.m (Plant -> Sensors -> bộ điều khiển -> Actuator), test_cases.m,
                           run_test_cases.m(ctrl, seed), make_pair_comparisons.m, plot_compare_cases.m
    Controllers/<Ctrl>/    MỖI bộ điều khiển 1 thư mục cùng cấu trúc: load_<ctrl>.m, <Ctrl>.mdl, Model_<Ctrl>.mdl (vòng kín, KHÔNG hậu tố _s), script/
  Documents/
    Thesis/                CHƯƠNG LUẬN VĂN (định dạng plant.txt, sinh .docx bằng tools/txt2docx.py): plant, ref, TestCases, (map, pi, ... khi làm),
                           và Thesis.docx/pdf tổng
    Notes/PRSM/            ghi chép suy diễn của PRSM: Cum1_CEPS, Cum2_Pacejka, Cum3_2DOF, HeThongPlant_TongHop, ThucTeHoa
    Notes/Controllers/     kế hoạch, nhật ký thử của từng bộ điều khiển (DieuKhien_<Ctrl>.txt); LyThuyet_Map.txt = lý thuyết xây dựng Map từ đầu đến cuối kèm lý luận từng bước và hỏi đáp bảo vệ (viết 2026-10-09 theo yêu cầu người dùng; Map do khung Map làm; số liệu lấy từ map.txt, đang làm lại nên con số trong đó lỗi thời)
    Data/                  bảng tính: Params.xlsx, params_*.csv/xlsx, Reference.xlsx (và Map.xlsx khi làm)
    Shared/                QuyChuan.txt (QUY CHUẨN thiết kế và đánh giá chung, BẮT BUỘC), Blueprint_OverAssist_RL.txt, References.txt (danh mục tài liệu tham khảo DÙNG CHUNG), PhanBien.txt
    Archive/               old/ (bản cũ của người dùng, không sửa); Gemini_old/ đã xóa 2026-10-08 (còn trong git)
  Result/                  soi gương Model/: PRSM/{Plant,Reference}/, Controllers/<Ctrl>/<Design|Sweep|TestCases|TestCases_noise>/, Compare/<A>_vs_<B>/
  Figures/                 sơ đồ khối, hình vẽ tay (drawio, png)
  References/              paper tham khảo (PDF)
  tools/                   txt2docx.py, reflow_txt.ps1, export_xlsx.py (còn đường dẫn Map cũ), build_map_txt.py (sinh chương map.txt từ csv; số liệu cũ, phải viết lại khi làm lại Map)
  scratch/                 script thử, file tạm - KHÔNG commit (nằm trong .gitignore)
```

Thư mục gốc chỉ có các mục trên cùng `CLAUDE.md` (trỏ tới Tracking/), `README.md`, `.gitignore`; không để script lẻ ở gốc.

- Phần chương luận văn: `Documents/Thesis/plant.txt` là NGOẠI LỆ của quy tắc độ rộng dòng: mỗi đoạn văn 1 dòng (không ngắt 180-200), không dùng gạch đầu dòng, ký hiệu trong câu viết `$latex$`; sinh `plant.docx` bằng `C:/Users/Admin/anaconda3/python.exe tools/txt2docx.py <txt> <docx>` (tiêu đề `1.`/`1.1.` -> Heading 2/3, dòng `(n) ascii` + dòng `[ latex ]` -> phương trình Word đánh số, dòng `[Hình n: chú thích | Result/.../x.png]` chèn ảnh thật, đường dẫn tính từ gốc repo; không có `| đường dẫn` thì để khung trống chờ người dùng vẽ). Tương tự `ref.txt` (Mục 1: giá trị đặt T_d,ref + T_a,max), `TestCases.txt` (ca thử chuẩn TC1-TC6).
- Mọi bộ điều khiển đọc T_a,max từ `ref.json` qua `load_ref.m` (một nguồn duy nhất); giới hạn T_a,max (đã gồm dự phòng F = T_f) nằm ở khối `AssistLimit`, phép chặn và trễ motor ở khối `Actuator`; bộ điều khiển KHÔNG tự chặn và không giữ bản sao bảng T_a,max, bộ nào cần giá trị này khai báo cổng vào `T_a_max`.
- Cảm biến chỉ có 2 chế độ, KHÔNG còn khái niệm mức `low`/`high`: không truyền seed = cảm biến lý tưởng; truyền một seed = có nhiễu + lượng tử + chu kỳ cập nhật (`sensor_noise_vars(seed)`, `run_test_cases(ctrl, seed)`, `tk_run(mdl, seed, vars)`).
- Seed (5 chữ số, viết `seed_00000`; người dùng chốt 2026-10-07): chọn/chỉnh tham số (ca TK) mỗi bộ điều khiển dùng dải riêng, CHỈ 1 seed bắt đầu từ đầu dải: Map 00000-09999, PI 10000-19999, SMC 20000-29999, RL chưa gán. Ca thử chuẩn TC1-TC6 có nhiễu: CHỈ 1 seed chấm, giống nhau cho mọi bộ điều khiển, đếm lùi từ 99999 (99999, nếu cần thêm thì 99998...). Thư mục kết quả có nhiễu: `TestCases_noise/seed_99999/`; không nhiễu: `TestCases/`. QUY TẮC THÊM (người dùng chốt 2026-10-08): khi chạy TC1-TC6 cho MỘT bộ điều khiển riêng lẻ thì dùng seed local của bộ đó (đầu dải: PI `seed_10000`, Map `seed_00000`, SMC `seed_20000`); seed chung 99999 CHỈ dùng khi so sánh nhiều bộ với nhau (`make_pair_comparisons`).
- Thứ tự chạy dữ liệu PRSM: `make_plant_limits` -> `make_ref_table` -> `make_ta_max`. Đầu phiên MATLAB: `run('<repo>/Model/setup_paths.m')`.
- Quy ước đường dẫn trong code: file trong `Model/PRSM/<Phần>/script/` và `Model/Controllers/<Ctrl>/script/` tính `modelDir = fileparts(fileparts(fileparts(scriptDir)))`; file trong `Model/Sim/script/` tính `fileparts(fileparts(scriptDir))`; rồi `addpath(modelDir); setup_paths;`. Dữ liệu đọc bằng `fullfile(modelDir, 'data', ...)`, kết quả ghi bằng `result_dir(...)`; không ghi đường dẫn cứng.
- Tài liệu cũ của các bộ điều khiển đã xóa ngày 2026-10-07 (làm lại từ Map); bản sao lưu ở `C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-07`, kiến thức nằm trong `historychat_map.md`.

## Làm một bộ điều khiển: nơi đặt code, loại script, dựng model, đặt tên (người dùng yêu cầu ghi ngày 2026-10-10 để khung chat mới hiểu ngay)

**1. Nơi đặt (mỗi thứ đúng MỘT chỗ):**
- Code của bộ `<Ctrl>` (Map, PI, PID, SMC, RL): `Model/Controllers/<Ctrl>/` gồm `load_<ctrl>.m` (nạp biến), `<Ctrl>.mdl` (khối bộ điều khiển), `Model_<Ctrl>.mdl` (vòng kín chạy được), `script/` (MỌI script khác của bộ đó). Không để script lẻ ngoài `script/`, không để ở gốc repo.
- Dữ liệu: `Model/data/<ctrl>.json` là nguồn duy nhất của bộ (trường `calibration`, `design`...); mô hình Simulink và script chỉ ĐỌC từ đó, không giữ bản sao. Kết quả: `Result/Controllers/<Ctrl>/<Design|Sweep|TestCases|TestCases_noise/seed_NNNNN>/`.
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
1. `load_<ctrl>` nạp biến. 2. `build_<ctrl>` sinh `<Ctrl>.mdl`: subsystem gốc tên đúng tên bộ; cổng vào đọc THEO TÊN trong số `T_s, theta1, theta2_dot, v, gamma, a_y, T_a_lim, T_a_max` (chỉ khai báo cổng cần dùng, cổng không khai báo được nối Terminator); cổng ra duy nhất `T_a`; theo "Quy tắc dựng model Simulink" bên dưới. 3. `test_<ctrl>`: so Simulink với phép tính độc lập. 4. `build_closed_loop('<Ctrl>')` sinh `Model_<Ctrl>.mdl` (Plant -> Sensors -> bộ -> AssistLimit -> Actuator, có `StopFcn` lưu kết quả). 5. Chạy: `tk_run(mdl, seed, vars)` trên ca TK (tham số truyền bằng `setVariable`, không đổi model), `run_test_cases(ctrl, seed)` trên TC1-TC6, `make_pair_comparisons` để so nhiều bộ. KHÔNG có hậu tố `_s` ở bất kỳ model nào (bỏ 2026-10-09).

**4. Script phụ dùng chung (dùng lại, đừng viết lại):** `Model/setup_paths.m` (path, nơi duy nhất biết bố cục); `common/result_dir.m` (đường dẫn kết quả), `save_run_results.m`, `pick_model_name.m` (tên model không ghi đè), `pick_by_tolerance.m` (quy tắc chọn: R trong 5 % rồi S nhỏ nhất), `sensor_noise_vars.m` (seed -> nhiễu cảm biến); `Sim/script/`: `test_cases.m` (ca TK và TC1-TC6), `tk_run.m` (chạy TK, trả R, S, e_rel...), `tk_score.m` và `tk_block_scores.m` (tính điểm), `tk_bangbang.m` (cổng không bang-bang), `gates_fcn.m` + `build_gates.m` + `Gates.mdl` (đo chỉ tiêu trong mô phỏng), `run_test_cases.m`, `make_pair_comparisons.m`, `plot_compare_cases.m`, `build_closed_loop.m`, `test_tk.m`; `tools/`: `txt2docx.py`, `reflow_txt.ps1`, `export_xlsx.py` (đường dẫn Map cũ, sửa khi dùng).

**5. Đặt tên file, thư mục, biến:**
- Kết quả `<Ctrl>_<nội dung>_<điều kiện>.<đuôi>` (ví dụ `Map_calibration_points.csv`); thư mục `Design`, `Sweep`, `TestCases`, `TestCases_noise/seed_NNNNN`, so sánh `Result/Compare/<A>_vs_<B>/`. Điều kiện số viết `0p8`.
- Biến thể của một bộ (một bậc, hai bậc) là trường trong file `.json` hoặc thư mục con, KHÔNG phải bộ mới và không thêm hậu tố `_s`, `_old`, `_new`, `_v2` vào tên model hay file.
- Tên khối Simulink theo "Quy tắc dựng model Simulink" bên dưới; tên cổng là tên tín hiệu vật lý (`T_s`, `v`, `T_a`).
- Code và comment trong `.m` bằng tiếng Anh; `.txt`, `.md`, hội thoại bằng tiếng Việt.

**6. Kinh nghiệm công cụ (đã gặp thật, Windows):**
- MATLAB gọi nền: `"/c/Program Files/MATLAB/R2023a/bin/matlab" -softwareopengl -batch "run('<đường dẫn TUYỆT ĐỐI>\Model\setup_paths.m'); ..."`; `run()` đổi thư mục hiện tại nên không dùng đường dẫn tương đối. Có hình thì dùng `-softwareopengl` và `Visible off`. Lỗi heap corruption khi thoát MATLAB vô hại nếu dữ liệu đã ghi. Không đặt biến vòng lặp trùng tên biến base workspace của model (từng đè `c`, độ dốc của ma sát). Với `fsolve`, kiểm phần dư thật chứ không tin cờ hội tụ, và dùng phần dư không thứ nguyên.
- Python: `C:/Users/Admin/anaconda3/python.exe -I` với `PYTHONIOENCODING=utf-8`; ghi file UTF-8 bằng công cụ Write, không dùng heredoc cho chuỗi có `\n`, dấu gạch ngược hay ngoặc (shell làm sai chuỗi). Đo độ rộng dòng `.txt` bằng ký tự (Python), không bằng `awk` (đếm byte).
- Nhật ký lớn: đọc bằng `grep` tiêu đề rồi `Read` với `offset`/`limit`.

## Quy tắc chọn tham số và so sánh các bộ điều khiển (người dùng chốt 2026-10-08, áp dụng cho MỌI bộ)

**BẮT BUỘC: mỗi lần thiết kế hoặc chỉnh một bộ điều khiển (Map, PI, PID, SMC, RL) phải đọc và tuân theo `Documents/Shared/QuyChuan.txt` (quy chuẩn thiết kế và đánh giá chung, phiên bản 2, 2026-10-09: ca TK dựng lại, R một số, cổng ổn định đo bằng mô phỏng, thứ tự cổng); mục này chỉ là bản tóm tắt, nếu mâu thuẫn thì QuyChuan.txt ưu tiên. Mục nào trong đó đánh dấu [CẦN CHỐT] phải được người dùng chốt số trước khi dùng.**

Mục tiêu: kết quả so sánh không phụ thuộc vào việc người làm chọn ngưỡng nào. Giải thích chi tiết và ví dụ số: `Documents/Notes/Controllers/DieuKhien_PI.txt`, mục A9 và B4.

- **Chỉ tiêu:** R (RMS của e_T, độ bám) và S (RMS của T_a sau lọc cao qua 5 Hz, độ ồn) đo trên ca TK (`tk_run.m`), cùng seed local của bộ điều khiển, trên tín hiệu THẬT. Mỗi bộ quét tham số cho ra một mặt Pareto (R, S).
- **Cổng chung cho mọi bộ, đặt trước khi chạy:** ổn định, PM >= 45 độ ở mọi giao cắt độ lợi, GM >= 2, sai số xác lập e_rel <= 3 % (trên hai mặt đường k_r = 30 và 0 đối với phân tích tuyến tính). Không thêm hay đổi cổng sau khi đã thấy kết quả; nếu buộc phải đổi thì ghi trung thực lý do và thời điểm.
- **Kết luận chính của một phép so sánh = so cả mặt Pareto**, không chọn điểm: mặt của A nằm hẳn dưới mặt của B thì A tốt hơn với mọi quy tắc chọn; hai mặt cắt nhau thì báo "A tốt hơn khi ưu tiên êm, B khi ưu tiên bám" kèm điểm cắt; dải S không chồng nhau thì nói thẳng là không so trực tiếp được.
- **Điểm chạy TC1-TC6 của mỗi bộ (KHÔNG dùng con số S_max chung, người dùng chốt 2026-10-08):** bám là ưu tiên một (mục tiêu đề tài là khắc phục trợ lực thừa, tức bám T_d,ref), êm là ưu tiên hai. Với mỗi bộ: trong các điểm đạt cổng cứng, lấy các điểm có R không quá 5 % so với R nhỏ nhất CỦA CHÍNH BỘ ĐÓ (5 % = ngưỡng hòa), rồi chọn điểm có S nhỏ nhất. Hàm dùng chung: `Model/common/pick_by_tolerance.m`.
- **Cổng cứng thêm: không bang-bang** (không EPS thật nào chấp nhận T_a nhảy liên tục giữa +-T_a,max vì nhiễu). Định nghĩa đặt trước: chạy ca TK hai lần (cảm biến lý tưởng và có nhiễu, seed local), tỉ lệ mẫu (từ 2 s) mà |T_a_cmd| chạm giới hạn T_a,max(v) của Actuator; điểm bị loại nếu tỉ lệ có nhiễu trừ tỉ lệ lý tưởng > 1 % (ngưỡng 1 % tự chọn; báo độ nhạy 0.5-5 %). Hàm: `Model/Sim/script/tk_bangbang.m`. Chỉ cần đánh giá cổng này cho các điểm chung kết (trong 5 % của R nhỏ nhất), theo thứ tự S tăng dần.
- **Ngưỡng hòa:** chênh lệch nhỏ hơn mức đặt trước (mặc định 5 %, hoặc độ lệch giữa các seed) thì coi là ngang nhau, không nói bộ nào hơn.
- **Cùng công sức thiết kế:** cùng cổng, lưới quét mịn tương đương, cùng cách chọn seed (1 seed local đầu dải), chỉnh trên TK rồi chấm trên TC, báo số tham số chỉnh của mỗi bộ.
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

- Mọi kết quả (hình `.png`, bảng `.csv`, `.mat`) lưu dưới `Result/` ở thư mục gốc, bố cục soi gương `Model/`: `Result/PRSM/Plant/`, `Result/PRSM/Reference/` (kết quả của môi trường), `Result/Controllers/<Ctrl>/<mục>/` (kết quả của MỘT bộ điều khiển: Design, Sweep, TestCases, TestCases_noise/high_seed90001 ...), `Result/Compare/<A>_vs_<B>/` (so sánh nhiều bộ điều khiển, ví dụ `Map_vs_PI`). Bộ điều khiển mới thêm thì tự có `Result/Controllers/<Tên>/`. Biến thể là thư mục con (`Result/Controllers/PI/2K/`).
- Tên file theo ý nghĩa: `<Đối tượng>_<nội dung>_<điều kiện>.<đuôi>`, ví dụ `Map_TC1_dry_calibration_time_response.png`, `Map_vs_PI_scenario_metrics.csv`, `Reference_Ta_max_by_speed_mu0p8.csv`. Tên kịch bản có nghĩa, điều kiện số dùng `0p8` thay dấu chấm.
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
