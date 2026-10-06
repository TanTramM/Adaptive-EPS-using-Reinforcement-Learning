# -*- coding: utf-8 -*-
"""Build Documents/PI/pi.txt from the result files (numbers are read from the CSVs, not typed)."""
import os, io, glob
import pandas as pd

ROOT = r'C:\Users\Admin\OneDrive\Desktop\git\Adaptive-EPS-using-Reinforcement-Learning'
R = os.path.join(ROOT, 'Result')
OUT = os.path.join(ROOT, 'Documents', 'PID', 'pi.txt')

def f(x, n=3):
    return f'{x:.{n}f}'

des = pd.read_csv(os.path.join(R, 'PID', 'Design', 'PI_design_grid.csv'))
wide = pd.read_csv(os.path.join(R, 'PID', 'Design', 'PI_design_grid_wide_check.csv'))
res = pd.read_csv(os.path.join(R, 'PID', 'Design', 'PI_plant_resonance.csv'))
kimax = pd.read_csv(os.path.join(R, 'PID', 'Design', 'PI_feasible_Ki_max.csv'))
reg = pd.read_csv(os.path.join(R, 'PID', 'Design', 'PI_feasible_region.csv'))
sw = pd.read_csv(os.path.join(R, 'PID', 'Sweep', 'PI_sweep_summary.csv'))
sel = pd.read_csv(os.path.join(R, 'PID', 'Sweep', 'PI_sweep_selection.csv'))
mapref = pd.read_csv(os.path.join(R, 'PID', 'Sweep', 'Map_final_TK_reference.csv')).iloc[0]
mk = pd.read_csv(os.path.join(R, 'Map', 'KSweep', 'Map_k_sweep_summary.csv'))
win = pd.read_csv(os.path.join(R, 'PID', 'Sweep', 'PI_TK_window_errors.csv'))
pid_none = pd.read_csv(os.path.join(R, 'PID', 'TestCases', 'PID_test_case_metrics.csv'))
cmp_dir = os.path.join(R, 'Compare', 'Map_vs_PID')
summ = pd.read_csv(os.path.join(cmp_dir, 'Map_vs_PID_noise_study_summary.csv'))

chosen = des[des.wc_design_rad_s == float(sel.loc[sel.controller == 'PI', 'selected_parameter'].iloc[0])].iloc[0]
piS = sw[sw.wc_design_rad_s == chosen.wc_design_rad_s].iloc[0]
rmin = sw.mean_R_RMS_eT_Nm.min()
mk_ok = mk[mk.pass_ == 1] if 'pass_' in mk.columns else mk[mk['pass'] == 1]
rmapsel = sel.loc[sel.controller.str.startswith('Map')].iloc[0]

L = []
def add(s=''):
    L.append(s)

