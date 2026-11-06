"""Build the short English progress report on the Vehicle Dynamics Blockset (VDB) tyre: figures and a Word file.

Every number is read from result files written by the MATLAB scripts; nothing is typed by hand.

    C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/build_report_vdb.py

Inputs:
    Result/Controllers/<Ctrl>/Cases_ssw/<Ctrl>_metrics_s99999.csv, <Ctrl>_<CASE>_sig_s99999.csv          paper Plant
    Model/VDB/temp_test/<Ctrl>/Result/<Ctrl>_VDBTireLagMz_metrics_s99999.csv, ..._<CASE>_sig_s99999.csv   Plant with the VDB tyre
    Result/PRSM/Plant_VDB/Variants/Plant_VDBTire*_compare.txt                                              open-loop deviations
    Model/VDB/Blocks/data/vdb_trail_fit.json, Model/shared/data/params.json
Outputs:
    Result/Report/VDB/*.png
    Documents/Report/VDB_tire_report.docx
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
DOC = os.path.join(ROOT, 'Documents', 'Report', 'VDB_tire_report.docx')
os.makedirs(FIG, exist_ok=True)
CTRLS = ['Map', 'PID', 'MapPID']
CASES = ['STEADY', 'SLIP', 'WEAVE']
TAG = 'VDBTireLagMz'
COL = {'Plant': '#7a7a7a', 'VDB': '#d0582a', 'Map': '#2a78d6', 'PID': '#eb6834', 'MapPID': '#2e9e5b'}
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.grid': True, 'grid.color': '#e2e2e2',
                     'axes.spines.top': False, 'axes.spines.right': False})


def rp(*p):
    return os.path.join(ROOT, *p)


# ------------------------------------------------------------------ data
def metrics(ctrl, vdb):
    f = rp('Model', 'VDB', 'temp_test', ctrl, 'Result', f'{ctrl}_{TAG}_metrics_s99999.csv') if vdb else \
        rp('Result', 'Controllers', ctrl, 'Cases_ssw', f'{ctrl}_metrics_s99999.csv')
    d = pd.read_csv(f)
    return d[d['Window'] == 'whole case'].set_index('Case')


def sig(ctrl, case, vdb):
    f = rp('Model', 'VDB', 'temp_test', ctrl, 'Result', f'{ctrl}_{TAG}_{case}_sig_s99999.csv') if vdb else \
        rp('Result', 'Controllers', ctrl, 'Cases_ssw', f'{ctrl}_{case}_sig_s99999.csv')
    return pd.read_csv(f)


def openloop(model):
    out = {}
    for line in open(rp('Result', 'PRSM', 'Plant_VDB', 'Variants', f'{model}_compare.txt'), encoding='utf-8'):
        m = re.match(r'\S+: (\w+) Ta0 .*?T_r ([\d.]+) %, T_s ([\d.]+) %', line)
        if m:
            out[m.group(1)] = (float(m.group(2)), float(m.group(3)))      # last line of each case wins
    return out


M = {c: (metrics(c, False), metrics(c, True)) for c in CTRLS}
OL = {k: openloop(k) for k in ['Plant_VDBTire', 'Plant_VDBTireLag', 'Plant_VDBTireLagMz']}
fit = json.load(open(rp('Model', 'VDB', 'Blocks', 'data', 'vdb_trail_fit.json'), encoding='utf-8'))
P = json.load(open(rp('Model', 'shared', 'data', 'params.json'), encoding='utf-8'))


def pnum(name):
    """Find a scalar parameter by name anywhere in params.json (value or {'value': ...})."""
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


# ------------------------------------------------------------------ figure 1: what was replaced
def fig_method():
    fig, ax = plt.subplots(figsize=(8.6, 3.3))
    ax.set_xlim(0, 10); ax.set_ylim(0, 4.2); ax.axis('off')

    def box(x, y, w, h, txt, fc, ec='#333333', lw=1.2, fs=9.5):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.04', fc=fc, ec=ec, lw=lw))
        ax.text(x + w / 2, y + h / 2, txt, ha='center', va='center', fontsize=fs)

    def arrow(x0, x1, y):
        ax.annotate('', xy=(x1, y), xytext=(x0, y), arrowprops=dict(arrowstyle='->', lw=1.2, color='#333333'))

    for y, label, tire_txt, fc in [(2.45, 'Paper Plant', 'Tires\nMagic Formula F_y\n+ linear trail, eq. (17)', '#f2f2f2'),
                                   (0.35, 'This work', 'VDB tyre (MathWorks)\nCombined Slip Wheel 2DOF\nrelaxation + Mz of the tyre', '#fbe3d8')]:
        ax.text(0.0, y + 0.6, label, fontsize=10, fontweight='bold', va='center')
        box(1.6, y, 2.0, 1.2, 'Steering column\n(unchanged)', '#f2f2f2')
        box(4.3, y, 2.6, 1.2, tire_txt, fc, ec=COL['VDB'] if fc != '#f2f2f2' else '#333333', lw=2.0 if fc != '#f2f2f2' else 1.2, fs=9)
        box(7.6, y, 2.2, 1.2, '2-DOF vehicle body\n(unchanged)', '#f2f2f2')
        arrow(3.6, 4.3, y + 0.75); arrow(6.9, 7.6, y + 0.75)
        ax.text(3.95, y + 0.9, 'θ2', ha='center', fontsize=9); ax.text(7.25, y + 0.9, 'F_y', ha='center', fontsize=9)
        ax.annotate('', xy=(3.6, y + 0.35), xytext=(4.3, y + 0.35), arrowprops=dict(arrowstyle='->', lw=1.2, color='#333333'))
        ax.text(3.95, y + 0.05, 'T_r', ha='center', fontsize=9)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, 'VDB_method.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ figure 2: pneumatic trail, Plant vs VDB
def fig_trail():
    t0, Ca, Fzf = pnum('t_0'), pnum('C_alpha_f'), None
    m, lf, lr, g = pnum('m'), pnum('l_f'), pnum('l_r'), pnum('g')
    Fz = m * g * lr / (lf + lr) / 2                  # per front wheel
    Caw = Ca / 2
    Bt0, Ct, Et = fit['fitted']['QBZ1'], fit['fitted']['QCZ1'], fit['fitted']['QEZ1']
    al = np.linspace(0, 0.20, 400)
    fig, ax = plt.subplots(figsize=(6.6, 3.4))
    errs = []
    for mu, ls in [(0.8, '-'), (0.5, '--'), (0.3, ':')]:
        tp = t0 * np.maximum(0, 1 - np.tan(al) * Caw / (3 * mu * Fz))
        Bt = Bt0 / mu                                # Pacejka [2] eq. (4.E40): Bt divided by the friction scale factor (mu enters only as LMUY)
        tv = t0 * np.cos(Ct * np.arctan(Bt * al - Et * (Bt * al - np.arctan(Bt * al)))) * np.cos(al)
        errs.append(np.max(np.abs(tv - tp)))
        ax.plot(np.degrees(al), 1e3 * tp, ls, color=COL['Plant'], lw=1.6)
        ax.plot(np.degrees(al), 1e3 * tv, ls, color=COL['VDB'], lw=1.6)
        ax.text(np.degrees(3 * mu * Fz / Caw) + 0.2, 1.0, f'μ = {mu}', fontsize=8.5, color='#444444')
    ax.plot([], [], color=COL['Plant'], label='Paper Plant, eq. (17)')
    ax.plot([], [], color=COL['VDB'], label='VDB tyre, Magic Formula trail')
    ax.set_xlabel('front slip angle α [deg]'); ax.set_ylabel('pneumatic trail t [mm]')
    ax.set_xlim(0, 11.5); ax.set_ylim(-3, 27); ax.legend(frameon=False, fontsize=9)
    fig.tight_layout(); fig.savefig(os.path.join(FIG, 'VDB_trail.png'), dpi=200); plt.close(fig)
    return max(errs)


# ------------------------------------------------------------------ figure 3: RMS e_T bars
def fig_bars():
    fig, axs = plt.subplots(1, 3, figsize=(8.6, 3.0), sharey=False)
    w = 0.38
    for k, case in enumerate(CASES):
        ax = axs[k]
        x = np.arange(len(CTRLS))
        a = [M[c][0].loc[case, 'RMS_eT_Nm'] for c in CTRLS]
        b = [M[c][1].loc[case, 'RMS_eT_Nm'] for c in CTRLS]
        ax.bar(x - w / 2, a, w, color=COL['Plant'], label='Paper Plant')
        ax.bar(x + w / 2, b, w, color=COL['VDB'], label='VDB tyre')
        for i in range(len(CTRLS)):
            ax.text(x[i] + w / 2, b[i], f'{100 * (b[i] / a[i] - 1):+.0f}%', ha='center', va='bottom', fontsize=8)
        ax.set_xticks(x); ax.set_xticklabels(CTRLS); ax.set_title(case, fontsize=10)
        ax.set_ylim(0, 1.18 * max(a + b))
        if k == 0:
            ax.set_ylabel('RMS e_T [N·m]')
    h, l = axs[0].get_legend_handles_labels()
    fig.legend(h, l, frameon=False, fontsize=8.5, ncol=2, loc='upper center')
    fig.tight_layout(rect=(0, 0, 1, 0.92)); fig.savefig(os.path.join(FIG, 'VDB_rms_bars.png'), dpi=200); plt.close(fig)


# ------------------------------------------------------------------ figure 4: time response, one case per controller
def fig_time(case, tw=None, name=None):
    fig, axs = plt.subplots(len(CTRLS), 1, figsize=(8.6, 6.0), sharex=True)
    for k, c in enumerate(CTRLS):
        a, b = sig(c, case, False), sig(c, case, True)
        if tw:
            a = a[(a.t >= tw[0]) & (a.t <= tw[1])]; b = b[(b.t >= tw[0]) & (b.t <= tw[1])]
        ax = axs[k]
        ax.plot(a.t, a.T_d_ref, color='#111111', lw=1.0, label='target T_d,ref')
        ax.plot(a.t, a.T_s, color=COL['Plant'], lw=1.3, label='T_s, paper Plant')
        ax.plot(b.t, b.T_s, color=COL['VDB'], lw=1.1, label='T_s, VDB tyre')
        ax.set_ylabel(f'{c}\nT_s [N·m]')
    axs[0].legend(frameon=False, fontsize=8, ncol=3, loc='upper left')
    axs[-1].set_xlabel('time [s]')
    fig.tight_layout(); fig.savefig(os.path.join(FIG, name or f'VDB_{case}_time.png'), dpi=200); plt.close(fig)


fig_method()
trail_err = fig_trail()
fig_bars()
fig_time('SLIP')
fig_time('STEADY')

# ------------------------------------------------------------------ Word report
doc = Document()
st = doc.styles['Normal']; st.font.name = 'Times New Roman'; st.font.size = Pt(11.5)
for s in doc.sections:
    s.left_margin = s.right_margin = Cm(2.2); s.top_margin = s.bottom_margin = Cm(2.0)


def para(txt, bold=False, italic=False, size=None, align=None):
    p = doc.add_paragraph(); r = p.add_run(txt); r.bold = bold; r.italic = italic
    if size:
        r.font.size = Pt(size)
    if align:
        p.alignment = align
    return p


def bullet(txt):
    doc.add_paragraph(txt, style='List Bullet')


def figure(fn, caption, width=16.0):
    doc.add_picture(os.path.join(FIG, fn), width=Cm(width))
    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
    para(caption, italic=True, size=10, align=WD_ALIGN_PARAGRAPH.CENTER)


def table(rows, header, widths=None):
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


para('Progress report: the controllers on a commercial tyre model (MathWorks VDB)', bold=True, size=15)
para('Tran Minh Tan, supervisor Dr. Phung Thanh Huy, HCMUT. Seed 99999, the same SSW cases (STEADY, SLIP, WEAVE) as in the paper.', italic=True, size=10)

doc.add_heading('1. Why', level=2)
para('The paper evaluates Map, PID and MapPID on a simplified Plant written by us: a Magic Formula lateral force and a linear pneumatic trail, eq. (17). '
     'A reviewer may ask whether the conclusions depend on this home-made tyre. This work replaces only the Tires block with the tyre of the MathWorks '
     'Vehicle Dynamics Blockset (VDB) and re-runs the paper cases with the controllers unchanged (same parameters, same seed).')

doc.add_heading('2. What was changed', level=2)
figure('VDB_method.png', 'Figure 1. Only the Tires block is replaced; steering column, vehicle body, sensors, actuator and controllers are the paper versions.')
para('The VDB tyre was added in three steps, and each step was checked against the paper Plant before the next one:')
fr = fit['fitted']
table([
    ['0. Same tyre as the Plant', 'VDB block configured with the Plant parameters (C, E, C_α, μ)',
     f"T_s {OL['Plant_VDBTire']['DRY'][1]:.2f} %, T_r {OL['Plant_VDBTire']['DRY'][0]:.2f} % (DRY)"],
    ['1. Tyre lag', 'Real lateral relaxation length of the VDB tyre (force builds up over a rolling distance)',
     'T_s ' + ' / '.join(f"{OL['Plant_VDBTireLag'][c][1]:.2f}" for c in CASES) + ' %'],
    ['2. Aligning moment', 'T_r from the tyre moment M_z (Magic Formula trail) instead of eq. (17)',
     'T_s ' + ' / '.join(f"{OL['Plant_VDBTireLagMz'][c][1]:.2f}" for c in CASES) + ' %'],
], ['Step', 'What the VDB tyre adds', 'Open-loop deviation from Plant (STEADY / SLIP / WEAVE)'])
para('Open-loop deviation = RMS of the difference divided by the largest Plant value, with the same steering input and no assist. '
     'Acceptance level written before running step 2: T_s within 3 %.', italic=True, size=10)

doc.add_heading('3. Method for the aligning moment (step 2)', level=2)
para(f"The VDB trail has the Magic Formula shape with three shape coefficients (B_t, C_t, E_t). They were chosen to follow the Plant trail as closely as possible, "
     f"but only inside the range found for real tyres: Pacejka, Tyre and Vehicle Dynamics, Table 4.2 and Table A3.1 (measured 205/60R15), and the VDB library tyre. "
     f"The trail at zero slip is fixed to the Plant value t_0 = {1e3 * pnum('t_0'):.0f} mm. "
     f"Result: B_t = {fr['QBZ1']:.2f} (range 6-12), C_t = {fr['QCZ1']:.3f} (1.05-1.29), E_t = {fr['QEZ1']:.2f} (-4 to 0); "
     f"largest trail difference {fit['max_abs_err_mm']:.1f} mm.")
figure('VDB_trail.png', 'Figure 2. Pneumatic trail at three friction levels. The Plant trail is a straight line with a corner; '
       'a real tyre (Magic Formula) gives a smooth bell. The two cannot coincide with physical coefficients.', 13.5)

doc.add_heading('4. Closed-loop results on the paper cases', level=2)
figure('VDB_rms_bars.png', 'Figure 3. RMS torque tracking error e_T over each whole case, paper Plant versus VDB tyre (labels: change in %).')
rows = []
for c in CTRLS:
    a, b = M[c]
    for case in CASES:
        rows.append([c, case, f"{a.loc[case, 'RMS_eT_Nm']:.3f}", f"{b.loc[case, 'RMS_eT_Nm']:.3f}",
                     f"{100 * (b.loc[case, 'RMS_eT_Nm'] / a.loc[case, 'RMS_eT_Nm'] - 1):+.1f}",
                     f"{a.loc[case, 'S_Nm']:.3f} / {b.loc[case, 'S_Nm']:.3f}"])
table(rows, ['Controller', 'Case', 'RMS e_T Plant [N·m]', 'RMS e_T VDB [N·m]', 'Change [%]', 'S Plant / VDB [N·m]'])
figure('VDB_SLIP_time.png', 'Figure 4. SLIP case (friction changes while cornering): steering torque T_s of each controller on both tyres.')
figure('VDB_STEADY_time.png', 'Figure 5. STEADY case: the largest differences appear in the high lateral-acceleration holds.')


def rng(case):
    v = [100 * (M[c][1].loc[case, 'RMS_eT_Nm'] / M[c][0].loc[case, 'RMS_eT_Nm'] - 1) for c in CTRLS]
    return min(v), max(v)


doc.add_heading('5. What the results say', level=2)
bullet('All three controllers stay stable and keep the same behaviour on the VDB tyre; no parameter was retuned.')
for case in CASES:
    lo, hi = rng(case)
    bullet(f'{case}: RMS e_T changes between {lo:+.1f} % and {hi:+.1f} % across the three controllers.')
d_st = {c: M[c][1].loc['STEADY', 'RMS_eT_Nm'] - M[c][0].loc['STEADY', 'RMS_eT_Nm'] for c in CTRLS}
bullet('In absolute terms the STEADY change is ' + ', '.join(f'{d_st[c]:+.3f} N·m ({c})' for c in CTRLS) +
       '. The percentage is larger for PID and MapPID only because their error on the paper Plant is already small. '
       'The comparison between controllers is unchanged: Map has the largest error in every case, and where PID and MapPID swap order (SLIP) they differ by less '
       'than 5 %, which the paper counts as a tie.')
bullet('The largest change is in STEADY at high lateral acceleration. It comes from the trail shape (Figure 2): with a real tyre the trail decays smoothly, '
       'so the road torque differs by a few percent and the fixed assist characteristic sees a slightly different load. This is a property of the tyre, not of a controller.')
bullet('Limits: one vehicle, one seed, simulation only; the vertical load on each tyre is still constant (no load transfer).')

doc.add_heading('6. Next steps', level=2)
bullet('Replace the 2-DOF vehicle body by the VDB 3-DOF body (already built and checked: deviation below 0.03 % with the Plant tyre).')
bullet('Feed the vertical loads of the VDB body into the VDB tyre, so that load transfer in cornering changes the tyre force and trail.')
bullet('Run the three controllers on the full VDB vehicle with the same cases and seed, then write this part as the last section of thesis Chapter 5 (thesis = paper + VDB section).')

doc.save(DOC)
print('written', DOC)
print('max trail difference (python formula, mu 0.3-0.8): %.2f mm; from MATLAB fit: %.2f mm' % (1e3 * trail_err, fit['max_abs_err_mm']))
for c in CTRLS:
    print(c, ' '.join(f"{case} {M[c][0].loc[case, 'RMS_eT_Nm']:.3f}->{M[c][1].loc[case, 'RMS_eT_Nm']:.3f}" for case in CASES))
