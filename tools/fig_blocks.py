"""Tiny block-diagram toolkit: ONE description gives both an editable draw.io file and a PNG preview, so the layout can be checked here.

    f = Fig(1260, 470)
    f.box(150, 130, 200, 130, ['Steering column', 'Eqs. (1)-(2)'], fill='#fff')
    f.arrow([(20, 170), (150, 170)])
    f.text(85, 155, r'$\\theta_1$')
    f.save_drawio('Figures/Figure_N_name.drawio'); f.save_png('Figures/Figure_N_name.png')

Coordinates are pixels, y down. Text may contain LaTeX between dollar signs (Greek letters, _sub, \\dot{}) and is converted to HTML for draw.io.
"""
import re
import html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyArrowPatch

GREEK = {'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'theta': 'θ', 'mu': 'μ', 'tau': 'τ', 'omega': 'ω',
         'Delta': 'Δ', 'times': '×', 'rightarrow': '→', 'le': '≤', 'pm': '±', 'cdot': '·'}


def tex2html(s):
    """convert the $...$ segments of s to HTML (Greek letters, subscripts, dots); other text is escaped"""
    out = []
    for i, part in enumerate(re.split(r'\$', s)):
        if i % 2 == 0:
            out.append(html.escape(part))
            continue
        t = part
        t = re.sub(r'\\dot\{\\(\w+)\}', lambda m: GREEK.get(m.group(1), m.group(1)) + '\u0307', t)
        t = re.sub(r'\\dot\\(\w+)', lambda m: GREEK.get(m.group(1), m.group(1)) + '\u0307', t)
        t = re.sub(r'\\([A-Za-z]+)', lambda m: GREEK.get(m.group(1), m.group(1)), t)
        t = re.sub(r'_\{([^}]*)\}', lambda m: '<sub>' + html.escape(m.group(1)) + '</sub>', t)
        t = re.sub(r'_(\w)', lambda m: '<sub>' + m.group(1) + '</sub>', t)
        t = t.replace('\\,', ' ').replace('\\ ', ' ')
        out.append('<i>' + t + '</i>' if '<sub>' in t or len(t) <= 3 else t)
    return ''.join(out)


