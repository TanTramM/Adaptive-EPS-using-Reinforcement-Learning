# -*- coding: utf-8 -*-
"""Mechanical structure of the column-type EPS drawn with matplotlib (no draw.io), in the style of the advisor's Figure 1(a).

Labels follow the model of the paper: the driver acts on the steering wheel (T_d, theta_1, theta_1 dot), the torsion bar of stiffness K
carries the sensed torque T_s, the assist motor with reduction gear applies T_a to the lower column (theta_2, theta_2 dot; inertia and
damping J_col, C_col; dry friction T_f), the road reaction T_r returns through the pinion (ratio n_st) and the rack from the front lateral
force F_yf at the steered angle delta_f. The steering-wheel inertia is not drawn as a parameter (theta_1 is prescribed).

Writes Figures/v5_Huypt/Figure_1a_column.png
Usage: C:/Users/Admin/anaconda3/python.exe -I tools/make_fig_column.py   (from the repo root)
"""
import os
import numpy as np
import matplotlib
import matplotlib.transforms
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, Rectangle, FancyBboxPatch, Circle, FancyArrowPatch, Polygon

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Figures', 'v5_Huypt', 'Figure_1a_column.png')
plt.rcParams.update({'font.family': 'Times New Roman', 'mathtext.fontset': 'stix', 'font.size': 11})   # journal: Times is allowed

INK = '#222222'
STEEL = '#c9ccd1'
STEEL_D = '#8d9299'
X0 = 50.0                                     # axis of the column


def shaft(ax, y0, y1, w=1.6):
    ax.add_patch(Rectangle((X0 - w / 2, y0), w, y1 - y0, fc=STEEL, ec=INK, lw=0.9, zorder=3))
    ax.add_patch(Rectangle((X0 - w / 2 + 0.25, y0), 0.35, y1 - y0, fc='#f1f2f4', ec='none', zorder=4))   # highlight


def bearing(ax, y, h=6.0, gap=1.4):
    """housing hatch on both sides of the shaft, as in the advisor's drawing"""
    for s in (-1, 1):
        x = X0 + s * gap
        ax.plot([x, x], [y - h / 2, y + h / 2], c=INK, lw=1.4, zorder=5)
        for k in np.linspace(y - h / 2 + 0.4, y + h / 2 - 0.4, 5):
            ax.plot([x, x + s * 1.6], [k, k + 1.2], c=INK, lw=0.9, zorder=5)


def rot_arrow(ax, y, r=5.5, ccw=True, lw=1.2):
    """rotation arrow drawn as a perspective arc under the shaft"""
    a, b = (X0 + r, y), (X0 - r, y)
    if not ccw:
        a, b = b, a
    ax.add_patch(FancyArrowPatch(a, b, connectionstyle='arc3,rad=%.2f' % (-0.35 if ccw else 0.35), arrowstyle='-|>',
                                 mutation_scale=12, lw=lw, color=INK, zorder=6))


def leader(ax, xy_tip, xy_text, text, ha='left', va='bottom', fs=9.5, L=9.0):
    """label on a short horizontal line with a slanted leader, the style of the advisor's figure"""
    xt, yt = xy_text
    x_end = xt + L if ha == 'left' else xt - L
    ax.plot([xt, x_end], [yt, yt], c=INK, lw=0.8, zorder=6)
    near = x_end if abs(x_end - xy_tip[0]) < abs(xt - xy_tip[0]) else xt
    ax.plot([near, xy_tip[0]], [yt, xy_tip[1]], c=INK, lw=0.8, zorder=6)
    ax.text((xt + x_end) / 2, yt + 0.6, text, ha='center', va='bottom', fontsize=fs, zorder=7, linespacing=1.15)


def spring(ax, y0, y1, n=6, w=1.6):
    ys = np.linspace(y0, y1, 2 * n + 1)
    xs = [X0] + [X0 + (w if i % 2 else -w) for i in range(1, 2 * n)] + [X0]
    ax.plot(xs, ys, c=INK, lw=1.4, zorder=5)


def rot(pt, c, ang):
    """rotate point pt about c by ang degrees (counter-clockwise, y up)"""
    a = np.deg2rad(ang)
    dx, dy = pt[0] - c[0], pt[1] - c[1]
    return (c[0] + dx * np.cos(a) - dy * np.sin(a), c[1] + dx * np.sin(a) + dy * np.cos(a))


def tire(ax, xc, yc, ang=0.0, w=6.0, h=19.0):
    """tire seen from the front (as in the advisor's drawing): dark sidewalls with fine ticks, two light tread bands, a dark centre groove"""
    ax.add_patch(FancyBboxPatch((xc - w / 2, yc - h / 2), w, h, boxstyle='round,pad=0,rounding_size=1.4', fc='#3a3d42', ec=INK, lw=1.0, zorder=3))
    for sx in (-1, 1):                                            # light tread bands
        ax.add_patch(Rectangle((xc + sx * 1.35 - 0.65, yc - h / 2 + 0.5), 1.3, h - 1.0, fc='#e3e5e8', ec=INK, lw=0.5, zorder=4))
    ax.plot([xc, xc], [yc - h / 2 + 0.3, yc + h / 2 - 0.3], c=INK, lw=0.9, zorder=5)    # centre groove
    for sx in (-1, 1):                                            # ticks of the sidewalls
        for k in np.linspace(yc - h / 2 + 1.2, yc + h / 2 - 1.2, 22):
            ax.plot([xc + sx * (w / 2 - 0.05), xc + sx * (w / 2 - 0.85)], [k, k], c='#7c828a', lw=0.6, zorder=5)


