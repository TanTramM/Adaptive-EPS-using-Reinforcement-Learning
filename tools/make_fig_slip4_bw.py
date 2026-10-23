# -*- coding: utf-8 -*-
"""SLIP v4 (make_cases('SLIP_V4'), 100 s, 2026-10-23): summary tables and black-and-white figures for Map, PID, MapPID, seeds 99995-99999.

SLIP v4 keeps cornering while the road loses grip, with the target a_y at or above the new grip (grip use a_y / (mu g) >= 0.9 after the drop, as the scene
'down' of v1). Grip use is computed here from the achieved a_y of the Plant.
writes in Result/Compare/SLIP_v4_summary/:
  SLIP_v4_all_runs.csv     one row per controller, seed, window (metrics of run_cases)
  SLIP_v4_delta.csv        per window: signed error (% of T_d,ref) minus that of the reference window of the same scene (Delta), achieved grip use, mean and std
writes in Figures/new/main/matlab (style of tools/make_fig_results_bw.py):
  Fig_SLIP4_bw.png         mu and grip use, T_s with T_ref, e_T with the scoring windows, T_a; three controllers, seed 99999
  Fig_SLIP4_delta_bw.png   (a) Delta against the TARGET grip use a_y,target / (mu g) (the achieved one saturates near 1 and falls again past the peak) (every hold window of the three scenes) (b) Delta in the deepest window of every scene
Needs Result/Compare/SLIP_v4_summary/SLIP_v4_windows.csv (exported from make_cases('SLIP_V4')).
usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig_slip4_bw.py   (from the repo root)
"""
import os
import importlib.util
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('bw', os.path.join(REPO, 'tools', 'make_fig_results_bw.py'))
bw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bw)
STYLE, REF_STYLE = bw.STYLE, bw.REF_STYLE

RC = os.path.join(REPO, 'Result', 'Controllers')
SUM = os.path.join(REPO, 'Result', 'Compare', 'SLIP_v4_summary')
OUT = os.path.join(REPO, 'Figures', 'new', 'main', 'matlab')
SEEDS = [99995, 99996, 99997, 99998, 99999]
CTRLS = ['Map', 'PID', 'MapPID']
SIGNED = 'Mean_eT_signed_pct_of_Tdref'
REF = {'drop': 'drop_ref', 'stair': 'stair_ref', 'pud': 'pud_ref', 'lane': 'lane_ref'}   # reference window (mu 0.8) of every scene
HOLDS = ['drop_lo', 'stair_m0p5', 'stair_m0p4', 'stair_m0p33', 'stair_m0p28', 'stair_m0p24', 'pud_in', 'lane_in']
DEEP = [('drop_lo', 'drop\n$\\mu$ 0.3'), ('stair_m0p24', 'stair\n$\\mu$ 0.24'), ('pud_in', 'puddle\n$\\mu$ 0.2'), ('lane_in', 'lane ch.\n$\\mu$ 0.2')]
G = 9.81


def load_sig(ctrl, seed):
    return pd.read_csv(os.path.join(RC, ctrl, 'Cases_slip4', '%s_SLIP_sig_s%d.csv' % (ctrl, seed)))


