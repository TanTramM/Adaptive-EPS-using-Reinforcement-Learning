"""Convert a thesis chapter written in the Documents/ .txt convention into a Word .docx.

Usage:  python tools/txt2docx.py Documents/Plant/plant.txt Documents/Plant/plant.docx

Text conventions (one logical item per line, no hard wrapping):
  ====...  / ----...        separator lines, ignored
  line between the first two '====' lines   chapter title  -> Heading 1
  "1. Title"                 section         -> Heading 2 (number removed, Word numbering applies)
  "1.1. Title"               subsection      -> Heading 3 (number removed)
  "  (n)  ascii formula"     equation line, the NEXT line "  [ latex ]" is converted to a native Word
                             equation (OMML) and numbered (n) at the right margin
  "  Bảng n: caption"        table caption; following lines containing " | " are the table rows
                             (first row = header) until a blank line
  "  [Hình n: caption]"      figure placeholder (empty box + caption)
  "  [Hình n: caption | path/to/image.png]"   figure with the image inserted (path relative to the repo root;
                             if the file is missing a placeholder is used and a warning printed)
  any other non-empty line   body paragraph (justified)

LaTeX subset supported: \\frac \\dfrac \\tfrac, _ ^, \\dot \\ddot \\hat, \\sqrt, Greek letters,
\\sin \\tan \\tanh \\arctan \\max \\min \\text{}, \\mathcal, \\left \\right \\big \\Big, bmatrix,
spacing commands, \\le \\ge \\approx \\cdot \\Leftrightarrow \\Rightarrow.
"""
import os
import re
import sys
from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, Cm, RGBColor
from lxml import etree

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
W_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'


def m(tag):
    return etree.Element('{%s}%s' % (M_NS, tag))


def msub(parent, tag):
    return etree.SubElement(parent, '{%s}%s' % (M_NS, tag))


# ----------------------------------------------------------------------------- LaTeX -> OMML
GREEK = {'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε', 'zeta': 'ζ', 'eta': 'η',
         'theta': 'θ', 'kappa': 'κ', 'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'pi': 'π', 'rho': 'ρ',
         'sigma': 'σ', 'tau': 'τ', 'phi': 'φ', 'varphi': 'φ', 'psi': 'ψ', 'omega': 'ω', 'Delta': 'Δ',
         'Omega': 'Ω', 'Sigma': 'Σ', 'Phi': 'Φ', 'Psi': 'Ψ', 'Gamma': 'Γ', 'Theta': 'Θ'}
SYMBOLS = {'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'approx': '≈', 'cdot': '·', 'times': '×',
           'Leftrightarrow': '⇔', 'Rightarrow': '⇒', 'rightarrow': '→', 'to': '→', 'infty': '∞',
           'partial': '∂', 'circ': '°', 'pm': '±', 'neq': '≠', 'sum': '∑', 'in': '∈', 'ldots': '…',
           'dots': '…', 'cdots': '⋯'}
FUNCS = {'sin', 'cos', 'tan', 'tanh', 'arctan', 'max', 'min', 'exp', 'ln', 'log', 'sgn', 'sign'}
SPACES = {'quad': ' ', 'qquad': '  ', ';': ' ', ',': ' ', ':': ' ',
          '!': '', ' ': ' '}
DELIMS = {'left', 'right', 'big', 'Big', 'bigg', 'Bigg', 'bigl', 'bigr', 'Bigl', 'Bigr'}
MATHCAL = {'F': 'ℱ', 'L': 'ℒ', 'H': 'ℋ'}


def tokenize(s):
    toks, i = [], 0
    while i < len(s):
        ch = s[i]
        if ch == '\\':
            j = i + 1
            if j < len(s) and s[j].isalpha():
                while j < len(s) and s[j].isalpha():
                    j += 1
                toks.append(('cmd', s[i + 1:j]))
                i = j
            else:
                toks.append(('cmd', s[j] if j < len(s) else ''))
                i = j + 1
        elif ch in '{}^_&':
            toks.append((ch, ch)); i += 1
        elif ch.isspace():
            i += 1
        else:
            toks.append(('chr', ch)); i += 1
    return toks


def run(text, upright=False):
    r = m('r')
    if upright:
        rpr = msub(r, 'rPr'); sty = msub(rpr, 'sty'); sty.set('{%s}val' % M_NS, 'p')
    t = msub(r, 't'); t.text = text
    t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    return r


