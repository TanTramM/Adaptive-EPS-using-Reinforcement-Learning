# -*- coding: utf-8 -*-
"""Number the display equations of the advisor's docx at the right margin (Word native '#' numbering inside an equation array),
remove the trailing empty paragraphs, and leave everything else untouched.

usage: python number_eqs.py <in.docx> <out.docx>
"""
import re
import sys
import zipfile

SRC, DST = sys.argv[1], sys.argv[2]

# paragraph index (order of <w:p> in the document, as listed by the analysis) -> equation number; a number sits on the LAST paragraph of its group
GROUPS = [
    (1, [16, 17]),            # column dynamics + sensed torque
    (2, [21, 22]),            # slip angles
    (3, [27, 28]),            # Magic Formula, D and B
    (4, [31, 32]),            # effective moment arm and caster trail
    (5, [34]),                # road reaction torque
    (6, [36, 37, 38]),        # single-track body
    (7, [41]),                # static balance
    (8, [77, 78]),            # reference
    (9, [83]),                # tracking error
    (10, [86]),               # assist bound
    (11, [94, 95]),           # calibration points
    (12, [98, 99]),           # lead-lag
    (13, [103]),              # steady state of the map
    (14, [105, 106]),         # sensitivity
    (15, [112]),              # PI/PID
    (16, [228]),              # motor
    (17, [230, 231]),         # T_a,max and a_y,lim
    (18, [234, 235, 236]),    # discrete form
    (19, [238]),              # K_aw
    (20, [277, 278]),         # R and S
    (21, [280]),              # e_rel
    (22, [284]),              # J
]
# first characters of the math text of each target paragraph (sanity check against a wrong index)
EXPECT = {16: 'Jcol', 17: 'Ts=', 21: 'αf', 22: 'αr', 27: 'Fy=', 28: 'D =', 31: 'ep =', 32: 'ec=', 34: 'Tr=', 36: 'ay=', 37: 'β=', 38: 'γ=',
          41: 'Ts=', 77: 'Trefv', 78: 'Thatv', 83: 'eT=', 86: 'Ta≤', 94: 'Ts,cal', 95: 'Ta,cal', 98: 'Ta,cmds', 99: 'Cmaps', 103: 'Ts+',
          105: 'ΔTs', 106: 'sm=', 112: 'Ta,cmds', 228: 'Gms', 230: 'Ta,maxv', 231: 'ay,limv', 234: 'uIk', 235: 'dk=', 236: 'ad',
          238: 'Kaw=', 277: 'R =', 278: 'S =', 280: 'erel', 284: 'J ='}
NUM = {}
for n, idx in GROUPS:
    NUM[idx[-1]] = n

PARA = re.compile(r'<w:p(?: [^>]*?)?(?:/>|>.*?</w:p>)', re.S)
RPR = '<w:rPr><w:rStyle w:val="HTMLCode"/><w:rFonts w:ascii="Cambria Math" w:eastAsiaTheme="minorHAnsi" w:hAnsi="Cambria Math"/></w:rPr>'
CTRL = '<m:ctrlPr><w:rPr><w:rStyle w:val="HTMLCode"/><w:rFonts w:ascii="Cambria Math" w:eastAsiaTheme="minorHAnsi" w:hAnsi="Cambria Math"/><w:i/></w:rPr></m:ctrlPr>'


def number(par, n):
    m = re.search(r'<m:oMathPara>(<m:oMathParaPr>.*?</m:oMathParaPr>)?<m:oMath>(.*)</m:oMath></m:oMathPara>', par, re.S)
    assert m and not m.group(1), 'unexpected paragraph structure'
    tail = ('<m:r>%s<m:t>#</m:t></m:r><m:d><m:dPr>%s</m:dPr><m:e><m:r>%s<m:t>%d</m:t></m:r></m:e></m:d>' % (RPR, CTRL, RPR, n))
    new = ('<m:oMathPara><m:oMath><m:eqArr><m:eqArrPr><m:maxDist m:val="1"/>%s</m:eqArrPr><m:e>%s%s</m:e></m:eqArr></m:oMath></m:oMathPara>'
           % (CTRL, m.group(2), tail))
    return par[:m.start()] + new + par[m.end():]


zin = zipfile.ZipFile(SRC)
xml = zin.read('word/document.xml').decode('utf-8')
paras = list(PARA.finditer(xml))
out, last, done = [], 0, 0
for i, mm in enumerate(paras):
    if i in NUM:
        mt = ''.join(re.findall(r'<m:t[^>]*>([^<]*)</m:t>', mm.group(0)))
        assert '<m:oMathPara>' in mm.group(0), (i, mt)
        out.append(xml[last:mm.start()]); out.append(number(mm.group(0), NUM[i])); last = mm.end(); done += 1
    elif i in EXPECT:
        mt = ''.join(re.findall(r'<m:t[^>]*>([^<]*)</m:t>', mm.group(0)))
        assert mt.replace(' ', '').startswith(EXPECT[i].replace(' ', '')), (i, mt[:40], EXPECT[i])
out.append(xml[last:])
xml2 = ''.join(out)
# sanity check of the index list on the non-numbered members too
for n, idx in GROUPS:
    for i in idx:
        mt = ''.join(re.findall(r'<m:t[^>]*>([^<]*)</m:t>', paras[i].group(0)))
        assert mt.replace(' ', '').startswith(EXPECT[i].replace(' ', '')), (n, i, mt[:40])

# trailing empty paragraphs after the last reference (before sectPr)
tail = re.search(r'((?:<w:p [^>]*/>|<w:p [^>]*>(?:<w:pPr>(?:(?!</w:pPr>).)*</w:pPr>)?</w:p>)+)(<w:sectPr)', xml2, re.S)
removed = 0
if tail:
    removed = len(re.findall(r'<w:p ', tail.group(1)))
    xml2 = xml2[:tail.start(1)] + xml2[tail.end(1):]
print('numbered', done, 'groups; removed trailing empty paragraphs:', removed)

zout = zipfile.ZipFile(DST, 'w', zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    data = zin.read(it.filename)
    if it.filename == 'word/document.xml':
        data = xml2.encode('utf-8')
    zout.writestr(it, data)
zout.close()
