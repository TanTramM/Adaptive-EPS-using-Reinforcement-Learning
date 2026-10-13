# -*- coding: utf-8 -*-
"""Figures of the advisor's revision of the paper (Documents/Paper/2026.10.13_Paper_Tan - v5-Huypt.docx), written to Figures/v5_Huypt/.

  Figure_1_model.png         (a) mechanical structure of the C-EPS (Figure_1a_column.png from tools/make_fig_column.py, run that first)
                             (b) coupled plant block diagram (redrawn here; equation numbers follow the numbering of the revised text)
  Figure_2_architecture.png  (a) assist map with lead-lag compensator, (b) lateral-acceleration-based torque feedback (PI/PID), with the
                             common assist limit, motor, plant and sensors (also Figure_2_architecture.drawio, editable)
  Figure_3_pareto.png        CALIB Pareto plane (S, R) of (a) Map, (b) PI, (c) PID, shared axes
  Figure_4_dry.png           DRY: T_s with T_ref, e_T with the scoring windows shaded, T_a; columns (a) Map, (b) PI, (c) PID, shared axes per row
  Figure_5_slip.png          SLIP: same layout as Figure 4
  Figure_6_drews.png         e_T on DRY, RAMP, SLIP, WEAVE, EDGE; columns (a) Map, (b) PI, (c) PID, shared axes per row

Sources: Result/Controllers/<Ctrl>/Calib/*.csv and Result/Controllers/<Ctrl>/Cases/<Ctrl>_<CASE>_sig_s99999.csv (common seed 99999);
scoring windows: Figures/v5_Huypt/scoring_windows.csv, exported from Model/Sim/script/make_cases.m (fields tag, win.label, win.t0, win.t1).

Usage: C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_v5.py   (from the repo root)
"""
import os
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fig_blocks import Fig
from make_fig_results import front, sweep, RC, GATE

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Figures', 'v5_Huypt')
JSTT = os.path.join(REPO, 'Figures', 'JSTT')      # one file per figure for the journal: vector PDF and TIFF 1000 dpi (LZW)
os.makedirs(JSTT, exist_ok=True)
CTRL = ['Map', 'PI', 'PID']
NAME = {'Map': '(a) Assist map', 'PI': '(b) PI', 'PID': '(c) PID'}
COL = {'Map': '#2a78d6', 'PI': '#cc9900', 'PID': '#eb6834'}
CASES = ['DRY', 'RAMP', 'SLIP', 'WEAVE', 'EDGE']
T0 = 2.0                                     # first 2 s are not scored
plt.rcParams.update({'font.size': 8.5, 'font.family': 'Arial', 'axes.titlesize': 9,   # journal: only Arial, Courier, Times, Symbol
                     'mathtext.fontset': 'custom', 'mathtext.rm': 'Arial', 'mathtext.it': 'Arial:italic', 'mathtext.bf': 'Arial:bold',
                     'mathtext.default': 'it'})


def journal_copies(fig, n):
    fig.savefig(os.path.join(JSTT, 'Fig%d.pdf' % n), facecolor='white')
    fig.savefig(os.path.join(JSTT, 'Fig%d.tif' % n), dpi=1000, facecolor='white', pil_kwargs={'compression': 'tiff_lzw'})


def sig(ctrl, case):
    d = pd.read_csv(os.path.join(RC, ctrl, 'Cases', f'{ctrl}_{case}_sig_s99999.csv'))
    return d[d.t >= T0]


def windows(case):
    w = pd.read_csv(os.path.join(OUT, 'scoring_windows.csv'))
    return w[w.case == case]


