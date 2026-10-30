# Dàn ý phần 4: Controller Parameter Selection

Cập nhật theo việc bổ sung cổng lọc vi phân cho MapPID và kiểm lại CSV ngày 2026-10-30.
Đây là dàn ý để viết mục 4. Bố cục bài dự kiến gồm 4.1–4.5; bằng chứng kiểm dữ liệu và danh sách việc còn lại đặt riêng ở cuối file.

## Mạch trình bày

Đi từ cấu hình mô phỏng đến ca hiệu chỉnh, định nghĩa điểm số, điều kiện chấp nhận, cách tìm và chọn tham số, rồi giải thích kết quả CALIB.
Trọng tâm là việc thêm nhánh PID vào Map đã cố định. PID thay bản đồ là cấu hình tham chiếu.

Mô hình vật lý và giới hạn trợ lực đã có ở mục 2; cấu trúc điều khiển và chống bão hòa đã có ở mục 3.
Mục 4 chỉ bổ sung các chi tiết triển khai cần để tái lập việc hiệu chỉnh. Phương trình mới tiếp tục từ (43), sau (42) của mục 3 hiện tại.
Mọi phương trình viết trong miền thời gian theo quy tắc đã cập nhật.

## 4.1. Simulation setup

### Mục đích đoạn

Nêu môi trường dùng chung và các giả thiết triển khai có ảnh hưởng đến việc chọn tham số.

### Nội dung cần viết

- Dùng mô hình cột lái, lốp phi tuyến và thân xe đã trình bày ở mục 2.
- Chu kỳ điều khiển và lưới tín hiệu dùng để chấm điểm đều là 1 ms.
- Động học động cơ bậc nhất có tần số 100 Hz. Viết bằng phương trình vi phân nếu cần bổ sung vào bài:

\[
\frac{dT_a}{dt}=\omega_m\left(T_{a,cmd}-T_a\right),\qquad \omega_m=2\pi\,100.
\]

- Cấu hình danh định: hệ số khuếch đại cơ cấu chấp hành bằng 1, độ trễ tính toán bổ sung bằng 0.
- Giới hạn trợ lực dùng chung theo mục 2.6 và phép chặn đã định nghĩa ở mục 3.
- Cảm biến đi qua nhiễu trắng, lượng tử hóa và giữ mẫu. Tóm tắt các thông số liên quan đến ba bộ điều khiển bằng một bảng nhỏ.

| Đại lượng đo | Độ phân giải | Chu kỳ cập nhật |
|---|---:|---:|
| Mô-men thanh xoắn | 0.01 N m | 1 ms |
| Tốc độ xe | 1 km/h | 10 ms |
| Gia tốc ngang | 0.01 g | 10 ms |

- Độ lệch chuẩn nhiễu lấy đúng từ cấu hình cảm biến hiện hành; phân biệt giá trị giả định của mô phỏng với thông số có nguồn thiết bị.
- Bộ điều khiển nhận tín hiệu đo có nhiễu. Điểm số dùng tín hiệu thật của mô hình để đo sai lệch vật lý và mô-men trợ lực thực.
- Thông số cơ học không cần chép lại nếu đã có trong mục 2.

## 4.2. Calibration case and performance measures

### 4.2.1. Ca CALIB

Nêu một chuỗi hiệu chỉnh dài 140 s, gồm chín khối tốc độ từ 20 đến 100 km/h, bước 10 km/h.
Góc vô-lăng, tốc độ xe và hệ số bám là các đầu vào mô phỏng. Gia tốc ngang danh định dùng để tạo góc lái từ bảng cân bằng xác lập.
Gia tốc ngang thực được sinh bởi mô hình và được đo để tính mô-men mục tiêu; không ép thân xe bám một tín hiệu gia tốc ngang đặt sẵn.

