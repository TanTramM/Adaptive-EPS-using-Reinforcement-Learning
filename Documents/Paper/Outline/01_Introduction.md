# Introduction (bản đánh số câu)

Nội dung giữ nguyên bản trước, chỉ đánh số từng câu để bạn nói "sửa câu 2.3", "bỏ câu 3.3", "tách câu 4.1"... Nhãn nằm trong ngoặc vuông đậm ở đầu câu và KHÔNG thuộc bài; khi đưa vào bài tôi bỏ hết nhãn. Quy ước nhãn: **1.x, 2.x, 3.x, 4.x** là câu x của đoạn 1–4 của Introduction; **C0–C2** là câu dẫn và hai đóng góp. Bảng B cuối file trả lời câu hỏi của thầy cho từng đoạn.

---

## 1. Introduction

**Đoạn 1: motivation và khảo sát**

**[1.1]** Electric power steering (EPS) assists the driver with a motor governed by a microcontroller unit (MCU), which makes it possible to tune the steering feel in software [1]. **[1.2]** The MCU can therefore respond to the driver's intention and deliver the assist that each driving situation requires. **[1.3]** In the literature, the MCU stores an assist map that converts the sensed torsion-bar torque and the vehicle speed into an assist torque, followed by a lead–lag compensator that copes with rapid torque changes and reduces noise [1,2]. **[1.4]** The map is calibrated on a dry road over a wide range of maneuvers, which gives the driver comfortable handling and sufficient torque to turn the wheel in each case.

**Đoạn 2: đầu bài**

**[2.0]** However, when the vehicle runs in the rain or on a slippery road, the map is inappropriate because its fixed data correspond to dry-road conditions, so it supplies more assist than the road can support and may compromise safety [3,4]. **[2.1]** The reason is that the map depends only on the measured torque and has no target torque to compare it with. **[2.2]** In situations where tire–road adhesion falls and the road reaction drops [3,5,12], or friction inside the steering system shifts the torque balance [2], the map corrects only the part of the change that the slope of its curve allows. **[2.3]** A steeper slope would leave a smaller error, but the higher loop gain amplifies sensor noise and shrinks the stability margin, that is, the room left before the loop becomes unstable [1,9], so the slope cannot be raised freely. **[2.4]** In short, the problem is one of reducing the torque error under varying road conditions without disturbing the dry-road calibration that the map already carries.

**Đoạn 3: việc làm của người khác**

**[3.1]** Earlier studies tried to overcome this issue with three main approaches. **[3.2]** The first adjusts the assist map or the motor current to the road. **[3.3]** Some of these works select among several maps or assist characteristics according to the friction coefficient, the axle load or the road type [3,5], and others add a correction to the motor command based on estimated friction [4,6]. **[3.4]** All of them rely on road information that must be identified beforehand and leave the slope limit of the map in place, and the compensation of [4] was capped by its authors and was not tied to a target torque, while that of [6] degraded the transient response. **[3.5]** The second applies fuzzy control to deal with nonlinearity and noise [10,11]. **[3.6]** However, Nguyen et al. [11] note that a change in adhesion may affect the robustness of the controller. **[3.7]** The third adds or replaces a torque feedback loop. **[3.8]** The proportional–integral–derivative (PID) loop of Zhao et al. [7] follows the torque requested by the map and not a target torque for the driver, and it does not consider variations in friction. **[3.9]** Lee et al. [8,9] track a target torque, but with a linear tire model on a dry road [8] or mainly with the vehicle parked [9].

**Đoạn 4: gap và hướng MapPID**

**[4.1]** These studies leave a gap, since the methods that adjust the map need road information and keep its slope limit. **[4.2]** The torque trackers in [8,9] drop the map and were restricted to simplified tires, a dry road, or a stationary vehicle. **[4.3]** A design that preserves the existing map and compensator, includes target-torque feedback, and is tested with nonlinear tires under changing adhesion was therefore not found. **[4.4]** To close this gap, the error between the measured torque and a target torque derived from the vehicle speed and the lateral acceleration is fed back [5,13], which makes a road estimate unnecessary, while the map and its compensator stay in place. **[4.5]** The PID controller is a natural choice for this feedback, because its integral action removes the steady torque error without needing to know the road surface and it is the form adopted in torque-feedback studies [7–9]. **[4.6]** Fuzzy [10,11] and model-based controllers were not chosen, since they require rules or a model of the road and the steering system, which the target-torque feedback is meant to avoid. **[4.7]** On its own, however, the PID controller replaces the map and gives up the assist that the map already provides for dry roads. **[4.8]** MapPID therefore adds a PID branch in parallel with the map and its compensator, so the map continues to supply that assist and the branch only has to correct what the map leaves, chiefly the steady error when adhesion varies, as long as the loop is stable and the motor does not saturate.

