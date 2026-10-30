# Dàn ý phần 5: Evaluation Results

## Mục tiêu và dữ liệu dùng để viết

Phần 5 trả lời ba câu hỏi: bám mô-men khi giữ cua, ứng xử khi điều kiện đổi trong cua, và đánh đổi giữa bám với thành phần nhanh của mô-men trợ lực khi lái liên tục.
Trọng tâm vẫn là MapPID so với Map. PID là cấu hình tham chiếu để thấy lợi ích và phần phải đánh đổi của nhánh ghép song song.

Chỉ lập kế hoạch nội dung, bảng và hình. Chưa viết thành văn bản bài báo.
Dùng ba ca SSW, viết đầy đủ lần đầu là STEADY, SLIP và WEAVE. Mỗi ca dài 100 s.
Bộ tham số là các thiết kế cuối đã báo cáo ở mục 4, không hiệu chỉnh lại theo kết quả kiểm tra.

Dữ liệu chính thức đã có đủ 15 tệp metrics và 45 tệp tín hiệu:
ba bộ điều khiển × năm hạt giống 99995–99999 × ba ca.
Có 510 dòng metrics, gồm ba dòng toàn ca và 31 cửa sổ cho mỗi bộ/hạt giống.
Trong 31 cửa sổ có 11 STEADY, 12 SLIP và 8 WEAVE.

Năm hạt giống CALIB 99990–99994 chỉ dùng chọn tham số ở mục 4.
Hình minh họa dùng hạt giống 99999, bảng thống kê dùng đủ năm hạt giống kiểm tra.
Không dùng các hạt giống cũ hoặc số liệu trong bảng tổng hợp chưa cập nhật.

## Quy ước trình bày

- Mọi phương trình và đại lượng động học theo miền thời gian; kích thích tuần hoàn ghi chu kỳ bằng giây.
- Giữ ký hiệu hiện tại: T_a,cmd trước giới hạn, T_a,lim sau giới hạn, T_a là mô-men thực sau động cơ.
- Mô-men mục tiêu trong bài là T_ref; cột tương ứng trong CSV mang tên T_d_ref.
- Trình bày kết quả mô phỏng của một xe, với đầu vào góc vô-lăng được quy định.
- Gọi đây là kiểm tra với tham số đã khóa; không gọi là thử nghiệm xe thật, kiểm chứng mù hoặc kiểm tra trên một mô hình xe độc lập.
- Nêu tổ hợp và diễn biến kích thích khác CALIB; không khẳng định mọi tốc độ hay mọi mức gia tốc đều chưa xuất hiện khi hiệu chỉnh.
- Sai lệch thực được tính từ tín hiệu thật của mô hình; bộ điều khiển vẫn nhận tín hiệu đo có nhiễu.
- Giữ mỗi dòng tối đa 200 ký tự. Khi viết md nội dung sẽ dùng nhãn [5.k.n] như các mục trước.

## 5.1. Evaluation Protocol

### Nhiệm vụ của mục

Nêu điều kiện kiểm tra, chỉ tiêu và cách đọc kết quả; không lặp mô hình hay quy trình tìm tham số của mục 4.

### Nội dung cần viết

- Ba cấu trúc dùng cùng mô hình xe, cảm biến, giới hạn trợ lực và tín hiệu góc lái/tốc độ/hệ số bám.
- Cùng hạt giống cho cùng ca giữa các bộ tạo cùng điều kiện nhiễu, không có nghĩa mô-men đo của chúng giống nhau.
- Bỏ 2 s đầu khi tính chỉ tiêu toàn ca. Khoảng chấm là 2–100 s.
- Báo trung bình và độ lệch chuẩn mẫu qua năm lần chạy, không coi chúng là năm xe hay năm cấu hình cơ học khác nhau.
- Phân biệt kết quả toàn ca với kết quả trong cửa sổ giữ cua hoặc đổi độ bám.

### Bảng kịch bản dự kiến

| Ca | Câu hỏi chính | Kích thích cần mô tả | Số cửa sổ |
|---|---|---|---:|
| STEADY | Độ chính xác khi giữ cua trên đường khô | Bốn tốc độ 25, 45, 65, 85 km/h, mức nhẹ đến 0.35–0.38 g | 11 |
| SLIP | Khi tốc độ hoặc độ bám đổi trong cua | Giảm/tăng tốc, giảm bám theo bậc, vũng nước kéo dài 2 s | 12 |
| WEAVE | Bám khi lái liên tục và đảo chiều | Quanh tâm, đổi làn qua nước, rút ngắn chu kỳ lái, lái trên đường trơn | 8 |