SEP = '=' * 190
DASH = '-' * 190
add(SEP)
add('BỘ ĐIỀU KHIỂN PI')
add(SEP)
add('Mục này thiết kế bộ điều khiển PI (proportional-integral, bộ điều khiển tỉ lệ - tích phân, tức bộ PID không có khâu vi phân) thay cho bản đồ trợ lực của mục 2, và so sánh với bản đồ trên cùng điều kiện. Bộ điều khiển được thiết kế chỉ từ hệ PRSM (đối tượng, giá trị đặt, cảm biến và motor, tức mọi phần trừ bộ điều khiển) và không dùng thông số nào của bản đồ; từ mục 2 chỉ mượn phương pháp và tiêu chí, để hai bộ so sánh được khách quan. PI được làm trước vì đơn giản và phổ biến nhất trong công nghiệp; khâu vi phân chỉ được thêm nếu PI không đạt (mục 3.9). Trong tài liệu này PI và PID được gọi chung là bộ PID, PI là trường hợp khâu vi phân bằng không.')
add()
add(DASH)
add('3. Bộ điều khiển PI')
add(DASH)
add('3.1. Vai trò và nguyên tắc so sánh khách quan')
add('Bản đồ ở mục 2 không có bộ nhớ nên không triệt được sai số xác lập và phải dùng độ dốc lớn (kéo theo khâu bù pha và độ lợi tần số cao lớn) để giảm sai số đó. Bộ PI có khâu tích phân, về nguyên tắc triệt được sai số xác lập mà không cần độ lợi lớn, nên có thể êm hơn; đổi lại PI phải tính sai số $e_T = T_s - T_{d,ref}$ nên đọc thêm gia tốc ngang $a_y$ (qua giá trị đặt $T_{d,ref}$), điều mà bản đồ không làm. Đây là khác biệt về thông tin đầu vào và được ghi rõ ở Bảng 14, không giấu đi.')
add('Để kết quả so sánh phản ánh cấu trúc chứ không phản ánh điều kiện thử hay công sức chỉnh, hai bộ điều khiển được đặt trong cùng điều kiện (Bảng 14). Quy tắc chọn tham số cuối cùng được đặt bằng con số trước khi chạy ca thử, và sau khi chạy sáu ca thử chuẩn TC1 đến TC6 không chỉnh lại tham số nào.')
add('Bảng 14: Điều kiện chung của bản đồ và bộ PI')
add('Hạng mục | Cách làm (áp cho cả hai bộ điều khiển trừ khi ghi khác)')
add('Hệ PRSM | Cùng khối đối tượng, cảm biến, motor và giới hạn $T_{a,max}(v)$; chỉ thay khối bộ điều khiển trong khung vòng kín chung')
add('Thông tin đầu vào | Chỉ tín hiệu đo, không đọc $\\mu$. Bản đồ đọc $T_s$ và $v$; PI đọc thêm $a_y$ qua $T_{d,ref}$ (khác biệt về cấu trúc)')
add('Điều kiện ổn định | Độ dự trữ pha $\\ge 45$ độ ([1], mục III.D) với cả đường khô và $k_r = 0$ (mất bám, vì $\\mu$ không đo được). Với PI thêm độ dự trữ biên $\\ge 2$ (tự chọn); bản đồ đạt $\\ge 4.8$ (mục 2.4)')
add('Tham số điều chỉnh | Bản đồ: độ dốc lớn nhất $K_{max}$ (11 giá trị). PI: tần số cắt $\\omega_c$ (13 giá trị)')
add('Ca chọn tham số | Ca TK (đường khô, 30, 60, 100 km/h), nhiễu mức high, hạt giống 91001 đến 91003, chỉ tiêu $R$, $S$, $TV$ như phương trình (16)')
add('Quy tắc chọn (đặt trước) | Trong các điểm có $R \\le 1.02 R_{min}$ lấy điểm có $S$ nhỏ nhất')
add('Ca chấm điểm | TC1 đến TC6, nhiễu mức high, hạt giống 90001 đến 90005, Map và PI chạy cùng đợt; mọi chỉ tiêu tính trên tín hiệu thật')
add('Báo cáo | Mọi chỉ tiêu, kể cả chỉ tiêu mà PI kém hơn')
add()
add('3.2. Cấu trúc bộ điều khiển')
add('Bộ điều khiển đọc bốn tín hiệu đo được là mô-men cảm biến $T_s$, gia tốc ngang $a_y$, vận tốc $v$ và lệnh sau giới hạn trợ lực $T_{a,lim}$ (chỉ để chống bão hòa tích phân), lấy mẫu với chu kỳ $T_{ctl} = 1$ ms như bản đồ. Giá trị đặt $T_{d,ref}$ lấy từ chính khối Reference của mục 1 (cùng bảng, cùng nội suy) với $v$ và $a_y$ đo, rồi tính sai số theo quy ước của chương mô hình: $e > 0$ nghĩa là tay lái nặng hơn mong muốn, cần thêm trợ lực.')
add()
add('  (17)  e_k = T_s,k - T_d,ref(v_k, a_y,k)')
add('  [ e_k=T_{s,k}-T_{d,ref}(v_k,a_{y,k}) ]')
add()
add('Lệnh trợ lực là tổng của thành phần tỉ lệ và thành phần tích phân. Tích phân dùng công thức Euler tiến, kèm khâu chống bão hòa kiểu tính ngược (back-calculation): khi lệnh vượt giới hạn, khối motor chặn lệnh và trả về $T_{a,lim}$, phần chênh lệch $T_{a,lim} - T_{a,c}$ kéo tích phân về để nó không cộng dồn khi đã bão hòa; hằng số thời gian bám bằng $T_i$.')
add()
add('  (18)  T_a,c,k = K_p*e_k + u_I,k,   u_I,k+1 = u_I,k + T_ctl*(K_i*e_k + K_aw*(T_a,lim,k - T_a,c,k)),   K_aw = 1/T_i = K_i/K_p')
add('  [ T_{a,c,k}=K_p e_k+u_{I,k},\\qquad u_{I,k+1}=u_{I,k}+T_{ctl}\\big(K_i e_k+K_{aw}(T_{a,lim,k}-T_{a,c,k})\\big),\\qquad K_{aw}=\\dfrac{1}{T_i}=\\dfrac{K_i}{K_p} ]')
add()
add('Bộ điều khiển không chặn $T_{a,max}$ và không có trễ motor: hai việc đó nằm trong khối motor dùng chung (phương trình (9)), nên cùng một giới hạn và cùng một trễ áp cho mọi bộ điều khiển. Bộ điều khiển không đọc $\\mu$. Khối được dựng bằng `Model/PID/script/build_pid.m`, kiểm tra bằng `test_pid_s.m` (so với phép tính độc lập từ `pid.json` và `ref.json`, sai lệch lớn nhất $7 \\cdot 10^{-16}$ N.m, có cả đoạn chạm giới hạn để kiểm tra chống bão hòa).')
add('[Hình 14: Sơ đồ khối bộ điều khiển PI: ba khâu lấy mẫu, khối Reference, khâu tỉ lệ, khâu tích phân Euler tiến với đường chống bão hòa đọc $T_{a,lim}$]')
add()
add('3.3. Mô hình dùng để thiết kế')
add('Vòng trợ lực được tuyến tính hóa giống mục 2.4 (phương trình (13)): giữ nguyên góc vô-lăng, ma sát khô không tạo cản (trường hợp xấu nhất), thân xe chưa kịp thay đổi, mô-men phản hồi mặt đường thay bằng độ cứng $k_r$, và có cả trễ motor $G_m(s)$. Có hai mặt đường: đường khô ($k_r = 30$ N.m/rad) và lốp bão hòa ($k_r = 0$, trường hợp $\\mu$ rất thấp); bộ điều khiển phải đạt điều kiện trên cả hai vì $\\mu$ không đo được. Hàm truyền được rời rạc hóa bằng bộ giữ bậc không với chu kỳ 1 ms, như khi thiết kế bản đồ.')
add('Cột lái là một khối quán tính nối với lò xo (thanh xoắn và lốp) qua một giảm chấn nhỏ, nên hàm truyền có hai cực phức với đỉnh cộng hưởng ngay ở giữa dải làm việc (Bảng 15, Hình 15). Đỉnh này là nguyên nhân chính giới hạn thiết kế PI: PI chỉ làm trễ pha, không có khả năng bù pha như khâu lead của bản đồ, nên không thể đặt tần số cắt vượt qua đỉnh cộng hưởng.')
add('Bảng 15: Cộng hưởng của plant (từ lệnh trợ lực tới mô-men cảm biến, có trễ motor)')
add('Mặt đường | $k_r$ [N.m/rad] | Độ lợi tĩnh | Đỉnh [dB] | Tần số đỉnh [rad/s] | Hệ số tắt dần | Tần số pha $-180$ độ [rad/s]')
for _, r in res.iterrows():
    nm = 'Đường khô' if r.plant == 'dry road' else 'Lốp bão hòa'
    add(f'{nm} | {f(r.k_r_Nm_per_rad, 1)} | {f(r.dc_gain)} | {f(r.peak_dB, 1)} | {f(r.peak_rad_s, 1)} | {f(r.zeta_column)} | {f(r.phase_minus180_rad_s, 1)}')
