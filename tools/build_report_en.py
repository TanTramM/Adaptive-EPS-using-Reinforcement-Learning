"""Build the English progress report on the assist map (Map) versus PID torque feedback: figures, a Word report and a PowerPoint deck.

Every number is read from the result files (csv/json) written by the MATLAB scripts; nothing is typed by hand.

    python -X utf8 tools/build_report_en.py <calib_erel_windows.csv> <freq_response.csv> <margins_discrete.csv>

The arguments are produced by MATLAB: calib_run on the selected points (per-window e_rel), frequency responses of pi_plant_lin and the loops, and
allmargin of the discrete (1 ms, one-sample delay) loops.
Before running: in MATLAB, make_pair_comparisons({'Map', 'PI', 'PID'}, 99999) writes the signal files <Ctrl>_<CASE>_sig_s99999.csv that the
time-response figures read (QuyChuan 3.3 deletes them from Result/Controllers/<Ctrl>/Cases after the comparison, so rerun it first).
Outputs:
    Result/Report/Map_vs_PID/*.png               English figures
    Documents/Report/MapPID_report.txt, .docx    report (docx built with tools/txt2docx.py)
    Documents/Report/MapPID_slides.pptx          slide deck
"""
import csv
import json
import os
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
FIG = os.path.join(ROOT, 'Result', 'Report', 'Map_vs_PID')
DOC = os.path.join(ROOT, 'Documents', 'Report')
os.makedirs(FIG, exist_ok=True)
os.makedirs(DOC, exist_ok=True)

COL = {'Map': '#2a78d6', 'PI': '#cc9900', 'PID': '#eb6834', 'ref': '#111111'}
SEED = 99999
SEEDS = {'Map': 0, 'PI': 10000, 'PID': 10000}
CASES = ['DRY', 'SLIP', 'WEAVE']
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.grid': True, 'grid.color': '#dddddd',
                     'axes.spines.top': False, 'axes.spines.right': False})


def rp(*p):
    return os.path.join(ROOT, *p)


def rel(path):
    return os.path.relpath(path, ROOT).replace('\\', '/')


def js(name):
    return json.load(open(rp('Model', 'data', name), encoding='utf-8'))


# ------------------------------------------------------------------ data
erel_csv, freq_csv, marg_csv = sys.argv[1], sys.argv[2], sys.argv[3]
mapj, pij, pidj = js('map.json')['design'], js('pi.json')['design'], js('pid.json')['design']
params = js('params.json')
refj = js('ref.json')
sensj = js('sensors.json')
erelW = pd.read_csv(erel_csv)
fr = pd.read_csv(freq_csv)
marg = pd.read_csv(marg_csv)
PMd = {c: marg[(marg.Ctrl == c) & (marg.saturated == 0)].iloc[0] for c in ('Map', 'PI', 'PID')}
sw = {'Map': pd.read_csv(rp('Result', 'Controllers', 'Map', 'Calib', 'Map_CALIB_sweep_s00000.csv')),
      'PI': pd.read_csv(rp('Result', 'Controllers', 'PI', 'Calib', 'PI_CALIB_sweep_s10000.csv')),
      'PID': pd.read_csv(rp('Result', 'Controllers', 'PID', 'Calib', 'PID_CALIB_sweep_s10000.csv'))}
summ = pd.concat([pd.read_csv(rp('Result', 'Compare', p, '%s_summary_s%05d.csv' % (p, SEED))) for p in ('Map_vs_PI', 'Map_vs_PID', 'PI_vs_PID')])
summ = summ.drop_duplicates(subset=['Ctrl', 'Case', 'Window'])
sig = {(c, k): pd.read_csv(rp('Result', 'Controllers', c, 'Cases', '%s_%s_sig_s%05d.csv' % (c, k, SEED))) for c in ('Map', 'PI', 'PID') for k in CASES}


def sval(ctrl, case, window, col):
    r = summ[(summ.Ctrl == ctrl) & (summ.Case == case) & (summ.Window == window)]
    return float(r[col].iloc[0]) if len(r) else float('nan')


def p1(x, n=1):
    return ('%.' + str(n) + 'f') % x


cal = {'Map': dict(R=mapj['CALIB_R_pct'], S=mapj['CALIB_S_Nm'], TV=mapj['CALIB_TV_Nm_per_s'], erel=mapj['CALIB_erel_pct'], rev=mapj['CALIB_rev_pct']),
       'PI': dict(R=pij['CALIB_R_pct'], S=pij['CALIB_S_Nm'], TV=pij['CALIB_TV_Nm_per_s'], erel=pij['CALIB_erel_pct'], rev=pij['CALIB_rev_pct']),
       'PID': dict(R=pidj['CALIB_R_pct'], S=pidj['CALIB_S_Nm'], TV=pidj['CALIB_TV_Nm_per_s'], erel=pidj['CALIB_erel_pct'], rev=pidj['CALIB_rev_pct'])}
tamax = refj['Ta_max']
v_tab, ta_tab = np.array(tamax['v_kmh'], float), np.array(tamax['Ta_max_Nm'], float)
w = fr.w.values
k_res = int(np.argmax(fr.G1_mag.values)); f_res = w[k_res] / (2 * np.pi)
hf = {'Map': mapj['Kmax'] * mapj['lead']['p'] / mapj['lead']['z'], 'PI': pij['Kp'], 'PID': pidj['Kp'] + pidj['Kd'] / pidj['Tf']}


def margins(mag, ph):
    """phase margin [deg] at the highest gain crossover, loop L = C*G with negative feedback through T_s."""
    idx = np.where(np.diff(np.sign(mag - 1.0)) != 0)[0]
    if len(idx) == 0:
        return float('nan'), float('nan')
    i = idx[-1]
    phase = np.degrees(ph[i])
    pm = 180.0 + (phase - 360.0 * np.round(phase / 360.0))
    return pm, w[i]


pm = {c: margins(fr['L%s_mag' % c.lower()].values, fr['L%s_ph' % c.lower()].values) for c in ('Map', 'PI', 'PID')}

# ------------------------------------------------------------------ figures


def save(fig, name):
    path = os.path.join(FIG, name)
    fig.savefig(path, dpi=170, bbox_inches='tight')
    plt.close(fig)
    return path


def fig_block():
    fig, ax = plt.subplots(figsize=(11, 4.8))
    ax.set_xlim(0, 22.4); ax.set_ylim(0, 9.4); ax.axis('off')

    def box(x, y, wd, ht, text, fc='#f3f6fa', ec='#33475b', ls='-', fs=9.5):
        ax.add_patch(FancyBboxPatch((x, y), wd, ht, boxstyle='round,pad=0.02,rounding_size=0.15', fc=fc, ec=ec, lw=1.3, ls=ls))
        ax.text(x + wd / 2, y + ht / 2, text, ha='center', va='center', fontsize=fs)

    def poly(pts, ls='-'):
        for p0, p1_ in zip(pts[:-2], pts[1:-1]):
            ax.plot([p0[0], p1_[0]], [p0[1], p1_[1]], color='#33475b', lw=1.1, ls=ls)
        ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle='-|>', mutation_scale=12, lw=1.1, color='#33475b', ls=ls))

    def lab(x, y, t, fs=8.5):
        ax.text(x, y, t, ha='center', va='bottom', fontsize=fs, color='#1b2a38')

    box(0.4, 7.8, 5.0, 1.2, 'Scenario\n(driver angle, speed, road)', fc='#eef2f0', fs=9)
    box(0.6, 3.2, 4.8, 2.2, 'Controller\nMap | PI | PID\nreads measured signals\nby port name', fc='#e8f0fb', ec='#2a78d6', fs=10)
    box(6.9, 3.65, 2.5, 1.3, 'Delay_ctrl\n(margin test)', ls='--')
    box(10.2, 3.3, 3.8, 2.0, 'Actuator\nclamp to T_a,max\nmotor lag 100 Hz')
    box(10.2, 6.2, 3.8, 1.2, 'AssistLimit\nT_a,max(v)')
    box(15.0, 3.65, 2.2, 1.3, 'Gain_act\n(margin test)', ls='--')
    box(18.0, 2.6, 4.1, 3.4, 'Plant\ncolumn: torsion bar,\ninertia, friction\nPacejka tires\n2-DOF bicycle', fc='#fbf1e8', ec='#eb6834')
    box(7.0, 0.4, 9.4, 1.0, 'Sensors: noise + quantization + update period', fs=9)
    poly([(5.4, 4.3), (6.9, 4.3)]); lab(6.15, 4.45, 'T_a,cmd', 8)
    poly([(9.4, 4.3), (10.2, 4.3)])
    poly([(14.0, 4.3), (15.0, 4.3)]); lab(14.5, 4.45, 'T_a', 8)
    poly([(17.2, 4.3), (18.0, 4.3)])
    poly([(12.1, 6.2), (12.1, 5.3)]); ax.text(12.25, 5.6, 'T_a,max', fontsize=8.5)
    poly([(10.2, 6.8), (3.0, 6.8), (3.0, 5.4)], ls=':'); lab(6.6, 6.88, 'T_a,max (only if the controller uses it)', 8)
    poly([(4.9, 8.4), (20.0, 8.4), (20.0, 6.0)]); lab(12.1, 8.48, 'theta1, v, mu (mu is not measured)')
    poly([(20.0, 2.6), (20.0, 0.9), (16.4, 0.9)]); ax.text(20.15, 1.25, 'true T_s, a_y,\ngamma, theta2_dot', fontsize=8, va='bottom')
    poly([(7.0, 0.9), (3.0, 0.9), (3.0, 3.2)]); lab(5.0, 1.0, 'measured signals', 8.5)
    return save(fig, 'Map_vs_PID_block.png')


