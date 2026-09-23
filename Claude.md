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

## Quy tắc dựng model Simulink (áp dụng cho MỌI `build_*.m` trong `Model/`)

Toàn bộ quy tắc dưới đây rút ra TỪ bản người dùng tự format tay
(`Model/Plant/Tires.mdl`) - đó là CHUẨN phong cách. Script `build_*.m` phải
sinh ra đúng cấu trúc đó; riêng vị trí/kích thước khối thì người dùng tự sắp
lại, script chỉ cần đặt hợp lý.

Model KHÔNG dựng tay - luôn sinh bằng script `build_*.m` (Simulink API), lưu
ra file hậu tố `_s`. Bản KHÔNG có `_s` là bản người dùng format tay từ bản
`_s`, script TUYỆT ĐỐI không ghi đè.

**1. Phân cấp: 1 subsystem cho MỖI ĐẠI LƯỢNG CÓ TÊN trong phương trình**
- Cụm = 1 subsystem gốc (`Tires`, `SteeringColumn`).
- Trong cụm, tách subsystem con theo từng "Mục"/phương trình của file cụm
  (`SlipAngles`, `TireForces`, `AligningTorque`).
- Trong mỗi mục, tách TIẾP: mỗi đại lượng CÓ TÊN trong phương trình (`D`,
  `B`, `F_yf`, `F_yr`, `T_s`...) có 1 subsystem riêng tính ra nó.
- Đại lượng trung gian KHÔNG có tên trong phương trình (t1..t4 của Magic
  Formula) để nguyên trong subsystem, KHÔNG tách thêm.
- Tên subsystem = ĐÚNG tên đại lượng nó tính ra (`D`, `B`). Nếu tên đó trùng
  tên 1 cổng ở cùng cấp thì thêm tiền tố `Cal ` (`Cal F_yf`, `Cal F_yr` - vì
  `TireForces` đã có cổng ra tên `F_yf`, `F_yr`).

**2. Đại lượng bất biến theo thời gian: đọc thẳng, KHÔNG truyền cổng**
- Đại lượng đã tính sẵn 1 lần trong `load_derived.m` (vd `F_zf`) đặt 1 khối
  Constant NGAY TẠI subsystem cần dùng - KHÔNG tạo cổng ra rồi nối vòng qua
  nhiều cấp. Cần ở 2 nơi thì đặt 2 khối Constant riêng.

**3. Đặt tên khối**
- Cổng In/Out: tên CÓ NGHĨA, đúng tên biến vật lý (`theta2`, `alpha_f`,
  `T_s`). Đây là giao diện công khai, `test_*.m` dò theo tên này.
- Khối tính toán: CÓ đặt tên, theo mẫu:
  - `Prod_<kết quả hoặc toán hạng>`: `Prod_D`, `Prod_CD`, `Prod_u`, `Prod_lfg`
  - `Div_<kết quả>`: `Div_B`, `Div_delta_f`, `Div_lfg_v`, `Div_Ktr`
  - `Sum_<kết quả>`: `Sum_af`, `Sum_ar`, `Sum_t1`, `Sum_ep`
  - `Trig_<hàm>_<đối số>`: `Trig_atan_u`, `Trig_tan_af`, `Trig_sin_t4`
  - `Sign_<đối số>`: `Sign_af`
  - `Int_<biến trạng thái>`: `Int_x1`, `Int_x2`
- Khối Constant: ĐỂ TÊN MẶC ĐỊNH (`Constant`, `Constant1`, ...). Chỉ đặt
  `Value` trỏ THẲNG tên biến base workspace. Mỗi lần dùng 1 tham số là 1
  khối Constant riêng, không chia sẻ.
- Khối Goto/From: ĐỂ TÊN MẶC ĐỊNH (`Goto`, `Goto1`, `From`, `From1`, ...).

**4. Goto/From**
- Dùng cho MỌI đại lượng CÓ TÊN (biến riêng) được tạo ra và dùng ở nơi khác
  trong cùng 1 cấp - KỂ CẢ khi chỉ có 1 đích đến (vd `delta_f` trong
  `SlipAngles`). BỎ HẲN quy tắc cũ "phải ≥2 đích đến mới tạo tag" - hễ đại
  lượng có tên riêng trong công thức là tạo Goto/From, không đếm số đích.
  Mục đích: mỗi phương trình đứng độc lập về hình ảnh, không có dây dài cắt
  ngang sơ đồ.
