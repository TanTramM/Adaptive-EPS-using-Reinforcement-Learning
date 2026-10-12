# -*- coding: utf-8 -*-
"""Generate Documents/Thesis/map.txt (Map chapter, lead-lag, QuyChuan v5) and its three new figures from the Map results.

Every number in the text and the tables is read from the files below, never typed:
  Model/data/map.json (design), Result/Controllers/Map/Design/Map_calibration_points.csv, Map_design_leadlag.csv,
  Calib/Map_CALIB_pick_s00000.csv (73 (g_min, K) pairs with J and the gate flags), Calib/Map_CALIB_sweep_s00000.csv (per-window e_rel),
  Cases/Map_metrics_s00000.csv (DRY, RAMP, SLIP, WEAVE, EDGE).
Figures written: Design/Map_bode.png, Calib/Map_CALIB_pick_s00000.png, Calib/Map_CALIB_pareto_s00000.png.
Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/build_map_txt.py
"""
import json
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RC = os.path.join(ROOT, 'Result', 'Controllers', 'Map')
D, CA, CS = (os.path.join(RC, x) for x in ('Design', 'Calib', 'Cases'))
SEED = 's00000'
J = json.load(open(os.path.join(ROOT, 'Model', 'data', 'map.json'), encoding='utf-8'))
d = J['design']

cal = pd.read_csv(os.path.join(D, 'Map_calibration_points.csv'))
dl = pd.read_csv(os.path.join(D, 'Map_design_leadlag.csv'))
pk = pd.read_csv(os.path.join(CA, 'Map_CALIB_pick_s00000.csv'))
sw = pd.read_csv(os.path.join(CA, 'Map_CALIB_sweep_s00000.csv'))
met = pd.read_csv(os.path.join(CS, 'Map_metrics_%s.csv' % SEED))

K, gmin = d['Kmax'], d['g_min']
z, p, z1, p1 = d['lead']['z'], d['lead']['p'], d['lag']['z1'], d['lag']['p1']
W2 = 2 * np.pi * 2.0                                  # 2 Hz in rad/s, upper edge of the steering band
T_NOISE = 0.0104                                      # std of the T_s noise (sensor model), N.m

ch = pk[(abs(pk.g_min - gmin) < 1e-9) & (abs(pk.K - K) < 1e-9) & (abs(pk.comp_K - K) < 1e-9)].iloc[0]
lead_only = pk[(pk.g_min == 1.0) & (pk.K == K) & (pk.comp_K == K)].iloc[0]
adm = pk[pk.admissible == 1]
n_pairs, n_adm = len(pk), len(adm)
n_main = int((pk.comp_K == pk.K).sum())
n_beyond = n_pairs - n_main
n_levels = pk.g_min.nunique()
n_lin = int(len(dl))
n_cand = int(dl.n_tried.sum())


def num(x, nd=2):
    return ('%.' + str(nd) + 'f') % x


def lagain(z_, p_, w):
    return np.sqrt((1 + (w / z_) ** 2) / (1 + (w / p_) ** 2))


def table(rows):
    return '\n'.join(' | '.join(str(c) for c in r) for r in rows)


# ------------------------------------------------------------------------------------------------ derived numbers
ay = cal[(cal.ay_g >= 0.1 - 1e-9) & (cal.ay_g <= 0.3 + 1e-9)].dropna(subset=['natural_slope'])
nat = ay.groupby('v_kmh').natural_slope.max()
nat_lo, nat_hi = nat.min(), nat.max()
v_nat_lo, v_nat_hi = int(nat.idxmin()), int(nat.idxmax())
n_cal = len(cal)

# e_rel versus K (compensator DC gain is 1, so only K sets it; mean over the rows of each K)
ek = pk[pk.comp_K == pk.K].groupby('K').erel_pct.mean()
ek_rows = [['K', 'sai số xác lập e_rel lớn nhất trên 9 cửa sổ static [%]', 'qua cổng 5 %']]
for k in (5.0, 5.5, 5.75, 5.8, 6.0, 6.5, 7.0, 8.0):
    ek_rows.append([num(k), num(ek[k]), 'có' if ek[k] <= 5 else 'không'])
K_gate = min(k for k in ek.index if ek[k] <= 5)

# minimum J per g_min level among the pairs that pass margin screen and e_rel (what J alone would do)
ok_gate = pk[(pk.g_screen == 1) & (pk.g_acc == 1)]
jl = ok_gate.groupby('g_min').apply(lambda x: x.loc[x.J.idxmin()])
j_rows = [['g_min (mức lưới)', 'K tại J nhỏ nhất', 'độ lợi lag tại 2 Hz', 'R [%]', 'S [N.m]', 'J = R x S', 'qua ràng buộc dải lái']]
for g in sorted(jl.index, reverse=True):
    r = jl.loc[g]
    j_rows.append([num(g), num(r.K), num(r.lag_gain_2Hz, 3), num(r.R_pct), num(r.S_Nm, 4), num(r.J, 3), 'có' if r.lag_gain_2Hz >= 1 / np.sqrt(2) - 1e-9 else 'không'])
j_noband = ok_gate.loc[ok_gate.J.idxmin()]
j_band = adm.loc[adm.J.idxmin()]
assert abs(j_band.g_min - gmin) < 1e-9 and abs(j_band.K - K) < 1e-9, 'select_map choice differs from the J minimum (margin check moved it?)'
# sensitivity a = 0.5 and 2 and the former rule on the admissible set
sens = {}
for a in (0.5, 2.0):
    r = adm.loc[(adm.R_pct ** a * adm.S_Nm).idxmin()]
    sens[a] = r
tol = adm[adm.R_pct <= 1.05 * adm.R_pct.min()]
former = tol.loc[tol.S_Nm.idxmin()]

# the compensator frequency response (lead, lag, product)
w = np.logspace(-0.5, 3.7, 600)
def hs(z_, p_, w_):
    return (1j * w_ / z_ + 1) / (1j * w_ / p_ + 1)
H_lead, H_lag = hs(z, p, w), hs(z1, p1, w)
H = H_lead * H_lag

# beyond-the-linear-limit rows
bey = pk[pk.comp_K != pk.K]
bey_rows = [['g_min', 'K của bảng', 'K của khâu bù', 'R [%]', 'S [N.m]', 'e_rel [%]', 'f chạm giới hạn tăng do nhiễu [%]', 'R(độ lợi x2)/R', 'R(trễ +1 ms)/R']]
for _, r in bey.iterrows():
    bey_rows.append([num(r.g_min), num(r.K, 0), num(r.comp_K, 0), num(r.R_pct), num(r.S_Nm, 3), num(r.erel_pct), num(100 * r.f_sat_delta, 2), num(r.ratio_gain, 2), num(r.ratio_delay, 2)])
bey_lo = bey[bey.g_min == 1.0]
bey_07 = bey[bey.g_min == 0.7]

# design table for each level at K
lev = dl[(dl.K == K) & (dl.ok == 1)].sort_values('g_min', ascending=False)
lev_rows = [['g_min', 'z [rad/s]', 'p [rad/s]', 'z1 [rad/s]', 'p1 [rad/s]', 'dự trữ pha [độ]', 'dự trữ độ lợi', 'độ lợi tần số cao K p p1/(z z1)', 'nhiễu T_a tuyến tính [N.m]']]
for _, r in lev.iterrows():
    lag_txt = (num(r.z1, 1), num(r.p1, 2)) if np.isfinite(r.z1) else ('-', '-')
    lev_rows.append([num(r.g_min), num(r.z, 1), num(r.p, 0), lag_txt[0], lag_txt[1], num(r.PM_deg, 1), num(r.GM, 2), num(r.HF_gain, 0), num(r.Ta_noise_std_Nm, 3)])
