# DÀN Ý LUẬN VĂN THẠC SĨ: TRỢ LỰC LÁI ĐIỆN CỘT LÁI VỚI NHÁNH PHẢN HỒI MÔ-MEN GHÉP SONG SONG BẢN ĐỒ TRỢ LỰC

Bản 1, 2026-11-12. HV: Trần Minh Tân. GVHD: TS. Phùng Thanh Huy. Tên trên là tên làm việc, chưa phải tên đề tài (xem mục 1, điểm 1).

## 0. MỤC ĐÍCH VÀ CÁCH DÙNG FILE

File này chỉ ghi dàn ý: luận văn có những chương, mục nào, mỗi mục viết gì, lấy từ đâu, đã có hay còn thiếu. Nội dung chi tiết viết thẳng vào `luanvan.txt` (chương 1 đã xong). File này thay cho `draft/dan_y_luan_van.docx` và `draft/dan_y_bai_bao.docx` (2026-10-12, thời còn Map, PI, SMC, nay đã cũ).

Nguồn chính: (1) bài báo `Documents/Paper/paper.txt` (bản đầy đủ: PT (1)-(55), Bảng 1-14, Hình 1-14); (2) các phần đã chạy sau bài: Plant dùng khối thư viện VDB, sai lệch tham số xe ±20 %, phân tích khoảng cách MapPID và PID trong ca WEAVE. Theo cấu trúc người dùng chốt 2026-11-07, luận văn = nội dung bài báo + phần VDB; các chương cũ trong `draft/` chỉ để tham khảo, sẽ viết lại.

Nhãn trạng thái dùng trong file:

- [CÓ]: đã có trong bài hoặc đã chạy xong; chỉ cần dịch sang tiếng Việt và viết lại cho luận văn.
- [VIẾT THÊM]: đã có dữ liệu hoặc ghi chú nhưng bài chưa viết; cần mở rộng hoặc gom số.
- [CHƯA CÓ]: chưa có dữ liệu; phải chạy hoặc tìm nguồn.
- [CẦN CHỐT]: người dùng hoặc thầy quyết định trước khi viết.

Viết tắt và thuật ngữ dùng trong file:

- C-EPS (Column-type Electric Power Steering): trợ lực lái điện có motor đặt trên cột lái.
- Map: bộ điều khiển dùng bản đồ trợ lực (bảng tra mô-men trợ lực theo mô-men thanh xoắn và vận tốc xe) nối với khâu bù lead-lag (một khâu sớm pha rồi một khâu trễ pha).
- PID: bộ điều khiển tỉ lệ, tích phân, vi phân. MapPID: giữ nguyên Map và thêm một nhánh PID chạy song song.
- CALIB: ca mô phỏng 140 s dùng để chọn tham số. STEADY, SLIP, WEAVE (gọi chung SSW): ba ca 100 s dùng để chấm (giữ cua trên đường khô; đổi tốc độ và hệ số bám; lái liên tục).
- RMS (Root Mean Square, căn của trung bình bình phương). e_T: sai lệch giữa mô-men thanh xoắn và mô-men mục tiêu. S: độ ồn của mô-men trợ lực (RMS phần còn lại sau khi trừ thành phần chậm).
- Mặt Pareto: tập các bộ tham số mà không bộ nào khác tốt hơn cùng lúc ở cả độ bám (R) lẫn độ êm (S).
- VDB (Vehicle Dynamics Blockset): thư viện động lực học xe của MATLAB/Simulink do MathWorks cung cấp.
- Seed: số khởi tạo bộ sinh nhiễu cảm biến; cùng seed thì cùng chuỗi nhiễu.

## 1. CÁC ĐIỂM CẦN CHỐT TRƯỚC KHI VIẾT

1. [CẦN CHỐT] Tên đề tài: đề tài đăng ký ghi "dùng học tăng cường (RL, Reinforcement Learning)", nhưng nội dung đã làm là MapPID, không có RL. Cần hỏi thầy và Phòng Đào tạo Sau đại học về thủ tục đổi tên hoặc cách giữ tên. Điểm này ảnh hưởng tên chương 1, mục tiêu, tóm tắt và hướng phát triển.
2. [ĐÃ CHỐT 2026-11-13: người dùng nói "bao gồm luôn cả phần vdb, để cuối cùng"; VDB là mục 5.8 và sai lệch tham số là mục 5.7 của chương 5, chương kết luận thành chương 6] Chương 6 riêng "Kiểm tra độ vững của kết quả" (VDB + sai lệch tham số) hay để VDB ở mục cuối chương 5 như chốt 07/11. Dàn ý này viết theo phương án chương 6 riêng (đã đưa vào câu hỏi xin ý kiến thầy trong báo cáo 14/11). Nếu giữ chốt cũ thì chương 6 gộp thành mục 5.8 và 5.9, chương 7 thành chương 6.
3. [CẦN CHỐT] Mẫu trình bày của trường: cần file mẫu hoặc quy định hiện hành (lề, cỡ chữ, đánh số hình, bảng, phương trình, kiểu trích dẫn). Phần đầu và phần cuối dưới đây theo bố cục thường gặp của luận văn thạc sĩ, phải kiểm lại theo quy định.
4. [CẦN CHỐT] Quy tắc miền thời gian của bài báo (không toán tử s, không hàm truyền, không Hz cho tham số động học) có áp cho luận văn không. Đề xuất: giữ như bài ở chương 2-5 để hai văn bản thống nhất; phần sàng lọc tuyến tính (bài chỉ tả định tính) trình bày đầy đủ ở phụ lục nếu thầy muốn.
5. [CẦN CHỐT] Bản bài làm nguồn: `paper.txt` (bản đầy đủ, khoảng 11 400 từ) hay `paper_v3.txt` (bản rút gọn, 8 364 từ). Đề xuất dùng `paper.txt` vì luận văn cần lý luận đầy đủ hơn bài.
6. [CẦN CHỐT] Mô hình người lái (khung DRIVER) và video 3D: không thuộc hướng chính; đưa vào phụ lục làm minh họa hay bỏ hẳn.
7. [CẦN CHỐT] Các hướng đã thử rồi bỏ (PI, SMC, ISMC, Map hai bậc, bộ điều khiển thứ tư): đề xuất không đưa vào luận văn; nếu đưa thì chỉ kể lịch sử ở phụ lục, không dùng làm lập luận (quy tắc "không lập luận từ các lần chạy trước").
8. [CẦN CHỐT] Có chạy phép thử K3 (MapPID với bảng Map bằng 0, ca WEAVE, 5 seed) để khép giả thuyết ở mục 5.6 không, hay để là hướng phát triển.

## 2. KHUNG TỔNG QUÁT

| Chương | Lấy từ | Trạng thái | Số trang ước (đề xuất) |
|---|---|---|---|
| Phần đầu | mẫu của trường, Abstract của bài | [CẦN CHỐT] mẫu | theo mẫu |
| 1. Tổng quan và đặt vấn đề | mục 1 của bài, số liệu thực tiễn (FHWA, JTEKT) | đã viết | 12 (hiện tại) |
| 2. Mô hình hóa hệ thống lái và xe | mục 2 và 4.1 của bài, nguồn gốc từng công thức | đã viết | 18 (hiện tại) |
| 3. Chiến lược điều khiển | mục 3 của bài | đã viết (bản 1) | 15 (hiện tại) |
| 4. Chọn tham số bộ điều khiển | mục 4 của bài | đã viết (bản 1) | 11 (hiện tại) |
| 5. Kết quả đánh giá (gồm độ bền tham số và VDB) | mục 5 của bài + việc B + việc A + VDB | đã viết (bản 1) | 26 (hiện tại, trang 56-81) |
| (6. Kiểm tra độ vững) | đã gộp vào chương 5, mục 5.7 và 5.8 | - | - |
| 6. Kết luận và hướng phát triển (trước là chương 7) | mục 6 của bài + chương 5 | [VIẾT THÊM] | 3-4 |
| Phần cuối | 14 tài liệu của bài + tài liệu thêm, phụ lục | [VIẾT THÊM] | 10-15 |

