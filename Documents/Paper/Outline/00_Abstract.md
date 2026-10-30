# Abstract (bản đánh số câu)

Nội dung giữ nguyên bản trước, chỉ đánh số từng câu để bạn nói "sửa câu A3", "tách câu A4"... Nhãn nằm trong ngoặc vuông đậm ở đầu câu và KHÔNG thuộc bài; khi đưa vào bài tôi bỏ hết nhãn. Quy ước nhãn: **A1–A6** là câu của Abstract. Phần Introduction nằm ở [01_Introduction.md](01_Introduction.md).

---

## Abstract

**[A1]** In column-type electric power steering (C-EPS), a calibrated map converts the torsion-bar torque and the vehicle speed into the assist torque, and because the map has no target torque to follow, it compensates only part of the torque drop when tire–road adhesion falls. **[A2]** A stronger response of the map would restore more of that torque, but this makes the steering system less stable and amplifies sensor noise, so this study adds feedback on the error between the measured torque and a target torque derived from the speed and the lateral acceleration, which does not require an estimate of road friction. **[A3]** Two structures are examined, a PID controller that replaces the map and MapPID, in which a PID branch runs in parallel with the unchanged map. **[A4]** Each controller was tuned by selecting parameters on a Pareto front of tracking error and assist-torque noise under the same requirements, using a nonlinear model of the column, tires and vehicle body with noisy, quantized sensors, and then tested in steady cornering, a sudden friction change and continuous steering. **[A5]** In all three tests, MapPID removed the steady-state error left by the map and kept the tracking error several times below that of the map alone, and its tracking was close to that of the PID controller. **[A6]** Since MapPID keeps the existing map intact, it can be added to a calibrated system to correct the torque error that the map by itself cannot eliminate, provided the loop remains stable and the assist command stays within its limit.

**Keywords:** Electric power steering; Assist map; Torque feedback; PID control; Lateral acceleration; Road friction.

---

## Bảng A. Abstract: mỗi câu trả lời câu hỏi gì

| Câu | Câu hỏi | Trả lời gì |
|---|---|---|
| A1 | Bối cảnh và vấn đề: hệ hiện có làm thế nào, hỏng ở đâu? | C-EPS tính trợ lực bằng bản đồ theo mô-men thanh xoắn và tốc độ; không có mô-men mục tiêu nên khi mất bám chỉ sửa một phần |
| A2 | Vì sao không sửa dễ được, bài đề xuất gì? | Làm bản đồ phản ứng mạnh hơn thì hệ lái kém ổn định hơn, khuếch đại nhiễu; vì vậy thêm phản hồi theo sai lệch so với mô-men mục tiêu từ tốc độ và gia tốc ngang, không cần ước lượng ma sát |
| A3 | Cấu trúc cụ thể là gì? | PID thay bản đồ; MapPID = nhánh PID song song với bản đồ giữ nguyên (số tham số để dành cho phần dưới) |
| A4 | Đánh giá thế nào? | Chọn tham số trên mặt Pareto với cùng yêu cầu; mô hình phi tuyến, cảm biến có nhiễu và lượng tử; thử ba tình huống |
| A5 | Kết quả chính so với bản đồ thuần, và so với PID (phụ, vế cuối)? (không số) | MapPID hết sai số xác lập, sai lệch thấp hơn bản đồ nhiều lần trong cả ba ca; bám gần PID |
| A6 | Ý nghĩa và điều kiện? | Giữ bản đồ có sẵn nên gắn thêm được vào hệ đã hiệu chỉnh để sửa sai lệch mà bản đồ thuần không sửa được, khi vòng ổn định và động cơ không bão hòa |

## Ghi chú

- **Số câu:** Abstract 6 câu (A1–A6, không số, không trích dẫn; A5 và A6 đều nhấn so với bản đồ thuần, so với PID chỉ còn vế cuối A5, không nói nhiễu); Introduction 11 câu thân bài (1.1–4.3) cộng C0–C2.
- **Đã sửa Abstract theo góp ý:** A2 bỏ "slope", nói "làm bản đồ phản ứng mạnh hơn" và bỏ lặp "vehicle speed" (chỉ còn "the speed"); A3 bỏ "bốn tham số" (chỉ còn ở Introduction, C1); A4 đổi thành "Each controller was tuned … and then tested" (không còn "each controller was then tested"); A5–A7 gộp lại thành hai câu A5, A6. Đoạn Introduction 2.1 vẫn dùng "local slope", chưa sửa vì chưa được bảo.
- **Câu dài nhất cần cân nhắc cắt hoặc tách:** 3.4 (hạn chế của hướng 1) và 4.8 (MapPID cộng điều kiện). Đoạn 4 giờ 8 câu, khoảng 270 từ; nếu thấy dài, tách thành hai đoạn (gap: 4.1–4.3; hướng của bài: 4.4–4.8), nhưng khung của thầy là 4 đoạn.
- **Câu 4.6 (vì sao không phải bộ khác)** dựa vào [10,11] và lập luận chung (mờ và bộ dựa mô hình cần luật hoặc mô hình), không dựa vào kết quả chạy trước; nếu bạn có bộ cụ thể muốn nêu tên (ví dụ SMC, thích ứng), nói tên, tôi thêm kèm nguồn.
- **Đoạn 1 viết lại theo bản của bạn:** 1.1 giữ ý "động cơ điện do MCU điều khiển, cho khả năng ..." và hoàn thành vế sau (tiết kiệm năng lượng, chỉnh cảm giác lái bằng phần mềm); bỏ "hydraulic" và vế C-EPS; 1.2 ngắn, phản ứng theo ý người lái; 1.3 giữ bản đồ lập trình sẵn rồi khâu bù sớm–trễ, bỏ vế "giữ vòng ổn định, giới hạn khuếch đại nhiễu". Ý "đường trơn, trợ lực thừa" chuyển sang đoạn 2 thành câu mới **2.0** (đặt nhãn 2.0 để các nhãn 2.1, 2.2 không đổi). Hai chỗ tôi đổi chữ: "Engineers pre-programmed" thành "In the literature, the MCU is pre-programmed" (thầy chỉ cho nói "trong tài liệu", không nói "trong công nghiệp"); "torque map" thành "assist map" (thống nhất với Keywords). Bài không còn định nghĩa C-EPS trong Introduction (Abstract vẫn có).
- **C0:** nếu thầy coi câu dẫn là "nói sẽ làm gì", bỏ C0, giữ C1–C2.
- Chưa sửa `paper_ENG.txt`, chưa gen.
