# Lập luận cho Introduction Map, PID, MapPID

Cập nhật 2026-10-18 sau khi đọc toàn văn Lee 2018 Mechatronics và Lee 2021 Control Engineering Practice. Bản Introduction ở `Introduction.txt`; số tài liệu trong bản đó là số riêng, chưa ghép vào bài chính.

## Mạch viết

| Đoạn | Câu hỏi cần trả lời | Nội dung |
| --- | --- | --- |
| 1 | Hệ thống này là gì? | Trợ lực giảm công sức đánh lái; EPS dùng động cơ điện; C-EPS đặt động cơ trên cột lái và vẫn nối cơ khí tới bánh xe. Thủy lực chỉ một vế trong câu so sánh. |
| 2 | Cách thiết kế thông thường là gì? | Bản đồ từ mô-men cảm biến và tốc độ xe, khâu bù ổn định; có thể thiết kế bản đồ từ quan hệ lực lái mong muốn và mô hình ngược xác lập. Đây là kiến trúc được mô tả trong tài liệu, không khẳng định mọi hãng xe hiện nay dùng cùng một thuật toán. |
| 3 | Vì sao cần nghiên cứu? | Phản lực thay đổi khi điều kiện bám thay đổi; Map phản ứng với mô-men đo nhưng không trực tiếp điều chỉnh sai số so với mô-men đích. Cần cân nhắc độ bám và dao động mô-men do nhiễu cùng nhau. |
| 4 | Người khác đã xử lý ảnh hưởng mặt đường thế nào? | Nhận dạng mặt đường, bù dòng theo hệ số bám, chọn nhiều bản đồ theo bám và tải cầu trước. |
| 5 | Đã có điều khiển phản hồi hoặc bám mô-men chưa? | Đã có. Lee 2021 còn tách sinh cảm giác lái khỏi bộ bám, xét bám–nhiễu–ổn định, so trực tiếp với Map và thử xe thật. Đây là mốc gần nhất phải dùng để xác định khoảng trống. |
| 6 | Câu hỏi cụ thể của bài mình là gì? | Trong mô hình lốp–xe phi tuyến khi hệ số bám thay đổi, dùng tham chiếu theo tốc độ và gia tốc ngang để so Map, PID và MapPID; nhánh Map còn giúp gì khi đã có phản hồi sai số? |
| 7 và đóng góp | Mình thực hiện những gì? | Phân tích độ nhạy xác lập; đặt ba cấu trúc vào cùng bài toán bám; đánh giá đánh đổi sai số/dao động và trợ lực ngược bằng cùng môi trường. |

## Nguồn đã đối chiếu trong PDF gốc ở References/

Số trang dưới đây là trang PDF, không nhất thiết là số trang in trên tạp chí. Đã đọc Introduction và phần liên quan đến từng nhận định; không tuyên bố đã đọc toàn văn mọi bài trong lượt này.

| Số trong bản nháp | Nguồn | Bằng chứng dùng trong Introduction |
| --- | --- | --- |
| [1] | Lee, Kim, Kim 2018, Controller Design | Trang 1-2: định nghĩa EPS, ưu điểm so với thủy lực, bản đồ mô-men, khâu bù, vị trí motor của C-EPS. Abstract nêu mô phỏng và thử xe với lead-lag. |
| [2] | Guan et al. 2021 | Trang 1-2: phân rã đặc tính trợ lực thành phong cách lái, mô hình ngược xác lập thân xe và hệ thống lái; giảm khó khăn hiệu chỉnh. |
| [3] | Li et al. 2023 Multi-Map | Trang 1-3: ảnh hưởng tải cầu trước và bám, mạng nơ-ron và nhiều bản đồ, xác nhận bằng đồng mô phỏng. |
| [4] | Fan, Zhou, Zheng 2014, SAE 2014-01-0083 | Trang 1 và 4: bù dòng fuzzy theo hệ số bám ước lượng và tốc độ. Có thử vật lý kiểm chứng mô hình, hiệu quả bộ điều khiển trình bày qua mô phỏng; không gọi toàn bộ nghiên cứu là chỉ mô phỏng. |
| [5] | Li, Xia 2012 | Trang 1, 3-4: chọn đường đặc tính theo nhận dạng đường bằng mạng nơ-ron; Bảng 4 chứa mô-men mong muốn theo tốc độ và gia tốc ngang. Bản thân bảng này là kiến thức đã có. |
| [6] | Li et al. 2020 | Trang 1-2: hai hướng theo hệ số bám, hệ số trợ lực và bù dòng; nghiên cứu xe thương mại. |
| [7] | Zhao et al. 2011 | Trang 1-2: sửa động đường đặc tính; PID trong vòng bám mô-men trợ lực motor. Không đồng nhất với PID bám sai số mô-men thanh xoắn của bài mình. |
| [8] | Lee et al. 2018 Mechatronics | Trang 1-2: mục tiêu mô-men theo góc, tốc độ góc, tốc độ xe. Trang 5-7: đường khô mu 0.85 và biến thiên lực thanh răng danh định 50-150%; có mô phỏng và HILS. Điều khiển bám mô-men, tích phân và bền với sai lệch phản lực đều đã có. |
| [9] | Lee et al. 2021, Control Engineering Practice | Đọc toàn bộ 10 trang. Trang 1-3: kiến trúc hai mô-đun, Map thông thường và hạn chế cấu trúc. Trang 3-5: bộ bám tuyến tính với tiêu chí bám, giảm nhiễu, dự trữ ổn định và DOB. Trang 5-6: tham chiếu từ lực thanh răng ước lượng. Trang 7-9: mô phỏng, so trực tiếp với Map dưới cùng suy giảm cao tần, rồi thử xe ở trạng thái đỗ. |
| [10] | Saifia et al. 2015 | Abstract ở trang 2: ổn định mô hình phi tuyến fuzzy với dòng motor bị ràng buộc/bão hòa. |
| [11] | Nguyen, Vu, Sename 2025 | Abstract ở trang 1: kiến trúc đầy đủ, suy luận nơ-ron mờ thích nghi kết hợp điều khiển định hướng từ thông, xét nhiễu mô-men. |