### Chỉ tiêu chính

Dùng E_RMS (N·m) cho RMS sai lệch toàn ca kiểm tra, tránh dùng lại R của CALIB vì R ở mục 4 là phần trăm tổng hợp ba nhóm.

\[
E_{RMS}=\sqrt{\frac{1}{|\mathcal I|}\sum_{k\in\mathcal I}e_T[k]^2},
\qquad \mathcal I=\{k:2\,\mathrm{s}\le t_k\le100\,\mathrm{s}\}.
\]

S dùng bộ làm trơn và định nghĩa phần dư ở mục 4, với tau_S = 31.8310 ms.
Khoảng tính RMS của phần dư đổi thành 2–100 s, không giữ cận 140 s của CALIB.

Với cửa sổ giữ cua một chiều, dùng sai lệch trung bình có dấu theo chiều mô-men mục tiêu:

\[
\epsilon_w=
100\,\operatorname{sgn}\!\left(\operatorname{mean}_w T_{ref}\right)
\frac{\operatorname{mean}_w(e_T)}
{\operatorname{mean}_w(|T_{ref}|)}.
\]

- epsilon_w dương: mô-men thanh xoắn lớn hơn mục tiêu theo chiều cua.
- epsilon_w âm: mô-men nhỏ hơn mục tiêu, biểu hiện trợ lực thừa trong đoạn xét.
- Không dùng trung bình có dấu làm chỉ tiêu chính ở đoạn đổi chiều nhiều lần; hai nửa chu kỳ có thể triệt tiêu nhau.
- Với các đoạn đó, ưu tiên E_RMS theo cửa sổ và đồ thị T_s so với T_ref.
- Ngưỡng 10% là ngưỡng kỹ thuật đã chọn, không phải kết luận chung về khả năng cảm nhận của người lái.
- TV, thời gian mô-men cao/thấp và chỉ tiêu hồi phục chỉ dùng bổ sung khi giúp giải thích một kết quả cụ thể.

Nếu cần phương trình mới, tiếp tục từ (54). Không chép lại các công thức đã có ở mục 4.

## 5.2. Steady Steering on a Dry Road

### Câu hỏi

MapPID có sửa được sai lệch giữ cua của Map trên đường khô, kể cả các mức vượt phạm vi kích thích CALIB, mà không đổi nhánh bản đồ không?

### Thiết lập cần nêu

- Hệ số bám giữ ở 0.8.
- Tốc độ 25 km/h: mức +0.15 và -0.25 g.
- Tốc độ 45 km/h: +0.15, -0.25, +0.35 g.
- Tốc độ 65 km/h: -0.15, +0.25, -0.35 g.
- Tốc độ 85 km/h: +0.15, -0.25, +0.38 g.
- Mỗi mức có dốc vào 1 s, giữ 4 s, trở về 0 trong 1 s và đi thẳng 1 s.
- Cửa sổ chấm là 1 s cuối của đoạn giữ. Không nói cửa sổ này chứng minh xác lập vô hạn.

### Kết quả làm trụ cột

Sai lệch có dấu, trung bình năm hạt giống, đơn vị %:

| Cửa sổ | Map | PID | MapPID |
|---|---:|---:|---:|
| `v45a0p35l` | 32.300 | -0.019 | -0.036 |
| `v65a0p35r` | 10.776 | -0.033 | -0.044 |
| `v85a0p38l` | 19.262 | -0.026 | -0.037 |

