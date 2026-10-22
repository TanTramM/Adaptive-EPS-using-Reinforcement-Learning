"""Figures and tables of the common-seed Pareto comparison (Documents/Shared/KeHoach_SoMatPareto.txt, rule 0(f)).
Reads Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv (written by compare_pareto_common('front')) and writes
ParetoCommon_safe.png, ParetoCommon_full.png, ParetoCommon_table_safe.csv, ParetoCommon_table_full.csv.
Usage: python make_fig_pareto_common.py [--prelim]   (--prelim: mark the figures "preliminary, incomplete")
"""
import os
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, 'Result', 'Compare', 'Pareto_common')
prelim = '--prelim' in sys.argv
ctrls = ['Map', 'PID', 'MapPID']
color = {'Map': '#1f77b4', 'PID': '#d95f02', 'MapPID': '#1b9e77'}
levels = [2.5, 3, 4, 6, 10, 14, 20]
titles = {'safe': 'Safe front (linear gates + calib_margin)', 'full': 'Full-gate front (+ e_rel <= 10 %)'}

pts = {}
for c in ctrls:
    f = os.path.join(out, f'ParetoCommon_{c}_points_s99990-s99994.csv')
    if os.path.exists(f):
        pts[c] = pd.read_csv(f)

for mode in ['safe', 'full']:
    fig, ax = plt.subplots(figsize=(7.2, 4.8))
    rows = []
    for c, T in pts.items():
        live = T[T['alive_' + mode].astype(bool)]
        fr = T[T['status_' + mode] == 'front'].sort_values('Rtb')
        ax.scatter(live['Rtb'], live['Stb'], s=8, color=color[c], alpha=0.18, linewidths=0)
        if mode == 'safe':
            bad = fr[fr['erel_max'] > 10]
            ok = fr[fr['erel_max'] <= 10]
        else:
            bad = fr.iloc[0:0]; ok = fr
        if len(fr):
            ax.plot(fr['Rtb'], fr['Stb'], '-', color=color[c], lw=1.2)
        ax.scatter(ok['Rtb'], ok['Stb'], s=22, color=color[c], label=f'{c} ({len(fr)} points)', zorder=3)
        if len(bad):
            ax.scatter(bad['Rtb'], bad['Stb'], s=26, facecolors='none', edgecolors=color[c], zorder=3)
        if not len(fr):
            ax.plot([], [], ' ', label=f'{c} (empty front)')
        for lv in levels:
            sub = fr[fr['Rtb'] <= lv]
            if len(sub):
                i = sub['Stb'].idxmin()
                rows.append(dict(ctrl=c, R_level=lv, S_min=sub.loc[i, 'Stb'], S_sd=sub.loc[i, 'Ssd'], R_tb=sub.loc[i, 'Rtb'], erel_max=sub.loc[i, 'erel_max']))
            else:
                rows.append(dict(ctrl=c, R_level=lv, S_min=np.nan, S_sd=np.nan, R_tb=np.nan, erel_max=np.nan))
    sel_f = os.path.join(out, 'ParetoCommon_select.csv')
    if os.path.exists(sel_f):
        sel = pd.read_csv(sel_f)
        for _, r in sel.iterrows():
            if r['face_used'] == mode:
                ax.scatter([r['Rtb']], [r['Stb']], marker='*', s=170, color=color[r['ctrl']], edgecolors='k', linewidths=0.8, zorder=5, label=f"{r['ctrl']} final design")
            elif mode == 'safe':
                ax.scatter([r['Rtb']], [r['Stb']], marker='*', s=110, color=color[r['ctrl']], edgecolors='k', linewidths=0.8, zorder=5, label=f"{r['ctrl']} final design (full front)")
    ax.set_xscale('log'); ax.set_yscale('log')
    ax.set_xlabel('R, five-seed mean (%)'); ax.set_ylabel('S, five-seed mean (N.m)')
    t = titles[mode] + ', seeds 99990-99994'
    if mode == 'safe':
        t += '\nhollow marker: fails e_rel <= 10 %'
    if prelim:
        t += '\nPRELIMINARY, incomplete'
    ax.set_title(t, fontsize=10); ax.grid(True, which='both', alpha=0.3); ax.legend(fontsize=9)
    fig.tight_layout(); fig.savefig(os.path.join(out, f'ParetoCommon_{mode}.png'), dpi=160); plt.close(fig)

    T = pd.DataFrame(rows)
    # tie flag: two S values within 5 % or within the larger seed deviation are treated as equal (QuyChuan)
    wide = T.pivot(index='R_level', columns='ctrl', values='S_min')
    sd = T.pivot(index='R_level', columns='ctrl', values='S_sd')
    best = []
    for lv in wide.index:
        v = wide.loc[lv].dropna()
        if v.empty:
            best.append('none'); continue
        b = v.idxmin(); ties = [k for k in v.index if k != b and (abs(v[k] - v[b]) < 0.05 * v[b] or abs(v[k] - v[b]) < max(sd.loc[lv, k], sd.loc[lv, b]))]
        best.append(b if not ties else b + ' ~ ' + ' ~ '.join(ties))
    W = wide.copy(); W['lowest_S'] = best
    W.to_csv(os.path.join(out, f'ParetoCommon_table_{mode}.csv'), float_format='%.4g')
    print(mode); print(W.to_string(float_format=lambda x: f'{x:.4g}'))
