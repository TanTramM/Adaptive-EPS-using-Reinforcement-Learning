# -*- coding: utf-8 -*-
"""Generate Documents/Thesis/map.txt from the Map design results (tables are read from the csv files, never typed)."""
import json
import os
import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CTRL = 'Map'
RC = os.path.join(ROOT, 'Result', 'Controllers', CTRL)
D = os.path.join(RC, 'Design')
TC = os.path.join(RC, 'TestCases')
TS = 0   # local noise seed of the Map: used for the design (TK) and for its own TC run (range 0-9999)
TN = os.path.join(RC, 'TestCases_noise', 'seed_%05d' % TS)
J = json.load(open(os.path.join(ROOT, 'Model', 'data', 'map.json'), encoding='utf-8'))
d = J['design']

stab = pd.read_csv(os.path.join(D, CTRL + '_stability_by_speed_K.csv'))
kacc = pd.read_csv(os.path.join(D, CTRL + '_K_for_accuracy.csv'))
par = pd.read_csv(os.path.join(D, CTRL + '_pareto.csv'))
dry = pd.read_csv(os.path.join(D, CTRL + '_dry_error_by_speed.csv'))
summ = pd.read_csv(os.path.join(D, CTRL + '_design_summary.csv'))
cal = pd.read_csv(os.path.join(D, CTRL + '_calibration_points.csv'))
chk = pd.read_csv(os.path.join(D, CTRL + '_closed_loop_check.csv'))
mi = pd.read_csv(os.path.join(TC, CTRL + '_test_case_metrics.csv'))
mn = pd.read_csv(os.path.join(TN, CTRL + '_test_case_metrics.csv'))
bb = pd.read_csv(os.path.join(D, CTRL + '_bangbang_by_K.csv'))
terel = pd.read_csv(os.path.join(D, CTRL + '_TK_erel.csv'))

K = d['Kmax']
z, p = d['lead']['z'], d['lead']['p']
Kstab = d['Kstab']
nat = kacc[kacc.v_kmh != 25]
natmax = kacc.natural_slope_max_0p1_0p3g.max()
SIG = 0.0104
rel = lambda p: os.path.relpath(p, ROOT).replace('\\', '/')


def noise_std(k, z, p):
    wm = 2 * np.pi * 100
    wN = np.pi / 1e-3
    w = np.linspace(0, wN, 20000)
    H = (1j * w / z + 1) / (1j * w / p + 1)
    F = k * H * (wm / (1j * w + wm))
    return float(np.sqrt(np.trapz(np.abs(F) ** 2, w) / wN)) * SIG


NOISE = noise_std(K, z, p)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(bb.K, 100 * bb.f_sat_delta, 'o-', color='#2a78d6', label='tăng tỉ lệ mẫu chạm giới hạn T_a,max do nhiễu')
ax.axhline(1.0, color='k', ls='--', lw=1); ax.text(3, 1.15, 'ngưỡng 1 %', fontsize=9)
ax.axvspan(6.75, 7.0, color='#1baf7a', alpha=0.25, label='miền K còn lại (độ chính xác từ 40 km/h và bang-bang)')
ax.set_yscale('log'); ax.set_xlabel('K'); ax.set_ylabel('chênh tỉ lệ mẫu chạm giới hạn, có nhiễu trừ lý tưởng [%]'); ax.grid(True, which='both', alpha=0.3); ax.legend(loc='upper left', fontsize=8)
ax.set_title('Cổng không-bang-bang của bản đồ theo K (ca TK, seed 00000)')
fig.tight_layout(); fig.savefig(os.path.join(D, CTRL + '_bangbang_by_K.png'), dpi=130); plt.close(fig)

L = []
def P(s=''):
    L.append(s)
def EQ(n, ascii_, latex):
    P('  (%d)  %s' % (n, ascii_)); P('  [ %s ]' % latex); P()
def TAB(title, rows):
    P(title)
    for r in rows: P(' | '.join(str(x) for x in r))
    P()
def H1(t):
    P('-' * 120); P(t); P('-' * 120)
def f(x, n=2):
    return ('%.' + str(n) + 'f') % x
def FIG(n, cap, path):
    P('[Hình %d: %s | %s]' % (n, cap, rel(path))); P()

# data-dependent claims are asserted, not assumed
VACC = 40
dry40 = dry[dry.v_kmh >= VACC].max_dry_err_pct_0p1_0p3g.max()
assert dry40 <= 3, 'dry-road accuracy condition not met at >= 40 km/h'
k25 = float(kacc[kacc.v_kmh == 25].Kmin_for_accuracy.iloc[0]); assert k25 > Kstab
KBB = float(bb[bb.f_sat_delta <= 0.01].K.max())
def kbb(th): return float(bb[bb.f_sat_delta <= th].K.max())

P('=' * 120)
P('BỘ ĐIỀU KHIỂN BẢN ĐỒ TRỢ LỰC TRUYỀN THỐNG (MAP)')
P('=' * 120)
P('Chương này thiết kế bộ điều khiển bản đồ trợ lực, bộ điều khiển truyền thống dùng làm chuẩn so sánh cho các bộ điều khiển đề xuất ở các chương sau. Toàn bộ thiết kế chỉ dựa vào môi trường mô phỏng đã dựng ở các chương trước (đối tượng điều khiển, giá trị đặt, cảm biến, motor) và không dùng kết quả của bất kỳ thiết kế nào khác: độ dốc lớn nhất và khâu bù được tính từ đầu. Mục 1 nêu vai trò và cấu trúc. Mục 2 dựng bản đồ từ các điểm hiệu chỉnh trên đường khô. Mục 3 phân tích ổn định và chọn khâu bù. Mục 4 chọn độ dốc lớn nhất bằng cách cân bằng đáp ứng và khuếch đại nhiễu. Mục 5 kiểm chứng trên sáu ca thử chuẩn. Mục 6 nêu hạn chế và các lựa chọn của tác giả. Quy tắc chọn tham số là quy tắc chung của mọi bộ điều khiển trong luận văn (cùng các cổng cứng, cùng cách chọn điểm), không phải quy tắc riêng của bản đồ.')
P()

