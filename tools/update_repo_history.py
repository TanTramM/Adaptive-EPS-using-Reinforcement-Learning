# -*- coding: utf-8 -*-
"""Regenerate Tracking/repo_history.md: which machine did what, from `git log` of the current branch (works on any machine, reads only git).

usage (from the repo root, any machine):
  python tools/update_repo_history.py                      rebuild the automatic part from git log (the notes part is kept)
  python tools/update_repo_history.py --note "text" [--machine PC|laptop]   append a dated note (what was run, where the files are) and rebuild
The machine of a commit comes from the tag at the start of the message ("[PC] ..." or "[laptop] ..."; tools/sync_repo.sh adds it from the host name).
Older commits carry no tag: the word "laptop" or "PC" in the message decides, otherwise the machine is shown as "?" (not recorded).
The file has an automatic part between the two marker lines (always rewritten) and a notes part after it (never rewritten except by --note).
"""
import argparse
import datetime
import os
import re
import socket
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'Tracking', 'repo_history.md')
BEGIN = '<!-- AUTO-BEGIN (tools/update_repo_history.py rewrites everything up to AUTO-END) -->'
END = '<!-- AUTO-END -->'
PC_HOST = 'DESKTOP-G6T192V'
OVERRIDE = {'2672ac7': 'PC', '3403405': 'PC'}   # untagged commits known to come from the PC (checked by hand 2026-10-23)


def machine_here():
    return 'PC' if socket.gethostname() == PC_HOST else 'laptop'


def machine_of(msg, h=None):
    if h in OVERRIDE:
        return OVERRIDE[h]
    m = re.match(r'\s*\[(PC|laptop)\]', msg, re.I)
    if m:
        return 'PC' if m.group(1).lower() == 'pc' else 'laptop'
    low = msg.lower()
    if 'laptop' in low and re.search(r'\bpc\b', low):
        return 'PC+laptop'          # merge of both machines
    if 'laptop' in low:
        return 'laptop'
    if re.search(r'\bpc\b', low):
        return 'PC'
    return '?'


def git_log():
    r = subprocess.run(['git', 'log', '--format=%h\x1f%ad\x1f%s', '--date=format:%Y-%m-%d %H:%M'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
    rows = []
    for line in r.stdout.splitlines():
        h, d, s = line.split('\x1f', 2)
        rows.append((h, d, s))
    return rows


def auto_part(rows):
    out = [BEGIN, '',
           '## Máy', '',
           '- PC (máy bàn chính, tên máy %s): chạy phần lớn mô phỏng và viết bài; nhánh làm việc cuối cùng đã gộp vào main.' % PC_HOST,
           '- laptop: chạy song song phần việc chia cho nó (MapPID, một nửa Map và PID khi so mặt Pareto chung), thường đẩy lên nhánh phụ rồi gộp.',
           '- Commit trước 2026-10-22 chưa ghi máy (hiện "?"): lúc đó làm trên một máy; từ nay mọi commit có tag [PC] hoặc [laptop] ở đầu (tools/sync_repo.sh tự thêm).',
           '',
           '## Lịch sử commit theo ngày (mới nhất trước; sinh tự động từ git log, %d commit)' % len(rows), '']
    day = None
    for h, d, s in rows:
        if d[:10] != day:
            day = d[:10]
            cnt = {}
            for hh, dd, ss in rows:
                if dd[:10] == day:
                    mm = machine_of(ss, hh)
                    cnt[mm] = cnt.get(mm, 0) + 1
            out += ['', '### %s (%s)' % (day, ', '.join('%s %d' % (k, v) for k, v in sorted(cnt.items()))), '']
        msg = re.sub(r'^\s*\[(PC|laptop)\]\s*', '', s, flags=re.I)
        out.append('- %s %s [%s] %s' % (d[11:], h, machine_of(s, h), msg))
    out += ['', END]
    return '\n'.join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--note')
    ap.add_argument('--machine')
    a = ap.parse_args()
    notes = ''
    if os.path.isfile(OUT):
        old = open(OUT, encoding='utf-8').read()
        if END in old:
            notes = old.split(END, 1)[1].lstrip('\n')
    if not notes.strip():
        notes = '## Ghi chú tay (ai chạy gì, file kết quả ở đâu; thêm bằng --note)\n'
    if a.note:
        mach = a.machine or machine_here()
        notes = notes.rstrip('\n') + '\n- %s [%s] %s\n' % (datetime.datetime.now().strftime('%Y-%m-%d %H:%M'), mach, a.note)
    head = '# Lịch sử repo: máy nào làm gì\n\nFile này do `tools/update_repo_history.py` cập nhật (phần tự động đọc từ git log; phần ghi chú tay ở cuối). Laptop và PC dùng chung một file qua main.\n\n'
    open(OUT, 'w', encoding='utf-8', newline='\n').write(head + auto_part(git_log()) + '\n\n' + notes)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
