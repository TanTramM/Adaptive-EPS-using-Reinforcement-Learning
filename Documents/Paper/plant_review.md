# Kiểm chứng mục System Modeling and Problem Formulation

## Phạm vi

File bài báo tương ứng là `System Modeling and Problem Formulation.txt`, gồm ba tiểu mục hiện có của bài: mô hình C-EPS–xe ghép, mô-men tham chiếu theo vận tốc và gia tốc ngang, và bài toán bám mô-men. `Introduction.txt` được giữ nguyên trong lượt này.

## Mạch lập luận

| Tiểu mục | Vai trò |
| --- | --- |
| 2.1 | Xây đường truyền vật lý `mu -> tire forces/pneumatic trail -> T_r -> T_s`, là cơ chế tạo trợ lực thừa trong mô phỏng. |
| 2.2 | Xác định cùng một mô-men mục tiêu từ `v` và `a_y` cho mọi bộ điều khiển mà không cần ước lượng `mu` hoặc lực thanh răng. |
| 2.3 | Định nghĩa sai số chung, dấu của thiếu mô-men và giới hạn trợ lực chung để so Map, PID và MapPID. |

## Đối chiếu nguồn và mô hình

| Nội dung | Bằng chứng | Cách dùng trong bản mới |
| --- | --- | --- |
| Cột lái hai khối và khối dưới quy đổi | Lee 2018, Sec. II-A, Eqs. (1)–(7): vô-lăng và cột nối bằng torsion bar; `J2`, `C2`, `tau_a`, `tau_l` là đại lượng quy đổi. Các giá trị nhận dạng: `K=143.24`, `J2=0.11`, `C2=1.35`. | Rút còn động lực học khối dưới vì `theta1(t)` được cho trước; nói rõ đây là điều kiện mô phỏng của bài, không nhận là mô hình tài xế. |
| Ma sát Coulomb | Lee 2018, phần mô phỏng quanh Fig. 10 và Table III: ma sát bánh răng motor–column và rack–pinion được đưa vào mô hình. | Dùng `T_f*tanh(c*theta2_dot)`; `tanh` và `c` là cách làm mịn của mô hình hiện hành, không gán cho phương trình gốc của Lee. |
| Bicycle model và tham số xe | Rajamani 2012, Ch. 2–3; trang PDF 54 nêu cornering stiffness mỗi bánh và hệ số 2 cho cầu, trang PDF 73 cho bộ `m=1573`, `Iz=2873`, `l_f=1.1`, `l_r=1.58`, `C_Df=C_Dr=80000` mỗi bánh. | Dùng độ cứng cấp cầu `160000 N/rad`; giữ phương trình `beta_dot`, `gamma_dot`, `a_y` và nói rõ giả thiết góc nhỏ, vận tốc dọc không đổi. |
| Magic Formula | Pacejka 2006, Ch. 4; mô hình hiện hành dùng dạng rút gọn với `D=mu*F_z` và `B=C_alpha/(C*D)`. | Nói đây là simplified Pacejka form; không nhận bộ `C`, `E` là nhận dạng cho xe thật. |
| Pneumatic trail theo `mu` và góc trượt | Li et al. 2023, Eq. (3)–(4): moment arm gồm mechanical offset và pneumatic offset; pneumatic offset giảm theo `sgn(alpha)*tan(alpha)/(3*mu*W)`. | Tách `e_eff=e_c+t_p`; chỉ `t_p` giảm. Chặn `t_p>=0` và giữ caster floor là lựa chọn mô hình của bài, phải nói thẳng. |
| Bảng mô-men mục tiêu | Li and Xia 2012, Table 4: “driver's average favored steering wheel ideal torque”, 20–100 km/h và 0.1–0.4 g. | Gọi là dữ liệu “reported by” nguồn, không gọi là chuẩn phổ quát. Điểm 0, odd symmetry, PCHIP và clipping đều là lựa chọn của bài. |

## Những điểm đã sửa so với `paper_jstt.txt`