- Map có sai lệch dương lớn ở các mức 0.35–0.38 g; không quy mọi sai lệch trên đường khô cho thay đổi độ bám.
- Nêu cả các mức nhẹ nơi sai lệch của Map nhỏ, để không mô tả mọi điểm làm việc như đều gặp giới hạn.
- Liên hệ với giới hạn bản đồ đã phân tích ở mục 3, nhưng không dùng kết quả này để khẳng định riêng độ dốc là nguyên nhân duy nhất.
- PID và MapPID đưa mô-men trung bình về gần mục tiêu trong các đoạn giữ này.
- Trên 11 cửa sổ, trị tuyệt đối lớn nhất của bias trung bình qua năm hạt giống khoảng 0.422% với PID và 0.417% với MapPID.
- Hai số trên là cực đại của các trung bình, không phải cực đại trên mọi cửa sổ và mọi hạt giống như e_rel,max của mục 4.
- Không gọi các sai lệch tính trung bình nhỏ hơn một bước lượng tử là độ chính xác đã được đo trên xe thật.
- RMS toàn ca của PID và MapPID khoảng 0.25 N·m vẫn gồm sai lệch lúc vào/ra cua; không mâu thuẫn với bias nhỏ trong cửa sổ giữ.

### Hình dự kiến

Một hình STEADY có T_s và T_ref theo thời gian, kèm phóng to một đoạn giữ ở mức 0.35 hoặc 0.38 g.
Dùng cùng khoảng thời gian cho cả ba bộ; bảng bias đi kèm giúp tránh phải đọc số quá nhỏ từ hình.

## 5.3. Changes in Speed and Road Adhesion

### Câu hỏi

Với tham số cố định, các cấu trúc đáp ứng ra sao khi đang cua mà tốc độ, phản lực lốp và mô-men mục tiêu cùng biến đổi?

### Ba cảnh cần trình bày

1. Đổi tốc độ trên đường khô: góc tương ứng 0.20 g, tốc độ 90 → 45 → 90 km/h, 13 s mỗi chiều và giữ 3 s ở tốc độ thấp.
2. Giảm bám theo bậc: 60 km/h, góc tương ứng -0.30 g, mu = 0.8 → 0.5 → 0.33 → 0.24 → 0.8.
   Mỗi mức thấp kéo dài 5 s; cửa sổ chấm nằm ở 2 s cuối mỗi mức.
3. Vũng nước: 80 km/h, góc tương ứng 0.25 g, mu giảm 0.8 → 0.2 trong 2 s rồi trở về 0.8.

Gia tốc ngang danh định dùng để tạo góc lái; khi mu giảm, gia tốc thực có thể giảm và T_ref thay đổi theo nó.
Không mô tả bài toán như đang ép xe giữ 0.30 g hoặc ép bám một mô-men mục tiêu không đổi.

### Kết quả giữ cua và vũng nước

Sai lệch có dấu, trung bình năm hạt giống, đơn vị %:

| Cửa sổ | Map | PID | MapPID |
|---|---:|---:|---:|
| `stair_m0p24` | -13.940 | 0.125 | 0.123 |
| `pud_in` | -12.562 | -0.843 | -0.514 |

- Dùng stair_m0p24 để cho thấy sai lệch trợ lực thừa của Map ở mức bám thấp, trong khi PID và MapPID vẫn có bias nhỏ.
- Dùng pud_in để mô tả cả quá độ, không coi sai lệch trung bình 2 s là sai lệch xác lập.
- MapPID có RMS sai lệch trong pud_in khoảng 0.0462 N·m, PID khoảng 0.0875 N·m và Map khoảng 0.3836 N·m.
- Kiểm đồ thị trước khi gán khác biệt quá độ cho một cơ chế điều khiển cụ thể.
- Với cảnh đổi tốc độ, báo riêng cửa sổ giảm và tăng tốc; không lấy trung bình có dấu để chúng triệt tiêu nhau.
- Không suy từ việc bám mô-men tốt sang kết luận quỹ đạo xe hoặc an toàn người lái đã được cải thiện.

### Hình dự kiến

Một hình SLIP gồm lịch tốc độ/mu và các đường T_s, T_ref, e_T.
Phóng to một bước giảm bám sâu và một lần vào/ra vũng nước.
Mốc thời gian và cửa sổ lấy từ lịch ca SSW, không chọn lại riêng cho từng bộ.

## 5.4. Continuous Steering

### Câu hỏi

Nhánh thêm vào giữ được mức bám nào khi đảo chiều liên tục, và phần mô-men trợ lực nhanh thay đổi thế nào so với PID thay bản đồ?

### Các cảnh cần nêu bằng chu kỳ