## 3. DÀN Ý TỪNG CHƯƠNG

### PHẦN ĐẦU [CẦN CHỐT theo mẫu của trường]

- Bìa, trang phụ bìa; Nhiệm vụ luận văn thạc sĩ; Lời cảm ơn; Lời cam đoan.
- Tóm tắt tiếng Việt và tiếng Anh: viết sau cùng, lấy Abstract của bài làm điểm xuất phát, thêm một câu về chương 6.
- Mục lục; danh mục hình; danh mục bảng; danh mục ký hiệu (ký hiệu, ý nghĩa, đơn vị: theta1, theta2, T_s, T_a, T_r, T_ref, mu, v, a_y, ...); danh mục viết tắt.

### CHƯƠNG 1. TỔNG QUAN VÀ ĐẶT VẤN ĐỀ [ĐÃ VIẾT, bản 2 ngày 2026-11-12: mở đầu từ thực tiễn theo cách của bài mẫu `References/luan_van_UP6.pdf`]

Nguồn: mục 1 của bài; các PDF trong `References/` (chỉ trích điều đã đọc thấy trong bản gốc); ba nguồn thực tiễn mới [16] FHWA, [17] JTEKT, [18] ảnh Wikimedia Commons (đã tải trang và kiểm câu chữ ngày 2026-11-12). Ảnh nằm ở `Documents/Thesis/figures/`.

- 1.1 Hệ thống lái trợ lực điện trên ô tô: 1.1.1 nhu cầu và mức độ phổ biến (EPS thay hệ thủy lực, số liệu thị trường châu Âu [15], ba lý do thực tiễn gồm nhiên liệu 3-5 % theo JTEKT [17]); 1.1.2 các kiểu EPS và vì sao C-EPS (JTEKT: cụm trợ lực trong cabin, hợp xe nhỏ); 1.1.3 cấu tạo C-EPS kèm Hình 1.1 (ảnh cột lái thật, có chú thích tiếng Việt). [CÓ]
- 1.2 Đặt vấn đề: 1.2.1 bộ điều khiển trợ lực trong thực tế (bản đồ, khâu bù, chỉnh bằng thử xe); 1.2.2 mặt đường ướt và trơn là điều kiện thường gặp (số liệu FHWA 2019-2023; mô-men tự lựa giảm [4]); 1.2.3 vì sao bản đồ cho trợ lực thừa (thiết kế cho đầy tải và hệ số bám cao [3], công thức ΔT_s, độ dốc không tăng tùy ý); 1.2.4 câu hỏi của luận văn. [CÓ]
- 1.3 Tình hình nghiên cứu theo ba hướng: chỉnh bản đồ hoặc dòng motor [3]-[6]; điều khiển mờ [10], [11]; phản hồi mô-men [7]-[9]; nhận xét và Bảng 1.1 (chín công trình). [CÓ]
- 1.4 Khoảng trống nghiên cứu và lý do chọn đề tài: giữ bản đồ, thêm phản hồi theo mô-men mục tiêu, vì sao PID, vì sao MapPID, lợi ích thực tiễn (không phải chỉnh lại bản đồ). [CÓ]
- 1.5 Mục tiêu nghiên cứu: một mục tiêu chính và năm nội dung. [CÓ]
- 1.6 Đối tượng và phạm vi: 1.6.1 đối tượng và ba nhóm tham số theo nguồn gốc (từ tài liệu: Lee 2018 [1], Rajamani [13], Pacejka [12]; tự chọn; do quy trình chọn); 1.6.2 phạm vi và giới hạn. [CÓ]
- 1.7 Phương pháp nghiên cứu, kèm câu "mọi con số thuộc một trong ba loại". [CÓ]
- 1.8 Đóng góp và bố cục luận văn. [CÓ]
- Việc treo của chương: (a) có thể thêm số liệu thực tiễn trong nước (tai nạn khi mưa, mùa mưa ở Việt Nam) nếu tìm được nguồn kiểm được; (b) đánh số lại tài liệu tham khảo theo thứ tự xuất hiện khi viết xong cả luận văn (hiện giữ số của bài báo [1]-[14], thêm [15]-[18]); (c) ảnh Hình 1.1 giữ giấy phép CC BY-SA 4.0, ghi nguồn và nói rõ có chú thích thêm.

### CHƯƠNG 2. MÔ HÌNH HÓA HỆ THỐNG LÁI VÀ XE [ĐÃ VIẾT, bản 1 ngày 2026-11-13: mỗi công thức đi từ nguồn kèm số phương trình, trang, điểm khác và lý do]

Nguồn: mục 2 và 4.1 của bài; Lee 2018 [1] (PT (1)-(14), Bảng III), Rajamani [13] (PT (2.19)-(2.30), tr. 27-30, 48), Pacejka [12] (PT (3.13)-(3.14), (4.6)-(4.8), (4.49), Bảng 4.2), Li 2023 [3] (PT (3)-(4)), Li và Xia [5] (Bảng 2, 4, 5), Ren và Deng [19], bảng thông số cảm biến [20]-[22], Fritsch và Carlson [23], Nexteer [24]. Hình ở `Documents/Thesis/figures/` (sinh bằng `tools/make_fig_thesis_ch2.py`).

- 2.1 Hệ thống cần mô hình hóa: bộ điều khiển trong ECU chỉ thấy T_s, v, a_y; ba khối cột lái, lốp, thân xe và vòng ghép (Hình 2.1). [CÓ]
- 2.2 Cột lái: PT (2.1)-(2.2) từ Lee [1] PT (6)-(8); ba điểm khác (ma sát tanh, T_r từ lốp, θ1 là đầu vào); nhận dạng trên xe thật Hyundai i30 (lift-on, free-handle); hạn chế: [1] không kiểm chứng trường hợp giữ cứng vô-lăng. [CÓ]
- 2.3 Lốp và mô-men phản lực: 2.3.1 góc trượt, tải tĩnh, n_st đối chiếu số đo thật [19]; 2.3.2 Magic Formula rút gọn (Pacejka (4.6)-(4.8), Bảng 4.2); 2.3.3 vệt khí nén (Li [3] PT (4), chặn dưới; t0 và e_p0 chọn vì không có số đo, không so với mô hình chổi); 2.3.4 T_r và Hình 2.4 (đỉnh T_r ở µ = 0.3 bằng 38 % đỉnh ở µ = 0.8). [CÓ]
- 2.4 Thân xe một vết: PT (2.14)-(2.16) từ Rajamani PT (2.19)-(2.22); khác: lốp phi tuyến, trạng thái β và γ; giới hạn góc nhỏ. [CÓ]
- 2.5 Ghép nối và cân bằng mô-men: PT (2.17); ví dụ T_s giảm 5.1 % khi µ từ 0.8 xuống 0.4 ở 20 m/s, θ1 = 0.3 rad. [CÓ]
- 2.6 Mô-men mục tiêu: Bảng 2.1 (Li và Xia Bảng 4), PCHIP, PT (2.18)-(2.19), Hình 2.6; đối chiếu Ren và Deng. [CÓ]
- 2.7 Mục tiêu bám và giới hạn trợ lực: PT (2.20)-(2.24), Bảng 2.2 (T_a,max từ 5.7 đến 9.8 N.m), so với năng lực motor thương mại [24]. [CÓ]
- 2.8 Motor và cảm biến: PT (2.25)-(2.26), Bảng 2.3 (bước lượng tử từ bảng thông số thật: Valeo, Bosch MM5.10, OBD-II). [CÓ]
- 2.8 (cuối mục): Bảng 2.4 tổng hợp thông số và nguồn (không có mục riêng). Đã bỏ mục kiểm chứng riêng (Bảng 2.5) theo yêu cầu người dùng 2026-11-13. [CÓ]
- 2.9 Kết luận chương và giới hạn của mô hình. [CÓ]
- Việc treo của chương: (a) phép thử cảm biến `test_sensors.m` chỉ chạy được khi có `add_sensors.m`, hàm này đã bị xóa khỏi kho mã (commit 2990a94), phải lấy lại từ lịch sử git; (b) số đo T_r hay vệt khí nén trên xe thật chưa có; (c) PT (3.13) của Pacejka được ghi theo dạng đóng và đã kiểm bằng tích phân số, nhưng chưa đối chiếu với từng ký hiệu gốc trong sách (θ_y, σ_y) một cách hình thức.

