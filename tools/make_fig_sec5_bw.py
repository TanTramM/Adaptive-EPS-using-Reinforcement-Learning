# -*- coding: utf-8 -*-
"""Figures of Section 5 (evaluation on the SSW scenarios) of the paper, readable in black and white.

  Fig_SSW_noise_bw.png     assist-torque noise in a held turn (STEADY, 65 km/h, 0.25 g, seed 99987, 1 ms signals):
                           (a)-(c) T_a minus its 5 Hz low-pass part for Map, PID, MapPID on one common scale,
                           (d) amplitude spectrum of T_a over the hold, band above 5 Hz shaded.
  Fig_SSW_windows_bw.png   signed steady error of every hold window (% of T_ref), (a) STEADY, (b) SLIP, band +-10 %.
  Fig_SSW_lane_bw.png      WEAVE double lane change, dry cycle then puddle cycle: (a) T_s of the three controllers and T_ref, (b) T_a.

Sources: Result/Compare/SSW_summary/SSW_windows_summary.csv, SSW_windows.csv (common seeds 99987-99989);
         Result/Compare/SSW_summary/fullrate/<Ctrl>_<CASE>_full_s99987.csv (scratch/export_ssw_fullrate.m, 1 ms)
Usage:   C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_sec5_bw.py   (from the repo root)
"""
import os
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = os.path.join(REPO, 'Result', 'Compare', 'SSW_summary')
FR = os.path.join(SS, 'fullrate')
OUT = os.path.join(REPO, 'Figures', 'new', 'main')

plt.rcParams.update({'font.family': 'serif', 'font.serif': ['Times New Roman'], 'font.size': 9, 'axes.linewidth': 0.6,
                     'mathtext.fontset': 'stix', 'axes.grid': False, 'xtick.direction': 'in', 'ytick.direction': 'in'})

CTRL = ('Map', 'PID', 'MapPID')
# same line and marker code as the Pareto figure of Section 4
STY = {'Map':    dict(c='0.45', ls=':',  m='o', mfc='w', lw=1.3),
       'PID':    dict(c='0.10', ls='--', m='s', mfc='w', lw=1.0),
       'MapPID': dict(c='0.00', ls='-',  m='^', mfc='k', lw=1.1)}


def save(fig, name):
    fn = os.path.join(OUT, name)
    fig.savefig(fn, dpi=300)
    plt.close(fig)
    print('wrote', fn)


def tag(ax, t, x=-0.09):
    ax.text(x, 1.0, '(%s)' % t, transform=ax.transAxes, fontsize=9, va='top', ha='left')


# ------------------------------------------------------------------ windows
def fig_windows():
    d = pd.read_csv(os.path.join(SS, 'SSW_windows_summary.csv'))
    d = d[d.Group == 'common']
    v = d.pivot_table(index=['Case', 'Window'], columns='Ctrl', values='Mean_eT_signed_pct_of_Tdref_mean', sort=False)
    steady = [w for w in v.loc['STEADY'].index]
    slip = [('ramp_dn', 'speed\ndown'), ('ramp_up', 'speed\nup'), ('stair_m0p5', r'$\mu$ 0.5'), ('stair_m0p33', r'$\mu$ 0.33'),
            ('stair_m0p24', r'$\mu$ 0.24'), ('pud_in', 'puddle\n$\\mu$ 0.2')]

    def lab(w):                                  # v65a0p25l -> 65 / 0.25
        vk = w[1:w.index('a')]
        a = w[w.index('a') + 1:-1].replace('p', '.')
        return '%s\n%s' % (vk, a)

    fig, axs = plt.subplots(1, 2, figsize=(6.3, 3.1), gridspec_kw=dict(width_ratios=[11, 6.6], wspace=0.08), sharey=True)
    off = {'Map': -0.22, 'PID': 0.0, 'MapPID': 0.22}
    for ax, case, wins, labels in ((axs[0], 'STEADY', steady, [lab(w) for w in steady]),
                                   (axs[1], 'SLIP', [w for w, _ in slip], [l for _, l in slip])):
        x = np.arange(len(wins))
        ax.axhspan(-10, 10, color='0.90', lw=0, zorder=0)
        ax.axhline(0, color='0.5', lw=0.5, zorder=1)
        for c in CTRL:
            s = STY[c]
            y = v.loc[case].loc[wins, c].values
            ax.plot(x + off[c], y, ls='none', marker=s['m'], ms=4.2, mfc=s['mfc'], mec=s['c'] if c != 'MapPID' else 'k', mew=0.8, zorder=3)
        ax.set_xticks(x)
        ax.set_xticklabels(labels, fontsize=7.5)
        ax.set_xlim(-0.6, len(wins) - 0.4)
        for xi in x[:-1]:
            ax.axvline(xi + 0.5, color='0.85', lw=0.4, zorder=0)
    axs[0].set_ylabel('Signed steady error (% of $T_{ref}$)')
    axs[0].set_ylim(-20, 36)
    axs[0].set_xlabel('STEADY: speed (km/h) / target lateral acceleration (g)', fontsize=8)
    axs[1].set_xlabel('SLIP: scene', fontsize=8)
    axs[0].text(10.45, 10.6, '+10 %', fontsize=7, ha='right', va='bottom', color='0.35')
    axs[0].text(10.45, -10.6, '−10 %', fontsize=7, ha='right', va='top', color='0.35')
    tag(axs[0], 'a', -0.11)
    tag(axs[1], 'b', -0.10)
    hs = [Line2D([], [], ls='none', marker=STY[c]['m'], ms=4.5, mfc=STY[c]['mfc'], mec=STY[c]['c'] if c != 'MapPID' else 'k', mew=0.8, label=c)
          for c in CTRL]
    fig.legend(handles=hs, loc='upper center', ncol=3, frameon=False, fontsize=8, bbox_to_anchor=(0.55, 1.0))
    fig.subplots_adjust(left=0.09, right=0.99, top=0.90, bottom=0.22)
    save(fig, 'Fig_SSW_windows_bw.png')


