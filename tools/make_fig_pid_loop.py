"""Draw the nonlinear PID loop with separate P, I, and D paths.

Run without arguments to write only draw.io; pass a preview base path for PNG.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOX = dict(rounded=False, fill='#ffffff', fs=22, lw=1.8)


def main():
    d = Diagram(3170, 1410, math=True, font='Times New Roman')
    y = 365

    # Reference and comparator: e_T = T_s,m - T_ref.
    d.block(180, 305, 250, 120, ['Reference', r'$T_{ref}(v_m,a_{y,m})$'], **BOX)
    d.sumj(535, y, r=25, signs={'left': '-', 'bottom': '+'}, fs=24)
    d.line([(430, y), (510, y)], arrow=True)
    d.text(467, 303, r'$T_{ref}$', fs=26)
    d.line([(560, y), (800, y)], arrow=True)
    d.text(615, 331, r'$e_T$', fs=26)
    d.dot(700, y)
    d.line([(700, y), (700, 218), (800, 218)], arrow=True)

    # Three genuinely separate paths. Only P and I receive e_T; D receives
    # measured torque directly. The I block includes the anti-windup state.
    d.frame(650, 125, 800, 540, 'PID controller', fill='none', stroke='#555555', fs=22)
    d.block(800, 170, 310, 95, ['Proportional (P)', r'$u_P=K_p e_T$'], **BOX)
    d.block(800, 305, 310, 120,
            ['Integral (I)', r'$\dot u_I=K_i e_T$', r'$+K_{aw}\Delta T_a$'], **BOX)
    d.block(800, 500, 310, 100,
            ['Derivative (D)', r'$u_D=K_d s/(T_f s+1)\,T_{s,m}$'], **BOX)
    d.sumj(1340, y, r=25,
           signs={'top': '+', 'left': '+', 'bottom': '+'}, fs=24)

    d.line([(1110, 218), (1340, 218), (1340, 340)], arrow=True)
    d.text(1195, 187, r'$u_P$', fs=26)
    d.line([(1110, y), (1315, y)], arrow=True)
    d.text(1195, 331, r'$u_I$', fs=26)
    d.line([(1110, 550), (1340, 550), (1340, 390)], arrow=True)
    d.text(1195, 584, r'$u_D$', fs=26)

    # Saturation and motor are shown as distinct final-control blocks.
    d.frame(1480, 260, 590, 210, 'Final control element',
            fill='none', stroke='#555555', fs=22)
    d.block(1520, 305, 210, 120,
            ['Assist limit', r'$L(T_{a,cmd},v_m)$'], **BOX)
    d.block(1850, 305, 180, 120, ['Motor', r'$G_a(s)$'], **BOX)
    d.line([(1365, y), (1520, y)], arrow=True)
    d.dot(1460, y)
    d.text(1430, 331, r'$T_{a,cmd}$', fs=26)
    d.line([(1730, y), (1850, y)], arrow=True)
    d.dot(1790, y)
    d.text(1790, 331, r'$T_{a,lim}$', fs=26)
    d.line([(2030, y), (2190, y)], arrow=True)
    d.text(2110, 331, r'$T_a$', fs=26)

    # Back-calculation uses the difference after and before the assist limit.
    d.sumj(1370, 750, r=20, signs={'top': '-', 'right': '+'}, fs=22)
    d.line([(1460, y), (1460, 705), (1370, 705), (1370, 730)],
           arrow=True, dashed=True)
    d.line([(1790, y), (1790, 750), (1390, 750)],
           arrow=True, dashed=True)
    d.line([(1350, 750), (1160, 750), (1160, 400), (1110, 400)],
           arrow=True, dashed=True)
    d.text(1245, 716, r'$\Delta T_a$', fs=24)

    # Physical plant: no global linear transfer function is assumed.
    d.block(2190, 265, 320, 200,
            ['Nonlinear C-EPS plant', r'$\dot{x}=f(x,T_a,\theta_1,v,\mu)$',
             r'$T_s=h_T(x,\theta_1)$', r'$a_y=h_y(x,v,\mu)$'], **BOX)
    for x, label in [(2250, r'$\theta_1$'), (2390, r'$v$'), (2470, r'$\mu$')]:
        d.line([(x, 50), (x, 265)], arrow=True)
        d.text(x - 25, 77, label, fs=26)
    d.dot(2390, 110)

    # True outputs leave the plant on the right, then branch to sensors.
    d.line([(2510, 320), (2810, 320)], arrow=True)
    d.text(2580, 285, r'$T_s$', fs=26)
    d.dot(2700, 320)
    d.line([(2700, 320), (2700, 520), (2580, 520),
            (2580, 645), (2600, 645)], arrow=True)
    d.line([(2510, 400), (2740, 400)], arrow=True)
    d.text(2580, 365, r'$a_y$', fs=26)
    d.dot(2540, 400)
    d.line([(2540, 400), (2540, 750), (2520, 750),
            (2520, 825), (2600, 825)], arrow=True)

    d.block(2600, 600, 210, 90, ['Torque sensor', r'$H_T$'], **BOX)
    d.block(2600, 780, 210, 90, ['Lateral-acc. sensor', r'$H_y$'], **BOX)
    d.block(2600, 930, 210, 90, ['Speed sensor', r'$H_v$'], **BOX)
    d.line([(2390, 110), (3100, 110), (3100, 900),
            (2530, 900), (2530, 975), (2600, 975)], arrow=True)

    # Three separate measurement returns. T_s,m also feeds D; v_m also
    # schedules the assist limit. Dots alone denote electrical takeoffs.
    d.line([(2810, 645), (2880, 645), (2880, 1090),
            (535, 1090), (535, 390)], arrow=True)
    d.text(2850, 608, r'$T_{s,m}$', fs=26)
    d.dot(780, 1090)
    d.line([(780, 1090), (780, 550), (800, 550)], arrow=True)

    d.line([(2810, 975), (3050, 975), (3050, 1200),
            (100, 1200), (100, 340), (180, 340)], arrow=True)
    d.text(2860, 938, r'$v_m$', fs=26)
    d.dot(1625, 1200)
    d.line([(1625, 1200), (1625, 425)], arrow=True)

    d.line([(2810, 825), (2970, 825), (2970, 1300),
            (45, 1300), (45, 395), (180, 395)], arrow=True)
    d.text(2860, 788, r'$a_{y,m}$', fs=26)

    path = os.path.join(REPO, 'Figures', 'new', 'Fig_PID_loop.drawio')
    d.save_drawio(path)
    print('written', path)
    if len(sys.argv) > 1:
        d.save_preview(sys.argv[1], scale=1.0, pdf=False)


if __name__ == '__main__':
    main()
