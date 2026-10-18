"""Small drawing kit: ONE description gives (a) an editable draw.io file (.drawio, the raw source of the figure) and (b) a PNG/PDF preview drawn
with matplotlib from the same primitives, so the layout can be checked without opening draw.io.

    d = Diagram(1500, 900)
    d.frame(20, 20, 600, 300, 'Steering column', fill='#f4f8fd')
    d.block(100, 100, 120, 60, ['K'], fill='#dce8f8')
    d.sumj(300, 130, r=16, signs={'left': '+', 'bottom': '-'})
    d.line([(220, 130), (284, 130)], arrow=True)
    d.text(250, 112, r'$T_s$')
    d.save('Figures/drawio/Fig_x')          # writes Fig_x.drawio and Fig_x.png (+ .pdf)

Coordinates are pixels, y down. Text may contain LaTeX between dollar signs (Greek letters, _sub, \\dot{}); it is converted to HTML for draw.io.
Open the .drawio in draw.io (app.diagrams.net) to edit and to export the final figure (File > Export as > PNG/PDF, 300 dpi or more).
"""
import html
import os
import re

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, FancyArrowPatch, FancyBboxPatch, Rectangle

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fig_blocks import tex2html


def tex2ascii(s):
    """convert the $...$ segments of s to AsciiMath between backticks (draw.io renders them when Extras > Mathematical Typesetting is on, i.e. math="1");
    other text is escaped.  Examples: $T_{a,lim}$ -> `T_(a,lim)`, $\\theta_1$ -> `theta_1`, $\\pm T_{a,max}(v)$ -> `+-T_(a,max)(v)`"""
    out = []
    for i, part in enumerate(re.split(r'\$', s)):
        if i % 2 == 0:
            out.append(html.escape(part))
            continue
        t = part
        t = re.sub(r'\\dot\{\\(\w+)\}', lambda m: 'dot ' + m.group(1), t)
        t = re.sub(r'\\dot\\(\w+)', lambda m: 'dot ' + m.group(1), t)
        t = t.replace('\\pm', '+-').replace('\\cdot', '*')
        t = re.sub(r'\\([A-Za-z]+)', lambda m: m.group(1), t)
        t = re.sub(r'_\{([^}]*)\}', lambda m: '_(' + m.group(1) + ')', t)
        t = t.replace('\\,', ' ').replace('\\ ', ' ')
        out.append('`' + html.escape(t.strip()) + '`')
    return ''.join(out)

INK = '#222222'
plt.rcParams.update({'font.family': 'Arial', 'mathtext.fontset': 'custom', 'mathtext.rm': 'Arial', 'mathtext.it': 'Arial:italic',
                     'mathtext.bf': 'Arial:bold', 'mathtext.default': 'it'})


