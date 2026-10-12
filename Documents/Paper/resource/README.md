# Adaptive C-EPS: mô hình và mã mô phỏng đi kèm bài báo

Thư mục [`resource/`](resource/) chứa mô hình Simulink và script tính toán, kiểm thử dùng để tái tạo kết quả của bài báo
trợ lực lái điện cột lái (C-EPS) bám mô-men theo gia tốc ngang để bỏ trợ lực thừa khi hệ số bám giảm.
So sánh ba bộ điều khiển: **Map** (bản đồ trợ lực kèm khâu bù lead-lag), **PI** và **PID** trên mô-men đo.
Không có mã sinh mô hình (`build_*`), mã sinh tài liệu hay hình của bài báo.

Yêu cầu: MATLAB R2023a với Simulink, Control System Toolbox, Optimization Toolbox (cho `fsolve`).

## Cách dùng

```matlab
run('resource/Model/setup_paths.m')                 % thêm mọi thư mục mã vào path (làm đầu mỗi phiên)
run('resource/Model/Controllers/PID/load_pid.m')    % nạp biến của PID (cũng nạp Plant, Ref, Sensors, Actuator); tương tự load_map, load_pi
test_pid                                            % kiểm khối bộ điều khiển (mỗi khối có một test)
[L, m] = calib_run('Model_PID', 10000, []);         % chạy ca CALIB, trả R, S, e_rel ... (seed 10000)
M = run_cases('PID', 99999);                        % chạy năm ca chấm điểm DRY, RAMP, SLIP, WEAVE, EDGE (seed 99999)
```

Kết quả mới chạy ghi vào `resource/Result/`, cùng chỗ với kết quả đã chạy sẵn (xem mục Kết quả đã chạy sẵn; chạy lại sẽ ghi đè). Tên file theo dạng `<Bộ>_<CA>_<nội dung>_<seed>`, ví dụ `PID_RAMP_sig_s99999.csv`.
Đã kiểm trên bản này: các test PASS, PID trên CALIB cho R 11.59 %, S 0.3115 N.m, PI chạy `run_cases` cho RMS e_T DRY 0.243 N.m (trùng bài báo).

## Cấu trúc `resource/Model/`

| Thư mục | Nội dung |
|---|---|
| `setup_paths.m` | Thêm mọi thư mục mã vào path; nơi duy nhất biết bố cục. |
| `data/` | Dữ liệu vào, nguồn duy nhất: `params.json` (tham số plant, mục 2 bài báo), `ref.json` (bảng mô-men đặt T_d,ref và giới hạn trợ lực T_a,max), `plant_limits.json` (a_y lớn nhất của plant), `sensors.json`, `actuator.json`, và điểm đã chọn của từng bộ: `map.json`, `pi.json`, `pid.json`. |
| `common/` | Hàm dùng chung: nhiễu cảm biến theo seed, đường dẫn kết quả, quy tắc chọn tham số (J = R x S). |
| `PRSM/` | Môi trường dùng chung cho mọi bộ điều khiển (Plant, Ref, Sensors, AssistLimit, Actuator): mô hình `.mdl`, `load_*.m` nạp biến, `script/` chứa test và phép tính dữ liệu. |
| `Sim/` | Khung thử dùng chung: ca thử, chạy, chấm điểm, cổng. |
| `Controllers/Map, PI, PID/` | Mỗi bộ: khối bộ điều khiển `<Ctrl>.mdl`, vòng kín `Model_<Ctrl>.mdl`, `load_<ctrl>.m`, `script/` (thiết kế, quét tham số, chọn, test). |

## Mô hình Simulink (`.mdl`)

| File | Làm gì |
|---|---|
| `PRSM/Plant/Plant.mdl` | Plant đầy đủ: cột lái + lốp + thân xe (4 trạng thái), mục 2. Lắp từ ba file dưới. |
| `PRSM/Plant/SteeringColumn.mdl` | Cột lái hai quán tính nối thanh xoắn, ma sát khô (phương trình 1, 2). |
| `PRSM/Plant/Tires.mdl` | Lốp Magic Formula, góc trượt, mô-men hồi vị T_r (phương trình 4-7). |
| `PRSM/Plant/Bike2DOF.mdl` | Thân xe hai bậc tự do (xe đạp), gia tốc ngang a_y. |
| `PRSM/Ref/Reference.mdl` | Mô-men đặt T_d,ref(v, a_y) từ bảng nội suy (phương trình 10). |
| `PRSM/Sensors/Sensors.mdl` | Cảm biến: nhiễu trắng, lượng tử hóa, giữ theo chu kỳ cập nhật (Bảng 2). |
| `PRSM/AssistLimit/AssistLimit.mdl` | Giới hạn trợ lực T_a,max(v) (phương trình 14, Bảng 4). |
| `PRSM/Actuator/Actuator.mdl` | Chặn theo giới hạn và trễ motor bậc nhất 100 Hz. |
| `Sim/Gates.mdl` | Khối đo R, S và các chỉ tiêu cổng trong lúc mô phỏng (chỉ đọc tín hiệu). |
| `Controllers/Map/Map.mdl` | Bản đồ trợ lực: vùng chết, bảng tra theo (v, T_s), khâu lead-lag (mục 4.2). |
| `Controllers/PI/PI.mdl` | PI trên e_T, chống bão hòa tính ngược (mục 4.3). |
| `Controllers/PID/PID.mdl` | PID: thêm khâu D lọc bậc nhất trên T_s đo (mục 4.3). |
| `Controllers/<Ctrl>/Model_<Ctrl>.mdl` | Vòng kín: ca thử, Plant, Sensors, bộ điều khiển, AssistLimit, Actuator; ghi tín hiệu để chấm điểm. |