# ------------------------------------------------------------------ 1
H1('1. Vai trò và cấu trúc')
P('1.1. Vai trò')
P('Theo [4], hệ trợ lực lái điện truyền thống chỉ xét vận tốc xe và mô-men tay lái; khi hệ số bám giảm, mô-men cản giảm nhưng bộ điều khiển vẫn cấp trợ lực như cũ nên trợ lực quá lớn, làm giảm cảm giác đường của tài xế. Bản đồ trợ lực là dạng điều khiển truyền thống đó: nó được hiệu chỉnh trên đường khô ($\\mu = 0.8$), nơi mô-men cản lớn nhất, để tay lái nhẹ trong điều kiện nặng nhất. Vì vậy bản đồ là chuẩn so sánh thích hợp: nó phải có đúng điểm yếu này, trợ lực thừa khi $\\mu$ giảm, và không được bị làm yếu thêm ở khía cạnh khác, chẳng hạn hiệu chỉnh kém trên đường khô hay tự dao động, nếu không phần cải thiện của bộ điều khiển đề xuất sẽ bị thổi phồng. Do đó chương này đặt cho bản đồ các điều kiện cứng chung của mọi bộ điều khiển (vòng kín ổn định với độ dự trữ pha và độ dự trữ độ lợi đủ lớn, lệnh không nhảy liên tục tới giới hạn vì nhiễu) cộng điều kiện riêng của bản đồ là bám đúng giá trị đặt trên đường khô trong dải đã hiệu chỉnh.')
P('1.2. Cấu trúc bộ điều khiển')
P('Theo [1] (mục III.A), bộ điều khiển gồm bản đồ mô-men, quan hệ một-một giữa mô-men cảm biến và mô-men trợ lực có vùng chết dưới một ngưỡng $\\tau_{s0}$, nối tiếp một khâu bù ổn định đặt sau bản đồ (phương trình (15) và (16) của [1]). Bộ điều khiển ở đây chỉ đọc hai tín hiệu đo được là mô-men cảm biến $T_s$ và vận tốc $v$, lấy mẫu với chu kỳ $T_{ctl} = 1$ ms (bằng chu kỳ cập nhật của $T_s$ trong mô hình cảm biến); không đọc $\\mu$, không tính sai số $e_T$ và không có khâu tích phân. Bản đồ cho trợ lực theo trị tuyệt đối của mô-men cảm biến, nhân với dấu để trợ lực luôn cùng chiều mô-men tay; $M$ là bảng hai chiều theo vận tốc và $|T_s|$, nội suy tuyến tính:')
P()
EQ(1, 'T_a,map = sgn(T_s) * M(v, |T_s|)', 'T_{a,map}=\\mathrm{sgn}(T_s)\\,M(v,|T_s|)')
P('Khâu bù là khâu sớm pha (lead): bộ lọc có độ lợi bằng một ở tần số thấp và làm tín hiệu sớm pha trong dải tần giữa điểm không $z$ và điểm cực $p$. Bản đồ dùng một độ dốc lớn nhất $K_{max}$ và một khâu bù chung cho mọi vận tốc; $H(z)$ là dạng rời rạc của $H(s)$ theo phép biến đổi song tuyến tính (Tustin) với chu kỳ $T_{ctl}$.')
P()
EQ(2, 'T_a,c = H(z) * T_a,map,   H(s) = (s/z + 1) / (s/p + 1)', 'T_{a,c}=H(z)\\,T_{a,map},\\qquad H(s)=\\dfrac{s/z+1}{s/p+1}')
P('Lệnh $T_{a,c}$ đi vào khối motor của môi trường mô phỏng, gồm giới hạn trợ lực $T_{a,max}(v)$ (chương giá trị đặt) và một khâu trễ bậc nhất $G_m(s) = \\omega_m/(s + \\omega_m)$ với $\\omega_m = 2\\pi \\cdot 100$ rad/s = 628 rad/s, hằng số thời gian 1.59 ms, theo phương trình (10) và Bảng III của [1]. Bộ điều khiển không tự chặn lệnh. Vì $H$ và $G_m$ đều có độ lợi bằng một ở tần số không, ở trạng thái xác lập $T_a$ bằng giá trị bản đồ (khi chưa chạm giới hạn): độ chính xác trên đường khô do hàm $M$ quyết định (mục 2), còn khâu bù chỉ quyết định ổn định và độ êm khi tín hiệu thay đổi (mục 3).')