class Diagram:
    def __init__(self, w, h, math=False, font='Arial'):
        self.w, self.h = w, h
        self.font = font                             # font family of every label (draw.io fontFamily and the PNG/PDF preview)
        self.math = math                             # True: draw.io labels use AsciiMath in backticks (math="1")
        self.items = []
        self.oy = 0                                  # vertical offset added to every y given to the drawing methods

    # ------------------------------------------------------------------ description
    def frame(self, x, y, w, h, label=None, fill='none', stroke='#8a8a8a', fs=16, dashed=True):
        self.items.append(('frame', x, y + self.oy, w, h, label, fill, stroke, fs, dashed))

    def block(self, x, y, w, h, lines, fill='#ffffff', stroke=INK, fs=16, bold_first=False, rounded=True, dashed=False, lw=1.8):
        self.items.append(('block', x, y + self.oy, w, h, list(lines), fill, stroke, fs, bold_first, rounded, dashed, lw))

    def ellipse(self, x, y, w, h, fill='#ffffff', stroke=INK, lw=1.6):
        self.items.append(('ellipse', x, y + self.oy, w, h, fill, stroke, lw))

    def sumj(self, cx, cy, r=16, signs=None, fs=15, mark=None):
        """summing junction (a circle); signs = {'left':'+', 'top':'-', ...} written beside the input points; mark='x' draws the product sign"""
        self.items.append(('sumj', cx, cy + self.oy, r, signs or {}, fs, mark))

    def line(self, pts, arrow=False, both=False, dashed=False, lw=1.8, color=INK, dotted=False):
        self.items.append(('line', [(a, b + self.oy) for a, b in pts], arrow, both, dashed, lw, color, dotted))

    def text(self, x, y, s, fs=16, ha='center', bold=False, color=INK, italic=False, w=None):
        self.items.append(('text', x, y + self.oy, s, fs, ha, bold, color, italic, w))

    def dot(self, x, y, r=4):
        self.items.append(('dot', x, y + self.oy, r))

    def poly(self, pts, lw=2.0, color=INK):
        """open polyline without arrow (spring, hatch, thread...)"""
        self.items.append(('line', [(a, b + self.oy) for a, b in pts], False, False, False, lw, color, False))

    # ------------------------------------------------------------------ PNG / PDF preview
    def save_preview(self, base, scale=2.0, pdf=True):
        plt.rcParams.update({'font.family': self.font, 'mathtext.rm': self.font, 'mathtext.it': self.font + ':italic', 'mathtext.bf': self.font + ':bold'})
        fig = plt.figure(figsize=(self.w / 100, self.h / 100), dpi=100)
        ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, self.w); ax.set_ylim(self.h, 0); ax.axis('off')
        px = lambda v: v * 0.72
        for it in self.items:
            k = it[0]
            if k == 'frame':
                _, x, y, w, h, label, fill, stroke, fs, dashed = it
                ax.add_patch(Rectangle((x, y), w, h, fc=fill, ec=stroke, lw=1.4, ls=(0, (6, 4)) if dashed else '-', zorder=0))
                if label:
                    ax.text(x + 12, y + 8, label, ha='left', va='top', fontsize=px(fs), fontweight='bold', color='#555555', zorder=1)
            elif k == 'block':
                _, x, y, w, h, lines, fill, stroke, fs, bold_first, rounded, dashed, lw = it
                if rounded:
                    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0,rounding_size=8', fc=fill, ec=stroke, lw=lw, ls='--' if dashed else '-', zorder=2))
                else:
                    ax.add_patch(Rectangle((x, y), w, h, fc=fill, ec=stroke, lw=lw, ls='--' if dashed else '-', zorder=2))
                n = len(lines); lh = fs * 1.3
                for j, ln in enumerate(lines):
                    ax.text(x + w / 2, y + h / 2 + (j - (n - 1) / 2) * lh, ln, ha='center', va='center', fontsize=px(fs),
                            fontweight='bold' if (bold_first and j == 0) else 'normal', color=INK, zorder=3)
            elif k == 'ellipse':
                _, x, y, w, h, fill, stroke, lw = it
                ax.add_patch(Ellipse((x + w / 2, y + h / 2), w, h, fc=fill, ec=stroke, lw=lw, zorder=2))
            elif k == 'sumj':
                _, cx, cy, r, signs, fs, mark = it
                ax.add_patch(Ellipse((cx, cy), 2 * r, 2 * r, fc='white', ec=INK, lw=1.8, zorder=2))
                if mark == 'x':
                    d = r * 0.62
                    ax.plot([cx - d, cx + d], [cy - d, cy + d], c=INK, lw=1.6, zorder=3); ax.plot([cx - d, cx + d], [cy + d, cy - d], c=INK, lw=1.6, zorder=3)
                off = {'left': (-r - 13, -11), 'right': (r + 13, -11), 'top': (13, -r - 12), 'bottom': (13, r + 12),
                       'topleft': (-r - 4, -r - 8), 'bottomleft': (-r - 4, r + 10), 'topright': (r + 4, -r - 8), 'bottomright': (r + 4, r + 10)}
                for side, sg in signs.items():
                    dx, dy = off[side]
                    ax.text(cx + dx, cy + dy, '−' if sg == '-' else sg, ha='center', va='center', fontsize=px(fs), zorder=4)
            elif k == 'line':
                _, pts, arrow, both, dashed, lw, color, dotted = it
                ls = (0, (1, 3)) if dotted else ('--' if dashed else '-')
                xs, ys = zip(*pts)
                body = list(pts)
                ax.plot(xs, ys, color=color, lw=lw, ls=ls, zorder=1, solid_capstyle='butt', solid_joinstyle='miter')
                if arrow:
                    ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle='-|>', mutation_scale=15, color=color, lw=lw, shrinkA=0, shrinkB=0, zorder=2))
                if both:
                    ax.add_patch(FancyArrowPatch(pts[1], pts[0], arrowstyle='-|>', mutation_scale=15, color=color, lw=lw, shrinkA=0, shrinkB=0, zorder=2))
            elif k == 'text':
                _, x, y, s, fs, ha, bold, color, italic, w = it
                ax.text(x, y, s, ha=ha, va='center', fontsize=px(fs), fontweight='bold' if bold else 'normal', fontstyle='italic' if italic else 'normal',
                        color=color, zorder=5, linespacing=1.3)
            elif k == 'dot':
                ax.plot([it[1]], [it[2]], 'o', color=INK, ms=it[3] * 1.4, zorder=5)
        fig.savefig(base + '.png', dpi=100 * scale, facecolor='white')
        if pdf:
            fig.savefig(base + '.pdf', facecolor='white')
        plt.close(fig)

    # ------------------------------------------------------------------ draw.io source
    def save_drawio(self, path):
        conv = tex2ascii if self.math else tex2html
        cells, nid = [], [2]

        def new_id():
            nid[0] += 1
            return 'c%d' % nid[0]

        def vertex(i, val, style, x, y, w, h):
            if 'fontSize' in style:
                style += 'fontFamily=%s;' % self.font
            return ('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1"><mxGeometry x="%g" y="%g" width="%g" height="%g" as="geometry"/></mxCell>'
                    % (i, html.escape(val, quote=True), style, x, y, w, h))
        for it in self.items:
            k = it[0]
            if k == 'frame':
                _, x, y, w, h, label, fill, stroke, fs, dashed = it
                val = '<b>%s</b>' % conv(label) if label else ''
                st = ('rounded=0;whiteSpace=wrap;html=1;fillColor=%s;strokeColor=%s;fontColor=#555555;fontSize=%d;verticalAlign=top;align=left;spacingLeft=10;%s'
                      % (fill, stroke, fs - 2, 'dashed=1;' if dashed else ''))
                cells.append(vertex(new_id(), val, st, x, y, w, h))
            elif k == 'block':
                _, x, y, w, h, lines, fill, stroke, fs, bold_first, rounded, dashed, lw = it
                val = '<br>'.join(('<b>%s</b>' % conv(l)) if (j == 0 and bold_first) else conv(l) for j, l in enumerate(lines))
                st = ('rounded=%d;arcSize=12;whiteSpace=wrap;html=1;fillColor=%s;strokeColor=%s;strokeWidth=%.1f;fontColor=#222222;fontSize=%d;%s'
                      % (1 if rounded else 0, fill, stroke, lw, fs - 2, 'dashed=1;' if dashed else ''))
                cells.append(vertex(new_id(), val, st, x, y, w, h))
            elif k == 'ellipse':
                _, x, y, w, h, fill, stroke, lw = it
                cells.append(vertex(new_id(), '', 'ellipse;whiteSpace=wrap;html=1;fillColor=%s;strokeColor=%s;strokeWidth=%.1f;' % (fill, stroke, lw), x, y, w, h))
            elif k == 'sumj':
                _, cx, cy, r, signs, fs, mark = it
                shape = 'shape=sumEllipse;' if mark == 'x' else 'ellipse;'
                cells.append(vertex(new_id(), '', '%swhiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#222222;strokeWidth=1.8;' % shape, cx - r, cy - r, 2 * r, 2 * r))
                off = {'left': (-r - 13, -11), 'right': (r + 13, -11), 'top': (13, -r - 12), 'bottom': (13, r + 12),
                       'topleft': (-r - 4, -r - 8), 'bottomleft': (-r - 4, r + 10), 'topright': (r + 4, -r - 8), 'bottomright': (r + 4, r + 10)}
                for side, sg in signs.items():
                    dx, dy = off[side]
                    cells.append(vertex(new_id(), '−' if sg == '-' else sg, 'text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;fontSize=%d;' % (fs - 2),
                                        cx + dx - 10, cy + dy - 10, 20, 20))
            elif k == 'line':
                _, pts, arrow, both, dashed, lw, color, dotted = it
                st = 'endArrow=%s;startArrow=%s;endFill=1;startFill=1;html=1;rounded=0;strokeColor=%s;strokeWidth=%.1f;%s' % (
                    'block' if arrow else 'none', 'block' if both else 'none', color, lw, 'dashed=1;' if dashed else ('dashed=1;dashPattern=1 3;' if dotted else ''))
                mid = ''.join('<mxPoint x="%g" y="%g"/>' % p for p in pts[1:-1])
                geo = ('<mxGeometry relative="1" as="geometry"><mxPoint x="%g" y="%g" as="sourcePoint"/><mxPoint x="%g" y="%g" as="targetPoint"/>%s</mxGeometry>'
                       % (pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], ('<Array as="points">%s</Array>' % mid) if mid else ''))
                cells.append('<mxCell id="%s" edge="1" parent="1" style="%s" value=""> %s</mxCell>' % (new_id(), st, geo))
            elif k == 'text':
                _, x, y, s, fs, ha, bold, color, italic, tw = it
                lines = s.split('\n'); val = '<br>'.join(conv(l) for l in lines)
                if bold:
                    val = '<b>%s</b>' % val
                width = tw or max(24, int(max(len(re.sub(r'[$\\{}_]', '', l)) for l in lines) * fs * 0.6) + 8)
                height = int(fs * 1.4 * len(lines)) + 4
                x0 = x - width / 2 if ha == 'center' else (x if ha == 'left' else x - width)
                st = 'text;html=1;strokeColor=none;fillColor=none;align=%s;verticalAlign=middle;whiteSpace=wrap;fontColor=%s;fontSize=%d;%s' % (
                    ha, color, fs - 2, 'fontStyle=2;' if italic else '')
                cells.append(vertex(new_id(), val, st, x0, y - height / 2, width, height))
            elif k == 'dot':
                cells.append(vertex(new_id(), '', 'ellipse;whiteSpace=wrap;html=1;fillColor=#222222;strokeColor=#222222;', it[1] - it[3], it[2] - it[3], 2 * it[3], 2 * it[3]))
        xml = ('<mxfile host="drawio"><diagram name="Page-1" id="fig"><mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
               'arrows="1" fold="1" page="1" pageScale="1" pageWidth="%d" pageHeight="%d" math="%d" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
               '%s</root></mxGraphModel></diagram></mxfile>') % (self.w + 40, self.h + 40, 1 if self.math else 0, '\n'.join(cells))
        open(path, 'w', encoding='utf-8', newline='').write(xml)

    def save(self, base, scale=2.0):
        os.makedirs(os.path.dirname(base) or '.', exist_ok=True)
        self.save_drawio(base + '.drawio')
        self.save_preview(base, scale=scale)
        print('wrote', base + '.drawio / .png / .pdf')
