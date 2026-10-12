"""Figure for the paper, Section 2.3: brush model of the tire contact patch (own drawing, replaces the borrowed figure of Pacejka's book).

Brush model (Pacejka 2006, Sec. 3.2): contact patch -a <= x <= a (leading edge at +a), parabolic vertical load q_z(x) = 3 F_z/(4a) (1 - (x/a)^2),
bristle deflection v(x) = (a - x) tan(alpha), lateral force per length q_y = min(c_py v, mu q_z).
With k = theta*tan(alpha) = tan(alpha)/tan(alpha_sl), theta = 2 c_py a^2/(3 mu F_z) = C_alpha/(3 mu F_z):
  sliding region x < x_s = a (2k - 1), adhesion region x_s < x <= a, full sliding for k >= 1,
  pneumatic trail t = -M_z/F_y, t -> a/3 for small k and 0 for k >= 1.
Panel (d) compares the exact brush trail with the linear law of Eq. (6) of the paper, t = t_0 (1 - k).

Usage:  python -X utf8 tools/make_fig_brush.py      (writes Figures/Figure_4_brush_model.png)
"""
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, Polygon

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'Figures', 'Figure_4_brush_model.png')
BLUE, RED, GREY, DARK, GREEN = '#1f5fa8', '#c0392b', '#9aa3ab', '#222222', '#2e7d32'
plt.rcParams.update({'font.size': 10, 'mathtext.fontset': 'dejavuserif', 'font.family': 'DejaVu Serif'})
x = np.linspace(-1, 1, 4001)
qz = 0.75 * (1 - x ** 2)                                  # a = 1, F_z = 1, mu = 1


def brush(k):
    """lateral force per length of the brush model for k = theta*tan(alpha); returns q_y, x_s, F_y, t"""
    xs = min(max(2 * k - 1, -1.0), 1.0)
    q = np.where(x >= xs, 1.5 * k * (1 - x), qz)
    q = np.minimum(q, qz) if k < 1 else qz
    Fy = np.trapz(q, x); Mz = np.trapz(q * x, x)
    return q, xs, Fy, (-Mz / Fy if Fy > 0 else 0.0)


def arrow(ax, p, q, color, lw=2.0, style='-|>', ms=14, z=5):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle=style, mutation_scale=ms, color=color, lw=lw, zorder=z, shrinkA=0, shrinkB=0))


fig = plt.figure(figsize=(12.6, 7.4))
gs = fig.add_gridspec(2, 3, height_ratios=[1.0, 0.95], hspace=0.30, wspace=0.12)
cases = [('A', 0.15, 'small slip: a short sliding zone at the rear'), ('B', 0.70, 'larger slip: sliding starts at the rear'), ('C', 1.15, 'full sliding: $q_y=\\mu q_z$')]
for j, (name, k, sub) in enumerate(cases):
    ax = fig.add_subplot(gs[0, j])
    q, xs, Fy, t = brush(k)
    ax.plot([-1.25, 1.25], [0, 0], color=DARK, lw=2.0, zorder=3)
    ax.plot(x, -qz, color=GREY, lw=1.4, ls='--', zorder=2)                                    # friction limit  mu q_z
    ax.fill_between(x, 0, -q, where=(x >= xs), color='#9fc3e8', alpha=0.9, zorder=1)           # adhesion region
    ax.fill_between(x, 0, -q, where=(x <= xs), color='#f1b7ae', alpha=0.9, zorder=1)           # sliding region
    for xb in np.arange(-0.96, 1.0, 0.08):                                                     # bristles
        i = np.argmin(abs(x - xb)); ax.plot([xb, xb], [0, -q[i]], color='#555555', lw=0.7, zorder=2)
    ax.plot(x, -q, color=DARK, lw=1.6, zorder=3)
    ax.plot([0, 0], [0.05, -0.05], color=DARK, lw=1.0)
    ax.text(0, 0.07, '$C$', ha='center', va='bottom', fontsize=11)
    if Fy > 0:
        top = -0.0
        arrow(ax, (-t, 0.0), (-t, -1.05), RED, lw=2.6)
        ax.text(-t - 0.04, -1.1, '$F_y$', color=RED, fontsize=13, ha='right', va='top')
        if t > 0.1:
            arrow(ax, (-t, 0.33), (0, 0.33), DARK, lw=1.0, style='<|-|>', ms=8)
            ax.text(-t / 2, 0.38, '$t$', ha='center', va='bottom', fontsize=11)
        else:
            ax.text(0.0, 0.42, '$t\\approx0$' if k < 1 else '$t=0$', ha='center', va='bottom', fontsize=11)
    if xs < 1 and xs > -1:
        ax.plot([xs, xs], [0, -0.04 - qz[np.argmin(abs(x - xs))]], color=DARK, lw=1.0, ls=':')
        ax.text((xs + 1) / 2, -1.52, 'adhesion', ha='center', va='center', fontsize=9.5, color=BLUE)
        ax.text((xs - 1) / 2 if xs > -0.6 else -0.5, -1.52, 'sliding', ha='center', va='center', fontsize=9.5, color=RED)
    elif xs >= 1:
        ax.text(0.0, -1.52, 'sliding over the whole patch', ha='center', va='center', fontsize=9.5, color=RED)
    else:
        ax.text(0.0, -1.52, 'adhesion', ha='center', va='center', fontsize=9.5, color=BLUE)
    arrow(ax, (-1.1, 0.78), (1.0, 0.78), '#555555', lw=1.4)
    ax.text(1.03, 0.78, 'travel', fontsize=9, va='center', color='#555555')
    ax.text(-1.0, 0.5, 'trailing', fontsize=8.5, ha='center', va='bottom', color='#555555')
    ax.text(1.0, 0.5, 'leading', fontsize=8.5, ha='center', va='bottom', color='#555555')
    ax.set_xlim(-1.3, 1.45); ax.set_ylim(-1.75, 1.0); ax.axis('off')
    ax.set_title('(%s) $\\tan\\alpha=%.2f\\,\\tan\\alpha_{sl}$' % (name.lower(), k) + '\n' + sub, fontsize=10.5, pad=2)
    ax.text(0.5, -1.72, '$t/t_0=%.2f$,  $F_y/(\\mu F_z)=%.2f$' % (max(t, 0) / (1 / 3), Fy), ha='center', va='top', fontsize=10, transform=ax.transData)

