# -*- coding: utf-8 -*-
"""Summary tables of the SSW runs (three cases STEADY, SLIP, WEAVE of 100 s, Documents/Shared/KeHoach_SSW.txt), csv only.

Seeds: local (Map 01001-01003, PID 11001-11003, MapPID 31001-31003) and common (99987-99989, the comparison).
usage: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/summarize_ssw.py
writes in Result/Compare/SSW_summary/:
  SSW_all_runs.csv        one row per controller, seed group, seed, case, window (metrics of run_cases)
  SSW_whole_case.csv      per seed group, case and controller: mean and std of R (RMS e_T), S, J = R x S and the report columns over the three seeds
  SSW_windows_summary.csv per seed group, window and controller: mean and std of the signed error (% of T_d,ref), RMS e_T, Recovery_s, Delta (window
                          minus the reference window of the same scene: stair_ref, pud_ref, lane_ref), achieved and target grip use, achieved / target a_y
"""
import os
import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'Result', 'Compare', 'SSW_summary')
CTRLS = ['Map', 'PID', 'MapPID']
SEEDS = {'local': {'Map': [1001, 1002, 1003], 'PID': [11001, 11002, 11003], 'MapPID': [31001, 31002, 31003]},
         'common': {c: [99987, 99988, 99989] for c in CTRLS}}
SIGNED = 'Mean_eT_signed_pct_of_Tdref'
REF = {'stair': 'stair_ref', 'pud': 'pud_ref', 'lane': 'lane_ref'}
G = 9.81


def main():
    W = pd.read_csv(os.path.join(OUT, 'SSW_windows.csv'))
    frames, extra = [], []
    for grp, sd in SEEDS.items():
        for c in CTRLS:
            for s in sd[c]:
                d = os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_ssw')
                T = pd.read_csv(os.path.join(d, '%s_metrics_s%05d.csv' % (c, s)))
                T.insert(0, 'Seed', s); T.insert(0, 'Group', grp); T.insert(0, 'Ctrl', c)
                frames.append(T)
                for case in W.case.unique():
                    sig = pd.read_csv(os.path.join(d, '%s_%s_sig_s%05d.csv' % (c, case, s)))
                    for _, w in W[W.case == case].iterrows():
                        m = (sig.t >= w.t0) & (sig.t <= w.t1)
                        x = sig[m]
                        extra.append((c, grp, s, case, w.label, float((x.a_y.abs() / G / x.mu).mean()), float((x.a_y_target_g.abs() / x.mu).mean()),
                                      float((x.a_y.abs() / G).mean() / max(x.a_y_target_g.abs().mean(), 1e-9))))
    A = pd.concat(frames, ignore_index=True)
    A.to_csv(os.path.join(OUT, 'SSW_all_runs.csv'), index=False)
    E = pd.DataFrame(extra, columns=['Ctrl', 'Group', 'Seed', 'Case', 'Window', 'grip_use', 'grip_target', 'ay_ratio'])
    # whole case
    wc = A[A.Window == 'whole case'].copy()
    wc['J'] = wc.RMS_eT_Nm * wc.S_Nm
    cols = ['RMS_eT_Nm', 'S_Nm', 'J', 'MaxAbs_eT_Nm', 'TV_Ta_Nm_per_s', 'Heavy_s', 'Light_s', 'MinRatio', 'Sat_pct', 'Peak_Ta_pct_of_Tamax']
    g = wc.groupby(['Group', 'Case', 'Ctrl'], sort=False)[cols]
    M, S = g.mean(), g.std()
    M.columns = [x + '_mean' for x in cols]; S.columns = [x + '_std' for x in cols]
    WC = pd.concat([M, S], axis=1)[[x for col in cols for x in (col + '_mean', col + '_std')]].reset_index()
    WC.to_csv(os.path.join(OUT, 'SSW_whole_case.csv'), index=False)
    # windows, with Delta against the reference window of the same scene
    wn = A[A.Window != 'whole case'][['Ctrl', 'Group', 'Seed', 'Case', 'Window', SIGNED, 'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Recovery_s']].copy()
    wn['Delta_pct'] = np.nan
    for (c, s), d in wn.groupby(['Ctrl', 'Seed']):
        for sc, ref in REF.items():
            r0 = d.loc[d.Window == ref, SIGNED]
            if len(r0) == 0:
                continue
            k = d.index[d.Window.str.startswith(sc + '_')]
            wn.loc[k, 'Delta_pct'] = d.loc[k, SIGNED] - r0.iloc[0]
    wn = wn.merge(E, on=['Ctrl', 'Group', 'Seed', 'Case', 'Window'], how='left')
    vals = [SIGNED, 'Delta_pct', 'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Recovery_s', 'grip_use', 'grip_target', 'ay_ratio']
    g = wn.groupby(['Group', 'Case', 'Window', 'Ctrl'], sort=False)[vals]
    M, S = g.mean(), g.std()
    M.columns = [x + '_mean' for x in vals]; S.columns = [x + '_std' for x in vals]
    WS = pd.concat([M, S], axis=1)[[x for col in vals for x in (col + '_mean', col + '_std')]].reset_index()
    WS.to_csv(os.path.join(OUT, 'SSW_windows_summary.csv'), index=False)
    pd.set_option('display.width', 220)
    print(WC[['Group', 'Case', 'Ctrl', 'RMS_eT_Nm_mean', 'RMS_eT_Nm_std', 'S_Nm_mean', 'S_Nm_std', 'J_mean', 'Light_s_mean', 'Heavy_s_mean']].round(4).to_string(index=False))
    print(WS[WS.Group == 'common'][['Case', 'Window', 'Ctrl', SIGNED + '_mean', 'Delta_pct_mean', 'grip_use_mean', 'ay_ratio_mean']].round(3).to_string(index=False))


if __name__ == '__main__':
    main()