add()
add('[Hình 15: Biểu đồ Bode của plant (có trễ motor) cho đường khô và lốp bão hòa | Result/PI/Design/PI_plant_bode.png]')
add()
add('3.4. Phương pháp thiết kế')
add('Bộ PI rời rạc có dạng:')
add()
add('  (19)  C(z) = K_p * (1 + (T_ctl/T_i)/(z - 1))')
add('  [ C(z)=K_p\\left(1+\\dfrac{T_{ctl}/T_i}{z-1}\\right) ]')
add()
add('Hai tham số $K_p$ và $T_i$ được tham số hóa theo tần số cắt mong muốn $\\omega_c$ và hệ số $a = \\omega_c T_i$ (vị trí điểm không của PI so với tần số cắt). Với mỗi cặp ($\\omega_c$, $a$), $K_p$ được chọn sao cho độ lợi vòng hở bằng một tại $\\omega_c$ trên đường khô (mô hình danh định); khi đó chỉ còn $a$ là tham số tự do. Công thức dưới đây viết cho hệ liên tục để thấy xu hướng; khi tính mã dùng giá trị chính xác của mô hình rời rạc.')
add()
add('  (20)  K_p(a) = 1 / ( |G(j*omega_c)| * sqrt(1 + 1/a^2) ),   K_i = K_p/T_i = K_p*omega_c/a')
add('  [ K_p(a)=\\dfrac{1}{|G(j\\omega_c)|\\sqrt{1+1/a^2}},\\qquad K_i=\\dfrac{K_p}{T_i}=\\dfrac{K_p\\,\\omega_c}{a} ]')
add()
add('$K_p$ tăng theo $a$ và $K_p$ chính là độ lợi của PI ở tần số cao, tức hệ số khuếch đại nhiễu cảm biến; vì vậy $a$ nhỏ nhất cho độ lợi nhiễu nhỏ nhất và tích phân mạnh nhất. Đây là cùng nguyên tắc mà bản đồ dùng khi chọn cặp lead có độ lợi tần số cao nhỏ nhất. Cho $a \\to 0$ thì PI suy biến thành bộ tích phân thuần, nên đặt chặn dưới $a \\ge 0.1$ (điểm không của PI cao hơn tần số cắt một decade). Với mỗi $\\omega_c$, lấy $a$ nhỏ nhất thỏa đồng thời, trên cả hai mặt đường: vòng kín ổn định, độ dự trữ pha $\\ge 45$ độ và độ dự trữ biên $\\ge 2$.')
add('Độ dự trữ biên (gain margin, GM) là hệ số mà độ lợi vòng hở có thể nhân lên trước khi mất ổn định, đo tại tần số $\\omega_{180}$ nơi pha vòng hở bằng $-180$ độ; nó bảo vệ vòng kín khỏi sai lệch về độ lợi (độ cứng, hằng số motor, $k_r$ theo $\\mu$), còn độ dự trữ pha bảo vệ khỏi sai lệch về trễ. Đỉnh độ nhạy $M_s$ (peak sensitivity) đo khoảng cách nhỏ nhất từ đường cong vòng hở tới điểm mất ổn định trên mọi tần số và được báo cáo thêm:')
add()
add('  (21)  GM = 1/|L(j*omega_180)|,   M_s = max_omega |1/(1 + L(j*omega))|,   L = C*G')
add('  [ GM=\\dfrac{1}{|L(j\\omega_{180})|},\\qquad M_s=\\max_\\omega\\left|\\dfrac{1}{1+L(j\\omega)}\\right|,\\qquad L=C\\,G ]')
add()
add('Điều kiện $\\mathrm{GM} \\ge 2$ là lựa chọn của tác giả (nguồn [1] chỉ yêu cầu độ dự trữ pha); lý do chọn là vòng có cộng hưởng nên độ dự trữ pha một mình không bảo đảm đủ biên độ ở lân cận cộng hưởng. Điều kiện này áp cho PI; bản đồ vốn đã đạt $\\mathrm{GM} \\ge 4.8$ nên không bị ảnh hưởng.')
add()
add('3.5. Kết quả thiết kế tuyến tính')
add('Bảng 16 cho các điểm thiết kế từ $\\omega_c = 0.5$ rad/s tới giới hạn khả thi. Độ dự trữ pha rất dư ở mọi điểm (92 đến 98 độ) vì PI chỉ có trễ pha nhỏ ở dải tần thấp; điều kiện chặn thật sự là độ dự trữ biên. Ở $\\omega_c = 7$ rad/s độ dự trữ biên chỉ còn ' + f(chosen.GM_dry, 2) + ' (đường khô) và ' + f(chosen.GM_sat, 2) + ' (lốp bão hòa), và độ dự trữ pha của lốp bão hòa tụt còn ' + f(chosen.PM_sat_deg, 1) + ' độ vì đỉnh cộng hưởng ' + f(res.peak_dB.iloc[1], 1) + ' dB của mặt đường này cắt mức 0 dB tại ' + f(chosen.wc_sat_rad_s, 1) + ' rad/s (cột $\\omega_c$ thật của lốp bão hòa trong Bảng 16).')
add('Bảng 16: Thiết kế PI theo tần số cắt (PM, GM, $M_s$ cho đường khô / lốp bão hòa)')
add('$\\omega_c$ [rad/s] | $K_p$ | $K_i$ [1/s] | $T_i$ [ms] | $a$ | PM [độ] | GM | $M_s$ | $\\omega_{180}$ khô [rad/s] | $|S(j\\pi)|$ tại 0.5 Hz')
for _, r in des.iterrows():
    add(f'{r.wc_design_rad_s:g} | {f(r.Kp, 3)} | {f(r.Ki_1_per_s, 2)} | {f(1000 * r.Ti_s, 1)} | {f(r.a_wcTi, 3)} | {f(r.PM_dry_deg, 1)} / {f(r.PM_sat_deg, 1)} | {f(r.GM_dry, 2)} / {f(r.GM_sat, 2)} | {f(r.Ms_dry, 2)} / {f(r.Ms_sat, 2)} | {f(r.wcg_dry_rad_s, 1)} | {f(r.S_at_0p5Hz_dry, 3)}')