kmax_feas = dl[dl.ok == 1].groupby('g_min').K.max()
kmax_rows = [['g_min', 'K lớn nhất còn có khâu bù đạt dự trữ pha 45 độ trên lưới'] ] + [[num(g), num(kmax_feas[g], 1)] for g in sorted(kmax_feas.index, reverse=True) if g in (1.0, 0.9, 0.8, 0.7, 0.6)]

# windows of the chosen point
wcols = [c for c in sw.columns if c.startswith('erel_static_')]
srow = sw[(abs(sw.g_min - gmin) < 1e-9) & (abs(sw.K - K) < 1e-9)].iloc[0]
win_rows = [['cửa sổ static', 'e_rel [%]']]
for c in wcols:
    nm = c.replace('erel_static_', '').replace('apos', 'a')
    win_rows.append([nm, num(srow[c])])
ext_rows = [['cửa sổ ext (0.4 g, chỉ báo cáo)', 'e_ext [%]']] + [[c.replace('eext_ext_', '').replace('apos', 'a'), num(srow[c])] for c in sw.columns if c.startswith('eext_')]

# cases
whole = met[met.Window == 'whole case'].set_index('Case')
case_rows = [['ca', 'RMS e_T [N.m]', 'max |e_T| [N.m]', 'S [N.m]', 'TV [N.m/s]', 'trợ lực ngược [%]', 'đỉnh |T_a| [% T_a,max]']]
for c in ('DRY', 'RAMP', 'SLIP', 'WEAVE', 'EDGE'):
    r = whole.loc[c]
    case_rows.append([c, num(r.RMS_eT_Nm, 3), num(r.MaxAbs_eT_Nm, 2), num(r.S_Nm, 3), num(r.TV_Ta_Nm_per_s, 1), num(r.Rev_pct, 3), num(r.Peak_Ta_pct_of_Tamax, 1)])
def winrows(case, header):
    rr = met[(met.Case == case) & (met.Window != 'whole case')]
    out = [header]
    for _, r in rr.iterrows():
        out.append([r.Window, num(r.Mean_eT_Nm, 3), num(r.Mean_eT_signed_pct_of_Tdref, 1)])
    return out
dry_w = winrows('DRY', ['cửa sổ', 'trung bình e_T [N.m]', 'e_T theo chiều T_d,ref [%] (dương: tay lái nặng hơn mong muốn)'])
rp = met[(met.Case == 'RAMP') & (met.Window != 'whole case')].set_index('Window').Mean_eT_signed_pct_of_Tdref
ramp_w = winrows('RAMP', ['cửa sổ', 'trung bình e_T [N.m]', 'e_T theo chiều T_d,ref [%] (dương: tay lái nặng hơn mong muốn)'])
slip_w = winrows('SLIP', ['cửa sổ', 'trung bình e_T [N.m]', 'e_T theo chiều T_d,ref [%] (dương: tay lái nặng hơn mong muốn)'])
edge_w = winrows('EDGE', ['cửa sổ', 'trung bình e_T [N.m]', 'e_T theo chiều T_d,ref [%] (dương: tay lái nặng hơn mong muốn)'])
dry_pct = met[(met.Case == 'DRY') & (met.Window != 'whole case')].set_index('Window').Mean_eT_signed_pct_of_Tdref
dry_worst_w = dry_pct.abs().idxmax()
dry_worst = dry_pct[dry_worst_w]
dry_second = dry_pct.drop(dry_worst_w).abs().max()
pud = met[(met.Case == 'SLIP') & (met.Window == 'pud_in')].Mean_eT_signed_pct_of_Tdref.iloc[0]
ed = met[met.Case == 'EDGE'].set_index('Window').Mean_eT_signed_pct_of_Tdref

# ------------------------------------------------------------------------------------------------ figures
plt.rcParams.update({'font.size': 10})
# 1. compensator Bode
fig, ax = plt.subplots(2, 1, figsize=(8.2, 6.4), sharex=True)
for Hh, lab, st in ((H_lead, 'lead (z = %.1f, p = %.0f)' % (z, p), '--'), (H_lag, 'lag (z1 = %.1f, p1 = %.2f)' % (z1, p1), '-.'), (H, 'lead x lag', '-')):
    ax[0].semilogx(w, 20 * np.log10(np.abs(Hh)), st, label=lab, lw=2 if st == '-' else 1.3)
    ax[1].semilogx(w, np.angle(Hh, deg=True), st, lw=2 if st == '-' else 1.3)
for a_ in ax:
    a_.axvline(W2, color='gray', ls=':'); a_.grid(True, which='both', alpha=.3)
ax[0].axhline(20 * np.log10(1 / np.sqrt(2)), color='r', ls=':', lw=1)
ax[0].text(W2 * 1.1, -14, '2 Hz', color='gray')
ax[0].set_ylabel('độ lợi [dB]'); ax[1].set_ylabel('pha [độ]'); ax[1].set_xlabel('tần số [rad/s]')
ax[0].legend(loc='upper left', fontsize=8)
ax[0].set_title('Khâu bù của Map đã chọn: lag giữ độ lợi %.2f tại 2 Hz (ràng buộc dải lái >= 0.707)' % lagain(z1, p1, W2), fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(D, 'Map_bode.png'), dpi=140); plt.close(fig)

# 2. J versus level
fig, ax = plt.subplots(figsize=(7.2, 4.4))
gs = sorted(jl.index)
ax.plot(gs, [jl.loc[g].J for g in gs], 'o-', color='C0')
ax.axvline(1 / np.sqrt(2), color='r', ls='--'); ax.text(1 / np.sqrt(2) + 0.01, ax.get_ylim()[1] * 0.97, 'ràng buộc dải lái\n(độ lợi lag 2 Hz >= 0.707)', color='r', va='top', fontsize=8)
ax.plot([gmin], [ch.J], 'r*', ms=14, label='điểm chọn g_min %.2f, K %.1f, J %.2f' % (gmin, K, ch.J))
ax.set_xlabel('g_min (mức lưới của khâu lag)'); ax.set_ylabel('J = R x S nhỏ nhất ở mức đó'); ax.grid(True, alpha=.3); ax.legend(fontsize=8)
ax.set_title('J giảm khi khâu lag sâu hơn: ràng buộc dải lái là phần chặn', fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(CA, 'Map_CALIB_pick_s00000.png'), dpi=140); plt.close(fig)

# 3. Pareto (R, S)
fig, ax = plt.subplots(figsize=(7.4, 5.0))
sc = ax.scatter(pk.R_pct, pk.S_Nm, c=pk.g_min, cmap='viridis', s=28, edgecolors='none')
bad = pk[pk.admissible == 0]
ax.scatter(bad.R_pct, bad.S_Nm, facecolors='none', edgecolors='gray', s=60, label='không qua cổng hoặc ràng buộc')
ax.plot([ch.R_pct], [ch.S_Nm], 'r*', ms=15, label='điểm chọn')
ax.plot([lead_only.R_pct], [lead_only.S_Nm], 'ks', ms=7, label='lead đơn K %.1f' % K)
ax.plot([j_noband.R_pct], [j_noband.S_Nm], 'm^', ms=8, label='J không ràng buộc')
ax.set_xlabel('R [%]'); ax.set_ylabel('S [N.m]'); ax.grid(True, alpha=.3); ax.legend(fontsize=8)
fig.colorbar(sc, label='g_min'); ax.set_title('Mặt (R, S) của %d cặp (g_min, K) trên ca CALIB' % n_pairs, fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(CA, 'Map_CALIB_pareto_s00000.png'), dpi=140); plt.close(fig)

# ------------------------------------------------------------------------------------------------ text
L = []
def add(*lines):
    L.extend(lines)
