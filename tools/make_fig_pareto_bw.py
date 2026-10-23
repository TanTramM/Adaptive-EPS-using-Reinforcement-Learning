# -*- coding: utf-8 -*-
"""Pareto figure of the controller selection (Section 4 of the paper), readable in black and white, without special symbols for the selected design.

  Fig_Pareto_J_bw.png
    One (R, S) panel, R on a log axis from 2 to 130 % so that the whole Map front is visible next to the PID and MapPID fronts.
    Thin grey hyperbolas are iso-J curves (J = R*S = const). Light grey dots are all candidates of the noise-band set; the lines are the fronts the
    designs are selected from: Map on the stability-only front (open circles, every point fails the static-accuracy gate), PID and MapPID on the
    front that passes every gate. The selected design (smallest J, ties within 3 % resolved by the largest phase margin) is ringed and labelled.

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
    'Map':    dict(c='0.40', ls=':',  m='o', ms=3.8, lw=1.3, fill='w'),     # open: fails the static-accuracy gate
    'PID':    dict(c='0.10', ls='--', m='s', ms=3.6, lw=1.0, fill='w'),
    'MapPID': dict(c='0.00', ls='-',  m='^', ms=4.2, lw=1.2, fill='k'),
}
FACE = {'Map': 'safe', 'PID': 'full', 'MapPID': 'full'}      # front each design is selected from (select.csv, face_used)
XMIN, XMAX, YMAX = 2, 130, 1.5


def load(ctrl):
    d = pd.read_csv(os.path.join(PC, 'ParetoCommon_%s_points_s99990-s99994.csv' % ctrl))
    return d[d.in_set == 1].copy()


def main():
    sel = pd.read_csv(os.path.join(PC, 'ParetoCommon_select.csv')).set_index('ctrl')
    fig, ax = plt.subplots(figsize=(6.3, 3.3))
    # iso-J curves, labelled where they leave the top edge (no data there)
    rr = np.logspace(np.log10(XMIN), np.log10(XMAX), 300)
    for J in (2, 3, 5, 10, 20, 50):
        ax.plot(rr, J / rr, color='0.80', lw=0.6, zorder=1)
        xl = J / (YMAX - 0.10)
        if xl * 1.04 > XMIN * 1.05:
            ax.text(xl * 1.04, YMAX - 0.10, '$J$ = %g' % J, fontsize=7, color='0.40', ha='left', va='center', zorder=1)
        else:                                        # the curve leaves through the left edge: label it below the curve, in the empty lower region
            ax.text(6.2, J / 6.2 - 0.06, '$J$ = %g' % J, fontsize=7, color='0.40', ha='left', va='center', zorder=1)
    for c in ('Map', 'PID', 'MapPID'):
        s = STYLE[c]
        d = load(c)
        ax.plot(d.Rtb, d.Stb, ls='none', marker='o', ms=1.8, mfc='0.65', mec='none', zorder=2)
        f = d[d['front_' + FACE[c]] == 1].sort_values('Rtb')
        ax.plot(f.Rtb, f.Stb, ls=s['ls'], color=s['c'], lw=s['lw'], marker=s['m'], ms=s['ms'], mfc=s['fill'], mec=s['c'], mew=0.8, zorder=3)
    # selected designs: ring + label with a leader line, labels placed in empty regions
    lab = {'MapPID': (2.15, 0.30), 'PID': (4.6, 1.12), 'Map': (24, 0.78)}
    for c in ('MapPID', 'PID', 'Map'):
        x, y = sel.loc[c, 'Rtb'], sel.loc[c, 'Stb']
        txt = '%s\n$R$ = %.2f %%, $S$ = %.2f N·m' % (c, x, y)
        ax.annotate(txt, xy=(x, y), xytext=lab[c], fontsize=7.5, ha='left', va='center',
                    arrowprops=dict(arrowstyle='-', color='k', lw=0.6, shrinkA=1, shrinkB=3.5), zorder=6)
        ax.plot([x], [y], ls='none', marker='o', ms=8, mfc='none', mec='k', mew=0.8, zorder=6)
    ax.set_xscale('log')
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(0, YMAX)
    ax.set_xticks([2, 3, 5, 10, 20, 50, 100])
    ax.set_xticklabels(['2', '3', '5', '10', '20', '50', '100'])
    ax.xaxis.set_minor_formatter(matplotlib.ticker.NullFormatter())
    ax.set_xlabel('$R$ (%)')
    ax.set_ylabel('$S$ (N·m)')
    h = [Line2D([], [], color=STYLE[c]['c'], ls=STYLE[c]['ls'], lw=STYLE[c]['lw'], marker=STYLE[c]['m'], ms=STYLE[c]['ms'],
                mfc=STYLE[c]['fill'], mec=STYLE[c]['c'], mew=0.8, label=n)
         for c, n in (('Map', 'Map, stability-only front'), ('PID', 'PID, all-gates front'), ('MapPID', 'MapPID, all-gates front'))]
    h.append(Line2D([], [], ls='none', marker='o', ms=1.8, mfc='0.65', mec='none', label='candidates'))
    ax.legend(handles=h, loc='upper right', bbox_to_anchor=(1.0, 0.86), frameon=False, fontsize=7.5, handlelength=2.4)
    fig.tight_layout()
    p = os.path.join(OUT, 'Fig_Pareto_J_bw.png')
    fig.savefig(p, dpi=300)
    plt.close(fig)
    print('wrote', p)


if __name__ == '__main__':
    main()