# ------------------------------------------------------------------ 2
H1('2. Dựng bản đồ')
P('2.1. Điểm hiệu chỉnh trên đường khô')
P('Ở trạng thái xác lập, mô-men cản $T_r$ do mô-men trợ lực $T_a$ và mô-men cảm biến $T_s$ cân bằng: $T_s = T_r - T_a$ (phương trình mô-men của trụ lái khi tốc độ góc bằng không). Muốn mô-men cảm biến bằng giá trị đặt trên đường khô, tại mỗi vận tốc và mỗi gia tốc ngang cần cấp trợ lực bằng mô-men cản trừ giá trị đặt, đúng cách [5] (mục III.D, Bảng 5) xác định trợ lực mà hệ cần cung cấp bằng mô-men vô-lăng khi chưa có trợ lực trừ mô-men vô-lăng lý tưởng:')
P()
EQ(3, 'T_s,cal = T_d,ref(v, a_y),   T_a,cal = T_r(v, a_y, 0.8) - T_d,ref(v, a_y)', 'T_{s,cal}=T_{d,ref}(v,a_y),\\qquad T_{a,cal}=T_r(v,a_y,0.8)-T_{d,ref}(v,a_y)')
P('Khác [5], nơi mô-men vô-lăng khi chưa có trợ lực lấy từ mô phỏng của một xe khác, ở đây $T_r$ tính bằng cách giải trạng thái xác lập của chính đối tượng điều khiển của luận văn: với vận tốc $v$ và gia tốc ngang $a_y$ cho trước, ba ẩn góc trượt thân xe $\\beta$, tốc độ quay thân xe $\\gamma$ và góc bánh trước $\\delta_f$ thỏa ba phương trình của mô hình hai bậc tự do (đạo hàm của $\\beta$ và $\\gamma$ bằng không, $a_y$ bằng giá trị đang quét) với lực lốp theo công thức Magic Formula, rồi $T_r$ tính từ lực bên bánh trước và cánh tay đòn kéo lệch. Với mỗi vận tốc từ 20 km/h đến 100 km/h, bước 5 km/h, gia tốc ngang được quét từ 0.1 g (hàng nhỏ nhất của Bảng 4 của [5], dưới mức đó không có số liệu) tới giá trị nhỏ hơn trong hai giá trị 0.4 g (hàng lớn nhất của bảng) và gia tốc ngang lớn nhất mà đối tượng điều khiển đạt được ở $\\mu = 0.8$, bước 0.005 g; được %d điểm hiệu chỉnh. Giá trị đặt $T_{s,cal}$ tra từ bảng giá trị đặt (nội suy tuyến tính như khối giá trị đặt).' % len(cal))
P('2.2. Đường cong bản đồ và giới hạn độ dốc')
P('Đường cong $M(v, |T_s|)$ tại mỗi vận tốc gồm bốn đoạn. Thứ nhất, vùng chết: $M = 0$ khi $|T_s| \\le T_{s0}$. Trong [1] vùng chết dùng để hệ không phản ứng quá nhạy với mô-men tay lái; ở đây còn có lý do thứ hai là nhiễu cảm biến: nhiễu và lượng tử hóa của $T_s$ có độ lệch chuẩn %s N.m (một bước phân giải 0.01 N.m cộng nhiễu một bước, theo mô hình cảm biến), nên nếu bản đồ trợ lực ngay từ $T_s = 0$ thì khi xe đi thẳng nhiễu này biến thành lệnh trợ lực giật liên tục. Chọn $T_{s0} = 0.3$ N.m, bằng khoảng 29 lần độ lệch chuẩn nhiễu và còn xa dưới mô-men đặt nhỏ nhất của dải hiệu chỉnh (1.0 N.m ở 20 km/h và 0.1 g), nên vùng chết không lấn vào vùng có số liệu; đây là Tự chọn(1). Thứ hai, đoạn nối từ $(T_{s0}, 0)$ tới điểm hiệu chỉnh đầu tiên (0.1 g), vì dưới 0.1 g không có số liệu gốc. Thứ ba, đoạn bám các điểm hiệu chỉnh có giới hạn độ dốc. Thứ tư, bão hòa: trên điểm hiệu chỉnh cuối cùng $M$ giữ nguyên giá trị cuối.' % f(SIG, 4))
P('Độ dốc của bản đồ là lượng trợ lực tăng thêm khi mô-men cảm biến tăng một đơn vị. Trong vòng kín, trợ lực tăng làm mô-men cảm biến giảm, nên độ dốc này chính là độ lợi của vòng phản hồi qua $T_s$: dốc càng lớn thì bộ điều khiển càng nhạy, càng khó ổn định và càng khuếch đại nhiễu cảm biến. [1] cũng lấy độ dốc lớn nhất của bản đồ làm trường hợp xấu nhất khi xét ổn định, vì khi bản đồ được xấp xỉ bằng một hằng số thì hằng số lớn nhất ứng với độ lợi vòng lớn nhất. Độ dốc tự nhiên của đường cong hiệu chỉnh, tức độ dốc cần có để đi qua mọi điểm, là:')
P()
EQ(4, 'dT_a/dT_s (tai diem k) = (T_a,cal,k - T_a,cal,k-1) / (T_s,cal,k - T_s,cal,k-1)', '\\left.\\dfrac{dT_a}{dT_s}\\right|_k=\\dfrac{T_{a,cal,k}-T_{a,cal,k-1}}{T_{s,cal,k}-T_{s,cal,k-1}}')
P('Hình 1 vẽ độ dốc tự nhiên theo gia tốc ngang. Trong vùng lái thường ngày, 0.1 g đến 0.3 g, độ dốc lớn nhất theo vận tốc dao động từ %s (%d km/h) tới %s (%d km/h), và là %s ở 20 km/h; trên 0.3 g, nơi $T_{d,ref}$ gần như không tăng nữa trong khi $T_r$ vẫn tăng, độ dốc lên tới hàng chục và hàng trăm. Vì độ dốc cần có vượt xa mức một bộ điều khiển ổn định được (mục 3), mỗi điểm của bản đồ bị chặn để độ dốc so với điểm trước không vượt giới hạn $K_{max}$:' % (f(nat.natural_slope_max_0p1_0p3g.min(), 1), int(nat.v_kmh.iloc[nat.natural_slope_max_0p1_0p3g.values.argmin()]), f(natmax, 1), int(kacc.v_kmh.iloc[kacc.natural_slope_max_0p1_0p3g.values.argmax()]), f(kacc[kacc.v_kmh == 20].natural_slope_max_0p1_0p3g.iloc[0], 1)))
P()
EQ(5, 'M_k = min(T_a,cal,k, M_(k-1) + K_max*(T_s,k - T_s,k-1))', 'M_k=\\min\\big(T_{a,cal,k},\\;M_{k-1}+K_{max}(T_{s,k}-T_{s,k-1})\\big)')
P('Nơi độ dốc tự nhiên nhỏ hơn $K_{max}$ thì bản đồ đi đúng qua các điểm hiệu chỉnh; nơi vượt thì bản đồ nằm thấp hơn điểm hiệu chỉnh và sai lệch đó cộng dồn theo $T_s$. Đây là chỗ bản đồ chấp nhận sai số xác lập để đổi lấy ổn định và độ êm; mức sai số được đo ở mục 2.3. $K_{max}$ chưa biết: giá trị của nó là kết quả của mục 3 và mục 4.')
FIG(1, 'Độ dốc tự nhiên dT_a/dT_s của các điểm hiệu chỉnh theo gia tốc ngang, cùng giới hạn ổn định K_stab và giá trị K_max đã chọn', os.path.join(D, CTRL + '_natural_slope.png'))
P('2.3. Sai số xác lập trên đường khô')
P('Với một bản đồ đã dựng, vòng kín dừng ở điểm cân bằng thỏa $T_s = T_r - M(T_s)$ (bản đồ đơn điệu nên nghiệm duy nhất), khi khâu bù không còn tác dụng. Sai số xác lập là chênh lệch giữa nghiệm đó và giá trị đặt:')
P()
EQ(6, 'T_s = T_r(v, a_y, 0.8) - M(v, T_s),   e_T = T_s - T_d,ref,   e_T% = 100*e_T/T_d,ref', 'T_s=T_r(v,a_y,0.8)-M(v,T_s),\\qquad e_T=T_s-T_{d,ref},\\qquad e_T\\%=100\\,\\dfrac{e_T}{T_{d,ref}}')
P('Điều kiện cứng về độ chính xác của bản đồ: sai số xác lập không quá 3% giá trị đặt trên toàn dải 0.1 g đến 0.3 g, ở mọi vận tốc từ 40 km/h trở lên (Tự chọn(2)). Ngưỡng 3% là mức tay lái lệch rất nhỏ so với giá trị đặt; dải 0.1 g đến 0.3 g là vùng lái thường ngày, trên 0.3 g là vùng khẩn cấp ngắn; điều kiện không áp dụng cho 20 km/h đến 35 km/h vì lý do ở mục 4.4 (do người dùng quyết định ngày 2026-10-08 sau khi thấy xung đột với điều kiện không bang-bang). Với mỗi vận tốc, giá trị $K$ nhỏ nhất đạt điều kiện này gọi là $K_{acc}(v)$ (Bảng 1, tìm với bước 0.25, tính cho cả các vận tốc không áp dụng điều kiện để thấy mức chênh).')
rows = [['v [km/h]', 'K_acc(v)', 'sai số lớn nhất tại K_acc [%]', 'độ dốc tự nhiên lớn nhất 0.1-0.3 g']]
for _, r in kacc.iterrows():
    rows.append([int(r.v_kmh), f(r.Kmin_for_accuracy, 2), f(r.max_err_pct_at_Kmin, 2), f(r.natural_slope_max_0p1_0p3g, 1)])
TAB('Bảng 1: Độ dốc K nhỏ nhất để sai số xác lập trên đường khô không quá 3% trong 0.1-0.3 g', rows)
FIG(2, 'Giới hạn độ chính xác K_acc(v), độ dốc tự nhiên lớn nhất, giới hạn ổn định K_stab và giá trị K_max đã chọn theo vận tốc', os.path.join(D, CTRL + '_K_accuracy_stability.png'))