1. Đổi ký hiệu trail thành `t_p` cho pneumatic trail và `e_eff` cho cánh tay đòn tổng. Bản cũ gọi `e_p` là cánh tay đòn tổng nhưng câu mô tả dễ khiến người đọc hiểu toàn bộ là pneumatic trail.
2. Nêu rõ công thức nguồn của Li 2023 đã được điều chỉnh: dùng caster cố định, pneumatic trail có sàn 0 và hai kích thước `e_p0`, `t_0`. Đây không phải công thức được chép nguyên từ nguồn.
3. Nêu rõ `160000 N/rad` là cornering stiffness của cả cầu, tương ứng hai lốp `80000 N/rad` trong Rajamani; tránh lỗi cũ từng gọi `80000 N/rad` là cấp cầu.
4. Giảm mức khẳng định về bảng mô-men mục tiêu. Nguồn Li and Xia nói dữ liệu dựa trên nhiều thí nghiệm nhưng không cung cấp đủ thiết kế thí nghiệm để xem đây là đặc tính phổ quát.
5. Giải thích rằng `a_y` vừa phản ánh đáp ứng thật của xe vừa làm thay đổi mục tiêu. Vì vậy phương pháp không giữ cùng mô-men mục tiêu tại cùng góc lái khi `mu` đổi.
6. Giữ motor dynamics và cách tính `T_a,max` cho phần Simulation Setup; mục này chỉ đặt giới hạn chung để định nghĩa bài toán.

## Giới hạn phải giữ trong bài

- Góc vô-lăng được áp đặt; không có vòng tài xế và không dự đoán người lái sẽ sửa góc như thế nào khi cảm giác lái thay đổi.
- Một hệ số `mu` chung cho cả hai cầu và hai bên xe; không có split-mu, chuyển tải, động lực học dọc hoặc roll.
- Lốp là mô hình tĩnh; không có relaxation length hay dữ liệu nhận dạng lốp của xe cụ thể.
- `n_st`, `e_p0`, `t_0`, `C`, `E` là tham số mô hình, trong đó hình học trail chưa được xác nhận bằng xe thật. Độ lớn hiệu ứng trợ lực thừa phụ thuộc trực tiếp các giá trị này.
- Small-angle bicycle model và các số hạng chia cho `v` không phù hợp cho đỗ xe hoặc vận tốc rất thấp; miền mô phỏng bắt đầu từ 20 km/h.
- Bảng mô-men tham chiếu chỉ phủ 20–100 km/h và 0.1–0.4 g; ngoài miền được clipping, không ngoại suy.
- Kết quả chỉ chứng minh hành vi trong mô hình ghép này; không được viết như xác nhận cảm giác chủ quan, an toàn hoặc hiệu năng trên xe thật.

## Việc cần đồng bộ khi ghép bài

- Đánh số lại citation theo thứ tự xuất hiện sau `Introduction.txt`; danh sách `[1]`–`[5]` trong file mục này chỉ là số cục bộ.
- Đảm bảo ký hiệu `e_eff`, `t_p`, `e_c` được dùng nhất quán trong bảng tham số, phần sensitivity và code-to-paper description. Code hiện vẫn dùng biến nội bộ `e_p` cho cánh tay đòn tổng; không cần đổi code nếu bài định nghĩa rõ.
- Khi phần Simulation Setup được viết lại, chuyển Table 3 tham số Plant sang mục đó hoặc cân nhắc đặt ngay sau 2.1; không lặp cùng bảng ở hai mục.
- Cập nhật Fig. 1/Fig. 2 theo thứ tự hình cuối cùng của toàn bài. Placeholder hiện dùng đường dẫn đang có trong `paper_jstt.txt`.
- Giữ Fig. 3 ở dạng một hình nhìn trên của bánh trước, chỉ giải thích `delta_f`, `alpha_f`, `F_yf`. Bỏ panel nhìn bên chứa `e_c`, `t_p`, `e_eff`: các đại lượng này vẫn được định nghĩa trong Eqs. (9)–(11), nhưng kích thước dùng trong mô hình chưa được xác nhận trên xe cụ thể nên không trình bày như hình học đã đo.