| Kích thích | Điều kiện | Cửa sổ đánh giá | Nhóm điểm R |
|---|---|---:|---|
| Giữ cua | 20 km/h: 0.10, 0.18 g; 30–100 km/h: 0.10, 0.20, 0.30 g | 26 | static |
| Chuyển tiếp giữa các mức | Mỗi mức 3 s: tăng 1 s, giữ 2 s | 26 | dyn |
| Đánh lái sin | 40–100 km/h: 0.5 Hz ở 0.3 g và 1 Hz ở 0.15 g | 14 | dyn |
| Giảm và tăng độ bám | 60 km/h, góc lái ứng với 0.3 g, hệ số bám 0.8 → 0.35 → 0.8 | 2 | mu |

- Giữ cua: dùng 1 s cuối của mỗi mức để tính sai lệch trung bình; 2 s đầu của mức thuộc cửa sổ chuyển tiếp.
- Cửa sổ giữ cua là định nghĩa đánh giá, không bảo đảm mọi ứng viên đã đạt xác lập hoàn toàn trong 1 s cuối, nhất là Map có đáp ứng chậm.
- Đánh lái sin gồm 1.25 chu kỳ ở 0.5 Hz (2.5 s), sau đó 3.5 chu kỳ ở 1 Hz (3.5 s); bắt đầu từ pha cosin tại đỉnh.
- Chỉ dùng sin từ 40 km/h trở lên để hạn chế vai trò chi phối của quán tính cột lái ở tốc độ thấp.
- Ở đoạn đổi độ bám, giữ mức 0.35 trong 6 s và mức 0.8 sau đó trong 4 s; chấm 2 s sau mỗi lần đổi.
- Tổng cộng 68 cửa sổ, gộp thành ba nhóm: static, dyn gồm chuyển tiếp và sin, mu.
- Hai giây đầu của toàn ca được bỏ khi tính S; không diễn giải thành bỏ 2 s đầu của từng khối tốc độ.

### 4.2.2. Sai lệch bám

Dùng cùng ký hiệu sai lệch mô-men của mục 3, nhưng tính từ mô-men thật khi chấm.
Với mỗi nhóm g, gộp các mẫu nằm trong hợp các cửa sổ của nhóm rồi tính:

\[
R_g=100\frac{\operatorname{RMS}_g(e_T)}{\operatorname{mean}_g(|T_{ref}|)}.
\]

\[
R=\left[\prod_{g\in\{static,dyn,mu\}}\max(R_g,1)\right]^{1/3}.
\]

- R và R_g có đơn vị phần trăm; số 1 trong phép lấy max tương ứng sàn 1%.
- Ba nhóm có trọng số bằng nhau dù thời lượng và số cửa sổ khác nhau.
- Sàn 1% ngăn sai lệch rất nhỏ của một nhóm tiếp tục kéo giảm điểm tổng hợp.

### 4.2.3. Thành phần nhanh của mô-men trợ lực

- Tính từ T_a sau động học động cơ, không dùng lệnh mô-men trước động cơ.
- Lọc thấp bậc nhất ở 5 Hz rồi lấy phần dư. Khi mô tả chính xác phép tính rời rạc trong mã, có thể dùng:

\[
T_{a,LP}[k]=(1-\alpha)T_{a,LP}[k-1]+\alpha T_a[k],\qquad
\alpha=\frac{\Delta t}{1/(2\pi\,5)+\Delta t}.
\]

\[
S=\operatorname{RMS}_{t\ge2\,s}\left(T_a[k]-T_{a,LP}[k]\right).
\]

- S tính trên toàn ca từ 2 s đến hết 140 s, không tính theo ba nhóm cửa sổ của R.
- Đây là chỉ tiêu thành phần nhanh của mô-men trợ lực, gồm ảnh hưởng của nhiễu và đáp ứng nhanh; không đồng nhất hoàn toàn với nhiễu cảm biến.

### 4.2.4. Sai lệch trung bình khi giữ cua và tổng hợp qua hạt giống

