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
  [Fig. n. caption | path]    picture (centred, at most text width, at most 15 cm high) followed by the caption in italics (Emphasis)
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
PAGE_BREAK_BEFORE = True          # page break before "1. Introduction": the title page holds the title, the Abstract and the keywords only
EQ_PT = 10                       # display equations and their numbers [pt] (advisor: HTML Code style, 10 pt)
BULLET_NUM_ID = '4'
UNNUMBERED_H1 = ('Abstract', 'Acknowledgements', 'Conflict of Interest', 'References')
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


def figure(doc, caption, path):
    """one figure = one caption. `path` is either one file, or several pictures separated by ' ; ', each written as
    'file@width_cm|panel label': the pictures are inserted as separate pictures one under the other (not merged), each followed by its panel label."""
    parts = [p.strip() for p in path.split(' ; ')]
    for pi, part in enumerate(parts):
        spec, _, label = part.partition('|')
        file_, _, wcm = spec.partition('@')
        full = os.path.join(REPO_ROOT, file_.strip())
        box = doc.add_paragraph(); box.alignment = WD_ALIGN_PARAGRAPH.CENTER
        box.paragraph_format.keep_with_next = True
        if os.path.isfile(full):
            w, h = Image.open(full).size
            width = float(wcm) if wcm else min(TEXT_W, MAX_FIG_H * w / h)
            box.add_run().add_picture(full, width=Cm(min(width, TEXT_W)))
        else:
            print('warning: image not found:', full)
            box.add_run('[insert figure]').italic = True
        if label.strip():
            lab = doc.add_paragraph(); lab.alignment = WD_ALIGN_PARAGRAPH.CENTER
            lab.paragraph_format.keep_with_next = True
            lab.paragraph_format.space_after = Pt(6)
            add_rich(lab, label.strip())
    cap = doc.add_paragraph()
    add_rich(cap, caption, char_style=doc.styles['Emphasis'])


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
    lo = [cm(max(len(w) for c in col(ci) for w in (c.split() or ['']))) for ci in range(ncol)]
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
    keep_table_together(t)
    doc.add_paragraph()


def bullet(doc, text):
    p = doc.add_paragraph(style='List Paragraph')
    pPr = p._p.get_or_add_pPr(); numPr = OxmlElement('w:numPr')
    ilvl = OxmlElement('w:ilvl'); ilvl.set(qn('w:val'), '0'); numId = OxmlElement('w:numId'); numId.set(qn('w:val'), BULLET_NUM_ID)
    numPr.append(ilvl); numPr.append(numId); pPr.append(numPr)
    add_rich(p, text)


def build(txt_path, docx_path):
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
            add_rich(doc.add_paragraph(style='Title'), s); i += 1; continue
        if s in UNNUMBERED_H1 or (h1.match(s) and not h2.match(s) and len(s) < 100):
            hp = doc.add_paragraph(style='Heading 1'); add_rich(hp, s); in_refs = (s == 'References')
            if PAGE_BREAK_BEFORE and h1.match(s) and s.startswith('1.'):
                hp.paragraph_format.page_break_before = True              # title and Abstract stay alone on the first page
            i += 1; continue
        if h2.match(s) and len(s) < 120:
            add_rich(doc.add_paragraph(style='Heading 2'), s); i += 1; continue
        me = eq.match(raw)
        if me and i + 1 < len(lines) and latex.match(lines[i + 1]):
            equation(doc, latex.match(lines[i + 1]).group(1), int(me.group(1))); i += 2; continue
        mf = figcap.match(raw)
        if mf:
            cap, _, path = mf.group(1).partition(' | ')
            figure(doc, cap.strip(), path.strip()); i += 1; continue
        mt = tabcap.match(raw)
        if mt and i + 1 < len(lines) and ' | ' in lines[i + 1]:
            rows = []; j = i + 1
            while j < len(lines) and ' | ' in lines[j]:
                rows.append([c.strip() for c in lines[j].strip().split(' | ')]); j += 1
            table(doc, mt.group(1), rows); i = j; continue
        if s.startswith('- '):
            bullet(doc, s[2:]); i += 1; continue
        p = doc.add_paragraph()
        if s.startswith('Keywords:'):
            r = p.add_run('Keywords:'); r.bold = True
            add_rich(p, s[len('Keywords:'):])
        elif in_refs or s.startswith('\\noindent '):
            add_rich(p, s.replace('\\noindent ', '', 1))
        else:
            p.paragraph_format.first_line_indent = INDENT
            add_rich(p, s)
        i += 1
    doc.save(docx_path)
    print('Wrote', docx_path)


if __name__ == '__main__':
    if sys.argv[1] == '--make-template':
        make_template(sys.argv[2])
    else:
        build(sys.argv[1], sys.argv[2])
