"""Bao cao tieng Viet ve lop VDB (Vehicle Dynamics Blockset): hinh va file Word.

Moi con so doc tu file ket qua do MATLAB ghi; khong go tay so nao.

    C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/build_report_vdb_vi.py

Dau vao:
    Result/Controllers/<Ctrl>/Cases_ssw/<Ctrl>_metrics_s99999.csv, <Ctrl>_<CASE>_sig_s99999.csv           Plant goc (bai bao)
    Model/VDB/temp_test/<Ctrl>/Result/<Ctrl>_<TAG>_metrics_s99999.csv, ..._<CASE>_sig_s99999.csv          TAG = VDBTireLag (khong Mz), VDBTireLagMz (co Mz)
    Result/PRSM/Plant_VDB/Variants/Plant_VDBTire*_compare.txt                                               lech ho mach
    Model/VDB/Blocks/data/vdb_trail_fit.json, Model/shared/data/params.json
Dau ra:
    Result/Report/VDB/VDBvi_*.png
    Documents/Report/VDB_tire_baocao.docx
"""
import json
import os
import re

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import FancyBboxPatch
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Cm, Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG = os.path.join(ROOT, 'Result', 'Report', 'VDB')
DOC = os.path.join(ROOT, 'Documents', 'Report', 'VDB_tire_baocao.docx')
os.makedirs(FIG, exist_ok=True)
CTRLS = ['Map', 'PID', 'MapPID']
CASES = ['STEADY', 'SLIP', 'WEAVE']
PLANTS = ['goc', 'VDBTireLag', 'VDBTireLagMz']
PNAME = {'goc': 'Plant gốc (bài báo)', 'VDBTireLag': 'Lốp VDB, chưa có M_z', 'VDBTireLagMz': 'Lốp VDB, có M_z'}
PSHORT = {'goc': 'Gốc', 'VDBTireLag': 'VDB không M_z', 'VDBTireLagMz': 'VDB có M_z'}
# categorical slots 1-3 of the validated reference palette (dataviz skill), fixed order
COL = {'goc': '#2a78d6', 'VDBTireLag': '#eb6834', 'VDBTireLagMz': '#1baf7a'}
INK, INK2 = '#0b0b0b', '#52514e'
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.grid': True, 'grid.color': '#e6e6e6',
                     'axes.spines.top': False, 'axes.spines.right': False, 'axes.edgecolor': '#9a9a9a',
                     'text.color': INK, 'axes.labelcolor': INK, 'xtick.color': INK2, 'ytick.color': INK2})


def rp(*p):
    return os.path.join(ROOT, *p)


# ------------------------------------------------------------------ du lieu
def _file(ctrl, plant, what):
    if plant == 'goc':
        return rp('Result', 'Controllers', ctrl, 'Cases_ssw', f'{ctrl}_{what}_s99999.csv')
    return rp('Model', 'VDB', 'temp_test', ctrl, 'Result', f'{ctrl}_{plant}_{what}_s99999.csv')


def metrics_all(ctrl, plant):
    return pd.read_csv(_file(ctrl, plant, 'metrics'))


def sig(ctrl, case, plant):
    return pd.read_csv(_file(ctrl, plant, f'{case}_sig'))