- Với mỗi lần chạy, lấy sai lệch trung bình tương đối lớn nhất qua 26 cửa sổ giữ cua.
- Khi đánh giá trên năm hạt giống chung, lấy trung bình số học của R và S để được Rbar và Sbar.
- e_rel_max là giá trị lớn nhất qua cả 26 cửa sổ và năm hạt giống.
- Tổng biến thiên mô-men trợ lực TV (N m/s) và tỉ lệ trợ lực ngược chiều chỉ dùng báo cáo phụ.

\[
\bar R=\frac{1}{5}\sum_{q=1}^{5}R_q,\qquad
\bar S=\frac{1}{5}\sum_{q=1}^{5}S_q.
\]

\[
e_{rel,max}=100\max_{q,w}
\frac{|\operatorname{mean}_{w}(e_{T,q})|}
{\operatorname{mean}_{w}(|T_{ref,q}|)}.
\]

## 4.3. Design constraints and acceptance criteria

### 4.3.1. Điều kiện cấu trúc và dải lái

Nhắc gọn quan hệ giữa tham số chuẩn và tham số triển khai, không suy diễn lại PID đã có ở mục 3:

\[
K_i=K_p/T_i,\qquad K_d=K_pT_d,\qquad \tau_f=T_d/N.
\]

| Điều kiện | Map | PID | MapPID |
|---|---|---|---|
| Biên pha tối thiểu | 30° | 30° | 30° |
| Biên độ dự trữ tối thiểu | 2 | 2 | 2 |
| Dải lái tại 2 Hz | Độ lợi khâu lag ≥ 0.707 | Độ lợi bộ lọc D ≥ 0.707 | Cả khâu lag và bộ lọc D ≥ 0.707 |
| Cấu trúc PID | Không áp dụng | T_d < T_i | T_d < T_i |
| Chính xác để vào tập full | e_rel_max ≤ 10% | e_rel_max ≤ 10% | e_rel_max ≤ 10% |
| Kiểm tra phi tuyến | Cùng hai phép thử stress | Cùng hai phép thử stress | Cùng hai phép thử stress |

- Với PID và MapPID, điều kiện dải lái của bộ lọc D tương đương tau_f ≤ 79.6 ms.
- T_d < T_i đặt thời gian chống bão hòa T_t = sqrt(T_i T_d) nằm giữa T_d và T_i; dùng lập luận theo sách đã trình bày ở mục 3.
- MapPID giữ nguyên bản đồ và khâu bù của Map; nhánh PID thêm vào vẫn phải đạt điều kiện dải lái.
- Các thiết kế cuối cùng được đối chiếu theo các điều kiện tương ứng trong bảng.
- Khi mô tả thời điểm thực hiện, ghi đúng: cổng tau_f của MapPID được kiểm bổ sung trên dữ liệu sau tìm kiếm.
  Việc kiểm bổ sung xác nhận tập đánh giá, các mặt Pareto cuối và điểm được chọn đều đạt cổng này.
- Không viết rằng cổng tau_f đã sàng mọi điểm MapPID trước mô phỏng trong lần chạy tạo dữ liệu hiện tại.
- Chi tiết sửa mã và bảng kiểm CSV đặt ở ghi chú nội bộ cuối dàn ý; trong bài chỉ cần nêu cách kiểm bổ sung và kết quả không đổi.

### 4.3.2. Sàng lọc tuyến tính

