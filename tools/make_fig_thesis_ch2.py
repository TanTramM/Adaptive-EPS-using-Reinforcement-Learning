"""Figures of thesis chapter 2 (Documents/Thesis/luanvan.txt) -> Documents/Thesis/figures/.

Hinh_2_1 .. Hinh_2_3: the three drawings of the paper (Figures/main/Fig_1..3) copied; in Fig_1 the three English block names are replaced by Vietnamese ones.
Unused matplotlib draft (the thesis uses tools/make_fig_thesis_ch2.m, MATLAB): lateral force F_yf and road-reaction torque T_r of the front axle against the slip angle, mu = 0.8, 0.5, 0.3 (formulas of Section 2.3, parameters read from params.json).
Unused (removed from the thesis, kept in Documents/Thesis/draft): pneumatic trail of the model against the brush model of Pacejka (2006), normalised trail t/t0 against x = C_alpha |tan(alpha)| / (3 mu F_z); the closed form of the
          brush model is first checked against a numerical integration of the brush model (assert).
Unused matplotlib draft (see make_fig_thesis_ch2.m): target torque T_ref(v, a_y) from the fine table of ref.json, with the four tabulated points.
All numbers come from Model/shared/data/*.json; nothing is typed by hand.

Run: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig_thesis_ch2.py
"""
import json
import os
import shutil

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'Model', 'shared', 'data')
OUT = os.path.join(ROOT, 'Documents', 'Thesis', 'figures')
os.makedirs(OUT, exist_ok=True)

plt.rcParams.update({'font.family': 'Times New Roman', 'mathtext.fontset': 'stix', 'font.size': 12, 'axes.spines.top': False,
                     'axes.spines.right': False, 'axes.grid': True, 'grid.color': '#e1e0d9', 'grid.linewidth': 0.8,
                     'axes.edgecolor': '#898781', 'xtick.color': '#52514e', 'ytick.color': '#52514e'})
BLUE, ORANGE, AQUA, GREY = '#2a78d6', '#eb6834', '#1baf7a', '#898781'

P = json.load(open(os.path.join(DATA, 'params.json'), encoding='utf-8'))
v1 = lambda g, k: P[g][k]['value']
m, lf, lr, g = v1('cum2', 'm'), v1('cum2', 'l_f'), v1('cum2', 'l_r'), v1('cum2', 'g')
Caf, C, E = v1('cum2', 'C_alpha_f'), v1('cum2', 'C'), v1('cum2', 'E')
nst, ep0, t0 = v1('cum2', 'n_st'), v1('cum2', 'e_p0'), v1('cum2', 't_0')
ec = ep0 - t0
Fzf = m * g * lr / (lf + lr)


def fyf(alpha, mu):
    D = mu * Fzf
    B = Caf / (C * D)
    x = B * alpha
    return D * np.sin(C * np.arctan(x - E * (x - np.arctan(x))))


def trail(alpha, mu):
    return np.maximum(0.0, t0 - t0 * Caf * np.abs(np.tan(alpha)) / (3 * mu * Fzf))


def tr(alpha, mu):
    return (ec + trail(alpha, mu)) / nst * fyf(alpha, mu)


# ------------------------------------------------------------------ figures 2.1 - 2.3 (drawings of the paper)
src = os.path.join(ROOT, 'Figures', 'main')
shutil.copyfile(os.path.join(src, 'Fig_2_Column.png'), os.path.join(OUT, 'Hinh_2_2_Column.png'))
shutil.copyfile(os.path.join(src, 'Fig_3_Tire_force.png'), os.path.join(OUT, 'Hinh_2_3_Tire_force.png'))

im = Image.open(os.path.join(src, 'Fig_1_Plant.png'))
if im.mode != 'RGB':
    bg = Image.new('RGB', im.size, 'white')
    bg.paste(im, mask=im.split()[-1] if im.mode == 'RGBA' else None)
    im = bg