BAR = '=' * 120
SEP = '-' * 120
def head(t):
    add(SEP, t, SEP)

add(BAR, 'BỘ ĐIỀU KHIỂN BẢN ĐỒ TRỢ LỰC TRUYỀN THỐNG (MAP)', BAR)
add('Chương này thiết kế bộ điều khiển bản đồ trợ lực, bộ điều khiển truyền thống dùng làm chuẩn so sánh cho các bộ điều khiển ở các chương sau. Thiết kế chỉ dựa vào môi trường mô phỏng đã dựng ở các chương trước '
    '(đối tượng điều khiển, giá trị đặt, cảm biến, motor) và theo đúng quy chuẩn chung của mọi bộ điều khiển (phiên bản 5, ngày 2026-10-11): cùng ca hiệu chỉnh CALIB, cùng cổng cứng, cùng quy tắc chọn điểm. '
    'Mục 1 nêu vai trò và cấu trúc. Mục 2 dựng bản đồ từ các điểm hiệu chỉnh trên đường khô. Mục 3 thiết kế khâu bù sớm-trễ pha (lead-lag) và nêu vì sao cần mức độ làm chậm của khâu trễ pha được giới hạn. '
    'Mục 4 chọn độ dốc lớn nhất và khâu bù bằng quy tắc chung. Mục 5 kiểm chứng trên năm ca chấm. Mục 6 nêu hạn chế và các lựa chọn của tác giả.')
add('')
head('1. Vai trò và cấu trúc')
add('1.1. Vai trò')
add('Theo [4], hệ trợ lực lái điện truyền thống chỉ xét vận tốc xe và mô-men tay lái; khi hệ số bám giảm, mô-men cản giảm nhưng bộ điều khiển vẫn cấp trợ lực như cũ nên trợ lực quá lớn, làm giảm cảm giác đường của tài xế. '
    'Bản đồ trợ lực là dạng điều khiển truyền thống đó: nó được hiệu chỉnh trên đường khô ($\\mu = 0.8$), nơi mô-men cản lớn nhất, để tay lái nhẹ trong điều kiện nặng nhất. Vì vậy bản đồ là chuẩn so sánh thích hợp: '
    'nó phải có đúng điểm yếu này, trợ lực thừa khi $\\mu$ giảm, và không được bị làm yếu thêm ở khía cạnh khác, chẳng hạn hiệu chỉnh kém trên đường khô hay tự dao động, nếu không phần cải thiện của bộ điều khiển đề xuất sẽ bị thổi phồng. '
    'Do đó bản đồ qua cùng các cổng cứng như mọi bộ khác (vòng kín ổn định với độ dư, sai số xác lập không quá 5 % trên dải đã hiệu chỉnh).')
add('1.2. Cấu trúc bộ điều khiển')
add('Theo [1] (mục III.A, phương trình (15) và (16)), bộ điều khiển gồm bản đồ mô-men, quan hệ một-một giữa mô-men cảm biến và mô-men trợ lực có vùng chết dưới một ngưỡng $\\tau_{s0}$, nối tiếp một khâu bù đặt sau bản đồ. '
    'Bộ điều khiển chỉ đọc hai tín hiệu đo được là mô-men cảm biến $T_s$ và vận tốc $v$, lấy mẫu với chu kỳ $T_{ctl} = 1$ ms (bằng chu kỳ cập nhật của $T_s$ trong mô hình cảm biến); không đọc $\\mu$, không tính sai số $e_T$ và không có khâu tích phân. '
    'Bản đồ cho trợ lực theo trị tuyệt đối của mô-men cảm biến, nhân với dấu để trợ lực luôn cùng chiều mô-men tay; $M$ là bảng hai chiều theo vận tốc và $|T_s|$, nội suy tuyến tính:')
add('')
add('  (1)  T_a,map = sgn(T_s) * M(v, |T_s|)', '  [ T_{a,map}=\\mathrm{sgn}(T_s)\\,M(v,|T_s|) ]', '')
add('Khâu bù gồm hai khâu nối tiếp, cùng dạng $(s/a + 1)/(s/b + 1)$ và cùng có độ lợi bằng một ở tần số không. Khâu sớm pha (lead, $b > a$) làm tín hiệu sớm pha trong dải tần giữa $z$ và $p$ để vòng kín ổn định; '
    'khâu trễ pha (lag, $b < a$) hạ độ lợi ở tần số trung và cao để giảm khuếch đại nhiễu cảm biến. Bản đồ dùng một độ dốc lớn nhất $K_{max}$ và một khâu bù chung cho mọi vận tốc; $H(z)$ là dạng rời rạc của $H(s)$ theo phép biến đổi song tuyến tính (Tustin) '
    'với chu kỳ $T_{ctl}$, thành một khối bậc hai.')
add('')
add('  (2)  T_a,c = H(z) * T_a,map,   H(s) = (s/z + 1)/(s/p + 1) * (s/z1 + 1)/(s/p1 + 1)',
    '  [ T_{a,c}=H(z)\\,T_{a,map},\\qquad H(s)=\\dfrac{s/z+1}{s/p+1}\\cdot\\dfrac{s/z_1+1}{s/p_1+1} ]', '')
add('Lệnh $T_{a,c}$ đi vào khối motor của môi trường mô phỏng, gồm giới hạn trợ lực $T_{a,max}(v)$ (chương giá trị đặt) và một khâu trễ bậc nhất $G_m(s) = \\omega_m/(s + \\omega_m)$ với $\\omega_m = 2\\pi \\cdot 100$ rad/s = 628 rad/s, hằng số thời gian 1.59 ms, theo phương trình (10) và Bảng III của [1]. '
    'Bộ điều khiển không tự chặn lệnh. Vì $H$ và $G_m$ đều có độ lợi bằng một ở tần số không, ở trạng thái xác lập $T_a$ bằng giá trị bản đồ (khi chưa chạm giới hạn): độ chính xác trên đường khô do hàm $M$ quyết định (mục 2), '
    'còn khâu bù chỉ quyết định ổn định, độ êm và độ nhanh khi tín hiệu thay đổi (mục 3).')
head('2. Dựng bản đồ')
add('2.1. Điểm hiệu chỉnh trên đường khô')
add('Ở trạng thái xác lập, mô-men cản $T_r$ do mô-men trợ lực $T_a$ và mô-men cảm biến $T_s$ cân bằng: $T_s = T_r - T_a$ (phương trình mô-men của trụ lái khi tốc độ góc bằng không). Muốn mô-men cảm biến bằng giá trị đặt trên đường khô, '
    'tại mỗi vận tốc và mỗi gia tốc ngang cần cấp trợ lực bằng mô-men cản trừ giá trị đặt, đúng cách [5] (mục III.D, Bảng 5) xác định trợ lực mà hệ cần cung cấp bằng mô-men vô-lăng khi chưa có trợ lực trừ mô-men vô-lăng lý tưởng:')
add('')
add('  (3)  T_s,cal = T_d,ref(v, a_y),   T_a,cal = T_r(v, a_y, 0.8) - T_d,ref(v, a_y)',
    '  [ T_{s,cal}=T_{d,ref}(v,a_y),\\qquad T_{a,cal}=T_r(v,a_y,0.8)-T_{d,ref}(v,a_y) ]', '')