## Cách diễn đạt đóng góp

- Lee 2021 đã làm phần khung chung mạnh hơn dự đoán: tách sinh cảm giác lái và bám mô-men, thiết kế bám–nhiễu–ổn định, thêm bộ quan sát nhiễu, so với Map và thử xe. Vì vậy không được nhận bất kỳ ý nào trong nhóm này là đóng góp mới của bài mình.
- Đóng góp có thể bảo vệ ở phạm vi bài hiện tại là phân tích và đánh giá ba cấu trúc trong bài toán biến thiên hệ số bám cụ thể, với mô hình lốp–xe phi tuyến và cùng giới hạn cảm biến/motor. Phép kết hợp MapPID chỉ nên gọi là cấu trúc được khảo sát cho tới khi tổng quan rộng hơn xác nhận mức độ mới.
- Không coi PID, tích phân khử sai số hoặc khái niệm bám mô-men đích là phát minh của bài mình.
- Không gọi Map là điều khiển không có hồi tiếp: nó dùng mô-men đo và tạo thành vòng tương tác với cơ cấu. Điểm khác nằm ở việc không trực tiếp khép kín sai số với mô-men đích.
- Không nói Map giữ nguyên trợ lực khi mu đổi: mô-men đo đổi thì đầu ra Map cũng đổi. Vấn đề là quan hệ Map cố định không bảo đảm mô-men bằng mục tiêu trong điều kiện mới.
- Quan hệ mô-men đích theo tốc độ và gia tốc ngang đã có trong [5]. Phần bài mình là dùng quan hệ đó làm tham chiếu trực tiếp cho các cấu trúc và kiểm tra hiệu quả, không nhận bảng dữ liệu là đóng góp mới.
- Không có ước lượng mu không đồng nghĩa mục tiêu độc lập với điều kiện đường: gia tốc ngang đo được vẫn thay đổi theo đáp ứng xe và mặt đường. Không bảo đảm giữ nguyên lực lái hoặc phản ánh đầy đủ cảm giác mặt đường.
- Lee 2021 chủ ý bỏ Map ra khỏi vòng bám để tách cảm giác lái khỏi ổn định. MapPID của bài mình đi theo câu hỏi kỹ thuật khác: nếu muốn giữ Map đã hiệu chỉnh và thêm nhánh sửa sai thì lợi ích còn lại là gì. Cần giải thích động cơ này; nếu MapPID không hơn PID thì kết quả âm chính là câu trả lời.
- Không khẳng định MapPID tốt hơn trước khi có phép so sánh tương ứng. Introduction không chốt số tham số hoặc thuật toán tìm khi các khung vẫn đang bàn cấu trúc và cách chỉnh.
- Không suy từ mô phỏng bám mô-men sang bằng chứng cải thiện an toàn hoặc cảm nhận của tài xế. Bài hiện tại chưa có thử người lái.
- Bỏ ngưỡng cảm nhận 10-18% khỏi lập luận chính: phép thử phân biệt mô-men tĩnh không đủ để làm ngưỡng phổ quát cho tác động an toàn trong khi lái.

