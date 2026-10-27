"""Fig. 4-6 of the paper redrawn after the teacher's comments (2026-10-28): Map with the limit merged into the lead-lag block, PID as ONE block with the
limit inside and ONE total formula, MapPID with one PID block.  Writes .drawio + .png + .pdf into Figures/new/main/28-10/ (the hand-made figures in
Figures/new/main/ are not touched).

Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig_controllers_2810.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import drawio_kit
from drawio_kit import Diagram

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'Figures', 'new', 'main', '28-10')

_orig_ascii = drawio_kit.tex2ascii


def _ascii(s):
    # \frac{a}{b} -> (a)/(b) so that draw.io's AsciiMath renders the fraction
    s = re.sub(r'\\frac\{([^{}]*)\}\{([^{}]*)\}', r'(\1)/(\2)', s)
    return _orig_ascii(s)


drawio_kit.tex2ascii = _ascii

FS = 26
B = dict(rounded=False, fs=FS, lw=1.6)
FONT = 'Times New Roman'


def lab(d, x, y, s, fs=28):
    d.text(x, y, s, fs=fs)


def vm_in(d, x, ytop, h=100):
    """measured speed v_m: a short arrow entering the block from above (like the plant input)"""
    d.line([(x, ytop - h), (x, ytop)], arrow=True)
    lab(d, x, ytop - h - 25, r'$v_m$')


def plant_and_sensor_chain(d, y, x_motor, x_plant, xin_theta, two_outputs=False):
    """motor -> plant, plant inputs and outputs; returns x of the plant output"""
    d.block(x_motor, y - 55, 180, 110, ['Motor', r'$G_a(s)$'], **B)
    d.block(x_plant, y - 100, 360, 200,
            ['Nonlinear C-EPS plant', r'$x=[\theta_2,\dot{\theta}_2,\beta,\gamma]^T$',
             r'$\dot{x}=f(x,T_a,\theta_1,v,\mu)$', r'$T_s=K(\theta_1-\theta_2)$'], **B)
    d.line([(x_motor + 180, y), (x_plant, y)], arrow=True)
    lab(d, (x_motor + 180 + x_plant) / 2, y - 30, r'$T_a$')
    d.line([(xin_theta, y - 230), (xin_theta, y - 100)], arrow=True)
    lab(d, xin_theta, y - 255, r'$[\theta_1,v,\mu]^T$')
    return x_plant + 360


def fig_map():
    """Map: ONE controller block (map, lead-lag and limit inside)"""
    d = Diagram(2050, 650, math=True, font=FONT)
    d.oy = 70
    y = 255
    vm_in(d, 650, y - 55)
    d.block(250, y - 55, 800, 110,
            ['Map controller', r'$T_{a,cmd}=L(C_{map}(s)\,M(v_m,T_{s,m}),\,v_m)$'], **dict(B, fs=28))
    d.block(1190, y - 55, 180, 110, ['Motor', r'$G_a(s)$'], **B)
    d.line([(1050, y), (1190, y)], arrow=True)
    lab(d, 1120, y - 30, r'$T_{a,cmd}$')
    xo = plant_and_sensor_chain(d, y, 1190, 1510, 1690)
    d.line([(xo, y), (xo + 100, y)], arrow=True)
    lab(d, xo + 50, y - 30, r'$T_s$')
    d.dot(xo + 50, y)
    d.block(750, 430, 360, 100, ['Torque sensor', r'$T_{s,m}=H_T(T_s)$'], **B)
    d.line([(xo + 50, y), (xo + 50, 480), (1110, 480)], arrow=True)
    d.line([(750, 480), (650, 480), (650, y + 55)], arrow=True)
    lab(d, 700, 445, r'$T_{s,m}$')
    d.save(os.path.join(OUT, 'Fig_Map'))


def ctrl_fig(name, title, formula, h, fs):
    """PID and MapPID: Reference -> error -> ONE controller block (limit and anti-windup inside) -> motor -> plant"""
    d = Diagram(3080, 800, math=True, font=FONT)
    y = 355
    vm_in(d, 300, y - 55)
    vm_in(d, 1380, y - h // 2)
    d.block(160, y - 55, 280, 110, ['Reference', r'$T_{ref}(v_m,a_{y,m})$'], **B)
    d.sumj(530, y, r=24, signs={'left': '-', 'bottom': '+'}, fs=26)
    d.line([(440, y), (506, y)], arrow=True)
    lab(d, 472, y - 50, r'$T_{ref}$')
    d.line([(554, y), (760, y)], arrow=True)
    lab(d, 650, y - 35, r'$e_T$')
    d.block(760, y - h // 2, 1240, h, [title] + formula, **dict(B, fs=fs))
    mb, mh = 600, 125                       # measurement block: two outputs at 1/3 and 2/3, one input at 1/2
    d.block(2330, mb, 400, mh, ['Measurement model', r'$T_{s,m}=H_T(T_s)$', r'$a_{y,m}=H_{a_y}(a_y)$'], **B)
    d.block(2140, y - 55, 180, 110, ['Motor', r'$G_a(s)$'], **B)
    d.line([(2000, y), (2140, y)], arrow=True)
    lab(d, 2070, y - 30, r'$T_{a,cmd}$')
    d.block(2440, y - 100, 360, 200,
            ['Nonlinear C-EPS plant', r'$x=[\theta_2,\dot{\theta}_2,\beta,\gamma]^T$',
             r'$\dot{x}=f(x,T_a,\theta_1,v,\mu)$', r'$T_s=K(\theta_1-\theta_2)$'], **B)
    d.line([(2320, y), (2440, y)], arrow=True)
    lab(d, 2380, y - 30, r'$T_a$')
    d.line([(2620, y - 230), (2620, y - 100)], arrow=True)
    lab(d, 2620, y - 255, r'$[\theta_1,v,\mu]^T$')
    d.line([(2800, y), (2990, y)], arrow=True)
    lab(d, 2895, y - 35, r'$T_s,a_y$')
    d.dot(2940, y)
    d.line([(2940, y), (2940, mb + mh / 2), (2730, mb + mh / 2)], arrow=True)
    # measured torque: to the error junction and into the block (derivative term acts on it)
    d.line([(2330, mb + mh / 3), (530, mb + mh / 3), (530, y + 24)], arrow=True)
    lab(d, 2200, mb + mh / 3 - 35, r'$T_{s,m}$')
    d.dot(1380, mb + mh / 3)
    d.line([(1380, mb + mh / 3), (1380, y + h // 2)], arrow=True)
    d.line([(2330, mb + 2 * mh / 3), (300, mb + 2 * mh / 3), (300, y + 55)], arrow=True)
    lab(d, 2200, mb + 2 * mh / 3 + 35, r'$a_{y,m}$')
    d.save(os.path.join(OUT, name))


def fig_pid():
    ctrl_fig('Fig_PID', 'PID controller',
             [r'$T_{a,cmd}=L(K_p e_T+\int_0^t[K_i e_T(\tau)+K_{aw}\Delta T_a(\tau)]\,d\,\tau'
              r'+\frac{K_d s}{\tau_f s+1}T_{s,m},\,v_m)$'], 210, 32)


def fig_mappid():
    ctrl_fig('Fig_MapPID', 'MapPID controller',
             [r'$T_{a,cmd}=L(C_{map}(s)\,M(v_m,T_{s,m})$',
              r'$+K_p e_T+\int_0^t[K_i e_T(\tau)+K_{aw}\Delta T_a(\tau)]\,d\,\tau+\frac{K_d s}{\tau_f s+1}T_{s,m},\,v_m)$'], 230, 30)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    fig_map()
    fig_pid()
    fig_mappid()
