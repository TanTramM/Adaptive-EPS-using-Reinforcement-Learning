# -*- coding: utf-8 -*-
"""DREWS v3 result figures (five cases of 100 s, Map, PID, MapPID, seeds 99995-99999), readable in black and white print.

Same style as tools/make_fig_results_bw.py (imported): no colour, one line style + marker + grey level per controller, the reference torque is a thick light-grey
line, scoring windows are hatched. Figures written to Figures/new/main/matlab:
  Fig_<CASE>_bw.png        top: speed (mu for SLIP), then T_s with T_ref, e_T with the scoring windows, T_a; three controllers on common axes, one seed
  Fig_SLIP_delta_bw.png    (a) signed error difference Delta (% of T_d,ref, window minus the same scene on mu 0.8) against mu on the staircase, mean +- std over the seeds
                           (b) the same on the slow mu ramp (continuous curve) (c) Delta in the deepest window of each scene
  Fig_DREWS_bars_bw.png    RMS e_T and S of the whole case, five cases, three controllers, mean +- std over the seeds

Sources: Result/Controllers/<Ctrl>/Cases_v3/*.csv, Result/Compare/DREWS_v3_summary/ (run tools/summarize_drews_v3.py first)
Usage:   C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig_drews_v3_bw.py   (from the repo root)
"""
import os
import sys
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
SUM = os.path.join(REPO, 'Result', 'Compare', 'DREWS_v3_summary')
OUT = os.path.join(REPO, 'Figures', 'new', 'main', 'matlab')
SEEDS = [99995, 99996, 99997, 99998, 99999]
CTRLS = ['Map', 'PID', 'MapPID']
CASES = ['DRY', 'RAMP', 'SLIP', 'EDGE', 'WEAVE']


def load_sig(ctrl, case, seed):
    return pd.read_csv(os.path.join(RC, ctrl, 'Cases_v3', '%s_%s_sig_s%d.csv' % (ctrl, case, seed)))


def windows(case):
    w = pd.read_csv(os.path.join(SUM, 'DREWS_v3_windows.csv'))
    return w[w.case == case].reset_index(drop=True)


