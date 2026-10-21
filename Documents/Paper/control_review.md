# Kiểm chứng mục Control Strategy and Assist-Map Limitation

## Phạm vi

File bài báo tương ứng là `Control Strategy and Assist-Map Limitation.txt`, gồm bốn tiểu mục:
- 3.1. Conventional Assist-Map Control with Lead-Lag Compensation
- 3.2. Steady-State Limitation of Assist-Map Control
- 3.3. PID Steering-Torque Feedback Control
- 3.4. Parallel Map-PID Control Structure

Mục này trình bày cấu trúc, nguyên lý điều khiển và phân tích độ nhạy xác lập của ba bộ điều khiển (Map, PID, MapPID) mà không phụ thuộc vào bộ tham số tối ưu cụ thể (vốn đang được quét lại trên ca CALIB v2).

## Mạch lập luận

| Tiểu mục | Vai trò và nội dung then chốt |
| --- | --- |
| 3.1 | Trình bày bộ điều khiển cơ sở theo chuẩn công nghiệp: bản đồ trợ lực tĩnh 2 chiều $M(v, T_s)$ được hiệu chỉnh trên đường khô ($\mu=0.8$) từ cân bằng tĩnh, có vùng chết $T_{s0}=0.3$ N·m và giới hạn độ dốc $K_{max}$; khâu bù lead–lag $C_{map}(s)$ bậc 2 giữ độ lợi DC bằng 1 để ổn định cộng hưởng cột lái (~6.2 Hz) và triệt tiêu khuếch đại nhiễu cao tần. |
| 3.2 | Phân tích giải tích độ nhạy xác lập: khi hệ số bám $\mu$ giảm làm phản lực lốp $\Delta T_r < 0$, sai số mô-men thanh xoắn chỉ được suy giảm theo tỉ lệ $\Delta T_s = \Delta T_r / (1 + s_m)$ với $s_m \le K_{max}$. Chứng minh bản đồ tĩnh không thể triệt tiêu trợ lực thừa nếu không có độ dốc vô cùng, đối lập với điều khiển có tích phân (enforces $\Delta e_T = 0$). |
| 3.3 | Trình bày bộ điều khiển phản hồi sai số mô-men PID: khâu vi phân đặt trên mô-men đo $T_{s,m}$ với bộ lọc bậc nhất $T_f$ (tránh derivative kick khi tín hiệu đặt đổi nhanh); quy ước dấu dương cho khâu vi phân phù hợp với phương trình gia tốc cột lái; khâu chống bão hòa tích phân (anti-windup back-calculation) với $K_{aw} = K_i / K_p$. |
| 3.4 | Trình bày cấu trúc lai song song MapPID: nhánh Map đóng vai trò đường dẫn trước (feedforward baseline) cung cấp phần lớn trợ lực trên đường khô, nhánh PID đóng vai trò phản hồi hiệu chỉnh sai lệch do mặt đường hoặc bão hòa lốp; cả hai dùng chung bộ giới hạn trợ lực $T_{a,max}(v_m)$ và quy tắc anti-windup được điều chỉnh $K_{aw} = K_i / (K_p + K_{max})$ để bảo đảm xả tích phân phù hợp khi motor bão hòa. |

## Đối chiếu nguồn và mô hình

