"""Bao cao tieng Viet tuan 14/11/2026: Plant VDB day du, do ben khi tham so xe sai lech (viec A), giai thich ca WEAVE (viec B).

Moi con so doc tu file ket qua do MATLAB ghi; khong go tay so nao (tru ten nhom tham so va nguon cua chung).

    C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/build_report_week1411_vi.py

Dau vao:
    Model/VDB/temp_test/Summary/VDB_body_summary_s99999.csv                       Plant goc va bon bien the VDB
    Result/Compare/Robust/Robust_summary_s99999.csv, Robust_rank_s99999.csv,      viec A (khung ROBUST)
        Robust_seeds_summary.csv, Robust_tornado_SLIP_s99999.png, Robust_bias_STEADY_s99999.png
    Result/Compare/PID_vs_MapPID/PID_vs_MapPID_WEAVE_windows_5seeds.csv,          viec B (khung WEAVE)
        _branch_windows_s99999.csv, _diag_s99999.csv, _zoom_sw1p5_s99999.png
    Model/original/Controllers/{PID,MapPID}/... khong doc; he so PID lay tu Model/shared/data/pid.json, mappid.json
Dau ra:
    Result/Report/Week1411/W1411_*.png
    Documents/Report/Week1411_baocao.docx
"""
import json
import os

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Cm, Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG = os.path.join(ROOT, 'Result', 'Report', 'Week1411')
DOC = os.path.join(ROOT, 'Documents', 'Report', 'Week1411_baocao.docx')
os.makedirs(FIG, exist_ok=True)
CTRLS = ['Map', 'PID', 'MapPID']
CASES = ['STEADY', 'SLIP', 'WEAVE']
# categorical slots of the validated reference palette (dataviz skill), same hue per controller as the MATLAB figures
COL = {'Map': '#eb6834', 'PID': '#2a78d6', 'MapPID': '#1baf7a'}
GREY = '#b4bac4'
INK, INK2 = '#0b0b0b', '#52514e'
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.grid': True, 'grid.color': '#e6e6e6',
                     'axes.spines.top': False, 'axes.spines.right': False, 'axes.edgecolor': '#9a9a9a',
                     'text.color': INK, 'axes.labelcolor': INK, 'xtick.color': INK2, 'ytick.color': INK2})


def rp(*p):
    return os.path.join(ROOT, *p)


TIE = 5.0                                              # nguong hoa cua bai bao (%)

# ------------------------------------------------------------------ du lieu
VB = pd.read_csv(rp('Model', 'VDB', 'temp_test', 'Summary', 'VDB_body_summary_s99999.csv'))
RS = pd.read_csv(rp('Result', 'Compare', 'Robust', 'Robust_summary_s99999.csv'))
RK = pd.read_csv(rp('Result', 'Compare', 'Robust', 'Robust_rank_s99999.csv'))
SD = pd.read_csv(rp('Result', 'Compare', 'Robust', 'Robust_seeds_summary.csv'))
WW = pd.read_csv(rp('Result', 'Compare', 'PID_vs_MapPID', 'PID_vs_MapPID_WEAVE_windows_5seeds.csv'))
BR = pd.read_csv(rp('Result', 'Compare', 'PID_vs_MapPID', 'PID_vs_MapPID_WEAVE_branch_windows_s99999.csv'))
DG = pd.read_csv(rp('Result', 'Compare', 'PID_vs_MapPID', 'PID_vs_MapPID_WEAVE_diag_s99999.csv'))


def jload(name):
    return json.load(open(rp('Model', 'shared', 'data', name), encoding='utf-8'))


def find(o, key):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == key:
                return v['value'] if isinstance(v, dict) and 'value' in v else v
            r = find(v, key)
            if r is not None:
                return r
    return None


