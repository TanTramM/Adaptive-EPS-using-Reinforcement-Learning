"""Figure of paper section 4 -> Figures/main/Fig_7_Pareto.png (common-seed Pareto fronts of Map, PID and MapPID).
Data: Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv (only the points on the safe and full fronts are drawn).
Selected designs are the official ones of Table 7 (R, S means over the five common seeds).
Usage: python make_fig_section4.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, 'Result', 'Compare')
out = os.path.join(root, 'Figures', 'main')
os.makedirs(out, exist_ok=True)

plt.rcParams.update({
    'font.family': 'serif', 'font.serif': ['Times New Roman', 'DejaVu Serif'], 'mathtext.fontset': 'stix',
    'font.size': 10, 'axes.labelsize': 10, 'legend.fontsize': 9, 'xtick.labelsize': 9, 'ytick.labelsize': 9,
    'axes.linewidth': 0.8, 'savefig.dpi': 400, 'figure.dpi': 120,
})

ctrls = ['Map', 'PID', 'MapPID']
color = {'Map': '#1f77b4', 'PID': '#d95f02', 'MapPID': '#1b9e77'}
marker = {'Map': 's', 'PID': '^', 'MapPID': 'o'}
selected = {'Map': (12.0719, 0.4397), 'PID': (3.2241, 0.7782), 'MapPID': (2.5330, 0.7953)}

pts = {c: pd.read_csv(os.path.join(res, 'Pareto_common', f'ParetoCommon_{c}_points_s99990-s99994.csv')) for c in ctrls}
fig, ax = plt.subplots(figsize=(6.5, 4.7))
for c in ctrls:
    s = pts[c][pts[c].in_set == 1]
    for key, filled in (('front_safe', False), ('front_full', True)):
        f = s[s[key] == 1].sort_values('Rtb')
        if len(f) == 0:
            continue
        ax.plot(f.Rtb, f.Stb, color=color[c], lw=1.0, zorder=3)
        ax.scatter(f.Rtb, f.Stb, s=34, marker=marker[c], facecolor=color[c] if filled else 'white',
                   edgecolor=color[c], lw=1.0, zorder=4)
    r, sv = selected[c]
    ax.scatter([r], [sv], s=130, marker='o', facecolor='none', edgecolor='black', lw=1.2, zorder=6)
ax.grid(True, which='major', color='#dddddd', lw=0.5)
ax.tick_params(direction='in')
for s_ in ('top', 'right'):
    ax.spines[s_].set_visible(False)
ax.set_xlabel(r'$\bar R$ (%)')
ax.set_ylabel(r'$\bar S$ (N$\cdot$m)')
ax.set_xscale('log')
ax.set_xlim(2, 200)
ax.set_ylim(0, 1.3)
ax.set_xticks([2, 5, 10, 20, 50, 100])
ax.set_xticklabels(['2', '5', '10', '20', '50', '100'])
ax.xaxis.set_minor_formatter(matplotlib.ticker.NullFormatter())
h = [plt.Line2D([], [], color=color[c], marker=marker[c], ls='-', lw=1.0, markerfacecolor=color[c], markersize=6, label=c)
     for c in ctrls]
h += [plt.Line2D([], [], color='#555555', marker='o', ls='', markerfacecolor='white', markersize=6, label='safe front'),
      plt.Line2D([], [], color='#555555', marker='o', ls='', markersize=6, label='full front'),
      plt.Line2D([], [], color='black', marker='o', ls='', markerfacecolor='none', markersize=9, label='selected design')]
ax.legend(handles=h, loc='upper right', frameon=False, ncol=2)
fig.tight_layout()
fig.savefig(os.path.join(out, 'Fig_7_Pareto.png'), bbox_inches='tight', facecolor='white')
plt.close(fig)
print('wrote', os.path.join(out, 'Fig_7_Pareto.png'))
