# -*- coding: utf-8 -*-
"""Pareto figure of the controller selection, readable in black and white, without special symbols for the selected design.

  Fig_Pareto_J_bw.png
    (a) (R, S) plane with iso-J curves (R*S = const, thin grey hyperbolas) behind the three Pareto fronts. The selected design is the point of the
        front that touches the lowest iso-J curve; it is named by a text label with a leader line, not by a special marker.
        Map points are drawn open because they fail the static-accuracy gate (safe front); PID and MapPID are drawn on the gate-passing front.
    (b) J = R*S along each front against R, with a ring on every point within 3 % of the minimum (the tie set of the selection rule).

Sources: Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv, ParetoCommon_select.csv
Usage:   C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_pareto_bw.py   (from the repo root)
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker
from matplotlib.lines import Line2D

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PC = os.path.join(REPO, 'Result', 'Compare', 'Pareto_common')
OUT = os.path.join(REPO, 'Figures', 'new', 'main')

plt.rcParams.update({'font.family': 'serif', 'font.serif': ['Times New Roman'], 'font.size': 9, 'axes.linewidth': 0.6,
                     'mathtext.fontset': 'stix', 'axes.grid': False, 'xtick.direction': 'in', 'ytick.direction': 'in'})

STYLE = {
    'Map':    dict(c='0.45', ls=':',  m='o', ms=4.0, lw=1.4, fill='w'),     # open: fails the static-accuracy gate
    'PID':    dict(c='0.10', ls='--', m='s', ms=3.6, lw=1.0, fill='w'),
    'MapPID': dict(c='0.00', ls='-',  m='^', ms=4.4, lw=1.2, fill='k'),
}
FACE = {'Map': 'safe', 'PID': 'full', 'MapPID': 'full'}      # front each design is selected from (select.csv, face_used)
TIE = 1.03                                                   # tie band of the selection rule


def load(ctrl):
    d = pd.read_csv(os.path.join(PC, 'ParetoCommon_%s_points_s99990-s99994.csv' % ctrl))
    d = d[d.in_set == 1].copy()
    d['J'] = d.Rtb * d.Stb
    return d


def main():
    sel = pd.read_csv(os.path.join(PC, 'ParetoCommon_select.csv')).set_index('ctrl')
    fig, axs = plt.subplots(1, 2, figsize=(6.3, 3.0), gridspec_kw=dict(width_ratios=[1.25, 1]))
    ax, bx = axs
    # ---------------------------------------------------------------- (a) iso-J curves + fronts
    XMAX = 16
    rr = np.logspace(np.log10(2), np.log10(XMAX), 200)
    for J in (1.5, 2, 3, 5, 7, 10):
        ax.plot(rr, J / rr, color='0.78', lw=0.6, zorder=1)
        if J <= 2:                                   # label on the curve, right part of the panel
            xl = 11.6 if J == 1.5 else 8.2
            ax.text(xl, J / xl + 0.010, 'J = %g' % J, fontsize=6.5, color='0.40', ha='left', va='bottom', zorder=1)
        else:                                        # label just below the top edge, right of the curve
            ax.text(J / 1.30 + 0.05, 1.30, 'J = %g' % J, fontsize=6.5, color='0.40', ha='left', va='bottom', zorder=1)
    for c in ('Map', 'PID', 'MapPID'):
        s = STYLE[c]
        d = load(c)
        ax.plot(d.Rtb, d.Stb, ls='none', marker='o', ms=1.8, mfc='0.6', mec='none', alpha=0.45, zorder=2)
        f = d[d['front_' + FACE[c]] == 1].sort_values('Rtb')
        ax.plot(f.Rtb, f.Stb, ls=s['ls'], color=s['c'], lw=s['lw'], marker=s['m'], ms=s['ms'], mfc=s['fill'], mec=s['c'], mew=0.8, zorder=3)
    lab = {'Map': ('Map\n$J$ = %.2f' % sel.loc['Map', 'J'], (28, 0.62)),
           'PID': ('PID\n$J$ = %.2f' % sel.loc['PID', 'J'], (6.5, 1.20)),
           'MapPID': ('MapPID\n$J$ = %.2f' % sel.loc['MapPID', 'J'], (2.15, 0.45))}
    for c in ('Map', 'PID', 'MapPID'):
        x, y = sel.loc[c, 'Rtb'], sel.loc[c, 'Stb']
        txt, xy = lab[c]
        ax.annotate(txt, xy=(x, y), xytext=xy, fontsize=7.5, ha='left', va='center',
                    arrowprops=dict(arrowstyle='-', color='k', lw=0.6, shrinkA=1, shrinkB=2), zorder=6)
        ax.plot([x], [y], ls='none', marker='o', ms=7.5, mfc='none', mec='k', mew=0.7, zorder=6)
    ax.set_xscale('log')
    ax.set_xlim(2, XMAX)
    ax.set_ylim(0, 1.45)
    ax.set_xticks([2, 3, 5, 10])
    ax.set_xticklabels(['2', '3', '5', '10'])
    ax.xaxis.set_minor_formatter(matplotlib.ticker.NullFormatter())
    ax.set_xlabel('$R$ (%)')
    ax.set_ylabel('$S$ (N·m)')
    ax.set_title('(a) Fronts and iso-$J$ curves (zoom)', fontsize=9)
    # ---------------------------------------------------------------- (b) J along the fronts
    for c in ('Map', 'PID', 'MapPID'):
        s = STYLE[c]
        d = load(c)
        f = d[d['front_' + FACE[c]] == 1].sort_values('Rtb')
        bx.plot(f.Rtb, f.J, ls=s['ls'], color=s['c'], lw=s['lw'], marker=s['m'], ms=s['ms'], mfc=s['fill'], mec=s['c'], mew=0.8, zorder=3)
        tie = f[f.J <= TIE * f.J.min()]
        bx.plot(tie.Rtb, tie.J, ls='none', marker='o', ms=6.5, mfc='none', mec='0.25', mew=0.6, zorder=4)
    bx.set_xscale('log')
    bx.set_yscale('log')
    bx.set_xlim(2, 130)
    bx.set_ylim(1.5, 45)
    bx.set_xticks([2, 5, 10, 20, 50, 100])
    bx.set_xticklabels(['2', '5', '10', '20', '50', '100'])
    bx.set_yticks([2, 3, 5, 10, 20, 40])
    bx.set_yticklabels(['2', '3', '5', '10', '20', '40'])
    bx.grid(True, which='major', color='0.88', lw=0.4)
    bx.set_xlabel('$R$ (%)')
    bx.set_ylabel('$J = R\\cdot S$')
    bx.set_title('(b) $J$ along each front', fontsize=9)
    h = [Line2D([], [], color=STYLE[c]['c'], ls=STYLE[c]['ls'], lw=STYLE[c]['lw'], marker=STYLE[c]['m'], ms=STYLE[c]['ms'],
                mfc=STYLE[c]['fill'], mec=STYLE[c]['c'], mew=0.8, label=n)
         for c, n in (('Map', 'Map (fails accuracy gate)'), ('PID', 'PID'), ('MapPID', 'MapPID'))]
    h.append(Line2D([], [], ls='none', marker='o', ms=7, mfc='none', mec='0.25', mew=0.7, label='within 3% of minimum $J$'))
    fig.legend(handles=h, loc='lower center', ncol=4, frameon=False, fontsize=7.5, handlelength=2.2, columnspacing=1.2)
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    p = os.path.join(OUT, 'Fig_Pareto_J_bw.png')
    fig.savefig(p, dpi=300)
    plt.close(fig)
    print('wrote', p)


if __name__ == '__main__':
    main()
