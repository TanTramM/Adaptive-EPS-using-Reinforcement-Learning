"""Build the paper .docx from Documents/Paper/paper.txt in the journal layout of the advisor's revision (2026.10.13_Paper_Tan - v5-Huypt.docx).

Usage:  python tools/paper2docx.py Documents/Paper/paper.txt Documents/Paper/paper.docx
        python tools/paper2docx.py --make-template "<advisor .docx>"     (once: writes tools/journal_template.docx)

The template is the advisor's .docx with its body emptied, so the page (A4, 2.54 cm margins), the footer "Page X of Y", the styles
(Times New Roman 12 pt, line spacing 1.5, justified, Title, Heading 1 bold 14 pt, Heading 2 italic 13 pt, List Paragraph, Table Grid,
Strong, Emphasis) and the bullet list (numId 4) are exactly the advisor's.

Format rules taken from the advisor's revision:
  title                  style Title (bold 16 pt); no author line
  Abstract, 1. ..., Acknowledgements, Conflict of Interest, References     style Heading 1, numbers kept in the text
  2.1. ...               style Heading 2 (italic), number kept
  body paragraph         first-line indent 1.27 cm; a line starting with '\\noindent ' has no indent (e.g. 'where ...' after an equation)
  Keywords: ...          no indent, label bold
  - item                 bullet (List Paragraph, numId 4)
  (n) ascii + [ latex ]  display equation at 10 pt, one number per line, '#(n)' equation array so Word puts (n) at the right margin
  [Fig. n. caption | path]    ONE inline drawing group: picture (centred, at most text width, at most 15 cm high) + a borderless text box with the caption in italics (Emphasis)
  Table n. caption       caption in bold (Strong) above the table; following ' | ' rows: Table Grid, centred, header row bold and centred,
                         body left-aligned, rows kept on one page
  [n] reference          no indent; *text* is italic (journal or book titles)
  $latex$                inline Word equation
"""
import os
import re
import sys
from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import txt2docx
from txt2docx import latex_to_omath, m, msub, run, M_NS, REPO_ROOT
txt2docx.AUTO_PAREN = True            # every matched round bracket in the equations becomes a stretchy bracket

TEMPLATE = os.path.join(REPO_ROOT, 'tools', 'journal_template.docx')
TEXT_W = 21.0 - 2 * 2.54          # A4 width minus the advisor's margins [cm]
MAX_FIG_H = 15.0                  # [cm]
INDENT = Cm(1.27)                 # 720 twips, the advisor's first-line indent
PAGE_BREAK_BEFORE = True          # page break before every numbered main section (1. Introduction ... 6. Conclusions); the title page holds the title, authors, Abstract and keywords only
EQ_PT = 10                       # display equations and their numbers [pt] (advisor: HTML Code style, 10 pt)
BULLET_NUM_ID = '4'
UNNUMBERED_H1 = ('Abstract', 'Acknowledgements', 'Acknowledgments', 'Author contributions', 'Declaration of Generative AI', 'Conflict of Interest', 'References')
RICH = re.compile(r'\$(.+?)\$|\*(.+?)\*')


def make_template(src, dst=TEMPLATE):
    doc = Document(src)
    body = doc.element.body
    for el in list(body):
        if el.tag != qn('w:sectPr'):
            body.remove(el)
    xml = doc.element.xml
    for rid, rel in list(doc.part.rels.items()):
        if rel.reltype.endswith('/image') and ('"%s"' % rid) not in xml:
            del doc.part.rels[rid]
    doc.save(dst)
    print('Wrote', dst)


def add_rich(p, text, bold=False, italic=False, char_style=None):
    pos = 0
    def plain(s, it):
        if s:
            r = p.add_run(s); r.bold = bold or None; r.italic = it or None
            if char_style:
                r.style = char_style
    for mm in RICH.finditer(text):
        plain(text[pos:mm.start()], italic)
        if mm.group(1) is not None:
            p._p.append(latex_to_omath(mm.group(1)))
        else:
            plain(mm.group(2), True)
        pos = mm.end()
    plain(text[pos:], italic)