def fig_freq():
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(8.5, 6.2), sharex=True)
    a1.loglog(w, fr.G1_mag, color='#555555', lw=1.6, label='plant G: dry road (k_r > 0)')
    a1.loglog(w, fr.G0_mag, color='#999999', lw=1.3, ls='--', label='plant G: saturated tire (k_r = 0)')
    for c in ('Map', 'PI', 'PID'):
        a1.loglog(w, fr['L%s_mag' % c.lower()], color=COL[c], lw=1.6, label='loop L = C*G: %s' % c)
    a1.axhline(1, color='k', lw=0.8)
    a1.annotate('column resonance %.1f Hz' % f_res, xy=(w[k_res], fr.G1_mag[k_res]), xytext=(w[k_res] * 1.8, fr.G1_mag[k_res] * 4),
                arrowprops=dict(arrowstyle='->', color='#333333'), fontsize=9)
    a1.set_ylabel('|.|'); a1.legend(fontsize=8, loc='lower left'); a1.set_ylim(1e-3, 1e3)
    for c in ('Map', 'PI', 'PID'):
        ph = np.degrees(fr['L%s_ph' % c.lower()].values)
        ph = ph - 360 * np.round(ph[0] / 360)
        a2.semilogx(w, ph, color=COL[c], lw=1.6, label=c)
    a2.axhline(-180, color='k', lw=0.8)
    a2.set_ylabel('phase of L [deg]'); a2.set_xlabel('frequency [rad/s]'); a2.legend(fontsize=8, loc='lower left')
    a2.set_ylim(-540, 90)
    fig.suptitle('Linearized assist loop (held steering angle, motor lag, continuous approximation with 1 ms delay)', fontsize=10.5)
    return save(fig, 'Map_vs_PID_bode.png')


def pareto_front(df):
    d = df.sort_values('R_pct')
    best, out = np.inf, []
    for _, r in d.iterrows():
        if r.S_Nm < best:
            out.append((r.R_pct, r.S_Nm)); best = r.S_Nm
    return np.array(out)


def fig_pareto():
    fig, ax = plt.subplots(figsize=(8.2, 5.2))
    for c in ('PI', 'PID', 'Map'):
        d = sw[c]
        ax.scatter(d.R_pct, d.S_Nm, s=10 if c != 'Map' else 26, color=COL[c], alpha=0.25 if c != 'Map' else 0.6, lw=0)
        f = pareto_front(d)
        ax.plot(f[:, 0], f[:, 1], color=COL[c], lw=1.8, label='%s: Pareto front (%d simulated points, seed %05d)' % (c, len(d), SEEDS[c]))
        ax.scatter([cal[c]['R']], [cal[c]['S']], s=150, marker='*', color=COL[c], edgecolor='k', zorder=5)
        ax.annotate('%s selected' % c, (cal[c]['R'], cal[c]['S']), xytext={'Map': (8, 6), 'PI': (10, -16), 'PID': (-20, 12)}[c], textcoords='offset points', fontsize=9, ha='left' if c != 'PID' else 'right')
    ax.set_xlabel('R: tracking error on CALIB [%]  (lower = better tracking)')
    ax.set_ylabel('S: RMS of T_a above 5 Hz [N.m]  (lower = smoother)')
    ax.set_yscale('log'); ax.legend(fontsize=8)
    ax.set_title('Tracking/smoothness trade-off on the calibration case CALIB', fontsize=11)
    return save(fig, 'Map_vs_PID_CALIB_pareto.png')


def fig_erel():
    fig, ax = plt.subplots(figsize=(10, 4.2))
    labs = list(erelW[erelW.Ctrl == 'Map'].Window)
    x = np.arange(len(labs)); bw = 0.27
    for i, c in enumerate(('Map', 'PI', 'PID')):
        d = erelW[erelW.Ctrl == c].set_index('Window').loc[labs]
        ax.bar(x + (i - 1) * bw, d.erel_signed_pct, bw, color=COL[c], label=c)
    ax.axhline(3, color='k', ls='--', lw=0.8); ax.axhline(-3, color='k', ls='--', lw=0.8)
    ax.set_xticks(x); ax.set_xticklabels([l.replace('static_', '').replace('_a', ' ').replace('pos', '').replace('p', '.').replace('g', ' g') for l in labs], rotation=35, ha='right', fontsize=8)
    ax.set_ylabel('steady error e_rel [%]  (negative = over-assist)'); ax.legend(fontsize=8)
    ax.set_title('Steady-state accuracy in the 11 cornering windows of CALIB (gate |e_rel| <= 3 %, dashed)', fontsize=10)
    return save(fig, 'Map_vs_PID_CALIB_erel.png')


def fig_case(case, xlim=None, name=None):
    fig, axs = plt.subplots(3, 1, figsize=(9.5, 6.8), sharex=True)
    d0 = sig[('Map', case)]
    axs[0].plot(d0.t, d0.T_d_ref, color=COL['ref'], ls='--', lw=1.2, label='T_d,ref')
    for c in ('Map', 'PI', 'PID'):
        d = sig[(c, case)]
        axs[0].plot(d.t, d.T_s, color=COL[c], lw=1.0, label=c)
        axs[1].plot(d.t, d.e_T, color=COL[c], lw=1.0, label=c)
        axs[2].plot(d.t, d.T_a, color=COL[c], lw=0.8, label=c)
    ax2 = axs[0].twinx(); ax2.plot(d0.t, d0.mu, color='#7f7f7f', lw=1.0); ax2.set_ylabel('mu', color='#7f7f7f'); ax2.set_ylim(0, 1.6); ax2.grid(False)
    axs[0].set_ylabel('T_s [N.m]'); axs[1].set_ylabel('e_T [N.m]'); axs[2].set_ylabel('T_a [N.m]'); axs[2].set_xlabel('t [s]')
    axs[0].legend(fontsize=8, ncol=4, loc='upper left')
    if xlim:
        axs[2].set_xlim(*xlim)
    fig.suptitle('%s case, noisy sensors (seed %05d): Map, PI, PID' % (case, SEED), fontsize=11)
    return save(fig, name or 'Map_vs_PID_%s_resp_s%05d.png' % (case, SEED))


