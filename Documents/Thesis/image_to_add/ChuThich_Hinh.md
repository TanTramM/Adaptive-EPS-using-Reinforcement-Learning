# Hình đề xuất thêm vào luận văn (2026-11-13, Lượt 106)

Thư mục này chứa các hình **đề xuất**, CHƯA chèn vào `Documents/Thesis/luanvan.txt`. Mỗi hình có: file, vị trí đề xuất, chú thích viết sẵn (dán được thẳng vào luanvan.txt), phần chữ hay bảng mà hình thay hoặc giúp rút gọn, và số liệu chính đọc từ hình.

- Tất cả vẽ bằng MATLAB: `tools/make_fig_thesis_add.m`, nhãn tiếng Việt trong `tools/make_fig_thesis_add_labels.json`.
- Sinh lại tất cả: `matlab -softwareopengl -batch "run('<repo>\tools\make_fig_thesis_add.m')"`.
- Sinh lại một hình: thêm `sel='5A';` trước `run(...)`. Mã hình dùng được: 2A, 2B, 2C, 3A, 3B, 3C, 4A, 5A, 5B, 5D. Hai mã 2A và 3B vẽ cùng một khối.
- Dữ liệu: hàm tĩnh của Map (`map_params`, `calibrate_map`, `map_table`, `map_eval`, `map_steady_state`); `Model/shared/data/ref.json` và `map.json`; `Documents/Thesis/figures/ch3_map_slopes.csv` và `ch4_selected.csv`; kết quả chấm năm seed 99995-99999 ở `Result/Controllers/<bộ>/Cases_ssw/`. Không có số nào gõ tay.

**Nguyên tắc chọn hình:** luận văn đang thừa chữ (xem phần ghi chú sau `@@END` cuối luanvan.txt). Vì vậy ưu tiên hình **thay được** một bảng hoặc một đoạn chữ dài, không chỉ để trang trí. Cột "Thay gì" ghi rõ phần nên cắt khi chèn hình. Nếu chèn hình mà giữ nguyên chữ thì luận văn chỉ dài thêm.

**Cách chèn:** dòng chú thích theo dạng của txt2docx, ví dụ `[Hình 2.5: ... | Documents/Thesis/image_to_add/Add_2A_Ts_static.png@12.0]`. Sau khi chèn phải đánh số lại các hình phía sau trong cùng chương. Nên chuyển file sang `Documents/Thesis/figures/` và đổi tên theo số hình chính thức.

## Bảng tóm tắt

| Ưu tiên | File | Chương, vị trí | Thay gì |
|---|---|---|---|
| 1 | Add_5A_Bars.png | 5.5, đầu mục | Gộp ý của Bảng 5.2, 5.4, 5.6 và đoạn số lặp đầu 5.5 |
| 1 | Add_3B_Ts_static_Map.png | 3.2, sau (3.11) | Bảng 3.1 và đoạn đọc bảng; bổ sung cho Hình 3.3 |
| 1 | Add_5C_SlipStair.png | 5.3, đoạn thang hệ số bám | Đoạn tả độ lệch của Map ở ba mức mu |
| 1 | Add_4A_Flow.png | 4.4, đầu mục | Rút gọn mạnh các đoạn tả lưới và giai đoạn của 4.4 |
| 2 | Add_5B_EpsSteady.png | 5.2, sau Bảng 5.2 | Bảng 5.3 (có thể bỏ) và đoạn tả 11 cửa sổ |
| 2 | Add_2A_Ts_static.png | 2.5, sau (2.16) | Ví dụ 5.1 % (điểm D8 của ghi chú) |
| 2 | Add_5D_Reverse.png | 5.5, sau Bảng 5.8 | Bảng trợ lực ngược đã chốt ở D5 (dùng hình hoặc bảng, không cả hai) |
| 2 | Add_2B_Tamax.png | 2.7, chỗ Bảng 2.2 | Bảng 2.2 |
| 3 | Add_3A_Slopes.png | 3.1.2, cuối mục | Câu liệt kê độ dốc 7.87 đến 16.22 |
| 3 | Add_3C_LeadLag.png | 3.1.4, cuối mục | Đoạn giải thích vai trò lead, lag bằng lời và hàm truyền |
| 3 | Add_2C_Sensor.png | 2.8, sau (2.25) | Không thay gì; chỉ minh họa, cân nhắc bỏ nếu cần trang |

Nếu chèn hết ưu tiên 1 và 2 và cắt đúng phần ở cột "Thay gì", số trang gần như không đổi mà luận văn có thêm 8 hình.

## Chi tiết từng hình