- Kiểm trên 68 mô hình tuyến tính hóa: 17 tốc độ từ 20 đến 100 km/h và bốn điểm làm việc ở mỗi tốc độ.
- Bốn điểm gồm a_y = 0.001 và 0.30 g trên hệ số bám 0.8; a_y = 0.001 và 0.15 g trên hệ số bám 0.2.
- Vòng hở tuyến tính gồm bộ điều khiển, động cơ 100 Hz và trễ 1 ms.
- MapPID được kiểm ở năm độ dốc bản đồ bằng K_max nhân với 0, 0.25, 0.50, 0.75 và 1.
- Trường hợp độ dốc bằng 0 đại diện vùng chết, khi nhánh PID là đường phản hồi còn hoạt động.
- Bộ Map có điều kiện tổng hợp lead–lag nội bộ chặt hơn, gồm biên pha tối thiểu 45° và biên độ dự trữ tối thiểu 2.
- Sàng lọc tuyến tính chạy trước mô phỏng CALIB để giảm số lần mô phỏng.
- Phân biệt trễ 1 ms của bước sàng lọc tuyến tính với cấu hình mô phỏng danh định không có trễ bổ sung.
- Các biên tuyến tính không thay thế kiểm tra trên mô hình phi tuyến có bão hòa và tín hiệu đo rời rạc.

### 4.3.3. Kiểm tra phi tuyến bằng CALIB

Hai phép thử được thực hiện riêng biệt trên toàn chuỗi CALIB:

1. Nhân đôi độ lợi cơ cấu chấp hành, giữ trễ bổ sung bằng 0.
2. Thêm trễ điều khiển 1 ms, giữ độ lợi cơ cấu chấp hành bằng 1.

- Dùng hạt giống 99990 và so với lần chạy danh định cùng hạt giống.
- Điều kiện trong mã: R danh định và R stress hữu hạn, dương; R_stress/R_nom ≤ 2 ở cả hai phép thử.
- Không có điều kiện yêu cầu mô-men trợ lực phải dương.
- Nếu trượt phép thử độ lợi thì bỏ qua phép thử trễ vì ứng viên đã không thể được chọn.
- Chỉ chạy stress cho các điểm đang nằm trên mặt Pareto. Loại điểm trượt, tính lại mặt và kiểm các điểm mới xuất hiện.
- Lặp đến khi mọi điểm trên hai mặt cuối đã được kiểm và đạt.
- Gọi đây là tiêu chí chấp nhận vận hành trên ca thử đã định nghĩa; không diễn giải thành chứng minh ổn định toàn cục.
- Hệ số ×2 và ngưỡng tỷ số 2 là lựa chọn của quy trình. Trễ 1 ms tương ứng một chu kỳ điều khiển.
- Nếu dùng tài liệu Seborg để giải thích bối cảnh chọn ngưỡng, kiểm lại PDF gốc trước khi trích; không gán ngưỡng R_stress/R_nom = 2 cho sách.
- Chỉ báo độ nhạy ở ngưỡng tỷ số 1.5 và 3 nếu có dữ liệu đã kiểm; không nhầm với việc đã mô phỏng độ lợi cơ cấu chấp hành 1.5 hoặc 3 lần.

## 4.4. Parameter search and final selection

### 4.4.1. Biến thiết kế và hộp tìm kiếm

| Cấu trúc | Biến tìm kiếm | Khoảng |
|---|---|---|
| Map | K_max | 1–30, thang log, không thứ nguyên |
| Map | g_min của khâu lag trong dải 0.2–2 Hz | 1/sqrt(2)–1, thang log |
| PID và nhánh PID của MapPID | K_p | 0.01–30, thang log |
| PID và nhánh PID của MapPID | T_i | 0.002–10 s, thang log |
| PID và nhánh PID của MapPID | T_d | 0.020–0.796 s, thang log |
| PID và nhánh PID của MapPID | N | 8–20, thang log |

- Map: với mỗi cặp K_max và g_min, tổng hợp lead–lag bằng quy tắc cố định trên các mô hình tuyến tính hóa.
- g_min = 1 tương ứng tắt tác dụng suy giảm của khâu lag.
- MapPID: khóa năm tham số Map theo thiết kế Map đã chọn, chỉ tìm bốn tham số PID.
- Cùng hộp PID cho PID và MapPID; không xem MapPID là bài toán chín biến tự do.
- K_aw được tính từ sqrt(K_i/K_d) cho cả hai cấu trúc, không phải biến tìm kiếm thứ năm.
- Giải thích giới hạn hộp bằng tài liệu hoặc lý thuyết. Không dùng tham số của thiết kế cũ để biện minh.