**Đóng góp**

**[C0]** The contributions of this paper are as follows.

- **[C1]** MapPID, a plug-in structure that extends the assist map with a PID branch without modifying it, so the dry-road calibration stays valid, no friction estimate is needed, and only four PID parameters need tuning for each vehicle.
- **[C2]** A comparison of the map, the PID controller and MapPID on a coupled nonlinear model, with the parameters of each controller selected on a Pareto front of tracking error and assist-torque noise under the same requirements, which shows that MapPID keeps the tracking error several times below that of the map alone, while its difference from the PID controller is small and depends on the test.

---

## Bảng B. Introduction: mỗi câu trả lời câu hỏi nào theo khung của thầy

| Câu hỏi của thầy | Câu | Trả lời gì |
|---|---|---|
| Motivation: vì sao vấn đề đáng quan tâm? | 1.1, 1.2 (và 2.0) | EPS dùng động cơ điện do MCU điều khiển, chỉnh cảm giác lái bằng phần mềm [1], MCU phản ứng theo ý người lái; (2.0) vô-lăng phải báo mặt đường, trợ lực thừa trên đường trơn giảm an toàn [3,4] |
| Khảo sát: hiện nay người ta làm thế nào? | 1.3, 1.4 | MCU lưu bản đồ trợ lực theo mô-men thanh xoắn và tốc độ [1,2], sau đó là khâu bù sớm–trễ đáp ứng thay đổi nhanh và giảm nhiễu [1]; bản đồ hiệu chỉnh trên đường khô, nhiều hoàn cảnh lái, để cảm giác lái tốt và luôn đủ mô-men cho người lái bẻ lái (không trích dẫn) |
| Đầu bài: bài toán cụ thể là gì? | 2.0–2.4 | Bản đồ không có mục tiêu nên chỉ sửa phần độ dốc cho phép [2,3,5,12]; độ dốc lớn thì mất ổn định, nhiễu [1,9]; bài toán = giảm sai lệch khi mặt đường đổi mà không phá hiệu chỉnh đường khô |
| Người khác đã làm gì, kết quả của họ (chỉ phần bài này làm tốt hơn)? | 3.1–3.9 | Ba hướng, mỗi hướng một câu nêu hướng chính rồi câu hạn chế: 3.2–3.4 chỉnh bản đồ hoặc lệnh động cơ theo mặt đường [3–6] (3.2 hướng chính, 3.3 cách làm, 3.4 hạn chế: cần biết mặt đường, giữ giới hạn độ dốc; [4] bị đặt trần, [6] quá độ xấu); 3.5–3.6 điều khiển mờ [10,11] (3.5 hướng chính, 3.6 [11] tự nêu lo ngại độ bền vững); 3.7–3.9 phản hồi mô-men (3.7 hướng chính, 3.8 [7] bám mô-men do bản đồ yêu cầu, 3.9 [8,9] lốp tuyến tính, đường khô, xe đỗ) |
| Gap: còn thiếu gì? | 4.1–4.3 | 4.1 hạn chế của các bài chỉnh bản đồ (cần thông tin mặt đường, giữ giới hạn độ dốc); 4.2 hạn chế của [8,9] (bỏ bản đồ, lốp đơn giản, đường khô, xe đứng yên); 4.3 kết luận gap: chưa thấy thiết kế giữ bản đồ và khâu bù, thêm phản hồi theo mục tiêu, thử với lốp phi tuyến khi độ bám đổi |
| Định hướng: bài vượt gap thế nào, vì sao PID, vì sao MapPID, vì sao không bộ khác? | 4.4–4.8 | 4.4 vượt gap: phản hồi sai lệch so với mô-men mục tiêu từ tốc độ và gia tốc ngang [5,13] (không cần ước lượng mặt đường), giữ nguyên bản đồ và khâu bù; 4.5 vì sao PID: tích phân khử sai số xác lập không cần biết mặt đường, là dạng đã dùng trong [7–9]; 4.6 vì sao không phải bộ khác: mờ [10,11] và bộ dựa mô hình cần luật hoặc mô hình mặt đường và hệ lái; 4.7 PID đứng một mình thay bản đồ nên bỏ trợ lực bản đồ đã có cho đường khô; 4.8 vì sao MapPID: nhánh PID song song, bản đồ vẫn cấp trợ lực đó, nhánh chỉ sửa phần bản đồ để lại (số tham số, Pareto, so sánh để dành cho đóng góp) |
| Đóng góp: bài đóng góp gì? | C0–C2 | (1) MapPID, cấu trúc cắm thêm giữ nguyên bản đồ, chỉ bốn tham số; (2) so sánh ba bộ trên mô hình phi tuyến với cùng cách chọn tham số: MapPID hơn bản đồ nhiều lần, khác PID nhỏ |