# ---------------------------------------------------------------- Figure 1
def plant_block(path):
    """coupled plant drawn top-down: steering column -> tires -> vehicle body, feedback paths on the left, v and mu from the right"""
    f = Fig(640, 900)
    f.frame(90, 70, 450, 730)
    f.text(104, 88, 'Plant', fs=14, ha='left', bold=True, color='#555555')
    f.box(175, 120, 260, 130, ['Steering column', 'torsion bar, inertia,', 'damping, dry friction', 'Eqs. (1)-(2)'], fill='#e8f0fa', fs=15)
    f.box(175, 370, 260, 130, ['Tires', 'slip angles, Magic Formula,', 'pneumatic trail', 'Eqs. (3)-(11)'], fill='#e8f5e9', fs=15)
    f.box(175, 620, 260, 130, ['Vehicle body', 'single track, 2 DOF', 'Eqs. (12)-(14)'], fill='#fff4d6', fs=15)
    # inputs of the column (from the top) and its outputs (to the right)
    f.arrow([(255, 10), (255, 120)]); f.text(240, 35, r'$\theta_1$', ha='right', fs=18)
    f.arrow([(355, 10), (355, 120)]); f.text(340, 35, r'$T_a$', ha='right', fs=18)
    f.arrow([(435, 160), (630, 160)]); f.text(600, 144, r'$T_s$', fs=18)
    f.arrow([(435, 215), (630, 215)]); f.text(600, 199, r'$\dot{\theta}_2$', fs=18)
    # column -> tires -> body
    f.arrow([(305, 250), (305, 370)]); f.text(322, 310, r'$\theta_2$', ha='left', fs=18)
    f.arrow([(265, 500), (265, 620)]); f.text(250, 560, r'$F_{yf}$', ha='right', fs=18)
    f.arrow([(345, 500), (345, 620)]); f.text(362, 560, r'$F_{yr}$', ha='left', fs=18)
    # feedback paths (left side)
    f.arrow([(175, 440), (140, 440), (140, 185), (175, 185)]); f.text(125, 315, r'$T_r$', ha='right', fs=18)
    f.arrow([(175, 690), (140, 690), (140, 475), (175, 475)]); f.text(125, 585, r'$\beta,\ \gamma$', ha='right', fs=18)
    # exogenous v and mu (from the right)
    f.arrow([(630, 405), (435, 405)]); f.text(600, 389, r'$\mu$', fs=18)
    f.arrow([(630, 465), (435, 465)]); f.text(600, 449, r'$v$', fs=18)
    f.dot(495, 465); f.arrow([(495, 465), (495, 660), (435, 660)])
    # outputs of the body (to the bottom)
    f.arrow([(265, 750), (265, 890)]); f.text(250, 865, r'$a_y$', ha='right', fs=18)
    f.arrow([(345, 750), (345, 890)]); f.text(360, 865, r'$\gamma$', ha='left', fs=18)
    f.save_png(path, scale=6.0)


def fig1():
    tmp = os.path.join(OUT, '_plant_block.png')
    plant_block(tmp)
    a = plt.imread(os.path.join(OUT, 'Figure_1a_column.png'))   # tools/make_fig_column.py
    b = plt.imread(tmp)
    W, H = 7.2, 4.6                                              # [in]; panels side by side, captions below
    hp = H - 0.35                                                # height of the panels
    wa = hp * a.shape[1] / a.shape[0] * 0.92                     # column drawing slightly smaller than the panel height
    ha_ = wa * a.shape[0] / a.shape[1]
    wb = hp * b.shape[1] / b.shape[0]
    gap = max(0.1, W - wa - wb - 0.1)
    fig = plt.figure(figsize=(W, H))
    xa = 0.05; xb = xa + wa + gap
    ax = fig.add_axes([xa / W, (0.35 + (hp - ha_) / 2) / H, wa / W, ha_ / H]); ax.imshow(a); ax.axis('off')
    ax = fig.add_axes([xb / W, 0.35 / H, wb / W, hp / H]); ax.imshow(b); ax.axis('off')
    fig.text((xa + wa / 2) / W, 0.12 / H, '(a) Mechanical structure of the column-type EPS', ha='center', fontsize=9)
    fig.text((xb + wb / 2) / W, 0.12 / H, '(b) Coupled plant model', ha='center', fontsize=9)
    fig.savefig(os.path.join(OUT, 'Figure_1_model.png'), dpi=300, facecolor='white')
    journal_copies(fig, 1)
    plt.close(fig); os.remove(tmp)