class Parser:
    def __init__(self, s):
        self.t = tokenize(s); self.p = 0

    def peek(self):
        return self.t[self.p] if self.p < len(self.t) else (None, None)

    def take(self):
        tok = self.peek(); self.p += 1; return tok

    def parse_seq(self, stop=('}',)):
        out = []
        while True:
            kind, val = self.peek()
            if kind is None or kind in stop or (kind == 'cmd' and val in stop):
                return out
            atom = self.parse_atom()
            if atom is None:
                continue
            out.append(self.parse_scripts(atom))

    def group_or_atom(self):
        kind, _ = self.peek()
        if kind == '{':
            self.take(); seq = self.parse_seq(); self.take(); return seq
        a = self.parse_atom()
        return [a] if a is not None else []

    def parse_scripts(self, base):
        sub = sup = None
        while self.peek()[0] in ('_', '^'):
            kind, _ = self.take()
            arg = self.group_or_atom()
            if kind == '_':
                sub = arg
            else:
                sup = arg
        if sub is None and sup is None:
            return base
        if sub is not None and sup is not None:
            el = m('sSubSup'); e = msub(el, 'e'); e.extend(base if isinstance(base, list) else [base])
            s1 = msub(el, 'sub'); s1.extend(sub); s2 = msub(el, 'sup'); s2.extend(sup); return el
        tag, part = ('sSub', 'sub') if sub is not None else ('sSup', 'sup')
        el = m(tag); e = msub(el, 'e'); e.extend(base if isinstance(base, list) else [base])
        s = msub(el, part); s.extend(sub if sub is not None else sup)
        return el

    def parse_atom(self):
        kind, val = self.take()
        if kind == '{':
            seq = self.parse_seq(); self.take()
            box = m('box'); e = msub(box, 'e'); e.extend(seq); return box
        if kind == 'chr':
            return run(val, upright=not val.isalpha())
        if kind == '&':
            return None
        if kind != 'cmd':
            return None
        if val in ('frac', 'dfrac', 'tfrac'):
            num = self.frac_arg(); den = self.frac_arg()
            f = m('f'); n = msub(f, 'num'); n.extend(num); d = msub(f, 'den'); d.extend(den); return f
        if val in ('dot', 'ddot', 'hat', 'bar', 'tilde'):
            arg = self.group_or_atom()
            acc = m('acc'); pr = msub(acc, 'accPr'); c = msub(pr, 'chr')
            c.set('{%s}val' % M_NS, {'dot': '̇', 'ddot': '̈', 'hat': '̂', 'bar': '̅',
                                     'tilde': '̃'}[val])
            e = msub(acc, 'e'); e.extend(arg); return acc
        if val == 'sqrt':
            arg = self.group_or_atom()
            rad = m('rad'); pr = msub(rad, 'radPr'); dh = msub(pr, 'degHide'); dh.set('{%s}val' % M_NS, '1')
            msub(rad, 'deg'); e = msub(rad, 'e'); e.extend(arg); return rad
        if val in ('text', 'mathrm', 'operatorname'):
            self.take(); txt = []
            while self.peek()[0] != '}':
                k, v = self.take(); txt.append(v if k != 'cmd' else ' ')
            self.take(); return run(''.join(txt), upright=True)
        if val == 'mathcal':
            arg = self.group_or_atom()
            ch = ''.join(x.findtext('{%s}t' % M_NS) or '' for x in arg)
            return run(MATHCAL.get(ch, ch))
        if val == 'begin':
            self.take(); env = ''
            while self.peek()[0] != '}':
                env += self.take()[1]
            self.take()
            return self.parse_matrix(env)
        if val in DELIMS:
            k, v = self.take()
            ch = v if k == 'chr' else {'{': '{', '}': '}', '|': '‖'}.get(v, v)
            return run('' if ch == '.' else ch, upright=True)
        if val in GREEK:
            return run(GREEK[val])
        if val in SYMBOLS:
            return run(SYMBOLS[val], upright=True)
        if val in FUNCS:
            return run(' ' + val, upright=True)
        if val in SPACES:
            return run(SPACES[val], upright=True) if SPACES[val] else None
        if val in ('{', '}', '|', '%', '#', '_'):
            return run(val, upright=True)
        return run(val, upright=True)

    def frac_arg(self):
        kind, val = self.peek()
        if kind == 'chr' and val.isdigit():
            self.take(); return [run(val, upright=True)]
        return self.group_or_atom()

    def parse_matrix(self, env):
        rows, row, cell = [], [], []
        while True:
            kind, val = self.peek()
            if kind is None:
                break
            if kind == 'cmd' and val == 'end':
                self.take(); self.take()
                while self.peek()[0] != '}':
                    self.take()
                self.take(); break
            if kind == '&':
                self.take(); row.append(cell); cell = []; continue
            if kind == 'cmd' and val == '\\':
                self.take(); row.append(cell); rows.append(row); row, cell = [], []; continue
            atom = self.parse_atom()
            if atom is not None:
                cell.append(self.parse_scripts(atom))
        row.append(cell); rows.append(row)
        mat = m('m')
        for r in rows:
            mr = msub(mat, 'mr')
            for c in r:
                e = msub(mr, 'e'); e.extend(c)
        brackets = {'bmatrix': ('[', ']'), 'pmatrix': ('(', ')'), 'cases': ('{', '')}.get(env)
        if not brackets:
            return mat
        d = m('d'); pr = msub(d, 'dPr')
        b = msub(pr, 'begChr'); b.set('{%s}val' % M_NS, brackets[0])
        en = msub(pr, 'endChr'); en.set('{%s}val' % M_NS, brackets[1])
        e = msub(d, 'e'); e.append(mat); return d