# ------------------------------------------------------------------ 3
H1('3. Ổn định và khâu bù')
P('3.1. Mô hình tuyến tính của đối tượng điều khiển')
P('Ổn định xét trên vòng tuyến tính hóa quanh một điểm làm việc: xe quay vòng ổn định với vận tốc $v$, gia tốc ngang $a_y$ và hệ số bám $\\mu$, góc vô-lăng $\\theta_1$ giữ không đổi (tài xế giữ góc). Trạng thái là góc và tốc độ góc trụ lái $\\theta_2$, $\\dot\\theta_2$ cùng $\\beta$ và $\\gamma$; đầu vào là mô-men trợ lực $T_a$, đầu ra là mô-men cảm biến $T_s = K(\\theta_1 - \\theta_2)$ với $K$ là độ cứng thanh xoắn. Phương trình trụ lái và thân xe của mô hình:')
P()
EQ(7, 'J_col*theta2_ddot = T_a - T_r + K*(theta1 - theta2) - C_col*theta2_dot;  beta_dot = (F_yf+F_yr)/(m*v) - gamma;  gamma_dot = (l_f*F_yf - l_r*F_yr)/Iz', 'J_{col}\\ddot\\theta_2=T_a-T_r+K(\\theta_1-\\theta_2)-C_{col}\\dot\\theta_2,\\quad \\dot\\beta=\\dfrac{F_{yf}+F_{yr}}{mv}-\\gamma,\\quad \\dot\\gamma=\\dfrac{l_fF_{yf}-l_rF_{yr}}{I_z}')
P('Đạo hàm riêng theo các trạng thái được lấy bằng sai phân trung tâm của chính các phương trình trên tại điểm cân bằng (trạng thái xác lập của mục 2.1). Ma sát Coulomb của trụ lái $T_f\\tanh(c\\dot\\theta_2)$ không được tuyến tính hóa: độ dốc của nó khi đứng yên rất lớn và chỉ thêm tắt dần khi trụ lái chuyển động, nên mô hình tuyến tính chỉ giữ ma sát nhớt $C_{col}$, là trường hợp bất lợi cho ổn định (Tự chọn(3)). Kết quả: đối tượng từ $T_a$ tới $T_s$ có độ lợi một chiều bằng $-0.99$ ở 20 km/h tới $-0.81$ ở 100 km/h (thêm trợ lực làm giảm $T_s$ với hệ số gần một, như phương trình cân bằng ở mục 2.1), một cặp cực dao động nhẹ tắt $-6.8 \\pm j38.3$ rad/s ở 60 km/h (tần số riêng của trụ lái và thanh xoắn $\\sqrt{K/J_{col}} = 36.1$ rad/s, hệ số tắt dần khoảng 0.18) và một cặp cực chậm của thân xe. Khi $v$, $a_y$ và $\\mu$ thay đổi trên các điểm đã xét, tần số của cặp cực dao động đổi dưới 5% (từ 37.6 rad/s đến 39.1 rad/s) và phần thực của nó nằm giữa $-8.2$ rad/s và $-6.3$ rad/s: ổn định của vòng bị chi phối bởi trụ lái, không bởi thân xe.')
P('3.2. Hàm truyền vòng hở và điều kiện cứng')
P('Gọi $k$ là độ dốc của bản đồ tại điểm làm việc, $0 < k \\le K_{max}$ (bản đồ đi qua mọi độ dốc từ không tới $K_{max}$ khi mô-men tay lái thay đổi). Hàm truyền vòng hở, với dấu trừ vì thêm trợ lực làm $T_s$ giảm, là:')
P()
EQ(8, 'L(s) = -k * H(s) * Gm(s) * exp(-s*T_d) * G(s),   T_d = 1 ms', 'L(s)=-k\\,H(s)\\,G_m(s)\\,e^{-sT_d}\\,G(s)')
P('trong đó $G(s)$ là hàm truyền tuyến tính hóa từ $T_a$ tới $T_s$, $G_m$ là khâu motor và $T_d = 1$ ms là trễ tương đương của việc lấy mẫu: cảm biến $T_s$ cập nhật mỗi 1 ms và bộ điều khiển lấy mẫu mỗi 1 ms, nên lấy tổng trễ bảo thủ bằng một chu kỳ (Tự chọn(4)). Phép Tustin của khâu sớm pha chỉ làm lệch khâu này ở tần số gần $1/T_{ctl}$, đã được trễ trên bao phủ. Điều kiện cứng về ổn định: với mọi điểm làm việc đã xét và mọi độ dốc $k \\in \\{0.25, 0.5, 0.75, 1\\}K_{max}$, vòng kín ổn định và độ dự trữ pha (PM, phase margin: góc pha còn thiếu để tới $-180°$ tại mọi tần số mà $|L| = 1$) không nhỏ hơn 45° (Tự chọn(5): 45° theo [1], nơi nêu hệ cần độ dự trữ pha lớn hơn 45° để ổn định bền vững). Độ dự trữ độ lợi (GM, gain margin: hệ số mà độ lợi vòng còn có thể tăng trước khi mất ổn định) không nhỏ hơn 2 tại mọi tần số mà pha bằng $-180°$ (điều kiện chung của mọi bộ điều khiển). Ổn định được xét bằng tiêu chuẩn Nyquist trên vòng hở vốn ổn định. Các điểm làm việc xét ở mỗi vận tốc là $(a_y, \\mu)$ = (0, 0.8), (0.3 g, 0.8), (0, 0.2) và (0.15 g, 0.2).')
P('3.3. Tìm khâu bù')
P('Với mỗi $K$, khâu sớm pha $(z, p)$ được tìm trên lưới 36 giá trị $z$ từ 8 rad/s đến 400 rad/s và 40 giá trị tỉ số $p/z$ từ 1.5 đến 120, cách đều theo thang logarit. Trong các khâu thỏa điều kiện cứng, chọn khâu có độ lợi tần số cao $k \\cdot p/z$ nhỏ nhất, vì độ lợi đó chính là mức khâu bù khuếch đại nhiễu cảm biến thành nhiễu lệnh trợ lực; nếu hòa thì chọn khâu có độ dự trữ pha lớn hơn (Tự chọn(6)). Tác dụng của nhiễu được ước lượng bằng độ lệch chuẩn của $T_a$ khi nhiễu trắng của $T_s$ (độ lệch chuẩn %s N.m, phổ phẳng tới tần số Nyquist $\\pi/T_{ctl}$) đi qua $k H(s) G_m(s)$. Bảng 2 cho kết quả ở 60 km/h; kết quả ở mọi vận tốc khác từ 20 km/h tới 100 km/h trùng với bảng này (xem file %s_stability_by_speed_K.csv), vì ổn định bị chi phối bởi trụ lái.' % (f(SIG, 4), CTRL))
rows = [['K', 'tìm được khâu bù', 'z [rad/s]', 'p [rad/s]', 'dự trữ pha [độ]', 'dự trữ độ lợi', 'tần số cắt [rad/s]', 'độ lợi tần số cao k*p/z', 'nhiễu T_a [N.m]']]
for _, r in stab[stab.v_kmh == 60].iterrows():
    if r.stable_lead_found == 1:
        rows.append([f(r.K, 1), 'có', f(r.z_rad_s, 1), f(r.p_rad_s, 0), f(r.PM_deg, 1), f(r.GM, 2), f(r.wc_rad_s, 0), f(r.HF_gain, 0), f(r.Ta_noise_std_Nm, 2)])
    else:
        rows.append([f(r.K, 1), 'không', '-', '-', '-', '-', '-', '-', '-'])
