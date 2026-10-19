"""Create the editable internal plant block diagram.

The diagram follows the process-control convention used throughout the paper:
external inputs enter from the left, external outputs leave to the right, and
internal feedback signals leave the source block at its right edge before
returning to the destination block at its left edge.

Usage: python -X utf8 tools/make_fig_plant_internal.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    d = Diagram(1880, 740, math=True, font='Times New Roman')
    box = dict(rounded=False, fill='#ffffff', fs=17, lw=1.8)

    # The dashed boundary separates the nonlinear plant from the controller,
    # actuator, and sensors. All external ports lie on its left or right side.
    d.frame(80, 45, 1720, 650, 'Plant',
            fill='none', stroke='#555555', fs=18, dashed=True)

    # Physical subsystems. Every signal leaves a source block from its right
    # edge, including signals that subsequently return through a feedback path.
    d.block(180, 180, 350, 250,
            ['Steering column',
             r'$\dot{x}_c=f_c(x_c,\theta_1,T_a,T_r)$',
             r'$[\theta_2\;\dot{\theta}_2\;T_s]^T$',
             r'$=h_c(x_c,\theta_1)$'], **box)
    d.block(700, 300, 370, 220,
            ['Tires',
             r'$[F_{yf}\;F_{yr}\;T_r]^T$',
             r'$=f_t(\theta_2,\beta,\gamma,v,\mu)$'], **box)
    d.block(1260, 300, 350, 220,
            ['2-DOF vehicle body',
             r'$[\dot{\beta}\;\dot{\gamma}]^T$',
             r'$=f_b(F_{yf},F_{yr},\beta,\gamma,v)$',
             r'$a_y=(F_{yf}+F_{yr})/m$'], **box)

    # External inputs: all enter through the left plant boundary. Speed is
    # branched to both Tires and the vehicle body.
    d.line([(20, 300), (180, 300)], arrow=True)
    d.text(105, 278, r'$\theta_1$', fs=18)
    d.line([(20, 380), (180, 380)], arrow=True)
    d.text(105, 358, r'$T_a$', fs=18)

    d.line([(20, 85), (620, 85)], arrow=False)
    d.text(45, 65, r'$v$', fs=18)
    d.dot(620, 85)
    d.line([(620, 85), (620, 390), (700, 390)], arrow=True)
    d.line([(620, 85), (1190, 85), (1190, 480), (1260, 480)], arrow=True)

    d.line([(20, 125), (650, 125), (650, 455), (700, 455)], arrow=True)
    d.text(45, 105, r'$\mu$', fs=18)

    # Forward physical path.
    d.line([(530, 330), (700, 330)], arrow=True)
    d.text(615, 307, r'$\theta_2$', fs=18)
    d.line([(1070, 350), (1260, 350)], arrow=True)
    d.text(1165, 327, r'$F_{yf}$', fs=18)
    d.line([(1070, 420), (1260, 420)], arrow=True)
    d.text(1165, 397, r'$F_{yr}$', fs=18)

    # Column outputs bypass the downstream blocks on two clear horizontal
    # lanes. Their terminal arrows are on the right plant boundary.
    d.line([(530, 220), (1840, 220)], arrow=True)
    d.text(1740, 197, r'$T_s$', fs=18)
    d.line([(530, 260), (1840, 260)], arrow=True)
    d.text(1740, 237, r'$\dot{\theta}_2$', fs=18)

    # Vehicle outputs also terminate at the right boundary. The yaw-rate line
    # has a takeoff point for the internal tire-kinematic feedback path.
    d.line([(1610, 350), (1840, 350)], arrow=True)
    d.text(1740, 327, r'$a_y$', fs=18)
    d.line([(1610, 420), (1840, 420)], arrow=True)
    d.dot(1700, 420)
    d.text(1740, 397, r'$\gamma$', fs=18)

    # Internal feedback paths. Each first moves right from its source block,
    # then returns below the forward path and enters the destination on the left.
    d.line([(1070, 480), (1130, 480), (1130, 575),
            (140, 575), (140, 410), (180, 410)], arrow=True)
    d.text(550, 552, r'$T_r$', fs=18)

    d.line([(1610, 480), (1640, 480), (1640, 625),
            (675, 625), (675, 485), (700, 485)], arrow=True)
    d.text(1110, 602, r'$\beta$', fs=18)

    d.line([(1700, 420), (1700, 665),
            (645, 665), (645, 505), (700, 505)], arrow=True)
    d.text(1110, 642, r'$\gamma$', fs=18)

    out = os.path.join(REPO, 'Figures', 'new')
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, 'Fig_Plant_internal.drawio')
    d.save_drawio(path)
    print('written', path)


if __name__ == '__main__':
    main()