def latex_to_omath(latex):
    om = m('oMath')
    om.extend(Parser(latex).parse_seq(stop=()))
    return om


# ----------------------------------------------------------------------------- docx helpers
FONT = 'Times New Roman'


def set_font(run_or_style, size=None, bold=None):
    f = run_or_style.font
    f.name = FONT
    if size:
        f.size = Pt(size)
    if bold is not None:
        f.bold = bold
    rpr = run_or_style.element.get_or_add_rPr() if hasattr(run_or_style, 'element') and hasattr(
        run_or_style.element, 'get_or_add_rPr') else run_or_style._element.get_or_add_rPr()
    rfonts = rpr.find(qn('w:rFonts'))
    if rfonts is None:
        rfonts = OxmlElement('w:rFonts'); rpr.append(rfonts)
    for a in ('w:ascii', 'w:hAnsi', 'w:cs', 'w:eastAsia'):
        rfonts.set(qn(a), FONT)
    for a in ('w:asciiTheme', 'w:hAnsiTheme', 'w:cstheme', 'w:eastAsiaTheme'):
        if rfonts.get(qn(a)) is not None:
            del rfonts.attrib[qn(a)]


def no_borders(table):
    tbl = table._tbl
    tblPr = tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        el = OxmlElement('w:' + side); el.set(qn('w:val'), 'nil'); borders.append(el)
    tblPr.append(borders)


def set_cell_width(cell, cm):
    tcPr = cell._tc.get_or_add_tcPr()
    w = OxmlElement('w:tcW'); w.set(qn('w:w'), str(int(cm * 567))); w.set(qn('w:type'), 'dxa')
    tcPr.append(w)


INLINE = re.compile(r'\$(.+?)\$')


def add_rich(p, text, size=13, bold=False, italic=False):
    """Add text to paragraph p; parts written as $latex$ become inline Word equations."""
    pos = 0
    for mm in INLINE.finditer(text):
        if mm.start() > pos:
            r = p.add_run(text[pos:mm.start()]); set_font(r, size, bold=bold); r.italic = italic
        p._p.append(latex_to_omath(mm.group(1)))
        pos = mm.end()
    if pos < len(text):
        r = p.add_run(text[pos:]); set_font(r, size, bold=bold); r.italic = italic