### 4.4.2. Tìm từ thô đến tinh

- Chuẩn hóa mỗi biến về [0,1] sau biến đổi log.
- PID và MapPID: bốn mức mỗi biến ở lưới thô, tương ứng 256 điểm.
- Map: 13 mức mỗi biến, tương ứng 169 cặp ở lưới thô; lead–lag được tổng hợp bên trong từng cặp.
- Lưới mịn có ba mức mỗi biến, quanh điểm khả thi có J = R S nhỏ nhất ở hạt giống tìm.
- Tâm lưới mịn không phải mọi điểm trên mặt Pareto.
- Bước mịn ban đầu bằng 1/6 với PID, MapPID và 1/24 với Map.
- Tâm không đổi thì chia đôi bước; dừng khi bước dưới 0.02 hoặc đạt sáu lớp tinh chỉnh.
- Map có quy tắc dự phòng khi không có điểm đạt cổng chính xác: lấy tâm theo J nhỏ nhất trong tập đạt điều kiện an toàn và stress.
- Dùng bộ nhớ đệm để tránh mô phỏng lại điểm trùng.
- Hạt giống tìm cục bộ: Map 00000, PID 10000, MapPID 30000.
- Mô tả là tìm kiếm lưới hữu hạn từ thô đến tinh, không khẳng định tối ưu toàn cục.

### 4.4.3. Đánh giá lại trên năm hạt giống chung

1. Lấy mọi điểm đã được mô phỏng sau sàng lọc cấu trúc và tuyến tính làm tập ứng viên.
   Chưa loại theo e_rel hay stress ở bước tạo tập này.
2. Pha 1: lấy mặt Pareto theo R và S ở hạt giống tìm cục bộ, đánh giá lại trên 99990–99994.
3. Với từng bộ điều khiển, tính sigma_R và sigma_S bằng trung vị của độ lệch chuẩn chia trung bình qua năm hạt giống, trên các điểm pha 1.
4. Pha 2: đánh giá thêm các ứng viên chưa bị mặt pha 1 trội chắc chắn trong dải ba sigma.
5. Tính Rbar, Sbar và e_rel_max trên năm hạt giống chung; lập hai tập chấp nhận và hai mặt Pareto.
6. Áp dụng vòng kiểm stress, loại điểm trượt và tính lại mặt đến khi hoàn tất.

Điểm p bị loại khỏi pha 2 khi tồn tại điểm f ở pha 1 thỏa đồng thời:

\[
R_{0,f}(1+3\sigma_R)\le R_{0,p},\qquad
S_{0,f}(1+3\sigma_S)\le S_{0,p}.
\]

- Các điểm pha 1 luôn thuộc tập đánh giá.
- Dải ba sigma là quy tắc mở rộng tập ứng viên theo dao động giữa hạt giống, không diễn giải thành khoảng tin cậy thống kê.
- Kiểm độ nhạy bằng cách so mặt trên tập này với mặt trên mọi điểm đã được đánh giá.
  Chỉ ghi kết quả trùng nhau sau khi đối chiếu báo cáo của từng bộ.
- Đối với dữ liệu MapPID hiện tại, cổng tau_f được kiểm bổ sung sau tìm kiếm và xác nhận không làm thay đổi các tập dùng để chọn cuối.

### 4.4.4. Hai mặt Pareto và quy tắc chọn điểm

- safe: mặt không bị trội trong tập đạt điều kiện cấu trúc, tuyến tính và stress; chưa bắt buộc e_rel_max ≤ 10%.
- full: mặt không bị trội khi thêm điều kiện e_rel_max ≤ 10%.
- Tập khả thi full nằm trong tập khả thi safe, nhưng mặt Pareto full không nhất thiết là tập con của mặt Pareto safe.
- Ưu tiên chọn trên mặt full. Nếu full rỗng, chọn trên mặt safe và ghi rõ rằng cấu hình không đạt ngưỡng chính xác.