- Tag = ĐÚNG tên biến, KHÔNG thêm hậu tố (`gamma`, `v`, `beta`, `delta_f`,
  `D`, `B`, `T_s`). Không dùng `_s`, `_sig`.
- Luôn `TagVisibility = 'local'`. Nhờ local mà tag trùng tên ở các cấp khác
  nhau không va chạm.

**5. Chọn khối theo phép toán, không gom biểu thức**
- Nhân/chia: khối `Product` (chia = `Inputs='*/'`). KHÔNG dùng `Gain`.
- `sin`/`atan`/`tan`/`tanh`: khối `Trigonometric Function`. `sgn(.)`: khối
  `Sign`. `|.|`: khối `Abs`. KHÔNG dùng `Fcn`/`MATLAB Function`.

**6. Bố cục (layout) - script CŨNG phải tuân theo, không chỉ để dành cho bản
format tay**
- Kích thước khối GIỮ NGUYÊN mặc định - CHỈ dịch vị trí (`moveBlock()`),
  không kéo dãn/co khối.
- Cổng vào (Inport) mặc định ở CỘT NGOÀI CÙNG BÊN TRÁI subsystem; cổng ra
  (Outport) ở CỘT NGOÀI CÙNG BÊN PHẢI.
  - NGOẠI LỆ: nếu 1 cổng vào/tag (From) chỉ thực sự được dùng ở GIỮA hoặc
    CUỐI chuỗi tính toán (ép về cột trái sẽ ra dây rất dài), cho phép đặt
    nó gần ĐÚNG CHỖ nó được dùng thay vì ép về cột trái (vd tag `D` trong
    `Cal F_yf` - dùng ở cuối chuỗi Magic Formula, đặt gần `Prod_Fyf`, không
    đặt tận cột trái cùng `alpha_f`).
- Khối Constant KHÔNG bắt buộc dồn về 1 cột riêng - đặt SÁT khối tiêu thụ nó
  (phía trên hoặc dưới đường tín hiệu chính), để dây ngắn và đường tín hiệu
  chính không bị lệch trục (vd `F_zf` trong `D` đặt ngay dưới `Prod_D`; `C`,
  `C_alpha_f` trong `B` đặt ngay trên `Prod_CD`/`Div_B`).
- Chuỗi khối tính toán CHÍNH (nối tiếp nhau đúng thứ tự công thức) phải
  THẲNG HÀNG trên cùng 1 trục (cùng y nếu xếp ngang) - để dây nối là ĐƯỜNG
  THẲNG, không gấp khúc, trừ khi không tránh được (nhánh phụ nhập từ
  trên/dưới). Mẫu chuẩn nhất - `Cal F_yf`: `Prod_u -> Trig_atan_u ->
  Sum_t1 -> Prod_t2 -> Sum_t3 -> Trig_atan_t3 -> Prod_t4 -> Trig_sin_t4 ->
  Prod_Fyf` nằm nguyên 1 hàng ngang, không lệch.
- Cho phép kéo GIÃN KHOẢNG CÁCH giữa các khối tính toán (Product, Divide,
  Sum...) để có khoảng trống, tránh dồn khối sát nhau gây rối mắt - đây là
  đổi VỊ TRÍ, không phải đổi KÍCH THƯỚC khối (vẫn giữ mặc định).
- Chừa đủ khoảng cách dọc giữa các hàng/nhóm khối để TÊN KHỐI (label hiển
  thị cạnh khối) không đè lên khối ở hàng kế bên.
- 2+ subsystem con cùng cấp, cùng đổ vào 1 giai đoạn tiếp theo (vd
  `Cal F_yf` và `Cal F_yr` cùng ra `TireForces`), xếp THẲNG HÀNG theo nhóm:
  cùng mép trái, xếp chồng dọc cách đều nhau, cổng ra cũng thẳng hàng.
- Tránh dây cắt nhau (wire crossing) khi có thể - chọn thứ tự xếp nhánh
  vào/ra sao cho dây đi tự nhiên, không vắt qua khối khác.

