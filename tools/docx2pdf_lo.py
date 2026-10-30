"""Convert a .docx to PDF with LibreOffice (headless, own profile, hard timeout) and check the PDF with PyMuPDF.

Word automation is NOT used: it hung several times on the paper (a stuck Word process, a read-only copy, OneDrive locks). LibreOffice runs as an
ordinary command, writes to a local temporary folder first and copies the result, so it cannot hang on a file that another program holds.

Usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/docx2pdf_lo.py Documents/Paper/paper_ENG.docx [out.pdf] [--txt Documents/Paper/paper_ENG.txt] [--png DIR]

Checks (printed):
  - number of pages and the vertical extent of the text on every page, with the number of pictures, so that a page that is nearly empty shows up;
  - pictures that leave the page margins;
  - every figure caption of the .txt (lines '[Fig. n. caption | path]'): the last words of the caption must be found in the PDF, which catches a caption
    that a too-short text box has cut off;
  - with --png, every page is rendered to DIR/page_NN.png for a look with the eyes.
The conversion engine differs from Word, so line breaks and picture positions can differ a little from the Word layout; the checks look for large faults.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

import fitz

SOFFICE = r'C:\Program Files\LibreOffice\program\soffice.exe'


def convert(docx, pdf, timeout=240):
    docx = os.path.abspath(docx); pdf = os.path.abspath(pdf)
    work = tempfile.mkdtemp(prefix='docx2pdf_')
    try:
        src = os.path.join(work, 'in.docx')
        shutil.copyfile(docx, src)                                       # convert a local copy: no lock from Word or OneDrive
        profile = 'file:///' + os.path.join(work, 'profile').replace('\\', '/')
        cmd = [SOFFICE, '--headless', '--norestore', '-env:UserInstallation=' + profile, '--convert-to', 'pdf:writer_pdf_Export',
               '--outdir', work, src]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        out = os.path.join(work, 'in.pdf')
        if not os.path.exists(out):
            raise RuntimeError('LibreOffice produced no PDF:\n' + r.stdout + r.stderr)
        shutil.copyfile(out, pdf)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return pdf


def captions_of(txt):
    caps = []
    for line in open(txt, encoding='utf-8').read().split('\n'):
        m = re.match(r'\[(Fig\. \d+\..*?) \| ', line)
        if m:
            caps.append(m.group(1))
    return caps


def norm(t):
    return re.sub(r'[^a-z0-9]', '', t.lower())


def tail_words(caption, n=5):
    """last words of the caption outside the inline math (the equations are typeset as objects, their text is not reliable)"""
    plain = re.sub(r'\$[^$]*\$', ' ', caption)
    return re.findall(r"[A-Za-z][A-Za-z\-]+", plain)[-n:]


def check(pdf, txt=None, png=None):
    doc = fitz.open(pdf)
    print('pages:', len(doc))
    problems = 0
    for i, page in enumerate(doc, 1):
        H, W = page.rect.height, page.rect.width
        blocks = [b for b in page.get_text('blocks') if b[4].strip() and b[3] < 0.93 * H]      # without the page-number footer
        y1 = max((b[3] for b in blocks), default=0)
        imgs = page.get_image_info()
        first = (blocks[0][4].strip().split('\n')[0][:48] if blocks else '')
        print('  page %2d: text to %3d%% of height, %d picture(s) | %s' % (i, round(100 * y1 / H), len(imgs), first))
        for im in imgs:
            x0, y0, x1, y1i = im['bbox']
            if x0 < 20 or x1 > W - 20 or y0 < 20 or y1i > H - 20:
                print('    ! picture outside the margins on page %d: %s' % (i, [round(v) for v in im['bbox']])); problems += 1
        if png:
            os.makedirs(png, exist_ok=True)
            page.get_pixmap(dpi=80).save(os.path.join(png, 'page_%02d.png' % i))
    if txt:
        alltext = norm(' '.join(p.get_text() for p in doc))
        for cap in captions_of(txt):
            tw = tail_words(cap)
            ok = norm(' '.join(tw)) in alltext
            label = cap[:7]
            print('  caption %-7s last words "%s": %s' % (label, ' '.join(tw), 'found' if ok else 'MISSING (cut off?)'))
            problems += 0 if ok else 1
    print('problems:', problems)
    return problems


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('docx'); ap.add_argument('pdf', nargs='?')
    ap.add_argument('--txt'); ap.add_argument('--png')
    a = ap.parse_args()
    pdf = a.pdf or os.path.splitext(a.docx)[0] + '.pdf'
    print('converted:', convert(a.docx, pdf))
    sys.exit(1 if check(pdf, a.txt, a.png) else 0)