def equation(doc, latex, num, style=None):
    p = doc.add_paragraph(style=style)
    para = m('oMathPara'); om = msub(para, 'oMath'); arr = msub(om, 'eqArr')
    pr = msub(arr, 'eqArrPr'); md = msub(pr, 'maxDist'); md.set('{%s}val' % M_NS, '1')
    e = msub(arr, 'e')
    e.extend(list(latex_to_omath(latex)))
    e.append(run('#', upright=True))
    d = msub(e, 'd'); de = msub(d, 'e'); de.append(run(str(num), upright=True))
    for r in para.iter('{%s}r' % M_NS):                      # display equations and their numbers at 10 pt, as in the advisor's file
        rpr = OxmlElement('w:rPr')
        for tag in ('w:sz', 'w:szCs'):
            el = OxmlElement(tag); el.set(qn('w:val'), str(2 * EQ_PT)); rpr.append(el)
        mrpr = r.find('{%s}rPr' % M_NS)
        r.insert(0 if mrpr is None else 1, rpr)
    p._p.append(para)


NS_DECL = ('xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
           'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
           'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
           'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
           'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
           'xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" '
           'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"')
_gid = [100]


def _textbox_xml(nid, x, y, w, h):
    return (f'<wps:wsp><wps:cNvPr id="{nid}" name="Text box {nid}"/><wps:cNvSpPr txBox="1"/>'
            f'<wps:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{w}" cy="{h}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
            f'<a:noFill/><a:ln><a:noFill/></a:ln></wps:spPr><wps:txbx><w:txbxContent/></wps:txbx>'
            f'<wps:bodyPr rot="0" vert="horz" wrap="square" lIns="0" tIns="0" rIns="0" bIns="0" anchor="t" anchorCtr="0"><a:noAutofit/></wps:bodyPr></wps:wsp>')


def caption_lines(text, width_cm):
    """number of lines the caption takes in 12 pt Times italic at the given width, from the real glyph widths (greedy word wrap, 3 % safety)"""
    try:
        from PIL import ImageFont
        font = ImageFont.truetype('C:/Windows/Fonts/timesi.ttf', 120)          # 120 px stand for 12 pt: 1 px = 0.1 pt = 0.003528 cm
        cm = lambda t: font.getlength(t) * 0.003528
    except Exception:
        cm = lambda t: 0.21 * len(t)
    lines, cur = 1, ''
    for w in text.split():
        trial = (cur + ' ' + w).strip()
        if cm(trial) > 0.93 * width_cm and cur:
            lines += 1; cur = w
        else:
            cur = trial
    return lines


def figure_group(doc, items, caption):
    """ONE inline drawing group = the picture(s) + a borderless text box with the caption (and, for several pictures, a small text box with each panel
    label). Picture and caption are one object, so they cannot drift apart when the author reformats the text.
    items = [(file, width_cm, height_cm, panel_label or '')]"""
    from docx.text.paragraph import Paragraph
    from docx.oxml import parse_xml
    emu = lambda cm: int(round(cm * 360000))
    gap = emu(0.15)
    cw = emu(TEXT_W)
    _gid[0] += 1
    n0 = _gid[0] * 10
    y = 0; k = 0
    shapes = []; boxes = []
    for (full, wcm, hcm, label) in items:
        rid, _ = doc.part.get_or_add_image(full)
        pw, ph = emu(wcm), emu(hcm)
        x = (cw - pw) // 2
        k += 1
        shapes.append(
            f'<pic:pic><pic:nvPicPr><pic:cNvPr id="{n0 + k}" name="Picture {n0 + k}"/><pic:cNvPicPr/></pic:nvPicPr>'
            f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            f'<pic:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{pw}" cy="{ph}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>')
        y += ph + gap
        if label:
            lh = emu(0.60); k += 1
            shapes.append(_textbox_xml(n0 + k, 0, y, cw, lh)); boxes.append((label, False))
            y += lh + gap
    # inline math is typeset as an equation: wider than plain text and it raises the line height, so the estimate keeps its symbols (LaTeX
    # commands counted as one character) and every line gets extra height; a box that is too short cuts the last line in Word
    plain = re.sub(r'\$([^$]*)\$', lambda m: re.sub(r'[{}\\_^]', '', re.sub(r'\\[A-Za-z]+', 'x', m.group(1))) + 'x', caption)
    lines = caption_lines(plain, TEXT_W)
    cap_h = emu(0.4 + (0.62 if '$' in caption else 0.52) * lines)       # 12 pt Times is about 0.49 cm per line, a line with an equation about 0.6 cm
    k += 1
    shapes.append(_textbox_xml(n0 + k, 0, y, cw, cap_h)); boxes.append((caption, True))
    total_h = y + cap_h
    xml = (
        f'<w:drawing {NS_DECL}><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cw}" cy="{total_h}"/>'
        f'<wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="{n0}" name="Figure group {n0}"/><wp:cNvGraphicFramePr/>'
        f'<a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"><wpg:wgp><wpg:cNvGrpSpPr/>'
        f'<wpg:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cw}" cy="{total_h}"/><a:chOff x="0" y="0"/><a:chExt cx="{cw}" cy="{total_h}"/></a:xfrm></wpg:grpSpPr>'
        + ''.join(shapes) + '</wpg:wgp></a:graphicData></a:graphic></wp:inline></w:drawing>')
    el = parse_xml(xml)
    for content, (text, is_cap) in zip(el.iter(qn('w:txbxContent')), boxes):
        p_el = OxmlElement('w:p'); content.append(p_el)
        par = Paragraph(p_el, doc._body)
        par.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.first_line_indent = Cm(0)
        par.paragraph_format.space_before = Pt(0); par.paragraph_format.space_after = Pt(0)
        par.paragraph_format.line_spacing = 1.0
        add_rich(par, text, char_style=doc.styles['Emphasis'] if is_cap else None)
    return el