| Cảnh | Điều kiện | Chu kỳ hoặc thời lượng |
|---|---|---|
| ctr | 95 km/h, 0.05 g, mu = 0.8 | Chu kỳ 5 s, bốn chu kỳ |
| lane | 80 km/h, hai lần đổi làn 0.20 g | Chu kỳ 2.5 s; lần sau gặp mu = 0.2 trong 0.4 s |
| sw | 70 km/h, 0.10 g, mu = 0.8 | Chu kỳ 3.3333 s, 1.2500 s, 0.6667 s |
| mu3 | 60 km/h, 0.15 g, mu = 0.3 | Chu kỳ 1.3333 s, tám chu kỳ |

### Kết quả theo các đoạn rút ngắn chu kỳ

E_RMS trong cửa sổ, trung bình năm hạt giống, đơn vị N·m:

| Mã cửa sổ trong CSV | Chu kỳ (s) | Map | PID | MapPID |
|---|---:|---:|---:|---:|
| `sw0p3` | 3.3333 | 1.7069 | 0.1690 | 0.1822 |
| `sw0p8` | 1.2500 | 2.3540 | 0.2761 | 0.3088 |
| `sw1p5` | 0.6667 | 2.6379 | 0.4622 | 0.5224 |

- MapPID bám kém hơn PID ở cả ba đoạn trên; khoảng chênh tăng từ gần 8% lên khoảng 13% khi chu kỳ ngắn hơn.
- RMS toàn ca WEAVE của MapPID cao hơn PID khoảng 10.9%, nhưng vẫn thấp hơn Map khoảng 6.5 lần.
- Không khái quát thành MapPID kém hơn PID trong mọi thao tác động: ở đoạn đổi làn qua nước, MapPID có RMS sai lệch thấp hơn PID.
- Ở lane_in, E_RMS lần lượt khoảng 2.2962 / 0.1060 / 0.0790 N·m cho Map / PID / MapPID.
- Nếu báo bias của lane_in, phải đặt cạnh lane_ref ở cùng vị trí tương đối của thao tác lái.
- Map có bias khoảng -76.59% ở lane_ref và -86.65% ở lane_in; phần chênh khoảng -10.06 điểm phần trăm.
- Không viết rằng toàn bộ -86.65% là hậu quả riêng của vũng nước.
- PID và MapPID có chênh bias giữa hai cửa sổ khoảng +0.201 và +0.109 điểm phần trăm.
- Các mã cửa sổ gốc được giữ để truy vết dữ liệu; tên và nhãn trong bài dùng chu kỳ tương ứng.
- Cảnh ctr không đồng nghĩa toàn bộ thời gian đều nằm trong vùng chết của bản đồ.

### Hình dự kiến

Một hình WEAVE cho T_s/T_ref và e_T theo thời gian, với phóng to đoạn chu kỳ 0.6667 s.
Một ô riêng cho hai lần đổi làn, đặt phần có và không có vũng nước cạnh nhau theo thời gian tương đối.

## 5.5. Overall Results and Limitations

### Bảng tổng hợp đã tính lại từ đúng dữ liệu

Trung bình và độ lệch chuẩn mẫu qua năm hạt giống. Các cột E và S đều có đơn vị N·m.

| Ca | Bộ | Trung bình E_RMS | Độ lệch chuẩn E_RMS | Trung bình S | Độ lệch chuẩn S |
|---|---|---:|---:|---:|---:|
| STEADY | Map | 1.0585 | 0.0007 | 0.1982 | 0.0009 |
| STEADY | PID | 0.2496 | 0.0039 | 0.5649 | 0.0044 |
| STEADY | MapPID | 0.2498 | 0.0049 | 0.5146 | 0.0065 |
| SLIP | Map | 0.6895 | 0.0001 | 0.2028 | 0.0009 |
| SLIP | PID | 0.2057 | 0.0013 | 0.4900 | 0.0057 |
| SLIP | MapPID | 0.1962 | 0.0019 | 0.4820 | 0.0069 |
| WEAVE | Map | 1.4510 | 0.0001 | 0.2896 | 0.0006 |
| WEAVE | PID | 0.1998 | 0.0044 | 0.8900 | 0.0036 |
| WEAVE | MapPID | 0.2217 | 0.0064 | 0.7557 | 0.0071 |

### Thứ tự diễn giải