### Add_2A_Ts_static.png (chương 2, mục 2.5)
- **Vị trí:** sau phương trình (2.16) và đoạn "Phương trình (2.16) cho thấy hệ số bám tới tay lái như thế nào".
- **Chú thích:** Mô-men thanh xoắn xác lập khi không có trợ lực, $T_s=T_r$, theo gia tốc ngang ở 60 km/h với ba hệ số bám, so với mô-men mục tiêu $T_{ref}$. Tính từ các phương trình (2.8) đến (2.12) ở trạng thái quay vòng xác lập; đường của $\mu=0.35$ dừng ở 0.32 g, gần giới hạn bám của lốp.
- **Thay gì:** ví dụ "giữ góc 0.3 rad, 20 m/s, giảm 5.1 %" ở 2.5 (D8). Viết lại thành một câu đọc hình: ở 0.3 g, $T_r$ giảm từ 7.64 N·m ($\mu=0.8$) xuống 7.26 N·m ($\mu=0.5$) và 6.59 N·m ($\mu=0.35$), tức 13.7 %, trong khi mục tiêu là 2.80 N·m.
- **Lưu ý:** hình so ở cùng gia tốc ngang, không phải cùng góc vô-lăng; phải ghi rõ điều kiện này trong câu.

### Add_2B_Tamax.png (chương 2, mục 2.7)
- **Vị trí:** chỗ Bảng 2.2, sau (2.23).
- **Chú thích:** Giới hạn trợ lực theo vận tốc trên đường khô: mô-men trợ lực cần thiết $T_{a,req}$ tại $a_{y,lim}$ (2.21), giới hạn $T_{a,max}=T_{a,req}+T_f$ (2.23) và gia tốc ngang dùng để tính $a_{y,lim}$ (2.22, trục phải). Lưới 17 vận tốc từ 20 đến 100 km/h.
- **Thay gì:** Bảng 2.2 (sáu hàng). Giữ một câu nêu hai số đầu mút (5.7 N·m ở 20 km/h, 9.8 N·m ở 30 km/h) và lý do $a_{y,lim}$ dưới 0.4 g ở 20-25 km/h.

### Add_2C_Sensor.png (chương 2, mục 2.8)
- **Vị trí:** sau phương trình (2.25) hoặc sau Bảng 2.3.
- **Chú thích:** Minh họa mô hình cảm biến (2.25) trên một tín hiệu dựng sẵn dài 0.1 s: giá trị thật và giá trị đo của (a) mô-men thanh xoắn, bước lượng tử 0.01 N·m, chu kỳ cập nhật 1 ms, và (b) gia tốc ngang, bước 0.01 g, chu kỳ 10 ms. Độ lệch chuẩn nhiễu bằng một bước lượng tử như Bảng 2.3.
- **Thay gì:** không thay; chỉ giúp người đọc thấy vì sao $a_{y,m}$ thô hơn $T_{s,m}$, tức lý do khâu vi phân không lấy đạo hàm của $T_{ref}$ (3.3.3). Có thể dùng để rút đoạn lý do $c=0$ còn 2-3 câu.
- **Lưu ý:** tín hiệu là minh họa (hình sin dựng tay, seed 99999), không phải bản ghi mô phỏng; chú thích phải nói rõ điều này.

### Add_3A_Slopes.png (chương 3, mục 3.1.2 hoặc 3.1.3)
- **Vị trí:** cuối 3.1.2 (sau câu "độ dốc tự nhiên lớn nhất ... từ 7.87 đến 16.22"), hoặc đầu quy tắc thứ hai ở 3.1.3.
- **Chú thích:** Độ dốc tự nhiên lớn nhất của các điểm hiệu chỉnh trong dải 0.1 đến 0.3 g ở 17 vận tốc, so với giới hạn độ dốc $K_{max}=6.77$ của Map. Ở mọi vận tốc độ dốc tự nhiên vượt $K_{max}$, nên bản đồ nằm thấp hơn các điểm hiệu chỉnh ở gia tốc ngang lớn.
- **Thay gì:** câu liệt kê số và một phần đoạn giải thích quy tắc giới hạn độ dốc.

