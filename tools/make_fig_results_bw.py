# -*- coding: utf-8 -*-
"""Result figures of the paper, drawn from the csv files and readable in black and white print.

Rules used in every figure (supervisor's request: the figure must still be readable when printed in black and white):
  - no colour; each controller has its OWN line style + marker shape + grey level, so the three can be told apart by shape alone;
  - the reference torque is a thick light-grey line under the measured one, so it stays visible;
  - scoring windows are shaded with a hatch, not with a colour;
  - the selected design is a black star in every Pareto panel.

Figures written to Figures/new/main:
  Fig_Pareto_PID_bw.png      (a) safe front, (b) gate-passing front of PID only (test of the style with one controller)
  Fig_Pareto_bw.png          same two panels for Map, PID, MapPID (five common seeds 99990-99994, final designs)
  Fig_<CASE>_<Ctrl>_bw.png   T_s with T_ref, e_T with the scoring windows, T_a; one controller, one seed (test with PID)
  Fig_<CASE>_bw.png          same, with several controllers on common axes (only for controllers listed in CTRLS_CASE)

Sources: Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv and ParetoCommon_select.csv;
         Result/Controllers/<Ctrl>/Cases_v2/<Ctrl>_<CASE>_sig_s<seed>.csv; Result/Compare/DREWS_v2_summary/DREWS_v2_windows.csv
Usage:   C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_results_bw.py   (from the repo root)
"""
import os
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RC = os.path.join(REPO, 'Result', 'Controllers')
PC = os.path.join(REPO, 'Result', 'Compare', 'Pareto_common')
WIN = os.path.join(REPO, 'Result', 'Compare', 'DREWS_v2_summary', 'DREWS_v2_windows.csv')
OUT = os.path.join(REPO, 'Figures', 'new', 'main')

plt.rcParams.update({'font.family': 'serif', 'font.serif': ['Times New Roman'], 'font.size': 9, 'axes.linewidth': 0.6,
                     'mathtext.fontset': 'stix', 'axes.grid': True, 'grid.color': '0.85', 'grid.linewidth': 0.4,
                     'xtick.direction': 'in', 'ytick.direction': 'in'})

# one style per controller: grey level, line style, marker (all distinguishable in black and white)
STYLE = {
    'Map':    dict(c='0.45', ls=':',        m='o', ms=4.0, lw=1.3, fill='0.45', label='Map'),
    'PID':    dict(c='0.10', ls='--',       m='s', ms=3.6, lw=1.0, fill='w',    label='PID'),
    'MapPID': dict(c='0.00', ls='-',        m='^', ms=4.4, lw=1.2, fill='k',    label='MapPID'),
}
REF_STYLE = dict(color='0.72', lw=3.0, solid_capstyle='butt')
CASES = ['DRY', 'RAMP', 'SLIP', 'EDGE', 'WEAVE']


# ------------------------------------------------------------------------------------------------------------------ Pareto
def pareto_panel(ax, ctrls, face, sel):
    """face = 'safe' or 'full'. Candidates in the noise-band set are small grey marks, the front is a line with filled markers,
    the selected design is a black star."""
    for c in ctrls:
        s = STYLE[c]
        d = pd.read_csv(os.path.join(PC, 'ParetoCommon_%s_points_s99990-s99994.csv' % c))
        d = d[d.in_set == 1]
        ax.plot(d.Rtb, d.Stb, linestyle='none', marker=s['m'], ms=s['ms'] - 1.5, mfc='none', mec=s['c'], mew=0.4, alpha=0.6)
        f = d[d['front_' + face] == 1].sort_values('Rtb')
        if len(f):
            ax.plot(f.Rtb, f.Stb, linestyle=s['ls'], color=s['c'], lw=s['lw'], marker=s['m'], ms=s['ms'], mfc=s['fill'], mec=s['c'], mew=0.8, zorder=3)
        r = sel[sel.ctrl == c]
        if len(r) and (r.face_used.iloc[0] == face or (face == 'safe')):
            ax.plot(r.Rtb, r.Stb, linestyle='none', marker='*', ms=13, mfc='k', mec='w', mew=0.6, zorder=5)
    ax.set_xscale('log')
    ax.set_xlabel('$R$ (%)')
    ax.set_ylabel('$S$ (N·m)')


