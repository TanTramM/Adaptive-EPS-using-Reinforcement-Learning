"""Minimal control-loop diagram of the assist-map controller (Map) in the notation of Seborg et al., Fig. 11.8: only the symbols G_c, G_v, G_p, G_d, G_m and
the variables D, Y_d, Y_u, Y, Y_m, P, U (plus the vehicle speed v and its measurement v_m); the meaning of every symbol is given in the text of the paper
(Figures/new/Fig_Map_loop_legend.txt), as Seborg does next to Fig. 11.8.  The map has no set point, so there is no first summing junction: the measured
torque Y_m enters G_c directly.  Writes Figures/new/Fig_Map_loop.drawio (raw source, AsciiMath labels, Times New Roman) and .png/.pdf (preview).

Usage: python tools/make_fig_map_loop_min.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    d = Diagram(1500, 580, math=True, font='Times New Roman')
    lab = 20
    box = dict(rounded=False, fill='#ffffff', fs=22, lw=1.8)
    y = 260                                                                   # forward path
    # ---------------------------------------------------------------- forward path: G_c -> P -> G_v -> U -> G_p -> Y_u -> junction -> Y
    d.block(210, y - 40, 130, 80, ['$G_c$'], **box)
    d.block(480, y - 40, 130, 80, ['$G_v$'], **box)
    d.block(750, y - 40, 130, 80, ['$G_p$'], **box)
    d.sumj(1030, y, r=18, signs={'top': '+', 'left': '+'}, mark='x')
    d.line([(340, y), (480, y)], arrow=True);  d.text(410, y - 24, '$P$', fs=lab)
    d.line([(610, y), (750, y)], arrow=True);  d.text(680, y - 24, '$U$', fs=lab)
    d.line([(880, y), (1012, y)], arrow=True); d.text(946, y - 24, '$Y_u$', fs=lab)
    d.line([(1048, y), (1330, y)], arrow=True); d.text(1300, y - 24, '$Y$', fs=lab)
    # ---------------------------------------------------------------- disturbance path (top): driver angle
    d.block(750, 60, 130, 80, ['$G_d$'], **box)
    d.line([(560, 100), (750, 100)], arrow=True); d.text(655, 76, '$D$', fs=lab)
    d.line([(880, 100), (1030, 100), (1030, y - 18)], arrow=True); d.text(1052, 180, '$Y_d$', fs=lab, ha='left')
    # ---------------------------------------------------------------- measurement: the only element of the bottom branch
    d.block(760, 420, 170, 80, ['$G_m$'], **box)
    d.dot(1150, y)
    d.line([(1150, y), (1150, 460), (930, 460)], arrow=True)
    d.line([(845, 560), (845, 500)], arrow=True); d.text(865, 540, '$v$', fs=lab, ha='left')
    d.line([(760, 485), (60, 485), (60, y), (210, y)], arrow=True); d.text(410, 509, '$Y_m$', fs=lab)
    d.line([(760, 440), (275, 440), (275, y + 40)], arrow=True); d.text(520, 416, '$v_m$', fs=lab)
    out = os.path.join(REPO, 'Figures', 'new')
    os.makedirs(out, exist_ok=True)
    d.save(os.path.join(out, 'Fig_Map_loop'))
    print('written', out)


if __name__ == '__main__':
    main()