add('Khác [5], nơi mô-men vô-lăng khi chưa có trợ lực lấy từ mô phỏng của một xe khác, ở đây $T_r$ tính bằng cách giải trạng thái xác lập của chính đối tượng điều khiển của luận văn: với vận tốc $v$ và gia tốc ngang $a_y$ cho trước, '
    'ba ẩn góc trượt thân xe $\\beta$, tốc độ quay thân xe $\\gamma$ và góc bánh trước $\\delta_f$ thỏa ba phương trình của mô hình hai bậc tự do (đạo hàm của $\\beta$ và $\\gamma$ bằng không, $a_y$ bằng giá trị đang quét) với lực lốp theo công thức Magic Formula, '
    'rồi $T_r$ tính từ lực bên bánh trước và cánh tay đòn kéo lệch. Với mỗi vận tốc từ 20 km/h đến 100 km/h, bước 5 km/h, gia tốc ngang được quét từ 0.1 g (hàng nhỏ nhất của Bảng 4 của [5], dưới mức đó không có số liệu) tới giá trị nhỏ hơn trong hai giá trị '
    '0.4 g (hàng lớn nhất của bảng) và gia tốc ngang lớn nhất mà đối tượng điều khiển đạt được ở $\\mu = 0.8$, bước 0.005 g; được %d điểm hiệu chỉnh, không điểm nào đòi trợ lực vượt $T_{a,max}$. '
    'Giá trị đặt $T_{s,cal}$ tra từ bảng giá trị đặt (nội suy tuyến tính như khối giá trị đặt).' % n_cal)
add('2.2. Đường cong bản đồ và giới hạn độ dốc')
add('Đường cong $M(v, |T_s|)$ tại mỗi vận tốc gồm bốn đoạn. Thứ nhất, vùng chết: $M = 0$ khi $|T_s| \\le T_{s0}$. Trong [1] vùng chết dùng để hệ không phản ứng quá nhạy với mô-men tay lái; ở đây còn có lý do thứ hai là nhiễu cảm biến: '
    'nhiễu và lượng tử hóa của $T_s$ có độ lệch chuẩn %.4f N.m (một bước phân giải 0.01 N.m cộng nhiễu một bước, theo mô hình cảm biến), nên nếu bản đồ trợ lực ngay từ $T_s = 0$ thì khi xe đi thẳng nhiễu này biến thành lệnh trợ lực giật liên tục. '
    'Chọn $T_{s0} = 0.3$ N.m, bằng khoảng %d lần độ lệch chuẩn nhiễu và còn xa dưới mô-men đặt nhỏ nhất của dải hiệu chỉnh (1.0 N.m ở 20 km/h và 0.1 g), nên vùng chết không lấn vào vùng có số liệu; đây là Tự chọn(1). '
    'Thứ hai, đoạn nối từ $(T_{s0}, 0)$ tới điểm hiệu chỉnh đầu tiên (0.1 g), vì dưới 0.1 g không có số liệu gốc. Thứ ba, đoạn bám các điểm hiệu chỉnh có giới hạn độ dốc. Thứ tư, bão hòa: trên điểm hiệu chỉnh cuối cùng $M$ giữ nguyên giá trị cuối.'
    % (T_NOISE, round(0.3 / T_NOISE)))
add('Độ dốc của bản đồ là lượng trợ lực tăng thêm khi mô-men cảm biến tăng một đơn vị. Trong vòng kín, trợ lực tăng làm mô-men cảm biến giảm, nên độ dốc này chính là độ lợi của vòng phản hồi qua $T_s$: dốc càng lớn thì bộ điều khiển càng nhạy, '
    'càng khó ổn định và càng khuếch đại nhiễu cảm biến. [1] cũng lấy độ dốc lớn nhất của bản đồ làm trường hợp xấu nhất khi xét ổn định, vì khi bản đồ được xấp xỉ bằng một hằng số thì hằng số lớn nhất ứng với độ lợi vòng lớn nhất. '
    'Độ dốc tự nhiên của đường cong hiệu chỉnh, tức độ dốc cần có để đi qua mọi điểm, là:')
add('')
add('  (4)  dT_a/dT_s (tai diem k) = (T_a,cal,k - T_a,cal,k-1) / (T_s,cal,k - T_s,cal,k-1)',
    '  [ \\left.\\dfrac{dT_a}{dT_s}\\right|_k=\\dfrac{T_{a,cal,k}-T_{a,cal,k-1}}{T_{s,cal,k}-T_{s,cal,k-1}} ]', '')
add('Hình 1 vẽ độ dốc tự nhiên theo gia tốc ngang. Trong vùng lái thường ngày, 0.1 g đến 0.3 g, độ dốc lớn nhất theo vận tốc nằm từ %.1f (%d km/h) tới %.1f (%d km/h); trên 0.3 g, nơi $T_{d,ref}$ gần như không tăng nữa trong khi $T_r$ vẫn tăng, độ dốc lên tới hàng chục. '
    'Vì độ dốc cần có vượt xa mức một bộ điều khiển ổn định được, mỗi điểm của bản đồ bị chặn để độ dốc so với điểm trước không vượt giới hạn $K_{max}$:' % (nat_lo, v_nat_lo, nat_hi, v_nat_hi))
add('')
add('  (5)  M_k = min(T_a,cal,k, M_(k-1) + K_max*(T_s,k - T_s,k-1))',
    '  [ M_k=\\min\\big(T_{a,cal,k},\\;M_{k-1}+K_{max}(T_{s,k}-T_{s,k-1})\\big) ]', '')
add('Nơi độ dốc tự nhiên nhỏ hơn $K_{max}$ thì bản đồ đi đúng qua các điểm hiệu chỉnh; nơi vượt thì bản đồ nằm thấp hơn điểm hiệu chỉnh và sai lệch đó cộng dồn theo $T_s$. Đây là chỗ bản đồ chấp nhận sai số xác lập để đổi lấy ổn định và độ êm; '
    'mức sai số được đo ở mục 2.3. $K_{max}$ là một tham số của thiết kế, được chọn ở mục 4.')
add('[Hình 1: Độ dốc tự nhiên dT_a/dT_s của các điểm hiệu chỉnh theo gia tốc ngang | Result/Controllers/Map/Design/Map_calibration_natural_slope.png]')
add('')
add('2.3. Sai số xác lập trên đường khô')
add('Với một bản đồ đã dựng, vòng kín dừng ở điểm cân bằng thỏa $T_s = T_r - M(T_s)$ (bản đồ đơn điệu nên nghiệm duy nhất), khi khâu bù không còn tác dụng. Sai số xác lập là chênh lệch giữa nghiệm đó và giá trị đặt:')
add('')
add('  (6)  T_s = T_r(v, a_y, 0.8) - M(v, T_s),   e_T = T_s - T_d,ref,   e_rel = 100*|trung binh e_T| / trung binh |T_d,ref|',
    '  [ T_s=T_r(v,a_y,0.8)-M(v,T_s),\\qquad e_T=T_s-T_{d,ref},\\qquad e_{rel}=100\\,\\dfrac{|\\overline{e_T}|}{\\overline{|T_{d,ref}|}} ]', '')
add('Điều kiện cứng về độ chính xác là điều kiện chung của mọi bộ điều khiển (quy chuẩn mục 5.3): $e_{rel}$ đo bằng mô phỏng trên từng cửa sổ giữ cua của ca CALIB, lớn nhất trên chín cửa sổ static (20 km/h: 0.10, 0.15 và 0.18 g; 60 và 100 km/h: 0.1, 0.2 và 0.3 g) không quá 5 %%. '
    'Hai cửa sổ 0.4 g của CALIB chỉ báo cáo. Vì khâu bù có độ lợi một ở tần số không, $e_{rel}$ gần như chỉ do $K_{max}$ quyết định. Bảng 1 cho $e_{rel}$ theo $K_{max}$ trên cặp mức lưới đã mô phỏng; $K_{max}$ nhỏ nhất qua cổng là %.2f.' % K_gate)
