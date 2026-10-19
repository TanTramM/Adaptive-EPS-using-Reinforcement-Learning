"""Draw the nonlinear Map closed loop in the signal-flow style of Seborg Fig. 11.7.

Run without arguments to write only draw.io; pass a preview base path for PNG.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOX = dict(rounded=False, fill='#ffffff', fs=22, lw=1.8)


def main():
    d = Diagram(2670, 1130, math=True, font='Times New Roman')
    y = 350
    d.block(220, 290, 310, 120, ['Assist map', r'$M(v_m,T_{s,m})$'], **BOX)
    d.block(670, 290, 230, 120, ['Lead-lag', r'$C_{map}(s)$'], **BOX)
    d.frame(1010, 250, 690, 200, 'Final control element', fill='none', stroke='#555555', fs=22)
    d.block(1040, 290, 240, 120, ['Assist limit', r'$L(T_{a,cmd},v_m)$'], **BOX)
    d.block(1460, 290, 200, 120, ['Motor', r'$G_a(s)$'], **BOX)
    d.block(1790, 250, 320, 200,
            ['Nonlinear C-EPS plant', r'$\dot{x}=f(x,T_a,\theta_1,v,\mu)$',
             r'$T_s=h_T(x,\theta_1)$'], **BOX)

    for start, end, x, label in [
        (530, 670, 600, r'$T_{map}$'),
        (900, 1040, 970, r'$T_{a,cmd}$'),
        (1280, 1460, 1370, r'$T_{a,lim}$'),
        (1660, 1790, 1725, r'$T_a$'),
    ]:
        d.line([(start, y), (end, y)], arrow=True)
        d.text(x, 318, label, fs=26)

    for x, label in [(1850, r'$\theta_1$'), (1990, r'$v$'), (2070, r'$\mu$')]:
        d.line([(x, 50), (x, 250)], arrow=True)
        d.text(x - 25, 77, label, fs=26)
    d.dot(1990, 110)

    d.line([(2110, 320), (2400, 320)], arrow=True)
    d.text(2180, 288, r'$T_s$', fs=26)
    d.dot(2290, 320)
    d.line([(2290, 320), (2290, 510), (2090, 510),
            (2090, 630), (2150, 630)], arrow=True)

    d.block(2150, 585, 230, 90, ['Torque sensor', r'$H_T$'], **BOX)
    d.block(2150, 765, 230, 90, ['Speed sensor', r'$H_v$'], **BOX)
    d.line([(1990, 110), (2520, 110), (2520, 725),
            (2090, 725), (2090, 810), (2150, 810)], arrow=True)

    d.line([(2380, 630), (2460, 630), (2460, 950),
            (380, 950), (380, 410)], arrow=True)
    d.text(2420, 593, r'$T_{s,m}$', fs=26)
    d.line([(2380, 810), (2570, 810), (2570, 1050),
            (130, 1050), (130, 325), (220, 325)], arrow=True)
    d.text(2430, 773, r'$v_m$', fs=26)
    d.dot(1150, 1050)
    d.line([(1150, 1050), (1150, 410)], arrow=True)

    path = os.path.join(REPO, 'Figures', 'new', 'Fig_Map_loop.drawio')
    d.save_drawio(path)
    print('written', path)
    if len(sys.argv) > 1:
        d.save_preview(sys.argv[1], scale=1.0, pdf=False)


if __name__ == '__main__':
    main()
