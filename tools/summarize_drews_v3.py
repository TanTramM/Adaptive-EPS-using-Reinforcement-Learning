# -*- coding: utf-8 -*-
"""Summary of the DREWS v3 runs (five cases of 100 s, Documents/Shared/KeHoach_DREWS_v3.txt): Map, PID, MapPID, seeds 99995-99999.

usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/summarize_drews_v3.py
writes in Result/Compare/DREWS_v3_summary/:
  DREWS_v3_all_runs.csv         one row per controller, seed, case, window (long format, for plots)
  DREWS_v3_<Ctrl>_summary.csv   mean and standard deviation over the seeds of every metric, per case and window
  DREWS_v3_slip_delta.csv       SLIP: signed error (% of T_d,ref) of every window minus that of the reference window of the same scene (Delta, mean and std over seeds)
"""
import os
import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEEDS = [99995, 99996, 99997, 99998, 99999]
CTRLS = ['Map', 'PID', 'MapPID']
OUT = os.path.join(ROOT, 'Result', 'Compare', 'DREWS_v3_summary')
SIGNED = 'Mean_eT_signed_pct_of_Tdref'
REF = {'stair': 'stair_ref', 'ramp': 'ramp_ref', 'pud': 'pud_ref'}   # reference window (mu 0.8) of every SLIP scene


def main():
    os.makedirs(OUT, exist_ok=True)
    frames = []
    for c in CTRLS:
        for s in SEEDS:
            f = os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_v3', '%s_metrics_s%d.csv' % (c, s))
            if not os.path.isfile(f):
                print('missing', f)
                continue
            T = pd.read_csv(f)
            T.insert(0, 'Seed', s)
            T.insert(0, 'Ctrl', c)
            frames.append(T)
    A = pd.concat(frames, ignore_index=True)
    A.to_csv(os.path.join(OUT, 'DREWS_v3_all_runs.csv'), index=False)
    num = [c for c in A.columns if c not in ('Ctrl', 'Seed', 'Case', 'Window')]
    for c in CTRLS:
        d = A[A.Ctrl == c]
        g = d.groupby(['Case', 'Window'], sort=False)[num]
        M, S = g.mean(), g.std()
        S.columns = [x + '_std' for x in S.columns]
        M.columns = [x + '_mean' for x in M.columns]
        R = pd.concat([M, S], axis=1)
        R.insert(0, 'n_seeds', d.groupby(['Case', 'Window'], sort=False).Seed.nunique())
        R = R[['n_seeds'] + [x for col in num for x in (col + '_mean', col + '_std')]]
        R.reset_index().to_csv(os.path.join(OUT, 'DREWS_v3_%s_summary.csv' % c), index=False)
    # Delta of the SLIP windows: signed error of the window minus that of the reference window of the same scene, per seed, then mean and std over seeds
    rows = []
    sl = A[A.Case == 'SLIP']
    for c in CTRLS:
        for sc, ref in REF.items():
            for s in SEEDS:
                d = sl[(sl.Ctrl == c) & (sl.Seed == s)].set_index('Window')
                if ref not in d.index:
                    continue
                r0 = d.loc[ref, SIGNED]
                for w in d.index:
                    if w.startswith(sc + '_') and w != ref:
                        rows.append((c, sc, w, s, d.loc[w, SIGNED], d.loc[w, SIGNED] - r0))
    D = pd.DataFrame(rows, columns=['Ctrl', 'Scene', 'Window', 'Seed', 'signed_pct', 'Delta_pct'])
    G = D.groupby(['Scene', 'Window', 'Ctrl'], sort=False).agg(signed_pct_mean=('signed_pct', 'mean'), Delta_pct_mean=('Delta_pct', 'mean'),
                                                              Delta_pct_std=('Delta_pct', 'std'), n_seeds=('Seed', 'nunique')).reset_index()
    G.to_csv(os.path.join(OUT, 'DREWS_v3_slip_delta.csv'), index=False)
    pd.set_option('display.width', 200)
    print(A[A.Window == 'whole case'].groupby(['Case', 'Ctrl'])[['RMS_eT_Nm', 'S_Nm', 'Heavy_s', 'Light_s']].mean().round(4).to_string())
    print(G.round(3).to_string())


if __name__ == '__main__':
    main()
