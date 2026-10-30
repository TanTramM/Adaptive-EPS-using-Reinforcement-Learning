"""Comparison figure PID vs MapPID of paper section 5 -> Figures/main/Fig_14_seeds.png:
whole-sequence E_RMS against S for the five noise seeds 99995-99999, one panel per sequence.
Data: Result/Controllers/<Ctrl>/Cases_ssw/<Ctrl>_metrics_s<seed>.csv (row 'whole case').
(The e_T zoom and the fast-component views of PID and MapPID were drawn and dropped: the two controllers look alike in them.)
Usage: python make_fig_compare.py
"""
import os
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = os.path.join(root, 'Result', 'Controllers')
out = os.path.join(root, 'Figures', 'main')
plt.rcParams.update({
    'font.family': 'serif', 'font.serif': ['Times New Roman', 'DejaVu Serif'], 'mathtext.fontset': 'stix',
    'font.size': 9, 'axes.labelsize': 9, 'legend.fontsize': 8.5, 'xtick.labelsize': 8, 'ytick.labelsize': 8,
    'axes.linewidth': 0.7, 'savefig.dpi': 400, 'figure.dpi': 120,
})
color = {'PID': '#d95f02', 'MapPID': '#1b9e77'}
marker = {'PID': '^', 'MapPID': 'o'}

rows = []
for c in ('PID', 'MapPID'):
    for s in range(99995, 100000):
        m = pd.read_csv(os.path.join(R, c, 'Cases_ssw', f'{c}_metrics_s{s}.csv'))
        for _, r in m[m.Window == 'whole case'].iterrows():
            rows.append((c, r.Case, s, r.RMS_eT_Nm, r.S_Nm))
df = pd.DataFrame(rows, columns=['c', 'case', 'seed', 'E', 'S'])
fig, axs = plt.subplots(1, 3, figsize=(6.5, 2.5))
for ax, case in zip(axs, ('STEADY', 'SLIP', 'WEAVE')):
    for c in ('PID', 'MapPID'):
        q = df[(df.case == case) & (df.c == c)]
        ax.scatter(q.E, q.S, s=22, marker=marker[c], color=color[c], zorder=3)
    ax.set_title(case, fontsize=9, loc='left')
    ax.set_xlabel('$E_{RMS}$ (N$\\cdot$m)')
    ax.grid(True, color='#e3e3e3', lw=0.4)
    ax.tick_params(direction='in', length=2.5)
    for s in ('top', 'right'):
        ax.spines[s].set_visible(False)
axs[0].set_ylabel('$S$ (N$\\cdot$m)')
h = [plt.Line2D([], [], color=color[c], marker=marker[c], ls='', markersize=5, label=c) for c in ('PID', 'MapPID')]
fig.legend(handles=h, loc='upper center', ncol=2, frameon=False, bbox_to_anchor=(0.5, 1.07), handletextpad=0.2)
fig.tight_layout()
fig.savefig(os.path.join(out, 'Fig_14_seeds.png'), bbox_inches='tight', facecolor='white')
plt.close(fig)

print('wrote Fig_14_seeds.png')
