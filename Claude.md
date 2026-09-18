# Adaptive C-EPS bằng Học tăng cường - Ghi chú làm việc

Luận văn Thạc sĩ (HCMUT, GVHD: TS. Phùng Thanh Huy, HV: Trần Minh Tân).
Đề tài: điều khiển trợ lực lái điện thích ứng (Adaptive C-EPS) khắc phục hiện
tượng trợ lực thừa (over-assist) khi hệ số bám mu thay đổi, dùng RL.

Toàn bộ giao tiếp, tài liệu, code comment (nếu có) đều bằng **tiếng Việt**,
trừ tên biến/ký hiệu kỹ thuật giữ nguyên tiếng Anh/công thức gốc.

## Cấu trúc thư mục

- `Documents/` - toàn bộ tài liệu suy diễn vật lý + blueprint điều khiển.
  - `Blueprint_OverAssist_RL.txt` - tài liệu GỐC, chỉ tổng hợp lý thuyết/
    chiến lược điều khiển (phạm vi bài toán, biến trạng thái, chiến lược FF/
    FB, trỏ tới các file cụm chi tiết). KHÔNG chứa suy diễn công thức đầy đủ.
  - `Cum1_CEPS.txt`, `Cum2_Pacejka.txt`, `Cum3_2DOF.txt` - suy diễn vật lý chi
    tiết từng cụm (xem "Quy ước 1 file cụm" bên dưới).
  - `HeThongPlant_TongHop.txt` - ghép nối thuần túy 4 phương trình vi phân +
    toàn bộ đại số của 3 cụm trên thành 1 hệ nhìn tổng quan (không suy diễn
    mới, chỉ tham chiếu lại).
  - `Gemini_old/` - tài liệu/code cũ (từ bản Gemini trước), KHÔNG dùng nữa,
    giữ lại để tham khảo lịch sử. Không sửa/xóa trừ khi được yêu cầu rõ.
- `References/` - paper tham khảo (Rajamani Vehicle Dynamics and Control,
  Multi-Map EPS, CEPS ANFIS-FOC, Road_Identification_BP-NN, Saifia2015 =
  Fuzzy_Control_EPS_Constraints (trùng file), Process_Control.pdf - Seborg).
- `Model/` - Simulink/S-Function. Hiện ĐANG TRỐNG (đã xóa toàn bộ để làm lại
  từ đầu sau khi 3 file cụm ở Documents/ được chốt xong). Chỉ code lại khi cả
  3 cụm đã hoàn thiện và được xác nhận.

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

## Trạng thái hiện tại (cập nhật khi có thay đổi lớn)

- 4 biến trạng thái đã chốt: x = [theta, theta_dot, beta, gamma]. KHÔNG thêm
  y, psi (đã chứng minh không xuất hiện ở vế phải bất kỳ PT lực/mô-men nào).
- Cả 3 cụm (cơ cấu lái, lốp Pacejka, thân xe 2-DOF) đã hoàn thiện + đã tổng
  hợp thành 1 hệ (HeThongPlant_TongHop.txt).
- CÒN TREO (chưa chốt): Blueprint mục 1.3 - cách xây T_d,ref(v,a_y) làm CV
  (2 phương án đã liệt kê, chưa chọn).
- CÒN TREO: mở rộng t_p = t_p(alpha_f, mu) ở Cụm 2 (theo Multi-Map EPS.pdf) -
  chưa làm, để bước sau.
- Model/ (Simulink/S-Function) chưa viết lại - đợi chốt xong phần plant lý
  thuyết + hướng điều khiển.

## Ghi chú khác

- Đừng chỉnh sửa trực tiếp `Documents/Gemini_old/Thesis.docx` trừ khi được
  yêu cầu rõ ràng - người dùng tự dán công thức LaTeX vào Word.
- Khi trích dẫn số liệu/claim từ 1 nguồn (paper, hay câu trả lời AI khác như
  Gemini), luôn kiểm tra lại trong file PDF gốc ở `References/` trước khi xác
  nhận đúng - không nhận trích dẫn theo lời kể lại nếu chưa đọc thấy trong
  nguồn.