### CHƯƠNG 3. CHIẾN LƯỢC ĐIỀU KHIỂN [ĐÃ VIẾT bản 1, 2026-11-13: mục 3.1-3.6 trong luanvan.txt, PT (3.1)-(3.21), Hình 3.1-3.5, Bảng 3.1-3.2; xem khối "TRẠNG THÁI VÀ KẾ HOẠCH CHƯƠNG 3" ở cuối chương]

Nguồn: mục 3 của bài, Hình 4-6; `Documents/Notes/Controllers/LyThuyet_Map.txt`, `DieuKhien_MapPID.txt`; `Documents/Shared/KeHoach_PID_Sach.txt`.

- 3.1 Bộ Map: hiệu chỉnh trên đường khô PT (23)-(24), vùng chết và giới hạn độ dốc K_max, bảng (25), khâu bù lead-lag (26)-(27), Hình 4; thêm hình bảng Map đã hiệu chỉnh. [CÓ]
- 3.2 Giới hạn tĩnh của Map: PT (28)-(31), vì sao không thể tăng độ dốc tùy ý. [CÓ; VIẾT THÊM: một ví dụ số tại một điểm làm việc]
- 3.3 Bộ PID: luật chuẩn của Åström và Hägglund [14] PT (32); ba sửa đổi lấy từ [14] (khâu vi phân lấy trên số đo, gọi là PI-D; lọc khâu vi phân; chống bão hòa tích phân bằng tính ngược), các PT (33)-(38) và Hình 5. [CÓ]
- 3.4 Bộ MapPID: PT (39)-(42), Hình 6; trạng thái xác lập của nhánh PID (41); map ảnh hưởng động học của nhánh; cách lắp vào xe đã có sẵn map. [CÓ]
- 3.5 So sánh cấu trúc ba bộ: tín hiệu vào, số tham số phải chỉnh, phần giữ nguyên. [VIẾT THÊM: một bảng]
- TRẠNG THÁI VÀ KẾ HOẠCH CHƯƠNG 3 (ghi 2026-11-13 để làm tiếp ở phiên sau; nhật ký Lượt 95 của Tracking/historychat_vdb_tire.md). CẬP NHẬT CUỐI NGÀY 2026-11-13: bảy bước dưới đây ĐÃ LÀM XONG. luanvan.txt có chương 3 đầy đủ (3.1 Map, 3.2 giới hạn tĩnh, 3.3 PID, 3.4 MapPID, 3.5 so sánh, 3.6 kết luận); các số trong chữ đã đối chiếu với ba csv bằng script nháp (không lỗi); luanvan.docx và luanvan.pdf đã sinh lại (lúc đó 45 trang, chương 3 ở trang 28-42; sau khi thêm chương 4 và giữ bảng ngắn trên một trang: 58 trang, chương 3 ở trang 29-44). Còn lại: người dùng đọc và duyệt chương 3; chưa commit; nhãn sơ đồ Việt hóa chờ người dùng chấp nhận; nhật ký khung đã đến hạn nén. Phần kế hoạch bên dưới giữ lại để tra cứu. Khác kế hoạch ban đầu: mô-men đo sau bộ lọc của khâu vi phân đặt tên T_s,f (bài báo dùng T_f, trùng với biên độ ma sát T_f ở Chương 2); Hình 3.2 và 3.3 tách thành hai hình.
  - Yêu cầu của người dùng: được mở rộng ngoài bài báo nhưng mỗi chỗ thêm phải có lý luận và nguồn (vì sao làm như vậy); hình mới phải vẽ bằng MATLAB hoặc là hình của người dùng; không thêm đoạn hay hình ngoài bài khi không có lý do (bài học từ chương 2).
  - Cách biết đã viết tới đâu: `grep -n "^3\." Documents/Thesis/luanvan.txt` (các tiêu đề mục đã ghép). Mỗi bước dưới đây chèn trọn một nhóm mục nên luanvan.txt luôn hợp lệ; KHÔNG sinh docx, pdf cho tới bước 7. Chèn bằng `C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/insert_thesis_part.py <file_phần.txt>` (chèn trước dòng TÀI LIỆU THAM KHẢO, từ chối nếu tiêu đề đã có, giữ một bản sao lưu ở draft/luanvan_backup_last.txt); các file phần để ở Documents/Thesis/draft/ch3_parts/.
  - Bước 1: mở chương, 3.1 Map (3.1.1 cấu trúc và lý do chọn; 3.1.2 hiệu chỉnh đường khô (3.1)-(3.2); 3.1.3 dựng bảng (3.3)-(3.4); 3.1.4 khâu bù (3.5)-(3.6); Hình 3.1, 3.2). Bước 2: 3.2 giới hạn tĩnh (3.7)-(3.11), Bảng 3.1, Hình 3.3. Bước 3: 3.3 PID (3.12)-(3.18), Hình 3.4. Bước 4: 3.4 MapPID (3.19)-(3.21), Hình 3.5. Bước 5: 3.5 so sánh (Bảng 3.2) và 3.6 kết luận. Bước 6: kiểm số trong chữ với các csv, kiểm số phương trình, hình, tham chiếu mục. Bước 7: sinh luanvan.docx rồi luanvan.pdf (`python tools/txt2docx.py Documents/Thesis/luanvan.txt Documents/Thesis/luanvan.docx --thesis`, rồi `python tools/docx2pdf_word.py Documents/Thesis/luanvan.docx Documents/Thesis/luanvan.pdf`), xem các trang chương 3, cập nhật dàn ý, nhật ký, bộ nhớ.
  - Hình đã sinh (Documents/Thesis/figures/): Hinh_3_1_Map.png, Hinh_3_4_PID.png, Hinh_3_5_MapPID.png (sơ đồ của bài Fig_4 đến Fig_6, đổi nhãn sang tiếng Việt bằng tools/make_fig_thesis_ch3_diagrams.py, để chiều rộng mặc định); Hinh_3_2_Map.png (bản đồ ở 20, 60, 100 km/h cùng điểm hiệu chỉnh) và Hinh_3_3_Static.png (lời giải đồ thị của (3.7) ở 60 km/h, 0.3 g, mu 0.8 sang 0.35) vẽ bằng MATLAB (tools/make_fig_thesis_ch3.m, nhãn đọc từ tools/make_fig_thesis_ch3_labels.json, chèn `@10.0`). Số dùng trong chữ nằm ở ch3_map_slopes.csv, ch3_static_example.csv, ch3_numbers.csv cùng thư mục.
  - Phương trình theo thứ tự: (3.1) T_s,cal; (3.2) T_a,cal (bằng T_a,req (2.21) ở mu 0.8); (3.3) đệ quy dựng bảng có K_max; (3.4) M = sgn(T_s) Mbar; (3.5)-(3.6) khâu lead, lag; (3.7) T_s + M = T_r; (3.8) dT_s = dT_r/(1 + s_tb) đúng cho thay đổi hữu hạn với 0 <= s_tb <= K_max; (3.9)-(3.10) dạng thay đổi nhỏ và s_m; (3.11) de_T = dT_s; (3.12) PID dạng chuẩn và dạng song song; (3.13)-(3.15) u_P, u_I, u_D; (3.16) T_a,cmd của PID; (3.17) dT_a; (3.18) K_aw; (3.19) T_a,cmd = u_map + u_PID; (3.20) u_PID; (3.21) u_PID,ss. Dùng lại: giới hạn (2.20), motor (2.24), mục tiêu (2.17)-(2.19), T_a,req (2.21), T_r (2.8)-(2.12), cân bằng (2.16).
  - Số đã tính (đọc ở các csv): độ dốc tự nhiên lớn nhất trong 0.1-0.3 g từ 7.87 (70 km/h) đến 16.22 (25 km/h), cả 17 vận tốc lớn hơn K_max = 6.77455; nhiễu T_s,m tổng 0.0104 N.m (sigma 0.01 cộng lượng tử 0.01/sqrt(12)), T_s0 = 0.3 gấp 28.8 lần; một bước 0.01 g của a_y,m làm T_ref nhảy từ 0.12 (20 km/h) đến 0.36 N.m (100 km/h), tức 11.6 đến 34.4 lần nhiễu, một bước 1 km/h của v_m nhảy tối đa 0.041 N.m (lý do lấy đạo hàm trên số đo); cột lái bị giữ có chu kỳ riêng 0.174 s, hệ số tắt dần 0.170; ví dụ tĩnh ở 60 km/h, mu 0.8 sang 0.35, a_y 0.1/0.2/0.3 g: dT_r = -0.078/-0.344/-1.047 N.m, dT_s = -0.059/-0.044/-0.158 N.m (76.0/12.9/15.1 % của dT_r), s_tb = 0.317/6.775/5.621, (3.9) cho -0.059/-0.044/-0.135; để |dT_s| <= 0.05 N.m ở 0.3 g cần s >= 19.9, nhiễu qua độ dốc là 0.071 N.m ở 6.77 và 0.207 N.m ở 19.9; ở 60 km/h tại cuối bảng (0.4 g) bản đồ cấp 5.461 N.m so với điểm hiệu chỉnh 7.017 N.m; ma sát khô có thể lệch T_s tới T_f/(1 + K_max) = 0.257 N.m; bảng không giảm theo |T_s| ở 17/17 vận tốc.
  - Nguồn đã kiểm ở bản gốc (PDF trong References/, trích bằng PyMuPDF; số trang in của [14] bằng số trang PDF trừ 6; [1] in 748-755, bằng trang PDF cộng 747; [5] in 402-405, bằng trang PDF cộng 401). [1] mục III.A: PT (15) bản đồ có vùng chết, K_v giảm theo vận tốc; PT (16) khâu bù đặt sau bản đồ, lead tăng dự trữ pha, lag hạ độ lợi tần số cao để khỏi khuếch đại nhiễu; mục III.D: thiết kế khi xe đỗ (dốc nhất, trường hợp xấu nhất), lag đặt ở tần số thấp hơn lead và cao hơn tần số lệnh lái; Bảng III: tau_s0 = 2 N.m, K_v = 35, ma sát 2 N.m, motor 100 Hz; thử trên xe i30 ở trạng thái đỗ. [9] mục 1: bộ điều khiển thường có ba phần (bản đồ, logic ổn định, logic phụ), mô-men logic phụ cộng vào mô-men chính; bản đồ quyết định phần lớn trợ lực nên quyết định cảm giác lái; khâu ổn định gồm bộ lọc gây lệch pha làm méo cảm giác lái; Kim và Song (2002) dùng PI bám mô-men mục tiêu; Williams (2009) thiết bị gắn thêm (hai ý này trích lại qua [9]). [9] mục 4.3: PID kèm DOB sai số ±0.3 N.m, lead-lag kèm DOB ±0.1, LQG ±0.9 (xe đỗ). [3]: bản đồ truyền thống thiết kế cho tải đầy và mu = 0.8; vùng chết 2 N.m cho xe thương mại. [5] tr. 402: ba dạng đường đặc tính (thẳng, gấp khúc, cong); tr. 404: mô-men không trợ lực trừ mô-men lý tưởng là trợ lực EPS phải cấp. [14]: tr. 1 (hơn 95 % vòng điều khiển quá trình là PID; đủ cho nhiều bài toán khi động học hiền); tr. 59 (PID là thuật toán phổ biến nhất); tr. 61 (vùng chết là sửa đổi thông dụng); tr. 62-64 (phân tích tĩnh: giao điểm duy nhất nếu đơn điệu; PT (3.8) sai lệch bằng 1/(1 + K_p K) lần độ lệch); tr. 64 PT (3.9); tr. 67 (tích phân đưa sai lệch xác lập về 0); tr. 69 (đạo hàm cải thiện ổn định, quá lớn thì lại kém); tr. 70 (dạng sách giáo khoa ít dùng); tr. 72 PT (3.18) dạng song song; tr. 73 (dạng chuẩn có nghiệm phức, hợp hệ có cực dao động; dạng nối tiếp chỉ nghiệm thực) và PT (3.19)-(3.21); tr. 74 (b, c; c thường bằng 0; b = 1, c = 0 "đôi khi gọi là PI-D"; đáp ứng với nhiễu tải và nhiễu đo không phụ thuộc b, c); tr. 76-77 PT (3.22), độ lợi tần số cao tối đa K N, N điển hình 8 đến 20; tr. 81-85 chống bão hòa tính ngược; tr. 85 T_t lớn hơn T_d, nhỏ hơn T_i, quy tắc căn bậc hai, đừng chọn quá nhỏ khi có khâu đạo hàm.
  - Chỗ khác bài báo, phải nói thẳng khi viết: (a) bỏ câu "chu kỳ dao động cột lái khoảng 0.16 s" của bài (không kiểm được nguồn; số tính được là 0.174 s); (b) bài viết "[14] gọi cách này là PI-D" còn nguồn chỉ nói "đôi khi gọi"; (c) thêm PT (3.8) đúng cho thay đổi hữu hạn, bài chỉ có dạng tuyến tính hóa; (d) cân bằng tĩnh bỏ qua ma sát khô nên sai số trong mô phỏng có thể lớn hơn phân tích (phân tích tĩnh trên 26 cửa sổ static của CALIB cho sai số lớn nhất 5.7 % ở 30 km/h, 0.3 g, tính bằng script nháp chưa lưu; bài báo đo 26.2 % trong mô phỏng); (e) ví dụ tĩnh cho thấy Map đã bù 85-87 % ở 0.2-0.3 g, không viết như thể Map bù kém về tĩnh, mà nhấn vào giới hạn độ dốc và nhiễu.
  - Còn mở: (i) nhãn sơ đồ đã Việt hóa bằng PIL như Hình 2.1, hỏi người dùng có chấp nhận không; (ii) hằng số thời gian lead-lag và K_max chỉ nêu ở chương 4 (chương 3 nêu K_max = 6.77 như giá trị chọn ở chương 4); (iii) chương 3 không thêm tài liệu tham khảo mới.