# ---------------------------------------------------------------- Figure 2
def common_part(f, off):
    """assist limit -> motor -> plant -> sensors, measured bus at y = off + 280 running left"""
    f.box(600, off + 85, 150, 80, ['Assist limit', r'$|T_a| \leq T_{a,max}(v)$'], fill='#ffffff')
    f.box(810, off + 85, 160, 80, ['Motor', r'$G_m(s)$, 1 ms delay'], fill='#ffffff')
    f.box(1030, off + 75, 200, 100, ['C-EPS-vehicle', 'plant', 'column, tires, body'], fill='#d9ead3')
    f.box(830, off + 250, 190, 60, ['Sensors', 'noise, quantization'], fill='#fdefc3')
    f.arrow([(750, off + 125), (810, off + 125)]); f.text(780, off + 142, r'$T_{a,lim}$')
    f.arrow([(970, off + 125), (1030, off + 125)]); f.text(1000, off + 110, r'$T_a$')
    f.arrow([(1130, off + 20), (1130, off + 75)]); f.text(1185, off + 32, r'$\theta_1,\ v,\ \mu$')
    f.arrow([(1130, off + 175), (1130, off + 280), (1020, off + 280)])
    f.text(1185, off + 225, 'true signals', fs=11, color='#555555')
    f.arrow([(675, off + 280), (675, off + 165)]); f.dot(675, off + 280); f.text(690, off + 222, r'$v$', ha='left')


def fig2():
    f = Fig(1260, 690)
    # (a) assist map
    off = 30
    f.text(20, off - 10, '(a) Conventional assist-map control', fs=14, ha='left', bold=True)
    f.box(140, off + 85, 170, 80, ['Assist map', r'$M(v, T_s)$'], fill='#dce8f8')
    f.box(370, off + 85, 170, 80, ['Lead-lag', r'$C_{map}(s)$'], fill='#dce8f8')
    f.arrow([(310, off + 125), (370, off + 125)]); f.text(340, off + 110, r'$T_{a,map}$')
    f.arrow([(540, off + 125), (600, off + 125)]); f.text(570, off + 110, r'$T_{a,cmd}$')
    common_part(f, off)
    f.arrow([(830, off + 280), (60, off + 280), (60, off + 125), (140, off + 125)], lw=2.6)
    f.text(320, off + 298, r'measured $T_s$, $v$', fs=12)
    # (b) torque feedback
    off = 370
    f.text(20, off - 10, '(b) Lateral-acceleration-based torque feedback (PI / PID)', fs=14, ha='left', bold=True)
    f.box(20, off + 95, 150, 60, ['Reference', r'$T_{ref}(v, a_y)$'], fill='#fbe3d6')
    f.box(215, off + 105, 40, 40, [r'$\Sigma$'], fill='#ffffff', bold_first=False)
    f.box(295, off + 85, 160, 80, ['PI / PID', r'$K_p + K_i/s$'], fill='#fbe3d6')
    f.box(295, off + 190, 160, 60, ['D term (PID)', r'$K_d s/(\tau_d s + 1)$'], fill='#fbe3d6', fs=12)
    f.box(500, off + 105, 40, 40, [r'$\Sigma$'], fill='#ffffff', bold_first=False)
    f.arrow([(170, off + 125), (215, off + 125)]); f.text(200, off + 110, r'$-$')
    f.arrow([(255, off + 125), (295, off + 125)]); f.text(275, off + 110, r'$e_T$')
    f.arrow([(455, off + 125), (500, off + 125)]); f.text(490, off + 110, '+')
    f.arrow([(455, off + 220), (520, off + 220), (520, off + 145)]); f.text(532, off + 160, '+')
    f.arrow([(540, off + 125), (600, off + 125)]); f.text(570, off + 110, r'$T_{a,cmd}$')
    f.arrow([(780, off + 125), (780, off + 55), (375, off + 55), (375, off + 85)], dashed=True)
    f.text(580, off + 40, r'$T_{a,lim}$ (back-calculation anti-windup)', fs=11)
    common_part(f, off)
    f.arrow([(830, off + 280), (95, off + 280)], lw=2.6, head=False)
    f.arrow([(95, off + 280), (95, off + 155)], lw=1.6); f.text(80, off + 222, r'$v,\ a_y$', ha='right')
    f.dot(235, off + 280); f.arrow([(235, off + 280), (235, off + 145)]); f.text(248, off + 168, '+', ha='left')
    f.text(248, off + 222, r'$T_s$', ha='left')
    f.dot(375, off + 280); f.arrow([(375, off + 280), (375, off + 250)]); f.text(388, off + 266, r'$T_s$', ha='left')
    f.text(470, off + 298, r'measured $T_s$, $v$, $a_y$', fs=12)
    f.save_drawio(os.path.join(OUT, 'Figure_2_architecture.drawio'))
    f.save_png(os.path.join(OUT, 'Figure_2_architecture.png'), scale=2.4)
    f.save_png(os.path.join(JSTT, 'Fig2.pdf'), scale=1.0)
    f.save_png(os.path.join(JSTT, 'Fig2.tif'), scale=10.0)