class Fig:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.items = []

    # ---- description
    def box(self, x, y, w, h, lines, fill='#ffffff', dashed=False, bold_first=True, stroke='#222222', fs=13):
        self.items.append(('box', x, y, w, h, lines, fill, dashed, bold_first, stroke, fs))

    def frame(self, x, y, w, h, color='#888888'):
        self.items.append(('frame', x, y, w, h, color))

    def text(self, x, y, s, fs=13, ha='center', bold=False, color='#222222', w=None):
        self.items.append(('text', x, y, s, fs, ha, bold, color, w))

    def arrow(self, pts, dashed=False, color='#222222', lw=1.6, head=True):
        self.items.append(('arrow', pts, dashed, color, lw, head))

    def dot(self, x, y):
        self.items.append(('dot', x, y))

    # ---- PNG preview (dpi 100 * scale; font sizes in px)
    def save_png(self, path, scale=2.0):
        fig = plt.figure(figsize=(self.w / 100, self.h / 100), dpi=100)
        ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, self.w); ax.set_ylim(self.h, 0); ax.axis('off')
        px = lambda v: v * 0.72
        for it in self.items:
            k = it[0]
            if k == 'box':
                _, x, y, w, h, lines, fill, dashed, bold_first, stroke, fs = it
                ax.add_patch(Rectangle((x, y), w, h, fc=fill, ec=stroke, lw=1.5, ls='--' if dashed else '-', zorder=2))
                n = len(lines); lh = fs * 1.35
                for j, ln in enumerate(lines):
                    ax.text(x + w / 2, y + h / 2 + (j - (n - 1) / 2) * lh, ln, ha='center', va='center', fontsize=px(fs if j or not bold_first else fs + 1),
                            fontweight='bold' if (j == 0 and bold_first) else 'normal', zorder=3)
            elif k == 'frame':
                _, x, y, w, h, color = it
                ax.add_patch(Rectangle((x, y), w, h, fc='none', ec=color, lw=1.3, ls=(0, (6, 4)), zorder=0))
            elif k == 'text':
                _, x, y, s, fs, ha, bold, color, _w = it
                ax.text(x, y, s, ha=ha, va='center', fontsize=px(fs), fontweight='bold' if bold else 'normal', color=color, zorder=4, linespacing=1.4)
            elif k == 'arrow':
                _, pts, dashed, color, lw, head = it
                body = pts[:-1] if head else pts
                xs, ys = zip(*pts[:-1]) if head else zip(*pts)
                ax.plot(xs, ys, color=color, lw=lw, ls='--' if dashed else '-', zorder=1, solid_capstyle='butt')
                if head:
                    ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle='-|>', mutation_scale=13, color=color, lw=lw, ls='--' if dashed else '-',
                                                 shrinkA=0, shrinkB=0, zorder=1))
            elif k == 'dot':
                ax.plot([it[1]], [it[2]], 'o', color='#222222', ms=6, zorder=5)
        fig.savefig(path, dpi=100 * scale, facecolor='white')
        plt.close(fig)

    # ---- draw.io file
    def save_drawio(self, path):
        cells, nid = [], [2]
        def new_id():
            nid[0] += 1
            return 'b%d' % nid[0]
        for it in self.items:
            k = it[0]
            if k == 'box':
                _, x, y, w, h, lines, fill, dashed, bold_first, stroke, fs = it
                val = '<br>'.join(('<b>%s</b>' % tex2html(l)) if (j == 0 and bold_first) else tex2html(l) for j, l in enumerate(lines))
                st = 'rounded=0;whiteSpace=wrap;html=1;fillColor=%s;strokeColor=%s;fontColor=#222222;fontSize=%d;verticalAlign=middle;align=center;%s' % (
                    fill, stroke, fs - 1, 'dashed=1;' if dashed else '')
                cells.append(self._vertex(new_id(), val, st, x, y, w, h))
            elif k == 'frame':
                _, x, y, w, h, color = it
                cells.append(self._vertex(new_id(), '', 'rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeColor=%s;dashed=1;' % color, x, y, w, h))
            elif k == 'text':
                _, x, y, s, fs, ha, bold, color, tw = it
                lines = s.split('\n'); val = '<br>'.join(tex2html(l) for l in lines)
                if bold:
                    val = '<b>%s</b>' % val
                width = tw or max(24, int(max(len(re.sub(r'[$\\{}_]', '', l)) for l in lines) * fs * 0.62) + 8)
                height = int(fs * 1.5 * len(lines)) + 4
                x0 = x - width / 2 if ha == 'center' else (x if ha == 'left' else x - width)
                st = 'text;html=1;strokeColor=none;fillColor=none;align=%s;verticalAlign=middle;whiteSpace=wrap;fontColor=%s;fontSize=%d;' % (ha, color, fs - 1)
                cells.append(self._vertex(new_id(), val, st, x0, y - height / 2, width, height))
            elif k == 'arrow':
                _, pts, dashed, color, lw, head = it
                st = 'endArrow=%s;html=1;rounded=0;strokeColor=%s;strokeWidth=%.1f;%s' % ('classic' if head else 'none', color, lw, 'dashed=1;' if dashed else '')
                mid = ''.join('<mxPoint x="%g" y="%g"/>' % p for p in pts[1:-1])
                geo = ('<mxGeometry relative="1" as="geometry"><mxPoint x="%g" y="%g" as="sourcePoint"/><mxPoint x="%g" y="%g" as="targetPoint"/>%s</mxGeometry>'
                       % (pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], ('<Array as="points">%s</Array>' % mid) if mid else ''))
                cells.append('<mxCell id="%s" edge="1" parent="1" style="%s" value=""> %s</mxCell>' % (new_id(), st, geo))
            elif k == 'dot':
                cells.append(self._vertex(new_id(), '', 'ellipse;whiteSpace=wrap;html=1;fillColor=#222222;strokeColor=#222222;', it[1] - 3, it[2] - 3, 6, 6))
        xml = ('<mxfile host="drawio"><diagram name="Page-1" id="fig"><mxGraphModel dx="1200" dy="700" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
               'arrows="1" fold="1" page="1" pageScale="1" pageWidth="%d" pageHeight="%d" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
               '%s</root></mxGraphModel></diagram></mxfile>') % (self.w + 40, self.h + 40, '\n'.join(cells))
        open(path, 'w', encoding='utf-8', newline='').write(xml)

    @staticmethod
    def _vertex(i, val, style, x, y, w, h):
        return ('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1"><mxGeometry x="%g" y="%g" width="%g" height="%g" as="geometry"/></mxCell>'
                % (i, html.escape(val, quote=True), style, x, y, w, h))