1. So với Map, MapPID giảm RMS sai lệch khoảng 4.24 lần ở STEADY, 3.51 lần ở SLIP và 6.54 lần ở WEAVE.
   Đánh đổi là S lớn hơn Map. Không dùng S thấp của Map để kết luận bộ này đạt yêu cầu bám.
2. So với PID, RMS sai lệch của MapPID gần như bằng ở STEADY, thấp hơn khoảng 4.6% ở SLIP và cao hơn khoảng 10.9% ở WEAVE.
3. S của MapPID thấp hơn PID khoảng 8.9%, 1.6% và 15.1% tương ứng ba ca.
   Mức khác biệt nhỏ ở SLIP phải đi kèm độ phân tán giữa hạt giống, không phóng đại.
4. Trên CALIB, điểm MapPID đã chọn có S cao hơn PID 2.2%; ở ba ca SSW, S lại thấp hơn.
   Đây là kết quả trên các chuỗi kích thích khác nhau, không phải lỗi số liệu hoặc bằng chứng một thứ hạng đúng cho mọi trường hợp.
5. Kết luận là đánh đổi giữa bám và thành phần nhanh của mô-men trợ lực với các tham số đã chọn; không khẳng định một cấu trúc trội toàn diện.

Không bắt buộc dùng tích E_RMS*S làm kết quả chính.
Nếu báo tích này, phải đặt tên khác J của CALIB và nêu đơn vị (N·m)^2.
Không chuyển mức giảm J trên CALIB sang phần trăm cải thiện toàn bộ các ca SSW.

### Giới hạn cần giữ

- Một xe mô phỏng, chưa có số đo kiểm chứng thực nghiệm.
- Người lái là nguồn góc, chưa có phản ứng điều chỉnh góc khi nặng hoặc nhẹ tay.
- Năm hạt giống mô tả độ nhạy với nhiễu trong cấu hình này, không phải độ bất định của mọi thông số xe.
- S đo phần dư sau bộ làm trơn, gồm cả đáp ứng nhanh do thao tác lái; chưa phải đánh giá chủ quan về độ êm hoặc âm thanh.
- Kết quả là kiểm tra mô-men, không tự chứng minh xe bám quỹ đạo tốt hơn hoặc an toàn hơn.
- Không nói PID/MapPID loại bỏ sai lệch xác lập trong toàn ca WEAVE, vì đó chủ yếu là chuyển động liên tục.
- Không giải thích chênh lệch khi lái nhanh bằng một nguyên nhân duy nhất nếu chưa có phép tách ảnh hưởng các nhánh.

## Bảng và hình cần chuẩn bị

Các số dưới đây là dự kiến nếu mục 4 không bổ sung hình hoặc bảng khác.

- Bảng 8: kịch bản SSW và cửa sổ đánh giá.
- Bảng 9: E_RMS và S toàn ca, trung bình và độ lệch chuẩn năm hạt giống.
- Bảng 10: các cửa sổ giữ cua/đổi bám quan trọng và dấu của sai lệch.
- Hình 7: STEADY, toàn cảnh và một đoạn giữ cua gần mức giới hạn.
- Hình 8: SLIP, tốc độ/mu cùng mô-men và sai lệch khi điều kiện đổi.
- Hình 9: WEAVE, một đoạn chu kỳ ngắn và so sánh hai lần đổi làn.
- Hình 10 chỉ bổ sung khi có dữ liệu 1 ms mới: so sánh thành phần mô-men trợ lực nhanh ở cửa sổ chung.
- Hình sinh bằng MATLAB, trục thời gian bằng s, màu/nét/dấu thống nhất và đọc được khi in trắng đen.
- Lưu hình mới vào Figures/main, đặt số theo bài; không ghi đè Hình 1–6 người dùng đang sửa.
- Mỗi hình phải giải thích một quan hệ; tránh lặp toàn bộ bảng số bằng một hình cột khác.

## Dữ liệu dùng được ngay và việc còn thiếu

### Đã có đủ

- Tất cả 15 tệp metrics cho năm hạt giống chính thức, tổng 510 dòng.
- Đủ 45 tệp tín hiệu SSW, gồm các đại lượng thật của mô hình.
- Các số toàn ca và trong cửa sổ ở trên đã được đối chiếu trực tiếp từ metrics.
- Tham số thiết kế cuối được giữ theo trường design của map.json, pid.json, mappid.json.