def save(fig, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    fig.savefig(p, dpi=300)
    plt.close(fig)
    print('wrote', p)


def style_kw(c, idx, n_ctrl, nlen):
    s = STYLE[c]
    me = max(1, nlen // 16)
    return dict(color=s['c'], ls=s['ls'], lw=0.9 if s['ls'] != ':' else 1.2, marker=s['m'], ms=3.0, mfc=s['fill'], mec=s['c'], mew=0.7,
                markevery=(int(me * 0.3 * idx), me), zorder=3)


# ------------------------------------------------------------------------------------------------------------ one case, three controllers
def fig_case(case, seed=99999):
    wins = windows(case).drop_duplicates(subset=['t0', 't1'])
    sig = {c: load_sig(c, case, seed) for c in CTRLS}
    t0 = sig[CTRLS[0]]
    fig, axs = plt.subplots(4, 1, figsize=(6.3, 7.2), sharex=True, gridspec_kw=dict(height_ratios=[0.55, 1.15, 1, 1]))
    for ax in axs:
        for _, w in wins.iterrows():
            ax.axvspan(w.t0, w.t1, facecolor='0.93', edgecolor='0.55', hatch='////', lw=0, zorder=0)
    if case == 'SLIP':
        axs[0].plot(t0.t, t0.mu, color='k', lw=1.0)
        axs[0].set_ylabel('$\\mu$')
        axs[0].set_ylim(0.15, 0.9)
    else:
        axs[0].plot(t0.t, t0.v_mps * 3.6, color='k', lw=1.0)
        axs[0].set_ylabel('$v$ (km/h)')
    axs[1].plot(t0.t, t0.T_d_ref, zorder=2, **REF_STYLE)
    for i, c in enumerate(CTRLS):
        d = sig[c]
        kw = style_kw(c, i, len(CTRLS), len(d))
        axs[1].plot(d.t, d.T_s, **kw)
        axs[2].plot(d.t, d.e_T, **kw)
        axs[3].plot(d.t, d.T_a, **kw)
    axs[1].set_ylabel('$T_s$, $T_{ref}$ (N·m)')
    axs[2].set_ylabel('$e_T$ (N·m)')
    axs[3].set_ylabel('$T_a$ (N·m)')
    axs[3].set_xlabel('Time (s)')
    axs[2].axhline(0, color='k', lw=0.5)
    axs[3].axhline(0, color='k', lw=0.5)
    axs[0].set_xlim(2, float(t0.t.max()))
    h = [Line2D([], [], **dict(REF_STYLE, label='$T_{ref}$'))]
    for c in CTRLS:
        s = STYLE[c]
        h.append(Line2D([], [], color=s['c'], ls=s['ls'], lw=1.2, marker=s['m'], ms=4, mfc=s['fill'], mec=s['c'], mew=0.8, label=s['label']))
    h.append(Patch(facecolor='0.93', edgecolor='0.55', hatch='////', label='scoring window'))
    fig.legend(handles=h, loc='lower center', ncol=len(h), frameon=False, fontsize=8, handlelength=2.4, columnspacing=1.3)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    save(fig, 'Fig_%s_bw.png' % case)


# ------------------------------------------------------------------------------------------------------------ SLIP Delta against mu
def signed_pct(d, t0, t1):
    m = (d.t >= t0) & (d.t <= t1)
    td = d.T_d_ref[m]
    return 100.0 * d.e_T[m].mean() * np.sign(td.mean()) / max(td.abs().mean(), 1e-9)


def ramp_curve(ctrl, W, seed, edges):
    d = load_sig(ctrl, 'SLIP', seed)
    r = W[W.label == 'ramp_ref'].iloc[0]
    ref = signed_pct(d, r.t0, r.t1)
    w = W[W.label == 'ramp_dn'].iloc[0]
    m = (d.t >= w.t0) & (d.t <= w.t1)
    dd = d[m]
    sg = np.sign(dd.T_d_ref.mean())
    out = []
    for a, b in zip(edges[:-1], edges[1:]):
        k = (dd.mu >= a) & (dd.mu < b)
        out.append(100.0 * (dd.e_T[k] * sg).sum() / max(dd.T_d_ref[k].abs().sum(), 1e-9) - ref if k.sum() > 5 else np.nan)
    return np.array(out)


def fig_slip_delta():
    W = windows('SLIP')
    D = pd.read_csv(os.path.join(SUM, 'DREWS_v3_slip_delta.csv'))
    fig, axs = plt.subplots(1, 3, figsize=(6.5, 2.7), gridspec_kw=dict(width_ratios=[1.15, 1.15, 0.9]))
    # (a) staircase: Delta at the holds, x = mu (0.8 = reference, Delta = 0 by definition)
    lv = [('stair_m0p6', 0.6), ('stair_m0p45', 0.45), ('stair_m0p38', 0.38), ('stair_m0p32', 0.32)]
    for i, c in enumerate(CTRLS):
        s = STYLE[c]
        xs, ys, es = [0.8], [0.0], [0.0]
        for lab, mu in lv:
            r = D[(D.Window == lab) & (D.Ctrl == c)]
            if len(r):
                xs.append(mu); ys.append(r.Delta_pct_mean.iloc[0]); es.append(r.Delta_pct_std.iloc[0])
        axs[0].errorbar(xs, ys, yerr=es, color=s['c'], ls=s['ls'], lw=s['lw'], marker=s['m'], ms=s['ms'] + 1, mfc=s['fill'], mec=s['c'], capsize=2, elinewidth=0.6)
    axs[0].set_xlabel('$\\mu$')
    axs[0].set_ylabel('$\\Delta$ (% of $T_{ref}$)')
    axs[0].set_title('(a) $\\mu$ staircase', fontsize=9)
    axs[0].invert_xaxis()
    axs[0].axhline(0, color='k', lw=0.5)
    # (b) slow ramp: continuous curve, mean and std over the seeds
    edges = np.arange(0.28, 0.81, 0.04)
    mid = 0.5 * (edges[:-1] + edges[1:])
    for i, c in enumerate(CTRLS):
        s = STYLE[c]
        Y = np.array([ramp_curve(c, W, sd, edges) for sd in SEEDS])
        m, e = np.nanmean(Y, axis=0), np.nanstd(Y, axis=0)
        axs[1].plot(mid, m, color=s['c'], ls=s['ls'], lw=s['lw'], marker=s['m'], ms=s['ms'] - 0.5, mfc=s['fill'], mec=s['c'])
        axs[1].fill_between(mid, m - e, m + e, facecolor='0.85', edgecolor=s['c'], hatch=['..', '//', ''][i], lw=0, alpha=0.5)
    axs[1].set_xlabel('$\\mu$')
    axs[1].set_title('(b) slow $\\mu$ ramp', fontsize=9)
    axs[1].invert_xaxis()
    axs[1].axhline(0, color='k', lw=0.5)
    # (c) deepest window of every scene
    items = [('stair_m0p32', 'stair\n$\\mu$ 0.32'), ('ramp_lo', 'ramp\n$\\mu$ 0.29'), ('pud_in', 'puddle\n$\\mu$ 0.25')]
    hat = {'Map': '....', 'PID': '////', 'MapPID': ''}
    fc = {'Map': '0.75', 'PID': 'w', 'MapPID': '0.15'}
    w = 0.26
    for i, c in enumerate(CTRLS):
        ys = []; es = []
        for lab, _ in items:
            r = D[(D.Window == lab) & (D.Ctrl == c)]
            ys.append(r.Delta_pct_mean.iloc[0] if len(r) else np.nan); es.append(r.Delta_pct_std.iloc[0] if len(r) else 0)
        axs[2].bar(np.arange(len(items)) + (i - 1) * w, ys, w, yerr=es, facecolor=fc[c], edgecolor='k', hatch=hat[c], lw=0.6, capsize=2, error_kw=dict(lw=0.6))
    axs[2].set_xticks(range(len(items)))
    axs[2].set_xticklabels([x[1] for x in items], fontsize=7.5)
    axs[2].axhline(0, color='k', lw=0.5)
    axs[2].set_title('(c) deepest window', fontsize=9)
    h = []
    for c in CTRLS:
        s = STYLE[c]
        h.append(Line2D([], [], color=s['c'], ls=s['ls'], lw=1.2, marker=s['m'], ms=4, mfc=s['fill'], mec=s['c'], mew=0.8, label=s['label']))
    fig.legend(handles=h, loc='lower center', ncol=3, frameon=False, fontsize=8, handlelength=2.4, columnspacing=1.5)
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    save(fig, 'Fig_SLIP_delta_bw.png')


# ------------------------------------------------------------------------------------------------------------ whole-case bars
def fig_bars():
    A = pd.read_csv(os.path.join(SUM, 'DREWS_v3_all_runs.csv'))
    A = A[A.Window == 'whole case']
    hat = {'Map': '....', 'PID': '////', 'MapPID': ''}
    fc = {'Map': '0.75', 'PID': 'w', 'MapPID': '0.15'}
    fig, axs = plt.subplots(1, 2, figsize=(6.3, 2.7))
    w = 0.26
    for ax, col, lab in zip(axs, ('RMS_eT_Nm', 'S_Nm'), ('RMS $e_T$ (N·m)', '$S$ (N·m)')):
        for i, c in enumerate(CTRLS):
            g = A[A.Ctrl == c].groupby('Case')[col]
            m = g.mean().reindex(CASES); e = g.std().reindex(CASES)
            ax.bar(np.arange(len(CASES)) + (i - 1) * w, m, w, yerr=e, facecolor=fc[c], edgecolor='k', hatch=hat[c], lw=0.6, capsize=2, error_kw=dict(lw=0.6))
        ax.set_xticks(range(len(CASES)))
        ax.set_xticklabels(CASES, fontsize=8)
        ax.set_ylabel(lab)
    h = [Patch(facecolor=fc[c], edgecolor='k', hatch=hat[c], label=STYLE[c]['label']) for c in CTRLS]
    fig.legend(handles=h, loc='lower center', ncol=3, frameon=False, fontsize=8, columnspacing=1.5)
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    save(fig, 'Fig_DREWS_bars_bw.png')


if __name__ == '__main__':
    for case in CASES:
        fig_case(case)
    fig_slip_delta()
    fig_bars()