### CHƯƠNG 4. CHỌN THAM SỐ BỘ ĐIỀU KHIỂN [ĐÃ VIẾT bản 1, 2026-11-13: mục 4.1-4.6 trong luanvan.txt, PT (4.1)-(4.10), Hình 4.1-4.2, Bảng 4.1-4.5; xem khối "KẾ HOẠCH CHƯƠNG 4" ở cuối chương]

Nguồn: mục 4 của bài, Hình 7; trong `Documents/Shared/` có `QuyChuan.txt`, `PhuongPhap_TimThamSo.txt`, `KeHoach_SoMatPareto.txt`, `KeHoach_ChonNhieuSeed.txt`; kết quả chọn tham số nằm ở `Result/Compare/Pareto_common/`, `Result/Compare/CALIB_profile/`, `Result/Controllers/<Ctrl>/Calib_v2/`.

- 4.1 Thiết lập mô phỏng: chu kỳ điều khiển 1 ms, cách rời rạc hóa (Euler tiến cho tích phân, sai phân lùi cho vi phân, Tustin cho khâu bù). [CÓ]
- 4.2 Ca CALIB và chỉ tiêu: Bảng 3, R PT (44)-(45), S (46)-(47), e_rel (48), năm seed chung (49)-(50), hai chỉ tiêu phụ; hình biên dạng CALIB (góc vô-lăng, vận tốc, hệ số bám theo thời gian). [CÓ; VIẾT THÊM: hình biên dạng]
- 4.3 Ràng buộc và tiêu chí chấp nhận: T_d < T_i, ràng buộc lọc ở chu kỳ 0.5 s, sàng lọc tuyến tính, thử nhiễu loạn actuator PT (51), e_rel,max <= 10 %. [CÓ]
- 4.4 Tìm tham số và chọn điểm cuối: Bảng 4, lưới thô rồi lưới mịn, hai pha đánh giá trên seed chung (52), mặt safe và mặt full, J = R x S (53), quy tắc hòa 3 %. [CÓ; VIẾT THÊM: sơ đồ khối quy trình]
- 4.5 Kết quả hiệu chỉnh: Bảng 5-7, Hình 7; Map chọn trên mặt safe vì mọi điểm đạt 10 % đều trượt phép thử chấp nhận phi tuyến; T_d của PID và MapPID gần cận dưới của lưới. [CÓ]
- KẾ HOẠCH CHƯƠNG 4, ĐÃ LÀM XONG bản 1 cuối ngày 2026-11-13 (luanvan.txt có 4.1-4.6; số trong chữ đã đối chiếu với csv và json bằng script nháp, không lỗi; thêm tài liệu [25] Seborg, Edgar, Mellichamp và Doyle (2017); hình bằng tools/make_fig_thesis_ch4.m cùng csv ch4_numbers.csv, ch4_selected.csv; luanvan.docx, pdf 58 trang, chương 3 ở trang 29-44 và chương 4 ở trang 45-55, Word 0 vấn đề; sửa tools/txt2docx.py cho bảng tới 16 hàng nằm trọn một trang; chưa commit; chờ người dùng duyệt). Nguồn đã kiểm ở PDF gốc: [11] Nguyen 2025 tr. 19 (dải lái 0.2-2.0 Hz, không vượt 5.0 Hz, hay gặp 0.2-1.0 Hz, kịch bản 1 Hz) và tr. 32 (vòng điều khiển EPS dưới 1 ms, tốc độ 1 kHz); [25] Seborg 4th ed. (số trang in bằng số trang PDF trừ 12): tr. 129 PT (8-12) hằng số bộ lọc alpha 0.05-0.2 hay dùng 0.1, tr. 256 khuyến nghị GM 1.7-4.0, PM 30-45 độ, tr. 313 PID rời rạc giống PID liên tục khi dt/Ti <= 0.1, sai phân lùi có dự trữ ổn định lớn hơn, lấy mẫu cộng giữ bậc không tương đương trễ dt/2; [1] mục III.D PM > 45 độ cho độ bền vững; [14] tr. 77 và tr. 85. Chỗ nói thẳng là lựa chọn: ngưỡng e_rel 10 % (không có PDF Deborne 2014 trong References), ngưỡng hòa 3 %, hệ số 3 sigma, hệ số 2 của hai tỉ số nhiễu loạn, cận lưới, T_d >= 20 ms, ngưỡng 0.5 N.m của trợ lực ngược; Map có mặt full rỗng nên chọn trên mặt safe; sai số tĩnh Map trong mô phỏng 26.2 % lớn hơn phân tích tĩnh 5.73 % (bỏ qua ma sát), nguyên nhân chưa tách riêng; hai thời gian vi phân sát cận dưới 20 ms. Kế hoạch ban đầu (ghi 2026-11-13, sau khi chương 3 xong; làm như chương 3: viết từng phần vào Documents/Thesis/draft/ch4_parts/ rồi chèn bằng `tools/insert_thesis_part.py`; biết đã tới đâu bằng `grep -n "^4\." Documents/Thesis/luanvan.txt`; chỉ sinh docx, pdf ở bước cuối).
  - Yêu cầu giữ như chương 3: được mở rộng nhưng mỗi chỗ thêm có lý luận và nguồn (nêu vì sao làm như vậy); hình mới vẽ bằng MATLAB, nhãn tiếng Việt; mốc nào chỉ là lựa chọn của tác giả thì viết thẳng là lựa chọn (đặt trước khi chạy), không viện kết quả các lần chạy trước làm lập luận.
  - Dữ liệu có sẵn: Result/Compare/CALIB_profile/CALIB_profile.csv (t, v_kmh, mu, ay_target_g, theta1_deg; 140 s, bước 0.01 s) và CALIB_windows.csv (68 cửa sổ: label, t0, t1; tiền tố static_, trans_, sine_, mu_) cho Hình 4.1 (biên dạng CALIB, mở rộng có lý do: Bảng 3 của bài chỉ liệt kê cửa sổ); Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv (cột in_set, front_safe, front_full, Rtb, Stb) và ParetoCommon_select.csv cho Hình 4.2 (hình gốc của bài do tools/make_fig_section4.py vẽ bằng matplotlib, nên vẽ lại bằng MATLAB); Bảng 4.4, 4.5 từ Model/shared/data/map.json, pid.json, mappid.json (trường design, ngoài cùng); Bảng 4.3 (số ứng viên) từ ParetoCommon_select_report.csv.
  - Phương trình dự kiến (4.1)-(4.10) từ PT (44)-(53) của bài (PT (43) của motor đã là (2.24)): R_g, R, lọc S, S, e_rel, R_bar và S_bar, e_rel,max, hai tỉ số nhiễu loạn actuator, ngưỡng loại pha 2 (3 sigma), J = R_bar x S_bar. Bảng: 4.1 cửa sổ CALIB (Bảng 3 của bài), 4.2 cận tìm kiếm (Bảng 4), 4.3 ứng viên và mặt Pareto (Bảng 5), 4.4 tham số chọn (Bảng 6), 4.5 chỉ tiêu trên CALIB (Bảng 7); cảm biến dùng lại Bảng 2.3. Hình 4.1 biên dạng CALIB, Hình 4.2 mặt Pareto.
  - Bước: 1) kiểm nguồn ngoài ở PDF gốc (Nguyen 2025 tr. 19 dải lái 0.2-2.0 Hz; Seborg PT 8-12 tr. 141, mục 14.7, mục 17.4, Bảng 12.7; Åström-Hägglund phần cài đặt số) và sinh hai hình MATLAB cùng csv; 2) mục 4.1; 3) mục 4.2; 4) mục 4.3; 5) mục 4.4; 6) mục 4.5 và kết luận; 7) kiểm số với json, csv, sinh docx, pdf, cập nhật dàn ý, nhật ký, bộ nhớ.
  - Nguồn nội bộ để lấy nhãn nguồn từng mốc: Documents/Shared/QuyChuan.txt phần 9 ([NGUỒN], [GIẢI THÍCH], [CẦN NGUỒN]) và Documents/Shared/PhuongPhap_TimThamSo.txt; chỉ dùng điều kiểm được ở PDF gốc trong References/.
  - Chỗ phải nói thẳng khi viết: ngưỡng e_rel 10 % (QuyChuan ghi nguồn Deborne 2014, PDF không có trong References/, nên viết là lựa chọn, đối chiếu nguồn nếu bổ sung); ngưỡng hòa 3 %, hệ số 3 sigma, hệ số 2 của hai tỉ số nhiễu loạn, cận lưới, T_d >= 20 ms là lựa chọn; kết quả Map phải chọn trên mặt safe vì mặt full rỗng.