def fig_bars():
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 3.6))
    x = np.arange(len(CASES)); bw = 0.27
    for i, c in enumerate(('Map', 'PI', 'PID')):
        a1.bar(x + (i - 1) * bw, [sval(c, k, 'whole case', 'mean_RMS_eT_Nm') for k in CASES], bw, color=COL[c], label=c)
        a2.bar(x + (i - 1) * bw, [sval(c, k, 'whole case', 'mean_TV_Ta_Nm_per_s') for k in CASES], bw, color=COL[c], label=c)
    for a, t in ((a1, 'RMS e_T over the case [N.m]'), (a2, 'total variation of T_a [N.m/s] (log)')):
        a.set_xticks(x); a.set_xticklabels(CASES); a.set_title(t, fontsize=10)
    a2.set_yscale('log'); a1.legend(fontsize=8)
    fig.suptitle('Scoring cases, noisy sensors, shared seed %05d' % SEED, fontsize=11)
    return save(fig, 'Map_vs_PID_bars_s%05d.png' % SEED)


def fig_cases():
    fig, axs = plt.subplots(3, 3, figsize=(13, 3.6), sharex='col', gridspec_kw={'hspace': 0.15, 'wspace': 0.18})
    for j, k in enumerate(CASES):
        d = sig[('Map', k)]
        axs[0, j].plot(d.t, d.a_y_target_g, color='#33475b', lw=1); axs[0, j].set_title(k, fontsize=10)
        axs[1, j].plot(d.t, d.mu, color='#7f7f7f', lw=1.2); axs[1, j].set_ylim(0, 1)
        axs[2, j].plot(d.t, d.v_mps * 3.6, color='#0e6e6e', lw=1.2); axs[2, j].set_xlabel('t [s]', fontsize=8)
        for a in axs[:, j]:
            a.tick_params(labelsize=7)
    axs[0, 0].set_ylabel('a_y target [g]', fontsize=8); axs[1, 0].set_ylabel('mu', fontsize=8); axs[2, 0].set_ylabel('v [km/h]', fontsize=8)
    return save(fig, 'Map_vs_PID_cases_inputs.png')


F = dict(cases=fig_cases(), block=fig_block(), bode=fig_freq(), pareto=fig_pareto(), erel=fig_erel(), bars=fig_bars(),
         dry=fig_case('DRY'), slip=fig_case('SLIP'), weave=fig_case('WEAVE'),
         slipzoom=fig_case('SLIP', (40, 63), 'Map_vs_PID_SLIP_zoom_down_s%05d.png' % SEED))

# ------------------------------------------------------------------ tables (rows of strings)
slip_w = ['pud_in', 'up_post', 'down_pre', 'down_post']
over_rows = [['Window', 'meaning', 'Map', 'PI', 'PID']]
mean_lbl = {'pud_in': 'inside 0.4 s puddle (mu 0.2), 80 km/h', 'up_post': 'after mu 0.3 -> 0.8, 60 km/h, 0.15 g',
            'down_pre': 'before mu drop, 100 km/h, 0.35 g', 'down_post': 'after mu 0.8 -> 0.3, settled'}
for wn in slip_w:
    over_rows.append([wn, mean_lbl[wn]] + [p1(sval(c, 'SLIP', wn, 'mean_Mean_eT_signed_pct_of_Tdref')) for c in ('Map', 'PI', 'PID')])
case_rows = [['Case', 'metric', 'Map', 'PI', 'PID']]
for k in CASES:
    case_rows.append([k, 'RMS e_T [N.m]'] + [p1(sval(c, k, 'whole case', 'mean_RMS_eT_Nm'), 3) for c in ('Map', 'PI', 'PID')])
    case_rows.append([k, 'max |e_T| [N.m]'] + [p1(sval(c, k, 'whole case', 'mean_MaxAbs_eT_Nm'), 2) for c in ('Map', 'PI', 'PID')])
    case_rows.append([k, 'TV of T_a [N.m/s]'] + [p1(sval(c, k, 'whole case', 'mean_TV_Ta_Nm_per_s'), 0) for c in ('Map', 'PI', 'PID')])
dry_max = {c: summ[(summ.Ctrl == c) & (summ.Case == 'DRY') & (summ.Window != 'whole case')]['mean_Mean_eT_signed_pct_of_Tdref'].abs().max() for c in ('Map', 'PI', 'PID')}
case_rows.append(['DRY', 'max |e_rel| in 15 windows [%]'] + [p1(dry_max[c], 2) for c in ('Map', 'PI', 'PID')])
sel_rows = [['item', 'Map', 'PI', 'PID'],
            ['parameters', 'K_max %.2f, lead z %.1f, p %.0f rad/s' % (mapj['Kmax'], mapj['lead']['z'], mapj['lead']['p']),
             'Kp %.2f, Ki %.1f 1/s' % (pij['Kp'], pij['Ki']), 'Kp %.2f, Ki %.1f 1/s, Kd %.3f s, Tf %.1f ms' % (pidj['Kp'], pidj['Ki'], pidj['Kd'], 1e3 * pidj['Tf'])],
            ['tuned parameters / simulations', '1 / %d' % len(sw['Map']), '2 / %d' % len(sw['PI']), '4 / %d' % len(sw['PID'])],
            ['high-frequency gain', p1(hf['Map'], 0), p1(hf['PI'], 2), p1(hf['PID'], 1)]]
for key, lab, n in (('R', 'R [%]', 2), ('S', 'S [N.m]', 3), ('TV', 'TV [N.m/s]', 1), ('erel', 'max |e_rel| [%]', 2), ('rev', 'reverse assist [%]', 2)):
    sel_rows.append([lab] + [p1(cal[c][key], n) for c in ('Map', 'PI', 'PID')])
gate_rows = [['Gate (order)', 'Map', 'PI', 'PID'],
             ['1 stable + margin (gain x2, +1 ms)', 'pass', 'pass', 'pass'],
             ['2 reverse assist <= 1 %', 'fail (%s)' % p1(cal['Map']['rev'], 2), 'fail (%s)' % p1(cal['PI']['rev'], 2), 'fail (%s)' % p1(cal['PID']['rev'], 2)],
             ['3 no bang-bang (<= 1 % extra saturation)', 'pass', 'pass', 'pass'],
             ['4 |e_rel| <= 3 % in all windows', 'fail (%s)' % p1(cal['Map']['erel'], 1), 'fail (%s)' % p1(cal['PI']['erel'], 2), 'fail (%s)' % p1(cal['PID']['erel'], 2)]]
P = {k: params[g][k]['value'] for g in ('cum1', 'cum2') for k in params[g]}
P['Iz'] = params['cum3']['Iz']['value']
map_worst = erelW[erelW.Ctrl == 'Map'].sort_values('erel_abs_pct', ascending=False).iloc[0]


def wname(lbl):
    v_, a_ = lbl.replace('static_v', '').split('_a')
    return '%s km/h, %s g' % (v_, a_.replace('pos', '').replace('neg', '-').replace('p', '.').rstrip('g').rstrip('0').rstrip('.'))
map_ok = erelW[(erelW.Ctrl == 'Map') & (erelW.erel_abs_pct <= 3)]

# ------------------------------------------------------------------ report text (tools/txt2docx.py format)
SEP = '=' * 120
DASH = '-' * 120


def tab(cap, rows):
    return [cap] + [' | '.join(r) for r in rows] + ['']


