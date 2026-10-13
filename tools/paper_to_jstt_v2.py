"""Version 2 of the journal text: the scoring numbers become the mean (and the standard deviation) over five noise realizations.

Input : Documents/Paper/paper_jstt_v1.txt (from paper_to_jstt_txt.py) and the statistics of tools/make_seed_stats.py
        (Result/Compare/Map_vs_PI_vs_PID/Map_vs_PI_vs_PID_stats_s99995-s99999.csv)
Output: Documents/Paper/paper_jstt_v2.txt

What changes: every number that depends on the noise (Abstract, Sections 4.1, 5.2, 5.3, 5.4, Table 7, Conclusions) is replaced by the mean over seeds 99999 to 99995;
the signs and the wording that were fixed by one realization are rewritten (e.g. PI and PID steady errors are both slightly negative and indistinguishable from
each other); Table 7 is printed as mean ± standard deviation; Figs. 4-6 are said to show seed 99999; the limitation sentence says what was done.
Numbers of the calibration (Table 3, Table 6, Fig. 3) are not touched: the calibration uses one realization by protocol.

Usage: python tools/paper_to_jstt_v2.py Documents/Paper/paper_jstt_v1.txt Documents/Paper/paper_jstt_v2.txt
"""
import os
import re
import sys
import pandas as pd

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = os.path.join(REPO, 'Result', 'Compare', 'Map_vs_PI_vs_PID', 'Map_vs_PI_vs_PID_stats_s99995-s99999.csv')
MINUS = '−'


def load():
    df = pd.read_csv(STATS)
    return {(r.quantity, r.controller): (r['mean'], r['sd']) for _, r in df.iterrows()}


def num(x, d=2, sign=False):
    s = f'{abs(x):.{d}f}'
    if x < 0 and float(s) != 0:
        return MINUS + s
    if sign and float(s) != 0:
        return '+' + s
    return s


def sub(t, old, new):
    assert old in t, old
    return t.replace(old, new)