### CHƯƠNG 5. KẾT QUẢ ĐÁNH GIÁ [ĐÃ VIẾT bản 1, 2026-11-13: mục 5.1-5.9 trong luanvan.txt, gồm độ bền tham số (5.7) và VDB (5.8, mục cuối); xem khối "KẾ HOẠCH CHƯƠNG 5" và dòng "TIẾN ĐỘ CHƯƠNG 5" ở cuối chương]

Nguồn: mục 5 của bài, Hình 8-14; `Documents/Shared/KeHoach_SSW.txt`; kết quả ở `Result/Controllers/<Ctrl>/Cases_ssw/`, `Cases_ssw_1ms/` và `Result/Compare/SSW_summary/`. Phân tích WEAVE:
`Documents/Shared/KeHoach_WEAVE_HaiNhanh.txt` mục 5, `Result/Compare/PID_vs_MapPID/`, `Result/Controllers/MapPID/Cases_ssw_branch/`.

- 5.1 Giao thức đánh giá: Bảng 8, E_RMS PT (54), độ lệch tương đối có dấu (55), năm seed chấm 99995-99999; hình biên dạng ba ca. [CÓ; VIẾT THÊM: hình biên dạng]
- 5.2 STEADY (giữ cua trên đường khô): Bảng 9-10, Hình 8-9. [CÓ]
- 5.3 SLIP (đổi tốc độ và hệ số bám): Bảng 11-12, Hình 10-11. [CÓ]
- 5.4 WEAVE (lái liên tục): Bảng 13-14, Hình 12-13. [CÓ]
- 5.5 Tổng hợp theo seed: Hình 14; MapPID so với Map và so với PID. [CÓ]
- 5.6 Vì sao MapPID bám kém PID trong WEAVE (trả lời câu hỏi bài để ngỏ ở mục 6): khoảng cách theo từng cửa sổ trên 5 seed; độ lớn hai nhánh (u_map rất nhỏ so với u_PID); ba phép chẩn đoán D1 (bỏ khâu lag), D2 (bỏ cả lead và lag), D3 (vùng chết bằng 0); kết luận: nhánh Map không giải thích khoảng cách; giả thuyết còn lại là hệ số PID của hai bộ khác nhau (K3). [CÓ dữ liệu, VIẾT THÊM; K3 [CHƯA CÓ], xem mục 1 điểm 8]
- 5.7 Nhận xét chung và giới hạn của chương. [CÓ]

