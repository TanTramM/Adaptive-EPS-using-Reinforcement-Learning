"""Quick preview of a .drawio file as PNG (matplotlib), for checking a figure edited by hand in draw.io when draw.io itself is not at hand.

Handles what the figures of the paper use: rectangles (rounded or not), ellipses, text boxes, groups (children are relative to the group), sum-junction ellipses,
edges (straight or with waypoints, dashed, arrow heads at either end, connected edges end on the border of their shapes) and HTML labels (br, sub, sup, b, i).
It is only an approximation of draw.io's own renderer (orthogonal auto-routing of connected edges is drawn straight): use draw.io's File > Export for the final figure.

Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/render_drawio.py Figures/drawio/Fig2_control.drawio [out.png]
"""
import html
import re
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from lxml import etree
from matplotlib.patches import Ellipse, FancyArrowPatch, FancyBboxPatch, Rectangle, Polygon

plt.rcParams.update({'font.family': 'Arial', 'mathtext.fontset': 'custom', 'mathtext.rm': 'Arial', 'mathtext.it': 'Arial:italic', 'mathtext.default': 'it'})


def style_of(s):
    d, first = {}, None
    for tok in (s or '').split(';'):
        if not tok:
            continue
        if '=' in tok:
            k, v = tok.split('=', 1); d[k] = v
        elif first is None:
            first = tok; d[tok] = '1'
        else:
            d[tok] = '1'
    d['_first'] = first
    return d


def clean(value):
    v = value or ''
    v = re.sub(r'<br\s*/?>|</div>|</p>', '\n', v, flags=re.I)
    v = re.sub(r'<sub>(.*?)</sub>', lambda m: '$_{' + re.sub(r'<[^>]+>', '', m.group(1)) + '}$', v, flags=re.I | re.S)
    v = re.sub(r'<sup>(.*?)</sup>', lambda m: '$^{' + re.sub(r'<[^>]+>', '', m.group(1)) + '}$', v, flags=re.I | re.S)
    bold = bool(re.search(r'<b>', v, re.I))
    v = re.sub(r'<[^>]+>', '', v)
    v = html.unescape(v).replace('\u00a0', ' ').strip('\n')
    return v, bold


def num(x, default=0.0):
    try:
        return float(x)
    except (TypeError, ValueError):
        return default