def figure(doc, caption, path):
    """one figure = one group (pictures + caption). `path` is one file, or several pictures separated by ' ; ', each written as
    'file@width_cm|panel label': the pictures go one under the other inside the same group, each followed by its panel label."""
    items = []
    for part in [p.strip() for p in path.split(' ; ')]:
        spec, _, label = part.partition('|')
        file_, _, wcm = spec.partition('@')
        full = os.path.join(REPO_ROOT, file_.strip())
        if label.strip() == 'side' and ' ; ' not in path:        # 'file@width|side': picture on the left, caption on the right, in a borderless two-column table
            return figure_side(doc, caption, full, float(wcm))
        w, h = Image.open(full).size
        width = min(float(wcm) if wcm else min(TEXT_W, MAX_FIG_H * w / h), TEXT_W)
        items.append((full, width, width * h / w, label.strip()))
    box = doc.add_paragraph(); box.alignment = WD_ALIGN_PARAGRAPH.CENTER
    box.paragraph_format.keep_together = True
    box.add_run()._r.append(figure_group(doc, items, caption))


def figure_side(doc, caption, full, width_cm):
    """A small figure: the picture (width_cm wide) in the left cell and the caption (italic) in the right cell of a one-row table without borders."""
    t = doc.add_table(rows=1, cols=2); t.alignment = WD_TABLE_ALIGNMENT.CENTER; t.autofit = False
    tblPr = t._tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        b = OxmlElement('w:' + side); b.set(qn('w:val'), 'nil'); borders.append(b)
    tblPr.append(borders)
    left, right = t.rows[0].cells
    left.width = Cm(width_cm + 0.3); right.width = Cm(TEXT_W - width_cm - 0.3)
    for cell in (left, right):
        tcPr = cell._tc.get_or_add_tcPr(); va = OxmlElement('w:vAlign'); va.set(qn('w:val'), 'center'); tcPr.append(va)
    p = left.paragraphs[0]; p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Cm(0); p.paragraph_format.space_after = Pt(0); p.paragraph_format.line_spacing = 1.0
    p.add_run().add_picture(full, width=Cm(width_cm))
    q = right.paragraphs[0]; q.alignment = WD_ALIGN_PARAGRAPH.LEFT
    q.paragraph_format.first_line_indent = Cm(0); q.paragraph_format.space_after = Pt(0); q.paragraph_format.line_spacing = 1.0
    add_rich(q, caption, char_style=doc.styles['Emphasis'])
    keep_table_together(t)
    sp = doc.add_paragraph(); sp.paragraph_format.space_after = Pt(0)
    sp.add_run().font.size = Pt(6)


def keep_table_together(table):
    rows = table.rows
    for ri, row in enumerate(rows):
        trPr = row._tr.get_or_add_trPr()
        cs = OxmlElement('w:cantSplit'); trPr.append(cs)
        if ri < len(rows) - 1:
            for cell in row.cells:
                for p in cell.paragraphs:
                    p.paragraph_format.keep_with_next = True


