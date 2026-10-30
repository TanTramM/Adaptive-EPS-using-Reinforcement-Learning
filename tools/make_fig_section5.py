"""Figures of paper section 5 -> Figures/main: six figures, one per sequence for Map and MapPID (Fig_8 ... Fig_13).
Each figure shows the target T_ref (thin dashed line) and the torsion-bar torque T_s (solid line) of one controller over one 100 s sequence.
Data: Result/Controllers/<Ctrl>/Cases_ssw/<Ctrl>_<CASE>_sig_s99999.csv (10 ms samples of the true model signals, seed 99999).
The three figures of a sequence share one vertical scale, and they fill one page of the paper.
Usage: python make_fig_section5.py
"""
import os
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, 'Figures', 'main')
os.makedirs(out, exist_ok=True)

plt.rcParams.update({
    'font.family': 'serif', 'font.serif': ['Times New Roman', 'DejaVu Serif'], 'mathtext.fontset': 'stix',
    'font.size': 9, 'axes.labelsize': 9, 'legend.fontsize': 8.5, 'xtick.labelsize': 8, 'ytick.labelsize': 8,
    'axes.linewidth': 0.7, 'savefig.dpi': 400, 'figure.dpi': 120,
})

ctrls = ['Map', 'PID', 'MapPID']
color = {'Map': '#1f77b4', 'PID': '#d95f02', 'MapPID': '#1b9e77'}
REF = dict(color='#404040', lw=0.7, ls=(0, (4, 2.2)))
num = 8
for case in ('STEADY', 'SLIP', 'WEAVE'):
    d = {c: pd.read_csv(os.path.join(root, 'Result', 'Controllers', c, 'Cases_ssw', f'{c}_{case}_sig_s99999.csv')) for c in ctrls}
    lo = min(min(d[c].T_s.min(), d[c].T_d_ref.min()) for c in ctrls)
    hi = max(max(d[c].T_s.max(), d[c].T_d_ref.max()) for c in ctrls)
    pad = 0.06 * (hi - lo)
    for c in ('Map', 'MapPID'):
        fig, ax = plt.subplots(figsize=(6.5, 2.35))
        ax.plot(d[c].t, d[c].T_d_ref, zorder=2, **REF)
        ax.plot(d[c].t, d[c].T_s, color=color[c], lw=0.75, zorder=3)
        ax.set_xlim(0, 100)
        ax.set_ylim(lo - pad, hi + pad)
        ax.set_xlabel('Time (s)')
        ax.set_ylabel('Torque (N$\\cdot$m)')
        ax.grid(True, color='#e3e3e3', lw=0.4)
        ax.tick_params(direction='in', length=2.5)
        for s in ('top', 'right'):
            ax.spines[s].set_visible(False)
        h = [plt.Line2D([], [], label='$T_{ref}$', **REF), plt.Line2D([], [], color=color[c], lw=0.9, label='$T_s$')]
        ax.legend(handles=h, loc='upper right', ncol=2, frameon=False, handlelength=2.6, columnspacing=1.2, bbox_to_anchor=(1.0, 1.16))
        fig.tight_layout()
        fig.savefig(os.path.join(out, f'Fig_{num}_{case}_{c}.png'), bbox_inches='tight', facecolor='white')
        plt.close(fig)
        num += 1
print('wrote Fig_8 ... Fig_13 in', out)
