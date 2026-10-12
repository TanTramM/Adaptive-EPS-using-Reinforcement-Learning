# -*- coding: utf-8 -*-
"""Figures of the results section of the paper (Documents/Paper/paper.txt, Section 6), one figure per controller.

  Figure_6_pareto_map.png, Figure_7_pareto_pi.png, Figure_8_pareto_pid.png
      Pareto plane (S, R) of the CALIB sweep of each controller: points that fail the accuracy gate (grey), points that pass it,
      their Pareto front and the selected point. Source: Result/Controllers/<Ctrl>/Calib/<Ctrl>_CALIB_{sweep,fine,pick}_<seed>.csv
  Figure_9_dry_map.png, Figure_10_dry_pi.png, Figure_11_dry_pid.png and Figure_12_slip_map.png, Figure_13_slip_pi.png, Figure_14_slip_pid.png
      Detail of the cases DRY and SLIP of each controller (seed 99999): T_s with T_d,ref, e_T with the scoring windows shaded, T_a. These are the
      figures <Ctrl>_<CASE>_resp_s99999.png written by Model/Sim/script/run_cases.m, copied here (not redrawn).
  Figure_15_drews_map.png, Figure_16_drews_pi.png, Figure_17_drews_pid.png
      Tracking error e_T on the five scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE), common noise seed 99999, same axes for the three
      controllers. Source: Result/Controllers/<Ctrl>/Cases/<Ctrl>_<CASE>_sig_s99999.csv

Usage: C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_results.py   (from the repo root)
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RC = os.path.join(REPO, 'Result', 'Controllers')
FIG = os.path.join(REPO, 'Figures')
GATE = 5.0
COL = {'Map': '#2a78d6', 'PI': '#cc9900', 'PID': '#eb6834'}
CASES = ['DRY', 'RAMP', 'SLIP', 'WEAVE', 'EDGE']
NUM = {'Map': (6, 9, 12, 15), 'PI': (7, 10, 13, 16), 'PID': (8, 11, 14, 17)}   # Pareto, DRY, SLIP, overview
plt.rcParams.update({'font.size': 9})


def front(d):
    d = d.sort_values(['S', 'R']).reset_index(drop=True)
    keep, best = [], np.inf
    for i, r in d.iterrows():
        if r.R < best - 1e-12:
            keep.append(i); best = r.R
    return d.loc[keep]


def sweep(ctrl):
    c = os.path.join(RC, ctrl, 'Calib')
    if ctrl == 'Map':
        m = pd.read_csv(os.path.join(c, 'Map_CALIB_sweep_s00000.csv'))
        pk = pd.read_csv(os.path.join(c, 'Map_CALIB_pick_s00000.csv'))
        ch = pk[pk.admissible == 1].sort_values('J').iloc[0]
        return (pd.DataFrame(dict(R=m.R_pct, S=m.S_Nm, e=m.erel_pct.abs())),
                (ch.R_pct, ch.S_Nm, f'$K_{{max}}$ {ch.K:g}, $g_{{min}}$ {ch.g_min:g}'))
    if ctrl == 'PI':
        p = pd.concat([pd.read_csv(os.path.join(c, 'PI_CALIB_sweep_s10000.csv')),
                       pd.read_csv(os.path.join(c, 'PI_CALIB_fine_s10000.csv'))], ignore_index=True)
        ch = pd.read_csv(os.path.join(c, 'PI_CALIB_pick_s10000.csv')).query('chosen == 1').iloc[0]
        return (pd.DataFrame(dict(R=p.R_pct, S=p.S_Nm, e=p.erel_pct.abs())),
                (ch.R_pct, ch.S_Nm, f'$K_p$ {ch.Kp:g}, $K_i$ {ch.Ki_1_per_s:g}'))
    q = pd.read_csv(os.path.join(c, 'PID_CALIB_sweep_s10000.csv'))
    ch = pd.read_csv(os.path.join(c, 'PID_CALIB_pick_s10000.csv')).query('chosen == 1').iloc[0]
    return (pd.DataFrame(dict(R=q.R_pct, S=q.S_Nm, e=q.erel_pct.abs())),
            (ch.R_pct, ch.S_Nm, f'$K_p$ {ch.Kp:g}, $K_i$ {ch.Ki_1_per_s:g}, $K_d$ {ch.Kd_s:g}, $T_f$ {1000 * ch.Tf_s:g} ms'))


def pareto_figs():
    data = {k: sweep(k) for k in COL}
    xs = pd.concat([d[0][d[0].e <= GATE].S for d in data.values()]); ys = pd.concat([d[0][d[0].e <= GATE].R for d in data.values()])
    xlim = (0.9 * xs.min(), 1.1 * xs.max()); ylim = (0.9 * ys.min(), 1.05 * ys.max())
    for k, (a, (R, S, t)) in data.items():
        ok = a[a.e <= GATE]; bad = a[a.e > GATE]; f = front(ok)
        fig, ax = plt.subplots(figsize=(6.0, 3.9))
        ax.scatter(bad.S, bad.R.clip(upper=ylim[1]), s=10, c='#c4c4c4', label=f'fails $|e_{{rel}}| \\leq 5$ % ({len(bad)})')
        ax.scatter(ok.S, ok.R, s=14, c=COL[k], alpha=0.55, label=f'passes ({len(ok)})')
        ax.step(f.S, f.R, where='post', c='k', lw=1.3, label='Pareto front')
        ax.scatter([S], [R], marker='*', s=200, c='#d62728', edgecolors='k', zorder=5, label=f'selected: {t}')
        ax.set_xscale('log'); ax.set_xlim(*xlim); ax.set_ylim(*ylim); ax.grid(True, which='both', color='#e3e3e3', lw=0.6)
        ax.set_xlabel('$S$ [N.m]'); ax.set_ylabel('$R$ [%]'); ax.set_title(f'{k} on CALIB: {len(a)} points simulated')
        ax.legend(fontsize=7.5, loc='upper right'); fig.tight_layout()
        fig.savefig(os.path.join(FIG, f'Figure_{NUM[k][0]}_pareto_{k.lower()}.png'), dpi=200); plt.close(fig)


def drews_figs():
    sig = {k: {c: pd.read_csv(os.path.join(RC, k, 'Cases', f'{k}_{c}_sig_s99999.csv')) for c in CASES} for k in COL}
    lim = {c: max(np.abs(sig[k][c].e_T[sig[k][c].t >= 2]).max() for k in COL) * 1.05 for c in CASES}
    for k in COL:
        fig, axs = plt.subplots(len(CASES), 1, figsize=(6.6, 8.2))
        for ax, c in zip(axs, CASES):
            d = sig[k][c]; w = d.t >= 2
            ax.plot(d.t[w], d.e_T[w], c=COL[k], lw=0.7)
            ax.axhline(0, c='k', lw=0.5); ax.set_ylim(-lim[c], lim[c]); ax.set_xlim(0, d.t.iloc[-1])
            ax.grid(True, color='#e3e3e3', lw=0.6); ax.set_ylabel('$e_T$ [N.m]')
            ax.set_title(c, fontsize=9, loc='left', pad=2)
        axs[-1].set_xlabel('t [s]'); fig.suptitle(f'{k}: tracking error on the scoring cases (same axes for all controllers)', fontsize=9.5)
        fig.tight_layout(); fig.savefig(os.path.join(FIG, f'Figure_{NUM[k][3]}_drews_{k.lower()}.png'), dpi=200); plt.close(fig)


def detail_figs():
    """Figures 9-14 are the three-panel figures written by run_cases.m (T_s with T_d,ref, e_T with the scoring windows, T_a); copied, not redrawn."""
    import shutil
    for ci, case in ((1, 'DRY'), (2, 'SLIP')):
        for k in COL:
            src = os.path.join(RC, k, 'Cases', f'{k}_{case}_resp_s99999.png')
            shutil.copyfile(src, os.path.join(FIG, f'Figure_{NUM[k][ci]}_{case.lower()}_{k.lower()}.png'))


if __name__ == '__main__':
    pareto_figs()
    detail_figs()
    drews_figs()
    print('written to', FIG)