## Script dùng chung

| File | Làm gì |
|---|---|
| `Sim/script/make_cases.m` | Sinh các ca thử: CALIB (chọn tham số) và DRY, RAMP, SLIP, WEAVE, EDGE (chấm điểm). Góc lái tính từ gia tốc ngang mục tiêu, không phụ thuộc bộ điều khiển. |
| `Sim/script/calib_run.m` | Chạy CALIB trên một vòng kín và chấm điểm. |
| `Sim/script/calib_score.m`, `calib_block_scores.m` | Tính R, S, TV, e_rel, trợ lực ngược trên tín hiệu thật (toàn ca và theo khối tốc độ). |
| `Sim/script/calib_margin.m` | Cổng dự trữ ổn định: chạy lại với độ lợi motor x2 và trễ +1 ms, so R với bản gốc. |
| `Sim/script/calib_bangbang.m` | Báo cáo bang-bang (nhiễu đẩy lệnh chạm giới hạn), chỉ báo cáo. |
| `Sim/script/gates_fcn.m` | Mã của khối MATLAB Function trong `Gates.mdl`. |
| `Sim/script/run_cases.m` | Chạy năm ca chấm điểm cho một bộ, lưu tín hiệu, hình và bảng chỉ tiêu. |
| `Sim/script/make_pair_comparisons.m`, `plot_compare_cases.m` | Chạy nhiều bộ cùng seed và so từng cặp (bảng, hình). |
| `Sim/script/test_calib.m`, `test_gates.m` | Test ca CALIB và cách chấm điểm; test khối `Gates.mdl`. |
| `common/sensor_noise_vars.m`, `sensor_tag.m` | Seed thành biến nhiễu của cảm biến; seed thành token trong tên file. |
| `common/pick_by_balance.m`, `pick_by_tolerance.m` | Quy tắc chọn điểm: cực tiểu J = R x S (dùng trong bài); quy tắc cũ R trong 5 % rồi S nhỏ nhất. |
| `common/selection_sensitivity.m` | Độ nhạy của điểm chọn theo các lựa chọn tự do của quy tắc. |
| `common/result_dir.m`, `save_run_results.m` | Đường dẫn thư mục kết quả; lưu tín hiệu và hình một lần chạy. |

## PRSM: nạp, tính dữ liệu, test

| File | Làm gì |
|---|---|
| `PRSM/*/load_*.m` | Nạp biến vào workspace cơ sở từ `data/*.json` (Plant, Ref, Sensors, AssistLimit, Actuator); `load_derived.m` tính các đại lượng dẫn xuất (tải trục). |
| `PRSM/Plant/script/make_plant_limits.m` | Tính a_y lớn nhất của plant theo (v, mu), ghi `plant_limits.json`. |
| `PRSM/Ref/script/make_ref_table.m` | Dựng bảng T_d,ref mịn (PCHIP) từ Bảng 3, ghi `ref.json`. |
| `PRSM/Ref/script/make_ta_max.m` | Tính giới hạn trợ lực T_a,max(v) (phương trình 14), ghi `ref.json`. |
| `PRSM/Ref/script/verify_Ta_need.m` | Kiểm công thức T_a cần thiết trên plant Simulink. |
| `PRSM/Plant/script/sweep_v_mu.m`, `sweep_Ta_mu.m` | Quét plant theo (v, mu) và (T_a, mu) để thấy trợ lực thừa. |
| `PRSM/Sensors/script/add_sensors.m` | Thêm khối Sensors vào một mô hình (dùng bởi `test_sensors.m`). |
| `test_cum1/2/3.m`, `test_plant.m`, `test_reference.m`, `test_sensors.m`, `test_assistlimit.m`, `test_actuator.m` | Mỗi test tính đáp án độc lập từ `params.json` rồi so với mô hình, in `TEST PASS`. |

## Map (`Controllers/Map/script/`), bảy bước của mục 4.2

