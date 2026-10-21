# -*- coding: utf-8 -*-
"""Summary of the DREWS v2 runs: mean and standard deviation over the five scoring seeds 99995-99999, per controller, case and window.

usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/summarize_drews_v2.py Map PID [MapPID ...]
writes Result/Compare/DREWS_v2_summary/DREWS_v2_<ctrl>_summary.csv (all rows) and prints the 'whole case' rows and the window means.
"""
import csv, os, sys, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEEDS = [99995, 99996, 99997, 99998, 99999]
COLS = ['RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s', 'S_Nm', 'Rev_pct', 'Peak_Ta_pct_of_Tamax',
        'MaxAbs_Ts_Nm', 'MaxOver_Nm', 'Heavy_s', 'MinRatio', 'Light_s', 'RevPeak_Nm', 'Sat_pct', 'Recovery_s']


def num(x):
    try:
        v = float(x)
        return v
    except ValueError:
        return float('nan')


def stats(v):
    v = [x for x in v if not math.isnan(x)]
    if not v:
        return float('nan'), float('nan'), 0
    m = sum(v) / len(v)
    sd = math.sqrt(sum((x - m) ** 2 for x in v) / (len(v) - 1)) if len(v) > 1 else 0.0
    return m, sd, len(v)


def main(ctrls):
    outdir = os.path.join(ROOT, 'Result', 'Compare', 'DREWS_v2_summary')
    os.makedirs(outdir, exist_ok=True)
    for c in ctrls:
        rows = {}
        order = []
        for s in SEEDS:
            f = os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_v2', '%s_metrics_s%d.csv' % (c, s))
            if not os.path.isfile(f):
                print('missing', f)
                continue
            for r in csv.DictReader(open(f, encoding='utf-8')):
                k = (r['Case'], r['Window'])
                if k not in rows:
                    rows[k] = {col: [] for col in COLS}
                    order.append(k)
                for col in COLS:
                    rows[k][col].append(num(r[col]))
        out = os.path.join(outdir, 'DREWS_v2_%s_summary.csv' % c)
        with open(out, 'w', newline='', encoding='utf-8') as fh:
            w = csv.writer(fh)
            w.writerow(['Case', 'Window', 'n_seeds'] + [x for col in COLS for x in (col + '_mean', col + '_std')])
            for k in order:
                line = [k[0], k[1], max(stats(rows[k][col])[2] for col in COLS)]
                for col in COLS:
                    m, sd, n = stats(rows[k][col])
                    line += ['' if math.isnan(m) else '%.5g' % m, '' if math.isnan(sd) else '%.3g' % sd]
                w.writerow(line)
        print('\n=== %s (mean +- std over %d seeds) ===' % (c, len(SEEDS)))
        for k in order:
            if k[1] == 'whole case':
                print('%-6s RMS_eT %.4f+-%.4f  MaxOver %.3f  Heavy_s %.2f  MinRatio %.3f  Light_s %.2f  RevPeak %.2f  Sat%% %.2f  S %.4f  TV %.3f' % (
                    (k[0],) + tuple(v for col in ('RMS_eT_Nm',) for v in stats(rows[k][col])[:2]) +
                    tuple(stats(rows[k][col])[0] for col in ('MaxOver_Nm', 'Heavy_s', 'MinRatio', 'Light_s', 'RevPeak_Nm', 'Sat_pct', 'S_Nm', 'TV_Ta_Nm_per_s'))))
        for k in order:
            if k[1] != 'whole case':
                m, sd, n = stats(rows[k]['Mean_eT_signed_pct_of_Tdref'])
                rec = stats(rows[k]['Recovery_s'])
                print('  %-6s %-12s e_rel %+7.2f%% +-%.2f  RMS_eT %.4f%s' % (k[0], k[1], m, sd, stats(rows[k]['RMS_eT_Nm'])[0],
                      ('  Recovery_s %.2f (n=%d)' % (rec[0], rec[2])) if k[1].endswith('_rec') else ''))
        print('written', out)


if __name__ == '__main__':
    main(sys.argv[1:] or ['PID', 'Map'])
