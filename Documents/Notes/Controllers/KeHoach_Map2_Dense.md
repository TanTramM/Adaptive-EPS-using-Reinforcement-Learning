# Bàn giao khung Map: Map2 phủ rộng và đánh giá đầy đủ ràng buộc

Ngày lập: 2026-10-21, theo yêu cầu trực tiếp của người dùng trong khung MapPID.
Chủ trì triển khai, chạy và ghi nhật ký: **khung Map**.
Đây là kế hoạch để khung Map thực hiện sau khi người dùng gửi prompt bàn giao.
Việc lập tài liệu này không khởi chạy MATLAB, watchdog hay MapPID.

## 1. Phạm vi và chỉ đạo

- Đọc kế hoạch này, `Tracking/historychat_map.md` (trạng thái và lượt cuối),
  `Tracking/CLAUDE.md`, `Documents/Shared/QuyChuan.txt`, mục 13 của
  `Documents/Shared/PhuongPhap_TimThamSo.txt` và lượt cuối khung TESTCASE trước khi sửa/chạy.
- Chỉ làm **Map2 = (K, g_min)** với khâu lead–lag được tổng hợp cố định.
  Giữ nguyên cấu trúc Map, PRSM, ca CALIB, cách tính R/S/e_rel, seed và các ngưỡng.
  Không thêm feedback, đổi bảng tham chiếu hoặc đổi mô hình để cứu điểm trượt.
- Đây là mở rộng lấy mẫu sau khi đã thấy kết quả Map2 thưa, phải ghi trung thực
  thời điểm/lý do; không mô tả như kế hoạch đã đăng ký trước toàn bộ nghiên cứu.
- Kế hoạch này ưu tiên cho đợt Map2 mới so với chỉ dẫn Map5 hoặc khởi chạy lại
  selector noMargin trong tài liệu cũ. Không chạy song song các luồng Map5/Map2
  ghi chung kết quả. Không chạy S1/S2 MapPID, surrogateopt hay DREWS trong đợt này.
- Thực hiện đến báo cáo cuối, có cache, resume và kiểm tra lỗi; không cần xin lại
  các lựa chọn triển khai đã ghi rõ ở đây. Không tự đổi gate nếu không có nghiệm.

## 2. Bằng chứng đã có, cần đối chiếu khi tiếp nhận

- PID grid đã xong: 561 điểm duy nhất, 168 mô phỏng thật, 114 khả thi;
  J chọn 2.48553, ratio gain/delay khoảng 0.713/1.022.
- Map2 thưa: `Result/Controllers/Map/Calib_v2/TwoParam/` có 38 điểm, 31 mô phỏng,
  22 khả thi danh định, 0/22 qua gain x2. Best danh định K=8.52112777691,
  g_min=0.707106781187, J=3.110294338; ratio gain seed1=3.59543512.
- Thiết kế Map bài báo trong map.json: K=6, lead z=33.5009375175479,
  p=600.10834977333, lag z1=28.1275792678243, p1=10.6884801217732.
  Kiểm nguyên thiết kế trên CALIB v2 đã xong:

| Seed | R (%) | S (Nm) | e_rel (%) | ratio gain | ratio delay |
|---|---:|---:|---:|---:|---:|
| 0 | 14.44862823 | 0.41765644 | 45.05512621 | 1.57501319 | 1.00012117 |
| 1 | 14.47580549 | 0.41732846 | 45.44615218 | 1.57218168 | 1.00014555 |

  K6 cũ qua margin nhưng trượt e_rel<=10%; chưa được dùng làm Map đạt chuẩn v2.
  Report/harness tại `scratch/mappid_legacy_map_margin.json/.mat/.m` nếu còn trên
  máy này; số nguồn cũng nằm trong `Tracking/historychat_mappid.md`, Lượt56.
  PM/GM trong JSON cũ chỉ là metadata, cần tính lại khi nhập baseline.
- Map5 có chẩn đoán `Map_CALIB_window_diagnosis*_s00000.csv` tại Calib_v2:
  lỗi gain x2 còn nằm trong vùng vận hành bình thường, không chỉ vùng biên.
  Không kết luận trước rằng họ Map2 liên tục vô nghiệm từ các mẫu hiện có.

## 3. Lưới cố định cho đợt mới

Chuẩn hoá: K=5*(16/5)^uK, g_min=1/sqrt(2)+(1-1/sqrt(2))*ug.

1. uK=i/16 và ug=j/16, i,j=0..16: **17 x 17 = 289 cặp** phủ toàn miền.
2. Thêm hàng K=6 với cùng 17 mức g_min: **306 cặp của họ Map2** sau loại trùng.
3. Thêm **một baseline Map bài báo nguyên cực/zero**, tách nhãn baseline_legacy.
   Baseline này không cần thuộc ảnh của luật tổng hợp Map2 và không được
   tự quy ngược thành một điểm Map2 chỉ vì cùng K/g_min.