- KẾ HOẠCH CHƯƠNG 5 (ghi 2026-11-13, sau khi chương 4 xong; người dùng nói: "làm tiếp cho phần 5, bao gồm luôn cả phần vdb, để cuối cùng"). ĐÃ CHỐT: chương 6 riêng bị gộp vào chương 5 (phương án chốt 07/11), VDB là mục cuối nội dung; sai lệch tham số +-20 % (việc A) đặt ngay trước VDB vì cùng loại câu hỏi (độ vững); chương "Kết luận" thành chương 6. Cấu trúc làm việc: 5.1 Giao thức (Bảng 5.1, Hình 5.1 biên dạng ba chuỗi, PT (5.1) E_RMS, (5.2) độ lệch tương đối có dấu, đọc theo ngưỡng phân biệt JND của [26]); 5.2 STEADY (Bảng 5.2-5.3, Hình 5.2); 5.3 SLIP (Bảng 5.4-5.5, Hình 5.3); 5.4 WEAVE (Bảng 5.6-5.7, Hình 5.4); 5.5 tổng hợp theo seed (Hình 5.5); 5.6 vì sao MapPID bám kém PID ở WEAVE (Bảng 5.8-5.10, Hình 5.6-5.7); 5.7 sai lệch tham số xe +-20 % (Bảng 5.11-5.12, Hình 5.8); 5.8 khối thư viện VDB, MỤC CUỐI (Bảng 5.13-5.14, Hình 5.9); 5.9 kết luận chương. Con số trong chữ và bảng lấy từ csv bằng tools/make_ch5_numbers.py (ra Documents/Thesis/figures/ch5_numbers.csv); hình bằng tools/make_fig_thesis_ch5.m (MATLAB, nhãn tiếng Việt đọc từ make_fig_thesis_ch5_labels.json); kiểm số trong chữ bằng script nháp ở scratchpad (check_ch5_numbers.py).
  - Cách làm: tám file phần ở Documents/Thesis/draft/ch5_parts/ (01_Protocol, 02_Steady, 03_Slip, 04_Weave, 05_WeaveWhy, 06_Robust, 07_VDB, 08_Conclusion), chèn từng file bằng tools/insert_thesis_part.py; sau mỗi phần luanvan.txt vẫn hợp lệ. Trạng thái từng phần ghi ở dòng "TIẾN ĐỘ CHƯƠNG 5" ngay dưới; lượt sau chỉ cần grep "^5\." trong luanvan.txt để biết đã tới đâu.
  - Dữ liệu: năm seed 99995-99999 ở Result/Controllers/<Ctrl>/Cases_ssw/<Ctrl>_metrics_s9999N.csv (cửa sổ và toàn chuỗi; tái lập đúng Bảng 9, 11, 13 của bài: Map STEADY 1.0585 +- 0.0007, PID 0.2496 +- 0.0039, MapPID 0.2498 +- 0.0049) và <Ctrl>_<CA>_sig_s9999N.csv (10 ms; cột t, theta1_rad, v_mps, mu, a_y_target_g, T_s, T_d_ref, e_T, T_a, a_y); 5.6: Result/Compare/PID_vs_MapPID/ và Result/Controllers/MapPID/Cases_ssw_branch/; 5.7: Result/Compare/Robust/ (Robust_summary_s99999.csv 16 biến thể, Robust_seeds_summary.csv 5 seed); 5.8: Model/VDB/temp_test/Summary/VDB_body_summary_s99999.csv.
  - Nguồn đã kiểm ở PDF gốc: [26] Deborne, Khouri Silva, Kemeny (2014), SAE 2014-01-0447 (tr. 5 mục Conclusion: JND mô-men vô-lăng 14.8 % theo chiều kim đồng hồ và 18 % ngược chiều ở 1 N.m xuống 10.2 % và 12.7 % ở 5 N.m; 18 người 22-56 tuổi; xác suất đúng 79.4 %, tr. 4; chỉ đo khi không lái, mô-men tĩnh). SỬA SAI CỦA BẢN CHƯƠNG 4: bản trước ghi PDF Deborne không có trong References/; thực ra có (file "Steering Wheel Torque Rendering - Measure of Driver Discrimination Capabilities.pdf"); đã sửa câu ở mục 4.3 và câu kết luận chương 4, thêm tài liệu [26].
  - Mở rộng so với bài (mỗi chỗ có lý luận): Hình 5.1 biên dạng (người đọc cần biết đầu vào để đọc đáp ứng; cùng lý do như Hình 4.1); Hình đáp ứng vẽ cả ba bộ trên ba ô cùng thang (bài bỏ PID vì chồng với MapPID và hạn chế số hình của tạp chí; luận văn không bị giới hạn đó và ba ô cho kiểm được câu "PID chồng MapPID"); đọc độ lệch tương đối bằng JND [26] (bài chỉ nêu "chưa chứng tỏ cảm giác lái"); 5.6 trả lời câu bài để ngỏ (dữ liệu việc B); 5.7, 5.8 từ việc A và VDB.
  - Chỗ phải nói thẳng khi viết: 5.6 chỉ một seed (99999) cho W1-W3, K3 (bộ hệ số PID của MapPID khác PID riêng) CHƯA kiểm, không có kiểm định thống kê; 5.7 nguồn danh định phải theo bản đã sửa 2026-11-13 (m, l_f, l_r, I_z, C_alpha từ Rajamani [13] tr. 48; T_f, J_col, C_col từ Lee 2018 [1]; t_0, e_p0 tự chọn; băng thông motor 100 Hz Lee 2018), KHÔNG theo bảng cũ trong KeHoach_DoBenThamSo.txt (ghi nhầm [5]); 5.8 là kiểm chứng cài đặt, KHÔNG phải xác thực bằng số đo xe thật; bản có M_z (TireLagMz) không độc lập nên chỉ nêu một câu ở giới hạn.
  - TIẾN ĐỘ CHƯƠNG 5 (2026-11-13, XONG bản 1): đã chèn đủ 01-08 (5.1 đến 5.9: PT (5.1)-(5.4), Bảng 5.1-5.15, Hình 5.1-5.9, khoảng 11 300 từ); luanvan.docx và luanvan.pdf sinh lại (84 trang, chương 5 ở trang 56-81, tài liệu tham khảo từ trang 82, Word 0 vấn đề); số trong chữ và trong các bảng đối chiếu 210/210 với figures/ch5_numbers.csv bằng check_ch5_numbers.py (scratchpad, chạy được lại nếu viết lại: hàm checks_a, checks_why, checks_robust, checks_vdb, checks_concl). Sửa ở chương 4: câu về ngưỡng 10 % (mục 4.3 và kết luận chương) nay trích [26] Deborne; thêm [26] và [27] vào danh mục. Sửa cho khớp việc gộp chương: mục 1.8 (bố cục nay là sáu chương) và câu cuối mục 2.9 (trỏ tới mục 5.7 và 5.8 thay cho chương 6). Chưa commit. CÒN: người dùng duyệt; chương kết luận (chương 6), tóm tắt, phụ lục, đánh số lại tài liệu tham khảo.
  - CẬP NHẬT MA SÁT (2026-11-13, sau lượt 98): khung ROBUST chạy xong KeHoach_MaSatCotLai.txt (Result/Compare/Friction/, script run_friction_check.m, summarize_friction.m; R0 PASS, tái lập Bảng 4.5 lệch 2e-6). Kết quả theo quy tắc đọc chốt trước: Q1 giải thích được (SLIP ramp_dn +11.59 -> +1.49 %, ramp_up -9.30 -> +0.59 %, tĩnh 1.12 %); Q2 KHÔNG (ba mức giảm chênh, mức 85 km/h xấu đi 0.59 -> 2.35 điểm); Q3 do ma sát (CALIB static_v30_apos0p30g, e_rel,max trung bình 26.00 -> 6.01 %, phân tích tĩnh 5.73 % cùng cửa sổ); Q4 E_RMS Tf0: Map -49.6 / -12.6 / -51.0 %, PID -41.2 / +26.9 / -7.2 %, MapPID -38.2 / +32.7 / -5.0 % (STEADY / SLIP / WEAVE). Đã viết vào luanvan.txt: mục 3.2 (bỏ câu 'lệch tới 0.26 N.m' vì ở cửa sổ CALIB độ lệch đo được khoảng 0.40 N.m, lớn hơn T_f/(1+K_max) = 0.26; chưa giải thích được chênh này), 3.6, 4.5, 4.6, 5.3 (đoạn mới), 5.9 (kết luận, thêm câu giá trị MapPID so với PID). CÓ CHỦ ĐÍCH KHÔNG đưa vào chữ: E_RMS của PID và MapPID khi T_f = 0 (xe không ma sát không có thật; PID và MapPID kém hơn ở SLIP +27 và +33 %, chưa có cơ chế đã kiểm), và Q2 ở mục 5.2 (không rõ ràng). Nếu bị hỏi miệng: thứ hạng không đổi khi T_f = 0 (Map vẫn kém hơn 2.3 đến 3.6 lần). Thêm ở 5.7.1 và 5.7.3: mức 20 % có mốc tham khảo Lee 2018 Mechatronics [8, tr. 163] (SỬA 2026-11-13: bản trước ghi nhầm [1]) (lực thanh răng danh định đổi 50-150 %), ngưỡng hòa 5 % bằng khoảng một nửa JND nhỏ nhất 10.2 % của [26]. Mục 'số khác bài báo' không còn là việc treo: bài báo chỉ để tham khảo, không sửa.
  - Phát hiện khi viết 5.1-5.5 (đã đưa vào chữ): (1) sai lệch tĩnh của Map ở ba mức mạnh nhất của STEADY được phân tích tĩnh mục 3.2 giải thích (29.5 / 8.8 / 19.9 % so với mô phỏng 32.3 / 10.8 / 19.3 %; độ dốc tự nhiên 14-18 lớn hơn K_max 6.77); chênh còn lại tối đa 4.8 điểm % (bản sau 2026-11-13: chữ chỉ ghi con số, không đoán nguyên nhân vì phép T_f = 0 giảm chênh ở 3 trong 4 mức nhưng mức 85 km/h xấu đi); (2) E_RMS của PID và MapPID ở STEADY do một sự kiện: giây 9-10 (quay vô-lăng nhanh -130 độ ở 25 km/h, trợ lực chạm T_a,max 8.07 N.m khoảng 0.6 s), chiếm 81 % tổng bình phương sai lệch, bỏ giây đó còn 0.110 N.m; (3) độ lệch Map ở hai đoạn đổi vận tốc của SLIP đổi dấu theo chiều đổi tốc độ (+11.6 / -9.3 %) trong khi phân tích tĩnh cho 0 đến 2.9 % luôn dương, nên không do bản đồ tĩnh; ĐÃ TÁCH 2026-11-13 bằng chạy Map với T_f = 0 (xem dòng CẬP NHẬT MA SÁT ngay dưới); (4) so theo cặp seed (Bảng 5.8). SỐ KHÁC BÀI BÁO: đoạn đi thẳng cuối STEADY (95-100 s, 5 seed): độ lệch chuẩn T_s của Map 0.003, PID 0.11, MapPID 0.13 N.m; bài ghi 0.015, 0.14, 0.17 và không nêu khoảng thời gian (không tái lập được); biên độ mục tiêu quanh tâm WEAVE: bài ghi 1.6, dữ liệu 1.46 N.m (max |T_ref| trong 3-22 s).