d = ImageDraw.Draw(im)
FONT = 'C:/Windows/Fonts/times.ttf'
# text boxes in the original pixel grid (3780 x 1293): (x0, y0, x1, y1) of the English words, and their Vietnamese replacement
boxes = [((565, 425, 950, 485), 'Cột lái'), ((1825, 492, 1960, 552), 'Lốp'), ((2780, 375, 3265, 437), 'Thân xe 2 bậc tự do')]
size = 58
ref_w = d.textlength('Steering column', font=ImageFont.truetype(FONT, size))
size = int(round(size * (950 - 565 - 14) / ref_w))      # calibrate: the old word spans about the box width minus a margin
font = ImageFont.truetype(FONT, size)
for (x0, y0, x1, y1), text in boxes:
    d.rectangle((x0, y0, x1, y1), fill='white')
    w = d.textlength(text, font=font)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    d.text((cx - w / 2, cy), text, font=font, fill=(34, 34, 34), anchor='lm')
im.save(os.path.join(OUT, 'Hinh_2_1_Plant.png'))

# ------------------------------------------------------------------ figure 2.5: F_yf and T_r against the slip angle
mus = [(0.8, BLUE), (0.5, ORANGE), (0.3, AQUA)]
a_deg = np.linspace(0, 12, 1201)
a = np.radians(a_deg)
fig, ax = plt.subplots(1, 2, figsize=(11, 4.2))
summary = {}
for mu, col in mus:
    F = fyf(a, mu) / 1000
    T = tr(a, mu)
    asl = np.degrees(np.arctan(3 * mu * Fzf / Caf))
    ipk = int(np.argmax(F))
    summary[mu] = dict(alpha_sl=asl, alpha_peak_F=a_deg[ipk], F_peak=F[ipk], alpha_peak_T=a_deg[int(np.argmax(T))], T_peak=T.max())
    ax[0].plot(a_deg, F, color=col, lw=2.2, label='$\\mu$ = %.1f' % mu)
    ax[1].plot(a_deg, T, color=col, lw=2.2, label='$\\mu$ = %.1f' % mu)
    ax[1].axvline(asl, color=col, lw=1.0, ls=':')
    ax[1].text(asl + 0.15, 0.2 + 0.45 * mus.index((mu, col)), '$\\alpha_{sl}$ = %.1f°' % asl, color=col, fontsize=10.5)
ax[0].set_xlabel('Góc trượt bánh trước $\\alpha_f$ (độ)'); ax[0].set_ylabel('Lực ngang cầu trước $F_{yf}$ (kN)')
ax[1].set_xlabel('Góc trượt bánh trước $\\alpha_f$ (độ)'); ax[1].set_ylabel('Mô-men phản lực $T_r$ (N·m)')
for k, (t_) in enumerate(['(a)', '(b)']):
    ax[k].text(0.0, -0.22, t_, transform=ax[k].transAxes, fontsize=12)
    ax[k].set_xlim(0, 12); ax[k].set_ylim(bottom=0)
    ax[k].legend(frameon=False, loc='lower right' if k == 0 else 'upper right')
fig.tight_layout()
fig.savefig(os.path.join(OUT, '..', 'draft', 'matplotlib_Hinh_2_4_unused.png'), dpi=200)
plt.close(fig)

# ------------------------------------------------------------------ figure 2.4: pneumatic trail, model against the brush model
def brush_closed(x):
    """t/t0 of the brush model, Pacejka (2006) Eq. (3.13), x = theta_y sigma_y = C_Falpha |tan alpha| / (3 mu F_z); t0 = a/3."""
    x = np.asarray(x, float)
    out = (1 - 3 * x + 3 * x ** 2 - x ** 3) / (1 - x + x ** 2 / 3)
    return np.where(x < 1, out, 0.0)


def brush_numeric(x, a=0.075, n=40001):
    """t/t0 by integrating the brush model (parabolic pressure, linear deflection from the leading edge) - independent check of the closed form."""
    xs = np.linspace(-a, a, n)
    qz = 3.0 / (4 * a) * (1 - (xs / a) ** 2)                    # F_z = 1
    mu = 1.0
    cpy_sigma = 3 * mu * x / (2 * a ** 2)                       # from x = 2 c_py a^2 sigma / (3 mu F_z)
    qy = np.minimum(cpy_sigma * (a - xs), mu * qz)
    Fy = np.trapz(qy, xs)
    xcp = np.trapz(qy * xs, xs) / Fy
    return (-xcp) / (a / 3)