Tổng danh sách dự kiến: 306 cặp Map2 + 1 baseline. Lưu manifest trước mô phỏng.
Nếu phát hiện trùng vật lý thì báo cả số yêu cầu và số thiết kế thực khác nhau.
Không thêm lớp mịn thích nghi hay sửa lưới theo J giữa đợt này. u0=[.5,.5] không
có vai trò chọn tâm trong quét toàn miền cố định này. Lý do 306: tăng độ phủ K và
g_min, có K6 để kiểm chứng vùng cũ; không tuyên bố ngang công sức PID chỉ từ số cặp.

Mỗi cặp vẫn dùng chính `design_leadlag` với inner PM>=45 độ, GM>=2,
68 plants và bốn tỉ lệ độ dốc nếu đúng cấu hình đang có; chọn gain cao tần nhỏ nhất,
hòa theo PM. Kiểm tra số plants thực và ghi manifest; không thay inner law/bounds.
g_min=1 biểu diễn lag tắt với pole/zero hữu hạn bằng nhau, DC=1.
Tách nTried/nCoarse/nFine của inner synthesis khỏi số CALIB và số cặp ngoài.
Nếu inner không tìm được bù: ghi synth_failed, không giả tạo PM/GM hay chạy
thiết kế NaN. Với họ này, inner gate45 đã mạnh hơn outer gate30; phải công bố
giới hạn đó, không coi là đã khảo sát mọi lead–lag có PM30..45.

## 4. Chuẩn bị, cô lập dữ liệu và kiểm cache

- Tạo code trong `Model/Controllers/Map/script/`, ví dụ `run_map2_dense.m`,
  runner trong `tools/jobs/start_map2_dense.ps1`, hướng dẫn sử dụng cùng thư mục.
  Tên chính xác có thể điều chỉnh nhưng phải ghi vào nhật ký và README.
- Kết quả mới: `Result/Controllers/Map/Calib_v2/TwoParamDense/`;
  runtime/log/lock: `scratch/jobs/map2_dense/`.
- Ghi profile `Map2_Dense_v1`, manifest cặp, ngưỡng, seed, inner settings,
  source revision và hash đầu vào PRSM/CALIB/scoring/controller để truy nguyên.
- Giữ nguyên Map5, TwoParam, JSON hiện hành và mọi kết quả PID/MapPID.
  Không dùng marker cũ để kết luận job mới xong. Không sửa lịch sử khung khác.
- Dùng lại cache chỉ khi đúng K/g_min, cực/zero, seed, stress, schema và fingerprint
  môi trường/cách chấm. Lệch fingerprint: giữ làm reference, chạy lại đúng đợt.
  Seed0 của grid không thay thế nominal seed1 cho mẫu số margin seed1.
- Nhập báo cáo Map cũ vào kết quả bền vững và xác minh provenance; cần chạy lại
  nếu thiếu đầu vào/cửa sổ cần báo. Không buộc phải chạy lại mọi thứ nếu cache đủ.
- Tính calibration và nạp Plant/Actuator một lần mỗi phiên/worker. Chỉ đọc
  map.json, dùng `calibrate_map(false)`/override phù hợp, tránh ghi đè JSON giữa worker.

## 5. Đánh giá đầy đủ, cùng seed trong mỗi ratio

Với mọi cặp inner synthesis thành công, có tín hiệu hữu hạn và mô hình chạy được:

1. Tính lại outer PM, GM, lagGain2Hz; ghi giá trị thật và từng pass flag.
2. Chạy nominal seed0: R,S,J=R*S, TV, e_rel max và có dấu theo từng cửa sổ,
   R từng nhóm static/dyn/mu, tín hiệu thật dùng chung `calib_run`/`calib_score`.
3. Chạy nominal seed1 rồi gain x2 seed1 và delay+1ms seed1.
   ratio_gain=R_gain_seed1/R_nom_seed1; ratio_delay=R_delay_seed1/R_nom_seed1.
   Gain và delay là hai stress riêng (delay không đi kèm gain x2).
4. Phải đo cả delay khi gain trượt; phải đo margin cho điểm trượt e_rel nhưng
   vẫn hữu hạn và ổn định đủ để thử. Không dừng stress chỉ vì c4>0.
5. Thêm `stable/finite`, tỷ lệ saturation, nhóm/cửa sổ gây lỗi để giải thích
   hiệu năng; ratio>2 không tự chứng minh phân kỳ hay GM tuyến tính sai.

