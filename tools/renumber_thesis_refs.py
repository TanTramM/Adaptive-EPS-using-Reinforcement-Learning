# -*- coding: utf-8 -*-
"""Renumber the references of Documents/Thesis/luanvan.txt by order of first appearance in the text.

Citations are bracket groups that start with a digit: [3], [3,6], [12, tr. 161], [1, mục III.D; 9, mục 1], [14, tr. 73-74, PT (3.19)-(3.21)].
Only the reference numbers at the start of each ';'-separated item are changed (also the second number of [3,6]); page, section and equation
locators stay. Citations are looked for from the line 'CHƯƠNG 1.' up to the line 'TÀI LIỆU THAM KHẢO', except in equation lines '(n.m) ...' and
LaTeX lines '[ ... ]'. The reference list is rewritten in the new order. A reference never cited keeps the next free numbers at the end of the list and is reported.

A copy of the file is kept in Documents/Thesis/draft/luanvan_backup_before_renumber.txt (overwritten at every call). With --dry-run nothing is written.
Run: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/renumber_thesis_refs.py [--dry-run]
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TXT = os.path.join(ROOT, 'Documents', 'Thesis', 'luanvan.txt')
BACKUP = os.path.join(ROOT, 'Documents', 'Thesis', 'draft', 'luanvan_backup_before_renumber.txt')
CITE = re.compile(r'\[(?=\d)([^\[\]]*)\]')
LEAD = re.compile(r'^(\s*)(\d+(?:\s*,\s*\d+)*)(.*)$', re.S)
SKIP = re.compile(r'^\s*(\(\d|\[ )')               # equation line or LaTeX line
MATH = re.compile(r'(\$.+?\$)')                      # inline math, e.g. $[0,1]$, is never a citation


def non_math(line):
    """The parts of the line outside $...$ with their index (even index = text, odd = math)."""
    return list(enumerate(MATH.split(line)))


def main(dry):
    lines = open(TXT, encoding='utf-8').read().split('\n')
    k0 = next(i for i, l in enumerate(lines) if l.startswith('CHƯƠNG 1.'))
    k1 = next(i for i, l in enumerate(lines) if l.strip() == 'TÀI LIỆU THAM KHẢO')
    refs = {}                                   # old number -> line, from the list
    k2 = k1 + 1
    while k2 < len(lines) and (not lines[k2].strip() or re.match(r'^\[\d+\]\s', lines[k2])):
        m = re.match(r'^\[(\d+)\]\s', lines[k2])
        if m:
            refs[int(m.group(1))] = lines[k2]
        k2 += 1
    order = []                                  # old numbers in order of first appearance

    def ids_of(inner):
        for item in inner.split(';'):
            m = LEAD.match(item)
            if m:
                for n in re.findall(r'\d+', m.group(2)):
                    yield int(n)

    for i in range(k0, k1):
        if SKIP.match(lines[i]):
            continue
        for j, part in non_math(lines[i]):
            if j % 2:
                continue
            for m in CITE.finditer(part):
                for n in ids_of(m.group(1)):
                    if n not in order:
                        order.append(n)
    unknown = [n for n in order if n not in refs]
    assert not unknown, 'cited but not in the list: %s' % unknown
    uncited = [n for n in sorted(refs) if n not in order]
    order += uncited
    new_of = {old: i + 1 for i, old in enumerate(order)}

    def fix_group(m):
        items = []
        for item in m.group(1).split(';'):
            mm = LEAD.match(item)
            if mm:
                ids = re.sub(r'\d+', lambda x: str(new_of[int(x.group(0))]), mm.group(2))
                item = mm.group(1) + ids + mm.group(3)
            items.append(item)
        return '[' + ';'.join(items) + ']'

    out = list(lines)
    n_groups = 0
    for i in range(k0, k1):
        if SKIP.match(lines[i]):
            continue
        pieces = []
        for j, part in non_math(lines[i]):
            if j % 2:
                pieces.append(part)
            else:
                part, c = CITE.subn(fix_group, part)
                n_groups += c
                pieces.append(part)
        out[i] = ''.join(pieces)
    entries = sorted(((new_of[old], re.sub(r'^\[\d+\]', '[%d]' % new_of[old], line)) for old, line in refs.items()))
    # the list starts after the heading and one blank line; keep that layout
    first = next(i for i in range(k1 + 1, k2) if re.match(r'^\[\d+\]\s', lines[i]))
    for j, (_, line) in enumerate(entries):
        out[first + j] = line
    print('citation groups rewritten:', n_groups)
    print('old -> new:', ', '.join('%d->%d' % (o, new_of[o]) for o in order))
    print('never cited (moved to the end):', uncited)
    if dry:
        print('dry run, nothing written')
        return
    shutil.copyfile(TXT, BACKUP)
    open(TXT, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    print('written; backup:', BACKUP)


if __name__ == '__main__':
    main('--dry-run' in sys.argv[1:])