# ---------------------------------------------------------------- Figure 3
def fig3_column(data, xlim, ylim):
    """journal version of Figure 3: the three panels stacked, one column wide (8.4 cm)"""
    fig, axs = plt.subplots(3, 1, figsize=(3.35, 6.6), sharex=True, sharey=True)
    for ax, k in zip(axs, CTRL):
        a, R, S, t = data[k]
        ok = a[a.e <= GATE]; bad = a[a.e > GATE]; f = front(ok)
        ax.scatter(bad.S, bad.R.clip(upper=ylim[1]), s=5, c='#c4c4c4', label=f'fails gate ({len(bad)})')
        ax.scatter(ok.S, ok.R, s=7, c=COL[k], alpha=0.55, label=f'passes ({len(ok)})')
        ax.step(f.S, f.R, where='post', c='k', lw=1.0, label='Pareto front')
        ax.scatter([S], [R], marker='*', s=90, c='#d62728', edgecolors='k', zorder=5, label='selected')
        ax.set_xscale('log'); ax.set_xlim(*xlim); ax.set_ylim(*ylim); ax.grid(True, which='both', color='#e3e3e3', lw=0.5)
        ax.set_xticks([0.15, 0.2, 0.3, 0.4, 0.6]); ax.set_xticklabels(['0.15', '0.2', '0.3', '0.4', '0.6'])
        ax.minorticks_off()
        ax.set_title(NAME[k] + f': {len(a)} configurations', fontsize=8, loc='left')
        ax.set_ylabel('$R$ [%]', fontsize=8)
        ax.tick_params(labelsize=7.5)
        ax.legend(fontsize=6, loc='upper right', handletextpad=0.3, borderpad=0.3, labelspacing=0.25)
    axs[-1].set_xlabel('$S$ [N·m]', fontsize=8)
    fig.tight_layout(h_pad=0.6)
    fig.savefig(os.path.join(OUT, 'Figure_3_pareto_col.png'), dpi=300)
    journal_copies(fig, 3)
    plt.close(fig)


def fig3():
    data = {}
    for k in CTRL:
        a, (R, S, t) = sweep(k)
        data[k] = (a, R, S, t.replace('$T_f$', r'$\tau_d$'))
    ok_all = pd.concat([d[0][d[0].e <= GATE] for d in data.values()])
    xlim = (0.9 * ok_all.S.min(), 1.1 * ok_all.S.max()); ylim = (0.9 * ok_all.R.min(), 1.05 * ok_all.R.max())
    fig, axs = plt.subplots(1, 3, figsize=(7.2, 2.9), sharey=True)
    for ax, k in zip(axs, CTRL):
        a, R, S, t = data[k]
        ok = a[a.e <= GATE]; bad = a[a.e > GATE]; f = front(ok)
        ax.scatter(bad.S, bad.R.clip(upper=ylim[1]), s=6, c='#c4c4c4', label=f'fails gate ({len(bad)})')
        ax.scatter(ok.S, ok.R, s=8, c=COL[k], alpha=0.55, label=f'passes ({len(ok)})')
        ax.step(f.S, f.R, where='post', c='k', lw=1.1, label='Pareto front')
        ax.scatter([S], [R], marker='*', s=110, c='#d62728', edgecolors='k', zorder=5, label='selected')
        ax.set_xscale('log'); ax.set_xlim(*xlim); ax.set_ylim(*ylim); ax.grid(True, which='both', color='#e3e3e3', lw=0.5)
        ax.set_xticks([0.15, 0.2, 0.3, 0.4, 0.6]); ax.set_xticklabels(['0.15', '0.2', '0.3', '0.4', '0.6'])
        ax.minorticks_off()
        ax.set_xlabel('$S$ [N·m]'); ax.set_title(NAME[k] + f'\n{len(a)} configurations', fontsize=9)
        ax.legend(fontsize=6.5, loc='upper right', handletextpad=0.3, borderpad=0.4)   # selected parameters: Table 2 of the paper
    axs[0].set_ylabel('$R$ [%]')
    fig.tight_layout(w_pad=0.6)
    fig.savefig(os.path.join(OUT, 'Figure_3_pareto.png'), dpi=300); plt.close(fig)
    fig3_column(data, xlim, ylim)


