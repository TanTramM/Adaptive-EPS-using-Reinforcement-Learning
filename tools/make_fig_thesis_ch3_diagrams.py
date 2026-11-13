"""Block diagrams of thesis chapter 3 (Documents/Thesis/luanvan.txt) -> Documents/Thesis/figures/.

Hinh_3_1_Map.png, Hinh_3_4_PID.png, Hinh_3_5_MapPID.png are the three block diagrams of the paper (Figures/main/Fig_4_Map, Fig_5_PID, Fig_6_MapPID) with the
English block names replaced by Vietnamese ones; the mathematics and the layout are untouched. Each English label is located in the original pixels
(first ink band inside a given region), erased, and the Vietnamese label is drawn in Times New Roman at the size that matches the original cap height,
centred on the same point and standing on the same baseline. Same method as Hinh_2_1 in make_fig_thesis_ch2.py.

Hinh_3_2_Map.png and Hinh_3_3_Static.png (the assist map and its static equilibrium) are made by make_fig_thesis_ch3.m in MATLAB.

Run: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_fig_thesis_ch3_diagrams.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'Figures', 'main')
OUT = os.path.join(ROOT, 'Documents', 'Thesis', 'figures')
FONT = 'C:/Windows/Fonts/times.ttf'
INK = (34, 34, 34)

# (source file, output file, [(region x0, y0, x1, y1 around ONE label, English text, Vietnamese text)]); the region must not contain box borders
JOBS = [
    ('Fig_4_Map.png', 'Hinh_3_1_Map.png', [
        ((200, 620, 880, 800), 'Map controller', 'Bộ điều khiển Map'),
        ((2600, 500, 3420, 700), 'Nonlinear C-EPS plant', 'Đối tượng C-EPS phi tuyến'),
        ((2740, 1250, 3280, 1420), 'Torque sensor', 'Cảm biến mô-men'),
    ]),
    ('Fig_5_PID.png', 'Hinh_3_4_PID.png', [
        ((20, 480, 420, 640), 'Reference', 'Mục tiêu'),
        ((1000, 480, 1480, 640), 'PID controller', 'Bộ điều khiển PID'),
        ((2730, 380, 3380, 540), 'Nonlinear C-EPS plant', 'Đối tượng C-EPS phi tuyến'),
        ((2760, 1060, 3350, 1250), 'Measurement model', 'Mô hình đo'),
    ]),
    ('Fig_6_MapPID.png', 'Hinh_3_5_MapPID.png', [
        ((1100, 405, 1450, 520), 'Map branch', 'Nhánh Map'),
        ((1100, 670, 1450, 800), 'PID branch', 'Nhánh PID'),
        ((30, 670, 420, 800), 'Reference', 'Mục tiêu'),
        ((2840, 315, 3400, 450), 'Nonlinear C-EPS plant', 'Đối tượng C-EPS phi tuyến'),
        ((2870, 1010, 3360, 1180), 'Measurement model', 'Mô hình đo'),
    ]),
]


def first_band(mask, gap=2):
    """Rows (r0, r1) of the first block of ink rows, a block ending after more than `gap` blank rows."""
    rows = np.where(mask.any(axis=1))[0]
    start = prev = rows[0]
    for r in rows[1:]:
        if r - prev > gap:
            break
        prev = r
    return start, prev


def locate(gray, region):
    """Bounding box (x0, x1, y0, y1) and baseline of the first text line in region."""
    x0, y0, x1, y1 = region
    mask = gray[y0:y1, x0:x1] < 140
    # skip a leading thin horizontal border line (box edge) if one is inside the region
    r0, r1 = first_band(mask)
    while r1 - r0 < 6:
        mask[r0:r1 + 1, :] = False
        r0, r1 = first_band(mask)
    band = mask[r0:r1 + 1]
    cols = np.where(band.any(axis=0))[0]
    lab, n = ndi.label(band, structure=np.ones((3, 3)))
    bottoms = [o[0].stop - 1 for o in ndi.find_objects(lab) if (o[0].stop - o[0].start) > 20]
    baseline = max(set(bottoms), key=bottoms.count)             # the most common bottom of the tall glyphs = the baseline
    return x0 + cols.min(), x0 + cols.max(), y0 + r0, y0 + r1, y0 + r0 + baseline


for src, dst, labels in JOBS:
    img = Image.open(os.path.join(SRC, src)).convert('RGB')
    gray = np.array(img.convert('L'))
    draw = ImageDraw.Draw(img)
    for region, english, vietnamese in labels:
        bx0, bx1, by0, by1, base = locate(gray, region)
        w_old = bx1 - bx0
        # font size: the one for which the English text has the width of the original word
        size = 40
        for _ in range(3):
            f = ImageFont.truetype(FONT, int(round(size)))
            size = size * w_old / draw.textlength(english, font=f)
        size = int(round(size))
        font = ImageFont.truetype(FONT, size)
        w_new = draw.textlength(vietnamese, font=font)
        cx = (bx0 + bx1) / 2
        draw.rectangle((bx0 - 8, by0 - 8, bx1 + 8, by1 + 2), fill='white')
        draw.text((cx - w_new / 2, base + 1), vietnamese, font=font, fill=INK, anchor='ls')
        print('%s: "%s" -> "%s": old width %d, new width %d, size %d, baseline %d' % (dst, english, vietnamese, w_old, w_new, size, base))
    img.save(os.path.join(OUT, dst))