### KẾ HOẠCH HOÀN THIỆN LUẬN VĂN (ghi 2026-11-13, sau lượt 99; người dùng: "luận văn hoàn chỉnh luôn"; làm từng bước, mỗi bước xong ghi dấu [XONG] ở đây)

Quyết định đã chốt khi lập kế hoạch: giữ tên làm việc của đề tài (ghi cờ cho người dùng, đổi ở một chỗ); trường chưa có mẫu nên dùng bố cục thường gặp (bìa, phụ bìa, lời cam đoan, lời cảm ơn, tóm tắt Việt và Anh, mục lục, danh mục hình, bảng, ký hiệu, viết tắt); KHÔNG bịa dữ liệu cá nhân (mã số học viên, ngành, ngày bảo vệ, lý lịch) và trang Nhiệm vụ luận văn do Phòng Đào tạo cấp: để dòng trống có ngoặc vuông cho người dùng điền; không viết câu khai báo công cụ AI (người dùng quyết định); danh mục công trình ghi bài báo là bản thảo, chưa công bố.
- Bước 1 [XONG 2026-11-13]: công cụ (txt2docx.py có chỉ thị @@SECTION, @@C, @@CB, @@I, @@R, @@SP, @@PAGEBREAK, @@TITLE, @@H, @@TOC, @@LOF, @@LOT, @@TAB, @@W; docx2pdf_word.py có --fields và --save-docx). tools/txt2docx.py --thesis hỗ trợ phần đầu (bìa, mục lục tự động bằng trường Word, danh mục hình và bảng bằng trường TOC theo kiểu đoạn, số trang La Mã cho phần đầu, số Ả Rập từ chương 1) và tools/docx2pdf_word.py cập nhật trường rồi (tùy chọn) lưu lại docx.
- Bước 2 [XONG]: chương 6 (6.1 kết luận theo năm nội dung của mục 1.5, 6.2 hạn chế, 6.3 hướng phát triển có lý luận và nguồn: người lái trong vòng điều khiển theo Mehrabi [15] mục 4.5 và 5.4, thích nghi theo [8, tr. 163] và kết quả 5.7, phép thử K3, thử phần cứng) chèn bằng tools/insert_thesis_part.py từ draft/ch6_parts/.
- Bước 3 [XONG]: phần đầu trong luanvan.txt (draft/front_parts/): bìa, phụ bìa, lời cam đoan, lời cảm ơn, tóm tắt, abstract, danh mục ký hiệu và viết tắt (rút từ luanvan.txt bằng script, rồi chọn tay).
- Bước 4 [XONG]: phần cuối (tools/make_thesis_back.py sinh bảng phụ lục từ csv): danh mục công trình, phụ lục (A bảng đầy đủ các biến thể, B cửa sổ chấm CALIB và SSW, C kết quả theo seed, D cách tái lập), lý lịch trích ngang (ô trống).
- Bước 5 [XONG, tools/renumber_thesis_refs.py, ánh xạ cũ->mới 3->1, 1->2, 15->3, 7->4, 17->5, 18->6, 9->7, 8->8, 16->9, 4->10, 6->11, 2->12, 5->13, 10->14, 11->15, 13->16, 12->17, 19->18, 23->19, 24->20, 20->21, 21->22, 22->23, 14->24, 25->25, 26->26, 27->27, 28->28; các ghi chú cũ trong dàn ý và nhật ký dùng SỐ CŨ]: đánh số lại tài liệu tham khảo theo thứ tự xuất hiện (script có sao lưu, kiểm mọi dạng trích dẫn).
- Bước 6 [CHƯA]: sinh docx, pdf, xem các trang đầu, mục lục, danh mục; cập nhật nhật ký, bộ nhớ.
- Sửa ngay khi lập kế hoạch: tài liệu cho mốc 20 % ở mục 5.7.1 là [8] (Lee 2018 Mechatronics, tr. 163), không phải [1] như bản đầu của lượt 99.