# ---------------------------------------------------------------- Figures 4 and 5
def fig_case(case, num):
    D = {k: sig(k, case) for k in CTRL}
    W = windows(case)
    lims = []
    for col in ('T_s', 'e_T', 'T_a'):
        m = max(np.abs(D[k][col]).max() for k in CTRL)
        if col == 'T_s':
            m = max(m, max(np.abs(D[k].T_d_ref).max() for k in CTRL))
        lims.append(1.08 * m)
    fig, axs = plt.subplots(3, 3, figsize=(7.2, 5.0), sharex=True, sharey='row')
    for j, k in enumerate(CTRL):
        d = D[k]
        ax = axs[0, j]
        ax.plot(d.t, d.T_s, c=COL[k], lw=0.7, label='$T_s$')
        ax.plot(d.t, d.T_d_ref, c='k', lw=0.8, ls='--', label='$T_{ref}$')
        ax.set_title(NAME[k], fontsize=9.5, fontweight='bold')
        ax = axs[1, j]
        for _, w in W.iterrows():
            ax.axvspan(w.t0, w.t1, color='#cfdcf0', lw=0)
        ax.plot(d.t, d.e_T, c=COL[k], lw=0.6)
        ax.axhline(0, c='k', lw=0.4)
        ax = axs[2, j]
        ax.plot(d.t, d.T_a, c=COL[k], lw=0.5)
        axs[2, j].set_xlabel('$t$ [s]')
        for i in range(3):
            axs[i, j].set_ylim(-lims[i], lims[i]); axs[i, j].set_xlim(0, d.t.iloc[-1])
            axs[i, j].grid(True, color='#e6e6e6', lw=0.5)
    axs[0, 0].legend(fontsize=7, loc='lower left', ncol=2, handlelength=1.6)
    axs[0, 0].set_ylabel('$T_s$, $T_{ref}$ [N·m]'); axs[1, 0].set_ylabel('$e_T$ [N·m]'); axs[2, 0].set_ylabel('$T_a$ [N·m]')
    fig.tight_layout(h_pad=0.4, w_pad=0.4)
    fig.savefig(os.path.join(OUT, f'Figure_{num}_{case.lower()}.png'), dpi=300); journal_copies(fig, num); plt.close(fig)


# ---------------------------------------------------------------- Figure 6
def fig6():
    D = {k: {c: sig(k, c) for c in CASES} for k in CTRL}
    fig, axs = plt.subplots(len(CASES), 3, figsize=(7.2, 7.6), sharey='row')
    for i, c in enumerate(CASES):
        lim = 1.05 * max(np.abs(D[k][c].e_T).max() for k in CTRL)
        for j, k in enumerate(CTRL):
            d = D[k][c]; ax = axs[i, j]
            ax.plot(d.t, d.e_T, c=COL[k], lw=0.5)
            ax.axhline(0, c='k', lw=0.4)
            ax.set_ylim(-lim, lim); ax.set_xlim(0, d.t.iloc[-1]); ax.grid(True, color='#e6e6e6', lw=0.5)
            if i == 0:
                ax.set_title(NAME[k], fontsize=9.5, fontweight='bold')
            if j == 0:
                ax.set_ylabel(f'{c}\n$e_T$ [N·m]')
            if i == len(CASES) - 1:
                ax.set_xlabel('$t$ [s]')
    fig.tight_layout(h_pad=0.5, w_pad=0.4)
    fig.savefig(os.path.join(OUT, 'Figure_6_drews.png'), dpi=300); plt.close(fig)
    journal_copies(fig, 6)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    fig1(); fig2(); fig3()
    fig_case('DRY', 4); fig_case('SLIP', 5)
    fig6()
    print('written to', OUT)