## Phân tích toàn văn Lee 2021

Lee, D., Jang, B., Han, M., Kim, K.-S. (2021). A new controller design method for an electric power steering system based on a target steering torque feedback controller. Control Engineering Practice, 106, 104658. DOI: 10.1016/j.conengprac.2020.104658.

Đã đọc toàn bộ PDF 10 trang trong `References/Anew controller design method for an electric power steering system based.pdf`.

Lee 2021 mô tả bộ EPS thông thường gồm Map mô-men, logic ổn định và các logic hiệu chỉnh động như giảm chấn, quán tính, ma sát. Họ chỉ ra Map phi tuyến làm bài toán cảm giác lái và bài toán ổn định ghép với nhau: đổi Map có thể buộc thiết kế lại khâu ổn định, còn bộ lọc ổn định có thể làm méo cảm giác do Map đặt ra.

Giải pháp của họ gồm hai mô-đun tách biệt. Logic sinh cảm giác lái tạo mô-men đích; bộ phản hồi điều khiển motor để mô-men cảm biến bám giá trị đó. Bộ bám được thiết kế từ mô hình cột lái hai bậc tự do. Ba tiêu chí tần số được đặt rõ: độ lợi thấp tần đủ lớn để bám và khử nhiễu loạn, độ lợi cao tần đủ nhỏ để giảm nhiễu cảm biến, và dự trữ pha/biên đủ để bền vững. Bộ điều khiển chính là lead-lag bậc ba; bộ quan sát nhiễu (DOB) ước lượng gộp lực thanh răng và mô-men người lái để cải thiện bám. Thử xe còn so PID+DOB, lead-lag+DOB và LQG; lead-lag+DOB cho sai số nhỏ nhất.

Tham chiếu của họ được lập từ lực thanh răng ước lượng bằng mô hình và các tín hiệu EPS. Map lực thanh răng–mô-men đích giữ một phần phản lực truyền cho người lái, nên về nguyên lý phản ánh mặt đường khô, ướt, đóng băng và độ nhám mà không cần nhập trực tiếp hệ số bám. Đây là điểm mạnh hơn tham chiếu chỉ theo góc/vận tốc của Lee 2018.

Họ đã so trực tiếp bộ phản hồi với EPS Map trong mô phỏng, còn đặt cùng điều kiện suy giảm cao tần để phép so về nhiễu hợp lý hơn. Bộ phản hồi bám đường cong đích tốt hơn, và khi hạ mô-men đích xuống một phần ba thì Map cũ có thể rung hoặc mất ổn định nếu không thiết kế lại. Do đó câu chuyện tổng quát "Map không đạt mô-men đích, phản hồi đạt tốt hơn và phải xét nhiễu" đã được Lee 2021 xử lý.

Phạm vi chưa được Lee 2021 xử lý trực tiếp: mô hình chạy xe của họ dùng phản lực tỷ lệ tuyến tính với góc cột lái, mô phỏng chính và thử xe tập trung ở trạng thái đỗ; không có chuyển tiếp hệ số bám trong mô hình lốp phi tuyến, không dùng tham chiếu theo tốc độ–gia tốc ngang, không xét Map và phản hồi chạy song song, không lập mặt Pareto từ cùng ca hiệu chỉnh, và không báo trợ lực ngược. Đây mới là phạm vi phân biệt được của bài mình.

Giới hạn của chính bài mình so với Lee 2021 cũng phải nói thẳng: bài mình mới là mô phỏng, dùng PID đơn giản và không có DOB; Lee đã có thử xe và bộ lead-lag+DOB mạnh hơn PID. Vì vậy bài mình không nên tuyên bố bộ điều khiển tốt hơn Lee. Giá trị nằm ở phép khảo sát có kiểm soát dưới biến thiên bám và ở câu hỏi MapPID, nếu kết quả cuối hỗ trợ.

Trang chính thức: https://doi.org/10.1016/j.conengprac.2020.104658

Đối chiếu sản phẩm C-EPS đang được Bosch công bố: https://www.bosch-mobility.com/en/solutions/steering-systems/electric-power-steering-with-servo-unit-on-the-steering-column/ . Trang này xác nhận motor điện, cơ cấu trợ lực đặt trên cột lái và khả năng chỉnh bằng phần mềm; không dùng để suy ra thuật toán bên trong mọi bộ điều khiển thương mại.
