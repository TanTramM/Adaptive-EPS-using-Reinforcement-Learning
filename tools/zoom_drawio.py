"""Scale a draw.io file (uncompressed XML) by a factor, keeping the drawing exactly as it is, only larger.

Everything that has a size is multiplied: geometry (x, y, width, height), edge points and offsets, page size, stroke widths, arrow sizes, font sizes (style
fontSize and inline "font-size: Npx" of HTML labels).  Cells that have no explicit stroke width or font size get the draw.io defaults (1 and 12) multiplied, so
the zoomed copy looks like the original at 'factor' times the size.  Rotation, colours, text and structure are untouched.

Usage: python tools/zoom_drawio.py <in.drawio> <out.drawio> [factor=2]
"""
import re
import sys
import xml.etree.ElementTree as ET


def num(s, f):
    v = float(s) * f
    return ('%d' % round(v)) if abs(v - round(v)) < 1e-9 else ('%g' % v)


def scale_style(style, f, has_text, is_edge, is_group):
    parts = [p for p in style.split(';') if p]
    keys = {p.split('=')[0]: p for p in parts}
    out = []
    for p in parts:
        k, _, v = p.partition('=')
        if k in ('strokeWidth', 'fontSize', 'startSize', 'endSize', 'spacing', 'spacingTop', 'spacingLeft', 'spacingBottom', 'spacingRight', 'dashPattern'):
            if k == 'dashPattern':
                v = ' '.join(num(t, f) for t in v.split())
            else:
                v = num(v, f)
            out.append('%s=%s' % (k, v))
        else:
            out.append(p)
    if 'strokeWidth' not in keys and not is_group and 'strokeColor=none' not in style:
        out.append('strokeWidth=%s' % num(1, f))
    if has_text and 'fontSize' not in keys:
        out.append('fontSize=%s' % num(12, f))
    return ';'.join(out) + (';' if out else '')


def main(src, dst, f, fit=False):
    tree = ET.parse(src)
    root = tree.getroot()
    for g in root.iter('mxGraphModel'):
        for a in ('dx', 'dy', 'pageWidth', 'pageHeight'):
            if g.get(a) is not None:
                g.set(a, num(g.get(a), f))
    for c in root.iter('mxCell'):
        val = c.get('value') or ''
        if 'font-size' in val:
            val = re.sub(r'font-size:\s*([0-9.]+)px', lambda m: 'font-size: %spx' % num(m.group(1), f), val)
            c.set('value', val)
        style = c.get('style')
        if style is not None:
            has_text = bool(val.strip()) and 'font-size' not in val
            c.set('style', scale_style(style, f, has_text, c.get('edge') == '1', 'group' in style.split(';')))
        for geo in c.iter('mxGeometry'):
            for a in ('x', 'y', 'width', 'height'):
                if geo.get(a) is not None:
                    geo.set(a, num(geo.get(a), f))
            for pt in geo.iter('mxPoint'):
                for a in ('x', 'y'):
                    if pt.get(a) is not None:
                        pt.set(a, num(pt.get(a), f))
    if fit:
        fit_page(root, 60 * f / 2)
    tree.write(dst, encoding='utf-8', xml_declaration=False)
    print('wrote', dst, 'x%g' % f + (', moved onto the page' if fit else ''))


def fit_page(root, margin):
    """move the top-level cells so that the drawing starts at (margin, margin) and set the page size to the drawing plus the margin on every side, so that an
    export by page (PDF, print) neither cuts the drawing nor leaves a blank area (the page of a drawing that was edited far from the origin may not contain it)"""
    top = [c for c in root.iter('mxCell') if c.get('parent') == '1' and c.find('mxGeometry') is not None]
    xs, ys = [], []
    for c in top:
        ge = c.find('mxGeometry')
        if c.get('edge') == '1':
            for pt in ge.iter('mxPoint'):
                xs.append(float(pt.get('x'))); ys.append(float(pt.get('y')))
        elif ge.get('x') is not None:
            x, y, w, h = (float(ge.get(a)) for a in ('x', 'y', 'width', 'height'))
            xs += [x, x + w]; ys += [y, y + h]
    dx, dy = margin - min(xs), margin - min(ys)
    for c in top:
        ge = c.find('mxGeometry')
        if c.get('edge') == '1':
            for pt in ge.iter('mxPoint'):
                pt.set('x', num(float(pt.get('x')) + dx, 1)); pt.set('y', num(float(pt.get('y')) + dy, 1))
        elif ge.get('x') is not None:
            ge.set('x', num(float(ge.get('x')) + dx, 1)); ge.set('y', num(float(ge.get('y')) + dy, 1))
    g = next(root.iter('mxGraphModel'))
    g.set('pageWidth', num(max(xs) - min(xs) + 2 * margin, 1)); g.set('pageHeight', num(max(ys) - min(ys) + 2 * margin, 1))
    g.set('dx', '0'); g.set('dy', '0')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] != '--fit' else 2.0, fit='--fit' in sys.argv)