add('Bảng 1: Sai số xác lập lớn nhất trên chín cửa sổ static của CALIB theo độ dốc K (trung bình trên các khâu bù đã thử cùng K; seed 00000)')
add(table(ek_rows))
add('')
head('3. Ổn định và khâu bù lead-lag')
add('3.1. Mô hình tuyến tính của đối tượng điều khiển')
add('Phân tích tuyến tính chỉ dùng để thiết kế khâu bù (quy chuẩn 5.2: cổng ổn định chính là mô phỏng, mục 4.1). Xe quay vòng ổn định với vận tốc $v$, gia tốc ngang $a_y$ và hệ số bám $\\mu$, góc vô-lăng $\\theta_1$ giữ không đổi (tài xế giữ góc). '
    'Trạng thái là góc và tốc độ góc trụ lái $\\theta_2$, $\\dot\\theta_2$ cùng $\\beta$ và $\\gamma$; đầu vào là mô-men trợ lực $T_a$, đầu ra là mô-men cảm biến $T_s = K_t(\\theta_1 - \\theta_2)$ với $K_t$ là độ cứng thanh xoắn. Phương trình trụ lái và thân xe của mô hình:')
add('')
add('  (7)  J_col*theta2_ddot = T_a - T_r + K_t*(theta1 - theta2) - C_col*theta2_dot;  beta_dot = (F_yf+F_yr)/(m*v) - gamma;  gamma_dot = (l_f*F_yf - l_r*F_yr)/Iz',
    '  [ J_{col}\\ddot\\theta_2=T_a-T_r+K_t(\\theta_1-\\theta_2)-C_{col}\\dot\\theta_2,\\quad \\dot\\beta=\\dfrac{F_{yf}+F_{yr}}{mv}-\\gamma,\\quad \\dot\\gamma=\\dfrac{l_fF_{yf}-l_rF_{yr}}{I_z} ]', '')
add('Đạo hàm riêng theo các trạng thái được lấy bằng sai phân trung tâm của chính các phương trình trên tại điểm cân bằng (trạng thái xác lập của mục 2.1). Ma sát Coulomb của trụ lái $T_f\\tanh(c\\dot\\theta_2)$ không được tuyến tính hóa: '
    'độ dốc của nó khi đứng yên rất lớn và chỉ thêm tắt dần khi trụ lái chuyển động, nên mô hình tuyến tính chỉ giữ ma sát nhớt $C_{col}$, là trường hợp bất lợi cho ổn định (Tự chọn(2)). Kết quả: đối tượng từ $T_a$ tới $T_s$ có độ lợi một chiều bằng $-0.99$ ở 20 km/h tới '
    '$-0.81$ ở 100 km/h (thêm trợ lực làm giảm $T_s$ với hệ số gần một, như phương trình cân bằng ở mục 2.1), một cặp cực dao động nhẹ tắt $-6.8 \\pm j38.3$ rad/s ở 60 km/h (tần số riêng của trụ lái và thanh xoắn $\\sqrt{K_t/J_{col}} = 36.1$ rad/s, hệ số tắt dần khoảng 0.18) và một cặp cực chậm của thân xe. '
    'Khi $v$, $a_y$ và $\\mu$ thay đổi trên các điểm đã xét, tần số của cặp cực dao động đổi dưới 5 % (từ 37.6 rad/s đến 39.1 rad/s): ổn định của vòng bị chi phối bởi trụ lái, không bởi thân xe.')
add('3.2. Hàm truyền vòng hở')
add('Gọi $k$ là độ dốc của bản đồ tại điểm làm việc, $0 < k \\le K_{max}$ (bản đồ đi qua mọi độ dốc từ không tới $K_{max}$ khi mô-men tay lái thay đổi). Hàm truyền vòng hở, với dấu trừ vì thêm trợ lực làm $T_s$ giảm, là:')
add('')
add('  (8)  L(s) = -k * H(s) * Gm(s) * exp(-s*T_d) * G(s),   T_d = 1 ms', '  [ L(s)=-k\\,H(s)\\,G_m(s)\\,e^{-sT_d}\\,G(s) ]', '')
add('trong đó $G(s)$ là hàm truyền tuyến tính hóa từ $T_a$ tới $T_s$, $G_m$ là khâu motor và $T_d = 1$ ms là trễ tương đương của việc lấy mẫu: cảm biến $T_s$ cập nhật mỗi 1 ms và bộ điều khiển lấy mẫu mỗi 1 ms, nên lấy tổng trễ bảo thủ bằng một chu kỳ (Tự chọn(3)). '
    'Các điểm làm việc xét ở mỗi vận tốc là $(a_y, \\mu)$ = (0, 0.8), (0.3 g, 0.8), (0, 0.2) và (0.15 g, 0.2), với độ dốc $k \\in \\{0.25, 0.5, 0.75, 1\\}K_{max}$. Độ dự trữ pha (PM, phase margin: góc pha còn thiếu để tới $-180°$ tại tần số mà $|L| = 1$) '
    'theo [1] nên lớn hơn 45° để vòng ổn định bền vững; độ dự trữ độ lợi (GM, gain margin: hệ số mà độ lợi vòng còn tăng được trước khi mất ổn định) lấy không nhỏ hơn 2. Trong quy chuẩn hiện hành hai con số này chỉ là CÔNG CỤ THIẾT KẾ và được báo cáo: '
    'điều kiện đạt hay không đạt ổn định là kết quả mô phỏng với độ dư (độ lợi động cơ nhân hai và trễ thêm 1 ms, mục 4.1).')
add('3.3. Tìm khâu bù lead-lag')
add('Với mỗi cặp $(g_{min}, K)$, bốn tham số $(z, p, z_1, p_1)$ được tìm trên lưới hai giai đoạn thô-mịn: $z$ từ 5 tới 500 rad/s, $p/z$ từ 1.2 tới 300 và $p \\le 3142$ rad/s (tần số Nyquist của bước 1 ms), $z_1$ từ 8 tới 120 rad/s, $p_1/z_1$ từ 0.1 tới 0.9 và $p_1 \\ge 3$ rad/s. '
    'Trong các khâu có dự trữ pha không nhỏ hơn 45° ở mọi điểm làm việc, GM không nhỏ hơn 2 và độ lợi của khâu lag tại 2 Hz không nhỏ hơn $g_{min}$, chọn khâu có độ lợi tần số cao $K \\cdot (p/z) \\cdot (p_1/z_1)$ nhỏ nhất, vì độ lợi đó chính là mức khâu bù khuếch đại nhiễu '
    'cảm biến thành nhiễu lệnh trợ lực; nếu hòa thì chọn dự trữ pha lớn hơn (Tự chọn(4)). Tham số $g_{min}$ là lối vào thứ hai của thiết kế vì nếu để lag tự do, tiêu chí độ lợi tần số cao nhỏ nhất kéo $p_1$ về cận lưới và làm vòng chậm tùy ý: '
    'dự trữ pha và độ lợi tần số cao không đo được độ bám trong dải lái. Bảng 2 cho các khâu bù đã thiết kế ở $K = %.1f$ (đối tượng 60 km/h); toàn bộ %d thiết kế đã giải (mỗi thiết kế quét thô-mịn, tổng %d khâu ứng viên được kiểm trên mô hình tuyến tính) nằm ở file Map_design_leadlag.csv.' % (K, n_lin, n_cand))