# ---- (d) pneumatic trail and lateral force against the slip
ax = fig.add_subplot(gs[1, :])
ks = np.linspace(0, 1.4, 281)
res = [brush(k) for k in ks]
Fy = np.array([r[2] for r in res]); tt = np.array([r[3] for r in res]) * 3; tt[0] = 1.0
ax.plot(ks, tt, color=RED, lw=2.4, label=r'pneumatic trail $t/t_0$, brush model')
ax.plot(ks, np.maximum(0, 1 - ks), color=RED, lw=1.8, ls='--', label=r'linear law of Eq. (6): $t/t_0=\max(0,\,1-\tan\alpha/\tan\alpha_{sl})$')
ax.plot(ks, Fy, color=BLUE, lw=2.4, label=r'lateral force $F_y/(\mu F_z)$, brush model')
Fmf = []
for k in ks:                                                                                  # Magic Formula with the same initial slope and peak (C=1.3, E=-1)
    C_, E_ = 1.3, -1.0; B_ = 3 * 1.0 / (C_ * 1.0) * 1.0                                          # B C D = C_alpha = 3 mu F_z / tan(alpha_sl) -> B D C = 3 (per unit tan(alpha_sl))
    u = B_ * k; Fmf.append(np.sin(C_ * np.arctan(u - E_ * (u - np.arctan(u)))))
ax.plot(ks, Fmf, color=GREEN, lw=1.8, ls='-.', label='Magic Formula (Eq. (5)), same initial slope and peak')
for name, k, _ in cases:
    ax.axvline(k, color=GREY, lw=0.9, ls=':')
    ax.text(k, 1.07, '(%s)' % name.lower(), ha='center', fontsize=10)
ax.axvline(1.0, color=DARK, lw=1.0, ls='-')
ax.text(1.01, 0.62, r'$k=1$: full sliding', rotation=90, va='center', ha='left', fontsize=9.5)
ax.set_xlim(0, 1.4); ax.set_ylim(0, 1.15)
ax.set_xlabel(r'slip, $k=\tan\alpha\,/\,\tan\alpha_{sl}$ with $\tan\alpha_{sl}=3\mu F_z/C_\alpha$')
ax.grid(alpha=0.25); ax.legend(loc='upper center', fontsize=9.5, frameon=False, ncol=2, bbox_to_anchor=(0.5, -0.22))
ax.set_title('(d) Force and pneumatic trail against slip (normalized)', fontsize=10.5, pad=3)
fig.savefig(OUT, dpi=300, bbox_inches='tight', facecolor='white')
print('wrote', OUT)