TAB('Bảng 2: Khâu sớm pha có độ lợi tần số cao nhỏ nhất đạt độ dự trữ pha 45° cho mỗi độ dốc K (xe ở 60 km/h)', rows)
s60 = stab[stab.v_kmh == 60]
assert s60[s60.stable_lead_found == 1].K.max() == Kstab and (s60[s60.K > Kstab].stable_lead_found == 0).all()
P('3.4. Giới hạn ổn định và vì sao khảo sát K tới 18')
P('Khảo sát các giá trị $K$ từ 1 tới 18 (1, 2, ..., 10, rồi 12, 14, 16, 18, cùng các bước mịn hơn quanh $K_{stab}$); $K = 0$ bỏ qua vì không có trợ lực. Cận trên 18 là giá trị chẵn đầu tiên lớn hơn độ dốc tự nhiên lớn nhất trong vùng lái thường ngày, %s ở 25 km/h (Bảng 1): với $K \\ge %s$ bản đồ trong 0.1 g đến 0.3 g đi qua mọi điểm hiệu chỉnh, tăng $K$ thêm không đổi bản đồ ở vùng đó nên không cần khảo sát xa hơn. Kết quả (Bảng 2) là chỉ có khâu bù khi $K \\le %s$; từ $K = 10$ trở lên, trên toàn lưới tìm kiếm, không có khâu nào cho độ dự trữ pha 45°, kể cả $K = 12, 14, 16, 18$. Gọi giá trị lớn nhất có khâu bù là $K_{stab} = %s$ (lưới $K$ có bước 0.25 ở vùng 5.5 đến 9.5 và các điểm kiểm ở 9.75 và 10). Vì độ lợi tần số cao tăng rất nhanh khi $K$ tiến tới $K_{stab}$ (từ %s ở $K = 8$ lên %s ở $K = 9.5$), nhiễu lệnh trợ lực cũng tăng nhanh theo.' % (f(natmax, 1), f(natmax, 1), f(Kstab, 1), f(Kstab, 1), f(s60[s60.K == 8].HF_gain.iloc[0], 0), f(s60[s60.K == 9.5].HF_gain.iloc[0], 0)))
P('3.5. Hệ quả cho độ chính xác ở vận tốc thấp')
P('Hình 2 đặt $K_{stab}$ cạnh $K_{acc}(v)$. Ở 25 km/h, $K_{acc} = %s$ lớn hơn $K_{stab} = %s$: không bản đồ nào vừa bám đúng giá trị đặt trên toàn dải 0.1 g đến 0.3 g vừa ổn định, và sai số xác lập ở đó lớn (tới %s%% ở bản đồ đã chọn, mục 4.3). Ở 30 km/h và 35 km/h, $K_{acc}$ là %s và %s, nằm dưới $K_{stab}$ nhưng trên mức mà điều kiện không bang-bang cho phép (mục 4.1), nên cũng không đạt; ở 20 km/h gia tốc ngang của đối tượng chỉ tới 0.2 g nên dải hiệu chỉnh ngắn hơn, sai số của bản đồ đã chọn ở đó bằng %s%%. Đây là hạn chế của bản đồ truyền thống, không phải của việc chọn tham số, được nêu ở mục 4.4 và 6.' % (f(k25, 2), f(Kstab, 1), f(dry[dry.v_kmh == 25].max_dry_err_pct_0p1_0p3g.iloc[0], 0), f(kacc[kacc.v_kmh == 30].Kmin_for_accuracy.iloc[0], 2), f(kacc[kacc.v_kmh == 35].Kmin_for_accuracy.iloc[0], 2), f(dry[dry.v_kmh == 20].max_dry_err_pct_0p1_0p3g.iloc[0], 1)))
FIG(3, 'Hàm truyền vòng hở (đối tượng ở 60 km/h và 100 km/h, a_y = 0.3 g): biên độ và pha, dự trữ pha 45°', os.path.join(D, CTRL + '_loop_bode.png'))

# ------------------------------------------------------------------ 4
H1('4. Chọn độ dốc lớn nhất')
P('4.1. Miền K cho phép và cổng không bang-bang')
P('Mọi bộ điều khiển trong luận văn phải qua thêm một điều kiện cứng chung: nhiễu cảm biến không được làm lệnh trợ lực nhảy liên tục tới giới hạn $T_{a,max}(v)$ của motor (kiểu bang-bang), vì không hệ trợ lực lái thật nào chấp nhận. Điều kiện được đo trên ca TK: chạy hai lần, một với cảm biến lý tưởng và một với cảm biến có nhiễu (hạt giống 00000); tính tỉ lệ mẫu, từ giây thứ hai, mà lệnh của bộ điều khiển chạm giới hạn (từ 99.9% giới hạn trở lên); bộ điều khiển bị loại nếu tỉ lệ có nhiễu lớn hơn tỉ lệ lý tưởng quá 1% (ngưỡng 1% là Tự chọn(8), báo độ nhạy ở dưới). Bảng 3 và Hình 4 cho kết quả theo $K$.')
rows = [['K', 'tỉ lệ chạm giới hạn, lý tưởng [%]', 'tỉ lệ chạm giới hạn, có nhiễu [%]', 'tăng do nhiễu [%]', 'qua cổng 1%']]
for _, r in bb.iterrows():
    rows.append([f(r.K, 2), f(100 * r.f_sat_ideal, 3), f(100 * r.f_sat_noisy, 3), f(100 * r.f_sat_delta, 3), 'có' if r.f_sat_delta <= 0.01 else 'không'])