\[
J=\bar R\,\bar S.
\]

- Tính J_min trên mặt được dùng để chọn.
- Giữ các điểm có J ≤ 1.03 J_min, sau đó chọn biên pha tuyến tính lớn nhất.
- Đây là quy tắc hòa 3%, không phải chọn đúng duy nhất điểm có tích Rbar Sbar nhỏ nhất.
- Khóa cấu hình cuối trước khi kiểm độc lập ở phần 5.

## 4.5. Calibration results and selected parameters

### 4.5.1. Số lượng ứng viên

Dùng bảng dưới để mô tả quy mô dữ liệu và hai mặt cuối.
Các số này giữ nguyên sau khi kiểm bổ sung cổng tau_f của MapPID.

| Bộ | Đã mô phỏng sau sàng lọc | Trong tập đánh giá | Đạt e_rel_max trong tập | Mặt safe cuối | Mặt full cuối |
|---|---:|---:|---:|---:|---:|
| Map | 149 | 80 | 17 | 58 | 0 |
| PID | 184 | 134 | 99 | 44 | 31 |
| MapPID | 225 | 187 | 142 | 33 | 22 |

- Cột đạt e_rel_max được đếm trước khi loại theo stress, không có nghĩa các điểm đó đạt mọi điều kiện.
- Với Map, 17 điểm đạt điều kiện chính xác không tạo được mặt full sau kiểm stress.
- Hai cột mặt safe và full không phải hai bước nối tiếp của một phép đếm loại dần.
- Số 225 ứng viên MapPID mô tả dữ liệu lịch sử đã được mô phỏng. Không đổi thành 224 hoặc viết rằng tất cả đã qua cổng tau_f trước mô phỏng.
- Điểm MapPID vượt tau_f không nằm trong 187 điểm dùng cho đánh giá chung và không ảnh hưởng hai mặt cuối.

### 4.5.2. Tham số đã chọn

Bảng tham số chính nên dùng K_p, T_i, T_d, N, đúng với bốn biến được tìm.
K_i, K_d, tau_f và K_aw là các giá trị suy ra, có thể ghi cùng bảng hoặc trong phần triển khai.

| Tham số | PID | MapPID |
|---|---:|---:|
| K_p | 2.90376113881 | 2.08008382306 |
| T_i (s) | 0.03419951893347 | 0.02398259905613 |
| T_d (s) | 0.02331802643614 | 0.02331802643604 |
| N | 19.25081683959 | 14.18412312226 |
| K_i | 84.9064907743 | 86.7330441622 |
| K_d | 0.067709978999 | 0.0485034495753 |
| tau_f (s) | 0.00121127465034 | 0.00164395262471 |
| K_aw | 35.41148228985 | 42.2869129155 |

Tham số Map được dùng nguyên vẹn cho nhánh Map của MapPID:

| Tham số | Giá trị |
|---|---:|
| K_max, không thứ nguyên | 6.77455395155 |
| g_min | 0.707106781 |
| Ngưỡng vùng chết T_s0 (N m) | 0.3 |
| Chu kỳ điều khiển (s) | 0.001 |
| Zero lead z (rad/s) | 33.50093752 |
| Pole lead p (rad/s) | 673.2661083 |
| Zero lag z_1 (rad/s) | 28.12757927 |
| Pole lag p_1 (rad/s) | 10.68848012 |

Các chữ số dài ở dàn ý phục vụ đối chiếu dữ liệu. Khi đưa vào bài, làm tròn nhất quán theo đơn vị và độ chính xác cần thiết.
T_d của cả PID và MapPID khoảng 23.3 ms, gần cận dưới 20 ms của hộp tìm kiếm. Báo vị trí này trung thực, không gọi là nghiệm nằm sâu trong hộp.

