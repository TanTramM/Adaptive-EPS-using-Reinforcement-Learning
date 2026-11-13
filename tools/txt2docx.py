"""Convert a thesis chapter written in the Documents/ .txt convention into a Word .docx.

Usage:  python tools/txt2docx.py Documents/Plant/plant.txt Documents/Plant/plant.docx [--paper]
        --paper: article layout for Documents/Paper/paper.txt (11 pt, 2 cm margins, numbered headings, Abstract and References as headings)
        --thesis: whole-thesis layout for Documents/Thesis/luanvan.txt (chapters "CHƯƠNG n. ..." as Heading 1 on a new page, "n.m." and "n.m.k."
                  headings with numbers kept, reference entries "[n] ..." with hanging indent, page numbers in the footer)

Text conventions (one logical item per line, no hard wrapping):
  ====...  / ----...        separator lines, ignored
  line between the first two '====' lines   chapter title  -> Heading 1
  "1. Title"                 section         -> Heading 2 (number removed, Word numbering applies)
  "1.1. Title"               subsection      -> Heading 3 (number removed)
  "  (n)  ascii formula"     equation line, the NEXT line "  [ latex ]" is converted to a native Word
                             equation (OMML) and numbered (n) at the right margin
  "  Bảng n: caption"        table caption (English: "Table n: caption"); following lines containing " | " are the table rows
                             (first row = header) until a blank line
  "  [Hình n: caption]"      figure placeholder (English: "[Figure n: caption]") (empty box + caption)
  "  [Hình n: caption | path/to/image.png]"   figure with the image inserted (path relative to the repo root, optional "@9.0" after the path = width in cm;
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
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING, WD_TAB_ALIGNMENT, WD_TAB_LEADER
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
SYMBOLS = {'ne': '≠', 'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'approx': '≈', 'cdot': '·', 'times': '×',
           'Leftrightarrow': '⇔', 'Rightarrow': '⇒', 'rightarrow': '→', 'to': '→', 'infty': '∞',
           'partial': '∂', 'circ': '°', 'pm': '±', 'neq': '≠', 'sum': '∑', 'prod': '∏', 'in': '∈', 'ldots': '…',
           'dots': '…', 'cdots': '⋯', 'int': '∫'}
FUNCS = {'sin', 'cos', 'tan', 'tanh', 'arctan', 'max', 'min', 'exp', 'ln', 'log', 'sgn', 'sign'}
SPACES = {'quad': ' ', 'qquad': '  ', ';': ' ', ',': ' ', ':': ' ',
          '!': '', ' ': ' '}
DELIMS = {'left', 'right', 'big', 'Big', 'bigg', 'Bigg', 'bigl', 'bigr', 'Bigl', 'Bigr'}
MATHCAL = {'F': 'ℱ', 'L': 'ℒ', 'H': 'ℋ'}
AUTO_PAREN = False        # paper2docx.py sets True: every matched "(...)" becomes a stretchy Word bracket


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
        if kind == 'chr' and val == '(' and AUTO_PAREN:             # matched round brackets become Word stretchy brackets that cover their whole content
            inner = []
            while self.peek()[0] is not None and self.peek() != ('chr', ')') and self.peek()[0] != '}':
                atom = self.parse_atom()
                if atom is not None:
                    inner.append(self.parse_scripts(atom))
            closed = self.peek() == ('chr', ')')
            if closed:
                self.take()
            d = m('d'); pr = msub(d, 'dPr')
            msub(pr, 'begChr').set('{%s}val' % M_NS, '(')
            msub(pr, 'endChr').set('{%s}val' % M_NS, ')' if closed else '')
            e = msub(d, 'e'); e.extend(inner); return d
        if kind == 'chr':
            return run(val, upright=not val.isalpha())
        if kind == '&':
            return None
        if kind != 'cmd':
            return None
        if val in ('frac', 'dfrac', 'tfrac'):
            num = self.frac_arg(); den = self.frac_arg()
            f = m('f'); n = msub(f, 'num'); n.extend(num); d = msub(f, 'den'); d.extend(den); return f
        if val in ('dot', 'ddot', 'hat', 'widehat', 'bar', 'tilde'):
            arg = self.group_or_atom()
            acc = m('acc'); pr = msub(acc, 'accPr'); c = msub(pr, 'chr')
            c.set('{%s}val' % M_NS, {'dot': '̇', 'ddot': '̈', 'hat': '̂', 'widehat': '̂', 'bar': '̅',
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
        if val in ('paren', 'brack', 'abs'):                      # stretchy delimiters around one group (new commands, safe for old documents)
            arg = self.group_or_atom()
            d = m('d'); pr = msub(d, 'dPr')
            b0, b1 = {'paren': ('(', ')'), 'brack': ('[', ']'), 'abs': ('|', '|')}[val]
            msub(pr, 'begChr').set('{%s}val' % M_NS, b0); msub(pr, 'endChr').set('{%s}val' % M_NS, b1)
            e = msub(d, 'e'); e.extend(arg); return d
        if val == 'limlow':                                        # \limlow{max}{limit text}: the limit sits under the operator
            base = self.group_or_atom(); lim = self.group_or_atom()
            ll = m('limLow'); e = msub(ll, 'e'); e.extend(base); l = msub(ll, 'lim'); l.extend(lim); return ll
        if val == 'nsum':                                          # \nsum{limit}: summation sign with the limit under it
            sub = self.group_or_atom()
            nr = m('nary'); pr = msub(nr, 'naryPr')
            msub(pr, 'chr').set('{%s}val' % M_NS, '∑'); msub(pr, 'limLoc').set('{%s}val' % M_NS, 'undOvr')
            msub(pr, 'supHide').set('{%s}val' % M_NS, '1')
            s1 = msub(nr, 'sub'); s1.extend(sub); msub(nr, 'sup'); msub(nr, 'e'); return nr
        if val == 'lbrace':
            return run('{', upright=True)
        if val == 'rbrace':
            return run('}', upright=True)
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


FONT_SCALE = 1.0          # 11/13 in paper mode (see build)


def set_font(run_or_style, size=None, bold=None):
    f = run_or_style.font
    f.name = FONT
    if size:
        f.size = Pt(size * FONT_SCALE)
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


def add_page_number_footer(section):
    """Centered page number (PAGE field) in the footer of the section."""
    p = section.footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_ = p.add_run()
    for kind, text in (('begin', None), (None, 'PAGE'), ('end', None)):
        if kind:
            el = OxmlElement('w:fldChar'); el.set(qn('w:fldCharType'), kind)
        else:
            el = OxmlElement('w:instrText'); el.set(qn('xml:space'), 'preserve'); el.text = text
        run_._r.append(el)
    set_font(run_, 12)


def add_field(p, instr, placeholder='', size=13):
    """Append a complex Word field (begin, instruction, separate, placeholder text, end) to the paragraph p. Word fills it in when the fields are
    updated (tools/docx2pdf_word.py --fields); until then the placeholder shows."""
    def fld(kind, dirty=False):
        r = p.add_run(); el = OxmlElement('w:fldChar'); el.set(qn('w:fldCharType'), kind)
        if dirty:
            el.set(qn('w:dirty'), 'true')
        r._r.append(el)
    fld('begin', True)
    r = p.add_run(); it = OxmlElement('w:instrText'); it.set(qn('xml:space'), 'preserve'); it.text = ' %s ' % instr; r._r.append(it)
    fld('separate')
    rp = p.add_run(placeholder); set_font(rp, size)
    fld('end')


def set_section_numbering(section, fmt, start=1):
    """Page-number format of a section ('lowerRoman' or 'decimal') and the number its first page gets. pgNumType must come right after pgMar."""
    sectPr = section._sectPr
    pg = sectPr.find(qn('w:pgNumType'))
    if pg is None:
        pg = OxmlElement('w:pgNumType')
        pgmar = sectPr.find(qn('w:pgMar'))
        if pgmar is not None:
            pgmar.addnext(pg)
        else:
            sectPr.append(pg)
    pg.set(qn('w:fmt'), fmt); pg.set(qn('w:start'), str(start))


def add_bookmark(p, name, bid):
    """Wrap the whole content of paragraph p in a bookmark (target of the PAGEREF fields of the lists of figures and tables)."""
    s = OxmlElement('w:bookmarkStart'); s.set(qn('w:id'), str(bid)); s.set(qn('w:name'), name)
    e = OxmlElement('w:bookmarkEnd'); e.set(qn('w:id'), str(bid))
    pPr = p._p.find(qn('w:pPr'))
    if pPr is not None:
        pPr.addnext(s)
    else:
        p._p.insert(0, s)
    p._p.append(e)


CAPTION_NUM = re.compile(r'^(Hình|Bảng)\s+((?:[A-Z]\.)?\d+(?:\.\d+)?)\s*[:.]\s*(.*)$')      # '5.3' in a chapter, 'A.1' in an appendix
FIRST_SENTENCE = re.compile(r'\.\s+(?=\S)')


def short_caption(text):
    """The first sentence of a caption (up to the first '. ' that is not inside an abbreviation), for the lists of figures and tables."""
    for mm in FIRST_SENTENCE.finditer(text):
        before = text[:mm.start()]
        if re.search(r'(tr|mục|PT|Bảng|Hình|vs|ví dụ)$', before) or re.search(r'\b[A-Z]$', before):
            continue
        return before
    return text.rstrip('.')


def build(txt_path, docx_path, paper=False, thesis=False):
    """paper=True: article layout (11 pt, 2 cm margins, section numbers kept in the headings, 'Abstract' and 'References' as headings).
    thesis=True: whole-thesis layout for Documents/Thesis/luanvan.txt: the first '====' block is a centered title, 'CHƯƠNG n. ...',
    'TÀI LIỆU THAM KHẢO' and 'PHỤ LỤC ...' lines are Heading 1 (new page), 'n.m. ...' Heading 2 and 'n.m.k. ...' Heading 3 with the numbers kept,
    lines '[n] ...' are reference entries (hanging indent), and page numbers are added in the footer."""
    global FONT_SCALE
    FONT_SCALE = 11.0 / 13.0 if paper else 1.0
    lines = open(txt_path, encoding='utf-8').read().splitlines()
    doc = Document()
    sec = doc.sections[0]
    sec.page_height, sec.page_width = Cm(29.7), Cm(21.0)
    lm = 2.0 if paper else 3.0
    sec.left_margin, sec.right_margin, sec.top_margin, sec.bottom_margin = Cm(lm), Cm(2.0), Cm(2.0), Cm(2.0)
    text_width = 21.0 - lm - 2.0

    normal = doc.styles['Normal']
    set_font(normal, 13)
    pf = normal.paragraph_format
    pf.line_spacing = 1.15 if paper else 1.3; pf.space_after = Pt(6); pf.space_before = Pt(0)
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
    eq = re.compile(r'^\s*\((\d+(?:\.\d+)?)\)\s+(.*)$')       # '(12)' or, in the thesis, '(2.12)'
    latex = re.compile(r'^\s*\[\s(.*)\s\]\s*$')
    tabcap = re.compile(r'^\s*((?:Bảng|Table)\s+(?:[A-Z]\.)?\d+[.:].*)$')
    figcap = re.compile(r'^\s*\[((?:Hình|Figure)\s+(?:[A-Z]\.)?\d+[.:].*)\]\s*$')

    t_h1 = re.compile(r'^(CHƯƠNG\s+\d+\.\s+.+|TÀI LIỆU THAM KHẢO|PHỤ LỤC.*|DANH MỤC CÔNG TRÌNH.*|LÝ LỊCH TRÍCH NGANG)$')
    t_h2 = re.compile(r'^(?:\d+|[A-Z])\.\d+\.\s+\S.*$')                # '5.3. Title' and, in an appendix, 'A.1. Title'
    t_h3 = re.compile(r'^(?:\d+|[A-Z])\.\d+\.\d+\.\s+\S.*$')
    t_ref = re.compile(r'^\[\d+\]\s+\S')
    # Layout directives of the whole thesis (lines starting with '@@', see the docstring of thesis_directives below). Without any '@@SECTION'
    # line the document is a single section with the page number in the footer, as before.
    directives = thesis and any(l.startswith('@@SECTION') for l in lines)
    if thesis and not directives:
        add_page_number_footer(sec)
    caps = []                                   # (kind, number, short title, bookmark) of every figure and table, for the lists of figures and tables
    bm_of = {}
    if thesis:
        for nm, bold_, ital_, sz_ in (('CaptionFig', False, True, 12), ('CaptionTab', False, True, 12), ('FrontHeading', True, False, 14)):
            st_ = doc.styles.add_style(nm, WD_STYLE_TYPE.PARAGRAPH); st_.base_style = normal
            set_font(st_, sz_, bold=bold_); st_.font.italic = ital_
            st_.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for nm, ind, bold_ in (('toc 1', 0.0, True), ('toc 2', 0.7, False), ('toc 3', 1.4, False)):      # Word's built-in styles of the table of contents
            st_ = doc.styles.add_style(nm, WD_STYLE_TYPE.PARAGRAPH); st_.base_style = normal
            set_font(st_, 13, bold=bold_)
            pf_ = st_.paragraph_format
            pf_.left_indent = Cm(ind); pf_.right_indent = Cm(1.0); pf_.space_after = Pt(3); pf_.line_spacing = 1.15
            pf_.tab_stops.add_tab_stop(Cm(text_width), WD_TAB_ALIGNMENT.RIGHT, WD_TAB_LEADER.DOTS)
        fh = doc.styles['FrontHeading'].paragraph_format
        fh.page_break_before = True; fh.space_before = Pt(0); fh.space_after = Pt(18); fh.keep_with_next = True
        for k, l in enumerate(lines):
            mf_ = figcap.match(l)
            if mf_:
                cap_ = mf_.group(1).partition(' | ')[0]
            elif tabcap.match(l) and k + 1 < len(lines) and ' | ' in lines[k + 1]:
                cap_ = tabcap.match(l).group(1)
            else:
                continue
            mn_ = CAPTION_NUM.match(cap_)
            if mn_:
                kind_, num_ = mn_.group(1), mn_.group(2)
                bm_ = 'cap%s_%s' % ('H' if kind_ == 'Hình' else 'B', num_.replace('.', '_'))
                bm_of[(kind_, num_)] = bm_
                caps.append((kind_, num_, short_caption(mn_.group(3)), bm_))
    bm_id = [100]
    pending_w = [None]

    def tag_caption(p, text):
        """In the thesis, give the caption paragraph its style and a bookmark (target of the lists of figures and tables)."""
        mn = CAPTION_NUM.match(text)
        if not (thesis and mn):
            return
        p.style = doc.styles['CaptionFig' if mn.group(1) == 'Hình' else 'CaptionTab']
        bm_id[0] += 1
        add_bookmark(p, bm_of[(mn.group(1), mn.group(2))], bm_id[0])

    def emit_table(rows, caption=None):
        """A grid table (first row = header); the text of every cell may hold $latex$."""
        if caption:
            cap = doc.add_paragraph(); cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
            cap.paragraph_format.keep_with_next = True
            add_rich(cap, caption, 12, italic=True)
            tag_caption(cap, caption)
        ncol = max(len(r_) for r_ in rows)
        t = doc.add_table(rows=len(rows), cols=ncol); t.style = 'Table Grid'
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = False
        def vis(x):
            return len(INLINE.sub(lambda mm_: 'x' * max(2, len(mm_.group(1)) // 3), x))
        wts = [max(20, min(45, max(vis(r_[ci]) + (3 if ri_ == 0 else 0) if ci < len(r_) else 0 for ri_, r_ in enumerate(rows)))) for ci in range(ncol)]
        if pending_w[0] and len(pending_w[0]) == ncol:      # '@@W w1 w2 ...' before a table gives its relative column widths
            wts = pending_w[0]
        pending_w[0] = None
        tot = float(sum(wts))
        widths = [text_width * w_ / tot for w_ in wts]
        for ri, rw in enumerate(rows):
            for ci in range(ncol):
                cell = t.rows[ri].cells[ci]; cell.width = Cm(widths[ci]); p = cell.paragraphs[0]
                p.paragraph_format.space_after = Pt(0); p.paragraph_format.line_spacing = 1.0
                add_rich(p, rw[ci] if ci < len(rw) else '', 12, bold=(ri == 0))
        n_keep = len(t.rows) - 1 if len(t.rows) <= 16 else 1   # a short table (up to 16 rows) stays on one page (Word moves it whole); in a longer one only the header stays with the first row
        for row_k in t.rows[:n_keep]:
            for p_ in (pp for c_ in row_k.cells for pp in c_.paragraphs):
                p_.paragraph_format.keep_with_next = True
        for ri, row_ in enumerate(t.rows):               # header row repeats on each page, rows never split across pages
            trPr = row_._tr.get_or_add_trPr()
            trPr.append(OxmlElement('w:cantSplit'))
            if ri == 0:
                hdr = OxmlElement('w:tblHeader'); hdr.set(qn('w:val'), 'true'); trPr.append(hdr)
        doc.add_paragraph().paragraph_format.space_after = Pt(0)

    def list_of(kind):
        """Entries of the list of figures or tables: label, first sentence of the caption, dot leader, page number (PAGEREF field of the caption bookmark)."""
        for kind_, num_, title_, bm_ in caps:
            if kind_ != kind:
                continue
            p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            pf_ = p.paragraph_format
            pf_.left_indent = Cm(2.4); pf_.first_line_indent = Cm(-2.4); pf_.right_indent = Cm(1.0)
            pf_.space_after = Pt(4); pf_.line_spacing = 1.15
            pf_.tab_stops.add_tab_stop(Cm(2.4))
            pf_.tab_stops.add_tab_stop(Cm(text_width), WD_TAB_ALIGNMENT.RIGHT, WD_TAB_LEADER.DOTS)
            add_rich(p, '%s %s\t%s\t' % (kind_, num_, title_), 13)
            add_field(p, 'PAGEREF %s \\h' % bm_, '0')

    seps = [i for i, l in enumerate(lines) if re.match(r'^\s*={20,}\s*$', l)]
    title_idx = seps[0] + 1 if len(seps) >= 2 else None
    title_text = lines[title_idx].strip() if title_idx is not None else ''
    n_sections = [0]

    i = 0
    while i < len(lines):
        raw = lines[i]; s = raw.strip()
        if not s or sep.match(raw):
            i += 1; continue
        if thesis and s.startswith('@@'):
            # thesis_directives: layout lines of the front matter, see docs in the module header
            mdir = re.match(r'^@@(\w+?)(\d*)(b?)(?:\s+(.*))?$', s)
            cmd, num_, bold_, arg = mdir.group(1), mdir.group(2), mdir.group(3), (mdir.group(4) or '')
            if cmd == 'SECTION':
                if n_sections[0] == 0:
                    sec.footer.is_linked_to_previous = False                       # the cover: no page number
                else:
                    sec = doc.add_section(WD_SECTION.NEW_PAGE)
                    sec.footer.is_linked_to_previous = False
                    add_page_number_footer(sec)
                    set_section_numbering(sec, 'lowerRoman' if arg.strip() == 'front' else 'decimal', 1)
                n_sections[0] += 1
            elif cmd == 'W':
                pending_w[0] = [float(x) for x in arg.split()]
            elif cmd == 'PAGEBREAK':
                doc.add_page_break()
            elif cmd == 'SP':
                for _ in range(int(num_ or arg or 1)):
                    sp = doc.add_paragraph(); sp.paragraph_format.space_after = Pt(0)
            elif cmd in ('C', 'CB', 'I', 'R'):
                size = int(num_) if num_ else 13
                bold_ = bold_ == 'b' or cmd == 'CB'
                pc = doc.add_paragraph()
                pc.alignment = {'C': WD_ALIGN_PARAGRAPH.CENTER, 'CB': WD_ALIGN_PARAGRAPH.CENTER, 'I': WD_ALIGN_PARAGRAPH.LEFT, 'R': WD_ALIGN_PARAGRAPH.RIGHT}[cmd]
                if cmd == 'I':
                    pc.paragraph_format.left_indent = Cm(6.5)
                pc.paragraph_format.space_after = Pt(4)
                add_rich(pc, arg, size, bold=bold_)
            elif cmd == 'TITLE':
                size = int(num_) if num_ else 18
                pc = doc.add_paragraph(); pc.alignment = WD_ALIGN_PARAGRAPH.CENTER
                pc.paragraph_format.space_before = Pt(12); pc.paragraph_format.space_after = Pt(12)
                add_rich(pc, title_text, size, bold=True)
            elif cmd == 'H':
                ph = doc.add_paragraph(style='FrontHeading')
                add_rich(ph, arg, 14, bold=True)
            elif cmd in ('TOC', 'LOF', 'LOT'):
                ph = doc.add_paragraph(style='FrontHeading')
                add_rich(ph, arg, 14, bold=True)
                if cmd == 'TOC':
                    pf_ = doc.add_paragraph(); add_field(pf_, 'TOC \\o "1-3" \\h \\z \\u', '[Mục lục: cập nhật trường để hiện (F9)]')
                else:
                    list_of('Hình' if cmd == 'LOF' else 'Bảng')
            elif cmd == 'TAB':
                rows = []; j = i + 1
                while j < len(lines) and ' | ' in lines[j]:
                    rows.append([c.strip() for c in lines[j].strip().split(' | ')]); j += 1
                emit_table(rows)
                i = j; continue
            else:
                raise SystemExit('unknown directive: ' + s)
            i += 1; continue
        if i == title_idx and directives:
            i += 1; continue
        if i == title_idx:
            if thesis:
                tp = doc.add_paragraph(); tp.alignment = WD_ALIGN_PARAGRAPH.CENTER
                tp.paragraph_format.space_before = Pt(24); tp.paragraph_format.space_after = Pt(24)
                add_rich(tp, s, 16, bold=True)
            else:
                doc.add_heading(s, level=1)
            i += 1; continue
        if thesis:
            mc = t_h1.match(s)
            if mc:
                hh = doc.add_heading('', level=1); hh.paragraph_format.page_break_before = True
                add_rich(hh, s, 16, bold=True); i += 1; continue
            m3 = t_h3.match(s)
            if m3 and len(s) < 150:
                add_rich(doc.add_heading('', level=3), s, 13, bold=True); i += 1; continue
            m2 = t_h2.match(s)
            if m2 and len(s) < 150:
                add_rich(doc.add_heading('', level=2), s, 14, bold=True); i += 1; continue
            if t_ref.match(s):
                p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                p.paragraph_format.left_indent = Cm(1.0); p.paragraph_format.first_line_indent = Cm(-1.0)
                add_rich(p, s, 13); i += 1; continue
        mh3 = h3.match(raw)
        if mh3 and len(mh3.group(3)) < 120:
            ttl = mh3.group(3).strip()
            if paper: ttl = '%s.%s. %s' % (mh3.group(1), mh3.group(2), ttl)
            add_rich(doc.add_heading('', level=3), ttl, 13, bold=True); i += 1; continue
        mh2 = h2.match(raw)
        if mh2 and len(mh2.group(2)) < 120:
            ttl = mh2.group(2).strip()
            if paper: ttl = '%s. %s' % (mh2.group(1), ttl)
            add_rich(doc.add_heading('', level=2), ttl, 14, bold=True); i += 1; continue
        if paper and (s == 'Abstract' or s.startswith('References (')):
            add_rich(doc.add_heading('', level=2), s.split(' (')[0], 14, bold=True); i += 1; continue
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
            img, _, wcm = img.strip().partition('@')                  # optional width in cm after '@', e.g. 'Figures/x.png@9.0'
            img_w = Cm(float(wcm)) if wcm.strip() else Cm(text_width - 1.0)
            img_path = os.path.join(REPO_ROOT, img.strip()) if img.strip() else ''
            box = doc.add_paragraph(); box.alignment = WD_ALIGN_PARAGRAPH.CENTER
            box.paragraph_format.keep_with_next = True
            if img_path and os.path.isfile(img_path):
                box.add_run().add_picture(img_path, width=img_w)
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
            tag_caption(cap, caption)
            i += 1; continue
        mt = tabcap.match(raw)
        if mt and i + 1 < len(lines) and ' | ' in lines[i + 1]:
            rows = []; j = i + 1
            while j < len(lines) and ' | ' in lines[j]:
                rows.append([c.strip() for c in lines[j].strip().split(' | ')]); j += 1
            emit_table(rows, caption=mt.group(1))
            i = j; continue
        p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        add_rich(p, s, 13)
        i += 1
    doc.save(docx_path)
    print('Wrote', docx_path)


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2], paper=('--paper' in sys.argv[3:]), thesis=('--thesis' in sys.argv[3:]))