def main():
    fig, ax = plt.subplots(figsize=(7.0, 7.0))
    ax.set_xlim(-8, 108); ax.set_ylim(0, 112); ax.set_aspect('equal'); ax.axis('off')

    # ---- steering wheel (perspective ring, hub, three spokes)
    yw = 102.0
    shaft(ax, 86, yw)
    ax.add_patch(Ellipse((X0, yw), 28, 7.5, fc='none', ec='#2b2e33', lw=6.5, zorder=8))
    ax.add_patch(Ellipse((X0, yw + 0.3), 28, 7.5, fc='none', ec='#7d838b', lw=1.2, zorder=9))
    for ang in (200, 340, 270):
        t = np.deg2rad(ang)
        ax.plot([X0, X0 + 13.5 * np.cos(t)], [yw, yw + 3.6 * np.sin(t)], c='#2b2e33', lw=3.5, zorder=8, solid_capstyle='round')
    ax.add_patch(Ellipse((X0, yw), 6, 2.6, fc='#55595f', ec=INK, lw=0.9, zorder=9))
    rot_arrow(ax, 97.8, r=6.5)
    leader(ax, (X0 - 6.5, 99.0), (22, 103.5), 'Steering wheel\n$T_d,\\ \\theta_1,\\ \\dot{\\theta}_1$', ha='left', L=14)

    # ---- upper column and torsion bar
    bearing(ax, 89.3, h=5.0)
    ax.text(X0 - 4, 85.6, r'$\theta_1$', ha='right', va='center', fontsize=10.5)
    spring(ax, 76, 85)
    ax.text(X0 - 4, 80.0, r'$K$', ha='right', va='center', fontsize=10.5)
    ax.add_patch(Rectangle((X0 - 2.2, 71.5), 4.4, 4.5, fc='white', ec=INK, lw=1.1, zorder=6))
    ax.text(X0, 73.75, 'T', ha='center', va='center', fontsize=9, zorder=7)
    leader(ax, (X0 + 2.2, 74.5), (61, 77.5), 'Torsion bar\n(torque sensor)\n$T_s$', ha='left', L=16)

    # ---- lower column, motor and reduction gear
    shaft(ax, 31, 71.5)
    yg = 63.0
    ax.add_patch(Ellipse((X0, yg), 8.5, 2.6, fc=STEEL_D, ec=INK, lw=0.9, zorder=6))            # worm wheel on the column
    ax.add_patch(Rectangle((X0 + 3.2, yg - 0.8), 13.5, 1.6, fc=STEEL, ec=INK, lw=0.8, zorder=5))   # worm shaft
    for k in np.linspace(X0 + 5.5, X0 + 11.5, 7):
        ax.plot([k, k + 0.6], [yg - 0.8, yg + 0.8], c=INK, lw=0.7, zorder=6)
    for k in np.linspace(X0 + 6.0, X0 + 12.0, 5):                                                     # gear housing hatch
        ax.plot([k, k + 1.0], [yg + 1.8, yg + 3.0], c=INK, lw=0.8, zorder=5)
        ax.plot([k, k + 1.0], [yg - 3.0, yg - 1.8], c=INK, lw=0.8, zorder=5)
    ax.plot([X0 + 5.5, X0 + 13.5], [yg + 1.8, yg + 1.8], c=INK, lw=1.1); ax.plot([X0 + 5.5, X0 + 13.5], [yg - 1.8, yg - 1.8], c=INK, lw=1.1)
    xm = X0 + 16.5                                                                                     # motor body (shaded cylinder)
    for i, c in enumerate(['#5c6168', '#7b8189', '#9aa0a8', '#b7bcc3', '#cfd3d8', '#b7bcc3', '#9aa0a8', '#7b8189', '#5c6168']):
        ax.add_patch(Rectangle((xm, yg - 4.5 + i), 11, 1.0, fc=c, ec='none', zorder=5))
    ax.add_patch(Rectangle((xm, yg - 4.5), 11, 9, fc='none', ec=INK, lw=1.0, zorder=6))
    for k in np.linspace(xm + 2, xm + 9, 6):
        ax.plot([k, k], [yg - 4.5, yg + 4.5], c='#4a4e54', lw=0.5, zorder=6)
    ax.add_patch(Ellipse((xm + 11, yg), 2.2, 9, fc='#8d9299', ec=INK, lw=1.0, zorder=7))
    ax.add_patch(FancyBboxPatch((xm + 13.5, yg - 3.4), 23.0, 6.8, boxstyle='round,pad=0.3,rounding_size=0.8', fc='white', ec=INK,
                                lw=1.0, zorder=7))
    ax.text(xm + 25.0, yg, 'Assist motor\n+ reduction gear', ha='center', va='center', fontsize=8.5, zorder=8)
    ax.text(X0 + 9.0, yg + 5.6, r'$\theta_2,\ \dot{\theta}_2$', ha='center', va='center', fontsize=10.5)
    rot_arrow(ax, 58.0, r=6.0)
    leader(ax, (X0 - 5.0, 57.0), (24, 61.5), '$T_a$', ha='left', fs=10.5)

    bearing(ax, 50.0)
    leader(ax, (X0 - 3.2, 49.5), (22, 53.5), '$J_{col},\\ C_{col}$', ha='left', fs=10, L=11)
    rot_arrow(ax, 42.5, r=6.0, ccw=False)
    leader(ax, (X0 + 5.0, 41.5), (63, 46.5), 'Dry friction\n$T_f$', ha='left', L=11)
    rot_arrow(ax, 36.0, r=6.0, ccw=False)
    leader(ax, (X0 - 5.0, 35.5), (24, 40.0), '$T_r$', ha='left', fs=10.5)

    # ---- pinion, rack, tie rods, wheels (front view: both wheels upright, as in the advisor's drawing)
    yr = 24.0
    ax.add_patch(Circle((X0, yr + 3.2), 3.6, fc='#e4e6e9', ec=INK, lw=1.1, zorder=7))
    ax.text(X0, yr + 3.2, r'$n_{st}$', ha='center', va='center', fontsize=10, zorder=8)
    ax.add_patch(Rectangle((24, yr - 0.7), 52, 1.4, fc=STEEL, ec=INK, lw=0.9, zorder=5))
    for xa in (31, 61):                                           # rack housings
        for s_ in (1, -1):
            yb = yr + s_ * 1.6
            ax.plot([xa, xa + 8], [yb, yb], c=INK, lw=1.1, zorder=6)
            for k in np.linspace(xa + 0.6, xa + 7.0, 5):
                ax.plot([k, k + 1.0], [yb, yb + s_ * 1.3], c=INK, lw=0.8, zorder=6)
    for s_ in (-1, 1):
        R = (X0 + s_ * 26.0, yr)                                  # ball joint at the rack end
        A = (X0 + s_ * 30.0, yr - 5.5)                            # joint of the knuckle arm
        W = (X0 + s_ * 41.0, yr - 5.5)                            # wheel centre
        ax.plot([R[0], A[0]], [R[1], A[1]], c='#555a60', lw=2.2, zorder=4)           # tie rod
        ax.plot([A[0], W[0] - s_ * 3.0], [A[1], W[1]], c='#555a60', lw=2.2, zorder=4)           # knuckle arm / axle
        ax.add_patch(Circle(R, 1.0, fc='white', ec=INK, lw=1.0, zorder=7))
        ax.add_patch(Circle(A, 1.0, fc='white', ec=INK, lw=1.0, zorder=7))
        tire(ax, W[0], W[1])
    # steered angle (left side), as in the advisor's drawing: vertex at the upper rotating joint R on the long bar; dashed line straight down,
    # arc from the tie rod (ending at the lower joint A) to the dashed line, short arrow pointing at the dashed line
    A = (X0 - 30.0, yr - 5.5)
    R = (X0 - 26.0, yr)
    rr = float(np.hypot(A[0] - R[0], A[1] - R[1]))
    ax.plot([R[0], R[0]], [R[1], A[1] - 8.5], c=INK, lw=0.9, ls=(0, (4, 3)), zorder=9)
    th = np.linspace(np.arctan2(A[1] - R[1], A[0] - R[0]) + 2 * np.pi, 1.5 * np.pi, 30)
    ax.plot(R[0] + rr * np.cos(th), R[1] + rr * np.sin(th), c=INK, lw=1.1, zorder=9)
    ya = A[1] - 6.5
    ax.add_patch(FancyArrowPatch((R[0] + 9.5, ya), (R[0] + 0.6, ya), arrowstyle='-|>', mutation_scale=12, lw=1.3, color=INK, zorder=9))
    ax.text(R[0] + 4.8, ya + 2.6, r'$\delta_f$', ha='center', va='center', fontsize=10.5)
    # lateral force on the front tire, pushing the left tie-rod joint
    ax.add_patch(FancyArrowPatch((R[0] - 12.0, R[1] + 0.3), (R[0] - 1.5, R[1] + 0.3), arrowstyle='-|>', mutation_scale=12, lw=1.3, color=INK, zorder=8))
    ax.text(R[0] - 8.0, R[1] + 3.6, r'$F_{yf}$', ha='center', va='center', fontsize=10.5)
    ax.text(X0 - 41.0, yr + 7.8, 'Tire\n(front left)', ha='center', va='bottom', fontsize=9)
    ax.text(X0 + 41.0, yr + 7.8, 'Tire\n(front right)', ha='center', va='bottom', fontsize=9)

    fig.savefig(OUT, dpi=600, bbox_inches='tight', pad_inches=0.05, facecolor='white')
    plt.close(fig)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