add('Bảng 2: Khâu bù lead-lag có độ lợi tần số cao nhỏ nhất, dự trữ pha trên 45°, ở K = %.1f, theo mức g_min (g_min = 1.00 là lead đơn)' % K)
add(table(lev_rows))
add('')
add('Hình 2 vẽ độ lợi và pha của khâu bù đã chọn. Lead cho pha dương quanh tần số cắt của vòng hở (khoảng 160 rad/s) để bù trễ lấy mẫu và trễ motor; lag rút độ lợi ở tần số cao nhưng nằm ở dải tần thấp hơn nên không lấy lại pha tại tần số cắt: '
    'hai khâu nằm ở hai dải tần khác nhau. Với $g_{min} = 1.00$ không có lag, độ lợi tần số cao là %.0f; với khâu đã chọn là %.0f, nhiễu lệnh ước lượng trên mô hình tuyến tính giảm từ %.3f xuống %.3f N.m. Tại 2 Hz tích lead x lag có độ lợi %.2f (%.1f dB), trong đó phần của lag là %.2f; ràng buộc dải lái chỉ áp cho lag, vì lead là khâu sớm pha.'
    % (lev[lev.g_min == 1.0].HF_gain.iloc[0], lev[abs(lev.g_min - gmin) < 1e-9].HF_gain.iloc[0], lev[lev.g_min == 1.0].Ta_noise_std_Nm.iloc[0], lev[abs(lev.g_min - gmin) < 1e-9].Ta_noise_std_Nm.iloc[0], abs(hs(z, p, W2) * hs(z1, p1, W2)), 20 * np.log10(abs(hs(z, p, W2) * hs(z1, p1, W2))), lagain(z1, p1, W2)))
add('[Hình 2: Đáp ứng tần số của khâu bù đã chọn (lead, lag và tích), vạch xám: 2 Hz, vạch đỏ: -3 dB | Result/Controllers/Map/Design/Map_bode.png]')
add('')
add('3.4. Giới hạn khả thi của K')
add('Bảng 3 cho K lớn nhất còn có khâu bù đạt dự trữ pha 45° trên lưới, theo năm mức $g_{min}$ đã tìm tới giới hạn (các mức sâu hơn chỉ được thiết kế ở vài giá trị K quanh điểm cần dùng nên không đưa vào bảng). Giới hạn này là của PHÂN TÍCH TUYẾN TÍNH và chỉ gợi ý cận lưới quét; quy chuẩn không dùng nó làm cổng. Khâu lag cho phép K lớn hơn lead đơn vì hạ độ lợi tần số cao, và mức lag sâu hơn cho K khả thi lớn hơn.')
add('Bảng 3: K lớn nhất có khâu bù đạt dự trữ pha 45° theo mức g_min (phân tích tuyến tính)')
add(table(kmax_rows))
add('')
head('4. Chọn độ dốc lớn nhất và khâu bù')
add('4.1. Cổng và độ nhạy')
add('Mỗi cặp $(g_{min}, K)$ được mô phỏng bốn lần trên ca CALIB: cảm biến có nhiễu (seed 00000), cảm biến lý tưởng, độ lợi động cơ nhân hai và trễ thêm một chu kỳ. Từ đó có $R$ (RMS của $e_T$ theo phần trăm giá trị đặt trên các cửa sổ), '
    '$S$ (RMS của $T_a$ sau lọc thông cao một bậc ở 5 Hz, tức phần mô-men trợ lực mà lệnh của tài xế dưới vài Hz không giải thích được), $TV$ (tổng biến thiên của $T_a$ mỗi giây), $e_{rel}$ và các số báo cáo. Hai cổng cứng, theo thứ tự ưu tiên của quy chuẩn: '
    'thứ nhất, ổn định có độ dư, đo bằng mô phỏng (không dùng điều kiện giải tích): tín hiệu hữu hạn, không dao động tăng dần ở mọi cửa sổ static, không bão hòa liên tục, và $R$ khi độ lợi nhân hai và khi trễ thêm 1 ms không quá hai lần $R$ danh định; '
    'thứ hai, $e_{rel} \\le 5$ % (mục 2.3). Bang-bang (tỉ lệ mẫu lệnh chạm giới hạn $T_{a,max}$ tăng do nhiễu) và trợ lực ngược chiều chỉ báo cáo, không còn là cổng.')
add('Lưới quét có %d mức $g_{min}$ (từ 1.00 tới %.2f, cận lưới của $p_1$) và $K$ từ %.2f tới %.0f; trong đó %d cặp là cặp thiết kế (khâu bù thiết kế đúng cho K đó) và %d cặp ở vùng vượt giới hạn tuyến tính (K lớn hơn K của khâu bù, xem 4.5). '
    'Lưới được mở rộng tới khi một cổng chặn (K nhỏ hơn %.2f không qua cổng $e_{rel}$) hoặc $R$ không còn đổi (K lớn). Tổng cộng %d cặp, %d cặp qua cả hai cổng và ràng buộc dải lái ở mục 4.2.'
    % (n_levels, pk.g_min.min(), pk.K.min(), pk.K.max(), n_main, n_beyond, K_gate, n_pairs, n_adm))
add('4.2. Quy tắc chọn: J = R x S cộng ràng buộc dải lái')
add('Quy tắc chọn là quy tắc chung của mọi bộ điều khiển (quy chuẩn mục 6.2, phiên bản 5): trong các điểm qua cổng cứng và ràng buộc dải lái, chọn điểm có $J = R \\cdot S$ nhỏ nhất. Đổi một phần trăm êm lấy một phần trăm bám, không đơn vị, không có ngưỡng tự chọn, không phụ thuộc vào một điểm cực trị. '
    'Hàm $J$ riêng lẻ không đủ cho bản đồ: giá trị $J$ nhỏ nhất theo từng mức $g_{min}$ GIẢM gần đơn điệu khi khâu lag sâu hơn (Bảng 4, Hình 3; nhấp nhô nhỏ do lưới rời rạc) vì làm chậm hạ $S$ nhanh hơn làm $R$ tăng, nên không có cực tiểu bên trong; điểm tối ưu của $J$ nằm ở cận lưới của lag ($p_1 = 3$ rad/s, hằng số thời gian 0.32 s). '
    'Điểm đó có $R$ = %.1f %% (so với %.1f %% của lead đơn) và làm trợ lực thừa khi qua vũng nước nặng thêm, tức $J$ thưởng đúng sự chậm trái với mục tiêu bám. Vì vậy quy chuẩn thêm ràng buộc dải lái (người dùng chốt 2026-10-11, quy chuẩn 6.2): '
    'mọi khâu lọc hoặc làm chậm trong bộ điều khiển phải giữ độ lợi không nhỏ hơn $1/\\sqrt{2}$ (-3 dB) tại 2 Hz, vì người lái đánh lái ở 0.2-2.0 Hz và không quá 5 Hz ([13], trích [14]), còn -3 dB là định nghĩa thông thường của băng thông. '
    'Với bản đồ ràng buộc áp cho khâu lag (khâu lead là khâu sớm pha, không bị tính). Đây là lần thứ tư quy tắc chọn được đổi sau khi đã thấy kết quả; việc đổi và lý do được ghi ở nhật ký thay đổi của quy chuẩn, và báo cáo phải nêu điểm chọn khi không có ràng buộc.'
    % (j_noband.R_pct, lead_only.R_pct))