### Add_3B_Ts_static_Map.png (chương 3, mục 3.2)
- **Vị trí:** sau (3.11), thay chỗ Bảng 3.1 (Hình 3.3 lời giải đồ thị giữ nguyên hoặc bỏ, xem dưới).
- **Chú thích:** Mô-men thanh xoắn xác lập của Map theo gia tốc ngang ở 60 km/h với ba hệ số bám, là nghiệm của (3.7) với bản đồ của Bảng 4.4, so với mô-men mục tiêu $T_{ref}$. Bỏ qua ma sát khô và động học. PID và MapPID theo (3.21) cho $T_s=T_{ref}$ ở mọi điểm nếu vòng ổn định và motor không bão hòa.
- **Đọc từ hình:** (1) trên đường khô Map bám mục tiêu tới khoảng 0.33 g, rồi vượt lên rất nhanh (tay lái nặng) vì giới hạn độ dốc, giải thích luôn +32.3 % của STEADY ở 0.35 g; (2) khi $\mu$ giảm, đường của Map nằm dưới mục tiêu (trợ lực thừa) nhưng chỉ lệch 0.05-0.16 N·m ở 0.2-0.3 g; (3) dưới 0.1 g Map nằm dưới mục tiêu vì đoạn thoải nối vùng chết với điểm hiệu chỉnh đầu (đoạn mục tiêu dưới 0.1 g là phần nội suy luận văn thêm, mục 2.6).
- **Thay gì:** Bảng 3.1 và đoạn đọc bảng; một phần đoạn "chi phí thứ hai" ở 3.2. Hình 3.3 (lời giải đồ thị một điểm) có thể bỏ nếu cần trang, vì hình này cho đủ cả dải.

### Add_3C_LeadLag.png (chương 3, mục 3.1.4)
- **Vị trí:** cuối 3.1.4.
- **Chú thích:** Đáp ứng của khâu bù lead-lag đã chọn (Bảng 4.4): (a) với bước 1 N·m của đầu ra bản đồ $M$, khâu sớm pha cho xung ban đầu gấp khoảng 20 lần ($\tau_{1,in}/\tau_{1,out}$), khâu trễ pha hạ đỉnh của $u_{map}$ còn 7.6 N·m rồi đầu ra về 1 N·m (độ lợi một chiều bằng 1); (b) với hình sin chu kỳ 0.5 s, biên độ đầu ra bằng 0.76 biên độ đầu vào, trên mức $1/\sqrt{2}$ của ràng buộc ở mục 4.3.
- **Thay gì:** đoạn giải thích hàm truyền $(s/z+1)/(s/p+1)$ và dự trữ pha bằng lời ở 3.1.4; cũng là minh họa cho ràng buộc $g_{min}$ ở 4.3 và cho câu "bước nhảy ban đầu bằng $K_{max}\tau_{1,in}\tau_{2,in}/(\tau_{1,out}\tau_{2,out})$" ở 4.4.
- **Lưu ý:** hình tính khâu bù liên tục (rời rạc hóa Tustin với bước 0.01 ms), không phải bản 1 ms trong mô phỏng; khác biệt chỉ thấy ở xung ban đầu.

### Add_4A_Flow.png (chương 4, mục 4.4)
- **Vị trí:** đầu 4.4 (hoặc cuối đoạn mở đầu chương 4).
- **Chú thích:** Quy trình chọn tham số chung cho ba bộ điều khiển, từ ca CALIB tới bộ tham số cố định dùng ở Chương 5.
- **Thay gì:** đoạn liệt kê mục ở đầu Chương 4 và phần lớn chữ tả trình tự ở 4.4 (lưới thô, lưới mịn, giai đoạn 1 và 2, mặt safe và full). Chi tiết số (bước lưới, quy tắc ba sigma (4.9)) chuyển sang Phụ lục C theo mục C4 của ghi chú.

### Add_5A_Bars.png (chương 5, mục 5.5)
- **Vị trí:** đầu 5.5, trước Hình 5.5 hiện có.
- **Chú thích:** Sai số bám toàn chuỗi $E_{RMS}$ và độ ồn $S$ của Map, PID và MapPID trên ba chuỗi chấm; cột là trung bình năm seed 99995-99999, vạch là độ lệch chuẩn mẫu.
- **Thay gì:** đoạn số lặp đầu 5.5 (B6 của ghi chú). Có hai cách: (a) giữ Bảng 5.2, 5.4, 5.6 ở 5.2-5.4 và dùng hình để tổng hợp; (b) bỏ ba bảng nhỏ, gộp số vào một bảng duy nhất ở Phụ lục B hoặc ngay dưới hình. Đề xuất (b) để bớt chữ.

### Add_5B_EpsSteady.png (chương 5, mục 5.2)
- **Vị trí:** sau Bảng 5.2, trước đoạn "Map chỉ đạt mức mục tiêu một cách gần đúng".
- **Chú thích:** Độ lệch tương đối có dấu $\epsilon_w$ (5.2) trong 11 cửa sổ chấm của STEADY, trung bình năm seed, vạch là độ lệch chuẩn mẫu. Map lệch lớn ở ba mức mạnh nhất (0.35 và 0.38 g, ngoài dải 0.1-0.3 g của CALIB) và ở 25 km/h, 0.25 g; PID và MapPID nằm trong 0.43 % ở mọi cửa sổ.
- **Thay gì:** đoạn tả từng cửa sổ và đoạn "năm mức nhẹ hơn"; Bảng 5.3 rút còn cột phân tích tĩnh (hoặc gộp vào chữ), vì cột mô phỏng đã có trong hình.

