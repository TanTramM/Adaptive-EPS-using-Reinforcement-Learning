"""Figure for the paper, Section 2.1: forces on the front wheel seen from two views.

(a) top view: steered angle delta_f, velocity direction, slip angle alpha_f, lateral force F_yf, self-aligning moment about the kingpin point Q
(b) side view: contact patch, caster trail e_c, pneumatic trail t_p, effective moment arm e_eff = e_c + t_p

Usage:  python -X utf8 tools/make_fig_tire.py      (writes Figures/Figure_3_tire_forces.png)
The geometry is exaggerated for readability (angles and trails are not to scale).
"""
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle, Arc, FancyArrowPatch

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'Figures', 'Figure_3_tire_forces.png')
BLUE, RED, GREY, GREEN, DARK = '#1f5fa8', '#c0392b', '#9aa3ab', '#2e7d32', '#222222'
plt.rcParams.update({'font.size': 10, 'mathtext.fontset': 'dejavuserif', 'font.family': 'DejaVu Serif'})


def arrow(ax, p, q, color, lw=2.0, style='-|>', ms=14, ls='-', z=5):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle=style, mutation_scale=ms, color=color, lw=lw, linestyle=ls, zorder=z, shrinkA=0, shrinkB=0))


def dim(ax, p, q, text, off, color=DARK, fs=11):
    """dimension line from p to q with arrow ends; the text sits at the middle shifted by off"""
    arrow(ax, p, q, color, lw=1.0, style='<|-|>', ms=8, z=4)
    m = ((p[0] + q[0]) / 2 + off[0], (p[1] + q[1]) / 2 + off[1])
    ax.text(m[0], m[1], text, ha='center', va='center', fontsize=fs, color=color)


fig, (A, B) = plt.subplots(1, 2, figsize=(12.8, 5.8), gridspec_kw={'width_ratios': [1.12, 1]})

