"""Version 5 of the journal text: every figure caption shortened to one short line (the panel content is described in the text, not in the caption).

Usage: python tools/paper_jstt_short_captions.py Documents/Paper/paper_jstt_v4.txt Documents/Paper/paper_jstt_v5.txt
"""
import re
import sys

SHORT = {
    1: 'Mechanical structure of the column-type EPS.',
    2: 'Block diagram of the coupled C-EPS–vehicle plant.',
    3: 'Control architectures: (a) assist map, (b) PI/PID torque feedback.',
    4: 'Tracking–noise trade-off on CALIB: (a) assist map, (b) PI, (c) PID.',
    5: 'DRY scenario: (a) assist map, (b) PI, (c) PID.',
    6: 'SLIP scenario: (a) assist map, (b) PI, (c) PID.',
    7: 'Tracking error in the five scenarios: (a) assist map, (b) PI, (c) PID.',
}


def main(src, dst):
    t = open(src, encoding='utf-8').read()
    n_done = 0

    def fix(m):
        nonlocal n_done
        n = int(m.group(1))
        n_done += 1
        return '[Fig. %d. %s | ' % (n, SHORT[n])
    t = re.sub(r'\[Fig\. (\d)\. .*? \| (?=Figures/)', fix, t)
    assert n_done == 7, n_done
    open(dst, 'w', encoding='utf-8').write(t)
    print('Wrote', dst, '(%d captions shortened)' % n_done)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