### Cần làm trước khi viết hoặc chèn hình chính thức

1. Cập nhật cách tổng hợp sang đúng 99995–99999.
   tools/summarize_ssw.py hiện vẫn gán hạt giống cũ và các tệp Result/Compare/SSW_summary hiện có chứa kết quả cũ.
   Không chạy script đó rồi dùng kết quả như thống kê của thiết kế hiện tại.
2. Dùng lại tệp cửa sổ chỉ sau khi đối chiếu với các hàm buildSTEADY, buildSLIPS, buildWEAVES của make_cases.m.
   Không đọc nhầm các mô tả DREWS ở đầu tệp.
3. Các CSV tín hiệu hiện lưu mỗi 10 ms, trong khi metrics đã được tính trên lưới 1 ms.
   Chỉ tiêu S trong metrics dùng được; không tính lại S hoặc các đỉnh nhiễu từ CSV đã lấy thưa.
4. Xuất thêm tín hiệu 1 ms của thiết kế cuối với hạt giống 99999 nếu cần hình phóng to nhiễu.
   Dữ liệu fullrate hiện thấy chỉ thuộc hạt giống cũ, chưa dùng được cho hình mới.
5. Việc xuất 1 ms giữ nguyên tham số và ca thử, ghi ra tệp riêng; không xóa hoặc ghi đè các metrics hiện có.
   run_scoring_seeds bỏ qua hạt giống đã có metrics, nên không dùng lời gọi mặc định đó như thể đã xuất lại tín hiệu đầy đủ.
   Sau khi xuất, đối chiếu E_RMS và S với metrics cùng hạt giống; giữ cách lấy mẫu T_a như run_cases.
6. Trước khi phân tích nhiễu ở mô-men nhỏ, định nghĩa cửa sổ hoặc quy tắc phân nhóm chung cho cả ba bộ.
   Phân biệt mô-men mục tiêu gần 0 với điều kiện vùng chết dựa trên mô-men đo.
   Hiện chỉ chốt được kết quả S toàn ca; nhận định cơ chế nhiễu ở mô-men nhỏ còn cần kiểm bằng tín hiệu 1 ms mới.
   Nếu quy kết cho vùng chết hoặc nhánh Map, cần ghi thêm T_s,m hoặc u_map; các CSV hiện tại chỉ có tín hiệu thật.
7. Recovery_s chỉ dùng cho cửa sổ hồi phục và tiêu chí giữ sai lệch dưới 10% trong 1 s.
   NaN có thể là không đạt trong cửa sổ hoặc chỉ tiêu không thích hợp khi mục tiêu đi qua 0; không diễn giải thành mất ổn định.
8. Sat_pct hiện là tỉ lệ mẫu có |T_a| >= 0.98*T_a,max(v), không phải phép đếm trực tiếp lệnh bị chặn.
   Nếu phân tích bão hòa, cần phân biệt T_a,cmd, T_a,lim, T_a, tốc độ đo và tốc độ thật.
9. Khi viết md nội dung mục 5, giữ kết quả của cửa sổ động riêng với kết quả giữ cua; không suy thứ hạng của cả ca từ một đoạn phóng to.

## Nguồn truy vết

- Model/Sim/script/make_cases.m: các hàm SSW hiện hành và lịch cửa sổ.
- Model/Sim/script/run_cases.m: cách tính metrics, quy ước dấu, chỉ tiêu phụ và cách lưu tín hiệu mỗi 10 mẫu.
- Result/Controllers/Map/Cases_ssw/Map_metrics_s99995.csv đến Map_metrics_s99999.csv.
- Result/Controllers/PID/Cases_ssw/PID_metrics_s99995.csv đến PID_metrics_s99999.csv.
- Result/Controllers/MapPID/Cases_ssw/MapPID_metrics_s99995.csv đến MapPID_metrics_s99999.csv.
- Các tệp <Ctrl>_<CASE>_sig_s9999x.csv tương ứng: dùng cho tín hiệu và xu hướng theo thời gian.
- Model/data/map.json, pid.json, mappid.json: chỉ trường design, không lấy thiết kế cũ.
- tools/summarize_ssw.py, tools/make_fig_sec5_bw.py, Model/Sim/script/make_paper_figures.m hiện cần kiểm và cập nhật nguồn trước khi tái sử dụng.