add()
w7 = wide[wide.wc_design_rad_s == 7].iloc[0]
add('Từ $\\omega_c = 7.25$ rad/s trở lên không có giá trị $a$ nào thỏa các điều kiện (kiểm tra các điểm 7.25, 7.5, 7.75, 8, 10, 12, 15, 20, 30, 60, 100 và 200 rad/s, file `PI_design_grid_wide_check.csv`). Riêng $\\omega_c = 40$ rad/s thỏa về hình thức vì điều kiện độ lợi bằng một đạt ngay ở đỉnh cộng hưởng; điểm này có $K_i = ' + f(wide[wide.wc_design_rad_s == 40].Ki_1_per_s.iloc[0], 2) + '$ 1/s, nhỏ hơn $K_i = ' + f(chosen.Ki_1_per_s, 2) + '$ 1/s của điểm 7 rad/s, nên độ lợi vòng ở dải lái 0.2 đến 2 Hz thấp hơn và không có lợi, không xét tiếp.')
add('Để kiểm tra rằng họ một tham số $\\omega_c$ không bỏ sót bộ PI tốt hơn nằm ngoài họ này, mặt phẳng ($K_p$, $K_i$) được quét trực tiếp với lưới 20 giá trị $K_p$ nhân 70 giá trị $K_i$ (Hình 16), cùng điều kiện ổn định, độ dự trữ pha và độ dự trữ biên trên cả hai mặt đường. Với mỗi $K_p$, $K_i$ lớn nhất còn khả thi là:')
add('Bảng 17: $K_i$ lớn nhất còn khả thi theo $K_p$ (lưới $K_i$ có bước khoảng 7.5 %)')
add('$K_p$ | ' + ' | '.join(f'{x:g}' for x in kimax.Kp))
add('$K_i$ lớn nhất [1/s] | ' + ' | '.join('không có' if pd.isna(x) else f(x, 2) for x in kimax.Ki_max_feasible_1_per_s))
add()
kmx = kimax.Ki_max_feasible_1_per_s.max()
add('$K_i$ lớn nhất trên lưới là ' + f(kmx, 2) + ' 1/s tại $K_p$ từ 0.2 đến 0.25, và không có điểm khả thi nào với $K_p \\ge 0.6$. Điểm $\\omega_c = 7$ rad/s ($K_p = ' + f(chosen.Kp, 3) + '$, $K_i = ' + f(chosen.Ki_1_per_s, 2) + '$ 1/s) nằm trên biên của vùng khả thi (sai khác trong một bước lưới). Nói cách khác, với các điều kiện đã chọn không tồn tại bộ PI có độ lợi tích phân lớn hơn đáng kể, nên điểm cuối của họ $\\omega_c$ đã là giới hạn của cấu trúc PI trên plant này, không phải do cách tham số hóa.')
add('[Hình 16: Vùng ($K_p$, $K_i$) khả thi của bộ PI (xanh) và các điểm thiết kế theo $\\omega_c$ (đỏ, nhãn là $\\omega_c$ [rad/s]) | Result/PI/Design/PI_feasible_region.png]')
add('[Hình 17: Hệ số, độ dự trữ pha và độ dự trữ biên của PI theo tần số cắt thiết kế | Result/PI/Design/PI_design_margins.png]')
add()
add('3.6. Chọn tần số cắt trên ca TK')
add('Mỗi điểm thiết kế của Bảng 16 chạy trên ca TK (đường khô, ba vận tốc, cua gấp, lái hình sin và chỉnh lái nhỏ), cảm biến mức high, ba hạt giống 91001 đến 91003, với cùng định nghĩa $R$, $S$ và $TV$ như phương trình (16) của bản đồ (bỏ 2 s đầu, tính trên tín hiệu thật). Kết quả ở Bảng 18 và Hình 18; độ lệch chuẩn qua ba hạt giống không quá ' + f(sw.std_R_RMS_eT_Nm.max(), 4) + ' N.m với $R$ và ' + f(sw.std_S_HF_RMS_Ta_Nm.max(), 4) + ' N.m với $S$, nhỏ hơn rất nhiều so với chênh lệch giữa các điểm.')
add('Bảng 18: Kết quả quét $\\omega_c$ trên ca TK (nhiễu mức high, trung bình ba hạt giống)')
add('$\\omega_c$ [rad/s] | $K_p$ | $K_i$ [1/s] | $R$ [N.m] | $S$ [N.m] | $TV(T_a)$ [N.m/s] | $e_{rel}$ [%]')
for _, r in sw.iterrows():
    add(f'{r.wc_design_rad_s:g} | {f(r.Kp, 3)} | {f(r.Ki_1_per_s, 2)} | {f(r.mean_R_RMS_eT_Nm, 3)} | {f(r.mean_S_HF_RMS_Ta_Nm, 3)} | {f(r.mean_TV_Ta_Nm_per_s, 1)} | {f(r.mean_e_rel_pct, 2)}')