**7. Bộ hàm tiện ích dùng chung (copy nguyên giữa các `build_*.m`)**
`moveBlock`, `createSubsystem`, `addInport`, `addOutport`, `addConstant`
(tên mặc định), `addGoto`, `addFrom` (tên mặc định), `addProduct`, `addSum`,
`addTrigFcn`, `addSignBlock`, `addIntegrator` (nhận tên rõ ràng).

**8. Code trong file `.m` viết bằng TIẾNG ANH** - tên hàm, tên biến, comment.
Chỉ tài liệu (`.txt`, `.md`) và hội thoại mới dùng tiếng Việt.

**9. Test: mỗi model có ĐÚNG 2 file test**
- `test_cumN_s.m` test bản `_s` (script sinh); `test_cumN.m` test bản format
  tay. Mỗi file cố định 1 tên model, TỰ CHỨA (không phụ thuộc file thứ ba),
  không nhận tham số tên model.
- Tự dò subsystem gốc + cổng THEO TÊN, KHÔNG giả định thứ tự cổng - bản
  format tay có thể đổi thứ tự (thực tế `Tires.mdl` có `F_yr` là cổng 1,
  `F_yf` là cổng 2, ngược bản `_s`).
- Nghiệm đối chiếu phải tính ĐỘC LẬP ngay trong file test (đọc thẳng
  `params.json`), KHÔNG lấy giá trị đã tính sẵn ở base workspace - nếu không
  thì test không bắt được lỗi của chính `load_derived.m`.
- Hệ có số hạng phi tuyến dốc (`tanh(c*x)` với `c` lớn) PHẢI đặt `MaxStep`
  cho harness - solver bước-thay-đổi mặc định chọn bước quá lớn sau khi hệ
  ổn định, gây méo số liệu log (đã gặp thật ở Cụm 1).

## Trạng thái hiện tại (cập nhật khi có thay đổi lớn)

- **Bài toán điều khiển** đã dựng lại từ đầu theo khung Seborg (Blueprint
  mục 1.2-1.4): MV = T_a; CV = T_s (mô-men cảm biến); DV không đo được =
  {T_d (mô-men tay tài xế), mu}; DV đo được = v. Sai số: e_T = T_s - T_d,ref.
- **Phạm vi đã THU HẸP**: chỉ xét khắc phục over-assist, KHÔNG xét chỉ tiêu
  "mượt"/độ êm (Blueprint mục 1.4(d)).
- **Cụm 1 đã đổi sang mô hình 2 khối quán tính có THANH XOẮN** (bỏ giả thiết
  trục cứng): tham số K, J1, C1, J2, C2, T_f từ Lee 2018 [1]. Lý do: trục
  cứng làm T_a không tác động thật lên CV. Biến trạng thái Cụm 1: theta1,
  theta1_dot, theta2, theta2_dot (toàn hệ thành 6 biến, không còn 4).
- **Cụm 2** giữ nguyên vật lý, chỉ đổi cổng vào `theta` -> `theta2` (góc phía
  sau thanh xoắn).
- Model/: Cụm 1 và Cụm 2 đã dựng lại xong theo quy tắc trên, test PASS khớp
  giải tích. CHƯA làm: `build_plant.m`, `build_cum3.m` (rà lại),
  `build_reference.m` (đổi T_d -> T_s), các `sweep_*.m`.
- CÒN TREO: T_a,max chưa có giá trị số - phương pháp đã chốt là tự xác định
  từ Plant sau khi ghép xong (0.9 x ngưỡng mất ổn định, Blueprint mục 1.4c).
- CÒN TREO: `params_cum1.csv` chưa cập nhật theo bộ tham số mới.

## Ghi chú khác

- Đừng chỉnh sửa trực tiếp `Documents/Gemini_old/Thesis.docx` trừ khi được
  yêu cầu rõ ràng - người dùng tự dán công thức LaTeX vào Word.
- Khi trích dẫn số liệu/claim từ 1 nguồn (paper, hay câu trả lời AI khác như
  Gemini), luôn kiểm tra lại trong file PDF gốc ở `References/` trước khi xác
  nhận đúng - không nhận trích dẫn theo lời kể lại nếu chưa đọc thấy trong
  nguồn.