def build(txt_path, docx_path):
    lines = open(txt_path, encoding='utf-8').read().splitlines()
    doc = Document()
    sec = doc.sections[0]
    sec.page_height, sec.page_width = Cm(29.7), Cm(21.0)
    sec.left_margin, sec.right_margin, sec.top_margin, sec.bottom_margin = Cm(3.0), Cm(2.0), Cm(2.0), Cm(2.0)
    text_width = 21.0 - 3.0 - 2.0

    normal = doc.styles['Normal']
    set_font(normal, 13)
    pf = normal.paragraph_format
    pf.line_spacing = 1.3; pf.space_after = Pt(6); pf.space_before = Pt(0)
    for lvl, size in ((1, 16), (2, 14), (3, 13)):
        st = doc.styles['Heading %d' % lvl]
        set_font(st, size, bold=True)
        st.font.color.rgb = RGBColor(0, 0, 0)
        st.font.italic = False
        st.paragraph_format.space_before = Pt(12 if lvl < 3 else 6)
        st.paragraph_format.space_after = Pt(6)
        st.paragraph_format.keep_with_next = True

    sep = re.compile(r'^\s*(=|-){20,}\s*$')
    h2 = re.compile(r'^(\d+)\.\s+(.*)$')
    h3 = re.compile(r'^\s*(\d+)\.(\d+)\.\s+(.*)$')
    eq = re.compile(r'^\s*\((\d+)\)\s+(.*)$')
    latex = re.compile(r'^\s*\[\s(.*)\s\]\s*$')
    tabcap = re.compile(r'^\s*(Bảng\s+\d+[.:].*)$')
    figcap = re.compile(r'^\s*\[(Hình\s+\d+[.:].*)\]\s*$')

    seps = [i for i, l in enumerate(lines) if re.match(r'^\s*={20,}\s*$', l)]
    title_idx = seps[0] + 1 if len(seps) >= 2 else None

    i = 0
    while i < len(lines):
        raw = lines[i]; s = raw.strip()
        if not s or sep.match(raw):
            i += 1; continue
        if i == title_idx:
            doc.add_heading(s, level=1); i += 1; continue
        mh3 = h3.match(raw)
        if mh3 and len(mh3.group(3)) < 120:
            add_rich(doc.add_heading('', level=3), mh3.group(3).strip(), 13, bold=True); i += 1; continue
        mh2 = h2.match(raw)
        if mh2 and len(mh2.group(2)) < 120:
            add_rich(doc.add_heading('', level=2), mh2.group(2).strip(), 14, bold=True); i += 1; continue
        me = eq.match(raw)
        if me and i + 1 < len(lines) and latex.match(lines[i + 1]):
            num = me.group(1); lx = latex.match(lines[i + 1]).group(1)
            t = doc.add_table(rows=1, cols=2); no_borders(t); t.alignment = WD_TABLE_ALIGNMENT.CENTER
            c0, c1 = t.rows[0].cells
            set_cell_width(c0, text_width - 1.8); set_cell_width(c1, 1.8)
            p0 = c0.paragraphs[0]; p0.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p0.paragraph_format.space_after = Pt(3); p0.paragraph_format.space_before = Pt(3)
            para = OxmlElement('m:oMathPara'); para.append(latex_to_omath(lx))
            p0._p.append(para)
            p1 = c1.paragraphs[0]; p1.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            p1.paragraph_format.space_after = Pt(0)
            r = p1.add_run('(%s)' % num); set_font(r, 13)
            for c in (c0, c1):
                c.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            i += 2; continue
        mf = figcap.match(raw)
        if mf:
            caption, _, img = mf.group(1).partition(' | ')
            img_path = os.path.join(REPO_ROOT, img.strip()) if img.strip() else ''
            box = doc.add_paragraph(); box.alignment = WD_ALIGN_PARAGRAPH.CENTER
            box.paragraph_format.keep_with_next = True
            if img_path and os.path.isfile(img_path):
                box.add_run().add_picture(img_path, width=Cm(text_width - 1.0))
            else:
                if img_path:
                    print('warning: image not found, placeholder used: %s' % img_path)
                r = box.add_run('[Chèn hình]'); set_font(r, 13); r.italic = True
                pPr = box._p.get_or_add_pPr(); bdr = OxmlElement('w:pBdr')
                for side in ('top', 'left', 'bottom', 'right'):
                    e = OxmlElement('w:' + side); e.set(qn('w:val'), 'single'); e.set(qn('w:sz'), '4')
                    e.set(qn('w:space'), '40'); e.set(qn('w:color'), '808080'); bdr.append(e)
                pPr.append(bdr)
            cap = doc.add_paragraph(); cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
            add_rich(cap, caption, 12, italic=True)
            i += 1; continue
        mt = tabcap.match(raw)
        if mt and i + 1 < len(lines) and ' | ' in lines[i + 1]:
            cap = doc.add_paragraph(); cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
            cap.paragraph_format.keep_with_next = True
            add_rich(cap, mt.group(1), 12, italic=True)
            rows = []; j = i + 1
            while j < len(lines) and ' | ' in lines[j]:
                rows.append([c.strip() for c in lines[j].strip().split(' | ')]); j += 1
            ncol = max(len(r_) for r_ in rows)
            t = doc.add_table(rows=len(rows), cols=ncol); t.style = 'Table Grid'
            t.alignment = WD_TABLE_ALIGNMENT.CENTER
            t.autofit = False
            def vis(x):
                return len(INLINE.sub(lambda mm_: 'x' * max(2, len(mm_.group(1)) // 3), x))
            wts = [max(9, min(45, max(vis(r_[ci]) + (3 if ri_ == 0 else 0) if ci < len(r_) else 0 for ri_, r_ in enumerate(rows)))) for ci in range(ncol)]
            tot = float(sum(wts))
            widths = [text_width * w_ / tot for w_ in wts]
            for ri, rw in enumerate(rows):
                for ci in range(ncol):
                    cell = t.rows[ri].cells[ci]; cell.width = Cm(widths[ci]); p = cell.paragraphs[0]
                    p.paragraph_format.space_after = Pt(0); p.paragraph_format.line_spacing = 1.0
                    add_rich(p, rw[ci] if ci < len(rw) else '', 12, bold=(ri == 0))
            doc.add_paragraph().paragraph_format.space_after = Pt(0)
            i = j; continue
        p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        add_rich(p, s, 13)
        i += 1
    doc.save(docx_path)
    print('Wrote', docx_path)


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2])