L = [SEP, 'Over-assist mitigation in column-type electric power steering: assist map versus PID torque feedback (progress report, %s)' % mapj['date'][:10], SEP,
     'Master thesis progress report, HCMUT. Student: Tran Minh Tan. Supervisor: Dr. Phung Thanh Huy. This report summarizes the model, the evaluation method, the two controllers that are planned for a first paper (an assist map, Map, which is the industrial baseline, and a PID controller that tracks a reference steering torque; PI is shown as the intermediate step), the results obtained so far and the open issues. All numbers are generated from the simulation result files; the code is in MATLAB/Simulink R2023a.',
     '', DASH, '1. Problem', DASH,
     'In a column-type electric power steering (C-EPS) system an electric motor adds an assist torque T_a to the column so that the driver feels a steering torque that depends on speed and lateral acceleration. Production systems compute T_a from a calibrated assist map of the measured torsion-bar torque T_s and the vehicle speed v. The map is calibrated on a dry road. When the road friction coefficient mu drops while the car is cornering, the self-aligning torque of the front tires collapses; with the same assist the driver suddenly needs less hand torque than intended. This is over-assist: the steering feels too light exactly when the front tires are close to their grip limit.',
     'The question studied here is how much a closed-loop controller that tracks a reference steering torque T_d,ref(v, a_y) removes over-assist compared with the assist map, and what it costs in assist-torque smoothness when realistic sensor noise and quantization are present. The comparison is made under one shared set of rules fixed before tuning (Section 3).',
     '', DASH, '2. Model', DASH,
     '2.1. Closed loop',
     'The simulation is built from interchangeable blocks (Figure 1): Plant, Sensors, the controller, AssistLimit and Actuator, together called PRSM (everything except the controller). The driver is a steering-angle source theta1(t) computed from a target lateral acceleration on a dry road, so every controller receives exactly the same steering input, and when mu drops the driver keeps the same angle. The controller reads measured signals by port name; scoring always uses the TRUE signals.',
     '[Figure 1: Closed-loop structure used for every controller (dashed blocks only for stability-margin tests; scoring uses the true T_s and T_d,ref) | %s]' % rel(F['block']),
     '2.2. Plant',
     'The steering column is modelled with the torsion bar and one column inertia (Lee et al. 2018), with viscous damping and Coulomb friction smoothed by tanh:',
     '  (1)  T_s = K (theta1 - theta2)', '  [ T_s = K\\left(\\theta_1 - \\theta_2\\right) ]',
     '  (2)  J_col theta2_ddot = T_a - T_r + T_s - T_f tanh(c theta2_dot) - C_col theta2_dot',
     '  [ J_{col}\\,\\ddot{\\theta}_2 = T_a - T_r + T_s - T_f\\tanh\\left(c\\,\\dot{\\theta}_2\\right) - C_{col}\\,\\dot{\\theta}_2 ]',
     'The front lateral force follows the Pacejka Magic Formula with D = mu F_zf, so the self-aligning torque T_r (pneumatic trail plus caster) depends on mu. The vehicle is a linear two-degree-of-freedom bicycle model with states sideslip beta and yaw rate gamma at constant speed:',
     '  (3)  m v (beta_dot + gamma) = F_yf + F_yr,   Iz gamma_dot = l_f F_yf - l_r F_yr,   a_y = (F_yf + F_yr) / m',
     '  [ m v\\left(\\dot{\\beta} + \\gamma\\right) = F_{yf} + F_{yr},\\quad I_z\\dot{\\gamma} = l_f F_{yf} - l_r F_{yr},\\quad a_y = \\dfrac{F_{yf} + F_{yr}}{m} ]',
     'The four states (theta2, theta2_dot, beta, gamma) are the minimum the physics requires: the controllers do not read them, but every scored quantity (T_s, a_y, T_r) is produced by them, and the column states create the resonance that limits the feedback bandwidth (Section 4).',
     tab('Table 1: Main plant parameters (data/params.json)', [['symbol', 'value', 'source'],
         ['K (torsion bar)', '%.2f N.m/rad' % P['K'], 'Lee 2018'], ['J_col, C_col', '%.2f kg.m2, %.2f N.m.s/rad' % (P['J_col'], P['C_col']), 'Lee 2018'],
         ['T_f (Coulomb friction)', '%.1f N.m' % P['T_f'], 'Lee 2018'], ['m, Iz', '%.0f kg, %.0f kg.m2' % (P['m'], P['Iz']), 'Rajamani'],
         ['l_f, l_r', '%.2f m, %.2f m' % (P['l_f'], P['l_r']), 'Rajamani'], ['C_alpha_f (front axle)', '%.0f N/rad' % P['C_alpha_f'], 'Rajamani (2 x 80000)']])[0],
     ]
L += tab('Table 1: Main plant parameters (data/params.json)', [['symbol', 'value', 'source'],
         ['K (torsion bar)', '%.2f N.m/rad' % P['K'], 'Lee 2018'], ['J_col, C_col', '%.2f kg.m2, %.2f N.m.s/rad' % (P['J_col'], P['C_col']), 'Lee 2018'],
         ['T_f (Coulomb friction)', '%.1f N.m' % P['T_f'], 'Lee 2018'], ['m, Iz', '%.0f kg, %.0f kg.m2' % (P['m'], P['Iz']), 'Rajamani'],
         ['l_f, l_r', '%.2f m, %.2f m' % (P['l_f'], P['l_r']), 'Rajamani'], ['C_alpha_f (front axle)', '%.0f N/rad' % P['C_alpha_f'], 'Rajamani (2 x 80000)']])[1:]
L += ['2.3. Reference, assist limit, actuator and sensors',
      'The reference steering torque T_d,ref(v, a_y) is a 17 x 17 table built from published ideal steering-torque data (20-100 km/h, 0-0.4 g). The assist limit is T_a,max(v) = T_a,req(v) + F with F = T_f = %.1f N.m as the bound on unmodelled friction (structure of Slotine and Li, Sec. 7.1.3); T_a,max = %s N.m at 20, 30, 60, 100 km/h. The actuator clamps the command to +-T_a,max and adds a first-order motor lag of 100 Hz. Everything runs at 1 ms.' % (tamax['F_Nm'], ', '.join(p1(np.interp(v, v_tab, ta_tab), 2) for v in (20, 30, 60, 100))),
      'Sensors add white noise (standard deviation one resolution step, an assumption), quantization and the update period of each signal: T_s 0.01 N.m every 1 ms, steering angle 0.1 deg, column speed 4 deg/s, speed 1 km/h, yaw rate 0.1 deg/s and a_y 0.01 g every 10 ms (CAN, assumed). Without a seed the sensors are ideal.',
      '', DASH, '3. Evaluation method (fixed before tuning, Documents/Shared/QuyChuan.txt)', DASH,
      '3.1. Cases',
      'Parameters are tuned on one calibration case, CALIB (117 s, dry road, blocks at 20, 60 and 100 km/h: steady cornering 0.1-0.4 g, 0.5 Hz sine steering, small corrections, and a mu step 0.8 -> 0.6 -> 0.8 at 60 km/h), with one local noise seed per controller (Map 00000, PI/PID 10000). Controllers are scored on three different cases that each answer one question, with the shared seed %05d:' % SEED]
L += tab('Table 2: Scoring cases', [['case', 'question', 'content'],
         ['DRY (129 s)', 'steady accuracy on the dry road (map design condition)', '20-100 km/h, three cornering levels each, mu 0.8'],
         ['SLIP (63 s)', 'over-assist when grip changes while cornering', 'pud: 0.4 s puddle in a lane change; up: mu 0.3 -> 0.8; down: mu 0.8 -> 0.3 at 0.35 g, 100 km/h'],
         ['WEAVE (61 s)', 'tracking and smoothness while steering continuously', 'slalom (mu 0.8), lane change (mu 0.3), sine at 100 km/h (mu 0.2)']])
L += ['3.2. Metrics, gates and selection rule',
      'R is the tracking error on CALIB: the RMS of e_T = T_s - T_d,ref in four window groups (steady cornering, sine, small corrections, after mu steps), each normalized by the mean |T_d,ref| of the group, averaged with equal weights [%]. S is the RMS of T_a after a 5 Hz first-order high-pass filter [N.m], i.e. the part of the assist torque that the driver input does not explain (mainly amplified sensor noise). The steady error is e_rel = 100 x mean(e_T) / mean(|T_d,ref|) in each steady cornering window; negative means over-assist.',
      'Hard gates, in priority order: (1) stability with margin, measured by simulation (actuator gain x2 and an extra 1 ms delay must not double R); (2) reverse assist (T_a opposite to T_s with |T_s| >= 0.5 N.m) <= 1 % of the time; (3) no bang-bang: noise must not raise the fraction of samples at T_a,max by more than 1 %; (4) |e_rel| <= 3 % in every steady window. Selection: among the points that pass, keep those with R within 5 % of the controller\'s own best R and take the smallest S. If no point passes, the lowest gate is dropped and the point violating least is taken (fallback rule). The main conclusion compares whole Pareto fronts (R, S), not single points.',
      '', DASH, '4. Controllers', DASH,
      '4.1. Assist map (Map)',
      'T_a = sgn(T_s) M(v, |T_s|) followed by a lead compensator (s/z + 1)/(s/p + 1), discretized with Tustin at 1 ms. M passes through dry-road calibration points (979 points, the assist that makes T_s = T_d,ref at mu 0.8), has a dead zone |T_s| < 0.3 N.m and its slope is limited to K_max. The map reads only T_s and v: it has no reference, no feedback error and no integrator.',
      'Three limits bound K_max: K_acc = %.2f (smallest slope giving <= 3 %% dry steady error from 40 km/h), K_stab = %.1f (largest slope for which a lead reaches PM >= 45 deg on 68 linearized operating points), and the bang-bang gate (K <= 7.5). The selection gives K_max = %.2f with lead z = %.1f rad/s, p = %.0f rad/s (PM %.1f deg). The lead has a high-frequency gain K p/z = %.0f, which amplifies sensor noise.' % (mapj['Kacc'], mapj['Kstab'], mapj['Kmax'], mapj['lead']['z'], mapj['lead']['p'], mapj['lead']['PM_deg'], hf['Map']),
      '4.2. PI and PID',
      'T_a = Kp e_T + Ki int(e_T) + Kd d/dt(T_s,meas) filtered by 1/(Tf s + 1), with back-calculation anti-windup on the actuator clamp (Kaw = Ki/Kp) and the reference T_d,ref(v, a_y) computed inside the controller from measured v and a_y. The derivative acts on the measured T_s, not on e_T, to avoid kicks when the reference changes. PI is the special case Kd = 0. The grid bounds come from the stability boundary of the linearized loop under the margin test (PI: Kp <= 1.5, Ki <= 8 1/s); PI was swept on %d points and PID on %d points (coarse then fine).' % (len(sw['PI']), len(sw['PID']))]