### Add_5C_SlipStair.png (chương 5, mục 5.3)
- **Vị trí:** sau đoạn "Khi hệ số bám giảm theo bậc, độ lệch của Map tăng dần" (hoặc thay ô (b) của Hình 5.3 nếu muốn gộp).
- **Chú thích:** Thang hệ số bám của SLIP (60 km/h, góc vô-lăng ứng với −0.30 g), seed 99999: (a) mô-men thanh xoắn của ba bộ và mô-men mục tiêu, (b) mô-men trợ lực, (c) hệ số bám. Khi $\mu$ giảm theo bậc 0.8, 0.5, 0.33, 0.24, mô-men của Map nhẹ dần so với mục tiêu (trợ lực thừa), còn PID và MapPID về mục tiêu sau mỗi bậc; khi $\mu$ trở về 0.8 ở 66.5 s cả ba bộ lệch lớn, Map lệch nhiều nhất. $T_{ref}$ vẽ theo lần chạy của MapPID.
- **Thay gì:** phần chữ tả hiện tượng ở đoạn thang hệ số bám; đây là hình trực tiếp nhất của hiện tượng trợ lực thừa mà đề tài nhắm tới (Hình 5.3 hiện chỉ phóng vũng nước).
- **Lưu ý:** ở ô (b), mô-men trợ lực của PID và MapPID ít âm hơn Map ở mức $\mu$ thấp, tức rút bớt trợ lực, đúng với (3.21). Đọc hình bằng câu này, không cần thêm số.

### Add_5D_Reverse.png (chương 5, mục 5.5; điểm D5 đã chốt)
- **Vị trí:** sau Bảng 5.8 hoặc sau Add_5A_Bars.png.
- **Chú thích:** Tỉ lệ thời gian có trợ lực ngược (các mẫu có $|T_s|\ge0.5$ N·m và $T_aT_s<0$) của ba bộ trên ba chuỗi chấm, trung bình năm seed 99995-99999, vạch là độ lệch chuẩn mẫu.
- **Số:** STEADY: Map 0.05 %, PID 7.28 %, MapPID 7.44 %. SLIP: Map 0.001 %, PID 4.19 %, MapPID 4.64 %. WEAVE: Map 2.22 %, PID 23.79 %, MapPID 23.35 %.
- **Thay gì:** chọn MỘT trong hai: hình này hoặc bảng 3 x 3 đã chốt ở D5 (ghi chú cuối luanvan.txt). Kèm đúng một câu ở 5.5 và một câu ở 6.2 như D5, không viết cơ chế.

## Gợi ý khác, CHƯA vẽ (cần người dùng quyết)

1. **Chương 1: sơ đồ các kiểu EPS (cột lái, trục bánh răng, thanh răng, bánh răng kép).** Giúp rút đoạn 1.1.2. MATLAB vẽ sơ đồ cơ khí sẽ thô; nên dùng một ảnh có giấy phép mở (Wikimedia) như Hình 1.1, ghi nguồn và giấy phép. Cần tìm ảnh và kiểm giấy phép trước.
2. **Chương 1: sơ đồ vị trí của luận văn so với ba hướng nghiên cứu** (chỉnh bản đồ theo mặt đường, điều khiển mờ, phản hồi mô-men; MapPID ở giao của "giữ bản đồ" và "phản hồi mô-men mục tiêu"). Giúp rút 1.3.4 và 1.4. Rủi ro: dễ thành hình trang trí; chỉ làm nếu thật sự cắt được chữ.
3. **Chương 5, mục 5.8: sơ đồ khối Plant có đánh dấu khối thay bằng VDB** (dựa trên Hình 2.1, tô màu khối lốp và khối thân). Giúp rút 5.8.1. Cách làm như các sơ đồ chương 3 (sửa nhãn trên ảnh sơ đồ có sẵn bằng script Python, xem `tools/make_fig_thesis_ch3_diagrams.py`); cần người dùng đồng ý vì đó không phải hình MATLAB.
4. **Chương 5, mục 5.7: độ lệch tĩnh lớn nhất của Map, PID, MapPID qua 17 biến thể** (cột theo nhóm tham số, thang log). Giúp rút đoạn "sai lệch tĩnh cho thấy rõ nhất lợi ích của phản hồi". Số có trong `Result/Compare/Robust/`.