TAB('Bảng 3: Cổng không bang-bang của bản đồ theo K (ca TK, hạt giống 00000, ngưỡng 1%)', rows)
FIG(4, 'Tăng tỉ lệ mẫu chạm giới hạn T_a,max do nhiễu theo K, ngưỡng 1% và miền K còn lại', os.path.join(D, CTRL + '_bangbang_by_K.png'))
P('Cổng này chỉ cho $K \\le %s$. Miền cho phép là $\\max_v K_{acc}(v) \\le K_{max} \\le \\min(K_{stab}, %s)$, trong đó $K_{stab} = %s$ (mục 3.4) không còn là cận trên thật. Độ nhạy theo ngưỡng: ngưỡng 0.5%% cho $K \\le %s$, 2%% cho $K \\le %s$, 5%% cho $K \\le %s$. Ở 30 km/h và 35 km/h cần $K_{acc} = %s$ và $%s$ lớn hơn cận %s: hai điều kiện cứng xung đột ở vận tốc thấp. Người dùng chọn ưu tiên điều kiện không bang-bang trên toàn dải và bỏ điều kiện độ chính xác ở vận tốc thấp: điều kiện độ chính xác chỉ áp dụng từ 40 km/h, nơi $K_{acc} \\le 6.75$ nằm trong miền cho phép (Tự chọn(2)). Hậu quả được đo ở mục 4.4.' % (f(KBB, 2), f(KBB, 2), f(Kstab, 1), f(kbb(0.005), 2), f(kbb(0.02), 2), f(kbb(0.05), 2), f(kacc[kacc.v_kmh == 30].Kmin_for_accuracy.iloc[0], 2), f(kacc[kacc.v_kmh == 35].Kmin_for_accuracy.iloc[0], 2), f(KBB, 2)))
P('4.2. Quy tắc chọn K: đáp ứng trước, êm sau')
P('Mỗi $K$ trong miền cho phép được đánh giá bằng mô phỏng vòng kín trên ca hiệu chỉnh TK, với cảm biến có nhiễu (hạt giống 00000, hạt giống địa phương của bản đồ trong dải 0 đến 9999, chỉ một hạt giống). Ca TK trên đường khô gồm ba khối 28 s ở 30, 60 và 100 km/h, mỗi khối là vào cua gắt 0.35 g, lái hình sin biên độ 0.1 g tần số 0.5 Hz, và các hiệu chỉnh nhỏ quanh 0.2 g. Hai chỉ số, tính riêng cho từng khối vận tốc và bỏ 2 s đầu của ca:')
P()
EQ(9, 'R = sqrt(mean(e_T^2)) trong cac cua so cua khoi,   S = sqrt(mean(HP5(T_a)^2)) tren ca khoi', 'R=\\sqrt{\\overline{e_T^2}}\\;\\text{(cửa sổ đánh giá)},\\qquad S=\\sqrt{\\overline{\\big(\\mathrm{HP}_{5\\,\\mathrm{Hz}}T_a\\big)^2}}')
P('$R$ là căn bình phương trung bình (RMS) của $e_T$ trong các cửa sổ đánh giá của khối (bám giá trị đặt: nhỏ là tốt); $S$ là RMS của $T_a$ sau khi lọc thông cao một bậc ở 5 Hz, tức phần mô-men trợ lực mà lệnh của tài xế (dưới vài Hz) không giải thích được, nghĩa là độ giật do nhiễu (nhỏ là tốt). Bản đồ được chấm bằng cả ba khối (căn của trung bình bình phương ba khối). Quy tắc chọn điểm là quy tắc chung của mọi bộ điều khiển và không dùng con số tuyệt đối nào cho $S$: bám giá trị đặt là ưu tiên một vì mục tiêu của đề tài là khắc phục trợ lực thừa, tức bám $T_{d,ref}$, còn êm là ưu tiên hai. Trong các $K$ qua mọi điều kiện cứng, giữ các $K$ có $R$ không quá 5% so với $R$ nhỏ nhất của bản đồ (5% là ngưỡng hòa: chênh nhỏ hơn mức này coi là ngang nhau), rồi chọn $K$ có $S$ nhỏ nhất (Tự chọn(7)). Mặt Pareto (tập thiết kế mà không thể cải thiện $R$ mà không làm $S$ xấu đi) chỉ dùng để vẽ hình và để so sánh giữa các bộ điều khiển, không dùng để chọn điểm.')
def pareto_rows(t):
    rows = [['K', 'R [N.m]', 'S [N.m]', 'tăng tỉ lệ chạm giới hạn do nhiễu [%]', 'qua mọi cổng cứng', 'trong 5% của R nhỏ nhất', 'điểm chọn']]
    for _, r in t[(t.K >= 5.5) & (t.K <= 9.5)].iterrows():
        dl = float(bb[abs(bb.K - r.K) < 1e-9].f_sat_delta.iloc[0])
        rows.append([f(r.K, 2), f(r.R, 3), f(r.S, 3), f(100 * dl, 2), 'có' if r.admissible else 'không', 'có' if r.finalist else '', 'có' if r.chosen else ''])
    return rows
TAB('Bảng 4: Đáp ứng R và nhiễu S của bản đồ theo K (ba khối 30, 60 và 100 km/h)', pareto_rows(par))
P('Kết quả: $K_{max}$ = %s. Miền cho phép chỉ còn %d giá trị $K$ trên lưới và hai điểm cuối cùng (K = 6.75 và 7.00) cách nhau dưới 5%% về $R$, nên điểm có $S$ nhỏ hơn được chọn.' % (f(K, 2), int(par.admissible.sum())))
FIG(5, 'Đáp ứng R và nhiễu S của bản đồ theo K; chấm xám: K ngoài miền cho phép, sao đỏ: K được chọn', os.path.join(D, CTRL + '_pareto.png'))
P('4.3. Thiết kế cuối cùng')
sm = summ.iloc[0]
rows = [['', 'giá trị'], ['K_max', f(K, 2)], ['điểm không z [rad/s]', f(z, 1)], ['điểm cực p [rad/s]', f(p, 0)], ['tỉ số p/z', f(p / z, 1)],
        ['độ lợi tần số cao k*p/z', f(sm.HF_gain_k_p_over_z, 0)], ['độ dự trữ pha nhỏ nhất [độ] (k = K_max)', f(d['lead']['PM_deg'], 1)],
        ['dự trữ độ lợi (đối tượng 60 km/h, 0.3 g)', f(sm.GM_60kmh, 2)], ['dự trữ độ lợi (đối tượng 100 km/h, 0.3 g)', f(sm.GM_100kmh, 2)],
        ['tần số cắt (đối tượng 60 km/h) [rad/s]', f(sm.wc_rad_s_60kmh, 0)], ['độ lệch chuẩn nhiễu T_a ước lượng [N.m]', f(NOISE, 2)]]