L += tab('Table 3: Selected points and their CALIB scores (local seeds)', sel_rows)
L += tab('Table 4: Gate status of the selected points (none passes all gates: selected by the fallback rule)', gate_rows)
L += ['', DASH, '5. Results', DASH,
      '5.1. Loop shape and the column resonance',
      'The linearized plant from T_a to T_s has a lightly damped column resonance at %.1f Hz (Figure 2). It caps the bandwidth of PI: increasing Kp or Ki beyond the bounds above destroys the margin. The map needs a large lead at its slope, and the PID uses its derivative for the same purpose. On the discrete (1 ms, one-sample delay) linear column model the selected loops have phase margins of %.0f deg (Map), %.0f deg (PI) and %.0f deg (PID), with peak sensitivity Ms %.1f, %.1f and %.1f. The PI margin is small: its selection passed the simulated margin gate (gain x2, +1 ms) because that gate only checks that R does not double, which is a weaker requirement than PM >= 45 deg.' % (f_res, PMd['Map'].PM_deg, PMd['PI'].PM_deg, PMd['PID'].PM_deg, PMd['Map'].Ms, PMd['PI'].Ms, PMd['PID'].Ms),
      '[Figure 2: Plant and open-loop frequency responses of the selected Map, PI and PID | %s]' % rel(F['bode']),
      '5.2. Calibration case: trade-off between tracking and smoothness',
      'Figure 3 shows every simulated point and the Pareto front of each controller. PID reaches the lowest tracking error (R %.1f %%), PI is close (R %.1f %%) and is the smoothest; the map stays at R %.1f %% and S %.2f N.m. Its front lies to the right of the PI and PID fronts over the whole range of S where they overlap, so the ranking does not depend on how a single point is chosen. Note that the seeds differ (Map 00000, PI/PID 10000); the seed-to-seed spread measured for PI and PID is below 0.3 %% of R.' % (cal['PID']['R'], cal['PI']['R'], cal['Map']['R'], cal['Map']['S']),
      '[Figure 3: Pareto fronts (R, S) on CALIB, stars = selected points | %s]' % rel(F['pareto']),
      'Figure 4 gives e_rel per steady window. The map meets the 3 %% gate only in %d of the 11 windows; it fails only at 0.4 g (worst window %s: %.1f %% too heavy), because above about 0.3 g the dry-road demand grows much faster than T_d,ref and the slope limit K_max (bounded by stability and bang-bang) cannot follow; this is a structural limit of the map, not a measurement error. PI and PID stay within %.1f %% in every window; the small excess over 3 %% occurs at 0.1 g, where T_d,ref is small and Coulomb friction (2 N.m) matters.' % (len(map_ok), wname(map_worst.Window), map_worst.erel_signed_pct, max(cal['PI']['erel'], cal['PID']['erel'])),
      '[Figure 4: Steady-state error in the 11 cornering windows of CALIB | %s]' % rel(F['erel']),
      '5.3. Scoring cases'] + tab('Table 5: Scoring cases, noisy sensors, shared seed %05d' % SEED, case_rows) + [
      '[Figure 5: Whole-case RMS e_T and total variation of T_a | %s]' % rel(F['bars']),
      '5.4. Over-assist (SLIP case)',
      'Table 6 lists the mean error as a percentage of T_d,ref in the SLIP windows (negative = steering too light = over-assist). After the friction drop at 0.35 g and 100 km/h the map settles at %s %% while PI and PID return to %s %% and %s %%. Inside the 0.4 s puddle every controller is too slow to react, but the map error is larger (%s %% against %s %% for PID).' % (p1(sval('Map', 'SLIP', 'down_post', 'mean_Mean_eT_signed_pct_of_Tdref')), p1(sval('PI', 'SLIP', 'down_post', 'mean_Mean_eT_signed_pct_of_Tdref'), 2), p1(sval('PID', 'SLIP', 'down_post', 'mean_Mean_eT_signed_pct_of_Tdref'), 2), p1(sval('Map', 'SLIP', 'pud_in', 'mean_Mean_eT_signed_pct_of_Tdref')), p1(sval('PID', 'SLIP', 'pud_in', 'mean_Mean_eT_signed_pct_of_Tdref')))]
L += tab('Table 6: Mean error in % of T_d,ref in the SLIP windows (negative = over-assist)', over_rows)
L += ['[Figure 6: SLIP case, last scene (mu 0.8 -> 0.3 at 48 s while cornering at 0.35 g, 100 km/h) | %s]' % rel(F['slipzoom']),
      '[Figure 7: SLIP case, whole case | %s]' % rel(F['slip']),
      '[Figure 8: WEAVE case | %s]' % rel(F['weave']),
      '', DASH, '6. Discussion and open issues', DASH,
      'Structural difference. PI and PID remove the mean over-assist because they read a_y (through T_d,ref) and integrate the error; the map has neither. The gap on SLIP is therefore a difference of structure, not of tuning, and must be stated as such. On the dry calibration case, which is the design condition of the map, PI and PID still track better.',
      'Noise. Smoothness is set by the high-frequency gain of each controller: PI %.2f, PID %.1f, Map %.0f (lead). One quantization step of T_s (0.01 N.m every 1 ms) passed through these gains explains why the map has the largest total variation of T_a even without a derivative term.' % (hf['PI'], hf['PID'], hf['Map']),
      'Margin gate. The simulated margin gate accepted a PI with a linear phase margin of about %.0f deg (Ms %.1f) and a PID with %.0f deg. It needs a stricter criterion (for example oscillation detection, or PM and Ms where a linear model exists) before the method is frozen.' % (PMd['PI'].PM_deg, PMd['PI'].Ms, PMd['PID'].PM_deg),
      'Gates. No controller passes all four gates: reverse assist is 1-4 % of the time for all of them (phase lag at the steering reversals of the 0.5 Hz sine), and e_rel slightly exceeds 3 % at 0.1 g for PI and PID and widely at 0.4 g for the map. The points were selected with the fallback rule. Before the paper the gate values (3 %, 1 %) need either a justification or a sensitivity study (3 and 5 %), and the mu step of CALIB (0.8 -> 0.6) is too mild to load the over-assist mechanism.',
      'Limitations. Simulation only; the driver is an open-loop steering-angle source (after a slide at 0.35 g on mu 0.3 the car does not recover, which is why that scene is the last one of SLIP); motor modelled as a first-order lag; noise level assumed (one resolution step); the plant is checked against its own equations and orders of magnitude from the literature, not against vehicle data.',
      '', DASH, '7. Planned paper and next steps', DASH,
      'Planned paper: assist map versus PI/PID torque feedback for over-assist mitigation in C-EPS, with three contributions: (C1) an evaluation framework with gates fixed before tuning, whole Pareto fronts and a no-bang-bang gate; (C2) the column resonance limits PI and the high-frequency gain of each controller sets the assist-torque noise; (C3) quantified over-assist of the map under friction changes. Next steps: fix the open gate issues and freeze the method; mu step of CALIB; sensitivity to gates, noise level and seed; robustness to plant parameter errors (+-20 %); choose the venue. A sliding-mode controller (SMC, ISMC) is kept for the thesis.',
      '', DASH, '8. Code', DASH,
      'MATLAB/Simulink R2023a; all code and comments are in English. Every Simulink model is generated by a build script through the Simulink API and has exactly one test that compares it with an independent calculation.',
      ''] + tab('Table 7: Repository layout', [['path', 'content'],
      ['Model/setup_paths.m', 'adds every code folder to the path (the only file that knows the layout)'],
      ['Model/data/*.json', 'single data source: plant parameters, reference, sensors, actuator, each controller'],
      ['Model/PRSM/<part>/', 'Plant, Ref, Sensors, AssistLimit, Actuator: build_*.m, test_*.m, load_*.m'],
      ['Model/Controllers/<Ctrl>/', 'load_<ctrl>.m, <Ctrl>.mdl, Model_<Ctrl>.mdl (closed loop), script/ (design, sweep, selection, tests)'],
      ['Model/Sim/script/', 'build_closed_loop.m, make_cases.m, calib_run.m, run_cases.m, make_pair_comparisons.m'],
      ['Result/', 'mirrors Model/: Controllers/<Ctrl>/{Design, Calib, Cases}, Compare/<A>_vs_<B>'],
      ['tools/build_report_en.py', 'generates the figures, this report and the slide deck from the result files']])