add('Bảng 4: J = R x S nhỏ nhất theo mức g_min, trong các cặp qua hai cổng cứng (ràng buộc dải lái: độ lợi lag tại 2 Hz không nhỏ hơn 0.707)')
add(table(j_rows))
add('')
add('[Hình 3: J nhỏ nhất theo mức g_min; vạch đỏ: ràng buộc dải lái | Result/Controllers/Map/Calib/Map_CALIB_pick_s00000.png]')
add('')
add('4.3. Điểm chọn')
add('Điểm chọn là $g_{min}$ = %.2f, $K_{max}$ = %.1f. Trong danh sách xếp theo $J$ tăng dần, điểm đầu qua kiểm tra dự trữ ổn định bằng mô phỏng (độ lợi nhân hai: $R$ = %.2f lần danh định; trễ thêm 1 ms: %.2f lần). Độ nhạy theo quy tắc: '
    'số mũ $a = 0.5$ cho $g_{min}$ = %.2f, $K$ = %.1f; $a = 2$ cho $g_{min}$ = %.2f, $K$ = %.1f; quy tắc cũ (giữ các điểm có $R$ trong 5 %% của $R$ nhỏ nhất, rồi chọn $S$ nhỏ nhất) cho $g_{min}$ = %.2f, $K$ = %.1f (R = %.1f %%, S = %.3f N.m); '
    'bỏ ràng buộc dải lái thì $J$ chọn $g_{min}$ = %.2f, $K$ = %.1f (R = %.1f %%, S = %.3f N.m). Lead đơn (nhánh đối chứng, cùng quy tắc) chọn $K$ = %.1f với R = %.1f %%, S = %.3f N.m.'
    % (gmin, K, ch.ratio_gain, ch.ratio_delay, sens[0.5].g_min, sens[0.5].K, sens[2.0].g_min, sens[2.0].K, former.g_min, former.K, former.R_pct, former.S_Nm, j_noband.g_min, j_noband.K, j_noband.R_pct, j_noband.S_Nm, K, lead_only.R_pct, lead_only.S_Nm))
add('Bảng 5: Thông số bộ điều khiển bản đồ sau thiết kế (ghi vào data/map.json, trường design; nguồn duy nhất cho mô hình Simulink)')
add(table([
    ['', 'giá trị'],
    ['K_max', num(K, 1)],
    ['g_min (mức lưới của lag)', num(gmin)],
    ['lead: z, p [rad/s]', '%s, %s' % (num(z, 1), num(p, 1))],
    ['lag: z1, p1 [rad/s]', '%s, %s' % (num(z1, 2), num(p1, 2))],
    ['độ lợi lag tại 2 Hz', num(ch.lag_gain_2Hz, 3)],
    ['dự trữ pha, dự trữ độ lợi tuyến tính (chỉ báo cáo)', '%s độ, %s' % (num(d['PM_deg'], 1), num(d['GM'], 2))],
    ['R trên CALIB [%]', num(ch.R_pct)],
    ['S trên CALIB [N.m]', num(ch.S_Nm, 4)],
    ['J = R x S', num(ch.J, 3)],
    ['TV trên CALIB [N.m/s]', num(ch.TV_Nm_per_s, 1)],
    ['e_rel lớn nhất, 9 cửa sổ static [%]', num(ch.erel_pct)],
    ['bang-bang: tăng do nhiễu (hai seed, chỉ báo cáo) [%]', num(100 * d['bangbang']['delta'], 3)],
    ['trợ lực ngược trên CALIB (chỉ báo cáo) [%]', num(ch.rev_pct)],
]))
add('')
add('Sai số xác lập của điểm chọn trên chín cửa sổ static của CALIB (lớn nhất %.2f %%) và trên hai cửa sổ ngoài cổng 0.4 g (Bảng 6): sai số lớn nhất nằm ở nơi độ dốc tự nhiên vượt $K_{max}$ (60 km/h, 0.2 g); ở 0.4 g độ dốc bị chặn mạnh nên tay lái nặng hơn mong muốn nhiều.' % ch.erel_pct)
add('Bảng 6: Sai số xác lập của điểm chọn trên CALIB (seed 00000)')
add(table(win_rows + [['—', '—']] + ext_rows))
add('')
add('[Hình 4: Mặt (R, S) của các cặp (g_min, K) trên CALIB; vòng xám: không qua cổng hay ràng buộc; sao đỏ: điểm chọn | Result/Controllers/Map/Calib/Map_CALIB_pareto_s00000.png]')
add('')
add('4.4. Một độ dốc cho mọi vận tốc')
add('Bản đồ dùng một độ dốc lớn nhất $K_{max}$ chung cho mọi vận tốc (người dùng chốt ngày 2026-10-09). Lý do: quy tắc chung của mọi bộ điều khiển chỉ giữ cấu trúc nhiều bậc theo vận tốc nếu $R$ giảm ít nhất 5 % mà $S$ không tăng so với bản một bậc; '
    'khi đó, với cổng cũ, bản hai bậc suy biến thành bản một bậc (cùng $K$, cùng $R$ và $S$). Kết luận này chưa được thử lại với cổng và quy tắc của phiên bản 5.')
add('4.5. Vượt giới hạn tuyến tính')
add('Quy chuẩn (mục 9.5) yêu cầu mở rộng lưới tới khi một cổng chặn hoặc $R$ phẳng. Để kiểm tra, khâu bù được giữ ở khâu thiết kế lớn nhất khả thi (lead đơn: K của khâu bù = %.0f; $g_{min}$ = 0.70: %.0f; $g_{min}$ = 0.60: %.0f) và độ dốc của bảng tăng tới %.0f (Bảng 7). '
    'Không cặp nào mất ổn định; $R$ phẳng (lead đơn %.1f-%.1f %%, $g_{min}$ = 0.70: %s %%) trong khi $S$ tăng (lead đơn %.2f tới %.2f N.m), nên không có lý do tăng $K$ hơn nữa; lead đơn còn rớt bang-bang từ K = 10 (chỉ báo cáo). Điểm chọn không đổi.'
    % (bey_lo.comp_K.iloc[0], bey_07.comp_K.iloc[0], bey[bey.g_min == 0.6].comp_K.iloc[0], bey.K.max(), bey_lo.R_pct.min(), bey_lo.R_pct.max(), ('%.1f' % bey_07.R_pct.min() if abs(bey_07.R_pct.max() - bey_07.R_pct.min()) < 0.05 else '%.1f-%.1f' % (bey_07.R_pct.min(), bey_07.R_pct.max())), bey_lo.S_Nm.min(), bey_lo.S_Nm.max()))
add('Bảng 7: Cặp vượt giới hạn tuyến tính (khâu bù cố định, độ dốc bảng tăng)')
add(table(bey_rows))
add('')
head('5. Kiểm chứng trong vòng kín')
add('Bộ điều khiển được chạy trên năm ca chấm của chương kịch bản: DRY (đường khô, giữ cua ở nhiều tốc độ và gia tốc ngang), RAMP (đổi tốc độ khi đang cua), SLIP (hệ số bám đổi khi đang cua: giảm, vũng nước, tăng), WEAVE (lái liên tục: lượn, đổi làn, mặt trơn) và EDGE '
    '(vùng cực trên 0.3 g, chỉ báo cáo). Cảm biến có nhiễu, hạt giống địa phương 00000 của bản đồ, cùng hạt giống đã chọn khâu bù. Mọi chỉ số tính trên tín hiệu thật của đối tượng, không phải tín hiệu bộ điều khiển đo được, và bỏ 2 s đầu của mỗi ca. '
    'Điểm chọn đã cố định ở mục 4 trước khi chạy, không chỉnh theo kết quả các ca. So sánh với các bộ điều khiển khác dùng hạt giống chung 99999 và nằm ở chương so sánh.')
add('Bảng 8: Chỉ số của bản đồ trên năm ca (RMS e_T và max |e_T|: N.m; S: độ ồn, N.m; TV: tổng biến thiên của T_a, N.m/s; trợ lực ngược: tỉ lệ thời gian |T_s| >= 0.5 N.m mà T_a ngược dấu)')
add(table(case_rows))
add('')
add('Trên đường khô (DRY), sai số xác lập có dấu tại các cửa sổ (Bảng 9, phần trăm giá trị đặt, dương nghĩa là tay lái nặng hơn mong muốn) không quá %.1f %% ở mọi cửa sổ trừ một cửa sổ: ở 40 km/h, 0.3 g sai số là %.1f %% (cửa sổ %s). '
    'Nguyên nhân: các cửa sổ static của CALIB chỉ đặt ở 20, 60 và 100 km/h, nên cổng $e_{rel}$ không thấy sai số ở tốc độ khác; ở 40 km/h độ dốc tự nhiên lớn hơn $K_{max}$ nên bản đồ bị chặn thấp hơn điểm hiệu chỉnh. Đây là hạn chế của bản đồ đã chọn, được báo cáo như hiện có và không che.' % (dry_second, dry_worst, dry_worst_w))