| File | Làm gì |
|---|---|
| `map_params.m`, `map_steady_state.m` | Tham số plant đọc thẳng từ json; trạng thái cua đều tại (v, a_y, mu). |
| `calibrate_map.m`, `calibrate_map_cached.m` | Bước 1: điểm hiệu chỉnh đường khô (phương trình 16), ghi vào `map.json`. |
| `map_table.m`, `map_eval.m`, `map_variables.m` | Bước 2-3: đường cong có trần độ dốc K_max và vùng chết (phương trình 17), bảng tra, biến cho khối Map. |
| `map_dry_error.m`, `map_k_accuracy.m` | Sai số tĩnh đường khô theo K_max; K_max nhỏ nhất đạt độ chính xác cho trước. |
| `map_op_points.m`, `map_plant_lin.m` | Bước 4: điểm làm việc và plant tuyến tính hóa (68 plant). |
| `map_margins.m`, `map_margins_batch.m`, `map_noise_gain.m` | Dự trữ pha và biên, độ lợi nhiễu của vòng Map. |
| `design_leadlag.m`, `sweep_leadlag.m` | Bước 5-6: chọn khâu bù lead-lag (lưới thô rồi mịn), quét cặp (K_max, g_min). |
| `run_calib_sweep.m`, `select_map.m` | Bước 7: mô phỏng CALIB cho từng cặp, áp cổng và chọn J nhỏ nhất, ghi `map.json`. |
| `reproduce_map.m` | Chạy lại toàn bộ chuỗi trên theo từng giai đoạn (khoảng 5 giờ, có thể chạy tiếp). |
| `plot_calibration.m`, `plot_step2.m` | Hình điểm hiệu chỉnh và đường cong trợ lực. |
| `test_map.m`, `test_calibration.m`, `test_step2.m`, `test_leadlag_design.m` | Test khối Map, hiệu chỉnh, bảng, công cụ thiết kế khâu bù. |

## PI và PID (`Controllers/PI/script/`, `Controllers/PID/script/`), sáu bước của mục 4.3

| File | Làm gì |
|---|---|
| `PI/script/pi_plant_lin.m` | Bước 3: mô hình thiết kế của vòng trợ lực (cột lái cộng độ cứng đường, hai trường hợp lốp). |
| `PI/script/identify_plant.m` | Kiểm mô hình thiết kế bằng đáp ứng bậc thang trên plant phi tuyến; biên ổn định của PI. |
| `PI/script/pi_margins.m` | Bước 4: ổn định và dự trữ của vòng PI rời rạc. |
| `PI/script/zn_ultimate.m` | Bước 5: độ lợi và chu kỳ tới hạn (Ziegler-Nichols), cho giới hạn T_i. |
| `PID/script/scan_pid_stability.m` | Biên ổn định của PID theo (K_p, K_i) với nhiều (K_d, T_f). |
| `PI/script/run_pi_sweep.m`, `run_pi_fine.m`, `PID/script/run_pid_sweep.m` | Bước 6: quét lưới trên CALIB (thô, rộng, mịn), ghi csv chạy tiếp được; độ nhạy của PI. |
| `PI/script/select_pi.m`, `PID/script/select_pid.m` | Áp cổng và quy tắc chọn, ghi `pi.json`, `pid.json`. |
| `PI/script/test_pi.m`, `PID/script/test_pid.m` | Test khối PI và PID với đáp án độc lập. |

## Kết quả đã chạy sẵn (`resource/Result/Controllers/<Bộ>/`)

| Thư mục | Nội dung |
|---|---|
| `Cases/` | Kết quả của năm ca chấm điểm DRY, RAMP, SLIP, WEAVE, EDGE của từng bộ với seed chung 99999 (số trong Bảng 10, 11 của bài): `<Bộ>_<CA>_resp_s99999.png` là hình ba ô theo thời gian (T_s và T_d,ref; e_T với các cửa sổ chấm điểm tô màu; T_a), DRY và SLIP là Hình 9-14 của bài, `<Bộ>_metrics_s99999.csv` là bảng chỉ tiêu theo ca và theo cửa sổ. Tín hiệu theo thời gian (`*_sig_*.csv`, mỗi file khoảng 4 MB) không kèm theo, chạy `run_cases` để sinh. |
| `Calib/` | Kết quả chọn tham số trên CALIB: `<Bộ>_CALIB_pareto_<seed>.png` (mặt Pareto R theo S, hình 6-8 của bài), `*_sweep_*.csv` (mọi điểm đã mô phỏng), `*_pick_*.csv` (các ứng viên cuối cùng, cổng và điểm chọn), thêm `*_fine_*`, `*_sens*`, `*_sweepbeyond*` (quét mịn, độ nhạy, quét vượt giới hạn tuyến tính). Có chúng thì chạy lại `select_map`, `select_pi`, `select_pid` được ngay, không phải quét lại. |
| `Design/` | Kết quả phân tích tuyến tính dùng làm đầu vào cho bước quét: bảng khâu bù lead-lag của Map (103 cặp), điểm hiệu chỉnh của Map, biên ổn định của PI và PID. |

## Thứ tự tái tạo (tóm tắt)

1. Dữ liệu môi trường (đã có sẵn trong `data/`): `make_plant_limits`, `make_ref_table`, `make_ta_max`.
2. Thiết kế và chọn tham số: Map bằng `reproduce_map`; PI bằng `identify_plant`, `run_pi_sweep`, `select_pi`, `run_pi_fine`; PID bằng `scan_pid_stability`, `run_pid_sweep`, `select_pid`.
3. Chấm điểm: `run_cases(<Bộ>, 99999)` cho mỗi bộ, rồi `make_pair_comparisons({'Map','PI','PID'}, 99999)` để so cặp.