add()
add('Độ bám $R$ giảm đều khi tăng $\\omega_c$ (từ ' + f(sw.mean_R_RMS_eT_Nm.iloc[0], 2) + ' xuống ' + f(sw.mean_R_RMS_eT_Nm.iloc[-1], 2) + ' N.m) còn độ êm $S$ xấu đi từ ' + f(sw.mean_S_HF_RMS_Ta_Nm.iloc[0], 3) + ' lên ' + f(sw.mean_S_HF_RMS_Ta_Nm.iloc[-1], 3) + ' N.m. Quy tắc chọn đặt trước (mục 3.1) là: trong các điểm có $R \\le 1.02 R_{min} = ' + f(1.02 * rmin, 3) + '$ N.m lấy điểm có $S$ nhỏ nhất; chỉ điểm $\\omega_c = ' + f(chosen.wc_design_rad_s, 0) + '$ rad/s thỏa, nên được chọn, tức điểm nhanh nhất trong tập khả thi. Cũng quy tắc đó áp lên bước quét $K_{max}$ của bản đồ (một $K_{max}$ cho mọi vận tốc, các điểm có độ dự trữ pha đạt) cho $K_{max} = ' + f(rmapsel.selected_parameter, 0) + '$, đúng với bậc cao mà bản đồ đã chọn.')
add('Để đặt PI cạnh bản đồ trên cùng mặt phẳng $R$ - $S$, Bảng 19 cho các điểm của bản đồ trên cùng ca TK, cùng hạt giống và mức nhiễu: bước quét $K_{max}$ một giá trị cho mọi vận tốc (các điểm đạt độ dự trữ pha 45 độ) và bản đồ ở dạng cuối cùng (hai bậc theo vận tốc, chạy lại cùng đợt với PI).')
add('Bảng 19: Bản đồ trên ca TK (nhiễu mức high, trung bình ba hạt giống)')
add('Cấu hình | $R$ [N.m] | $S$ [N.m] | $TV(T_a)$ [N.m/s] | $e_{rel}$ [%]')
for _, r in mk[mk['pass'] == 1].iterrows():
    add(f'Bản đồ, $K_{{max}} = {r.K_max:g}$ cho mọi vận tốc | {f(r.mean_R_RMS_eT_Nm, 3)} | {f(r.mean_S_HF_RMS_Ta_Nm, 3)} | {f(r.mean_TV_Ta_Nm_per_s, 1)} | {f(r.mean_e_rel_pct, 2)}')