### 4.5.3. Chất lượng hiệu chỉnh của các điểm chọn

| Chỉ tiêu | Map | PID | MapPID |
|---|---:|---:|---:|
| Rbar (%) | 12.0719 | 3.2241 | 2.5330 |
| Sbar (N m) | 0.4397 | 0.7782 | 0.7953 |
| J (% N m) | 5.3085 | 2.5089 | 2.0145 |
| e_rel_max (%) | 26.2366 | 2.0861 | 1.8056 |
| Biên pha nhỏ nhất (°) | 45.49 | 50.78 | 39.04 |
| Biên độ dự trữ nhỏ nhất | 5.24 | 6.22 | 3.13 |
| Mặt dùng để chọn | safe, không đạt e_rel_max | full | full |

Các ý cần rút ra theo thứ tự:

1. Map không đạt đồng thời ngưỡng chính xác và kiểm stress trong tập tìm kiếm đã xét.
   Cấu hình đại diện được lấy trên mặt safe; e_rel_max khoảng 26.2% phải được công bố rõ.
2. MapPID giảm sai lệch tổng hợp so với Map nhưng tăng thành phần nhanh của mô-men trợ lực.
   Map ít nhiễu hơn ở điểm chọn không đồng nghĩa đã đạt yêu cầu bám.
3. So với PID, MapPID có Rbar và J nhỏ hơn ở điểm chọn, nhưng Sbar cao hơn khoảng 2.2%.
   Không viết MapPID luôn ít nhiễu hơn PID.
4. Các mặt Pareto rời rạc có vùng cắt nhau; điểm chọn không đủ để khẳng định một cấu trúc trội trên toàn bộ mặt.
5. Kết luận phần 4 chỉ áp dụng cho CALIB và bộ tham số đã chọn.
   Khả năng dùng trên các thao tác khác được đánh giá bằng SSW ở phần 5.

### Hình và bảng nên ưu tiên

- Một bảng kịch bản và cửa sổ CALIB.
- Một bảng hộp tham số và điều kiện chấp nhận, gộp hoặc tách tùy độ dài.
- Bảng tham số cuối và bảng điểm số; có thể gộp khi dàn trang.
- Một hình về giới hạn chính xác và điều kiện stress của Map, nếu dữ liệu thể hiện rõ quan hệ này.
- Một hình Pareto chung, có hai ô safe và full, đánh dấu điểm chọn và phân biệt ba bộ bằng nét/dấu đọc được khi in trắng đen.
- Hình kết quả phải sinh bằng MATLAB từ dữ liệu chính thức. Chỉ định số hình/bảng sau khi thống nhất bố cục.

## Ghi chú nội bộ: việc đã hoàn tất về cổng tau_f

Phần này giữ bằng chứng để viết đúng phương pháp; không chép nguyên lịch sử sửa mã vào nội dung bài.

### Thay đổi mã đã thực hiện

- Ngày 2026-10-30, đã thêm cổng tau_f ≤ 79.6 ms cho nhánh PID vào mappid_eval.m.
- Cổng mới nằm trước bước đọc CSV nên điểm cũ lưu trong bộ nhớ đệm cũng bị từ chối nếu vi phạm khi gọi lại hàm.
- Điều kiện T_d < T_i đã có từ trước, dưới dạng K_d K_i < K_p^2.
- Mã mới chưa được chạy thử bằng MATLAB theo nhật ký cập nhật.
- Kiểm dữ liệu CSV đã hoàn tất, không cần mô phỏng lại CALIB để chọn lại tham số.

### Bằng chứng kiểm dữ liệu hiện có