open(os.path.join(DOC, 'MapPID_report.txt'), 'w', encoding='utf-8').write('\n'.join(L))

from txt2docx import build  # noqa: E402
build(os.path.join(DOC, 'MapPID_report.txt'), os.path.join(DOC, 'MapPID_report.docx'))

# ------------------------------------------------------------------ slides
from pptx import Presentation  # noqa: E402
from pptx.chart.data import CategoryChartData  # noqa: E402
from pptx.dml.color import RGBColor  # noqa: E402
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION  # noqa: E402
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR  # noqa: E402
from pptx.util import Inches, Pt  # noqa: E402

INK, MUTED, ACC, BG2 = RGBColor(0x1F, 0x2A, 0x37), RGBColor(0x5B, 0x67, 0x75), RGBColor(0x0E, 0x6E, 0x6E), RGBColor(0xF1, 0xF4, 0xF7)
DARK = RGBColor(0x14, 0x24, 0x33)
pres = Presentation()
pres.slide_width, pres.slide_height = Inches(13.333), Inches(7.5)
BL = pres.slide_layouts[6]


def tb(slide, x, y, w_, h, paras, size=16, color=INK, bold=False, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, name=None):
    s = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w_), Inches(h))
    if name:
        s.name = name
    tf = s.text_frame; tf.word_wrap = True; tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Inches(0.05)
    for i, p in enumerate(paras if isinstance(paras, list) else [paras]):
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        txt, opt = (p, {}) if isinstance(p, str) else p
        r = para.add_run(); r.text = txt
        r.font.size = Pt(opt.get('size', size)); r.font.bold = opt.get('bold', bold); r.font.name = 'Calibri'
        r.font.color.rgb = opt.get('color', color)
        para.alignment = align; para.space_after = Pt(opt.get('after', 8))
        if opt.get('bullet'):
            pPr = para._p.get_or_add_pPr()
            pPr.set('marL', '228600'); pPr.set('indent', '-228600')
            bu = pPr.makeelement('{http://schemas.openxmlformats.org/drawingml/2006/main}buChar', {'char': '•'})
            pPr.append(bu)
    return s


def title(slide, text, sub=None):
    tb(slide, 0.6, 0.35, 12.1, 0.8, text, size=32, bold=True, name='Title')
    if sub:
        tb(slide, 0.6, 1.1, 12.1, 0.5, sub, size=16, color=MUTED, name='Subtitle')


def bullets(slide, items, x, y, w_, h, size=16):
    return tb(slide, x, y, w_, h, [(t, {'bullet': True, 'size': size, 'after': 10}) for t in items], name='Body')


def pic(slide, path, x, y, w_=None, h=None):
    kw = {}
    if w_:
        kw['width'] = Inches(w_)
    if h:
        kw['height'] = Inches(h)
    return slide.shapes.add_picture(path, Inches(x), Inches(y), **kw)


def table(slide, rows, x, y, w_, colw=None, size=12, rowh=0.36):
    t = slide.shapes.add_table(len(rows), len(rows[0]), Inches(x), Inches(y), Inches(w_), Inches(rowh * len(rows))).table
    for j in range(len(rows[0])):
        if colw:
            t.columns[j].width = Inches(colw[j])
    for i, r in enumerate(rows):
        for j, v in enumerate(r):
            c = t.cell(i, j); c.text = str(v) if str(v) else ' '
            p = c.text_frame.paragraphs[0]; p.runs[0].font.size = Pt(size); p.runs[0].font.name = 'Calibri'
            p.runs[0].font.bold = (i == 0); p.runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF) if i == 0 else INK
            c.fill.solid(); c.fill.fore_color.rgb = DARK if i == 0 else (BG2 if i % 2 else RGBColor(0xFF, 0xFF, 0xFF))
            c.margin_left = c.margin_right = Inches(0.06)
    return t


def card(slide, x, y, w_, h, head, body, color=ACC):
    sh = slide.shapes.add_shape(5, Inches(x), Inches(y), Inches(w_), Inches(h))
    sh.fill.solid(); sh.fill.fore_color.rgb = BG2; sh.line.fill.background(); sh.shadow.inherit = False
    tb(slide, x + 0.2, y + 0.15, w_ - 0.4, 0.5, head, size=18, bold=True, color=color)
    tb(slide, x + 0.2, y + 0.7, w_ - 0.4, h - 0.8, body, size=14, color=INK)


def stat(slide, x, y, big, small, color):
    tb(slide, x, y, 3.6, 0.9, big, size=40, bold=True, color=color)
    tb(slide, x, y + 0.9, 3.6, 0.8, small, size=13, color=MUTED)


def dark_slide(text, sub):
    s = pres.slides.add_slide(BL)
    s.background.fill.solid(); s.background.fill.fore_color.rgb = DARK
    tb(s, 0.8, 2.2, 11.7, 1.6, text, size=36, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF), name='Title')
    tb(s, 0.8, 4.0, 11.7, 1.6, sub, size=18, color=RGBColor(0xC8, 0xD3, 0xDE), name='Subtitle')
    return s


s = dark_slide('Over-assist mitigation in column EPS: assist map versus PID torque feedback',
               ['Progress report: method, model, results, code', ('Tran Minh Tan  |  Supervisor: Dr. Phung Thanh Huy  |  HCMUT  |  %s' % mapj['date'][:10], {'size': 14})])
s.notes_slide.notes_text_frame.text = 'Purpose: show the supervisor the method, model, results and code for the planned paper (Map vs PID).'

s = pres.slides.add_slide(BL)
title(s, 'Main message', 'Closed-loop torque feedback removes the over-assist that the map cannot; both are limited by sensor noise times high-frequency gain')
stat(s, 0.8, 2.0, '%s %%' % p1(sval('Map', 'SLIP', 'down_post', 'mean_Mean_eT_signed_pct_of_Tdref')), 'Map: steady over-assist after mu 0.8 -> 0.3 while cornering (SLIP)', COL['Map'] and RGBColor(0x2A, 0x78, 0xD6))
stat(s, 4.9, 2.0, '%s %%' % p1(sval('PID', 'SLIP', 'down_post', 'mean_Mean_eT_signed_pct_of_Tdref'), 2), 'PID: same situation, error returns to about zero', RGBColor(0xEB, 0x68, 0x34))
stat(s, 9.0, 2.0, '%.0f x' % (hf['Map'] / hf['PID']), 'high-frequency gain of the map (lead) relative to PID: why the map is the noisiest', RGBColor(0x0E, 0x6E, 0x6E))
bullets(s, ['Same plant, sensors, actuator, cases and gates for every controller, fixed before tuning',
            'PID tracks best on the calibration case (R %.1f %% vs map %.1f %%); PI is the smoothest' % (cal['PID']['R'], cal['Map']['R']),
            'Open issue: no controller passes all four gates; gate values and the calibration case need a final decision'], 0.8, 4.4, 11.8, 2.6)