def save(fig, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    fig.savefig(p, dpi=300)
    plt.close(fig)
    print('wrote', p)


def grip_use(d, t0, t1, col='a_y', scale=G):
    m = (d.t >= t0) & (d.t <= t1)
    return float((d[col][m].abs() / scale / d.mu[m]).mean())


# ------------------------------------------------------------------------------------------------------------ tables
def summarize(W):
    os.makedirs(SUM, exist_ok=True)
    frames = []
    for c in CTRLS:
        for s in SEEDS:
            T = pd.read_csv(os.path.join(RC, c, 'Cases_slip4', '%s_metrics_s%d.csv' % (c, s)))
            T.insert(0, 'Seed', s)
            T.insert(0, 'Ctrl', c)
            frames.append(T)
    A = pd.concat(frames, ignore_index=True)
    A.to_csv(os.path.join(SUM, 'SLIP_v4_all_runs.csv'), index=False)
    rows = []
    for c in CTRLS:
        for s in SEEDS:
            d = A[(A.Ctrl == c) & (A.Seed == s)].set_index('Window')
            sig = load_sig(c, s)
            for sc, ref in REF.items():
                r0 = d.loc[ref, SIGNED]
                for w in d.index:
                    if w.startswith(sc + '_') and w != ref:
                        ww = W[W.label == w].iloc[0]
                        rows.append((c, sc, w, s, d.loc[w, SIGNED], d.loc[w, SIGNED] - r0, grip_use(sig, ww.t0, ww.t1),
                                     grip_use(sig, ww.t0, ww.t1, 'a_y_target_g', 1.0)))
    D = pd.DataFrame(rows, columns=['Ctrl', 'Scene', 'Window', 'Seed', 'signed_pct', 'Delta_pct', 'grip_use', 'grip_target'])
    Gt = D.groupby(['Scene', 'Window', 'Ctrl'], sort=False).agg(grip_target=('grip_target', 'mean'), grip_use_mean=('grip_use', 'mean'), signed_pct_mean=('signed_pct', 'mean'),
                                                               Delta_pct_mean=('Delta_pct', 'mean'), Delta_pct_std=('Delta_pct', 'std'),
                                                               n_seeds=('Seed', 'nunique')).reset_index()
    Gt.to_csv(os.path.join(SUM, 'SLIP_v4_delta.csv'), index=False)
    pd.set_option('display.width', 200)
    print(A[A.Window == 'whole case'].groupby('Ctrl')[['RMS_eT_Nm', 'MaxAbs_eT_Nm', 'S_Nm', 'Heavy_s', 'Light_s']].mean().round(4).to_string())
    print(Gt.round(3).to_string())
    return A, Gt


# ------------------------------------------------------------------------------------------------------------ time response
def style_kw(c, idx, nlen):
    s = STYLE[c]
    me = max(1, nlen // 16)
    return dict(color=s['c'], ls=s['ls'], lw=0.9 if s['ls'] != ':' else 1.2, marker=s['m'], ms=3.0, mfc=s['fill'], mec=s['c'], mew=0.7,
                markevery=(int(me * 0.3 * idx), me), zorder=3)


def fig_case(W, seed=99999):
    wins = W.drop_duplicates(subset=['t0', 't1'])
    sig = {c: load_sig(c, seed) for c in CTRLS}
    t0 = sig['Map']
    fig, axs = plt.subplots(5, 1, figsize=(6.3, 8.4), sharex=True, gridspec_kw=dict(height_ratios=[0.55, 0.6, 1.15, 1, 1]))
    for ax in axs:
        for _, w in wins.iterrows():
            ax.axvspan(w.t0, w.t1, facecolor='0.93', edgecolor='0.55', hatch='////', lw=0, zorder=0)
    axs[0].plot(t0.t, t0.mu, color='k', lw=1.0)
    axs[0].set_ylabel('$\\mu$')
    axs[0].set_ylim(0.1, 0.9)
    # grip use: target (dashed) and achieved by the Plant with the Map (the three controllers give the same a_y within a few %)
    axs[1].plot(t0.t, t0.a_y_target_g.abs() / t0.mu, color='0.55', ls='--', lw=0.9)
    axs[1].plot(t0.t, t0.a_y.abs() / G / t0.mu, color='k', lw=1.0)
    axs[1].axhline(1.0, color='k', lw=0.5, ls=':')
    axs[1].set_ylabel('$|a_y|/(\\mu g)$')
    axs[1].set_ylim(0, 1.35)
    axs[2].plot(t0.t, t0.T_d_ref, zorder=2, **REF_STYLE)
    for i, c in enumerate(CTRLS):
        d = sig[c]
        kw = style_kw(c, i, len(d))
        axs[2].plot(d.t, d.T_s, **kw)
        axs[3].plot(d.t, d.e_T, **kw)
        axs[4].plot(d.t, d.T_a, **kw)
    axs[2].set_ylabel('$T_s$, $T_{ref}$ (N·m)')
    axs[3].set_ylabel('$e_T$ (N·m)')
    axs[4].set_ylabel('$T_a$ (N·m)')
    axs[4].set_xlabel('Time (s)')
    for ax in axs[3:]:
        ax.axhline(0, color='k', lw=0.5)
    axs[3].set_ylim(-1.5, 1.5)          # the mu-rise spikes at the end of the puddle and of the staircase are clipped (their peak is in SLIP_v4_all_runs.csv)
    axs[0].set_xlim(2, float(t0.t.max()))
    h = [Line2D([], [], **dict(REF_STYLE, label='$T_{ref}$'))]
    for c in CTRLS:
        s = STYLE[c]
        h.append(Line2D([], [], color=s['c'], ls=s['ls'], lw=1.2, marker=s['m'], ms=4, mfc=s['fill'], mec=s['c'], mew=0.8, label=s['label']))
    h.append(Line2D([], [], color='0.55', ls='--', lw=0.9, label='target grip use'))
    h.append(Patch(facecolor='0.93', edgecolor='0.55', hatch='////', label='scoring window'))
    fig.legend(handles=h, loc='lower center', ncol=3, frameon=False, fontsize=8, handlelength=2.4, columnspacing=1.3)
    fig.tight_layout(rect=(0, 0.06, 1, 1))
    save(fig, 'Fig_SLIP4_bw.png')


# ------------------------------------------------------------------------------------------------------------ Delta against grip use
def fig_delta(Gt):
    fig, axs = plt.subplots(1, 2, figsize=(6.5, 2.9), gridspec_kw=dict(width_ratios=[1.4, 1]))
    mk = {'drop': 's', 'stair': 'o', 'pud': '^', 'lane': 'D'}
    for c in CTRLS:
        s = STYLE[c]
        r = Gt[(Gt.Ctrl == c) & Gt.Window.isin(HOLDS)]
        st = r[r.Scene == 'stair'].sort_values('grip_target')
        xs = np.r_[0.37, st.grip_target.values]
        ys = np.r_[0.0, st.Delta_pct_mean.values]
        es = np.r_[0.0, st.Delta_pct_std.values]
        axs[0].errorbar(xs, ys, yerr=es, color=s['c'], ls=s['ls'], lw=s['lw'], marker=s['m'], ms=s['ms'] + 1, mfc=s['fill'], mec=s['c'], capsize=2, elinewidth=0.6)
        for sc in ('drop', 'pud', 'lane'):
            q = r[r.Scene == sc]
            axs[0].errorbar(q.grip_target, q.Delta_pct_mean, yerr=q.Delta_pct_std, color=s['c'], ls='none', marker=mk[sc], ms=5, mfc='w' if c != 'MapPID' else 'k',
                            mec=s['c'], capsize=2, elinewidth=0.6)
    axs[0].axhline(0, color='k', lw=0.5)
    axs[0].set_xlabel('target grip use $|a_{y,target}|/(\\mu g)$')
    axs[0].set_ylabel('$\\Delta$ (% of $T_{ref}$)')
    axs[0].set_title('(a) error change against grip use', fontsize=9)
    axs[0].text(0.03, 0.05, 'line: staircase  square: drop  triangle: puddle  diamond: lane change', transform=axs[0].transAxes, fontsize=7)
    hat = {'Map': '....', 'PID': '////', 'MapPID': ''}
    fc = {'Map': '0.75', 'PID': 'w', 'MapPID': '0.15'}
    w = 0.26
    for i, c in enumerate(CTRLS):
        ys, es = [], []
        for lab, _ in DEEP:
            r = Gt[(Gt.Window == lab) & (Gt.Ctrl == c)]
            ys.append(r.Delta_pct_mean.iloc[0]); es.append(r.Delta_pct_std.iloc[0])
        axs[1].bar(np.arange(len(DEEP)) + (i - 1) * w, ys, w, yerr=es, facecolor=fc[c], edgecolor='k', hatch=hat[c], lw=0.6, capsize=2, error_kw=dict(lw=0.6))
    axs[1].set_xticks(range(len(DEEP)))
    axs[1].set_xticklabels([x[1] for x in DEEP], fontsize=7.5)
    axs[1].axhline(0, color='k', lw=0.5)
    axs[1].set_title('(b) deepest window', fontsize=9)
    h = []
    for c in CTRLS:
        s = STYLE[c]
        h.append(Line2D([], [], color=s['c'], ls=s['ls'], lw=1.2, marker=s['m'], ms=4, mfc=s['fill'], mec=s['c'], mew=0.8, label=s['label']))
    fig.legend(handles=h, loc='lower center', ncol=3, frameon=False, fontsize=8, handlelength=2.4, columnspacing=1.5)
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    save(fig, 'Fig_SLIP4_delta_bw.png')


if __name__ == '__main__':
    W = pd.read_csv(os.path.join(SUM, 'SLIP_v4_windows.csv'))
    A, Gt = summarize(W)
    fig_case(W)
    fig_delta(Gt)