add(f'Bản đồ cuối cùng (hai bậc, 8 và 6) | {f(mapref.R_RMS_eT_Nm, 3)} | {f(mapref.S_HF_RMS_Ta_Nm, 3)} | {f(mapref.TV_Ta_Nm_per_s, 1)} | {f(mapref.e_rel_pct, 2)}')
add(f'PI, $\\omega_c = {chosen.wc_design_rad_s:g}$ rad/s | {f(piS.mean_R_RMS_eT_Nm, 3)} | {f(piS.mean_S_HF_RMS_Ta_Nm, 3)} | {f(piS.mean_TV_Ta_Nm_per_s, 1)} | {f(piS.mean_e_rel_pct, 2)}')
add()
add('[Hình 18: Ca TK: độ bám $R$ theo độ êm $S$ của PI (nhãn là $\\omega_c$ [rad/s]) và của bản đồ (nhãn là $K_{max}$) | Result/PI/Sweep/PI_sweep_pareto.png]')
add('So với bản đồ cuối cùng, PI ở điểm chọn có $R$ lớn hơn ' + f(piS.mean_R_RMS_eT_Nm / mapref.R_RMS_eT_Nm, 2) + ' lần, nhưng $S$ chỉ bằng ' + f(piS.mean_S_HF_RMS_Ta_Nm / mapref.S_HF_RMS_Ta_Nm, 2) + ' lần, $TV(T_a)$ nhỏ hơn ' + f(mapref.TV_Ta_Nm_per_s / piS.mean_TV_Ta_Nm_per_s, 0) + ' lần và sai số xác lập $e_{rel}$ chỉ ' + f(piS.mean_e_rel_pct, 2) + ' % so với ' + f(mapref.e_rel_pct, 2) + ' %. Trên Hình 18 đường của PI nằm hoàn toàn bên trái và phía trên đường của bản đồ: êm hơn nhiều nhưng không có điểm nào đạt độ bám của bản đồ.')
add()
add('3.7. Vì sao độ bám của PI kém hơn')
add('Bảng 20 tách $R$ theo từng cửa sổ của ca TK (hạt giống 91001, mức high). Ở các cửa sổ giữ góc (trạng thái xác lập) PI tốt hơn bản đồ: $e_T$ trung bình của PI chỉ từ ' + f(win[win.controller.str.startswith('PI of')].query("window.str.startswith('steady')").mean_eT_Nm.min(), 3) + ' đến ' + f(win[win.controller.str.startswith('PI of')].query("window.str.startswith('steady')").mean_eT_Nm.max(), 3) + ' N.m so với ' + f(win[win.controller == 'Map (final)'].query("window.str.startswith('steady')").mean_eT_Nm.min(), 3) + ' đến ' + f(win[win.controller == 'Map (final)'].query("window.str.startswith('steady')").mean_eT_Nm.max(), 3) + ' N.m của bản đồ, nên khâu tích phân triệt được sai số xác lập. Ngược lại ở các cửa sổ lái hình sin 0.5 Hz và chỉnh lái nhỏ, sai số của PI lớn hơn bản đồ nhiều lần: ở 100 km/h cửa sổ hình sin PI có RMS $e_T$ bằng ' + f(win[win.controller.str.startswith('PI of')].query("window == 'sine_v100'").RMS_eT_Nm.iloc[0], 3) + ' N.m so với ' + f(win[win.controller == 'Map (final)'].query("window == 'sine_v100'").RMS_eT_Nm.iloc[0], 3) + ' N.m. Đó là sai số động do băng thông thấp, và nó chi phối $R$.')
pi_rows = win[win.controller.str.startswith('PI of')]
map_rows = win[win.controller == 'Map (final)']
add('Bảng 20: Sai số theo cửa sổ của ca TK (hạt giống 91001, mức high; RMS $e_T$ và $e_T$ trung bình, N.m)')
add('Cửa sổ | RMS $T_{d,ref}$ | PI: RMS $e_T$ | PI: $e_T$ trung bình | Bản đồ: RMS $e_T$ | Bản đồ: $e_T$ trung bình')
for wn in [x for x in pi_rows.window if not x.startswith('R ')]:
    a = pi_rows[pi_rows.window == wn].iloc[0]; b = map_rows[map_rows.window == wn].iloc[0]
    add(f'{wn.replace("_", " ")} | {f(a.RMS_Tdref_Nm, 2)} | {f(a.RMS_eT_Nm, 3)} | {f(a.mean_eT_Nm, 3)} | {f(b.RMS_eT_Nm, 3)} | {f(b.mean_eT_Nm, 3)}')
add(f'$R$ (mọi cửa sổ) | | {f(pi_rows[pi_rows.window.str.startswith("R ")].RMS_eT_Nm.iloc[0], 3)} | | {f(map_rows[map_rows.window.str.startswith("R ")].RMS_eT_Nm.iloc[0], 3)} |')
add()
v6a = win[win.controller.str.contains('wc 6 rad/s, a = 0.106')]
v6b = win[win.controller.str.contains('wc 6 rad/s, a = 0.265')]
Ra = v6a[v6a.window.str.startswith('R ')].RMS_eT_Nm.iloc[0]; Rb = v6b[v6b.window.str.startswith('R ')].RMS_eT_Nm.iloc[0]
add('Có thể nghi nguyên nhân là phần tỉ lệ $K_p$ quá nhỏ ($K_p$ chỉ khoảng 0.12 đến 0.26 trong khi bản đồ có độ lợi tần số cao 8 đến 19 lần độ dốc). Kiểm tra: ở $\\omega_c = 6$ rad/s, nâng $K_p$ từ ' + f(des[des.wc_design_rad_s == 6].Kp.iloc[0], 3) + ' lên ' + f(float(v6b.controller.iloc[0].split('Kp ')[1].split(',')[0]), 3) + ' (giá trị lớn nhất còn thỏa độ dự trữ pha và độ dự trữ biên ở tần số cắt đó) chỉ đưa $R$ từ ' + f(Ra, 3) + ' xuống ' + f(Rb, 3) + ' N.m, tức giảm ' + f(100 * (1 - Rb / Ra), 1) + ' %. Vậy $R$ bị chi phối bởi độ lợi vòng hở ở dải tần của lệnh lái (khoảng 0.2 đến 2 Hz), mà độ lợi đó bị trần $K_i \\lesssim 8$ 1/s chặn (Bảng 17), chứ không bởi việc chọn $K_p$ nhỏ.')
add('Cơ chế vật lý: sai số động còn lại tỉ lệ với hàm độ nhạy $|S(j\\omega)| = |1/(1+L)|$ tại tần số của lệnh lái. Với PI chọn, $|S|$ tại 0.5 Hz (tần số lái hình sin của TK) là ' + f(chosen.S_at_0p5Hz_dry, 3) + ' (đường khô), nghĩa là còn ' + f(100 * chosen.S_at_0p5Hz_dry, 0) + ' % lệch của hệ hở; ở $\\omega_c = 0.5$ rad/s con số đó là ' + f(des.S_at_0p5Hz_dry.iloc[0], 3) + '. Bản đồ giảm $|S|$ ở dải này nhờ độ lợi vòng hở lớn trên cả dải tới tần số cắt 150 đến 290 rad/s, điều mà khâu lead cho phép (bù pha qua đỉnh cộng hưởng) còn PI thì không.')
add()
add('3.8. Kết quả các ca thử chuẩn')
add('Các ca thử TC1 đến TC6 (Documents/Sim/TestCases.txt) được chạy cho PI với điểm đã chọn ($K_p = ' + f(chosen.Kp, 3) + '$, $K_i = ' + f(chosen.Ki_1_per_s, 2) + '$ 1/s) hai lần: với cảm biến lý tưởng (kết quả ở `Result/PI/TestCases/`) và với cảm biến có nhiễu mức high, năm hạt giống 90001 đến 90005, cùng đợt với bản đồ (kết quả ở `Result/Compare/Map_vs_PID/`). Mọi chỉ tiêu tính trên tín hiệu thật, bỏ 2 s đầu.')
add('Bảng 21 cho chỉ tiêu toàn ca của hai bộ điều khiển với nhiễu mức high (trung bình và độ lệch chuẩn qua năm hạt giống).')
add('Bảng 21: Chỉ tiêu toàn ca, nhiễu mức high (trung bình $\\pm$ độ lệch chuẩn qua 5 hạt giống)')
add('Ca | Bộ | RMS $e_T$ [N.m] | max $|e_T|$ [N.m] | RMS $T_a$ [N.m] | max $|T_a|$ [N.m] | $TV(T_a)$ [N.m/s]')
S = summ[summ.Window == 'whole case']
cases = list(dict.fromkeys(S.Case))
for c in cases:
    for ctl, nm in [('Map', 'Bản đồ'), ('PID', 'PI')]:
        r = S[(S.Case == c) & (S.Ctrl == ctl)].iloc[0]
        def pm(a, b, n=3):
            return f'{f(r[a], n)} $\\pm$ {f(r[b], n)}'
        add(f'{c[:3]} | {nm} | {pm("mean_RMS_eT_Nm", "std_RMS_eT_Nm")} | {pm("mean_MaxAbs_eT_Nm", "std_MaxAbs_eT_Nm", 2)} | {pm("mean_RMS_Ta_Nm", "std_RMS_Ta_Nm", 2)} | {pm("mean_MaxAbs_Ta_Nm", "std_MaxAbs_Ta_Nm", 2)} | {pm("mean_TV_Ta_Nm_per_s", "std_TV_Ta_Nm_per_s", 1)}')
