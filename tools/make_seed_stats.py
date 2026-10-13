"""Statistics over the noise seeds of the scoring cases (Map, PI, PID; seeds 99999 down to 99995, the same sequences for every controller).

Reads Result/Controllers/<Ctrl>/Cases/<Ctrl>_metrics_s<seed>.csv written by run_cases.m (run_scoring_seeds.m for the extra seeds) and writes
Result/Compare/Map_vs_PI_vs_PID/Map_vs_PI_vs_PID_stats_s99995-s99999.csv: for every reported quantity the five values, the mean and the sample standard deviation
(ddof = 1). The same numbers are printed.

Quantities (names as in the paper): whole-case RMS e_T, S and reverse assist of the five cases; DRY largest |e_rel| of the 15 windows (and the worst window);
SLIP e_rel after mu 0.8 -> 0.3 (down_post) and after mu 0.3 -> 0.8 (up_post), RMS e_T in the puddle (pud_in); RAMP e_rel of the three scenes while the speed
falls (dn) and rises (up); EDGE e_rel at 0.35 g and 0.4 g at 40 km/h.

Usage: C:/Users/Admin/anaconda3/python.exe -I tools/make_seed_stats.py   (from the repo root)
"""
import os
import numpy as np
import pandas as pd

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RC = os.path.join(REPO, 'Result', 'Controllers')
OUT = os.path.join(REPO, 'Result', 'Compare', 'Map_vs_PI_vs_PID')
SEEDS = [99999, 99998, 99997, 99996, 99995]
CTRL = ['Map', 'PI', 'PID']
CASES = ['DRY', 'RAMP', 'SLIP', 'WEAVE', 'EDGE']


def load():
    return {(c, s): pd.read_csv(os.path.join(RC, c, 'Cases', f'{c}_metrics_s{s}.csv')) for c in CTRL for s in SEEDS}


def win(df, case, label, col):
    r = df[(df.Case == case) & (df.Window == label)]
    return float(r[col].iloc[0])


def quantities(M):
    """{name: {ctrl: [values over the seeds]}}"""
    q = {}

    def put(name, ctrl, vals):
        q.setdefault(name, {})[ctrl] = list(vals)
    for c in CTRL:
        for case in CASES:
            for col, nm in (('RMS_eT_Nm', 'RMS_eT'), ('S_Nm', 'S'), ('Rev_pct', 'Rev')):
                put(f'{case}_whole_{nm}', c, [win(M[(c, s)], case, 'whole case', col) for s in SEEDS])
        dry = [M[(c, s)][(M[(c, s)].Case == 'DRY') & (M[(c, s)].Window != 'whole case')] for s in SEEDS]
        put('DRY_max_abs_erel', c, [d.Mean_eT_signed_pct_of_Tdref.abs().max() for d in dry])
        put('DRY_max_abs_erel_window', c, [d.loc[d.Mean_eT_signed_pct_of_Tdref.abs().idxmax(), 'Window'] for d in dry])
        put('DRY_erel_v40a0p3r', c, [win(M[(c, s)], 'DRY', 'v40a0p3r', 'Mean_eT_signed_pct_of_Tdref') for s in SEEDS])
        put('DRY_meanerr_v40a0p3r_Nm', c, [win(M[(c, s)], 'DRY', 'v40a0p3r', 'Mean_eT_Nm') for s in SEEDS])
        for lab, nm in (('down_post', 'SLIP_erel_down'), ('up_post', 'SLIP_erel_up')):
            put(nm, c, [win(M[(c, s)], 'SLIP', lab, 'Mean_eT_signed_pct_of_Tdref') for s in SEEDS])
        put('SLIP_puddle_RMS_eT', c, [win(M[(c, s)], 'SLIP', 'pud_in', 'RMS_eT_Nm') for s in SEEDS])
        for sc in ('lo', 'mid', 'hi'):
            for d in ('dn', 'up'):
                put(f'RAMP_erel_{sc}_{d}', c, [win(M[(c, s)], 'RAMP', f'{sc}_{d}', 'Mean_eT_signed_pct_of_Tdref') for s in SEEDS])
        for lab in ('v40a0p35l', 'v40a0p4l'):
            put(f'EDGE_erel_{lab}', c, [win(M[(c, s)], 'EDGE', lab, 'Mean_eT_signed_pct_of_Tdref') for s in SEEDS])
    return q


def summarize(q):
    rows = []
    for name, per in q.items():
        for c in CTRL:
            v = per[c]
            if isinstance(v[0], str):
                rows.append(dict(quantity=name, controller=c, mean=np.nan, sd=np.nan, **{f's{s}': x for s, x in zip(SEEDS, v)}))
                continue
            a = np.array(v, dtype=float)
            rows.append(dict(quantity=name, controller=c, mean=a.mean(), sd=a.std(ddof=1), **{f's{s}': x for s, x in zip(SEEDS, v)}))
    return pd.DataFrame(rows)


if __name__ == '__main__':
    q = quantities(load())
    df = summarize(q)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'Map_vs_PI_vs_PID_stats_s99995-s99999.csv')
    df.to_csv(path, index=False)
    pd.set_option('display.width', 220); pd.set_option('display.max_rows', 400)
    print(df.round(4).to_string(index=False))
    print('written', path)
