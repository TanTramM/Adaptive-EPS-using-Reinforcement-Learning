"""Figures drawn as editable draw.io files (raw sources in Figures/drawio/*.drawio) with a PNG/PDF preview from the same description.

  Fig2_control   control block diagrams: (a) assist map with lead-lag, (b) PI/PID torque feedback with anti-windup (control-theory notation:
                 summing junctions with signs, transfer functions, saturation, motor, plant, sensors in the feedback path)
  Fig1b_plant    block diagram of the plant, equation by equation (Eqs. (1)-(14) of the paper)
  Fig1a_mechanism  schematic of the column-type EPS (mechanical structure)

Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig_drawio.py [fig2|fig1b|fig1a ...]   (from the repo root)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'Figures', 'drawio')
BLUE, ORANGE, GREEN, YELLOW, GREY = '#dce8f8', '#fbe3d6', '#d9ead3', '#fdefc3', '#f2f2f2'


def fig2():
    d = Diagram(1500, 1050)
    # ---------------------------------------------------------------- (a) assist map
    d.text(20, 24, '(a) Conventional assist-map control', fs=20, ha='left', bold=True)
    y = 190
    d.block(60, y - 45, 200, 90, ['Assist map', '$M(v, T_s)$'], fill=BLUE, bold_first=True)
    d.block(330, y - 45, 200, 90, ['Lead\u2013lag', '$C_{map}(s)$'], fill=BLUE, bold_first=True)
    d.block(600, y - 45, 180, 90, ['Saturation', r'$\pm T_{a,max}(v)$'], fill='#ffffff', bold_first=True)
    d.block(850, y - 45, 200, 90, ['Motor', r'$G_m(s)$, 1 ms delay'], fill='#ffffff', bold_first=True)
    d.block(1130, 110, 320, 160, ['C-EPS\u2013vehicle plant', 'column, tires, body', 'Eqs. (1)\u2013(14)'], fill=GREEN, bold_first=True)
    for (x0, x1, lab, xt) in ((260, 330, r'$T_{a,map}$', 295), (530, 600, r'$T_{a,cmd}$', 565), (780, 850, r'$T_{a,lim}$', 815), (1050, 1130, r'$T_a$', 1090)):
        d.line([(x0, y), (x1, y)], arrow=True)
        d.text(xt, y - 24, lab, fs=17)
    for xx, lab in ((1210, r'$\theta_1$'), (1290, r'$\mu$'), (1380, r'$v$')):
        d.line([(xx, 45), (xx, 110)], arrow=True)
        d.text(xx + 18, 62, lab, fs=17, ha='left')
    d.text(1290, 32, 'driver angle, friction (unmeasured), speed', fs=14, italic=True, color='#555555')
    d.block(1130, 360, 320, 70, ['Sensors', 'noise, quantization, update period'], fill=YELLOW, bold_first=True, fs=15)
    d.line([(1290, 270), (1290, 360)], arrow=True)
    d.text(1306, 315, r'true $T_s,\ \dot{\theta}_2,\ \gamma,\ a_y$', fs=15, ha='left')
    d.line([(1130, 395), (160, 395), (160, y + 45)], arrow=True, lw=3.2)
    d.text(640, 418, r'measured $T_s,\ v$', fs=16)
    d.dot(690, 395); d.line([(690, 395), (690, y + 45)], arrow=True)
    d.text(706, 345, r'$v$', fs=16, ha='left')
    # ---------------------------------------------------------------- (b) PI / PID
    d.text(20, 470, '(b) Lateral-acceleration-based torque feedback (PI / PID)', fs=20, ha='left', bold=True)
    y = 700
    d.block(40, y - 45, 190, 90, ['Reference', r'$T_{ref}(v, a_y)$'], fill=ORANGE, bold_first=True)
    d.sumj(300, y, r=17, signs={'left': '+', 'bottom': '-'})
    d.line([(230, y), (283, y)], arrow=True)
    d.frame(370, 505, 440, 400, 'PI / PID controller', fill='#fafafa')
    d.line([(317, y), (440, y)], arrow=True)
    d.text(345, y - 20, r'$e_T$', fs=17)
    d.dot(395, y)
    # integral path
    d.block(440, y - 28, 80, 56, ['$K_i$'], fill=ORANGE)
    d.line([(395, y), (440, y)])
    d.sumj(575, y, r=15, signs={'left': '+', 'top': '+'})
    d.line([(520, y), (560, y)], arrow=True)
    d.block(620, y - 28, 80, 56, [r'$1/s$'], fill=ORANGE)
    d.line([(590, y), (620, y)], arrow=True)
    # proportional path (below) and derivative path (bottom)
    d.line([(395, y), (395, 775)])
    d.block(440, 750, 100, 50, ['$K_p$'], fill=ORANGE)
    d.line([(395, 775), (440, 775)], arrow=True)
    d.sumj(740, y, r=17, signs={'left': '+', 'bottomleft': '+', 'bottomright': '+'})
    d.line([(700, y), (723, y)], arrow=True)
    d.line([(540, 775), (726, 775), (726, y + 17)], arrow=True)
    d.block(440, 830, 210, 56, [r'$K_d s/(\tau_d s + 1)$'], fill=ORANGE, fs=15)
    d.text(545, 812, 'derivative of the measured $T_s$', fs=13, italic=True, color='#555555')
    d.line([(650, 858), (754, 858), (754, y + 17)], arrow=True)
    # anti-windup
    d.sumj(880, 545, r=14, signs={'right': '+', 'bottom': '-'})
    d.block(660, 520, 120, 50, [r'$K_{aw}$'], fill=ORANGE)
    d.line([(866, 545), (780, 545)], arrow=True)
    d.line([(660, 545), (575, 545), (575, y - 15)], arrow=True, dashed=True)
    d.text(590, 620, 'anti-windup', fs=13, italic=True, color='#555555', ha='left')
    # controller output, saturation, motor, plant
    d.line([(757, y), (860, y)], arrow=True)
    d.text(787, y - 22, r'$T_{a,cmd}$', fs=16)
    d.dot(830, y); d.line([(830, y), (830, 610), (880, 610), (880, 559)], arrow=True)
    d.block(860, y - 45, 140, 90, ['Saturation', r'$\pm T_{a,max}$'], fill='#ffffff', bold_first=True, fs=15)
    d.line([(1000, y), (1075, y)], arrow=True)
    d.dot(1020, y); d.line([(1020, y), (1020, 545), (894, 545)], arrow=True, dashed=True)
    d.text(1045, y + 24, r'$T_{a,lim}$', fs=15)
    d.block(1075, y - 45, 135, 90, ['Motor', r'$G_m(s)$, 1 ms'], fill='#ffffff', bold_first=True, fs=15)
    d.line([(1210, y), (1250, y)], arrow=True)
    d.text(1230, y - 22, r'$T_a$', fs=16)
    d.block(1250, 625, 220, 150, ['C-EPS\u2013vehicle', 'plant', 'Eqs. (1)\u2013(14)'], fill=GREEN, bold_first=True)
    for xx, lab in ((1290, r'$\theta_1$'), (1360, r'$\mu$'), (1430, r'$v$')):
        d.line([(xx, 570), (xx, 625)], arrow=True)
        d.text(xx + 14, 586, lab, fs=16, ha='left')
    d.block(1250, 880, 220, 70, ['Sensors', 'noise, quantization'], fill=YELLOW, bold_first=True, fs=15)
    d.line([(1360, 775), (1360, 880)], arrow=True)
    d.text(1376, 828, 'true signals', fs=14, ha='left')
    # measurement bus
    yb = 995
    d.line([(1250, 915), (1215, 915), (1215, yb), (135, yb), (135, y + 45)], arrow=True, lw=3.2)
    d.text(640, yb + 18, r'measured $T_s,\ v,\ a_y$', fs=16)
    d.dot(300, yb); d.line([(300, yb), (300, y + 17)], arrow=True)
    d.dot(345, yb); d.line([(345, yb), (345, 858), (440, 858)], arrow=True)
    d.dot(930, yb); d.line([(930, yb), (930, y + 45)], arrow=True)
    d.text(944, 800, r'$v$', fs=15, ha='left')
    d.save(os.path.join(OUT, 'Fig2_control'))


def fig1b():
    d = Diagram(1500, 1180)

    def stub(x0, y0, x1, y1, label, lx, ly, ha='center'):
        d.line([(x0, y0), (x1, y1)], arrow=True, lw=1.6)
        d.text(lx, ly, label, fs=15, ha=ha)
    # ================================================================= lane 1: steering column, Eqs. (1)-(2)
    d.frame(100, 60, 1340, 340, 'Steering column  –  Eqs. (1)–(2)', fill='#f5f9fe')
    y = 210
    d.line([(20, y), (213, y)], arrow=True); d.text(60, y - 22, r'$\theta_1$', fs=18)
    d.sumj(230, y, r=17, signs={'left': '+', 'bottom': '-'})
    d.block(300, y - 25, 80, 50, ['$K$'], fill=BLUE)
    d.line([(247, y), (300, y)], arrow=True)
    d.text(340, y - 42, 'Eq. (2)', fs=13, italic=True, color='#555555')
    d.line([(380, y), (478, y)], arrow=True)
    d.dot(420, y); d.line([(420, y), (420, 35)], arrow=True); d.text(440, 45, r'$T_s$', fs=18, ha='left')
    d.sumj(500, y, r=22, signs={'left': '+', 'top': '+', 'bottomleft': '-', 'bottom': '-', 'bottomright': '-'})
    d.line([(500, 10), (500, y - 22)], arrow=True); d.text(520, 30, r'$T_a$', fs=18, ha='left')
    d.block(590, y - 25, 100, 50, [r'$1/J_{col}$'], fill=BLUE)
    d.line([(522, y), (590, y)], arrow=True)
    d.block(750, y - 25, 60, 50, [r'$1/s$'], fill=BLUE)
    d.line([(690, y), (750, y)], arrow=True); d.text(720, y - 22, r'$\ddot{\theta}_2$', fs=17)
    d.block(890, y - 25, 60, 50, [r'$1/s$'], fill=BLUE)
    d.line([(810, y), (890, y)], arrow=True); d.text(830, y - 22, r'$\dot{\theta}_2$', fs=17)
    d.dot(850, y); d.line([(850, y), (850, 35)], arrow=True); d.text(868, 45, r'$\dot{\theta}_2$', fs=18, ha='left')
    d.line([(950, y), (1000, y)]); d.dot(1000, y); d.text(975, y - 22, r'$\theta_2$', fs=17)
    d.text(640, y - 42, 'Eq. (1)', fs=13, italic=True, color='#555555')
    # damping and dry friction in the feedback path
    d.block(700, 255, 100, 40, [r'$C_{col}$'], fill=BLUE)
    d.block(670, 315, 160, 40, [r'$T_f \tanh(c\,\dot{\theta}_2)$'], fill=BLUE, fs=15)
    d.line([(850, y), (850, 335), (830, 335)], arrow=True); d.dot(850, 275); d.line([(850, 275), (800, 275)], arrow=True)
    d.line([(700, 275), (514, 275), (514, y + 17)], arrow=True)
    d.line([(670, 335), (500, 335), (500, y + 22)], arrow=True)
    # theta_2 back to the torsion bar junction
    d.line([(1000, y), (1000, 380), (230, 380), (230, y + 17)], arrow=True)
    # ================================================================= lane 2: tires, Eqs. (3)-(11)
    d.frame(100, 430, 1340, 370, 'Tires  –  Eqs. (3)–(11)', fill='#f5fbf5')
    d.line([(1000, y), (1360, y), (1360, 500), (1330, 500)], arrow=True)
    d.text(1330, y - 22, r'$\theta_2$', fs=17)
    d.block(1250, 475, 80, 50, [r'$1/n_{st}$'], fill=GREEN)
    d.line([(1250, 500), (1188, 500)], arrow=True)
    d.sumj(1170, 500, r=18, signs={'right': '+', 'top': '-', 'bottom': '-'})
    d.line([(1152, 500), (1090, 500)]); d.dot(1090, 500); d.text(1120, 478, r'$\alpha_f$', fs=17)
    d.block(930, 470, 120, 60, ['Tire force', r'$F_{yf}(\alpha_f,\mu)$'], fill=GREEN, fs=14, bold_first=True)
    d.line([(1090, 500), (1050, 500)], arrow=True)
    stub(990, 452, 990, 470, r'$\mu$', 1004, 450, ha='left')
    d.line([(930, 500), (860, 500)]); d.dot(860, 500); d.text(895, 478, r'$F_{yf}$', fs=17)
    d.line([(1090, 500), (1090, 610), (1050, 610)], arrow=True)
    d.block(930, 580, 120, 60, ['Pneumatic trail', r'$e_p(\alpha_f,\mu)$'], fill=GREEN, fs=14, bold_first=True)
    stub(990, 668, 990, 640, r'$\mu$', 1004, 660, ha='left')
    d.line([(930, 610), (780, 610), (780, 571)], arrow=True); d.text(880, 588, r'$e_p$', fs=17)
    d.line([(860, 500), (780, 500), (780, 539)], arrow=True)
    d.sumj(780, 555, r=16, mark='x')
    d.line([(764, 555), (720, 555)], arrow=True)
    d.block(620, 530, 100, 50, [r'$1/n_{st}$'], fill=GREEN)
    d.line([(620, 555), (486, 555), (486, y + 20)], arrow=True); d.text(560, 533, r'$T_r$', fs=18)
    # slip-angle junction inputs
    d.line([(1370, 900), (1370, 455), (1170, 455), (1170, 482)], arrow=True)
    d.dot(1230, 455); d.text(1330, 437, r'$\beta$', fs=17)
    d.block(1130, 545, 80, 40, [r'$l_f/v$'], fill=GREEN)
    d.line([(1170, 545), (1170, 518)], arrow=True)
    d.line([(1400, 1040), (1400, 665), (1210, 665)], arrow=True)
    d.dot(1300, 665); d.line([(1300, 665), (1300, 565), (1210, 565)], arrow=True)
    stub(1085, 565, 1130, 565, r'$v$', 1105, 543)
    d.text(1385, 688, r'$\gamma$', fs=17, ha='left')
    # rear tire
    d.sumj(1170, 720, r=18, signs={'right': '-', 'top': '+'})
    d.block(1130, 645, 80, 40, [r'$l_r/v$'], fill=GREEN)
    d.line([(1170, 685), (1170, 702)], arrow=True)
    stub(1085, 665, 1130, 665, r'$v$', 1105, 643)
    d.line([(1230, 455), (1230, 720), (1188, 720)], arrow=True)
    d.line([(1152, 720), (1090, 720)]); d.dot(1090, 720); d.text(1120, 698, r'$\alpha_r$', fs=17)
    d.block(930, 690, 120, 60, ['Tire force', r'$F_{yr}(\alpha_r,\mu)$'], fill=GREEN, fs=14, bold_first=True)
    d.line([(1090, 720), (1050, 720)], arrow=True)
    stub(990, 772, 990, 750, r'$\mu$', 1004, 764, ha='left')
    d.line([(930, 720), (900, 720)]); d.dot(900, 720); d.text(880, 772, r'$F_{yr}$', fs=15)
    # ================================================================= lane 3: vehicle body, Eqs. (12)-(14)
    d.frame(100, 830, 1340, 320, 'Vehicle body  –  Eqs. (12)–(14)', fill='#fffaf0')
    d.line([(860, 500), (860, 900), (882, 900)], arrow=True)
    d.line([(900, 720), (900, 882)], arrow=True)
    d.sumj(900, 900, r=17, signs={'left': '+', 'top': '+'})
    d.line([(917, 900), (960, 900)], arrow=True)
    d.block(960, 875, 70, 50, [r'$1/m$'], fill=YELLOW)
    d.line([(1030, 900), (1080, 900)]); d.dot(1060, 900)
    d.text(1045, 878, r'$a_y$', fs=17)
    d.line([(1060, 900), (1060, 850), (1470, 850)], arrow=True); d.text(1440, 828, r'$a_y$', fs=18, ha='right')
    d.line([(1080, 900), (1110, 900)], arrow=True)
    d.block(1110, 875, 70, 50, [r'$1/v$'], fill=YELLOW)
    stub(1145, 960, 1145, 925, r'$v$', 1160, 948, ha='left')
    d.line([(1180, 900), (1213, 900)], arrow=True)
    d.sumj(1230, 900, r=17, signs={'left': '+', 'bottom': '-'})
    d.line([(1400, 960), (1230, 960), (1230, 917)], arrow=True); d.dot(1400, 960)
    d.line([(1247, 900), (1280, 900)], arrow=True); d.text(1262, 878, r'$\dot{\beta}$', fs=16)
    d.block(1280, 875, 60, 50, [r'$1/s$'], fill=YELLOW)
    d.line([(1340, 900), (1370, 900)]); d.dot(1370, 900)
    # yaw
    d.line([(860, 900), (860, 1010), (950, 1010)], arrow=True)
    d.line([(900, 720), (900, 1075)])
    d.block(950, 985, 80, 50, [r'$l_f$'], fill=YELLOW)
    d.block(950, 1050, 80, 50, [r'$l_r$'], fill=YELLOW)
    d.line([(900, 1075), (950, 1075)], arrow=True)
    d.line([(1030, 1010), (1110, 1010), (1110, 1024)], arrow=True)
    d.line([(1030, 1075), (1110, 1075), (1110, 1056)], arrow=True)
    d.sumj(1110, 1040, r=16, signs={'top': '+', 'bottom': '-'})
    d.line([(1126, 1040), (1170, 1040)], arrow=True)
    d.block(1170, 1015, 80, 50, [r'$1/I_z$'], fill=YELLOW)
    d.line([(1250, 1040), (1290, 1040)], arrow=True); d.text(1270, 1018, r'$\dot{\gamma}$', fs=16)
    d.block(1290, 1015, 60, 50, [r'$1/s$'], fill=YELLOW)
    d.line([(1350, 1040), (1400, 1040)]); d.dot(1400, 1040)
    d.line([(1400, 1040), (1470, 1040)], arrow=True); d.text(1440, 1018, r'$\gamma$', fs=18, ha='right')
    d.save(os.path.join(OUT, 'Fig1b_plant'))




def fig1a():
    """VERTICAL schematic of the column-type EPS (as in the first version): steering wheel at the top, upper column, torsion bar with the torque/angle
    sensor, lower column with the worm-gear reduction and the assist motor, universal joint, pinion and rack, tie rods, front wheels (front view)."""
    import math
    d = Diagram(1020, 1100)
    ax = 500                                       # axis of the column
    GR, DG = '#d9d9d9', '#9a9a9a'

    def hatch_v(x, y0, y1, side, n=5):
        step = (y1 - y0) / n
        for i in range(n):
            ya = y0 + i * step
            d.poly([(x, ya), (x + side * 12, ya + step * 0.6)], lw=1.4)

    def hatch_h(x0, x1, y, up, n=5):
        step = (x1 - x0) / n
        for i in range(n):
            xa = x0 + i * step
            d.poly([(xa, y), (xa + step * 0.6, y + (-12 if up else 12))], lw=1.4)

    def bearing(y):
        d.block(ax - 34, y - 22, 20, 44, [''], fill=GR, rounded=False, lw=1.6)
        d.block(ax + 14, y - 22, 20, 44, [''], fill=GR, rounded=False, lw=1.6)
        hatch_v(ax - 34, y - 22, y + 22, -1, 4)
        hatch_v(ax + 34, y - 22, y + 22, 1, 4)

    def rot_arrow(y, ccw=True, r=44):
        pts = [(ax + r * math.cos(math.radians(a)), y + 12 * math.sin(math.radians(a))) for a in range(0, 181, 15)]
        pts = pts if ccw else pts[::-1]
        d.line(pts, arrow=True, lw=1.8)

    def zig(y0, y1, n=7, w=14):
        pts = [(ax, y0)]
        for i in range(1, 2 * n):
            pts.append((ax + (w if i % 2 else -w), y0 + (y1 - y0) * i / (2 * n)))
        pts.append((ax, y1))
        d.poly(pts, lw=2.4)

    # ---- steering wheel (perspective ring, hub, spokes) and rotation arrow
    d.ellipse(ax - 120, 36, 240, 76, fill='#3a3a3a')
    d.ellipse(ax - 108, 44, 216, 60, fill='#ffffff')
    d.poly([(ax - 104, 74), (ax - 14, 78)], lw=6, color='#3a3a3a'); d.poly([(ax + 14, 78), (ax + 104, 74)], lw=6, color='#3a3a3a')
    d.poly([(ax, 78), (ax, 104)], lw=6, color='#3a3a3a')
    d.ellipse(ax - 26, 62, 52, 28, fill=DG)
    rot_arrow(132, ccw=True, r=58)
    d.text(ax - 150, 40, 'Steering wheel', fs=16, bold=True, ha='right')
    d.text(ax - 150, 66, r'$T_d,\ \theta_1,\ \dot{\theta}_1$', fs=16, ha='right')
    d.line([(ax - 146, 55), (ax - 118, 70)], lw=1.2)
    # ---- upper column
    d.block(ax - 7, 106, 14, 276, [''], fill=GR, rounded=False, lw=1.6)
    bearing(190); bearing(300)
    d.text(ax - 62, 245, r'$\theta_1$', fs=17, ha='right')
    d.text(ax - 62, 270, 'upper column', fs=14, ha='right', italic=True, color='#555555')
    # ---- torsion bar
    d.block(ax - 18, 380, 36, 10, [''], fill=DG, rounded=False, lw=1.4)
    zig(390, 450)
    d.block(ax - 18, 450, 36, 10, [''], fill=DG, rounded=False, lw=1.4)
    d.text(ax - 62, 420, r'$K$', fs=18, ha='right')
    d.text(ax - 62, 446, 'torsion bar', fs=14, ha='right', italic=True, color='#555555')
    # ---- torque / angle sensor on the bar
    d.block(ax - 20, 468, 40, 34, ['T'], fill='#ffffff', rounded=False, fs=15)
    d.block(ax + 90, 446, 160, 56, ['Torque / angle', 'sensor'], fill=ORANGE, fs=14, bold_first=True)
    d.line([(ax + 20, 485), (ax + 90, 485)], dotted=True, lw=1.6)
    d.text(ax + 170, 520, r'$T_s = K(\theta_1 - \theta_2)$', fs=15, color='#555555')
    # ---- ECU and its signals
    d.block(ax + 310, 446, 150, 56, ['ECU', 'control law'], fill=BLUE, fs=14, bold_first=True)
    d.line([(ax + 250, 474), (ax + 310, 474)], arrow=True, lw=1.8)
    d.text(ax + 280, 454, r'$T_s,\ \theta_1$', fs=14)
    d.line([(ax + 385, 370), (ax + 385, 446)], arrow=True, lw=1.8)
    d.text(ax + 400, 392, r'$v,\ a_y$', fs=15, ha='left')
    d.text(ax + 400, 412, '(vehicle bus)', fs=13, ha='left', italic=True, color='#555555')
    # ---- motor and worm gear on the lower column
    d.block(ax + 310, 566, 150, 70, ['Assist motor', r'$T_a$'], fill=GREEN, fs=14, bold_first=True)
    d.line([(ax + 385, 502), (ax + 385, 566)], arrow=True, lw=1.8)
    d.text(ax + 400, 534, r'$T_{a,cmd}$', fs=15, ha='left')
    d.block(ax + 40, 594, 270, 12, [''], fill=GR, rounded=False, lw=1.4)             # worm shaft
    for k in range(10):
        d.poly([(ax + 60 + 24 * k, 594), (ax + 74 + 24 * k, 606)], lw=1.2)
    d.frame(ax + 30, 560, 290, 80, None, fill='none')
    d.text(ax + 175, 658, 'reduction gear (worm)', fs=13, italic=True, color='#555555')
    d.ellipse(ax - 38, 580, 76, 40, fill=DG)
    # ---- lower column
    d.block(ax - 7, 502, 14, 250, [''], fill=GR, rounded=False, lw=1.6)
    bearing(682)
    d.text(ax - 62, 560, r'$\theta_2,\ \dot{\theta}_2$', fs=17, ha='right')
    d.text(ax - 62, 586, 'lower column', fs=14, ha='right', italic=True, color='#555555')
    rot_arrow(634, ccw=True, r=50)
    d.text(ax - 62, 640, r'$T_a$', fs=17, ha='right')
    d.text(ax - 62, 690, r'$J_{col},\ C_{col}$', fs=15, ha='right')
    d.text(ax + 62, 700, 'dry friction $T_f$', fs=15, ha='left')
    d.line([(ax + 58, 700), (ax + 36, 690)], lw=1.2)
    # ---- universal joint
    d.ellipse(ax - 20, 750, 40, 40, fill='#ffffff')
    d.poly([(ax - 10, 760), (ax + 10, 780)], lw=1.8); d.poly([(ax - 10, 780), (ax + 10, 760)], lw=1.8)
    d.text(ax + 34, 770, 'universal joint', fs=13, italic=True, color='#555555', ha='left')
    d.block(ax - 7, 790, 14, 28, [''], fill=GR, rounded=False, lw=1.6)
    # ---- pinion and rack
    py = 850
    rx0, rx1 = ax - 270, ax + 270
    d.block(rx0, py - 8, rx1 - rx0, 16, [''], fill=GR, rounded=False, lw=1.6)
    for k in range(8):
        d.poly([(ax - 56 + 14 * k, py - 8), (ax - 56 + 14 * k, py - 16)], lw=1.4)
    d.ellipse(ax - 34, py - 34, 68, 68, fill=DG)
    for k in range(12):
        a = 2 * math.pi * k / 12
        d.poly([(ax + 34 * math.cos(a), py + 34 * math.sin(a)), (ax + 41 * math.cos(a), py + 41 * math.sin(a))], lw=1.6)
    d.text(ax, py - 2, r'$n_{st}$', fs=16)
    d.text(ax + 60, py - 56, 'pinion and rack', fs=14, ha='left', italic=True, color='#555555')
    for sgn in (-1, 1):                              # rack housings
        xh = ax + sgn * 175
        d.block(xh - 28, py - 26, 56, 18, [''], fill=GR, rounded=False, lw=1.4)
        d.block(xh - 28, py + 8, 56, 18, [''], fill=GR, rounded=False, lw=1.4)
        hatch_h(xh - 30, xh + 30, py - 26, True, 5); hatch_h(xh - 30, xh + 30, py + 26, False, 5)
    # ---- tie rods and wheels (front view)
    for sgn in (-1, 1):
        R = (ax + sgn * 270, py)                     # upper rotating joint at the rack end
        A = (ax + sgn * 312, py + 56)                # knuckle joint
        Wx = ax + sgn * 392                          # wheel centre line
        d.line([R, A], lw=3.0, color='#555a60')
        d.line([A, (Wx - sgn * 22, A[1])], lw=3.0, color='#555a60')
        d.block(Wx - 24, py + 18, 48, 150, [''], fill='#3a3d42', rounded=True, lw=1.6)
        d.block(Wx - 15, py + 26, 12, 134, [''], fill='#e3e5e8', rounded=False, lw=0.8)
        d.block(Wx + 3, py + 26, 12, 134, [''], fill='#e3e5e8', rounded=False, lw=0.8)
        d.line([(Wx, py + 26), (Wx, py + 160)], lw=1.4)
        d.ellipse(R[0] - 7, R[1] - 7, 14, 14, fill='#ffffff'); d.ellipse(A[0] - 7, A[1] - 7, 14, 14, fill='#ffffff')
        d.text(Wx, py + 188, 'Tire\n(front %s)' % ('left' if sgn < 0 else 'right'), fs=14)
    # steered angle delta_f at the upper joint of the left tie rod, F_yf on the left wheel
    R = (ax - 270, py); A = (ax - 312, py + 56)
    d.line([R, (R[0], A[1] + 34)], dashed=True, lw=1.2, color='#444444')
    rr = math.hypot(A[0] - R[0], A[1] - R[1])
    a0 = math.atan2(A[1] - R[1], A[0] - R[0]); a1 = math.pi / 2
    pts = [(R[0] + rr * math.cos(a0 + (a1 - a0) * t / 12), R[1] + rr * math.sin(a0 + (a1 - a0) * t / 12)) for t in range(13)]
    d.poly(pts, lw=1.4)
    d.line([(R[0] + 56, A[1] + 30), (R[0] + 4, A[1] + 30)], arrow=True, lw=1.8)
    d.text(R[0] + 34, A[1] + 12, r'$\delta_f$', fs=17)
    d.line([(R[0] - 110, py - 4), (R[0] - 12, py - 4)], arrow=True, lw=2.2)
    d.text(R[0] - 62, py - 26, r'$F_{yf}$', fs=17)
    d.text(ax, 1075, r'road reaction $T_r = (e_p / n_{st})\,F_{yf}$ acts back on the column', fs=14, italic=True, color='#555555')
    d.line([(ax + 4, 800), (ax + 4, 752)], lw=0.0)
    d.save(os.path.join(OUT, 'Fig1a_mechanism'))



def fig1b_vertical():
    """compact VERTICAL block diagram of the plant, top to bottom: steering column -> tires -> vehicle body, with the equations of each block"""
    d = Diagram(720, 1100)
    x, w = 180, 330
    d.frame(90, 70, 520, 960, 'Plant', fill='#fbfbfb')
    d.block(x, 120, w, 170, ['Steering column', r'$J_{col}\ddot{\theta}_2 = T_s + T_a - T_r - C_{col}\dot{\theta}_2$', r'$\qquad - T_f \tanh(c\dot{\theta}_2)$',
                             r'$T_s = K(\theta_1 - \theta_2)$', 'Eqs. (1)–(2)'], fill=BLUE, bold_first=True, fs=15)
    d.block(x, 400, w, 250, ['Tires', r'slip angles $\alpha_f,\ \alpha_r$   Eqs. (3)–(6)', r'Magic Formula $F_y(\alpha, \mu)$   Eqs. (7)–(8)',
                             r'pneumatic trail $e_p(\alpha_f, \mu)$   Eqs. (9)–(10)', r'$T_r = (e_p / n_{st})\,F_{yf}$   Eq. (11)'], fill=GREEN, bold_first=True, fs=15)
    d.block(x, 760, w, 190, ['Vehicle body (single track, 2 DOF)', r'$a_y = (F_{yf} + F_{yr}) / m$', r'$\dot{\beta} = a_y / v - \gamma$',
                             r'$\dot{\gamma} = (l_f F_{yf} - l_r F_{yr}) / I_z$', 'Eqs. (12)–(14)'], fill=YELLOW, bold_first=True, fs=15)
    # inputs at the top
    d.line([(250, 20), (250, 120)], arrow=True); d.text(232, 50, r'$\theta_1$', fs=18, ha='right')
    d.line([(440, 20), (440, 120)], arrow=True); d.text(458, 50, r'$T_a$', fs=18, ha='left')
    d.text(345, 8, 'driver angle, assist torque', fs=13, italic=True, color='#555555')
    # outputs of the column
    d.line([(510, 160), (680, 160)], arrow=True); d.text(660, 140, r'$T_s$', fs=18)
    d.line([(510, 230), (680, 230)], arrow=True); d.text(660, 210, r'$\dot{\theta}_2$', fs=18)
    # column -> tires
    d.line([(345, 290), (345, 400)], arrow=True); d.text(362, 345, r'$\theta_2$', fs=18, ha='left')
    # tires -> body
    d.line([(270, 650), (270, 760)], arrow=True); d.text(252, 705, r'$F_{yf}$', fs=18, ha='right')
    d.line([(420, 650), (420, 760)], arrow=True); d.text(438, 705, r'$F_{yr}$', fs=18, ha='left')
    # feedback T_r (left): tires -> column
    d.line([(180, 560), (130, 560), (130, 205), (180, 205)], arrow=True); d.text(118, 380, r'$T_r$', fs=18, ha='right')
    # feedback beta, gamma (left): body -> tires
    d.line([(180, 880), (110, 880), (110, 500), (180, 500)], arrow=True); d.text(98, 690, r'$\beta,\ \gamma$', fs=18, ha='right')
    # mu and v from the right
    d.line([(680, 470), (510, 470)], arrow=True); d.text(660, 450, r'$\mu$', fs=18)
    d.text(660, 495, '(not measured)', fs=12, italic=True, color='#555555', ha='center')
    d.line([(680, 560), (510, 560)], arrow=True); d.text(660, 540, r'$v$', fs=18)
    d.dot(600, 560); d.line([(600, 560), (600, 850), (510, 850)], arrow=True)
    # outputs of the body
    d.line([(270, 950), (270, 1060)], arrow=True); d.text(252, 1035, r'$a_y$', fs=18, ha='right')
    d.line([(420, 950), (420, 1060)], arrow=True); d.text(438, 1035, r'$\gamma$', fs=18, ha='left')
    d.save(os.path.join(OUT, 'Fig1b_plant_vertical'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ['fig2']
    for name in which:
        globals()[name]()