def fig_pareto(ctrls, name):
    sel = pd.read_csv(os.path.join(PC, 'ParetoCommon_select.csv'))
    fig, axs = plt.subplots(1, 2, figsize=(6.3, 2.9), sharey=True)
    for ax, face, ttl in zip(axs, ('safe', 'full'), ('(a) Safe front', '(b) Gate-passing front')):
        pareto_panel(ax, ctrls, face, sel)
        ax.set_title(ttl, fontsize=9)
    axs[0].set_ylim(0, 1.5)
    axs[0].set_xlim(2, 130)
    axs[1].set_xlim(2, 130)
    h = []
    for c in ctrls:
        s = STYLE[c]
        h.append(Line2D([], [], color=s['c'], ls=s['ls'], lw=s['lw'], marker=s['m'], ms=s['ms'], mfc=s['fill'], mec=s['c'], mew=0.8, label=s['label'] + ' front'))
    h.append(Line2D([], [], ls='none', marker='o', ms=3, mfc='none', mec='0.4', label='candidates'))
    h.append(Line2D([], [], ls='none', marker='*', ms=11, mfc='k', mec='w', label='selected design'))
    fig.legend(handles=h, loc='lower center', ncol=len(h), frameon=False, fontsize=8, handlelength=2.2, columnspacing=1.2)
    fig.tight_layout(rect=(0, 0.09, 1, 1))
    p = os.path.join(OUT, name)
    fig.savefig(p, dpi=300)
    plt.close(fig)
    print('wrote', p)


# ------------------------------------------------------------------------------------------------------------------ DREWS cases
def load_sig(ctrl, case, seed):
    return pd.read_csv(os.path.join(RC, ctrl, 'Cases_v2', '%s_%s_sig_s%d.csv' % (ctrl, case, seed)))


def shade_windows(ax, wins):
    for _, w in wins.iterrows():
        ax.axvspan(w.t0, w.t1, facecolor='0.93', edgecolor='0.55', hatch='////', lw=0, zorder=0)


def fig_case(case, ctrls, seed, name, tmax=None):
    wins = pd.read_csv(WIN)
    wins = wins[wins.case == case]
    # the nested windows of a scene (pre / in / rec) overlap: shade only the first and the last of identical starts once
    wins = wins.drop_duplicates(subset=['t0', 't1'])
    sig = {c: load_sig(c, case, seed) for c in ctrls}
    t0 = sig[ctrls[0]]
    fig, axs = plt.subplots(3, 1, figsize=(6.3, 6.0), sharex=True, gridspec_kw=dict(height_ratios=[1.15, 1, 1]))
    for ax in axs:
        shade_windows(ax, wins)
    axs[0].plot(t0.t, t0.T_d_ref, zorder=2, **REF_STYLE)
    for c in ctrls:
        s = STYLE[c]; d = sig[c]
        me = max(1, len(d) // 14)
        kw = dict(color=s['c'], ls=s['ls'], lw=0.9 if s['ls'] != ':' else 1.2, marker=s['m'], ms=3.0, mfc=s['fill'], mec=s['c'], mew=0.7, markevery=(int(me * 0.3 * ctrls.index(c)), me), zorder=3)
        axs[0].plot(d.t, d.T_s, **kw)
        axs[1].plot(d.t, d.e_T, **kw)
        axs[2].plot(d.t, d.T_a, **kw)
    axs[0].set_ylabel('$T_s$, $T_{ref}$ (N·m)')
    axs[1].set_ylabel('$e_T$ (N·m)')
    axs[2].set_ylabel('$T_a$ (N·m)')
    axs[2].set_xlabel('Time (s)')
    axs[1].axhline(0, color='k', lw=0.5)
    axs[2].axhline(0, color='k', lw=0.5)
    axs[0].set_xlim(2, tmax or float(t0.t.max()))
    h = [Line2D([], [], **dict(REF_STYLE, label='$T_{ref}$'))]
    for c in ctrls:
        s = STYLE[c]
        h.append(Line2D([], [], color=s['c'], ls=s['ls'], lw=1.2, marker=s['m'], ms=4, mfc=s['fill'], mec=s['c'], mew=0.8, label=s['label']))
    h.append(Patch(facecolor='0.93', edgecolor='0.55', hatch='////', label='scoring window'))
    fig.legend(handles=h, loc='lower center', ncol=len(h), frameon=False, fontsize=8, handlelength=2.4, columnspacing=1.3)
    fig.tight_layout(rect=(0, 0.05, 1, 1))
    p = os.path.join(OUT, name)
    fig.savefig(p, dpi=300)
    plt.close(fig)
    print('wrote', p)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    fig_pareto(['PID'], 'Fig_Pareto_PID_bw.png')
    fig_pareto(['Map', 'PID', 'MapPID'], 'Fig_Pareto_bw.png')
    for case in ('DRY', 'SLIP', 'WEAVE'):
        fig_case(case, ['PID'], 99999, 'Fig_%s_PID_bw.png' % case)