def main(src, dst):
    S = load()
    m = lambda q, c: S[(q, c)][0]
    sd = lambda q, c: S[(q, c)][1]
    t = open(src, encoding='utf-8').read()

    # Abstract
    t = sub(t, 'steady relative torque error of −4.07%, compared with −0.04% for PI and +0.02% for PID.',
            f'steady relative torque error of {num(m("SLIP_erel_down", "Map"))}%, compared with {num(m("SLIP_erel_down", "PI"))}% for PI '
            f'and {num(m("SLIP_erel_down", "PID"))}% for PID (means over five noise realizations).')
    rev = m('WEAVE_whole_Rev', 'Map')
    t = sub(t, 'reverse assistance occurs during 25.7% of the evaluated time for PID, compared with 0% for the assist map.',
            f'reverse assistance occurs during {m("WEAVE_whole_Rev", "PID"):.1f}% of the evaluated time for PID, compared with '
            + ('less than 0.1%' if rev < 0.1 else f'{rev:.1f}%') + ' for the assist map.')

    # Section 4.1
    t = sub(t, 'The same noise realization is used for all controllers within each comparison.',
            'The same five noise realizations (random-number seeds 99999 to 99995) are used for all controllers. The scoring results are reported as the '
            'mean and the sample standard deviation over the five realizations; the time histories in Figs. 4–6 show the realization with seed 99999.')

    # Section 5.2
    t = sub(t, 'the maximum absolute steady-state errors are 2.03% for PI, and 1.71% for PID.',
            f'the maximum absolute steady-state errors are {num(m("DRY_max_abs_erel", "PI"))}% for PI and {num(m("DRY_max_abs_erel", "PID"))}% for PID '
            f'(standard deviations {num(sd("DRY_max_abs_erel", "PI"))}% and {num(sd("DRY_max_abs_erel", "PID"))}%). The difference between the two feedback '
            'controllers is within these standard deviations.')

    # Section 5.3
    t = sub(t, 'steady relative tracking error of −4.07%, compared with −0.04% for PI and +0.02% for PID.',
            f'steady relative tracking error of {num(m("SLIP_erel_down", "Map"))}%, compared with {num(m("SLIP_erel_down", "PI"))}% for PI and '
            f'{num(m("SLIP_erel_down", "PID"))}% for PID (standard deviation {num(sd("SLIP_erel_down", "PI"))}% and {num(sd("SLIP_erel_down", "PID"))}%). '
            'The two feedback controllers are therefore both close to zero and cannot be distinguished from each other.')
    t = sub(t, 'the RMS tracking error is 2.30 N·m for the assist map, 0.85 N·m for PI, and 0.34 N·m for PID.',
            f'the RMS tracking error is {m("SLIP_puddle_RMS_eT", "Map"):.2f} N·m for the assist map, {m("SLIP_puddle_RMS_eT", "PI"):.2f} N·m for PI, '
            f'and {m("SLIP_puddle_RMS_eT", "PID"):.2f} N·m for PID.')
    t = sub(t, 'the corresponding steady relative errors are +1.02%, −0.18%, and −0.21%.',
            f'the corresponding steady relative errors are {num(m("SLIP_erel_up", "Map"), sign=True)}%, {num(m("SLIP_erel_up", "PI"))}%, '
            f'and {num(m("SLIP_erel_up", "PID"))}%.')

    # Section 5.4
    t = sub(t, 'Table 7 reports whole-case RMS tracking error, high-frequency assist-torque content, and reverse-assist percentage.',
            'Table 7 reports whole-case RMS tracking error, high-frequency assist-torque content, and reverse-assist percentage as mean ± standard deviation over the five noise realizations.')
    t = sub(t, 'the RMS error decreases from 1.327 N·m for the assist map to 0.378 N·m for PI and 0.218 N·m for PID.',
            f'the RMS error decreases from {m("WEAVE_whole_RMS_eT", "Map"):.3f} N·m for the assist map to {m("WEAVE_whole_RMS_eT", "PI"):.3f} N·m for PI '
            f'and {m("WEAVE_whole_RMS_eT", "PID"):.3f} N·m for PID.')
    t = sub(t, 'The corresponding S values increase from 0.160 to 0.334 and 0.410 N·m.',
            f'The corresponding S values increase from {m("WEAVE_whole_S", "Map"):.3f} to {m("WEAVE_whole_S", "PI"):.3f} and {m("WEAVE_whole_S", "PID"):.3f} N·m.')
    t = sub(t, 'The corresponding PI errors are −0.4% and −0.6%, while the PID errors are −0.2% at both operating points.',
            f'The corresponding PI errors are {num(m("EDGE_erel_v40a0p35l", "PI"), 1)}% and {num(m("EDGE_erel_v40a0p4l", "PI"), 1)}%, while the PID errors are '
            f'{num(m("EDGE_erel_v40a0p35l", "PID"), 1)}% and {num(m("EDGE_erel_v40a0p4l", "PID"), 1)}%.')

    # Table 7 (long format: one row per scenario and controller)
    head = 'Table 7. Whole-case performance of the investigated controllers (mean ± standard deviation over five noise realizations).'
    rows = ['Scenario | Controller | RMS tracking error (N·m) | S (N·m) | Reverse assist (%)']
    names = {'Map': 'Assist map', 'PI': 'PI', 'PID': 'PID'}
    for case in ('DRY', 'SLIP', 'WEAVE', 'RAMP', 'EDGE'):
        for c in ('Map', 'PI', 'PID'):
            cells = []
            for q, d in (('RMS_eT', 3), ('S', 3), ('Rev', 2)):
                a, b = S[(f'{case}_whole_{q}', c)]
                cells.append(f'{a:.{d}f} ± {b:.{d}f}')
            rows.append(f'{case} | {names[c]} | ' + ' | '.join(cells))
    t = re.sub(r'Table 7\. Whole-case performance[^\n]*\n(?:[^\n]* \| [^\n]*\n)+', head + '\n' + '\n'.join(rows) + '\n', t, count=1)
    assert 'Controller | RMS tracking error' in t

    # captions of the time histories and the limitation sentence
    for n in (4, 5, 6):
        t = re.sub(r'(\[Fig\. %d\. [^|\]]*?)( \| Figures/)' % n, r'\1 The noise realization with seed 99999 is shown.\2', t, count=1)
    t = sub(t, 'The desired torque is taken from one published reference characteristic. ',
            'The desired torque is taken from one published reference characteristic. Each controller was calibrated with a single noise realization, '
            'whereas the scoring cases are averaged over five realizations. ')

    # Conclusions
    t = sub(t, 'produced a steady relative tracking error of −4.07% for the assist map, compared with −0.04% for PI and +0.02% for PID.',
            f'produced a steady relative tracking error of {num(m("SLIP_erel_down", "Map"))}% for the assist map, compared with {num(m("SLIP_erel_down", "PI"))}% for PI '
            f'and {num(m("SLIP_erel_down", "PID"))}% for PID.')
    open(dst, 'w', encoding='utf-8').write(t)
    print('Wrote', dst)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