def table(doc, caption, rows):
    cap = doc.add_paragraph(); cap.paragraph_format.keep_with_next = True
    add_rich(cap, caption, char_style=doc.styles['Strong'])
    ncol = max(len(r) for r in rows)
    t = doc.add_table(rows=len(rows), cols=ncol); t.style = doc.styles['Table Grid']
    t.alignment = WD_TABLE_ALIGNMENT.CENTER; t.autofit = False
    plain = lambda x: re.sub(r'\$(.+?)\$', lambda q: 'x' * max(2, len(q.group(1)) // 3), x)
    col = lambda ci: [plain(r[ci]) for r in rows if ci < len(r)]
    # widths in cm for 12 pt Times (about 0.22 cm per character, 0.5 cm cell padding): no column narrower than its longest word,
    # each column as wide as its longest cell when the table fits the text width, else the spare width shared by the overflow
    cm = lambda n: 0.22 * n + 0.5
    lo = [cm(max(len(w) + (1 if k == 0 else 0) for k, c in enumerate(col(ci)) for w in (c.split() or ['']))) for ci in range(ncol)]   # +1: bold header
    hi = [max(lo[ci], cm(max(len(c) for c in col(ci)))) for ci in range(ncol)]
    if sum(hi) <= TEXT_W:
        widths = hi
    else:
        spare = max(0.0, TEXT_W - sum(lo)); extra = [h - l for h, l in zip(hi, lo)]
        widths = [l + spare * e / sum(extra) for l, e in zip(lo, extra)]
    # a body column holding numbers and symbols is centred; a column of descriptive words stays left-aligned
    def wordy(c):
        return any(len(w) >= 4 and w.isalpha() and not w.isupper() for w in re.split(r'[^A-Za-z]+', re.sub(r'\$.+?\$', '', c)))
    centred = [sum(wordy(r[ci]) for r in rows[1:] if ci < len(r)) * 2 < max(1, len(rows) - 1) for ci in range(ncol)]
    for ri, rw in enumerate(rows):
        for ci in range(ncol):
            cell = t.rows[ri].cells[ci]; cell.width = Cm(widths[ci]); p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if (ri == 0 or centred[ci]) else WD_ALIGN_PARAGRAPH.LEFT
            add_rich(p, rw[ci] if ci < len(rw) else '', bold=(ri == 0))
            p.paragraph_format.line_spacing = 1.0          # single spacing inside tables (the text keeps 1.5)
    keep_table_together(t)
    doc.add_paragraph()


def bullet(doc, text):
    p = doc.add_paragraph(style='List Paragraph')
    pPr = p._p.get_or_add_pPr(); numPr = OxmlElement('w:numPr')
    ilvl = OxmlElement('w:ilvl'); ilvl.set(qn('w:val'), '0'); numId = OxmlElement('w:numId'); numId.set(qn('w:val'), BULLET_NUM_ID)
    numPr.append(ilvl); numPr.append(numId); pPr.append(numPr)
    add_rich(p, text)



# Title-page data required by the journal (JSTT guide for authors: given and family name, full postal address with country, corresponding author marked * with e-mail)
AUTHORS = [('Minh Tan Tram', '1,*'), ('Thanh Huy Phung', '1')]
AFFILIATION = ('1', 'Ho Chi Minh City University of Technology (HCMUT), Vietnam National University Ho Chi Minh City (VNU-HCM), '
                    '268 Ly Thuong Kiet Street, Ho Chi Minh City, Vietnam')
CORRESPONDING = '*Corresponding author: Minh Tan Tram, e-mail: tmtan.sdh241@hcmut.edu.vn'
EMAILS = 'Thanh Huy Phung, e-mail: huypt@hcmut.edu.vn'


def front_matter(doc):
    """author line, affiliation and corresponding author, centred under the title"""
    def centred(parts, italic=False, size=None):
        par = doc.add_paragraph()
        par.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.first_line_indent = Cm(0)
        for text, sup in parts:
            r = par.add_run(text); r.italic = italic or None
            if sup:
                r.font.superscript = True
            if size:
                r.font.size = Pt(size)
        return par
    parts = []
    for k, (name, aff) in enumerate(AUTHORS):
        parts += [(name, False), (aff, True)]
        if k < len(AUTHORS) - 1:
            parts.append((', ', False))
    centred(parts)
    centred([(AFFILIATION[0], True), (AFFILIATION[1], False)], italic=True, size=11)
    centred([(CORRESPONDING, False)], size=11)
    centred([(EMAILS, False)], size=11)

def build(txt_path, docx_path, through=None):
    lines = open(txt_path, encoding='utf-8').read().splitlines()
    doc = Document(TEMPLATE)
    sep = re.compile(r'^\s*(=|-){20,}\s*$')
    h1 = re.compile(r'^\d+\.\s+\S')
    h2 = re.compile(r'^\d+\.\d+\.\s+\S')
    eq = re.compile(r'^\s*\((\d+)\)\s+(.*)$')
    latex = re.compile(r'^\s*\[\s(.*)\s\]\s*$')
    figcap = re.compile(r'^\s*\[((?:Fig\.|Figure)\s+\d+[.:].*)\]\s*$')
    tabcap = re.compile(r'^\s*(Table\s+\d+[.:].*)$')
    seps = [i for i, l in enumerate(lines) if re.match(r'^\s*={20,}\s*$', l)]
    title_idx = seps[0] + 1 if len(seps) >= 2 else None
    in_refs = False
    i = 0
    while i < len(lines):
        raw = lines[i]; s = raw.strip()
        if not s or sep.match(raw):
            i += 1; continue
        if i == title_idx:
            add_rich(doc.add_paragraph(style='Title'), s); front_matter(doc); i += 1; continue
        if h1.match(s) and not h2.match(s) and through is not None and int(s.split('.', 1)[0]) > through:
            break
        if s in UNNUMBERED_H1 or (h1.match(s) and not h2.match(s) and len(s) < 100):
            hp = doc.add_paragraph(style='Heading 1'); add_rich(hp, s); in_refs = (s == 'References')
            if PAGE_BREAK_BEFORE and (h1.match(s) or s in ('Acknowledgments', 'Acknowledgements', 'References')):
                hp.paragraph_format.page_break_before = True              # every numbered section and the reference list start a new page
            i += 1; continue
        if h2.match(s) and len(s) < 120:
            add_rich(doc.add_paragraph(style='Heading 2'), s); i += 1; continue
        me = eq.match(raw)
        if me and i + 1 < len(lines) and latex.match(lines[i + 1]):
            equation(doc, latex.match(lines[i + 1]).group(1), int(me.group(1))); i += 2; continue
        mf = figcap.match(raw)
        if mf:
            cap, _, path = mf.group(1).partition(' | ')
            path = path.strip(); newpage = path.endswith('|newpage')         # 'file@width|newpage': the figure starts a new page
            n0 = len(doc.paragraphs)
            figure(doc, cap.strip(), path[:-len('|newpage')] if newpage else path)
            if newpage:
                doc.paragraphs[n0].paragraph_format.page_break_before = True
            i += 1; continue
        mt = tabcap.match(raw)
        if mt and i + 1 < len(lines) and ' | ' in lines[i + 1]:
            rows = []; j = i + 1
            while j < len(lines) and ' | ' in lines[j]:
                rows.append([c.strip() for c in lines[j].strip().split(' | ')]); j += 1
            table(doc, mt.group(1), rows); i = j; continue
        if s.startswith('- '):
            bullet(doc, s[2:]); i += 1; continue
        p = doc.add_paragraph()
        # a paragraph may be wrapped over several lines of the .txt (Documents rule: 180-200 characters per line): the lines up to the next blank line,
        # heading, equation, figure, table caption, bullet or the Keywords line belong to it (references stay one per line)
        j = i + 1
        if not in_refs and not s.startswith('Keywords:'):
            def stops(k):
                t = lines[k]; u = t.strip()
                return (not u or sep.match(t) or h1.match(u) or h2.match(u) or eq.match(t) or latex.match(t) or figcap.match(t) or tabcap.match(t)
                        or u.startswith('- ') or u.startswith('Keywords:') or u.startswith('\\noindent ') or u in UNNUMBERED_H1)
            while j < len(lines) and not stops(j):
                s += ' ' + lines[j].strip(); j += 1
        if s.startswith('Keywords:'):
            r = p.add_run('Keywords:'); r.bold = True
            add_rich(p, s[len('Keywords:'):])
        elif in_refs or s.startswith('\\noindent '):
            add_rich(p, s.replace('\\noindent ', '', 1))
        else:
            p.paragraph_format.first_line_indent = INDENT
            add_rich(p, s)
        if not in_refs and s.rstrip().endswith(':'):
            p.paragraph_format.keep_with_next = True               # a lead-in ending with a colon stays on the same page as the equation that follows
        i = j
    doc.save(docx_path)
    print('Wrote', docx_path)


if __name__ == '__main__':
    if sys.argv[1] == '--make-template':
        make_template(sys.argv[2])
    else:
        through = int(sys.argv[sys.argv.index('--through') + 1]) if '--through' in sys.argv else None
        build(sys.argv[1], sys.argv[2], through)
