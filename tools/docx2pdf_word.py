"""Export a .docx to PDF with Microsoft Word (so that the equation numbers '#(n)' are typeset as Word does), in a Word process of its own.

A new, invisible Word instance is started (DispatchEx), so the Word window of the user is not touched; the docx is converted from a temporary copy (no lock from
OneDrive or from an open window). The Word process started here is recorded by its PID and is the only one that is stopped when the export takes longer than the
time-out. The page check of docx2pdf_lo.py is reused.

Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/docx2pdf_word.py Documents/Paper/paper_ENG.docx [out.pdf] [--txt Documents/Paper/paper_ENG.txt] [--png DIR]
"""
import os
import shutil
import subprocess
import sys
import tempfile
import time

import pythoncom
import win32com.client

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import docx2pdf_lo as lo

TIMEOUT = 150


def word_pids():
    out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq WINWORD.EXE', '/FO', 'CSV', '/NH'], capture_output=True, text=True).stdout
    return {int(l.split('","')[1]) for l in out.splitlines() if 'WINWORD' in l}


def export(docx, pdf):
    docx = os.path.abspath(docx); pdf = os.path.abspath(pdf)
    work = tempfile.mkdtemp(prefix='docx2pdf_word_')
    src = os.path.join(work, 'in.docx'); out = os.path.join(work, 'in.pdf')
    shutil.copyfile(docx, src)
    before = word_pids()
    pythoncom.CoInitialize()
    word = win32com.client.DispatchEx('Word.Application')
    mine = word_pids() - before                                   # the Word process started by this call
    t0 = time.time()
    try:
        word.Visible = False
        word.DisplayAlerts = 0
        doc = word.Documents.Open(src, ReadOnly=True, AddToRecentFiles=False, Visible=False)
        doc.ExportAsFixedFormat(out, 17)                            # 17 = wdExportFormatPDF
        doc.Close(False)
        word.Quit()
    except Exception:
        for pid in mine:                                          # only the process of this call
            subprocess.run(['taskkill', '/PID', str(pid), '/F'], capture_output=True)
        raise
    finally:
        pythoncom.CoUninitialize()
    if time.time() - t0 > TIMEOUT:
        print('warning: the export took %d s' % (time.time() - t0))
    if not os.path.exists(out):
        raise RuntimeError('Word produced no PDF')
    shutil.copyfile(out, pdf)
    shutil.rmtree(work, ignore_errors=True)
    return pdf


if __name__ == '__main__':
    import argparse, threading
    ap = argparse.ArgumentParser()
    ap.add_argument('docx'); ap.add_argument('pdf', nargs='?'); ap.add_argument('--txt'); ap.add_argument('--png')
    a = ap.parse_args()
    pdf = a.pdf or os.path.splitext(a.docx)[0] + '.pdf'
    before = word_pids()
    res = {}
    def run():
        try: res['pdf'] = export(a.docx, pdf)
        except Exception as e: res['err'] = e
    th = threading.Thread(target=run, daemon=True); th.start(); th.join(TIMEOUT)
    if th.is_alive():
        for pid in word_pids() - before:                          # Word started by this run and still alive after the time-out
            subprocess.run(['taskkill', '/PID', str(pid), '/F'], capture_output=True)
        print('time-out: Word did not finish in %d s (only the Word process of this run was stopped)' % TIMEOUT); sys.exit(2)
    if 'err' in res:
        print('error:', res['err']); sys.exit(1)
    print('converted by Word:', res['pdf'])
    sys.exit(1 if lo.check(res['pdf'], a.txt, a.png) else 0)
