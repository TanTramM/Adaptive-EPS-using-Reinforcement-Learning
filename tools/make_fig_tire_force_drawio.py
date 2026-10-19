"""Editable draw.io top-view diagram of the front-tire force geometry.

The figure intentionally omits caster trail, pneumatic trail, and the effective
moment arm. It only defines the quantities needed for the front slip angle and
lateral tire force in the road plane.

Usage: python -X utf8 tools/make_fig_tire_force_drawio.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK = '#222222'
GREY = '#777777'


def point_add(p, a, u, b=0.0, v=(0.0, 0.0)):
    return p[0] + a*u[0] + b*v[0], p[1] + a*u[1] + b*v[1]


def arc_points(c, radius, a0, a1, count=18):
    return [(c[0] + radius*math.cos(a0 + (a1-a0)*i/count),
             c[1] - radius*math.sin(a0 + (a1-a0)*i/count))
            for i in range(count + 1)]


def main():
    d = Diagram(1120, 650, math=True, font='Times New Roman')
    c = (390.0, 355.0)
    delta = math.radians(24.0)
    alpha = math.radians(12.0)

    # Coordinates use y downward. h follows the wheel plane; n is its lateral
    # direction in the road plane.
    h = (math.cos(delta), -math.sin(delta))
    n = (math.sin(delta), math.cos(delta))
    velocity_angle = delta - alpha
    q = (math.cos(velocity_angle), -math.sin(velocity_angle))

    # Vehicle longitudinal axis and wheel plane.
    d.line([(70, c[1]), (1030, c[1])], arrow=True, dashed=True,
           lw=1.3, color=GREY)
    d.text(1010, c[1] - 25, 'vehicle $x$ direction', fs=16, ha='right', color=GREY)
    d.line([point_add(c, -230, h), point_add(c, 470, h)],
           arrow=False, dashed=True, lw=1.3, color=GREY)
    d.text(790, 155, 'wheel plane', fs=16, color=GREY)

    # Front tire and its contact-patch hatching.
    half_l, half_w = 155.0, 52.0
    corners = [point_add(c, -half_l, h, -half_w, n),
               point_add(c,  half_l, h, -half_w, n),
               point_add(c,  half_l, h,  half_w, n),
               point_add(c, -half_l, h,  half_w, n)]
    d.poly(corners + [corners[0]], lw=2.0, color=INK)
    for s in (-100, -60, -20, 20, 60, 100):
        d.poly([point_add(c, s, h, -half_w, n),
                point_add(c, s, h, half_w, n)], lw=1.0, color=GREY)
    d.text(370, 535, 'front tire (top view)', fs=16, color=GREY)

    # Local velocity direction and the lateral tire force.
    d.line([c, point_add(c, 360, q)], arrow=True, lw=2.2)
    d.text(735, 250, r'$v_f$', fs=20)
    d.line([c, point_add(c, 235, n)], arrow=True, lw=2.4)
    fy_tip = point_add(c, 235, n)
    d.text(fy_tip[0] + 18, fy_tip[1], r'$F_{yf}(\alpha_f,\mu)$', fs=20, ha='left')
    d.dot(c[0], c[1], r=4)

    # Steering and slip angles. Curves are polylines so they remain editable in
    # draw.io without relying on a renderer-specific arc primitive.
    delta_arc = arc_points(c, 205, 0.0, delta)
    d.line(delta_arc, arrow=True, lw=1.6)
    d.text(565, 330, r'$\delta_f$', fs=20)
    alpha_arc = arc_points(c, 275, velocity_angle, delta)
    d.line(alpha_arc, arrow=True, lw=1.6)
    d.text(640, 218, r'$\alpha_f$', fs=20)

    d.text(70, 600,
           'Angles and geometry are schematic and not to scale.',
           fs=15, ha='left', italic=True, color=GREY)

    out = os.path.join(REPO, 'Figures', 'new')
    os.makedirs(out, exist_ok=True)
    d.save(os.path.join(out, 'Fig_Tire_force'), scale=3.0)
    print('written', out)


if __name__ == '__main__':
    main()