`calib_margin` hiện fail-fast khi gain trượt và có catch gộp lỗi thực thi.
Viết wrapper chẩn đoán riêng của Map dùng các lệnh `calib_run` chung để đo đầy
đủ hai stress và phân loại lỗi; không đổi logic chung của PID/MapPID hay định nghĩa R.
Không gọi lại simulator nhiều lần vô ích nếu đã có từng measurement checkpoint.

Gate chính giữ nguyên: PM>=30 độ, GM>=2, lagGain2Hz>=1/sqrt(2),
e_rel nominal seed0<=10%, ratio gain/delay seed1<=2, tín hiệu hữu hạn.
PM>=45 của inner là quy tắc tổng hợp, không đổi thành gate ngoài mới.
Seed0 dùng tìm/chọn, seed1 dùng stress theo quy trình đã có; báo đầy đủ seed.

## 6. Chọn điểm đạt chuẩn và điểm thoả hiệp

Đặt vector vi phạm, mọi thành phần không âm:

```
v_PM    = max(0, (30 - PM)/30)
v_GM    = max(0, (2 - GM)/2)
v_lag   = max(0, (1/sqrt(2) - lagGain2Hz)/(1/sqrt(2)))
v_erel  = max(0, (erel_pct - 10)/10)
v_gain  = max(0, (ratio_gain - 2)/2)
v_delay = max(0, (ratio_delay - 2)/2)
Vmax = max(v); Vsum = sum(v)
```

Đây là quy ước so độ vượt tương đối của tác giả, không phải trọng số an toàn
được suy ra từ vật lý. PM/GM/g_lag tốt không bù cho vi phạm ở tiêu chí khác.
Lưu raw values, khoảng cách có dấu tới ngưỡng và v cho cả sáu tiêu chí.
GM=Inf là không có phase crossover hữu hạn: không tự coi là lỗi simulator;
ghi rõ ý nghĩa. NaN/thiếu phép đo/lỗi workspace không được coi là v=0.

### Nếu có điểm qua tất cả gate

- Lọc khả thi toàn bộ trước, lập Pareto R,S trên pool khả thi đó.
- Tìm Jmin; tập J<=1.03*Jmin chọn PM lớn nhất, hòa tiếp J rồi K,g_min tăng dần
  để tái lập. Vì stress đã đo đầy đủ, không cần fallback dựa trên cache thiếu.
- Xuất `feasible_selected.json` và `.mat`, nhãn full_constraints_pass=true.
  Thiết kế cuối phải chứa cả K,g_min và cực/zero vật lý đầy đủ.

### Nếu không có điểm qua tất cả gate

- Ghi kết luận chính xác: **không có điểm khả thi trong tập 306 cặp đã khảo sát**;
  không khẳng định toàn miền liên tục hoặc mọi cấu trúc Map vô nghiệm.
- Dựng Pareto theo vector sáu vi phạm để thấy đánh đổi, không chỉ theo J.
- Ngưỡng ổn định/vận hành vẫn cứng: ứng viên thoả hiệp chỉ được lấy từ điểm
  có inner synthesis hợp lệ, PM/GM/lag đạt, nominal và hai stress đều hoàn tất,
  tín hiệu hữu hạn. Các điểm phân kỳ/simulator lỗi không được xếp thành thiết kế dùng được.
- Trong pool này chọn thứ tự từ điển (Vmax, Vsum, J, -PM, K, g_min).
  So số dùng dung sai 1e-9 tương đối/absolute đã ghi trước; không dùng hòa3%
  của J để bỏ qua khác biệt vi phạm. Nếu baseline không thuộc họ Map2, báo
  xếp hạng baseline riêng, không thay thế điểm Map2 được giao cho downstream.
- Xuất `compromise_candidate.json/.mat`, full_constraints_pass=false,
  violated_constraints và raw measurements. **Không tạo Map đạt chuẩn giả.**
  Nếu không có pool hữu hạn đủ điều kiện: chỉ báo infeasible, không chọn thoả hiệp.
- Công bố điểm thoả hiệp như ứng viên thử nghiệm/khởi tạo, cùng mọi độ vượt;
  không overwrite map.json hay gọi đây là bộ đã thoả chuẩn. Không tự nới e_rel,
  gain ratio hay delay threshold sau khi thấy số.

Sau khi chốt lựa chọn theo seed tìm/stress, chạy nominal seed1..5 cho điểm chọn
và tối đa bốn phương án Pareto đại diện, báo mean/std, e_rel max và vi phạm từng
seed. Seed bổ sung là báo cáo, không âm thầm chọn lại theo J trung bình. Nếu
reporting seed vi phạm thì đánh dấu review_required và ghi rõ, không giấu cảnh báo.
Vẽ độ nhạy tỷ lệ 1.5/2/3 từ measurements đã có; không đổi gate chính2.

## 7. Vận hành RAM, cache, watchdog và tự sửa lỗi