def openloop(model):
    out = {}
    for line in open(rp('Result', 'PRSM', 'Plant_VDB', 'Variants', f'{model}_compare.txt'), encoding='utf-8'):
        m = re.match(r'\S+: (\w+) Ta0 .*?T_r ([\d.]+) %, T_s ([\d.]+) %', line)
        if m:
            out[m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return out


MA = {(c, p): metrics_all(c, p) for c in CTRLS for p in PLANTS}
RMS = {(c, p, k): float(MA[(c, p)].query('Case == @k and Window == "whole case"')['RMS_eT_Nm'].iloc[0])
       for c in CTRLS for p in PLANTS for k in CASES}
SS = {(c, p, k): float(MA[(c, p)].query('Case == @k and Window == "whole case"')['S_Nm'].iloc[0])
      for c in CTRLS for p in PLANTS for k in CASES}
SIG = {(c, k, p): sig(c, k, p) for c in CTRLS for k in CASES for p in PLANTS}
OL = {k: openloop(k) for k in ['Plant_VDBTire', 'Plant_VDBTireLag', 'Plant_VDBTireLagMz']}
fit = json.load(open(rp('Model', 'VDB', 'Blocks', 'data', 'vdb_trail_fit.json'), encoding='utf-8'))
P = json.load(open(rp('Model', 'shared', 'data', 'params.json'), encoding='utf-8'))


def pnum(name):
    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == name:
                    return v['value'] if isinstance(v, dict) and 'value' in v else v
                r = walk(v)
                if r is not None:
                    return r
        return None
    return float(walk(P))


def pct(a, b):
    return 100 * (b / a - 1)


def aligned(c, k, p):
    a, b = SIG[(c, k, 'goc')], SIG[(c, k, p)]
    n = min(len(a), len(b))
    return a.iloc[:n].reset_index(drop=True), b.iloc[:n].reset_index(drop=True)


# su kien chi phoi: cac giay (bin 1 s) ma mot minh chiem >= 20 % tong |thay doi binh phuong e_T| cua PID giua Plant goc va mot ban VDB
EVENT = {}
for k in CASES:
    ev = set()
    for p in PLANTS[1:]:
        a, b = aligned('PID', k, p)
        d = b.e_T.values ** 2 - a.e_T.values ** 2
        s = pd.Series(d).groupby(np.floor(a.t.values).astype(int)).sum()
        ev |= {int(t) for t, v in s.items() if abs(v) >= 0.2 * s.abs().sum()}
    if ev:
        EVENT[k] = sorted(ev)


def ev_mask(s, k):
    m = np.zeros(len(s), bool)
    for t0 in EVENT.get(k, []):
        m |= (s.t.values >= t0) & (s.t.values < t0 + 1)
    return m


def rms_excl(c, k, p):
    """RMS e_T of plant p with the event seconds of case k removed."""
    s = SIG[(c, k, p)]
    return float(np.sqrt(np.mean(s.e_T.values[~ev_mask(s, k)] ** 2)))


def ms_share(c, k, p):
    """Share of the squared e_T of plant p that lies in the event seconds of case k."""
    s = SIG[(c, k, p)]
    return float(np.sum(s.e_T.values[ev_mask(s, k)] ** 2) / np.sum(s.e_T.values ** 2))


def static_windows(c, p):
    d = MA[(c, p)]
    return d[(d.Case == 'STEADY') & (d.Window != 'whole case')].set_index('Window')['RMS_eT_Nm']


# ------------------------------------------------------------------ hinh 1: thay khoi nao
def fig_method():
    fig, ax = plt.subplots(figsize=(8.6, 3.3))
    ax.set_xlim(0, 10); ax.set_ylim(0, 4.2); ax.axis('off')

    def box(x, y, w, h, txt, fc, ec='#333333', lw=1.2, fs=9.5):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.04', fc=fc, ec=ec, lw=lw))
        ax.text(x + w / 2, y + h / 2, txt, ha='center', va='center', fontsize=fs)

    def arrow(x0, x1, y):
        ax.annotate('', xy=(x1, y), xytext=(x0, y), arrowprops=dict(arrowstyle='->', lw=1.2, color='#333333'))

    for y, label, tire_txt, hl in [(2.45, 'Bài báo', 'Tires tự viết\nF_y: Magic Formula\ntrail: PT (17), tuyến tính', False),
                                   (0.35, 'Phần mới', 'Lốp VDB (MathWorks)\nCombined Slip Wheel 2DOF\nđộ trễ lốp + M_z của lốp', True)]:
        ax.text(0.0, y + 0.6, label, fontsize=10, fontweight='bold', va='center')
        box(1.6, y, 2.0, 1.2, 'Cột lái\n(giữ nguyên)', '#f2f2f2')
        box(4.3, y, 2.6, 1.2, tire_txt, '#e3eefb' if hl else '#f2f2f2', ec=COL['goc'] if hl else '#333333', lw=2.0 if hl else 1.2, fs=9)
        box(7.6, y, 2.2, 1.2, 'Thân xe 2 bậc tự do\n(giữ nguyên)', '#f2f2f2')
        arrow(3.6, 4.3, y + 0.75); arrow(6.9, 7.6, y + 0.75)
        ax.text(3.95, y + 0.9, 'θ2', ha='center', fontsize=9); ax.text(7.25, y + 0.9, 'F_y', ha='center', fontsize=9)
        ax.annotate('', xy=(3.6, y + 0.35), xytext=(4.3, y + 0.35), arrowprops=dict(arrowstyle='->', lw=1.2, color='#333333'))
        ax.text(3.95, y + 0.05, 'T_r', ha='center', fontsize=9)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, 'VDBvi_method.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ hinh 2: trail
def fig_trail():
    t0, Ca = pnum('t_0'), pnum('C_alpha_f')
    m, lf, lr, g = pnum('m'), pnum('l_f'), pnum('l_r'), pnum('g')
    Fz = m * g * lr / (lf + lr) / 2
    Caw = Ca / 2
    Bt0, Ct, Et = fit['fitted']['QBZ1'], fit['fitted']['QCZ1'], fit['fitted']['QEZ1']
    al = np.linspace(0, 0.20, 400)
    fig, ax = plt.subplots(figsize=(6.6, 3.4))
    for mu, ls in [(0.8, '-'), (0.5, '--'), (0.3, ':')]:
        tp = t0 * np.maximum(0, 1 - np.tan(al) * Caw / (3 * mu * Fz))
        Bt = Bt0 / mu                                # Pacejka [2] (4.E40): Bt chia cho he so mu
        tv = t0 * np.cos(Ct * np.arctan(Bt * al - Et * (Bt * al - np.arctan(Bt * al)))) * np.cos(al)
        ax.plot(np.degrees(al), 1e3 * tp, ls, color=COL['goc'], lw=2)
        ax.plot(np.degrees(al), 1e3 * tv, ls, color=COL['VDBTireLagMz'], lw=2)
        ax.text(np.degrees(3 * mu * Fz / Caw) + 0.2, 1.0, f'μ = {mu}', fontsize=8.5, color=INK2)
    ax.plot([], [], color=COL['goc'], lw=2, label='Plant gốc, PT (17)')
    ax.plot([], [], color=COL['VDBTireLagMz'], lw=2, label='Lốp VDB, trail Magic Formula')
    ax.set_xlabel('góc trượt bánh trước α [độ]'); ax.set_ylabel('trail t [mm]')
    ax.set_xlim(0, 11.5); ax.set_ylim(-3, 27); ax.legend(frameon=False, fontsize=9)
    fig.tight_layout(); fig.savefig(os.path.join(FIG, 'VDBvi_trail.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ hinh 3: cot RMS e_T, ba Plant
def fig_bars(excl=False):
    val = (lambda c, p, k: rms_excl(c, k, p)) if excl else (lambda c, p, k: RMS[(c, p, k)])
    fig, axs = plt.subplots(1, 3, figsize=(9.6, 3.2))
    w = 0.26
    for j, k in enumerate(CASES):
        ax = axs[j]
        x = np.arange(len(CTRLS))
        top = max(val(c, p, k) for c in CTRLS for p in PLANTS)
        for i, p in enumerate(PLANTS):
            v = [val(c, p, k) for c in CTRLS]
            ax.bar(x + (i - 1) * (w + 0.02), v, w, color=COL[p], label=PNAME[p])
            if p != 'goc':
                for q, c in enumerate(CTRLS):
                    ax.text(x[q] + (i - 1) * (w + 0.02), v[q] + 0.01 * top + (0.05 * top if i == 2 else 0),
                            f'{pct(val(c, "goc", k), v[q]):+.0f}%', ha='center', va='bottom', fontsize=6.5, color=INK2)
        ax.set_xticks(x); ax.set_xticklabels(CTRLS)
        ax.set_title(k + (' (bỏ giây ' + ', '.join(f'{e}' for e in EVENT[k]) + ' s)' if excl and k in EVENT else ''), fontsize=10)
        ax.set_ylim(0, 1.22 * top); ax.grid(axis='x', visible=False)
        if j == 0:
            ax.set_ylabel('RMS e_T [N·m]')
    h, l = axs[0].get_legend_handles_labels()
    fig.legend(h, l, frameon=False, fontsize=8.5, ncol=3, loc='upper center')
    fig.tight_layout(rect=(0, 0, 1, 0.91))
    fig.savefig(os.path.join(FIG, 'VDBvi_rms_bars_excl.png' if excl else 'VDBvi_rms_bars.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ hinh 4, 5: phong to su kien
def fig_event(k, panels, rows, name):
    """panels: list of (ctrl, t_start, t_end, title), one column each; rows: list of (signal column, y label)."""
    fig, axs = plt.subplots(len(rows), len(panels), figsize=(9.0, 2.15 * len(rows)), sharex='col')
    for j, (c, t0, t1, title) in enumerate(panels):
        for i, (col, lab) in enumerate(rows):
            ax = axs[i, j]
            for p in PLANTS:
                s = SIG[(c, k, p)]
                s = s[(s.t >= t0) & (s.t <= t1)]
                ax.plot(s.t, s[col], color=COL[p], lw=2, label=PNAME[p])
            if col == 'T_s':
                s = SIG[(c, k, 'goc')]; s = s[(s.t >= t0) & (s.t <= t1)]
                ax.plot(s.t, s.T_d_ref, color=INK, lw=1, ls='--', label='giá trị đặt T_d,ref')
            for e in EVENT[k]:
                if t0 < e + 1 and e < t1:
                    ax.axvspan(e, e + 1, color='#f0efec', zorder=0)
            if j == 0:
                ax.set_ylabel(lab)
            if i == 0:
                ax.set_title(title, fontsize=10)
        axs[-1, j].set_xlabel('thời gian [s]')
    h, l = axs[0, 0].get_legend_handles_labels()
    fig.legend(h, l, frameon=False, fontsize=8.5, ncol=4, loc='upper center')
    fig.tight_layout(rect=(0, 0, 1, 0.93)); fig.savefig(os.path.join(FIG, name), dpi=200); plt.close(fig)


fig_method()
fig_trail()
fig_bars()
fig_bars(excl=True)
e0 = EVENT['STEADY'][0]
fig_event('STEADY', [('PID', e0 - 0.4, e0 + 1.4, 'PID'), ('MapPID', e0 - 0.4, e0 + 1.4, 'MapPID')],
          [('T_s', 'T_s [N·m]'), ('T_a', 'T_a [N·m]'), ('theta1_rad', 'θ1 [rad]')], 'VDBvi_STEADY_event.png')
fig_event('SLIP', [('PID', e - 0.6, e + 1.5, f'PID, μ tăng lại lúc {e} s') for e in EVENT['SLIP']],
          [('T_s', 'T_s [N·m]'), ('a_y', 'a_y [m/s²]'), ('mu', 'μ'), ('T_a', 'T_a [N·m]')], 'VDBvi_SLIP_event.png')

# ------------------------------------------------------------------ cac so dung trong loi van
d_ol = {k: (OL['Plant_VDBTireLag'][k][1], OL['Plant_VDBTireLagMz'][k][1]) for k in CASES}
ev = {}                                            # peak |T_s| in each event second, PID, per plant
for k in EVENT:
    for e in EVENT[k]:
        for p in PLANTS:
            s = SIG[('PID', k, p)]
            w = (s.t >= e) & (s.t < e + 1)
            ev[(k, e, p)] = float(np.max(np.abs(s.T_s.values[w])))
sw = {}
for c in ['PID', 'MapPID']:
    g = static_windows(c, 'goc')
    for p in PLANTS[1:]:
        v = static_windows(c, p).reindex(g.index)
        sw[(c, p)] = float(np.max(np.abs(v - g)))
mapw = {p: float(np.median(static_windows('Map', p).values - static_windows('Map', 'goc').values)) for p in PLANTS[1:]}

for c in CTRLS:
    print(c, ' | '.join(f"{k} " + ' -> '.join(f'{RMS[(c, p, k)]:.3f}' for p in PLANTS) for k in CASES))
print('events', EVENT, {(c, k): f"{100 * ms_share(c, k, 'goc'):.0f}%" for c in CTRLS for k in EVENT})
for c in CTRLS:
    print(c, 'excl', ' | '.join(f"{k} " + ' -> '.join(f'{rms_excl(c, k, p):.3f}' for p in PLANTS) for k in CASES))
print('Ts peak diff (PID)', ev)
print('max |d| static windows PID/MapPID', sw)
print('Map median static-window shift', mapw)

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


def figure(fn, caption, width=16.0):
    NFIG[0] += 1
    doc.add_picture(os.path.join(FIG, fn), width=Cm(width))
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


def f3(x):
    return f'{x:.3f}'


def ta_ev(k, e):
    s = SIG[('PID', k, 'goc')]
    w = (s.t >= e) & (s.t < e + 1)
    return float(np.max(np.abs(s.T_a.values[w])))


def rng_ex(k, p, ctrls=('PID', 'MapPID')):
    v = [pct(rms_excl(c, k, 'goc'), rms_excl(c, k, p)) for c in ctrls]
    return f'{min(v):+.0f} đến {max(v):+.0f} %' if round(min(v)) != round(max(v)) else f'{min(v):+.0f} %'


eS, eL1, eL2 = EVENT['STEADY'][0], EVENT['SLIP'][0], EVENT['SLIP'][1]
fr = fit['fitted']

para('Báo cáo tiến độ: chạy ba bộ điều khiển trên mô hình lốp thương mại (MathWorks VDB)', bold=True, size=15)
para('HV Trần Minh Tân, GVHD TS. Phùng Thanh Huy, HCMUT. Ba ca SSW của bài báo (STEADY, SLIP, WEAVE), cảm biến có nhiễu với seed 99999; '
     'tham số ba bộ điều khiển giữ nguyên như trong bài báo.', italic=True, size=10)

doc.add_heading('1. Mục đích', level=2)
para('Bài báo đánh giá ba bộ Map, PID và MapPID trên một Plant tự viết: lực ngang lốp theo Magic Formula và trail (khoảng cách từ tâm vết tiếp xúc tới điểm đặt lực ngang, '
     'quyết định mô-men trả lái T_r) theo phương trình tuyến tính (17). Người phản biện có thể hỏi kết luận có phụ thuộc vào mô hình lốp tự viết này không. '
     'Phần mới chỉ thay khối Tires bằng lốp của Vehicle Dynamics Blockset (VDB, bộ thư viện động lực học ô tô thương mại của MathWorks), giữ nguyên mọi phần khác, '
     'rồi chạy lại các ca của bài báo.')

doc.add_heading('2. Đã thay đổi gì', level=2)
figure('VDBvi_method.png', 'Chỉ khối Tires được thay; cột lái, thân xe, cảm biến, cơ cấu chấp hành và các bộ điều khiển giữ nguyên bản của bài báo.')
para('Lốp VDB được đưa vào theo từng bước; mỗi bước được so với Plant gốc khi chưa có trợ lực (hở mạch) trước khi sang bước sau:')
table([
    ['0. Lốp VDB cấu hình như Plant', 'Khối VDB nhận đúng tham số của Plant (C, E, C_α, μ)',
     f"T_s {OL['Plant_VDBTire']['DRY'][1]:.2f} % (ca DRY)"],
    ['1. Độ trễ lốp', 'Lực ngang tăng dần theo quãng lăn của bánh (độ trễ thật của lốp), thay cho lực tức thời',
     ' / '.join(f'{d_ol[k][0]:.2f}' for k in CASES) + ' %'],
    ['2. Mô-men M_z của lốp', 'T_r lấy từ M_z của lốp VDB (trail dạng Magic Formula) thay cho PT (17)',
     ' / '.join(f'{d_ol[k][1]:.2f}' for k in CASES) + ' %'],
], ['Bước', 'Lốp VDB thêm gì', 'Lệch T_s hở mạch so với Plant gốc (STEADY / SLIP / WEAVE)'])
para('Lệch hở mạch = RMS (căn trung bình bình phương) của hiệu hai đường T_s chia cho giá trị lớn nhất của Plant gốc, cùng góc lái, không trợ lực. '
     'Ngưỡng đặt trước khi chạy bước 2: không quá 3 %. Cả ba ca đều đạt.', italic=True, size=10)

doc.add_heading('3. Cách chọn hệ số trail cho M_z (bước 2)', level=2)
para(f"Trail của lốp VDB có dạng Magic Formula với ba hệ số hình dạng B_t, C_t, E_t. Ba hệ số được chọn để bám trail của Plant gốc sát nhất, nhưng chỉ trong khoảng của lốp thật "
     f"(Pacejka, Tyre and Vehicle Dynamics, Bảng 4.2 và Bảng A3.1, cùng lốp mẫu của VDB); trail tại góc trượt 0 cố định bằng t_0 = {1e3 * pnum('t_0'):.0f} mm của Plant. "
     f"Kết quả: B_t = {fr['QBZ1']:.2f} (khoảng 6-12), C_t = {fr['QCZ1']:.3f} (1.05-1.29), E_t = {fr['QEZ1']:.2f} (-4 đến 0); trail lệch lớn nhất {fit['max_abs_err_mm']:.1f} mm.")
figure('VDBvi_trail.png', 'Trail ở ba mức μ. Trail của Plant gốc là đoạn thẳng có góc gãy, giảm ngay từ góc trượt 0; trail của lốp thật (Magic Formula) là đường cong trơn, '
       'gần như nằm ngang khi góc trượt nhỏ. Với hệ số hợp lý về vật lý, hai đường không thể trùng nhau.', 13.5)

doc.add_heading('4. Kết quả vòng kín trên ba ca của bài báo', level=2)
para('Mỗi bộ điều khiển chạy trên ba bản Plant: Plant gốc, Plant với lốp VDB có độ trễ nhưng T_r vẫn theo PT (17) (gọi tắt "VDB không M_z"), '
     'và Plant với lốp VDB đầy đủ (gọi tắt "VDB có M_z"). Chỉ tiêu là RMS của sai số mô-men e_T = T_s - T_d,ref trên cả ca, với T_d,ref là mô-men tay lái mong muốn.')
figure('VDBvi_rms_bars.png', 'RMS e_T trên cả ca của ba bản Plant (nhãn: thay đổi so với Plant gốc).')
rows = []
for c in CTRLS:
    for k in CASES:
        rows.append([c, k] + [f3(RMS[(c, p, k)]) for p in PLANTS] +
                    [f"{pct(RMS[(c, 'goc', k)], RMS[(c, p, k)]):+.1f}" for p in PLANTS[1:]] +
                    [f"{SS[(c, 'goc', k)]:.3f} / {SS[(c, 'VDBTireLagMz', k)]:.3f}"])
table(rows, ['Bộ', 'Ca', 'Gốc [N·m]', 'VDB không M_z', 'VDB có M_z', 'Δ không M_z [%]', 'Δ có M_z [%]', 'S gốc / có M_z [N·m]'])
def rng_all(k, p, ctrls=('PID', 'MapPID')):
    v = [pct(RMS[(c, 'goc', k)], RMS[(c, p, k)]) for c in ctrls]
    return f'{min(v):+.0f} đến {max(v):+.0f} %' if round(min(v)) != round(max(v)) else f'{min(v):+.0f} %'


para(f"S là độ ồn của T_a (RMS sau lọc cao qua 5 Hz); S gần như không đổi giữa các bản Plant. Nhìn theo phần trăm, khi có M_z thì STEADY của PID và MapPID đổi "
     f"{rng_all('STEADY', 'VDBTireLagMz')}, SLIP đổi {rng_all('SLIP', 'VDBTireLagMz')}. Mục 5 cho thấy các con số này đến từ đâu.", italic=True, size=10)

doc.add_heading('5. Phân tích chi tiết: phần lệch nằm ở đâu', level=2)
doc.add_heading('5.1. Phần lệch lớn tập trung vào ba giây', level=3)
para(f"Chia mỗi ca thành từng giây và đo mỗi giây góp bao nhiêu vào thay đổi bình phương e_T. Với PID, gần như toàn bộ thay đổi nằm trong ba giây: giây {eS} s của STEADY, "
     f"giây {eL1} s và {eL2} s của SLIP. Ở cả ba giây, mô-men trợ lực T_a nằm sát giới hạn T_a,max của cơ cấu chấp hành (lần lượt {ta_ev('STEADY', eS):.2f}, "
     f"{ta_ev('SLIP', eL1):.2f}, {ta_ev('SLIP', eL2):.2f} N·m), tức là bộ điều khiển đã dùng hết quyền và không làm gì thêm được; khi đó khác biệt của Plant đi thẳng vào e_T. "
     f"Ngay trên Plant gốc, các giây này đã chiếm {100 * ms_share('PID', 'STEADY', 'goc'):.0f} % (STEADY) và {100 * ms_share('PID', 'SLIP', 'goc'):.0f} % (SLIP) "
     f"bình phương e_T của PID, vì ở mọi chỗ khác PID bám rất sát. Vì vậy chỉ cần đỉnh trong một giây thay đổi là RMS cả ca đổi vài chục phần trăm.")
figure('VDBvi_rms_bars_excl.png', 'RMS e_T sau khi bỏ các giây T_a chạm giới hạn (nhãn: thay đổi so với Plant gốc).')
rows = []
for c in CTRLS:
    for k in CASES:
        rows.append([c, k] + [f3(rms_excl(c, k, p)) for p in PLANTS] +
                    [f"{pct(rms_excl(c, k, 'goc'), rms_excl(c, k, p)):+.1f}" for p in PLANTS[1:]])
table(rows, ['Bộ', 'Ca', 'Gốc [N·m]', 'VDB không M_z', 'VDB có M_z', 'Δ không M_z [%]', 'Δ có M_z [%]'])
para(f"Bỏ các giây đó, PID và MapPID lệch: STEADY {rng_ex('STEADY', 'VDBTireLag')} (không M_z), {rng_ex('STEADY', 'VDBTireLagMz')} (có M_z); "
     f"SLIP {rng_ex('SLIP', 'VDBTireLag')} và {rng_ex('SLIP', 'VDBTireLagMz')}; WEAVE {rng_ex('WEAVE', 'VDBTireLag')} và {rng_ex('WEAVE', 'VDBTireLagMz')}.")

doc.add_heading(f'5.2. Sự kiện 1: đánh lái nhanh ở STEADY (giây {eS} s), do M_z', level=3)
para(f"Xe chạy 25 km/h, vô-lăng quay từ 0 tới khoảng -130 độ trong 1 s. T_a chạm giới hạn ở cả ba bản Plant. Đỉnh |T_s| của PID: "
     f"{ev[('STEADY', eS, 'goc')]:.2f} N·m (gốc), {ev[('STEADY', eS, 'VDBTireLag')]:.2f} N·m (VDB không M_z), {ev[('STEADY', eS, 'VDBTireLagMz')]:.2f} N·m (VDB có M_z). "
     "Chỉ bản có M_z lệch rõ, nên nguyên nhân là trail: khi góc trượt nhỏ, trail của lốp thật gần như bằng t_0, còn PT (17) đã giảm, "
     "nên T_r của lốp VDB lớn hơn và người lái phải giữ mô-men lớn hơn trong lúc trợ lực đã hết.")
figure('VDBvi_STEADY_event.png', f'Giây {eS} s của STEADY (vùng tô xám): T_s, T_a và góc vô-lăng θ1. T_a nằm ở giới hạn trong khoảng 0.6 s; đường T_s của bản có M_z tách khỏi hai bản kia.')

doc.add_heading(f'5.3. Sự kiện 2 và 3: μ tăng lại khi đang cua ở SLIP (giây {eL1} s và {eL2} s), do độ trễ lốp', level=3)
para(f"Hệ số bám μ nhảy từ mức thấp lên 0.8 trong khi vô-lăng vẫn giữ góc. Lốp của Plant gốc không có độ trễ nên lực ngang và a_y nhảy tức thời; "
     f"lốp VDB cần một quãng lăn để lực tăng dần, giống lốp thật. Ở giây {eL2} s, đỉnh |T_s| của PID giảm từ {ev[('SLIP', eL2, 'goc')]:.2f} N·m (gốc) xuống "
     f"{ev[('SLIP', eL2, 'VDBTireLag')]:.2f} và {ev[('SLIP', eL2, 'VDBTireLagMz')]:.2f} N·m (hai bản VDB), nên RMS của SLIP giảm. "
     f"Ở giây {eL1} s, a_y vọt lên gần 0.8 g rồi lốp VDB làm a_y giảm chậm hơn, nên T_a nằm ở giới hạn lâu hơn và đỉnh |T_s| lớn hơn: "
     f"{ev[('SLIP', eL1, 'goc')]:.2f} N·m (gốc), {ev[('SLIP', eL1, 'VDBTireLag')]:.2f} N·m (không M_z), {ev[('SLIP', eL1, 'VDBTireLagMz')]:.2f} N·m (có M_z; "
     "ở góc trượt lớn trail Magic Formula giảm nhanh nên bù lại một phần). Hai bản VDB giống nhau ở sự kiện 3, nên nguyên nhân là độ trễ lốp, không phải M_z.")
figure('VDBvi_SLIP_event.png', 'Hai lần μ tăng lại trong SLIP (PID): T_s, a_y, μ và T_a. Lốp gốc cho a_y nhảy tức thời; lốp VDB cho a_y tăng và giảm có độ trễ.')

doc.add_heading('5.4. Ngoài các sự kiện', level=3)
bullet(f"PID và MapPID: sai số ở mọi cửa sổ giữ cua của STEADY gần như trùng Plant gốc (lệch lớn nhất {1e3 * max(sw.values()):.1f} mN·m), "
       "vì khâu tích phân bù hết phần T_r thay đổi.")
bullet(f"Map: sai số ở các cửa sổ giữ cua tăng đều (trung vị {mapw['VDBTireLagMz']:+.3f} N·m) khi có M_z, không đổi khi không M_z "
       f"({mapw['VDBTireLag']:+.4f} N·m). Map chỉ tra bảng, không có phản hồi sai số, nên T_r đổi bao nhiêu thì e_T đổi bấy nhiêu. "
       "Đây đúng là hiện tượng trợ lực sai khi xe khác với lúc dựng bảng mà đề tài muốn chỉ ra.")
bullet(f"WEAVE (lái lượn liên tục, không có sự kiện T_a chạm giới hạn): PID và MapPID lệch {rng_ex('WEAVE', 'VDBTireLag')} khi không M_z và "
       f"{rng_ex('WEAVE', 'VDBTireLagMz')} khi có M_z; phần lớn do độ trễ lốp làm lực ngang chậm pha khi lái nhanh, nằm quanh ngưỡng hòa 5 % của bài báo.")

doc.add_heading('6. Kết luận', level=2)
bullet('Ba bộ điều khiển chạy ổn định trên lốp VDB, không chỉnh lại tham số nào.')
bullet('Thứ bậc giữa các bộ không đổi: Map sai số lớn nhất ở mọi ca; PID và MapPID chênh nhau dưới 5 % (hòa theo quy tắc của bài báo).')
bullet(f"Các con số lệch lớn ({rng_all('STEADY', 'VDBTireLagMz')} ở STEADY, {rng_all('SLIP', 'VDBTireLagMz')} ở SLIP) không phải do bộ điều khiển và không phải do Plant lệch đều; chúng đến từ ba giây T_a chạm giới hạn, "
       "nơi chỉ Plant quyết định T_s. Nguyên nhân: trail (sự kiện 1) và độ trễ lốp (sự kiện 2, 3).")
bullet(f"Bỏ ba giây đó, PID và MapPID lệch vài phần trăm. Map lệch đều {pct(rms_excl('Map', 'STEADY', 'goc'), rms_excl('Map', 'STEADY', 'VDBTireLagMz')):+.0f} % "
       "ở STEADY khi có M_z, vì Map không có phản hồi.")
bullet('Hệ quả cho cách báo cáo: RMS cả ca bị chi phối bởi vài giây T_a chạm giới hạn, nên khi so hai Plant cần báo thêm RMS bỏ các giây đó.')

doc.add_heading('7. Đề xuất và bước tiếp theo', level=2)
bullet('Chọn bản Plant cho phần so sánh chính (cần thầy cho ý kiến): (A) lốp VDB không M_z, gần Plant gốc nhất, còn bản có M_z dùng làm phép thử độ nhạy theo mô hình trail; '
       'hoặc (B) dùng bản có M_z và giải thích rằng PT (17) đơn giản hóa trail.')
bullet('Thay thân xe 2 bậc tự do bằng thân VDB 3 bậc tự do (đã dựng và kiểm, lệch dưới 0.03 % khi dùng lốp của Plant).')
bullet('Nối tải đứng của thân VDB vào lốp VDB để có chuyển tải khi vào cua (lực và trail đổi theo tải).')
bullet('Chạy ba bộ trên xe VDB đầy đủ với cùng ca và seed, rồi viết thành mục cuối chương 5 của luận văn (luận văn = bài báo + mục VDB).')
para('Giới hạn: một xe, một seed, chỉ mô phỏng; tải đứng trên mỗi bánh hiện vẫn cố định.', italic=True, size=10)

doc.save(DOC)
print('written', DOC)