TAB('Bảng 5: Thông số bộ điều khiển bản đồ sau thiết kế', rows)
assert (chk.max_real_pole < 0).all() and (chk.PM_deg > 44.5).all(), 'closed-loop check failed'
P('Các giá trị này được ghi vào data/map.json (trường design) và là nguồn duy nhất cho mô hình Simulink. Kiểm tra độc lập bằng các đối tượng hàm truyền của Control System Toolbox (trễ xấp xỉ Padé bậc ba) ở $k = 0.25K_{max}$ và $k = K_{max}$, ở 20, 60 và 100 km/h và ba điểm làm việc: mọi cực vòng kín nằm ở nửa trái mặt phẳng phức (phần thực lớn nhất là %s rad/s) và độ dự trữ pha nhỏ nhất là %s°. Sai số xác lập của bản đồ đã chọn trên đường khô (Hình 6, các giá trị lớn nhất trong 0.1 g đến 0.3 g theo vận tốc) không quá %s%% từ 40 km/h tới 100 km/h; ở 35 km/h là %s%%, 30 km/h là %s%%, 25 km/h là %s%%, 20 km/h là %s%%.' % (f(chk.max_real_pole.max(), 1), f(chk.PM_deg.min(), 1), f(dry40, 2), f(dry[dry.v_kmh == 35].max_dry_err_pct_0p1_0p3g.iloc[0], 1), f(dry[dry.v_kmh == 30].max_dry_err_pct_0p1_0p3g.iloc[0], 1), f(dry[dry.v_kmh == 25].max_dry_err_pct_0p1_0p3g.iloc[0], 1), f(dry[dry.v_kmh == 20].max_dry_err_pct_0p1_0p3g.iloc[0], 1)))
FIG(6, 'Sai số xác lập của bản đồ đã chọn trên đường khô theo gia tốc ngang ở 5 vận tốc; vùng xanh: 0.1 g đến 0.3 g, sai số trong 3%', os.path.join(D, CTRL + '_dry_road_steady_error.png'))
FIG(7, 'Bản đồ trợ lực M(v, |T_s|) đã chọn (đường liền) và các điểm hiệu chỉnh trên đường khô (chấm) ở 5 vận tốc', os.path.join(D, CTRL + '_assist_curves_by_speed.png'))
P('4.4. Một độ dốc cho mọi vận tốc, và sai số trên ca TK')
P('Bản đồ dùng một độ dốc lớn nhất $K_{max}$ chung cho mọi vận tốc (người dùng chốt ngày 2026-10-09). Lý do: quy tắc chung của mọi bộ điều khiển chỉ giữ cấu trúc nhiều bậc theo vận tốc nếu $R$ giảm ít nhất 5%% mà $S$ không tăng so với bản một bậc, và đo trong giai đoạn thiết kế cho thấy với các cổng chung hiện nay bản đồ hai độ dốc suy biến thành bản một độ dốc: miền $K$ cho phép bị cổng không bang-bang chặn ở $K \\le %s$ và cổng độ chính xác đòi $K \\ge 6.75$ ở 40 km/h đến 55 km/h, nên cả hai bậc rơi vào cùng một giá trị và cho cùng $R$ = %s N.m, $S$ = %s N.m trên ca TK. Do đó không có lý do để dùng hai độ dốc.' % (f(KBB, 2), f(float(terel.R_TK.iloc[0]), 3), f(float(terel.S_TK.iloc[0]), 3)))
rows = [['bản', 'sai số tại cửa sổ giữ góc 0.35 g, 30 km/h [%]', '60 km/h [%]', '100 km/h [%]']]
for _, r in terel.iterrows():
    rows.append([r.design, f(r.erel_v30_pct, 1), f(r.erel_v60_pct, 1), f(r.erel_v100_pct, 1)])
TAB('Bảng 6: Sai số xác lập e_rel của bản đồ trên ca TK (cửa sổ giữ góc ứng với 0.35 g), theo định nghĩa của tk_run.m', rows)
P('Các bộ điều khiển khác dùng sai số $e_{rel}$ đo trên chính ca TK, tức tại cửa sổ giữ góc ứng với 0.35 g, làm điều kiện chính xác chung (không quá 3%%). Với bản đồ điều kiện đó không thể đạt ở bất kỳ $K$ nào (Bảng 6: %s%% ở 30 km/h với bản đã chọn, và kể cả ở $K$ = 9.5 vẫn trên 5%%), vì bản đồ chỉ được hiệu chỉnh tới 0.3 g và trên mức đó độ dốc bị chặn (mục 2.2); đó là bản chất của bản đồ, nên điều kiện chính xác của bản đồ được định nghĩa trên dải đã hiệu chỉnh (mục 2.3) chứ không trên cửa sổ 0.35 g. Đây là một sai khác so với các bộ điều khiển khác, được ghi trung thực (Tự chọn(9)): ở cua gắt trên 0.3 g bản đồ có sai số xác lập lớn hơn các bộ có khâu tích phân, và phần chênh này được tính vào kết quả so sánh chứ không bị che.' % f(float(terel.erel_v30_pct.iloc[0]), 1))
H1('5. Kiểm chứng trong vòng kín')
P('Bộ điều khiển được chạy trên sáu ca thử chuẩn TC1 đến TC6 của chương kịch bản, hai lần: với cảm biến lý tưởng và với cảm biến có nhiễu (hạt giống địa phương của bản đồ, %05d, trong dải 0 đến 9999, cùng hạt giống đã dùng để chọn $K$ theo quy tắc chung: chọn tham số trên ca TK rồi chấm trên TC). Mọi chỉ số tính trên tín hiệu thật của đối tượng, không phải tín hiệu bộ điều khiển đo được, và bỏ 2 s đầu của mỗi ca. Việc so sánh với các bộ điều khiển khác dùng một hạt giống chung 99999 và nằm ở chương so sánh. Bảng 7 cho các chỉ số của cả ca: RMS của $e_T$, giá trị tuyệt đối lớn nhất của $e_T$, giá trị tuyệt đối lớn nhất của $T_a$ và biến thiên toàn phần của $T_a$ mỗi giây (TV, total variation: tổng $|\\Delta T_a|$ chia thời gian, đo độ giật).' % TS)
rows = [['ca', 'RMS e_T lý tưởng [N.m]', 'RMS e_T có nhiễu [N.m]', 'max |e_T| lý tưởng [N.m]', 'max |T_a| lý tưởng [N.m]', 'TV lý tưởng [N.m/s]', 'max |T_a| có nhiễu [N.m]', 'TV có nhiễu [N.m/s]']]
wi = mi[mi.Window == 'whole case'].reset_index(drop=True); wn = mn[mn.Window == 'whole case'].reset_index(drop=True)
for i in range(len(wi)):
    rows.append([wi.Case[i][:3], f(wi.RMS_eT_Nm[i], 3), f(wn.RMS_eT_Nm[i], 3), f(wi.MaxAbs_eT_Nm[i], 2), f(wi.MaxAbs_Ta_Nm[i], 2), f(wi.TV_Ta_Nm_per_s[i], 2), f(wn.MaxAbs_Ta_Nm[i], 2), f(wn.TV_Ta_Nm_per_s[i], 0)])
TAB('Bảng 7: Chỉ số của bản đồ trên sáu ca thử chuẩn, cảm biến lý tưởng và cảm biến có nhiễu (hạt giống %05d)' % TS, rows)
dr = (wn.RMS_eT_Nm / wi.RMS_eT_Nm - 1).abs().max() * 100
P('Khi cảm biến lý tưởng, TV chỉ từ %s N.m/s đến %s N.m/s: bản đồ êm. Khi có nhiễu, TV tăng lên từ %s N.m/s đến %s N.m/s, vì nhiễu cảm biến $T_s$ đi qua độ dốc bản đồ và độ lợi tần số cao của khâu bù (mục 3.3); RMS $e_T$ tính trên tín hiệu thật chỉ đổi tối đa %s%% giữa hai chế độ cảm biến, vì phần giật tần số cao của $T_a$ bị trụ lái lọc đi. Đây là đặc tính cố hữu của bản đồ, và là mức nhiễu mà bộ điều khiển đề xuất phải so sánh.' % (f(wi.TV_Ta_Nm_per_s.min(), 2), f(wi.TV_Ta_Nm_per_s.max(), 1), f(wn.TV_Ta_Nm_per_s.min(), 0), f(wn.TV_Ta_Nm_per_s.max(), 0), f(dr, 1)))
P('Sai số xác lập tại các cửa sổ đo (Bảng 8, phần trăm có dấu của giá trị đặt, âm nghĩa là tay lái nhẹ hơn mong muốn tức trợ lực thừa) cho thấy hai điều. Trên đường khô (TC1), sai số tại các cửa sổ không quá %s%%, đúng điều kiện cứng của mục 2.3. Khi $\\mu$ giảm, bản đồ vẫn cấp trợ lực như đường khô nên tay lái nhẹ đi: %s%% ở TC3 sau khi $\\mu$ giảm đột ngột và %s%% ở TC4 khi xe qua vũng nước; đây đúng là điểm yếu trợ lực thừa mà chuẩn so sánh phải có. Phần trăm ở cửa sổ sau cua của TC4 (trung bình $|T_{d,ref}|$ gần không) không có ý nghĩa và chỉ đưa vào để đủ bảng.' % (f(mi[mi.Case.str.startswith('TC1') & (mi.Window != 'whole case')].Mean_eT_signed_pct_of_Tdref.abs().max(), 2), f(mi[(mi.Case.str.startswith('TC3')) & (mi.Window == 'after_mu_drop_steady')].Mean_eT_signed_pct_of_Tdref.iloc[0], 1), f(mi[(mi.Case.str.startswith('TC4')) & (mi.Window == 'during_puddle')].Mean_eT_signed_pct_of_Tdref.iloc[0], 1)))
rows = [['ca', 'cửa sổ', 'trung bình e_T [N.m]', 'e_T / T_d,ref [%]']]
for _, r in mi[mi.Window != 'whole case'].iterrows():
    rows.append([r.Case[:3], r.Window, f(r.Mean_eT_Nm, 3), f(r.Mean_eT_signed_pct_of_Tdref, 1)])