for xv in (0.05, 0.2, 0.5, 0.8, 0.95):
    assert abs(brush_closed(xv) - brush_numeric(xv)) < 2e-3, (xv, brush_closed(xv), brush_numeric(xv))
xs_ = np.linspace(0, 1.15, 600)
fig, ax = plt.subplots(figsize=(6.4, 4.2))
ax.plot(xs_, np.maximum(0, 1 - xs_), color=BLUE, lw=2.2, label='Mô hình của luận văn, PT (2.10)')
ax.plot(xs_, brush_closed(xs_), color=ORANGE, lw=2.2, label='Mô hình chổi, PT (2.12)')
ax.axvline(1.0, color=GREY, lw=1.0, ls=':')
ax.text(1.015, 0.06, 'trượt hoàn toàn', color=GREY, rotation=90, fontsize=10.5)
ax.set_xlabel('$x = C_{\\alpha f}\\,|\\tan\\alpha_f| \\,/\\, (3\\mu F_{zf})$'); ax.set_ylabel('Vệt khí nén chuẩn hóa $t_p / t_0$')
ax.set_xlim(0, 1.15); ax.set_ylim(0, 1.05)
ax.legend(frameon=False, loc='upper right')
fig.tight_layout()
fig.savefig(os.path.join(OUT, '..', 'draft', 'Hinh_2_4_trail_brush_unused.png'), dpi=200)
plt.close(fig)
trail_mid = dict(x05_linear=float(1 - 0.5), x05_brush=float(brush_closed(0.5)))

# ------------------------------------------------------------------ figure 2.6: target torque
R = json.load(open(os.path.join(DATA, 'ref.json'), encoding='utf-8'))
fine = R['fine']
vf, af = np.array(fine['v_breakpoints_kmh'], float), np.array(fine['ay_breakpoints_g'], float)
tab = np.array(fine['table_Nm'], float)                          # [a_y index][v index]
assert tab.shape == (len(af), len(vf))
vb, ab = R['v_breakpoints_kmh'], R['ay_breakpoints_g']
tb = np.array(R['table_Nm'], float)                              # [a_y][v] at the published points
cols = [BLUE, ORANGE, AQUA, '#eda100', '#6250d6']
fig, ax = plt.subplots(figsize=(6.6, 4.4))
for k, vk in enumerate(vb):
    j = int(np.argmin(abs(vf - vk)))
    assert abs(vf[j] - vk) < 1e-9
    ax.plot(af, tab[:, j], color=cols[k], lw=2.0)
    ax.plot(ab, tb[:, k], 'o', color=cols[k], ms=6, mec='white', mew=0.8)
    ax.text(0.405, tab[-1, j] + {100: 0.07, 80: -0.07}.get(vk, 0.0), '%d km/h' % vk, color=cols[k], va='center', fontsize=10.5)
ax.set_xlabel('Gia tốc ngang $a_y$ (g)'); ax.set_ylabel('Mô-men mục tiêu $T_{ref}$ (N·m)')
ax.set_xlim(0, 0.47); ax.set_ylim(0, 3.7)
fig.tight_layout()
fig.savefig(os.path.join(OUT, '..', 'draft', 'matplotlib_Hinh_2_5_unused.png'), dpi=200)
plt.close(fig)

print('F_zf = %.2f N, e_c = %.4f m' % (Fzf, ec))
for mu, s in summary.items():
    print('mu %.1f: alpha_sl %.2f deg | F_yf peak %.2f kN at %.2f deg | T_r peak %.3f N.m at %.2f deg' %
          (mu, s['alpha_sl'], s['F_peak'], s['alpha_peak_F'], s['T_peak'], s['alpha_peak_T']))
print('trail at x = 0.5: linear %.3f, brush %.3f' % (trail_mid['x05_linear'], trail_mid['x05_brush']))
print('written to', OUT)