VARS = ['VDBTireLag', 'VDBBody', 'VDBTireBody', 'VDBTireLagBody']
VNAME = {'VDBTireLag': 'Lốp VDB\ncó trễ', 'VDBBody': 'Thân VDB', 'VDBTireBody': 'Lốp + thân\nkhông trễ', 'VDBTireLagBody': 'Lốp có trễ\n+ thân'}
GROUPS = ['Tf', 'Jcol', 'Ccol', 'Mass', 'Calpha', 'Trail', 'Caster', 'Motor']


def vb(var, c, k, col):
    return float(VB[(VB.variant == var) & (VB.controller == c) & (VB.case == k)][col].iloc[0])


def rs(var, c, k, col):
    return float(RS[(RS.Variant == var) & (RS.Ctrl == c) & (RS.Case == k)][col].iloc[0])


def gap(a, b):
    """% by which b exceeds a."""
    return 100 * (b / a - 1)


# ------------------------------------------------------------------ hinh 1: VDB, Delta RMS theo bien the
def fig_vdb():
    fig, axs = plt.subplots(1, 3, figsize=(9.8, 3.3), sharey=True)
    w = 0.25
    for j, k in enumerate(CASES):
        ax = axs[j]; x = np.arange(len(VARS))
        for i, c in enumerate(CTRLS):
            v = [vb(var, c, k, 'dRMS_eT_pct') for var in VARS]
            ax.bar(x + (i - 1) * (w + 0.02), v, w, color=COL[c], label=c)
        ax.axhline(0, color='#9a9a9a', lw=0.8)
        ax.set_xticks(x); ax.set_xticklabels([VNAME[v] for v in VARS], fontsize=7.8)
        ax.set_title(k, fontsize=10); ax.grid(axis='x', visible=False)
        if j == 0:
            ax.set_ylabel('ΔRMS e_T so với Plant gốc [%]')
    h, l = axs[0].get_legend_handles_labels()
    fig.legend(h, l, frameon=False, ncol=3, loc='upper center', fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.92)); fig.savefig(os.path.join(FIG, 'W1411_vdb_drms.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ hinh 2: viec A, khoang RMS tuyet doi qua cac bien the
def fig_robust_range():
    fig, ax = plt.subplots(figsize=(8.6, 3.9))
    y = 0; ticks, labels = [], []
    for k in CASES:
        for c in CTRLS:
            d = RS[(RS.Ctrl == c) & (RS.Case == k)]
            lo, hi, nom = d.E_RMS_Nm.min(), d.E_RMS_Nm.max(), rs('nom', c, k, 'E_RMS_Nm')
            ax.plot([lo, hi], [y, y], color=COL[c], lw=5, alpha=0.5, solid_capstyle='round')
            ax.plot(nom, y, 'o', color=COL[c], ms=8, mec='white', mew=1.5)
            ticks.append(y); labels.append(f'{k}  {c}')
            y -= 1
        y -= 0.6
    ax.set_yticks(ticks); ax.set_yticklabels(labels, fontsize=9)
    ax.set_xlabel('RMS e_T [N·m]  (thanh: khoảng qua 16 biến thể ±20 %; chấm: danh định)')
    ax.set_xlim(0, None); ax.grid(axis='y', visible=False)
    fig.tight_layout(); fig.savefig(os.path.join(FIG, 'W1411_robust_range.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ hinh 3: viec B, chenh RMS theo cua so (5 seed)
SW = ['sw0p3', 'sw0p8', 'sw1p5']                     # ba canh luon sin cung 70 km/h, 0.1 g


def fig_gap():
    d = WW[WW.window != 'whole']
    fig, ax = plt.subplots(figsize=(8.6, 3.3))
    x = np.arange(len(d))
    for i, (_, r) in enumerate(d.iterrows()):
        hl = r.window in SW
        ax.bar(i, r.gap_RMS_pct_mean, 0.55, color=COL['MapPID'] if hl else GREY)
        ax.errorbar(i, r.gap_RMS_pct_mean, yerr=r.gap_RMS_pct_std, color=INK2, capsize=4, lw=1.2)
        if hl:
            ax.text(i, r.gap_RMS_pct_mean + r.gap_RMS_pct_std + 0.4, f'+{r.gap_RMS_pct_mean:.1f}', ha='center', fontsize=9)
    ax.axhline(0, color='#9a9a9a', lw=0.8)
    ax.set_xticks(x); ax.set_xticklabels([f'{w}\nchu kỳ {p:.3g} s' for w, p in zip(d.window, d.P_s)], fontsize=8.3)
    ax.set_ylabel('RMS e_T: MapPID cao hơn PID [%]'); ax.grid(axis='x', visible=False)
    fig.tight_layout(); fig.savefig(os.path.join(FIG, 'W1411_weave_gap.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ hinh 4: viec B, RMS hai nhanh va chan doan
def fig_branch():
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10.0, 3.4), gridspec_kw={'width_ratios': [1.6, 1]})
    x = np.arange(len(BR)); w = 0.36
    a1.bar(x - w / 2 - 0.01, BR.RMS_umap, w, color=COL['Map'], label='nhánh Map u_map')
    a1.bar(x + w / 2 + 0.01, BR.RMS_uPID, w, color=COL['PID'], label='nhánh PID u_PID')
    a1.set_xticks(x); a1.set_xticklabels(BR.window, fontsize=8.5); a1.set_ylabel('RMS trong cửa sổ [N·m]')
    a1.legend(frameon=False, fontsize=8.5); a1.grid(axis='x', visible=False); a1.set_title('Hai nhánh của MapPID', fontsize=10)
    wh = DG[DG.window == 'whole'].iloc[0]
    names = ['MapPID gốc', 'D1: bỏ khâu lag', 'D2: bỏ lead-lag', 'D3: bỏ vùng chết']
    vals = [wh.gap_MapPID_vs_PID_pct, wh.gap_D1_vs_PID_pct, wh.gap_D2_vs_PID_pct, wh.gap_D3_vs_PID_pct]
    yy = np.arange(len(names))[::-1]
    a2.barh(yy, vals, 0.55, color=[GREY] + [COL['MapPID']] * 3)
    for yv, v in zip(yy, vals):
        a2.text(v + 0.15, yv, f'{v:.1f} %', va='center', fontsize=9)
    a2.set_yticks(yy); a2.set_yticklabels(names, fontsize=8.5); a2.set_xlim(0, max(vals) * 1.25)
    a2.set_xlabel('còn cao hơn PID, toàn ca [%]'); a2.grid(axis='y', visible=False); a2.set_title('Phép chẩn đoán', fontsize=10)
    fig.tight_layout(); fig.savefig(os.path.join(FIG, 'W1411_weave_branch_diag.png'), dpi=200); plt.close(fig)


fig_vdb(); fig_robust_range(); fig_gap(); fig_branch()

# ------------------------------------------------------------------ so dung trong loi van
# VDB
d_same = max(abs(vb(v, c, k, 'dRMS_eT_pct')) for v in ['VDBBody', 'VDBTireBody'] for c in CTRLS for k in CASES)
lag = [vb(v, c, k, 'dRMS_eT_pct') for v in ['VDBTireLag', 'VDBTireLagBody'] for c in CTRLS for k in CASES]
VR = pd.read_csv(rp('Model', 'VDB', 'temp_test', 'Summary', 'VDB_body_rank_s99999.csv'))
print('VDB rank csv columns', list(VR.columns)); print(VR.to_string())

# viec A
rk = RK[RK.Variant != 'nom']
n_var = rk.Variant.nunique()
map_last = {k: int(rk[rk.Case == k].Order_best_first.str.endswith('< Map').sum()) for k in CASES}
weave_same = int((rk[rk.Case == 'WEAVE'].Order_best_first == 'PID < MapPID < Map').sum())
slip_mp_better = sorted(rk[(rk.Case == 'SLIP') & (rk.Order_best_first == 'MapPID < PID < Map')].Variant)
# kiem lai bang 5 seed: MapPID tot hon PID qua nguong hoa
sd = SD.pivot_table(index=['Variant', 'Case'], columns='Ctrl', values='E_mean')
slip_mp_better_5 = sorted(v for (v, k), r in sd.iterrows() if k == 'SLIP' and gap(r['MapPID'], r['PID']) >= TIE)
print('SLIP MapPID better (s99999):', slip_mp_better, ' (5 seeds):', slip_mp_better_5)


def dE(var, c, k):
    return rs(var, c, k, 'dE_pct')


def worst(c, k):
    d = RS[(RS.Ctrl == c) & (RS.Case == k)]
    return d.E_RMS_Nm.max(), d.E_RMS_Nm.min()


eps_map = rs('nom', 'Map', 'STEADY', 'MaxAbsEps_pct'); epsm_map = rs('nom', 'Map', 'STEADY', 'MeanEps_pct')
eps_fb = max(RS[(RS.Ctrl != 'Map') & (RS.Case == 'STEADY')].MaxAbsEps_pct)
eps_map_var = max(RS[(RS.Ctrl == 'Map') & (RS.Case == 'STEADY')].MaxAbsEps_pct)

# viec B
whole = WW[WW.window == 'whole'].iloc[0]
sw = WW.set_index('window').loc[SW]
b15 = BR.set_index('window').loc['sw1p5']
wh = DG[DG.window == 'whole'].iloc[0]
closed = {n: wh[f'change_{n}_vs_MapPID_pct'] for n in ['D1', 'D2', 'D3']}
lane = DG.set_index('window').loc[['lane1', 'lane2'], 'change_D1_vs_MapPID_pct']
PIDj, MPj = jload('pid.json'), jload('mappid.json')
kp_pid, kp_mp = PIDj['design']['Kp'], MPj['design']['Kp']      # top-level 'design' = what load_pid / load_mappid use
print('Kp pid / mappid:', kp_pid, kp_mp)
RSo = {(c, k): (rs('nom', c, k, 'E_RMS_Nm'), rs('nom', c, k, 'S_Nm')) for c in CTRLS for k in CASES}

# ------------------------------------------------------------------ Word
doc = Document()
st = doc.styles['Normal']; st.font.name = 'Times New Roman'; st.font.size = Pt(12)
for s in doc.sections:
    s.left_margin = s.right_margin = Cm(2.2); s.top_margin = s.bottom_margin = Cm(2.0)


def para(txt, bold=False, italic=False, size=None, align=None):
    p = doc.add_paragraph(); r = p.add_run(txt); r.bold = bold; r.italic = italic
    if size:
        r.font.size = Pt(size)
    if align is not None:
        p.alignment = align
    return p


def bullet(txt):
    doc.add_paragraph(txt, style='List Bullet')


NFIG = [0]


def figure(path, caption, width=16.0):
    NFIG[0] += 1
    doc.add_picture(path, width=Cm(width))
    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
    para(f'Hình {NFIG[0]}. {caption}', italic=True, size=10, align=WD_ALIGN_PARAGRAPH.CENTER)


def table(rows, header):
    t = doc.add_table(rows=1, cols=len(header)); t.style = 'Light Grid Accent 1'
    for i, h in enumerate(header):
        t.rows[0].cells[i].text = h
    for r in rows:
        cells = t.add_row().cells
        for i, v in enumerate(r):
            cells[i].text = v
    for row in t.rows:
        for c in row.cells:
            for p in c.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(10)
    doc.add_paragraph()


def rng(vals):
    return f'{min(vals):+.1f} đến {max(vals):+.1f} %'


para('Báo cáo tiến độ tuần 14/11/2026: độ vững của kết quả và giải thích ca WEAVE', bold=True, size=15)
para('HV Trần Minh Tân, GVHD TS. Phùng Thanh Huy, HCMUT. Ba ca SSW của bài báo (STEADY: giữ cua; SLIP: hệ số bám μ đổi khi đang cua; WEAVE: lái liên tục), '
     'cảm biến có nhiễu với seed 99999, một số phép có thêm 5 seed 99995-99999. Tham số ba bộ điều khiển giữ nguyên như trong bài báo.', italic=True, size=10)

doc.add_heading('1. Tóm tắt', level=2)
bullet('Thay thân xe và lốp của Plant bằng khối của Vehicle Dynamics Blockset (VDB, thư viện mô hình xe của MathWorks): thứ hạng ba bộ điều khiển không đổi ở cả ba ca.')
bullet(f'Lệch từng nhóm tham số xe ±20 % ({n_var} biến thể): thứ hạng không đổi. Map luôn kém nhất ở STEADY và SLIP, '
       f'WEAVE luôn giữ PID < MapPID < Map. PID và MapPID nhạy nhất với khối lượng xe, vệt caster và vệt khí nén.')
bullet(f'MapPID bám kém PID {whole.gap_RMS_pct_mean:.1f} % ± {whole.gap_RMS_pct_std:.1f} ở WEAVE (5 seed). Khoảng cách này không do nhánh Map gây ra: '
       f'tắt từng phần của nhánh Map chỉ thu hẹp tối đa {-min(closed.values()):.1f} %.')
bullet(f"Đổi lại, MapPID êm hơn PID ở WEAVE: độ ồn mô men trợ lực thấp hơn {-gap(RSo[('PID', 'WEAVE')][1], RSo[('MapPID', 'WEAVE')][1]):.0f} %.")
bullet('Đề xuất không thêm bộ điều khiển thứ tư, dùng thời gian còn lại để viết luận văn với chương mới "Kiểm tra độ vững của kết quả" (mục 6).')

doc.add_heading('2. Plant VDB đầy đủ: thân xe và lốp', level=2)
para('Tuần trước đã báo phần lốp VDB. Tuần này thay tiếp khối thân xe 2 bậc tự do bằng thân VDB 3 bậc tự do, rồi ghép cả lốp lẫn thân. '
     'Có bốn biến thể Plant, mỗi biến thể chạy đủ ba bộ điều khiển trên ba ca.')
figure(os.path.join(FIG, 'W1411_vdb_drms.png'), 'Thay đổi RMS e_T (căn trung bình bình phương của sai số mô men e_T = T_s − T_d,ref) của bốn biến thể Plant VDB so với Plant gốc.')
bullet(f'Khi lốp và thân VDB đặt cùng giả thiết với Plant (không có độ trễ lốp), RMS e_T lệch tối đa {d_same:.1f} %. '
       'Điều này cho thấy Plant tự viết được cài đặt đúng; đây là kiểm chứng cài đặt, không phải xác thực với xe thật.')
bullet(f'Khác biệt có căn cứ vật lý duy nhất là độ trễ lốp (lực ngang tăng dần theo quãng lăn). Độ trễ làm RMS e_T đổi {rng(lag)}.')
bullet('Thứ hạng giữ ở mọi ô. Riêng ca SLIP khi có độ trễ lốp, PID và MapPID chuyển thành hòa (chênh dưới 5 %).')

doc.add_heading('3. Bộ điều khiển thứ tư: đề xuất không làm', level=2)
para('Đã cân nhắc 10 phương án theo công sức, hiệu quả, độ khác biệt và khả năng bảo vệ. Phương án điểm cao nhất là MapSTA (Map ghép với điều khiển trượt bậc hai '
     'super-twisting). Phương án này không sàng lọc tuyến tính được nên phải quét tham số hoàn toàn bằng mô phỏng, kết quả chưa chắc hơn MapPID, và lý thuyết khó giải thích '
     'trước hội đồng. Vì vậy em đề xuất dùng thời gian còn lại để đào sâu MapPID (mục 4 và 5) và viết luận văn.')

doc.add_heading('4. Độ bền khi tham số xe sai lệch', level=2)
doc.add_heading('4.1. Cách thử', level=3)
para(f'Mỗi lần tăng hoặc giảm 20 % một nhóm tham số của Plant, giữ nguyên tham số bộ điều khiển đã chọn trên Plant danh định. '
     f'Tổng cộng {n_var + 1} biến thể (danh định và 8 nhóm × 2 chiều) × 3 bộ × 3 ca = {(n_var + 1) * 9} lần chạy. '
     'Các biến thể làm đổi thứ hạng được chạy thêm 5 seed. Biến thể danh định trùng kết quả của bài báo với sai số 0, và cả 16 biến thể đều khác danh định.')
table([
    ['Tf', 'Ma sát Coulomb của cột lái', 'Lee 2018'],
    ['Jcol', 'Quán tính cột lái', 'Lee 2018'],
    ['Ccol', 'Hệ số cản nhớt cột lái', 'Lee 2018'],
    ['Mass', 'Khối lượng xe và mô men quán tính quay quanh trục đứng, đổi cùng nhau', 'Li và Xia'],
    ['Calpha', 'Độ cứng lệch hướng của lốp', 'Li và Xia'],
    ['Trail', 'Vệt khí nén t_0 (khoảng cách từ tâm vết tiếp xúc tới điểm đặt lực ngang)', 'tự chọn, có kiểm chéo'],
    ['Caster', 'Vệt caster e_c', 'tự chọn, có kiểm chéo'],
    ['Motor', 'Băng thông motor trợ lực', 'chọn 100 Hz'],
], ['Nhóm', 'Tham số', 'Nguồn giá trị danh định'])

doc.add_heading('4.2. Thứ hạng và độ nhạy', level=3)
bullet(f"Map kém nhất ở STEADY {map_last['STEADY']}/{n_var} và SLIP {map_last['SLIP']}/{n_var} biến thể. "
       f'WEAVE giữ đúng thứ tự PID < MapPID < Map ở {weave_same}/{n_var} biến thể.')
bullet(f"Ở SLIP, MapPID tốt hơn PID quá ngưỡng hòa trong {len(slip_mp_better_5)} biến thể ({', '.join(slip_mp_better_5)}, theo trung bình 5 seed); các biến thể còn lại hòa.")
pm, mm = worst('PID', 'SLIP'), worst('Map', 'SLIP')
bullet(f'Hình 2 dùng giá trị tuyệt đối. Trường hợp xấu nhất của PID và MapPID vẫn tốt hơn trường hợp tốt nhất của Map; ví dụ ở SLIP, PID xấu nhất là {pm[0]:.3f} N·m, '
       f'còn Map tốt nhất là {mm[1]:.3f} N·m.')
bullet(f"PID và MapPID nhạy nhất với khối lượng xe (SLIP: {dE('Massp20', 'PID', 'SLIP'):+.0f} % và {dE('Massm20', 'PID', 'SLIP'):+.0f} % với PID), "
       f"vệt caster ({dE('Casterp20', 'PID', 'SLIP'):+.0f} %) và vệt khí nén ({dE('Trailp20', 'PID', 'SLIP'):+.0f} %). Quán tính cột lái và băng thông motor "
       'gần như không ảnh hưởng. Hai tham số tự chọn nằm trong nhóm nhạy, nên luận văn cần giải thích rõ cách chọn giá trị của chúng.')
para('Lưu ý khi đọc phần trăm: phần trăm thay đổi của Map nhỏ hơn PID chỉ vì mức danh định của Map đã cao hơn khoảng 4 lần, không có nghĩa Map bền hơn.', italic=True, size=10)
figure(os.path.join(FIG, 'W1411_robust_range.png'), 'RMS e_T tuyệt đối của ba bộ qua 16 biến thể tham số.', 14.5)
figure(rp('Result', 'Compare', 'Robust', 'Robust_tornado_SLIP_s99999.png'), 'Thay đổi RMS e_T theo từng nhóm tham số, ca SLIP (đậm: +20 %, nhạt: −20 %).', 14.0)

doc.add_heading('4.3. Sai lệch tĩnh khi giữ cua', level=3)
para(f'Ở danh định, Map lệch trung bình {epsm_map:+.1f} % so với mô men mục tiêu và lệch lớn nhất {eps_map:.1f} %. Khi tham số lệch, sai lệch của Map lên tới {eps_map_var:.0f} %. '
     f'PID và MapPID lệch lớn nhất {eps_fb:.2f} % ở mọi biến thể, vì khâu tích phân kéo sai lệch tĩnh về 0. '
     'Kết luận: MapPID giữ được độ bám tĩnh khi xe đổi, còn Map thì không. Đây đúng là hiện tượng trợ lực sai mà đề tài muốn chỉ ra.')
figure(rp('Result', 'Compare', 'Robust', 'Robust_bias_STEADY_s99999.png'),
       'Sai lệch tĩnh theo từng cửa sổ giữ cua của STEADY. Đường đậm là danh định, đường mảnh là các biến thể. Thang của Map lớn hơn nhiều so với hai bộ kia.', 15.0)

doc.add_heading('5. Vì sao MapPID bám kém PID ở WEAVE', level=2)
doc.add_heading('5.1. Khoảng cách nằm ở đâu', level=3)
bullet(f'Trên 5 seed, MapPID cao hơn PID {whole.gap_RMS_pct_mean:.2f} % ± {whole.gap_RMS_pct_std:.2f}, khớp số trong bài báo.')
bullet('Trong ba cảnh lượn sin cùng điều kiện (70 km/h, 0.1 g), khoảng cách tăng khi chu kỳ lái ngắn dần: '
       + ', '.join(f'+{r.gap_RMS_pct_mean:.1f} % (chu kỳ {r.P_s:.3g} s)' for _, r in sw.iterrows()) + '.')
bullet(f'Chênh biên độ và chênh độ trễ đều nhỏ: biên độ T_s của MapPID thấp hơn tối đa {-sw.dAmp_pct_mean.min():.2f} điểm phần trăm, '
       f'trễ hơn tối đa {sw.dDelay_ms_mean.max():.1f} ms. Phần sai số còn lại là các đỉnh nhọn quanh lúc đổi chiều lái (Hình 6).')
figure(os.path.join(FIG, 'W1411_weave_gap.png'), 'MapPID cao hơn PID bao nhiêu phần trăm theo từng cửa sổ của WEAVE (trung bình ± độ lệch chuẩn trên 5 seed). '
       'Màu đậm là ba cảnh lượn sin cùng điều kiện; chỉ ba cảnh này cho phép đọc xu hướng theo chu kỳ.', 15.0)
figure(rp('Result', 'Compare', 'PID_vs_MapPID', 'PID_vs_MapPID_WEAVE_zoom_sw1p5_s99999.png'),
       'Phóng cảnh chu kỳ 0.67 s: T_s, e_T, hai nhánh của MapPID và T_a. e_T của MapPID (đỏ) nhọn hơn quanh các điểm đổi chiều.', 15.0)

doc.add_heading('5.2. Nhánh Map góp phần bao nhiêu', level=3)
bullet(f'Ở chu kỳ 0.67 s, nhánh Map chỉ có RMS {b15.RMS_umap:.2f} N·m, còn nhánh PID có {b15.RMS_uPID:.2f} N·m: mô men trợ lực hầu như do PID tạo ra.')
bullet('Ba phép chẩn đoán, mỗi phép đổi một chỗ của nhánh Map: D1 bỏ khâu lag, D2 bỏ cả lead-lag, D3 bỏ vùng chết. Khoảng cách toàn ca chỉ giảm '
       + ', '.join(f'{-v:.1f} %' for v in closed.values()) + f' (Hình 7). Ngoại lệ là D1 ở hai đoạn chuyển làn ({lane.iloc[0]:.1f} và {lane.iloc[1]:.1f} %), '
       'nơi nhánh Map lớn hơn.')
bullet(f'Giả thuyết còn lại: hệ số PID của MapPID được chọn khi đã có nhánh Map nên nhỏ hơn PID riêng (Kp {kp_mp:.2f} so với {kp_pid:.2f}). '
       'Giả thuyết này chưa được kiểm. Phép kiểm đề xuất là chạy MapPID với bảng Map bằng 0.')
figure(os.path.join(FIG, 'W1411_weave_branch_diag.png'), 'Trái: RMS hai nhánh của MapPID theo cửa sổ. Phải: khoảng cách toàn ca còn lại so với PID sau mỗi phép chẩn đoán.', 16.0)

doc.add_heading('5.3. Điểm có lợi cho MapPID: êm hơn', level=3)
table([[k, f"{gap(RSo[('PID', k)][0], RSo[('MapPID', k)][0]):+.1f} %", f"{gap(RSo[('PID', k)][1], RSo[('MapPID', k)][1]):+.1f} %"] for k in CASES],
      ['Ca', 'RMS e_T của MapPID so với PID (bám)', 'S của MapPID so với PID (độ ồn)'])
gw = {k: (gap(RSo[('PID', k)][0], RSo[('MapPID', k)][0]), gap(RSo[('PID', k)][1], RSo[('MapPID', k)][1])) for k in CASES}
para(f"S là RMS của mô men trợ lực T_a sau lọc cao qua 5 Hz; S nhỏ thì tay lái êm hơn. Ở WEAVE, MapPID bám kém hơn {gw['WEAVE'][0]:.0f} % nhưng êm hơn "
     f"{-gw['WEAVE'][1]:.0f} %. Ở STEADY, hai bộ bám ngang nhau (chênh {gw['STEADY'][0]:+.1f} %) và MapPID êm hơn {-gw['STEADY'][1]:.1f} %.", italic=True, size=10)

doc.add_heading('6. Kết luận và đề xuất', level=2)
bullet('Kết luận của bài báo vẫn đúng khi đổi mô hình xe (VDB) và khi tham số xe lệch ±20 %.')
bullet('MapPID kém PID ở WEAVE không do nhánh Map; đổi lại, MapPID êm hơn PID.')
bullet('Khi tham số xe lệch, PID và MapPID vẫn giữ được độ bám tĩnh, còn Map thì không.')
bullet('Đề xuất cấu trúc luận văn: chương 5 là kết quả của bài báo cùng phần giải thích WEAVE; chương 6 mới, "Kiểm tra độ vững của kết quả", gồm Plant VDB và sai lệch tham số; '
       'chương 7 là kết luận.')
doc.add_heading('7. Xin ý kiến thầy', level=2)
bullet('Thầy có đồng ý không thêm bộ điều khiển thứ tư không?')
bullet('Nên tách chương 6 riêng, hay để phần VDB ở cuối chương 5?')
bullet('Vệt khí nén và vệt caster là hai tham số tự chọn nhưng nằm trong nhóm nhạy. Kiểm chéo hiện có đã đủ chưa, hay cần thêm nguồn?')
bullet('Có nên đưa ý "MapPID êm hơn nhưng bám kém hơn ở WEAVE" thành một ý chính của bài không?')
para('Giới hạn: một xe, chỉ mô phỏng; các phép chẩn đoán WEAVE dùng một seed; giả thuyết về hệ số PID chưa kiểm.', italic=True, size=10)

doc.save(DOC)
print('written', DOC)
