# Adaptive C-EPS bằng Học tăng cường - Ghi chú làm việc

Luận văn Thạc sĩ (HCMUT, GVHD: TS. Phùng Thanh Huy, HV: Trần Minh Tân).
Đề tài: điều khiển trợ lực lái điện thích ứng (Adaptive C-EPS) khắc phục hiện
tượng trợ lực thừa (over-assist) khi hệ số bám mu thay đổi, dùng RL.

**ĐẦU MỖI PHIÊN: đọc `History_Chat.md` (thư mục gốc) TRƯỚC KHI làm việc.** File đó ghi lại toàn bộ cuộc trò chuyện và trạng thái hiện tại của dự án. **CUỐI MỖI LƯỢT hỏi-đáp: thêm 1 mục "Lượt N" vào cuối `History_Chat.md` (và sửa mục "TRẠNG THÁI HIỆN TẠI" nếu có thay đổi)** - người dùng dựa vào file này để chuyển sang phiên mới khi hết token.

Toàn bộ giao tiếp, tài liệu, code comment (nếu có) đều bằng **tiếng Việt**,
trừ tên biến/ký hiệu kỹ thuật giữ nguyên tiếng Anh/công thức gốc.

## Cấu trúc thư mục

- `Documents/` - toàn bộ tài liệu suy diễn vật lý + blueprint điều khiển, phân
  tầng theo đúng cấu trúc con của `Model/` (mỗi cụm/bộ điều khiển 1 thư mục
  con cùng tên, tài liệu và code soi gương nhau).
  - `Blueprint_OverAssist_RL.txt` (gốc) - tài liệu GỐC, chỉ tổng hợp lý
    thuyết/chiến lược điều khiển (phạm vi bài toán, biến trạng thái, chiến
    lược FF/FB, trỏ tới các file con chi tiết). KHÔNG chứa suy diễn công
    thức đầy đủ.
  - `References.txt` (gốc) - danh mục tài liệu tham khảo DÙNG CHUNG toàn
    luận văn, đánh số theo thứ tự xuất hiện lần đầu qua các file con.
  - `Plant/` - tương ứng `Model/Plant/` + `Model/load_plant.m`.
    - `plant.txt` - BẢN CHÍNH THỨC đưa vào luận văn (đã gộp suy diễn +
      kết quả của cả 3 cụm, sắp lại logic, bỏ ghi chú quá trình làm).
      Là NGOẠI LỆ của quy tắc độ rộng dòng: mỗi đoạn văn 1 dòng (không ngắt
      180-200), không dùng gạch đầu dòng, ký hiệu trong câu viết `$latex$`;
      sinh bản Word `plant.docx` bằng `python tools/txt2docx.py` (quy ước
      định dạng mô tả đầu file tool: tiêu đề `1.`/`1.1.` -> Heading 2/3,
      dòng `(n) ascii` + dòng `[ latex ]` -> phương trình Word đánh số).
    - `Cum1_CEPS.txt`, `Cum2_Pacejka.txt`, `Cum3_2DOF.txt` - suy diễn vật
      lý chi tiết từng cụm cho riêng người viết tự kiểm chứng (xem "Quy ước
      1 file cụm" bên dưới); `HeThongPlant_TongHop.txt` - ghép nối thuần
      túy hệ phương trình trạng thái của cả 3 cụm. Cả 4 file này ĐÃ ĐƯỢC
      GỘP vào `plant.txt`, giữ lại chỉ để tra soát suy diễn gốc.
    - `params_cum1.csv`, `params_cum2.csv`, `params_plant.xlsx`.
  - `Ref/` - tương ứng `Model/Ref/` + `Model/load_ref.m`: `ref.txt` (Mục 1 chương Bộ điều khiển: giá trị đặt T_d,ref + T_a,max, cùng quy ước plant.txt, sinh `ref.docx`), `Reference.xlsx` (tab T_d,ref mịn, tab T_a,max); `params_ref.xlsx` (cũ,
    chỉ Bảng 4 gốc).
  - (Đã bỏ thư mục `Boundaries/` và file `boundaries.json`: biên vận hành của
    Plant (a_y,max(v, mu)) nằm ở `Plant/plant.txt` mục 6.2, dữ liệu
    `Model/data/plant_limits.json` do `Plant/script/make_plant_limits.m` sinh;
    giới hạn trợ lực T_a,max(v) nằm ở `Ref/ref.txt` mục 1.5, dữ liệu trường
    `Ta_max` trong `Model/data/ref.json` do `Ref/script/make_ta_max.m` sinh.
    Mọi bộ điều khiển (Map, PID, SMC, SMC_KI) đọc T_a,max từ `ref.json` qua
    `load_ref.m` (biến `Tamax_v_bp_ms`, `Tamax_table`). Một nguồn duy nhất.)
  - `PID/` - tương ứng `Model/PID/`: `DieuKhien_PID.txt`.
  - `SMC/` - tương ứng `Model/SMC/` và `Model/SMC_KI/`: `DieuKhien_SMC.txt`
    (hiện gộp cả 2 bản SMC, cần tách khi làm SMC_KI đầy đủ).
  - `RL/` - tương ứng `Model/RL/` (code và model RL xóa rồi làm lại ngày 2026-10-02; bước 1 xong: `Model_RL_s.mdl`, `load_rl.m`, `data/rl.json`, `Model/RL/script/`; làm tiếp từng bước theo `DieuKhien_RL.txt`): `DieuKhien_RL.txt` - kế hoạch và tài liệu thiết kế bộ RL THUẦN (xuất thẳng T_a, chu kỳ 1 ms, so với Map); chương chính thức sau này là `rl.txt`.
  - `Map/` - tương ứng `Model/Map/`: `map.txt` (Mục 2 chương Bộ điều khiển:
    bản đồ trợ lực truyền thống làm baseline - bản đồ đường cong hiệu chỉnh ở
    mu = 0.8 + vùng chết + giới hạn độ dốc, 1 khâu lead theo tiêu chí [1] (K_max = 18, z = 80, p = 680 rad/s), chu kỳ 1 ms;
    kết quả 6 ca thử TC1-TC6 và bảng chỉ tiêu so sánh; sinh `map.docx` có chèn hình từ
    `Result/Map/` - chia thư mục con Calibration/, OverAssist/, TestCases/), `Map.xlsx` (bản đồ đầy đủ,
    tham số, cặp hiệu chỉnh, bảng kết quả). Số liệu do
    `Model/Map/script/calibrate_map.m` và `export_map_results.m` sinh ra.
  - `Sim/` - tương ứng `Model/Sim/`: `TestCases.txt` (+ `TestCases.docx`, định
    dạng chương luận văn như plant.txt) - ca thử chuẩn dùng chung cho mọi
    bộ điều khiển: TC1 kiểm tra hiệu chỉnh đường khô, TC2 chạy đường thực tế
    150 s, TC3-TC6 tình huống nguy hiểm (mục 4 TestCases.txt); code `Model/Sim/script/test_cases.m` (định nghĩa,
    góc lái độc lập bộ điều khiển) và `run_test_cases.m('<Ctrl>')` (chạy, hình
    6 ô, bảng chỉ tiêu vào `Result/<Ctrl>/TestCases/`).
  - `Sim/ThucTeHoa.txt` - danh sách các khâu thực tế còn thiếu của môi trường mô phỏng (nhiễu cảm biến, động học motor, sai lệch thông số xe, trễ a_y qua CAN, nhiễu mặt đường) theo thứ tự quan trọng: lý do, ảnh hưởng, cách làm, dự đoán Map/PID/RL, trạng thái, lịch tới báo cáo thứ 7; cập nhật "Nhật ký thực hiện" khi làm xong từng khâu.
  - `PhanBien.txt` (gốc) - câu hỏi phản biện hội đồng và cách trả lời, DÙNG CHUNG toàn luận văn, chia section theo chương (P Plant, R Ref, M Map, T Ca thử, C PID/SMC, L RL, G chung); mỗi mục: câu hỏi, trả lời ngắn, cơ sở + số liệu, điểm yếu thật. Cập nhật dần; khi người dùng nêu/ta phát hiện điểm yếu mới thì thêm mục vào đúng section.
  - `Gemini_old/` (gốc) - tài liệu/code cũ (từ bản Gemini trước), KHÔNG dùng
    nữa, giữ lại để tham khảo lịch sử. Không sửa/xóa trừ khi được yêu cầu rõ.
- `References/` - paper tham khảo (Rajamani Vehicle Dynamics and Control,
  Multi-Map EPS, CEPS ANFIS-FOC, Road_Identification_BP-NN, Saifia2015 =
  Fuzzy_Control_EPS_Constraints (trùng file), Process_Control.pdf - Seborg).
- `Model/` - Simulink + script MATLAB (code `.m` bằng TIẾNG ANH): `data/` (params.json, plant_limits.json, ref.json [gồm bảng T_d,ref mịn và Ta_max], pid.json [Kp, Ki, Kd do `PID/script/tune_pid.m` ghi bằng pidtune], smc.json, smc_ki.json, map.json, sensors.json [độ phân giải, chu kỳ cập nhật, nguồn, tập seed của khối Sensors: nhiễu + Quantizer + giữ bậc không]), `load_sensors.m` + `sensor_noise_vars.m` (biến nhiễu của khối Sensors, mặc định không nhiễu), `load_plant.m` (+ `load_derived.m`), `load_ref.m`, `load_pid.m`, `load_smc.m`, `load_map.m` (mỗi file bộ điều khiển tự gọi load_plant và load_ref), `Model_Map_s.mdl` (vòng kín chạy được; model và kết quả của PID/SMC/SMC_KI ĐÃ XÓA, script và data giữ nguyên, dựng lại bằng `build_<ctrl>.m` + `build_model_<ctrl>.m` khi làm phần điều khiển), `Plant/` (SteeringColumn, Tires, Bike2DOF, Plant; script `make_plant_limits.m`), `Ref/` (Reference; script `make_ref_table.m`, `make_ta_max.m`, `verify_Ta_need.m`, `export_reference_results.m`), `PID/` (kèm `find_ultimate_gain.m`, `scan_kcu_grid.m` chỉnh định), `SMC/`, `SMC_KI/`, `Map/` (bản đồ EPS tra bảng, baseline; `calibrate_map.m`, `export_map_results.m`), `Sim/` (ca thử chung `test_cases.m`, `run_test_cases.m(ctrl, level, seed)`, `run_noise_study.m`, `add_sensors.m`, `test_sensors.m`, `compare_test_cases.m`, so sánh nhiều bộ điều khiển). Thứ tự chạy dữ liệu: `make_plant_limits` -> `make_ref_table` -> `make_ta_max` -> `calibrate_map`. Chi tiết: `History_Chat.md`.
- `tools/reflow_txt.ps1` - gộp/ngắt dòng file `.txt` theo quy tắc 190 ký tự (xem `History_Chat.md`).
- `tools/export_xlsx.py` - cập nhật `Documents/Map/Map.xlsx` và `Documents/Ref/Reference.xlsx` từ `Model/data/*.json` và `Result/Map/*` (chạy sau khi chạy lại Map/Ref; python Anaconda, cần đóng file Excel).
- `tools/txt2docx.py` - chuyển file `.txt` chương luận văn (quy ước như plant.txt) sang `.docx` (python Anaconda: `C:/Users/Admin/anaconda3/python.exe`; tự chuyển LaTeX sang phương trình Word, không cần pandoc). Dòng `[Hình n: chú thích | Result/.../x.png]` chèn ảnh thật (đường dẫn tính từ gốc repo); không có `| đường dẫn` thì để khung trống chờ người dùng vẽ.
- `old/` - bản cũ người dùng để tham chiếu (old/TB = bản thanh xoắn). Không sửa.

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

- Mọi kết quả (hình `.png`, bảng `.csv`, `.mat`) lưu dưới `Result/` ở thư mục gốc, MỖI đối tượng một thư mục: `Result/Plant/`, `Result/Reference/`, `Result/PID/`, `Result/SMC/` (kết quả của MỘT bộ điều khiển hoặc một thành phần), `Result/Compare/<A>_vs_<B>/` (kết quả so sánh nhiều bộ điều khiển, ví dụ `PID_vs_SMC`). Bộ điều khiển mới thêm thì tạo `Result/<Tên>/`.
- Tên file theo ý nghĩa: `<Đối tượng>_<nội dung>_<điều kiện>.<đuôi>`, ví dụ `PID_S1_hold_angle_mu_step_time_response.png`, `PID_vs_SMC_scenario_metrics.csv`, `Plant_Ta_max_by_speed_mu0p8.csv`. Tên kịch bản có nghĩa (`S1_hold_angle_mu_step`, `S2_sine_steering_mu_step`), điều kiện số dùng `0p8` thay dấu chấm.
- Mọi script xuất kết quả dùng `Model/result_dir.m` để lấy đường dẫn (chỗ DUY NHẤT biết gốc `Result/`) và `Model/save_run_results.m` để xuất tín hiệu + hình một lần chạy; KHÔNG ghi đường dẫn cứng. Model `Model_<Ctrl>_s.mdl` có `StopFcn` tự gọi `save_run_results` khi chạy tay (file `<Ctrl>_manual_run_*`), nên `ReturnWorkspaceOutputs = off`; script chạy model bằng `sim(Simulink.SimulationInput(tên))` để luôn nhận được đối tượng kết quả.

## Quy tắc dựng model Simulink (áp dụng cho MỌI `build_*.m` trong `Model/`)

Toàn bộ quy tắc dưới đây rút ra TỪ bản người dùng tự format tay
(`Model/Plant/Tires.mdl`) - đó là CHUẨN phong cách. Script `build_*.m` phải
sinh ra đúng cấu trúc đó; riêng vị trí/kích thước khối thì người dùng tự sắp
lại, script chỉ cần đặt hợp lý.

Model KHÔNG dựng tay - luôn sinh bằng script `build_*.m` (Simulink API), lưu
ra file hậu tố `_s`. Bản KHÔNG có `_s` là bản người dùng format tay từ bản
`_s`, script TUYỆT ĐỐI không ghi đè.

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

**9. Test: mỗi model có ĐÚNG 2 file test**
- `test_cumN_s.m` test bản `_s` (script sinh); `test_cumN.m` test bản format
  tay. Mỗi file cố định 1 tên model, TỰ CHỨA (không phụ thuộc file thứ ba),
  không nhận tham số tên model.
- Tự dò subsystem gốc + cổng THEO TÊN, KHÔNG giả định thứ tự cổng - bản
  format tay có thể đổi thứ tự (thực tế `Tires.mdl` có `F_yr` là cổng 1,
  `F_yf` là cổng 2, ngược bản `_s`).
- Nghiệm đối chiếu phải tính ĐỘC LẬP ngay trong file test (đọc thẳng
  `params.json`), KHÔNG lấy giá trị đã tính sẵn ở base workspace - nếu không
  thì test không bắt được lỗi của chính `load_derived.m`.
- Hệ có số hạng phi tuyến dốc (`tanh(c*x)` với `c` lớn) PHẢI đặt `MaxStep`
  cho harness - solver bước-thay-đổi mặc định chọn bước quá lớn sau khi hệ
  ổn định, gây méo số liệu log (đã gặp thật ở Cụm 1).

## Trạng thái hiện tại

Xem mục "TRẠNG THÁI HIỆN TẠI" trong `History_Chat.md` (luôn được cập nhật, chính xác hơn mục này). Tóm tắt: Plant 4 trạng thái (theta2, theta2_dot, beta, gamma) với góc vô-lăng theta1 là đầu vào; đã có PID (Ziegler-Nichols) và SMC bậc 1 + lớp biên sat cùng bộ so sánh; T_a,max ước lượng 5.6-7.2 N.m nhưng CHƯA áp giới hạn; RL chưa làm.

## Ghi chú khác

- Đừng chỉnh sửa trực tiếp `Documents/Gemini_old/Thesis.docx` trừ khi được
  yêu cầu rõ ràng - người dùng tự dán công thức LaTeX vào Word.
- Khi trích dẫn số liệu/claim từ 1 nguồn (paper, hay câu trả lời AI khác như
  Gemini), luôn kiểm tra lại trong file PDF gốc ở `References/` trước khi xác
  nhận đúng - không nhận trích dẫn theo lời kể lại nếu chưa đọc thấy trong
  nguồn.