def render(path, out):
    tree = etree.parse(path)
    cells = {c.get('id'): c for c in tree.iter('mxCell')}
    ox, oy = {}, {}

    def origin(cid):
        if cid in ox:
            return ox[cid], oy[cid]
        c = cells[cid]; g = c.find('mxGeometry')
        x = num(g.get('x')) if g is not None else 0.0
        y = num(g.get('y')) if g is not None else 0.0
        p = c.get('parent')
        if p and p in cells and cells[p].get('vertex') == '1':
            px, py = origin(p); x += px; y += py
        ox[cid], oy[cid] = x, y
        return x, y

    boxes = {}
    for cid, c in cells.items():
        if c.get('vertex') == '1' and c.find('mxGeometry') is not None:
            g = c.find('mxGeometry'); x, y = origin(cid)
            boxes[cid] = (x, y, num(g.get('width')), num(g.get('height')))
    allx, ally = [], []
    for b in boxes.values():
        allx += [b[0], b[0] + b[2]]; ally += [b[1], b[1] + b[3]]
    edges = [c for c in cells.values() if c.get('edge') == '1']
    for e in edges:
        for pt in e.iter('mxPoint'):
            allx.append(num(pt.get('x'))); ally.append(num(pt.get('y')))
    pad = 30
    x0, x1, y0, y1 = min(allx) - pad, max(allx) + pad, min(ally) - pad, max(ally) + pad
    W, H = x1 - x0, y1 - y0
    fig = plt.figure(figsize=(W / 100, H / 100), dpi=100)
    ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(x0, x1); ax.set_ylim(y1, y0); ax.axis('off')
    px = lambda v: v * 0.72

    def col(s, default):
        if s is None:
            return default
        if s in ('none', 'None'):
            return 'none'
        m = re.match(r'light-dark\(\s*([^,]+),', s)           # draw.io dark-mode syntax: use the light colour
        if m:
            s = m.group(1).strip()
        return s if s != 'default' else default

    for cid, (x, y, w, h) in boxes.items():
        c = cells[cid]; st = style_of(c.get('style')); first = st['_first']
        if c.get('parent') in cells and cells[c.get('parent')].get('edge') == '1':
            continue
        fill = col(st.get('fillColor'), '#ffffff'); stroke = col(st.get('strokeColor'), '#000000'); lw = num(st.get('strokeWidth'), 1.0)
        ls = '--' if st.get('dashed') == '1' else '-'
        is_text = first == 'text' or st.get('text') == '1'
        label, bold = clean(c.get('value'))
        if first == 'group' or (st.get('group') == '1'):
            continue
        if not is_text:
            if first == 'ellipse' or 'ellipse' in (st.get('shape') or '') or st.get('shape') in ('sumEllipse',):
                ax.add_patch(Ellipse((x + w / 2, y + h / 2), w, h, fc=fill, ec=stroke, lw=lw, ls=ls, zorder=2))
                if st.get('shape') == 'sumEllipse':
                    d = 0.3 * w
                    ax.plot([x + w / 2 - d, x + w / 2 + d], [y + h / 2 - d, y + h / 2 + d], c=stroke, lw=lw, zorder=3)
                    ax.plot([x + w / 2 - d, x + w / 2 + d], [y + h / 2 + d, y + h / 2 - d], c=stroke, lw=lw, zorder=3)
            elif st.get('shape') == 'triangle' or first == 'triangle':
                ax.add_patch(Polygon([(x, y), (x + w, y + h / 2), (x, y + h)], closed=True, fc=fill, ec=stroke, lw=lw, zorder=2))
            elif st.get('rounded') == '1':
                ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0,rounding_size=%g' % (0.12 * min(w, h)), fc=fill, ec=stroke, lw=lw, ls=ls, zorder=2))
            else:
                ax.add_patch(Rectangle((x, y), w, h, fc=fill, ec=stroke, lw=lw, ls=ls, zorder=0 if fill == 'none' else 1))
        if label:
            fs = num(st.get('fontSize'), 12)
            ha = {'left': 'left', 'right': 'right'}.get(st.get('align'), 'center')
            va = {'top': 'top', 'bottom': 'bottom'}.get(st.get('verticalAlign'), 'center')
            tx = x + (4 if ha == 'left' else (w - 4 if ha == 'right' else w / 2))
            ty = y + (4 if va == 'top' else (h - 4 if va == 'bottom' else h / 2))
            ax.text(tx, ty, label, ha=ha, va=va, fontsize=px(fs), fontweight='bold' if (bold or st.get('fontStyle') in ('1', '3')) else 'normal',
                    fontstyle='italic' if st.get('fontStyle') in ('2', '3') else 'normal', color=col(st.get('fontColor'), '#000000'), zorder=5, linespacing=1.2,
                    rotation=-num(st.get('rotation')))

    for e in edges:
        st = style_of(e.get('style'))
        g = e.find('mxGeometry')
        pts = []
        src = tgt = None
        if g is not None:
            for pt in g.findall('mxPoint'):
                if pt.get('as') == 'sourcePoint':
                    src = (num(pt.get('x')), num(pt.get('y')))
                elif pt.get('as') == 'targetPoint':
                    tgt = (num(pt.get('x')), num(pt.get('y')))
            arr = g.find("Array[@as='points']")
            if arr is not None:
                pts = [(num(p.get('x')), num(p.get('y'))) for p in arr.findall('mxPoint')]
        sid, tid = e.get('source'), e.get('target')

        def center(cid):
            b = boxes.get(cid)
            return None if b is None else (b[0] + b[2] / 2, b[1] + b[3] / 2)

        def border(cid, toward):
            b = boxes.get(cid)
            if b is None:
                return toward
            cx, cy = b[0] + b[2] / 2, b[1] + b[3] / 2
            dx, dy = toward[0] - cx, toward[1] - cy
            if dx == 0 and dy == 0:
                return (cx, cy)
            sx = (b[2] / 2) / abs(dx) if dx else 1e9; sy = (b[3] / 2) / abs(dy) if dy else 1e9
            s = min(sx, sy)
            return (cx + dx * s, cy + dy * s)
        if sid in boxes:
            nxt = pts[0] if pts else (center(tid) if tid in boxes else (tgt or center(sid)))
            src = border(sid, nxt)
        if tid in boxes:
            prv = pts[-1] if pts else (center(sid) if sid in boxes else (src or center(tid)))
            tgt = border(tid, prv)
        if src is None or tgt is None:
            continue
        line = [src] + pts + [tgt]
        color = col(st.get('strokeColor'), '#000000'); lw = num(st.get('strokeWidth'), 1.0)
        ls = '--' if st.get('dashed') == '1' else '-'
        xs, ys = zip(*line)
        ax.plot(xs, ys, color=color, lw=lw, ls=ls, zorder=1, solid_joinstyle='miter')
        endA = st.get('endArrow', 'classic'); startA = st.get('startArrow', 'none')
        if endA != 'none':
            ax.add_patch(FancyArrowPatch(line[-2], line[-1], arrowstyle='-|>', mutation_scale=12 + 2 * lw, color=color, lw=lw, shrinkA=0, shrinkB=0, zorder=2))
        if startA != 'none':
            ax.add_patch(FancyArrowPatch(line[1], line[0], arrowstyle='-|>', mutation_scale=12 + 2 * lw, color=color, lw=lw, shrinkA=0, shrinkB=0, zorder=2))
        lab, _ = clean(e.get('value'))
        if lab:
            mx, my = (src[0] + tgt[0]) / 2, (src[1] + tgt[1]) / 2
            ax.text(mx, my - 8, lab, ha='center', va='bottom', fontsize=px(num(st.get('fontSize'), 12)), zorder=5)
    fig.savefig(out, dpi=100, facecolor='white')
    plt.close(fig)
    print('rendered', path, '->', out, '| %d shapes, %d edges' % (len(boxes), len(edges)))


if __name__ == '__main__':
    src = sys.argv[1]
    render(src, sys.argv[2] if len(sys.argv) > 2 else src.rsplit('.', 1)[0] + '_preview.png')