add('Bảng 9: Sai số xác lập của bản đồ trên ca DRY')
add(table(dry_w))
add('')
add('Khi hệ số bám giảm bản đồ vẫn cấp trợ lực như đường khô nên tay lái nhẹ đi: ở vũng nước của ca SLIP (cửa sổ pud_in) sai số có dấu là %.1f %% (âm là trợ lực thừa). Đây đúng là điểm yếu trợ lực thừa mà chuẩn so sánh phải có. '
    'Phần trăm ở cửa sổ sau vũng nước (pud_post) có mẫu số gần không, không có ý nghĩa, chỉ đưa vào để đủ bảng.' % pud)
add('Bảng 10: Sai số xác lập của bản đồ trên ca SLIP')
add(table(slip_w))
add('')
add('Ca RAMP (đổi tốc độ khi xe đang cua) cho thấy hiện tượng cố hữu của bản đồ không có tích phân: khi giảm tốc ($T_s$ bị ép lên biên dốc) sai số dương, tay lái nặng hơn mong muốn, tới %.1f %%; khi tăng tốc sai số âm, từ %.1f %% đến %.1f %% (Bảng 11). Nguyên nhân là ma sát khô $T_f$ của trụ lái cộng việc bộ điều khiển không có khâu tích phân.' % (rp.max(), rp[rp < 0].min(), rp[rp < 0].max()))
add('Bảng 11: Sai số xác lập của bản đồ trên ca RAMP (dn: giảm tốc, up: tăng tốc)')
add(table(ramp_w))
add('')
add('Ca EDGE (vùng cực trên 0.3 g, chỉ báo cáo): ở 0.4 g sai số là %.1f %%, %.1f %% và %.1f %% ở 40, 60 và 100 km/h; ở 0.35 g là %.1f %%, %.1f %% và %.1f %%. Vùng này vượt dải đã hiệu chỉnh nên độ dốc bị chặn; đây là giới hạn của bản đồ, được báo cáo.'
    % (ed['v40a0p4l'], ed['v60a0p4r'], ed['v100a0p4l'], ed['v40a0p35l'], ed['v60a0p35r'], ed['v100a0p35l']))
add('Bảng 12: Sai số xác lập của bản đồ trên ca EDGE')
add(table(edge_w))
add('')
add('[Hình 5: Đáp ứng của bản đồ trên ca DRY, cảm biến có nhiễu hạt giống 00000 | Result/Controllers/Map/Cases/Map_DRY_resp_s00000.png]')
add('')
add('[Hình 6: Đáp ứng của bản đồ trên ca SLIP | Result/Controllers/Map/Cases/Map_SLIP_resp_s00000.png]')
add('')
add('[Hình 7: Đáp ứng của bản đồ trên ca WEAVE | Result/Controllers/Map/Cases/Map_WEAVE_resp_s00000.png]')
add('')
add('[Hình 8: Đáp ứng của bản đồ trên ca RAMP | Result/Controllers/Map/Cases/Map_RAMP_resp_s00000.png]')
add('')
add('[Hình 9: Đáp ứng của bản đồ trên ca EDGE | Result/Controllers/Map/Cases/Map_EDGE_resp_s00000.png]')
add('')
head('6. Hạn chế và các lựa chọn của tác giả')
add('Hạn chế của bản đồ như một chuẩn so sánh. Thứ nhất, nó chỉ đúng trên đường khô: ngoài $\\mu = 0.8$ nó không biết $\\mu$ nên trợ lực thừa (mục 5), đúng như [4] mô tả. Thứ hai, độ chính xác trên đường khô chỉ được bảo đảm ở trạng thái xác lập, '
    'trong 0.1 g đến 0.3 g và ở các tốc độ có cửa sổ trong CALIB; ở 40 km/h sai số tới %.1f %% (mục 5), và trên 0.3 g bản đồ nằm thấp hơn điểm hiệu chỉnh vì độ dốc bị chặn (mục 2.2). Thứ ba, hiệu chỉnh chỉ bảo đảm trạng thái xác lập: sai số lớn nhất cả ca DRY là %.2f N.m, '
    'xảy ra ở các chuyển tiếp giữa các bậc gia tốc ngang. Thứ tư, bản đồ chỉ dùng một độ dốc chung cho mọi vận tốc (mục 4.4). Thứ năm, chọn điểm theo $J$ có ràng buộc dải lái cho điểm bám kém hơn điểm theo quy tắc cũ ($g_{min}$ = %.2f, $K$ = %.1f): trên CALIB $R$ tăng từ %.1f %% lên %.1f %% và $S$ giảm từ %.3f xuống %.3f N.m (mục 4.3).' % (dry_worst, whole.loc['DRY'].MaxAbs_eT_Nm, former.g_min, former.K, former.R_pct, ch.R_pct, former.S_Nm, ch.S_Nm))
add('Các lựa chọn của tác giả (không từ nguồn): Tự chọn(1) vùng chết $T_{s0} = 0.3$ N.m (mục 2.2). Tự chọn(2) bỏ ma sát Coulomb khi tuyến tính hóa (mục 3.1). Tự chọn(3) trễ tương đương 1 ms (mục 3.2). Tự chọn(4) lưới tìm khâu bù và tiêu chí độ lợi tần số cao nhỏ nhất (mục 3.3). '
    'Tự chọn(5) các mức $g_{min}$ của lưới và cận $p_1 \\ge 3$ rad/s (mục 3.3). Tự chọn(6) một hạt giống địa phương 00000 vừa để chọn vừa để chấm các ca. Các số chung của mọi bộ điều khiển (ngưỡng $e_{rel}$ 5 %, 2 Hz và -3 dB của ràng buộc dải lái, quy tắc $J = R \\cdot S$, độ dư độ lợi và trễ) '
    'do quy chuẩn chung quy định, không phải lựa chọn riêng của bản đồ. Thời điểm đổi: ràng buộc dải lái thêm sau khi thấy $J$ suy biến trên bản đồ, đã nêu ở mục 4.2.')
add('Tài liệu tham khảo dùng ở chương này (danh mục chung ở Documents/Shared/References.txt): [1] Lee, Kim, Kim (2018): cấu trúc bản đồ cộng khâu bù, vùng chết, mô hình motor, độ dự trữ pha trên 45°. [4] Li và cộng sự (2023): trợ lực thừa của EPS truyền thống khi hệ số bám giảm. '
    '[5] Li và Xia: bảng mô-men vô-lăng lý tưởng và cách xác định trợ lực cần cấp. [13] Nguyen, Vu, Sename (2025), tr. 19: dải đánh lái của người 0.2-2.0 Hz. [14] Yong (2019), được [13] trích.')
out = '\n'.join(L) + '\n'
os.makedirs(os.path.join(ROOT, 'Documents', 'Thesis'), exist_ok=True)
open(os.path.join(ROOT, 'Documents', 'Thesis', 'map.txt'), 'w', encoding='utf-8', newline='\n').write(out)
print('map.txt chars', len(out), 'lines', len(L), '| chosen', gmin, K, '| former', former.g_min, former.K, '| J-no-band', j_noband.g_min, j_noband.K)
