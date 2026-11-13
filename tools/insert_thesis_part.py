"""Insert one part of the thesis (a text file in the luanvan.txt convention) before the line 'TAI LIEU THAM KHAO' of Documents/Thesis/luanvan.txt.

Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/insert_thesis_part.py Documents/Thesis/draft/ch3_parts/01_Map.txt

The part goes in front of the reference list with one blank line on each side. Safety: the script refuses to insert when a heading of the part
('CHUONG n.' or 'n.m.' or 'n.m.k.' line) is already in luanvan.txt, and it keeps a copy of the file as it was in
Documents/Thesis/draft/luanvan_backup_last.txt (overwritten at every call). Nothing else of luanvan.txt is touched.
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TXT = os.path.join(ROOT, 'Documents', 'Thesis', 'luanvan.txt')
BACKUP = os.path.join(ROOT, 'Documents', 'Thesis', 'draft', 'luanvan_backup_last.txt')
MARK = 'T\u00c0I LI\u1ec6U THAM KH\u1ea2O'            # the line that starts the reference list
HEADING = re.compile(r'^(CH\S+NG \d+\.|\d+\.\d+\.(\d+\.)? )')


def main(part_path):
    part = open(part_path, encoding='utf-8').read().strip('\n').split('\n')
    lines = open(TXT, encoding='utf-8').read().split('\n')
    for h in (l for l in part if HEADING.match(l)):
        if h in lines:
            sys.exit('already in luanvan.txt, nothing inserted: ' + h)
    marks = [i for i, l in enumerate(lines) if l.strip() == MARK]
    assert len(marks) == 1, 'the line of the reference list was not found exactly once'
    m = marks[0]
    k = m
    while lines[k - 1].strip() == '':
        k -= 1
    shutil.copyfile(TXT, BACKUP)
    new = lines[:k] + [''] + part + [''] + lines[m:]
    open(TXT, 'w', encoding='utf-8', newline='').write('\n'.join(new))
    print('inserted %d lines before the reference list; headings: %s' % (len(part), [l for l in part if HEADING.match(l)]))


if __name__ == '__main__':
    main(sys.argv[1])