TAB('Bảng 8: Sai số xác lập của bản đồ tại các cửa sổ đo (cảm biến lý tưởng)', rows)
names = [('TC1_dry_calibration', 'TC1: hiệu chỉnh trên đường khô'), ('TC2_road', 'TC2: chạy đường thực tế'), ('TC3_mu_drop_hard_corner', 'TC3: giảm μ đột ngột khi vào cua gắt'),
         ('TC4_wet_patch_lane_change', 'TC4: đổi làn qua vũng nước'), ('TC5_sine_high_speed_low_mu', 'TC5: lái sin ở tốc độ cao trên đường rất trơn'), ('TC6_mu_rise_mid_corner', 'TC6: μ tăng giữa cua')]
for i, (tag, nm) in enumerate(names):
    FIG(8 + i, 'Đáp ứng của bản đồ trên ca %s, cảm biến lý tưởng' % nm, os.path.join(TC, '%s_%s_time_response.png' % (CTRL, tag)))
FIG(14, 'Đáp ứng của bản đồ trên ca TC1 khi cảm biến có nhiễu (hạt giống %05d): T_a giật do nhiễu' % TS, os.path.join(TN, '%s_TC1_dry_calibration_time_response.png' % CTRL))

# ------------------------------------------------------------------ 6
H1('6. Hạn chế và các lựa chọn của tác giả')
P('Hạn chế của bản đồ như một chuẩn so sánh. Thứ nhất, nó chỉ đúng trên đường khô: ngoài $\\mu = 0.8$ nó không biết $\\mu$ nên trợ lực thừa (mục 5), đúng như [4] mô tả. Thứ hai, độ chính xác trên đường khô chỉ được bảo đảm ở trạng thái xác lập, ở 30 km/h trở lên và trong 0.1 g đến 0.3 g; ở 25 km/h bản đồ không thể vừa chính xác vừa ổn định (mục 3.5 và 4.4), và trên 0.3 g bản đồ nằm thấp hơn điểm hiệu chỉnh vì độ dốc bị chặn (mục 2.2), nên tay lái nặng hơn mong muốn trong cua gắt trên đường khô (cửa sổ trước khi $\\mu$ giảm của TC3, 0.35 g ở 100 km/h: %s%%). Thứ ba, hiệu chỉnh chỉ bảo đảm trạng thái xác lập: ở TC1 sai số tại các cửa sổ xác lập không quá %s N.m nhưng sai số lớn nhất của cả ca là %s N.m, xảy ra ở các chuyển tiếp giữa các bậc gia tốc ngang, nơi quán tính và ma sát của trụ lái làm hệ chưa kịp tới cân bằng. Thứ tư, bản đồ chỉ dùng một độ dốc chung cho mọi vận tốc vì bản hai độ dốc suy biến thành một (mục 4.4). Thứ năm, mức nhiễu lệnh trợ lực là cố hữu (mục 3.3 và 5) và là thứ bộ điều khiển đề xuất phải so sánh.' % (f(mi[(mi.Case.str.startswith('TC3')) & (mi.Window == 'before_mu_drop')].Mean_eT_signed_pct_of_Tdref.iloc[0], 1), f(mi[mi.Case.str.startswith('TC1') & (mi.Window != 'whole case')].Mean_eT_Nm.abs().max(), 3), f(wi.MaxAbs_eT_Nm[0], 2)))
P('Các lựa chọn của tác giả (không từ nguồn): Tự chọn(1) vùng chết $T_{s0} = 0.3$ N.m (mục 2.2). Tự chọn(2) điều kiện sai số xác lập không quá 3% trong 0.1 g đến 0.3 g ở vận tốc từ 40 km/h (mục 2.3; thu hẹp từ 30 km/h theo quyết định của người dùng ngày 2026-10-08 sau khi thấy xung đột với cổng không bang-bang). Tự chọn(3) bỏ ma sát Coulomb khi tuyến tính hóa (mục 3.1). Tự chọn(4) trễ tương đương 1 ms (mục 3.2). Tự chọn(5) độ dự trữ pha 45° tại mọi độ dốc $k \\in \\{0.25, 0.5, 0.75, 1\\}K_{max}$ và bốn điểm làm việc (mục 3.2). Tự chọn(6) lưới tìm khâu bù và chọn độ lợi tần số cao nhỏ nhất (mục 3.3). Tự chọn(7) ngưỡng hòa 5% của quy tắc chọn chung và một hạt giống địa phương 00000 vừa để chọn $K$ vừa để chấm ca TC riêng (mục 4.2 và 5). Tự chọn(8) ngưỡng 1% của cổng không bang-bang (mục 4.1). Tự chọn(9) định nghĩa điều kiện chính xác của bản đồ trên dải hiệu chỉnh thay vì trên cửa sổ 0.35 g của ca TK (mục 4.4). Giá trị $K_{stab}$ phụ thuộc lưới tìm khâu bù và cách xấp xỉ trễ; với lưới dày hơn hoặc mô hình trễ khác nó có thể dịch nhẹ, nhưng không đổi kết luận rằng $K$ lớn hơn khoảng 10 không ổn định hóa được bằng một khâu sớm pha duy nhất.')
P('Tài liệu tham khảo dùng ở chương này (danh mục chung ở Documents/Shared/References.txt): [1] Lee, Kim, Kim (2018): cấu trúc bản đồ cộng khâu sớm pha, vùng chết, mô hình motor, độ dự trữ pha trên 45°. [4] Li và cộng sự (2023): trợ lực thừa của EPS truyền thống khi hệ số bám giảm. [5] Li và Xia: bảng mô-men vô-lăng lý tưởng và cách xác định trợ lực cần cấp.')

out = os.path.join(ROOT, 'Documents', 'Thesis', 'map.txt')
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print('written', out, len(L), 'lines')