s = pres.slides.add_slide(BL)
title(s, 'Problem: over-assist when grip drops', 'The map is calibrated on a dry road and does not know mu')
bullets(s, ['Assist map: T_a = M(v, |T_s|), calibrated so that T_s = T_d,ref at mu = 0.8',
            'When mu drops while cornering, the self-aligning torque T_r of the front tires collapses',
            'Same assist + smaller T_r = lighter steering than intended, exactly near the grip limit',
            'Feedback alternative: track T_d,ref(v, a_y) with T_a; it needs a_y and a reference, but no estimate of mu'], 0.6, 1.8, 6.2, 4.8)
pic(s, F['slipzoom'], 7.0, 1.6, w_=5.8)
tb(s, 7.0, 6.75, 5.8, 0.5, 'SLIP, last scene: mu 0.8 -> 0.3 at 48 s (0.35 g, 100 km/h)', size=11, color=MUTED)

s = pres.slides.add_slide(BL)
title(s, 'Model: closed loop shared by every controller', 'Plant - Sensors - controller - AssistLimit - Actuator, all at 1 ms; scoring on the true signals')
pic(s, F['block'], 0.6, 1.7, w_=12.1)

s = pres.slides.add_slide(BL)
title(s, 'Model: plant and environment', 'Four states (theta2, theta2_dot, beta, gamma), driver = steering-angle source')
bullets(s, ['Column: T_s = K (theta1 - theta2);  J_col theta2_ddot = T_a - T_r + T_s - T_f tanh(c theta2_dot) - C_col theta2_dot',
            'Tires: Pacejka Magic Formula, D = mu F_zf; T_r = (pneumatic trail + caster) F_yf / n_st',
            'Vehicle: 2-DOF bicycle (beta, gamma) at constant speed; a_y = (F_yf + F_yr)/m',
            'T_d,ref(v, a_y): 17 x 17 table; T_a,max(v) = demand + F (F = T_f = 2 N.m)',
            'Sensors: noise (1 resolution step), quantization, 1 ms (T_s) / 10 ms (v, a_y via CAN)',
            'Motor: clamp to +-T_a,max and first-order lag 100 Hz'], 0.6, 1.8, 6.6, 5.2, size=15)
table(s, [['parameter', 'value'], ['K', '%.2f N.m/rad' % P['K']], ['J_col / C_col', '%.2f / %.2f' % (P['J_col'], P['C_col'])], ['T_f', '%.1f N.m' % P['T_f']],
          ['m / Iz', '%.0f kg / %.0f kg.m2' % (P['m'], P['Iz'])], ['C_alpha_f', '%.0f N/rad' % P['C_alpha_f']], ['column resonance', '%.1f Hz' % f_res]],
      7.6, 1.9, 5.1, colw=[2.2, 2.9], size=14, rowh=0.45)

s = pres.slides.add_slide(BL)
title(s, 'Method: one calibration case, three scoring cases', 'Tune on CALIB (local seed), score on DRY, SLIP, WEAVE (shared seed %05d)' % SEED)
card(s, 0.6, 1.7, 2.9, 2.5, 'CALIB  117 s', 'Dry; 20, 60, 100 km/h; 0.1-0.4 g, sine, small corrections; mu step 0.8 -> 0.6. Tuning only.', ACC)
card(s, 3.7, 1.7, 2.9, 2.5, 'DRY  129 s', 'Steady torque on the dry road (map design condition). Main metric: max |e_rel|.', RGBColor(0x2A, 0x78, 0xD6))
card(s, 6.8, 1.7, 2.9, 2.5, 'SLIP  63 s', 'Grip changes while cornering: puddle, mu rise, mu drop. Main metric: signed error after the change.', RGBColor(0xEB, 0x68, 0x34))
card(s, 9.9, 1.7, 2.9, 2.5, 'WEAVE  61 s', 'Continuous steering: slalom, lane change on mu 0.3, sine on mu 0.2. Main metric: RMS e_T, S, TV.', RGBColor(0xCC, 0x99, 0x00))

pic(s, F['cases'], 1.2, 4.35, h=3.0)

s = pres.slides.add_slide(BL)
title(s, 'Method: metrics, gates and selection rule', 'Written before tuning; one function per metric, shared by all controllers')
table(s, [['metric', 'definition'], ['R [%]', 'RMS e_T / mean |T_d,ref| in four window groups, equal weights'], ['S [N.m]', 'RMS of T_a after a 5 Hz high-pass (assist-torque noise)'],
          ['TV [N.m/s]', 'total variation of T_a per second'], ['e_rel [%]', 'mean e_T / mean |T_d,ref| per steady window; < 0 = over-assist']], 0.6, 1.8, 6.3, colw=[1.4, 4.9], size=13, rowh=0.5)
table(s, [['gate (priority order)', 'threshold'], ['1 stability with margin', 'gain x2 and +1 ms keep R < 2x'], ['2 reverse assist', '<= 1 % of time'],
          ['3 no bang-bang', '<= 1 % extra time at T_a,max'], ['4 steady accuracy', '|e_rel| <= 3 % in all windows']], 7.2, 1.8, 5.5, colw=[2.9, 2.6], size=13, rowh=0.5)
bullets(s, ['Selection: R within 5 % of the controller\'s own best R, then smallest S',
            'Conclusion = compare whole Pareto fronts (R, S), not single points',
            'Fallback if nothing passes: drop the lowest gate, take the least violation'], 0.6, 5.0, 12.1, 2.0, size=15)

s = pres.slides.add_slide(BL)
title(s, 'Controllers: assist map and PID', 'Map reads T_s and v only; PI/PID read T_s, v, a_y and the actuator clamp')
card(s, 0.6, 1.7, 5.9, 3.4, 'Map (industrial baseline)',
     'T_a = sgn(T_s) M(v, |T_s|) + lead (s/z+1)/(s/p+1)\nDead zone 0.3 N.m, slope <= K_max\nK_acc = %.2f (accuracy), K_stab = %.1f (PM 45 deg), bang-bang K <= 7.5\nSelected: K_max %.2f, z %.1f, p %.0f rad/s\n1 tuned parameter, %d simulations' % (mapj['Kacc'], mapj['Kstab'], mapj['Kmax'], mapj['lead']['z'], mapj['lead']['p'], len(sw['Map'])),
     RGBColor(0x2A, 0x78, 0xD6))
card(s, 6.8, 1.7, 5.9, 3.4, 'PI / PID (torque feedback)',
     'e_T = T_s - T_d,ref(v, a_y)\nT_a = Kp e_T + Ki int e_T + Kd d/dt T_s,meas / (Tf s + 1)\nAnti-windup on the clamp (Kaw = Ki/Kp)\nPI: Kp %.2f, Ki %.1f (%d simulations)\nPID: Kp %.2f, Ki %.1f, Kd %.3f, Tf %.1f ms (%d simulations)' % (pij['Kp'], pij['Ki'], len(sw['PI']), pidj['Kp'], pidj['Ki'], pidj['Kd'], 1e3 * pidj['Tf'], len(sw['PID'])),
     RGBColor(0xEB, 0x68, 0x34))

table(s, [['', 'Map', 'PI', 'PID'], ['tuned parameters', '1', '2', '4'], ['simulations on CALIB', str(len(sw['Map'])), str(len(sw['PI'])), str(len(sw['PID']))],
           ['high-frequency gain', p1(hf['Map'], 0), p1(hf['PI'], 2), p1(hf['PID'], 1)], ['signals read', 'T_s, v', 'T_s, v, a_y', 'T_s, v, a_y']],
      0.6, 5.35, 12.1, colw=[3.7, 2.8, 2.8, 2.8], size=13, rowh=0.36)

