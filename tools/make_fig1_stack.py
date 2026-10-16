"""Place the two draw.io previews of Figure 1 side by side: (a) the vertical mechanism (left) and (b) the vertical plant block diagram (right), captions under
each, into one picture for the paper (Figures/drawio/Fig1_model.png/.pdf).
The raw sources stay Fig1a_mechanism.drawio and Fig1b_plant_vertical.drawio (edit and re-export them in draw.io; this script only places the two exports).
Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig1_stack.py   (from the repo root)
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(REPO, 'Figures', 'drawio')
plt.rcParams.update({'font.family': 'Arial'})
a = plt.imread(os.path.join(D, 'Fig1a_mechanism.png'))
b = plt.imread(os.path.join(D, 'Fig1b_plant_vertical.png'))
H = 9.0                                              # figure height [in]
hp = H - 0.55                                        # height of the panels
wa, wb = hp * a.shape[1] / a.shape[0], hp * b.shape[1] / b.shape[0]
W = wa + wb + 0.2
fig = plt.figure(figsize=(W, H))
ax = fig.add_axes([0.0, 0.5 / H, wa / W, hp / H]); ax.imshow(a); ax.axis('off')
ax = fig.add_axes([(wa + 0.2) / W, 0.5 / H, wb / W, hp / H]); ax.imshow(b); ax.axis('off')
fig.text((wa / 2) / W, 0.18 / H, '(a) Mechanical structure of the column-type EPS', ha='center', fontsize=11)
fig.text((wa + 0.2 + wb / 2) / W, 0.18 / H, '(b) Block diagram of the coupled plant model', ha='center', fontsize=11)
fig.savefig(os.path.join(D, 'Fig1_model.png'), dpi=300, facecolor='white')
fig.savefig(os.path.join(D, 'Fig1_model.pdf'), facecolor='white')
print('wrote Fig1_model, aspect %.2f' % (W / H))