### CHƯƠNG 6. KIỂM TRA ĐỘ VỮNG CỦA KẾT QUẢ [ĐÃ GỘP VÀO CHƯƠNG 5 ngày 2026-11-13 theo lời người dùng: mục 6.3 thành 5.7, mục 6.2 thành 5.8 (VDB ở cuối); chương 7 thành chương 6. Nội dung dưới đây giữ làm nguồn]

- 6.1 Mục đích: kết quả chương 5 dựa trên một mô hình tự viết với một bộ tham số; câu hỏi của chương: thứ hạng và kết luận có còn giữ khi (a) thay khối của mô hình bằng khối thư viện, (b) tham số xe lệch khỏi giá trị danh định. Phân biệt kiểm chứng cài đặt (verification, đã làm) với xác thực bằng số đo trên xe (validation, chưa làm). [VIẾT THÊM]
- 6.2 Plant dùng khối VDB. Nguồn: `Documents/Shared/KeHoach_Plant_VDB.txt`, `KeHoach_VDB_ThanXe.txt`, `Documents/Notes/PRSM/DoiChieu_Plant_VDB.txt`; `Model/VDB/`, `Model/VDB/temp_test/Summary/`, `Result/PRSM/Plant_VDB/`; báo cáo `Documents/Report/VDB_tire_baocao.docx` (07/11), `Week1411_baocao.docx` (14/11).
  - 6.2.1 Khối lốp và khối thân của VDB thay vào Plant, giữ nguyên cổng; ánh xạ cổng và kiểm từng cổng. [CÓ]
  - 6.2.2 Cùng giả thiết với Plant: vòng hở và vòng kín trùng Plant, tức là kiểm chứng cài đặt. [CÓ]
  - 6.2.3 Độ trễ lốp (lốp cần một quãng lăn để tạo lực, đặc trưng bằng chiều dài trễ): khác biệt có căn cứ duy nhất; kết quả SSW của ba bộ trên bốn biến thể Plant VDB; thứ hạng giữ, riêng SLIP thành hòa giữa MapPID và PID. [CÓ]
  - 6.2.4 Khác biệt mô hình còn lại: vệt khí nén PT (9) so với mô hình chổi và mô-men tự lựa M_z của VDB; bản có M_z được khớp theo PT (9) nên không độc lập, chỉ nêu ở phần giới hạn. [CÓ ghi chú]
- 6.3 Sai lệch tham số xe +-20 %. Nguồn: `Documents/Shared/KeHoach_DoBenThamSo.txt` mục 10; `Result/Compare/Robust/`.
  - 6.3.1 Cách thử: tám nhóm tham số (Mass, Calpha, Trail, Caster, Jcol, Ccol, Tf, Motor), 17 biến thể x 3 bộ x 3 ca SSW, seed 99999, kiểm lại 5 seed cho 9 biến thể; bộ điều khiển giữ tham số danh định; nguồn giá trị danh định của từng nhóm. [CÓ]
  - 6.3.2 Thứ hạng ba bộ qua các biến thể; các biến thể SLIP mà MapPID hơn PID quá ngưỡng hòa. [CÓ]
  - 6.3.3 Độ nhạy (biểu đồ tornado) và sai lệch tĩnh của Map khi tham số lệch. [CÓ]
- 6.4 Tổng hợp chương và giới hạn: một xe, một số tham số tự chọn, chưa có số đo. [VIẾT THÊM]
- 6.5 (tùy chọn) Minh họa: video 3D hai xe, mô hình người lái điều khiển bằng mô-men. [CẦN CHỐT, mục 1 điểm 6]

### CHƯƠNG 7. KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

Nguồn: mục 6 của bài; chương 6; mục 5.6.

- 7.1 Kết luận: các ý ở mục 6 của bài, thêm kết quả chương 6 và mục 5.6. [VIẾT THÊM]
- 7.2 Hạn chế: một xe mô phỏng, góc vô-lăng cho trước, tham số tự chọn, chưa có số đo và phần cứng. [CÓ trong bài, VIẾT THÊM]
- 7.3 Hướng phát triển: người lái trong vòng điều khiển, thử trên phần cứng, tham số đo trên xe thật, phép thử K3, bộ điều khiển thích nghi hoặc học tăng cường (tùy tên đề tài). [VIẾT THÊM]

### PHẦN CUỐI

- Danh mục công trình đã công bố: bài báo gửi JSTT (ghi trạng thái nộp). [CẦN CHỐT]
- Tài liệu tham khảo: 14 tài liệu của bài, thêm tài liệu dùng ở chương 1, 2, 6 (tài liệu của VDB, bảng hệ số lốp của Pacejka, ...); kiểu trích dẫn theo mẫu của trường.
- Phụ lục [VIẾT THÊM]:
  - A: thông số mô hình đầy đủ (nếu không đặt ở mục 2.9).
  - B: lịch thời gian chi tiết của CALIB và SSW (bảng cửa sổ chấm).
  - C: sàng lọc tuyến tính (68 điểm làm việc).
  - D: cấu trúc mô hình Simulink và mã nguồn, cách tái lập kết quả.
  - E: kết quả bổ sung (bảng đầy đủ theo seed và theo biến thể).
- Lý lịch trích ngang.

## 4. THỨ TỰ VIẾT VÀ CÁCH TỔ CHỨC FILE (ĐỀ XUẤT)

1. Chương 2, 3, 4: dịch và mở rộng từ bài, ít phụ thuộc các điểm cần chốt.
2. Chương 5, thêm mục 5.6.
3. Chương 6, sau khi thầy trả lời mục 1 điểm 2.
4. Chương 1 (đã viết) và chương 7.
5. Tóm tắt, phần đầu, phụ lục.

Tất cả viết chung vào một file `luanvan.txt` (mỗi đoạn một dòng, ký hiệu viết `$latex$`, phương trình dạng "(n) ascii" rồi "[ latex ]"), sinh Word bằng `tools/txt2docx.py --thesis` rồi xuất PDF bằng `tools/docx2pdf_word.py`. Số liệu trong chương lấy từ file csv bằng script, không gõ tay.

## 5. DỮ LIỆU ĐÃ CÓ (PHẦN ĐÃ CHẠY) VÀ CHỖ DÙNG

| Đợt chạy | Kết quả ở | Dùng cho |
|---|---|---|
| Kiểm thử các khối mô hình | test_*.m trong Model/original/PRSM/<Phần>/script/ | 2.10 |
| Chọn tham số trên CALIB (5 seed 99990-99994) | Result/Compare/Pareto_common/, Result/Controllers/<Ctrl>/Calib_v2/ | chương 4 |
| Chấm SSW (5 seed 99995-99999) | Result/Controllers/<Ctrl>/Cases_ssw/, Cases_ssw_1ms/, Result/Compare/SSW_summary/ | chương 5 |
| Hình của bài | Figures/main/Fig_1 đến Fig_14 | chương 2-5 |
| Phân tích hai nhánh trong WEAVE (việc B) | Result/Compare/PID_vs_MapPID/, Result/Controllers/MapPID/Cases_ssw_branch/ | 5.6 |
| Plant VDB: lốp, thân, lốp + thân, độ trễ lốp | Model/VDB/temp_test/Summary/, Result/PRSM/Plant_VDB/ | 6.2 |
| Sai lệch tham số +-20 % (việc A) | Result/Compare/Robust/ | 6.3 |
| Báo cáo đã gửi thầy (hình dùng lại được) | Documents/Report/VDB_tire_baocao.docx, Week1411_baocao.docx, Result/Report/Week1411/ | chương 6 |
| Người lái, video 3D | Result/PRSM/Driver/, Model/VDB/temp_test/Viz3D/ | 6.5 (tùy chọn) |

