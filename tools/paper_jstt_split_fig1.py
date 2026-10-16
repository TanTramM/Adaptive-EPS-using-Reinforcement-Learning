"""Version 4 of the journal text: Figure 1 (a mechanism, b plant block diagram) is split into two figures and the figure numbers after it count up.

  Fig. 1 mechanical structure of the column-type EPS        (Figures/drawio/Fig1a_mechanism.png)
  Fig. 2 block diagram of the coupled C-EPS-vehicle plant   (Figures/drawio/Fig1b_plant_vertical.png)
  Fig. 3 assist-map and torque-feedback control architectures
  Fig. 4 calibration Pareto fronts      Fig. 5 DRY      Fig. 6 SLIP      Fig. 7 tracking error of the five scoring cases

Every reference in the running text (Fig. n, Figs. a-b) is renumbered. Also writes the figure files of the submission with matching names to Figures/JSTT_v4/.

Usage: python tools/paper_jstt_split_fig1.py Documents/Paper/paper_jstt_v3.txt Documents/Paper/paper_jstt_v4.txt
"""
import os
import re
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CAP1 = ('Mechanical structure of the column-type EPS: steering wheel and upper column, torsion bar with the torque and angle sensor, assist motor with the '
        'worm reduction gear, universal joint, pinion and rack, tie rods and front wheels.')
CAP2 = ('Block diagram of the coupled C-EPS–vehicle plant: steering column, tires and vehicle body, with the tire–road reaction torque and the '
        'vehicle lateral motion fed back.')
FILES = [  # (new number, source, name in Figures/JSTT_v4)
    (1, 'Figures/drawio/Fig1a_mechanism.png', 'Fig1_mechanism.png'),
    (2, 'Figures/drawio/Fig1b_plant_vertical.png', 'Fig2_plant.png'),
    (3, 'Figures/drawio/Fig2_control.png', 'Fig3_control.png'),
    (4, 'Figures/matlab/Fig3.png', 'Fig4_pareto.png'),
    (5, 'Figures/matlab/Fig4.png', 'Fig5_dry.png'),
    (6, 'Figures/matlab/Fig5.png', 'Fig6_slip.png'),
    (7, 'Figures/matlab/Fig6.png', 'Fig7_drews.png'),
]


def main(src, dst):
    t = open(src, encoding='utf-8').read()
    # 1. the numbers after Figure 1 count up by one (done on a placeholder so that nothing is shifted twice)
    t = re.sub(r'Figs\. (\d)–(\d)', lambda m: 'Figs. @%d@–@%d@' % (int(m.group(1)) + 1, int(m.group(2)) + 1), t)
    t = re.sub(r'\bFig\. ([2-6])\b', lambda m: 'Fig. @%d@' % (int(m.group(1)) + 1), t)
    # 2. Figure 1 becomes two figures
    old_start = t.index('[Fig. 1. Coupled C-EPS')
    old_end = t.index(']', t.index('Fig1b_plant_vertical.png', old_start)) + 1
    new = ('[Fig. 1. %s | Figures/drawio/Fig1a_mechanism.png#12.5]\n' % CAP1 +
           '[Fig. @2@. %s | Figures/drawio/Fig1b_plant_vertical.png#9.0]' % CAP2)
    t = t[:old_start] + new + t[old_end:]
    # 3. the sentence of Section 2.1 that introduces the figure
    old = 'as illustrated in Fig. 1.'
    assert old in t
    t = t.replace(old, 'as illustrated in Figs. 1 and 2.')
    t = t.replace('@', '').replace('#', '@')
    open(dst, 'w', encoding='utf-8').write(t)
    out = os.path.join(REPO, 'Figures', 'JSTT_v4')
    os.makedirs(out, exist_ok=True)
    for n, s, name in FILES:
        shutil.copyfile(os.path.join(REPO, s), os.path.join(out, name))
        pdf = os.path.join(REPO, s.rsplit('.', 1)[0] + '.pdf')
        if os.path.isfile(pdf):
            shutil.copyfile(pdf, os.path.join(out, name.rsplit('.', 1)[0] + '.pdf'))
    print('Wrote', dst, 'and the figure files in', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