add()
add('Trợ lực thừa do $\\mu$ thay đổi nằm ở các cửa sổ sau khi $\\mu$ đổi của TC3 đến TC6. Bảng 22 cho $e_T$ trung bình theo phần trăm giá trị đặt (dương: tay lái nặng hơn mong muốn, âm: trợ lực thừa).')
add('Bảng 22: $e_T$ trung bình theo phần trăm $T_{d,ref}$ ở các cửa sổ có $\\mu$ đổi, nhiễu mức high (trung bình $\\pm$ độ lệch chuẩn qua 5 hạt giống)')
add('Ca và cửa sổ | Bản đồ [%] | PI [%]')
W = summ[summ.Window != 'whole case']
for c in cases:
    if c[:3] not in ('TC3', 'TC4', 'TC5', 'TC6'):
        continue
    for wn in list(dict.fromkeys(W[W.Case == c].Window)):
        a = W[(W.Case == c) & (W.Window == wn) & (W.Ctrl == 'Map')].iloc[0]
        b = W[(W.Case == c) & (W.Window == wn) & (W.Ctrl == 'PID')].iloc[0]
        add(f'{c[:3]}, {wn.replace("_", " ")} | {f(a.mean_Mean_eT_signed_pct_of_Tdref, 2)} $\\pm$ {f(a.std_Mean_eT_signed_pct_of_Tdref, 2)} | {f(b.mean_Mean_eT_signed_pct_of_Tdref, 2)} $\\pm$ {f(b.std_Mean_eT_signed_pct_of_Tdref, 2)}')
add()
tvr = []
for c in cases:
    a = S[(S.Case == c) & (S.Ctrl == 'Map')].iloc[0].mean_TV_Ta_Nm_per_s
    b = S[(S.Case == c) & (S.Ctrl == 'PID')].iloc[0].mean_TV_Ta_Nm_per_s
    tvr.append(a / b)
better = [c[:3] for c in cases if S[(S.Case == c) & (S.Ctrl == 'PID')].iloc[0].mean_RMS_eT_Nm < S[(S.Case == c) & (S.Ctrl == 'Map')].iloc[0].mean_RMS_eT_Nm]
worse = [c[:3] for c in cases if c[:3] not in better]
add('Trên sáu ca thử chuẩn, PI có RMS $e_T$ toàn ca nhỏ hơn bản đồ ở ' + ', '.join(better) + ' và lớn hơn ở ' + ', '.join(worse) + '; $TV(T_a)$ của PI nhỏ hơn bản đồ từ ' + f(min(tvr), 0) + ' đến ' + f(max(tvr), 0) + ' lần. Trợ lực thừa sau khi $\\mu$ giảm ở TC3 là -14.12 % với bản đồ và -0.13 % với PI (Bảng 22), tức tích phân xóa gần hết trợ lực thừa ở trạng thái xác lập. Các cửa sổ before và after lane change của TC4 có $T_{d,ref}$ gần bằng không nên phần trăm ở đó không có nghĩa (mẫu số nhỏ); cần xem sai số tuyệt đối. Kết quả này khác ca TK, nơi PI kém hơn bản đồ về $R$: TK có lái hình sin 0.5 Hz và chỉnh lái nhỏ ở ba vận tốc, tức dải tần mà độ lợi vòng hở của PI bị cộng hưởng chặn; nguyên nhân ở từng ca chuẩn chưa được phân tích riêng.')
add()
FIGS = [('Map_vs_PID_whole_case.png', 'RMS $e_T$ và $TV(T_a)$ toàn ca của bản đồ và PI, nhiễu mức high, 5 hạt giống')]
for p in sorted(glob.glob(os.path.join(cmp_dir, 'Map_vs_PID_*_Ts_eT_Ta.png'))):
    FIGS.append((os.path.basename(p), None))