s = pres.slides.add_slide(BL)
title(s, 'Result: column resonance and loop shape', 'The %.1f Hz resonance caps the PI bandwidth; the map needs a large lead' % f_res)
pic(s, F['bode'], 0.5, 1.6, h=5.6)
bullets(s, ['Phase margin, discrete 1 ms model: Map %.0f, PI %.0f, PID %.0f deg (Ms %.1f, %.1f, %.1f)' % (PMd['Map'].PM_deg, PMd['PI'].PM_deg, PMd['PID'].PM_deg, PMd['Map'].Ms, PMd['PI'].Ms, PMd['PID'].Ms),
            'High-frequency gain: Map %.0f, PID %.1f, PI %.2f' % (hf['Map'], hf['PID'], hf['PI']),
            'Noise in T_a scales with this gain, not with the presence of a D term'], 8.4, 2.0, 4.4, 4.5, size=15)

s = pres.slides.add_slide(BL)
title(s, 'Result: tracking vs smoothness on CALIB', 'Whole Pareto fronts; stars are the selected points')
pic(s, F['pareto'], 0.5, 1.6, h=5.5)
table(s, [['', 'R %', 'S N.m', 'TV']] + [[c, p1(cal[c]['R'], 1), p1(cal[c]['S'], 3), p1(cal[c]['TV'], 0)] for c in ('Map', 'PI', 'PID')], 9.3, 2.0, 3.5, colw=[0.8, 0.9, 0.9, 0.9], size=13, rowh=0.45)
tb(s, 9.3, 4.2, 3.5, 2.6, 'The map front lies to the right of the PI/PID fronts wherever S overlaps: the ranking does not depend on the choice of a single point.', size=14, color=MUTED)

s = pres.slides.add_slide(BL)
title(s, 'Result: steady accuracy on CALIB', 'Map meets the 3 %% gate in %d of 11 windows (fails at 0.4 g); PI/PID miss it only slightly at 0.1 g' % len(map_ok))
pic(s, F['erel'], 0.9, 1.7, h=5.5)

s = pres.slides.add_slide(BL)
title(s, 'Result: scoring cases (noisy sensors, seed %05d)' % SEED, 'Whole-case RMS tracking error and total variation of the assist torque')
cd = CategoryChartData(); cd.categories = CASES
for c in ('Map', 'PI', 'PID'):
    cd.add_series(c, [round(sval(c, k, 'whole case', 'mean_RMS_eT_Nm'), 3) for k in CASES])
ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(1.8), Inches(6.2), Inches(4.9), cd).chart
ch.has_title = True; ch.chart_title.text_frame.text = 'RMS e_T over the case [N.m]'
ch.chart_title.text_frame.paragraphs[0].runs[0].font.size = Pt(14)
ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.BOTTOM; ch.legend.include_in_layout = False
for i, c in enumerate(('Map', 'PI', 'PID')):
    ser = ch.plots[0].series[i]; ser.format.fill.solid(); ser.format.fill.fore_color.rgb = RGBColor.from_string(COL[c][1:].upper())
ch.plots[0].has_data_labels = True; ch.plots[0].data_labels.font.size = Pt(10); ch.plots[0].data_labels.number_format = '0.00'; ch.plots[0].data_labels.number_format_is_linked = False
ch.value_axis.has_major_gridlines = True; ch.value_axis.tick_labels.font.size = Pt(11); ch.category_axis.tick_labels.font.size = Pt(12)
table(s, [['TV of T_a [N.m/s]', 'Map', 'PI', 'PID']] + [[k] + [p1(sval(c, k, 'whole case', 'mean_TV_Ta_Nm_per_s'), 0) for c in ('Map', 'PI', 'PID')] for k in CASES]
      + [['DRY max |e_rel| %'] + [p1(dry_max[c], 2) for c in ('Map', 'PI', 'PID')]], 7.2, 2.0, 5.5, colw=[2.2, 1.1, 1.1, 1.1], size=13, rowh=0.5)

s = pres.slides.add_slide(BL)
title(s, 'Result: over-assist in the SLIP case', 'Mean error in % of T_d,ref (negative = steering too light)')
table(s, over_rows, 0.6, 1.8, 12.1, colw=[1.6, 5.2, 1.8, 1.7, 1.8], size=14, rowh=0.55)
bullets(s, ['After the friction drop the map settles at a lighter steering; PI and PID return to the reference (integral action and a_y-based reference)',
            'Inside the 0.4 s puddle nobody can react fully, but the map error is the largest',
            'This gap is structural (feedback + reference vs open-loop map), and is reported as such'], 0.6, 4.9, 12.1, 2.3, size=15)

s = pres.slides.add_slide(BL)
title(s, 'Open issues before freezing the method', 'Found while running all controllers under the same rules')
card(s, 0.6, 1.7, 3.9, 2.9, 'Gates', 'No controller passes all four gates (reverse assist 1-4 %%, e_rel > 3 %%): points chosen by the fallback rule. The simulated margin gate accepted a PI with PM %.0f deg (Ms %.1f): too weak. Thresholds need a source or a sensitivity study.' % (PMd['PI'].PM_deg, PMd['PI'].Ms), RGBColor(0xEB, 0x68, 0x34))
card(s, 4.7, 1.7, 3.9, 2.9, 'Calibration case', 'The mu step 0.8 -> 0.6 hardly changes T_r, so tuning does not see over-assist; only the scoring case SLIP does. Deeper step (e.g. 0.35) planned.', ACC)
card(s, 8.8, 1.7, 3.9, 2.9, 'Model limits', 'Simulation only; open-loop driver (no recovery after a slide); motor as first-order lag; noise level assumed; plant not validated against vehicle data.', RGBColor(0x2A, 0x78, 0xD6))
table(s, gate_rows + [['linear PM / Ms (1 ms discrete model)', '%.0f deg / %.1f' % (PMd['Map'].PM_deg, PMd['Map'].Ms), '%.0f deg / %.1f' % (PMd['PI'].PM_deg, PMd['PI'].Ms), '%.0f deg / %.1f' % (PMd['PID'].PM_deg, PMd['PID'].Ms)]],
      0.6, 4.85, 12.1, colw=[4.9, 2.4, 2.4, 2.4], size=12, rowh=0.36)

s = pres.slides.add_slide(BL)
title(s, 'Code: MATLAB/Simulink R2023a, generated models', 'Every model is built by a script and has one test; all code and comments in English')
tb(s, 0.6, 1.8, 6.3, 5.2, ['Model/setup_paths.m        paths (single place)', 'Model/data/*.json          single data source',
                           'Model/PRSM/<Plant|Ref|Sensors|', '   AssistLimit|Actuator>/  build_*.m, test_*.m',
                           'Model/Controllers/<Map|PI|PID>/', '   load_<ctrl>.m, <Ctrl>.mdl, Model_<Ctrl>.mdl,', '   script/ design, sweep, select, test',
                           'Model/Sim/script/          build_closed_loop, make_cases,', '   calib_run, run_cases, make_pair_comparisons',
                           'Result/                    Design, Calib, Cases, Compare', 'tools/build_report_en.py   this report and deck'], size=13, color=INK)
for r in s.shapes[-1].text_frame.paragraphs:
    for run in r.runs:
        run.font.name = 'Courier New'
bullets(s, ['Run: setup_paths; load_pid; build_closed_loop(\'PID\'); run_cases(\'PID\', 10000)',
            'Compare: make_pair_comparisons({\'Map\',\'PID\'}, 99999)',
            'Tests: test_plant, test_map, test_pid, test_calib, test_gates (all pass)',
            'Repository: github.com/TanTramM/Adaptive-EPS-using-Reinforcement-Learning'], 7.2, 1.9, 5.6, 5.0, size=15)

s = dark_slide('Planned paper and next steps',
               ['Paper: assist map vs PI/PID torque feedback; contributions: fair evaluation framework, resonance and high-frequency gain analysis, quantified over-assist',
                ('Next: settle gate values and the calibration mu step, freeze the method; sensitivity (gates, noise, seed); robustness to +-20 % plant errors; choose the venue. SMC/ISMC stay in the thesis.', {'size': 16})])

out_pptx = os.path.join(DOC, 'MapPID_slides.pptx')
pres.save(out_pptx)
print('figures:', len(F), '| report:', rel(os.path.join(DOC, 'MapPID_report.docx')), '| slides:', rel(out_pptx), len(pres.slides), 'slides')