| Mục kiểm | Kết quả đã ghi nhận |
|---|---|
| Điểm có tau_f = 99.5 ms | 16 điểm góc lưới thô, bốn điểm mỗi luồng |
| Trong 16 điểm: chưa mô phỏng | 15 điểm bị loại bởi sàng lọc tuyến tính hoặc T_d < T_i |
| Điểm còn lại, K_p = 0.01 và K_i = 0.001 | Đã mô phỏng; e_rel khoảng 26%, J = Inf |
| Khả năng làm tâm tinh chỉnh của điểm này | Không thể do không đạt cổng chính xác |
| Lưới mịn: pareto, pareto_check, pick | Không có điểm vượt tau_f |
| Tập đánh giá MapPID: 187 điểm | Không có điểm vượt tau_f |
| Mặt safe cuối: 33 điểm | Không có điểm vượt tau_f |
| Mặt full cuối: 22 điểm | Không có điểm vượt tau_f |
| tau_f lớn nhất trên hai mặt cuối | Khoảng 29 ms |
| Điều kiện T_d < T_i | Không có vi phạm trong dữ liệu được kiểm |
| calib_margin trên hai mặt cuối | margin_done = 1 và margin_pass = 1 cho mọi điểm |

Điểm vượt cổng duy nhất đã được mô phỏng không tham gia tập đánh giá cuối và không thể làm tâm lưới mịn.
Việc kiểm bổ sung không thay đổi đường tinh chỉnh, tập dùng để chọn cuối, hai mặt Pareto hay bộ tham số đã chọn.
Phân biệt kết luận này từ CSV với việc chạy thử mã mới: kiểm dữ liệu đã xong, mã mới chưa được chạy thử.

### Cách phản ánh trong bài

- Nêu rõ điều kiện dải lái tương ứng của Map, PID và MapPID.
- Ghi rằng bộ lọc D của MapPID được kiểm bổ sung sau tìm kiếm và mọi thiết kế cuối đều thỏa.
- Giữ nguyên các con số của lần chạy chính thức; không mô tả lần chạy cũ như đã có cổng mới từ đầu.
- Không biến việc kiểm CSV thành một kết quả mô phỏng mới hoặc bằng chứng tổng quát về ổn định.

## Nguồn dữ liệu và việc còn lại trước khi viết

### Nguồn dùng để viết

- Model/data/map.json, pid.json và mappid.json: chỉ dùng trường design.
- Result/Compare/Pareto_common/ParetoCommon_Map_points_s99990-s99994.csv.
- Result/Compare/Pareto_common/ParetoCommon_PID_points_s99990-s99994.csv.
- Result/Compare/Pareto_common/ParetoCommon_MapPID_points_s99990-s99994.csv.
- File chọn riêng của PID: ParetoCommon_PID_select.csv và ParetoCommon_PID_select_report.csv.
- Định nghĩa ca và điểm số: make_cases.m, calib_score.m, calib_margin.m.
- Quy trình chọn chung: compare_pareto_common.m.
- Kiểm bổ sung cổng: Tracking/historychat_pareto_pc.md, Lượt 18–19.
- Không dùng legacy, design_pre_pareto, CSV trong Legacy_2026-10-27 hoặc số liệu mục 4–6 của bản bài cũ.

### Việc còn lại

- Kiểm nguồn hoặc lập luận độc lập cho các cận hộp tìm kiếm, nhất là cận dưới T_d = 20 ms.
- Đối chiếu giả thiết nhiễu và chu kỳ cảm biến với các tài liệu có sẵn; đánh dấu rõ phần tác giả tự đặt.
- Kiểm báo cáo độ nhạy của tập ứng viên và quy tắc chọn trước khi đưa nhận xét vào bài.
- Tạo lại hình từ dữ liệu PIDBOOK chính thức; các hình PID cũ không dùng để minh họa kết quả mới.
- Giữ CALIB 99990–99994 tách với SSW 99995–99999.
- Khi viết md nội dung mục 4, dùng nhãn câu và số phương trình tiếp nối mục 3.
- Chỉ đưa phần nội dung đã duyệt vào paper.txt; ghi chú kiểm CSV và danh sách việc nội bộ ở lại file dàn ý.
