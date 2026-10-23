# -*- coding: utf-8 -*-
"""Assist-torque noise figure of Section 5 (Fig. 9), with the two trial layouts that were not chosen, STEADY, seed 99987, 1 ms signals.

Purpose of the figure: the whole-case S of Table 9 hides WHERE the controllers differ. The data show that the noise depends on the torque level:
in a held turn PID and MapPID are equally noisy, near zero torque (straight driving, transitions) PID is about twice as noisy as MapPID, and Map is silent
(dead zone). Three trial layouts, colour with a distinct marker and line style per controller so that black-and-white print stays readable:

  Fig_SSW_noise_c1.png   one panel: RMS of T_a - F5(T_a) in every 1 s window against the mean |T_ref| of the window 
  Fig_SSW_noise_c2.png   two columns x three rows: 3 s of the signal in a held turn (left) and in straight driving (right), one row per controller
  Fig_SSW_noise_bw.png   FINAL (was c3): upper panel = c1, lower panels = 1 s of straight driving, one row per controller (the example of the left end of the upper panel)

Source: Result/Compare/SSW_summary/fullrate/<Ctrl>_STEADY_full_s99987.csv (columns t, T_d_ref, T_a_hp5)
Usage:  C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_noise_alt.py   (from the repo root)
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FR = os.path.join(REPO, 'Result', 'Compare', 'SSW_summary', 'fullrate')
OUT = os.path.join(REPO, 'Figures', 'new', 'main')

plt.rcParams.update({'font.family': 'serif', 'font.serif': ['Times New Roman'], 'font.size': 9, 'axes.linewidth': 0.6,
                     'mathtext.fontset': 'stix', 'axes.grid': False, 'xtick.direction': 'in', 'ytick.direction': 'in'})

CTRL = ('Map', 'PID', 'MapPID')
STY = {'Map':    dict(c='#6b6b6b', ls=':',  m='o', mfc='none',    lw=1.2),
       'PID':    dict(c='#d9531e', ls='--', m='s', mfc='none',    lw=1.0),
       'MapPID': dict(c='#1f4e9c', ls='-',  m='^', mfc='#1f4e9c', lw=1.0)}


def load():
    return {c: pd.read_csv(os.path.join(FR, '%s_STEADY_full_s99987.csv' % c)) for c in CTRL}


def windows(d):
    """1 s windows: mean |T_ref| and RMS of the high-passed assist torque"""
    k = (d.t - 2.0).astype(float) // 1.0
    g = d.assign(k=k.astype(int)).groupby('k')
    x = g.T_d_ref.apply(lambda s: s.abs().mean())
    y = g.T_a_hp5.apply(lambda s: float(np.sqrt(np.mean(s ** 2))))
    return x.values, y.values


def scatter(ax, data, legend=True):
    for c in CTRL:
        s = STY[c]
        x, y = windows(data[c])
        ax.plot(x, y, ls='none', marker=s['m'], ms=4.0, mfc=s['mfc'], mec=s['c'], mew=0.7, alpha=0.9, zorder=2)
    ax.set_xlabel(r'Mean $|T_{ref}|$ in the 1 s window (N$\cdot$m)')
    ax.set_ylabel(r'RMS of $T_a-F_5(T_a)$ (N$\cdot$m)')
    ax.set_xlim(0, 3.6)
    ax.set_ylim(0, 1.35)
    ax.grid(True, color='0.9', lw=0.4)
    ax.annotate('straight driving\n(torque near zero)', xy=(0.06, 0.62), xytext=(0.45, 1.12), fontsize=8, ha='left',
                arrowprops=dict(arrowstyle='-', color='0.3', lw=0.5))
    ax.annotate('held turns', xy=(3.0, 0.45), xytext=(2.75, 0.85), fontsize=8, ha='left',
                arrowprops=dict(arrowstyle='-', color='0.3', lw=0.5))
    if legend:
        h = [Line2D([], [], color=STY[c]['c'], ls=STY[c]['ls'], lw=0, marker=STY[c]['m'], ms=5, mfc=STY[c]['mfc'], mec=STY[c]['c'], label=c) for c in CTRL]
        ax.legend(handles=h, loc='upper right', frameon=False, fontsize=8)


def trace(ax, d, c, t0, t1, ylim, rms=True):
    s = STY[c]
    m = (d.t >= t0) & (d.t <= t1)
    ax.plot(d.t[m], d.T_a_hp5[m], color=s['c'], lw=0.45)
    ax.axhline(0, color='0.6', lw=0.4)
    ax.set_xlim(t0, t1)
    ax.set_ylim(-ylim, ylim)
    ax.set_ylabel(c, color=s['c'], fontsize=9, fontweight='bold', labelpad=2)
    if rms:
        r = float(np.sqrt(np.mean(d.T_a_hp5[m] ** 2)))
        ax.text(0.985, 0.9, 'RMS %.2f' % r, transform=ax.transAxes, fontsize=8, va='top', ha='right', bbox=dict(fc='w', ec='none', pad=1.0), zorder=5)


def save(fig, name):
    fn = os.path.join(OUT, name)
    fig.savefig(fn, dpi=300)
    plt.close(fig)
    print('wrote', fn)


def fig_c1(data):
    fig, ax = plt.subplots(figsize=(6.3, 3.3))
    scatter(ax, data)
    fig.tight_layout()
    save(fig, 'Fig_SSW_noise_c1.png')


def fig_c2(data):
    fig, axs = plt.subplots(3, 2, figsize=(6.3, 4.6), sharex='col')
    for r, c in enumerate(CTRL):
        trace(axs[r, 0], data[c], c, 86.0, 89.0, 1.4)
        trace(axs[r, 1], data[c], c, 92.0, 95.0, 3.0)
    axs[0, 0].set_title('Held turn, 85 km/h, 0.38 g', fontsize=9)
    axs[0, 1].set_title('Straight driving, 85 km/h', fontsize=9)
    axs[2, 0].set_xlabel('Time (s)')
    axs[2, 1].set_xlabel('Time (s)')
    fig.text(0.012, 0.5, r'$T_a-F_5(T_a)$ (N$\cdot$m)', rotation=90, va='center', fontsize=9)
    fig.tight_layout(rect=(0.03, 0, 1, 1))
    save(fig, 'Fig_SSW_noise_c2.png')


def fig_c3(data):
    fig = plt.figure(figsize=(6.3, 5.6))
    gs = fig.add_gridspec(4, 1, height_ratios=[2.6, 0.9, 0.9, 0.9], hspace=0.5)
    ax = fig.add_subplot(gs[0])
    scatter(ax, data)
    axs = [fig.add_subplot(gs[i + 1]) for i in range(3)]
    for a, c in zip(axs, CTRL):
        trace(a, data[c], c, 92.0, 93.0, 3.0)
    fig.text(0.012, 0.24, r'$T_a-F_5(T_a)$ (N$\cdot$m)', rotation=90, va='center', fontsize=9)
    axs[2].set_xlabel('Time (s), straight driving at 85 km/h')
    fig.subplots_adjust(left=0.12, right=0.98, top=0.98, bottom=0.08)
    save(fig, 'Fig_SSW_noise_bw.png')


if __name__ == '__main__':
    d = load()
    for c in CTRL:
        x, y = windows(d[c])
        lo = y[x < 0.25]
        hi = y[x > 1.0]
        print(c, 'windows', len(y), 'median RMS |Tref|<0.25: %.2f' % np.median(lo) if len(lo) else '-', ' |Tref|>1: %.2f' % np.median(hi) if len(hi) else '-')
    fig_c3(d)                      # the layout chosen for Fig. 9 of the paper; fig_c1, fig_c2 are the trial layouts (not written)
