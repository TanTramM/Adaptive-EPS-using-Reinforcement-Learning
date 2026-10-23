# -*- coding: utf-8 -*-
"""Figures of Section 4 (controller parameter selection) of the paper, readable in black and white.

  Fig_CALIB_profile_bw.png   the calibration scenario CALIB v2: (a) vehicle speed, (b) target lateral acceleration with the low-friction interval
                             shaded, (c) evaluation windows of the three groups of R (static, dyn, mu) as bars on a common time axis.
  Fig_Map_gates_bw.png       the Map candidates against the slope limit K_max: (a) largest steady relative error |e_rel| with the 10 % gate,
                             (b) ratio of R with the motor gain doubled to the nominal R, with the limit 2. No candidate passes both gates.

Sources: Result/Compare/CALIB_profile/CALIB_profile.csv, CALIB_windows.csv (exported from make_cases('CALIB'));
         Result/Compare/Pareto_common/ParetoCommon_Map_points_s99990-s99994.csv
Usage:   C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_sec4_bw.py   (from the repo root)
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CP = os.path.join(REPO, 'Result', 'Compare', 'CALIB_profile')
PC = os.path.join(REPO, 'Result', 'Compare', 'Pareto_common')
OUT = os.path.join(REPO, 'Figures', 'new', 'main')

plt.rcParams.update({'font.family': 'serif', 'font.serif': ['Times New Roman'], 'font.size': 9, 'axes.linewidth': 0.6,
                     'mathtext.fontset': 'stix', 'axes.grid': False, 'xtick.direction': 'in', 'ytick.direction': 'in'})


def group(label):
    if label.startswith('static'):
        return 'static'
    if label.startswith('mu'):
        return 'mu'
    return 'dyn'


def fig_calib():
    p = pd.read_csv(os.path.join(CP, 'CALIB_profile.csv'))
    w = pd.read_csv(os.path.join(CP, 'CALIB_windows.csv'))
    w['g'] = w.label.map(group)
    fig, axs = plt.subplots(3, 1, figsize=(6.3, 3.6), sharex=True, gridspec_kw=dict(height_ratios=[1, 1.5, 0.75], hspace=0.12))
    av, aa, aw = axs
    # low-friction interval (mu < 0.8) shaded on every panel
    low = p.mu < 0.79
    t_lo = p.t[low]
    lo0, lo1 = t_lo.min(), t_lo.max()
    for ax in axs:
        ax.axvspan(lo0, lo1, color='0.88', lw=0, zorder=0)
    # (a) speed
    av.plot(p.t, p.v_kmh, color='k', lw=1.0)
    av.set_ylabel('$v$ (km/h)')
    av.set_ylim(0, 115)
    av.set_yticks([20, 60, 100])
    # (b) target lateral acceleration
    aa.plot(p.t, p.ay_target_g, color='k', lw=0.8)
    aa.axhline(0, color='0.6', lw=0.4, zorder=1)
    aa.set_ylabel('$a_y^*$ (g)')
    aa.set_ylim(-0.38, 0.38)
    aa.set_yticks([-0.3, 0, 0.3])
    av.text(0.5 * (lo0 + lo1), 85, r'$\mu$ = 0.35', fontsize=7.5, va='center', ha='center',
            bbox=dict(boxstyle='square,pad=0.15', fc='w', ec='none'))
    # (c) evaluation windows, one row per group
    rows = [('static', 2, 'k'), ('dyn', 1, '0.55'), ('mu', 0, 'k')]
    for g, y, col in rows:
        ww = w[w.g == g]
        aw.broken_barh(list(zip(ww.t0, ww.t1 - ww.t0)), (y - 0.32, 0.64), facecolors=col, edgecolors='none')
    aw.set_yticks([2, 1, 0])
    aw.set_yticklabels(['static (%d)' % (w.g == 'static').sum(), 'dyn (%d)' % (w.g == 'dyn').sum(), r'$\mu$ (%d)' % (w.g == 'mu').sum()],
                       fontsize=7.5)
    aw.set_ylim(-0.6, 3.3)
    aw.tick_params(axis='y', length=0)
    aw.set_xlabel('Time (s)')
    aw.set_xlim(0, p.t.max())
    for ax, tag in zip(axs, 'abc'):
        ax.text(0.006, 0.96, '(%s)' % tag, transform=ax.transAxes, fontsize=9, va='top', ha='left')
    fig.align_ylabels(axs)
    fig.subplots_adjust(left=0.13, right=0.98, top=0.98, bottom=0.11)
    fn = os.path.join(OUT, 'Fig_CALIB_profile_bw.png')
    fig.savefig(fn, dpi=300)
    plt.close(fig)
    print('wrote', fn)


def fig_map_gates():
    d = pd.read_csv(os.path.join(PC, 'ParetoCommon_Map_points_s99990-s99994.csv'))
    d = d[(d.in_set == 1) & (d.margin_done == 1)].copy()
    stable = d.margin_pass == 1
    fig, axs = plt.subplots(1, 2, figsize=(6.3, 2.5), gridspec_kw=dict(wspace=0.32))
    ae, ag = axs
    kw_s = dict(ls='none', marker='o', ms=3.6, mfc='k', mec='k', mew=0.6)
    kw_u = dict(ls='none', marker='o', ms=3.6, mfc='w', mec='k', mew=0.6)
    # (a) static accuracy
    ae.plot(d.K[stable], d.erel_max[stable], **kw_s)
    ae.plot(d.K[~stable], d.erel_max[~stable], **kw_u)
    ae.axhline(10, color='k', ls='--', lw=0.8)
    ae.text(11.3, 11.2, 'gate 10 %', fontsize=7.5, ha='right', va='bottom')
    ae.set_yscale('log')
    ae.set_ylim(3, 400)
    ae.set_yticks([5, 10, 20, 50, 100, 200])
    ae.set_yticklabels(['5', '10', '20', '50', '100', '200'])
    ae.set_ylabel(r'max $|e_{rel}|$ (%)')
    # (b) stability under doubled motor gain
    ag.plot(d.K[stable], d.ratio_gain[stable], **kw_s)
    ag.plot(d.K[~stable], d.ratio_gain[~stable], **kw_u)
    ag.axhline(2, color='k', ls='--', lw=0.8)
    ag.text(1.0, 2.08, 'limit 2', fontsize=7.5, ha='left', va='bottom')
    ag.set_ylim(0, 4)
    ag.set_ylabel(r'$R_{2\times\mathrm{gain}}\,/\,R$')
    # the two groups are separated by K_max: shade the gap between the largest stable and the smallest unstable-accurate slope
    k_st = d.K[stable].max()
    k_un = d.K[(~stable) & (d.pass_erel == 1)].min()
    for ax in axs:
        ax.axvspan(k_st, k_un, color='0.88', lw=0, zorder=0)
        ax.set_xlim(0.5, 11.6)
        ax.set_xticks([1, 3, 5, 7, 9, 11])
        ax.set_xlabel(r'$K_{max}$')
    for ax, tag in zip(axs, 'ab'):
        ax.text(-0.2, 1.0, '(%s)' % tag, transform=ax.transAxes, fontsize=9, va='top')
    hs = [Line2D([], [], **kw_s), Line2D([], [], **kw_u)]
    fig.legend(hs, ['passes the stability test', 'fails the stability test'], loc='upper center', ncol=2, frameon=False,
               fontsize=7.5, bbox_to_anchor=(0.55, 1.0), handletextpad=0.3, columnspacing=1.5)
    fig.subplots_adjust(left=0.10, right=0.98, top=0.88, bottom=0.17)
    fn = os.path.join(OUT, 'Fig_Map_gates_bw.png')
    fig.savefig(fn, dpi=300)
    plt.close(fig)
    print('wrote', fn, '| stable max K %.3f, unstable-accurate min K %.3f' % (k_st, k_un))


if __name__ == '__main__':
    fig_calib()
    fig_map_gates()
