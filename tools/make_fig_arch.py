"""Closed-loop architecture shared by every controller, for the paper (Figure 4). Same wiring as Model_<Ctrl>.mdl built by build_closed_loop.m.
Writes Figures/Figure_5_architecture.drawio (editable) and Figures/Figure_5_architecture.png (preview, same layout).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fig_blocks import Fig

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
f = Fig(1220, 640)
f.text(10, 22, 'Closed-loop architecture shared by all controllers', fs=15, ha='left', bold=True)
# blocks
f.box(20, 190, 170, 100, ['Controller', 'Map, PI, PID', '1 ms sample'], fill='#dbe8fb')
f.box(250, 208, 100, 64, ['Delay', '(margin test)'], dashed=True, fs=12)
f.box(420, 190, 170, 100, ['Actuator', r'bound $\pm T_{a,max}(v)$', r'motor lag $G_m(s)$'])
f.box(650, 208, 90, 64, ['Gain', '(margin test)'], dashed=True, fs=12)
f.box(820, 180, 210, 100, ['Plant', 'steering column, tires,', 'vehicle body'], fill='#d9ead3')
f.box(820, 50, 210, 70, ['Scenario', r'$\theta_1(t),\ v(t),\ \mu(t)$'], fill='#f3f3f3')
f.box(820, 430, 210, 76, ['Sensors', 'noise, quantization,', 'update period'], fill='#fdeec4')
f.box(420, 340, 170, 64, ['Assist limit', r'$T_{a,max}(v)$'])
# forward path
f.arrow([(190, 240), (250, 240)]); f.text(220, 224, r'$T_{a,cmd}$', fs=12)
f.arrow([(350, 240), (420, 240)])
f.arrow([(590, 240), (650, 240)]); f.text(620, 224, r'$T_a$', fs=12)
f.arrow([(740, 240), (820, 240)]); f.text(780, 224, r'$T_a$', fs=12)
# limit signals
f.arrow([(505, 190), (505, 130), (105, 130), (105, 190)]); f.text(305, 114, r'$T_{a,lim}$ (command after the limit)', fs=12)
f.arrow([(505, 340), (505, 290)]); f.text(545, 316, r'$T_{a,max}$', fs=12)
# measured bus (thick) and its branch to the assist limit
f.arrow([(820, 468), (140, 468), (140, 290)], lw=3.4)
f.text(480, 484, r'measured: $T_s,\ \theta_1,\ \dot{\theta}_2,\ v,\ \gamma,\ a_y$', fs=12)
f.dot(505, 468); f.arrow([(505, 468), (505, 404)]); f.text(527, 436, r'$v$', fs=12)
# scenario, plant outputs
f.arrow([(925, 120), (925, 180)]); f.text(975, 150, r'$\theta_1,\ v,\ \mu$', fs=12)
f.arrow([(925, 280), (925, 430)]); f.text(940, 355, 'true: $T_s,\\ \\dot{\\theta}_2,$\n$\\gamma,\\ a_y$', fs=12, ha='left')
f.arrow([(1030, 85), (1090, 85), (1090, 468), (1030, 468)]); f.text(1102, 400, r'$\theta_1,\ v$ (true)', fs=12, ha='left')
# notes
notes = ['The controller reads the measured bus by name and returns T_a,cmd; the Actuator, not the controller, applies the limit T_a,max(v).',
         'PI and PID compute T_d,ref(v, a_y) and e_T = T_s - T_d,ref from the measured signals; the assist map reads T_s and v only.',
         'The dashed Delay and Gain blocks serve only the stability-margin test (defaults: no delay, gain 1).',
         'The friction coefficient mu is not measured: it acts on the tires as a disturbance.']
for i, n in enumerate(notes):
    f.text(20, 540 + 24 * i, '• ' + n.replace('T_a,cmd', '$T_{a,cmd}$').replace('T_a,max(v)', '$T_{a,max}(v)$').replace('T_d,ref(v, a_y)', '$T_{d,ref}(v,a_y)$')
           .replace('e_T = T_s - T_d,ref', '$e_T=T_s-T_{d,ref}$').replace('T_s and v', '$T_s$ and $v$').replace(' mu ', ' $\\mu$ '), fs=12, ha='left', w=1380)
f.save_drawio(os.path.join(root, 'Figures', 'Figure_5_architecture.drawio'))
f.save_png(os.path.join(root, 'Figures', 'Figure_5_architecture.png'))
print('wrote Figure_5_architecture')