def full(c, case):
    return pd.read_csv(os.path.join(FR, '%s_%s_full_s99987.csv' % (c, case)))


# ------------------------------------------------------------------ noise
def fig_noise():
    """Nine charts in one column, three groups of one row per controller (Map, PID, MapPID), each group on its own common scale:
    RMS of T_a - F5(T_a) over 1 s along STEADY; the signal itself (1 ms) in a held turn (86-89 s, 0.38 g); the signal in straight driving (92-95 s)."""
    D = {c: full(c, 'STEADY') for c in CTRL}
    HOLD = (86.0, 89.0)
    STRT = (92.0, 95.0)
    fig = plt.figure(figsize=(6.3, 8.3))
    gs = fig.add_gridspec(3, 1, height_ratios=[1.0, 1.0, 1.0], hspace=0.28)
    edges = np.arange(2, 101, 1.0)

    def group(g, title, xlabel):
        sub = gs[g].subgridspec(3, 1, hspace=0.10)
        axs = []
        for k in range(3):
            ax = fig.add_subplot(sub[k], sharex=axs[0] if axs else None)
            axs.append(ax)
            ax.text(0.005, 0.90, CTRL[k], transform=ax.transAxes, fontsize=8, va='top', ha='left',
                    bbox=dict(boxstyle='square,pad=0.1', fc='w', ec='none'))
            if k < 2:
                plt.setp(ax.get_xticklabels(), visible=False)
        axs[0].set_title(title, fontsize=8.5, pad=3, loc='left')
        axs[-1].set_xlabel(xlabel)
        return axs

    # group 1: RMS over 1 s
    axs = group(0, 'RMS of $T_a-F_5(T_a)$ over 1 s (dashed in the Map and MapPID rows: PID, for reference)', 'Time (s)')
    R = {}
    for c in CTRL:
        t, h = D[c].t.values, D[c].T_a_hp5.values
        R[c] = np.array([np.sqrt(np.mean(h[(t >= a) & (t < a + 1)] ** 2)) for a in edges[:-1]])
    for k, c in enumerate(CTRL):
        r = R[c]
        ax = axs[k]
        ax.fill_between(edges[:-1], 0, r, step='post', color='0.80', lw=0)
        ax.step(edges[:-1], r, where='post', color='k', lw=0.6)
        if c != 'PID':
            ax.step(edges[:-1], R['PID'], where='post', color='k', lw=0.5, ls=(0, (3, 2)))
        for z, hat in ((HOLD, None), (STRT, None)):
            ax.axvspan(z[0], z[1], color='0.35', alpha=0.30, lw=0)
        ax.set_ylim(0, 1.3)
        ax.set_yticks([0, 0.5, 1.0])
        ax.tick_params(axis='y', labelsize=7.5)
        ax.set_xlim(2, 100)
    axs[1].set_ylabel('(N·m)', fontsize=8.5)
    # groups 2 and 3: the signal itself
    for g, (t0, t1), title in ((1, HOLD, 'Held turn, 85 km/h, 0.38 g: $T_a-F_5(T_a)$'), (2, STRT, 'Straight driving, 85 km/h: $T_a-F_5(T_a)$')):
        axs = group(g, title, 'Time (s)')
        ym = max(np.abs(D[c].T_a_hp5[(D[c].t >= t0) & (D[c].t < t1)]).max() for c in CTRL)
        ym = np.ceil(ym * 2) / 2
        tk = [-1, 0, 1] if ym <= 1.5 else [-2, 0, 2]
        for k, c in enumerate(CTRL):
            d = D[c]
            w = (d.t >= t0) & (d.t < t1)
            ax = axs[k]
            ax.plot(d.t[w], d.T_a_hp5[w], color='k', lw=0.4)
            ax.axhline(0, color='0.6', lw=0.4)
            ax.set_ylim(-ym, ym)
            ax.set_yticks(tk)
            ax.tick_params(axis='y', labelsize=7.5)
            ax.set_xlim(t0, t1)
            rms = np.sqrt(np.mean(d.T_a_hp5[w] ** 2))
            ax.text(0.995, 0.90, 'RMS %.2f N·m' % rms, transform=ax.transAxes, fontsize=7.5, va='top', ha='right',
                    bbox=dict(boxstyle='square,pad=0.1', fc='w', ec='none'))
        axs[1].set_ylabel('(N·m)', fontsize=8.5)
    fig.subplots_adjust(left=0.11, right=0.975, top=0.975, bottom=0.05)
    save(fig, 'Fig_SSW_noise_bw.png')