# ------------------------------------------------------------------ (a) top view
d, al = np.deg2rad(22), np.deg2rad(13)
h = np.array([np.cos(d), np.sin(d)]); n = np.array([-np.sin(d), np.cos(d)])
C = np.array([0.0, 0.0])
def rect(c, L, W):
    return [c + sx * L / 2 * h + sy * W / 2 * n for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
A.add_patch(Polygon(rect(C, 3.0, 1.0), closed=True, fc='#dfe3e6', ec=DARK, lw=1.4, zorder=2))
A.add_patch(Polygon(rect(C, 1.0, 1.0), closed=True, fc='#8f9aa3', ec=DARK, lw=1.0, hatch='////', zorder=3))
A.plot([-1.6, 6.3], [0, 0], color=GREY, lw=1.2, ls='--', zorder=1)                        # vehicle x axis
A.text(6.35, 0.0, 'vehicle $x$\n(forward)', ha='left', va='center', fontsize=9.5, color='#555555')
A.plot(*zip(C - 2.1 * h, C + 5.9 * h), color=DARK, lw=1.0, ls='-.', zorder=1)             # wheel plane
A.text(*(C + 5.2 * h + 0.25 * n), 'wheel plane', ha='center', va='bottom', fontsize=9.5, rotation=np.rad2deg(d))
vdir = np.array([np.cos(d - al), np.sin(d - al)])
arrow(A, C, C + 4.0 * vdir, BLUE, lw=2.4)
A.text(*(C + 4.0 * vdir + np.array([0.15, -0.3])), r'$v_f$', color=BLUE, fontsize=13, ha='left', va='top')
A.add_patch(Arc(C, 5.0, 5.0, theta1=np.rad2deg(d - al), theta2=np.rad2deg(d), color=BLUE, lw=1.6, zorder=4))
mid = d - al / 2
A.text(*(2.95 * np.array([np.cos(mid), np.sin(mid)]) + np.array([0.0, 0.1])), r'$\alpha_f$', color=BLUE, fontsize=13, ha='left', va='bottom')
A.add_patch(Arc(C, 8.0, 8.0, theta1=0, theta2=np.rad2deg(d), color=GREEN, lw=1.6, zorder=4))
A.text(4.35, 0.62, r'$\delta_f$', color=GREEN, fontsize=13, ha='left', va='center')
ec, t = 1.15, 0.65
K = C + ec * h; P = C - t * h
A.plot(*K, marker='x', ms=11, mew=2.4, color=DARK, zorder=6)
A.text(*(K - 0.62 * n + 0.1 * h), r'$Q$', ha='center', va='top', fontsize=12)
A.plot(*P, marker='o', ms=7, color=RED, zorder=6)
arrow(A, P, P + 2.9 * n, RED, lw=2.6)
A.text(*(P + 2.95 * n + np.array([-0.1, 0.05])), r'$F_{yf}$', color=RED, fontsize=13, ha='right', va='bottom')
A.text(*(P - 0.33 * h), r'$P$', color=RED, fontsize=11.5, ha='center', va='center', bbox=dict(boxstyle='round,pad=0.1', fc='#dfe3e6', ec='none'), zorder=7)
rM = 1.9                                                                                     # self-aligning moment about Q, clockwise, drawn on the +n side
t1, t2 = np.deg2rad(28), np.deg2rad(152)
A.add_patch(Arc(K, 2 * rM, 2 * rM, theta1=np.rad2deg(d + t1), theta2=np.rad2deg(d + t2), color=DARK, lw=1.6, zorder=4))
ang = d + t1
tip = K + rM * np.array([np.cos(ang), np.sin(ang)])
tan = np.array([np.sin(ang), -np.cos(ang)])                                                  # clockwise tangent
arrow(A, tip - 0.3 * tan, tip + 0.02 * tan, DARK, lw=1.6, ms=13, z=6)
A.text(*(K + (rM + 0.35) * n + 0.2 * h), r'$M_z=e_{eff}F_{yf}$ about $Q$', fontsize=11.5, ha='center', va='bottom')
o = -1.25 * n                                                                               # dimension lines beside the wheel
dim(A, C + o, K + o, r'$e_c$', -0.32 * n)
dim(A, P + o, C + o, r'$t_p$', -0.32 * n)
dim(A, P + 2.0 * o, K + 2.0 * o, r'$e_{eff}=e_c+t_p$', -0.34 * n)
for q in (P, C, K):
    A.plot(*zip(q - 0.5 * n if q is not K else q, q + 2.0 * o), color=GREY, lw=0.8, ls=':', zorder=1)
A.set_xlim(-2.8, 8.6); A.set_ylim(-4.3, 4.6); A.set_aspect('equal'); A.axis('off')
A.set_title('(a) Top view: slip angle and lateral force', fontsize=11.5, pad=4)

# ------------------------------------------------------------------ (b) side view (caster plane)
R, tau = 2.3, np.deg2rad(11)
ec2, t2 = 0.65, 0.40
B.plot([-4.2, 4.8], [0, 0], color=DARK, lw=2.0, zorder=2)
B.add_patch(Circle((0, R), R, fc='#eef0f2', ec=DARK, lw=1.8, zorder=1))
B.add_patch(Circle((0, R), 1.45, fc='none', ec=GREY, lw=1.0, zorder=1))
B.add_patch(Circle((0, R), 0.22, fc=DARK, ec=DARK, zorder=3))
Kp = np.array([ec2, 0.0]); top = Kp + 6.0 * np.array([-np.sin(tau), np.cos(tau)])
B.plot(*zip(Kp, top), color=DARK, lw=1.8, ls='-.', zorder=3)
B.text(top[0], top[1] + 0.15, 'kingpin axis', ha='center', va='bottom', fontsize=9.5)
B.plot(*Kp, marker='x', ms=11, mew=2.4, color=DARK, zorder=6)
B.text(Kp[0] + 0.2, 0.3, '$Q$', fontsize=12, ha='left', va='bottom')
B.plot([0], [0], marker='o', ms=6, color=DARK, zorder=6)
B.text(-0.05, 0.3, '$C$', fontsize=12, ha='right', va='bottom')
Pp = np.array([-t2, 0.0])
B.add_patch(Polygon([(-0.95, 0), (0.95, 0), (0.95, -0.17), (-0.95, -0.17)], closed=True, fc='#8f9aa3', ec=DARK, lw=1.0, hatch='////', zorder=2))
B.plot(*Pp, marker='o', ms=12, mfc='white', mec=RED, mew=2.2, zorder=7)
B.plot(*Pp, marker='o', ms=3.5, color=RED, zorder=8)
B.text(Pp[0] - 0.4, 0.3, '$P$', color=RED, fontsize=11.5, ha='right', va='bottom')
B.text(-1.25, -0.75, r'$F_{yf}$ (out of the page)', color=RED, fontsize=10.5, ha='right', va='center')
B.text(0.0, -0.75, 'contact patch', fontsize=9.5, ha='left', va='center', color='#333333')
y0 = -1.9
for q in (Pp, np.array([0, 0]), Kp):
    B.plot([q[0], q[0]], [-1.2, y0 - 0.55], color=GREY, lw=0.8, ls=':', zorder=1)
dim(B, (Pp[0], y0), (0, y0), r'$t_p$', (0, -0.3))
dim(B, (0, y0), (Kp[0], y0), r'$e_c$', (0, -0.3))
dim(B, (Pp[0], y0 - 0.8), (Kp[0], y0 - 0.8), r'$e_{eff}=e_c+t_p$', (0, -0.34))
arrow(B, (2.2, 5.3), (4.0, 5.3), '#555555', lw=1.6)
B.text(4.1, 5.3, 'travel', fontsize=9.5, va='center', color='#555555')
B.text(0.2, -4.7, 'caster angle $\\tau$ (exaggerated): $e_c$ is fixed by the geometry;\n$t_p$ shrinks as $\\alpha_f$ grows and vanishes when the patch slides', fontsize=9.5, va='center', ha='center',
       color='#222222', bbox=dict(boxstyle='round,pad=0.35', fc='white', ec=GREY, lw=0.8))
B.plot([Kp[0], Kp[0]], [0, 3.9], color=GREY, lw=1.0, ls='--', zorder=1)
B.add_patch(Arc(Kp, 7.0, 7.0, theta1=90, theta2=90 + np.rad2deg(tau), color=DARK, lw=1.3, zorder=4))
B.text(Kp[0] - 0.05, 3.85, r'$\tau$', fontsize=11.5, ha='center', va='bottom')
B.set_xlim(-4.4, 5.6); B.set_ylim(-5.4, 6.9); B.set_aspect('equal'); B.axis('off')
B.set_title('(b) Side view: trails and effective moment arm', fontsize=11.5, pad=4)

fig.tight_layout(w_pad=1.0)
fig.savefig(OUT, dpi=300, bbox_inches='tight', facecolor='white')
print('wrote', OUT)