- Mục tiêu RAM vật lý toàn máy **80–90%**, chừa ít nhất10%; kiểm thêm commit
  headroom. Đây là chỉ tiêu vận hành, không cấp phát RAM giả để đạt80%.
- Một supervisor/lock duy nhất cho profile. Kiểm tra các process cũ trước chạy;
  chỉ dừng cây Map thuộc nhiệm vụ này khi nó gây chạy trùng/ghi đụng. Không giết
  MATLAB theo tên, không dừng công việc khung khác.
- Worker count tự chọn theo RAM đo thực tế, CPU và số task còn lại; khởi động
  tăng dần, không hardcode sáu worker chỉ vì từng dùng được. Tính cả client và
  worker pool; không mở pool nội bộ trong từng worker gây lồng song song.
- Sampling RAM khoảng10s; dưới10% reserve thì checkpoint/dừng đúng worker sở
  hữu và giảm concurrency; khi dưới80% liên tục180s và đủ headroom mới tăng.
  Khi chờ headroom phải ghi heartbeat và lý do, không báo treo vô căn cứ.
- MATLAB `-softwareopengl`, hidden window; TEMP/prefs riêng mỗi worker ở vị trí
  hợp lệ có sẵn/được phép. `Simulink.sdi.clear` và bỏ log nặng sau mỗi simulation;
  chỉ giữ raw signal của baseline, điểm chọn và các điểm chẩn đoán cần thiết.
- Mỗi task có khóa/worker riêng; client duy nhất merge/select. Ghi CSV/checkpoint
  ngay sau từng phép đo, publish JSON/MAT atomic; cache key phân biệt từng stress.
  Resume không đổi manifest, không tính lỗi native thành rejection khoa học.
- Native heap/access crash: retry đúng task/worker sau60s và đủ startup headroom,
  peers khỏe tiếp tục. Code/workspace lỗi: ghi stack, sửa đúng phạm vi rồi retry;
  nếu lặp3 lần cần audit, không retry mù. Timeout chưa phân biệt được lỗi mô hình
  hay tài nguyên thì đánh execution_unresolved, không xếp hạng như số vật lý.
- Nếu cùng task native-crash3 lần, tái lập riêng một worker để chẩn đoán;
  không tự chế số. Hết phương án an toàn thì báo missing/unresolved và chặn
  công bố kết quả đầy đủ. Watchdog không restart vòng selector noMargin.
- Timer/watchdog kiểm worker liveness + CPU/heartbeat/measurement progress;
  chỉ idle khi không còn task hoặc mọi task đã có kết quả/phân loại rõ.
  Log RAM/concurrency/retry, mọi lỗi/cách sửa vào **historychat_map.md**.

## 8. Deliverables và thứ tự thực hiện

1. Khung Map ghi Lượt mở đầu/trạng thái, rà soát code hiện có và dirty changes;
   giữ sửa đổi của người dùng, không reset/stash hay dọn hàng loạt.
2. Tạo manifest306 cặp + baseline, runner/evaluator riêng Map; test nhẹ mapping,
   endpoints, số lượng, cache key, tắt lag, khôi phục từ checkpoint và đầy đủ hai
   stress khi gain fail. Không cần rerun tests đã có nếu không sửa phần liên quan.
3. Preflight một baseline và một cặp grid; phát hiện sai khác với số cũ phải
   giải thích bằng source/input fingerprint trước chạy full. Không đổi gate để khớp số.
4. Launch nền, giữ RAM80–90% và theo dõi/recover tới xong; báo tiến độ thực.
5. Xuất manifest, synthesis.csv, nominal.csv, stress.csv, constraints.csv,
   execution_errors.csv (nếu có), violation_pareto.csv, selection_summary.json,
   JSON/MAT đạt chuẩn hoặc thoả hiệp theo mục6, báo cáo năm seed.
6. Báo cáo Markdown gồm bảng tất cả gate của điểm chọn + baseline, số tổng hợp
   bù/cặp duy nhất/mô phỏng thật/cache hit/retry, Pareto R,S, bản đồ K–g_min của
   e_rel/ratio_gain/ratio_delay/Vmax và vùng khả thi; ghi cửa sổ gây lỗi và dấu.
7. Ghi kết luận và lệnh reproduce/resume vào historychat_map.md/README. Đóng
   supervisor sau khi xong, không auto chạy DREWS hoặc MapPID. Báo người dùng
   kết quả và vị trí dữ liệu để khung MapPID có thể đọc làm initializer sau này.

Không yêu cầu commit/push toàn repo trong nhiệm vụ này; chỉ chuẩn bị file đúng
phạm vi Map và kết quả. Nếu người dùng yêu cầu chuyển máy thì commit/push scoped,
tránh gom tài liệu Paper hoặc thay đổi chưa liên quan của khung khác.
