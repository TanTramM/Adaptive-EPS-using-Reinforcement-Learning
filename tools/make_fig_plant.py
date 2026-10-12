"""Block diagram of the plant (Plant.mdl: SteeringColumn, Tires, Bike2DOF) for the paper, Figure 2.
Ports are exactly those of the Simulink model: inputs theta1, T_a, v, mu; outputs T_s, a_y, gamma, theta2_dot.
Writes Figures/Figure_2_plant.drawio (editable) and Figures/Figure_2_plant.png (preview, same layout).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fig_blocks import Fig

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
f = Fig(1280, 470)
f.frame(110, 100, 1060, 320)
f.text(125, 117, 'Plant', fs=14, ha='left', bold=True, color='#555555')
f.box(150, 130, 200, 130, ['Steering column', 'torsion bar, inertia,', 'damping, dry friction', 'Eqs. (1)-(2)'], fill='#e8f0fa')
f.box(520, 130, 220, 130, ['Tires', 'slip angles, Magic Formula,', 'pneumatic trail', 'Eqs. (4)-(7)'], fill='#e8f5e9')
f.box(900, 130, 220, 130, ['Vehicle body', 'single track, 2 DOF', 'Eq. (8)'], fill='#fff4d6')
# exogenous inputs
f.arrow([(20, 170), (150, 170)]); f.text(85, 154, r'$\theta_1$')
f.arrow([(20, 230), (150, 230)]); f.text(85, 214, r'$T_a$')
f.arrow([(600, 30), (600, 130)]); f.text(584, 52, r'$v$')
f.dot(600, 70); f.arrow([(600, 70), (1010, 70), (1010, 130)])
f.arrow([(630, 450), (630, 260)]); f.text(648, 440, r'$\mu$')
# internal signals
f.arrow([(350, 170), (520, 170)]); f.text(435, 154, r'$\theta_2$')
f.arrow([(740, 170), (900, 170)]); f.text(820, 154, r'$F_{yf}$')
f.arrow([(740, 230), (900, 230)]); f.text(820, 214, r'$F_{yr}$')
f.arrow([(560, 260), (560, 345), (250, 345), (250, 260)]); f.text(405, 330, r'$T_r$')
f.arrow([(1010, 260), (1010, 385), (700, 385), (700, 260)]); f.text(855, 370, r'$\beta,\ \gamma$')
# outputs
f.arrow([(220, 130), (220, 25)]); f.text(238, 48, r'$T_s$')
f.arrow([(300, 130), (300, 25)]); f.text(322, 48, r'$\dot{\theta}_2$')
f.arrow([(1120, 170), (1250, 170)]); f.text(1185, 154, r'$a_y$')
f.arrow([(1120, 230), (1250, 230)]); f.text(1185, 214, r'$\gamma$')
f.save_drawio(os.path.join(root, 'Figures', 'Figure_2_plant.drawio'))
f.save_png(os.path.join(root, 'Figures', 'Figure_2_plant.png'))
print('wrote Figure_2_plant')