| Nội dung | Bằng chứng | Cách dùng trong bản mới |
| --- | --- | --- |
| Bản đồ trợ lực và khâu bù lead-lag | Lee 2018 TCST [1], Sec. III-A, Eqs. (15)–(17): bản đồ phi tuyến $M(v, T_s)$ và khâu lọc lead-lag $C(s)$; Sec. III-D về dự trữ ổn định quanh cộng hưởng cột lái. | Giữ nguyên cấu trúc lead-lag chuẩn của Lee 2018 với độ lợi DC bằng 1; mô tả việc tạo bảng từ cân bằng tĩnh và ràng buộc độ dốc $K_{max}$. |
| Phân tích độ nhạy xác lập $\Delta T_s = \Delta T_r / (1 + s_m)$ | Suy dẫn trực tiếp từ phương trình cân bằng mô-men cột lái ở trạng thái xác lập $T_s + M(v, T_s) = T_r$. | Làm rõ đây là kết quả giải tích cục bộ tại điểm làm việc xác lập; chứng minh cơ chế gây trợ lực thừa khi $\Delta T_r < 0$ và giới hạn của bản đồ tĩnh. |
| Khâu vi phân trên tín hiệu đo và lọc $T_f$ | Seborg et al. (Process Dynamics and Control, Ch. 8); Slotine & Li (Applied Nonlinear Control). | Đặt khâu D trên $T_{s,m}$ thay vì $e_T$; giải thích rõ lý do tránh derivative kick và lọc nhiễu lượng tử hóa ở tần số cao. |
| Quy tắc anti-windup MapPID: $K_{aw} = K_i / (K_p + K_{max})$ | Phân tích độ lợi vòng hở tĩnh tổng cộng của MapPID là $K_p + s_m \approx K_p + K_{max}$; mã nguồn `mappid_variables.m` và `QuyChuan.txt` mục 2.4. | Trình bày quy tắc suy rộng nhất quán: khi $K_{max}=0$ quay về $K_i/K_p$, khi $K_p$ nhỏ vẫn xác định nhờ $K_{max}$. |

## Những điểm đã sửa và nâng cấp so với `paper_jstt.txt`

1. **Thay PI bằng MapPID trong thân bài chính:** Bản nháp cũ trong `paper_jstt.txt` trình bày Map, PI, PID. Bản mới thay thế PI bằng MapPID, phù hợp với quyết định của dự án (Lượt 94-98, Lượt 167-168) và Introduction đã cập nhật; PI được hiểu là trường hợp suy biến của PID khi $K_d = 0$.
2. **Tách biệt cấu trúc lý thuyết và bộ tham số thực nghiệm:** Không đưa Bảng tham số cụ thể (Table 2 cũ với $K_p=1.5, K_i=32,...$) vào Mục 3, vì các bộ điều khiển đang được quét lại tham số trên ca CALIB v2 bằng phương pháp quét lưới (grid search) với ngưỡng $e_{max}=10\,\%$. Bảng tham số cuối cùng sẽ được đưa vào Mục 4 (Simulation Setup and Calibration) sau khi có kết quả chính thức.
3. **Đánh số phương trình liên tục toàn bài:** Tiếp nối phương trình (1)–(19) từ Mục 2 (`System Modeling and Problem Formulation.txt`), các phương trình trong Mục 3 được đánh số liên tục từ (20) đến (38).
4. **Bổ sung sơ đồ khối trực quan:** Dẫn chiếu đầy đủ tới Fig. 4 (`Fig_Map_loop.png`), Fig. 5 (`Fig_PID_loop.png`), và Fig. 6 (`Fig_MapPID_preview.png`) phù hợp với các sơ đồ khối mới được chuẩn hóa.

## Giới hạn cần lưu ý

- Phân tích độ nhạy $\Delta T_s = \Delta T_r / (1 + s_m)$ là phân tích cục bộ tại trạng thái xác lập khi vận tốc và gia tốc ngang không đổi, chưa bao gồm động học chuyển tiếp hoặc ảnh hưởng của ma sát khô khi vô-lăng chuyển động.
- Khâu lead-lag $C_{map}(s)$ bảo đảm dự trữ biên/pha trên các mô hình tuyến tính hóa tại các điểm làm việc đại diện; không đại diện cho một chứng minh ổn định phi tuyến toàn cục kiểu Lyapunov.
- Cấu trúc MapPID kết hợp tuyến tính và phi tuyến; hành vi khi bão hòa motor phụ thuộc vào tính kịp thời của nhánh anti-windup.