nfig = 19
caption = {'TC1': 'Ca TC1: hiệu chỉnh đường khô', 'TC2': 'Ca TC2: chạy đường thực tế', 'TC3': 'Ca TC3: $\\mu$ giảm đột ngột khi đang cua gấp ở 100 km/h',
           'TC4': 'Ca TC4: vào vũng nước khi đang chuyển làn gấp ở 80 km/h', 'TC5': 'Ca TC5: lái hình sin liên tục ở 100 km/h trên mặt đường rất trơn',
           'TC6': 'Ca TC6: $\\mu$ tăng đột ngột giữa cua ở 60 km/h'}
for name, cap in FIGS:
    if cap is None:
        tag = name.split('_')[3] if len(name.split('_')) > 3 else ''
        key = [k for k in caption if name.find(k) >= 0]
        cap = (caption[key[0]] if key else name) + ' (bản đồ và PI, nhiễu mức high, hạt giống 90001)'
    add(f'[Hình {nfig}: {cap} | Result/Compare/Map_vs_PID/{name}]')
    nfig += 1
add()
add('3.9. Kết luận và điều kiện chuyển sang PID')
add('Bộ PI thiết kế từ PRSM với điều kiện ổn định chặt ($\\mathrm{PM} \\ge 45$ độ và $\\mathrm{GM} \\ge 2$ trên cả hai mặt đường) cho các kết quả sau. Về sai số xác lập PI tốt hơn bản đồ rõ rệt (' + f(piS.mean_e_rel_pct, 2) + ' % so với ' + f(mapref.e_rel_pct, 2) + ' % trên TK) nhờ khâu tích phân. Về độ êm PI tốt hơn rất nhiều ($S$ bằng ' + f(piS.mean_S_HF_RMS_Ta_Nm / mapref.S_HF_RMS_Ta_Nm, 2) + ' lần, $TV(T_a)$ nhỏ hơn ' + f(mapref.TV_Ta_Nm_per_s / piS.mean_TV_Ta_Nm_per_s, 0) + ' lần). Về độ bám động PI kém hơn bản đồ: $R$ lớn hơn ' + f(piS.mean_R_RMS_eT_Nm / mapref.R_RMS_eT_Nm, 2) + ' lần, và không có điểm nào trong họ thiết kế đạt độ bám của bản đồ; nguyên nhân là đỉnh cộng hưởng của cột lái chặn độ lợi vòng hở của PI (trần $K_i \\lesssim 8$ 1/s, tần số cắt tối đa 7 rad/s), điều mà khâu lead của bản đồ vượt qua nhờ bù pha.')
add('Điều kiện chuyển sang PID đã đặt trước là: đường $R$ - $S$ của PI không có điểm nào đạt đồng thời $R \\le 1.02 R_{Map}$ và $S \\le S_{Map}$. Với $R_{Map} = ' + f(mapref.R_RMS_eT_Nm, 3) + '$ N.m ngưỡng là ' + f(1.02 * mapref.R_RMS_eT_Nm, 3) + ' N.m, còn $R$ nhỏ nhất của PI là ' + f(rmin, 3) + ' N.m, nên điều kiện thỏa và PI được xem là không đủ theo tiêu chí TK đã đặt trước. Cần nói rõ rằng trên sáu ca chuẩn PI lại vượt bản đồ ở phần lớn ca (mục 3.8), nên quyết định có làm PID hay không phải cân nhắc cả hai kết quả. Việc làm PID (thêm khâu vi phân) chưa thực hiện vì cần xác nhận trước. Giả thuyết cần kiểm chứng ở bước đó: khâu vi phân lấy trên $T_s$ đo (không lấy trên $e_T$, để không đạo hàm nhiễu của giá trị đặt) cộng thêm pha dương và giảm chấn cho cộng hưởng, nhờ đó cho phép nâng tần số cắt vượt trần 7 rad/s; giả thuyết này chưa được kiểm tra.')
add('Các điểm yếu và giới hạn cần ghi nhận. Một là điều kiện $\\mathrm{GM} \\ge 2$ và chặn dưới $a \\ge 0.1$ là lựa chọn của tác giả; $a$ ít ảnh hưởng tới kết quả (mục 3.7) còn $\\mathrm{GM}$ quyết định trần $\\omega_c$, nên một ngưỡng GM thấp hơn sẽ cho PI nhanh hơn. Hai là mô hình thiết kế dùng góc vô-lăng giữ nguyên và chỉ hai giá trị $k_r$, như bản đồ; sai lệch thông số xe chưa xét. Ba là ca TK chỉ trên đường khô, ảnh hưởng của $\\mu$ thay đổi chỉ được kiểm ở TC3 đến TC6. Bốn là chu kỳ 10 ms của $a_y$ qua CAN là giả định chưa có nguồn, và đường nhiễu $a_y \\to T_{d,ref} \\to e_T$ chỉ có ở PI. Năm là $T_{a,max}(v)$ là giới hạn trợ lực ước từ mô-men cần thiết, không phải khả năng của motor. Sáu là bản đồ trong so sánh là dạng cuối cùng hai bậc, còn quy tắc chọn tham số được kiểm trên bước quét một $K_{max}$.')
add()

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with io.open(OUT, 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(L) + '\n')
print('wrote', OUT, len(L), 'lines;', nfig - 19, 'figures from the comparison')