# ------------------------------------------------------------------ lane change
def fig_lane():
    """(a) T_s of the three controllers with T_ref; (b)-(d) T_a of each controller on its own row, one common scale."""
    D = {c: full(c, 'WEAVE') for c in CTRL}
    t0, t1 = 29.5, 38.5
    fig = plt.figure(figsize=(6.3, 4.9))
    gs = fig.add_gridspec(4, 1, height_ratios=[1.7, 0.8, 0.8, 0.8], hspace=0.12)
    aa = fig.add_subplot(gs[0])
    rows = [fig.add_subplot(gs[k], sharex=aa) for k in (1, 2, 3)]
    for ax in [aa] + rows:
        ax.axvspan(35.3, 35.7, color='0.85', lw=0, zorder=0)
        ax.axhline(0, color='0.75', lw=0.4, zorder=1)
    ref = D['PID']
    w = (ref.t >= t0) & (ref.t <= t1)
    aa.plot(ref.t[w], ref.T_d_ref[w], color='0.72', lw=2.8, zorder=2, label='$T_{ref}$')
    for c in CTRL:
        d = D[c]
        w = (d.t >= t0) & (d.t <= t1)
        s = STY[c]
        aa.plot(d.t[w], d.T_s[w], color=s['c'], ls=s['ls'], lw=s['lw'], zorder=3, label=c)
    aa.set_ylabel('$T_s$ (N·m)')
    aa.set_ylim(-3.6, 3.9)
    aa.text(31.25, 3.75, 'dry road', fontsize=7.5, ha='center', va='top')
    aa.text(35.5, 3.75, r'puddle, $\mu$ = 0.2', fontsize=7.5, ha='left', va='top')
    aa.legend(loc='lower center', bbox_to_anchor=(0.5, 1.0), ncol=4, frameon=False, fontsize=8, handlelength=2.6)
    plt.setp(aa.get_xticklabels(), visible=False)
    ym = max(np.abs(D[c].T_a[(D[c].t >= t0) & (D[c].t <= t1)]).max() for c in CTRL)
    ym = np.ceil(ym)
    for ax, c in zip(rows, CTRL):
        d = D[c]
        w = (d.t >= t0) & (d.t <= t1)
        ax.plot(d.t[w], d.T_a[w], color='k', lw=0.5)
        ax.set_ylim(-ym, ym)
        ax.set_yticks([-5, 0, 5])
        ax.tick_params(axis='y', labelsize=7.5)
        ax.text(0.005, 0.90, c, transform=ax.transAxes, fontsize=7.5, va='top', ha='left',
                bbox=dict(boxstyle='square,pad=0.1', fc='w', ec='none'))
        if c != CTRL[-1]:
            plt.setp(ax.get_xticklabels(), visible=False)
    rows[1].set_ylabel('$T_a$ (N·m)')
    rows[-1].set_xlabel('Time (s)')
    rows[-1].set_xlim(t0, t1)
    tag(aa, 'a', -0.09)
    tag(rows[0], 'b', -0.09)
    fig.subplots_adjust(left=0.10, right=0.99, top=0.94, bottom=0.09)
    save(fig, 'Fig_SSW_lane_bw.png')


if __name__ == '__main__':
    which = sys.argv[1:] or ['windows', 'noise', 'lane']
    if 'windows' in which:
        fig_windows()
    if 'noise' in which:
        fig_noise()
    if 'lane' in which:
        fig_lane()
