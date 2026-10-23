"""Gop mọi file Cases_v2/<Ctrl>_metrics_s<seed>.csv của Map, PID, MapPID thành MỘT csv dạng dài để vẽ biểu đồ.

usage: C:/Users/Admin/anaconda3/python.exe -I tools/combine_drews_v2.py
writes Result/Compare/DREWS_v2_summary/DREWS_v2_all_runs.csv   (mỗi dòng = một bộ, một seed, một ca, một cửa sổ)
"""
import os
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEEDS = [99995, 99996, 99997, 99998, 99999]
frames = []
for c in ['Map', 'PID', 'MapPID']:
    for s in SEEDS:
        f = os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_v2', f'{c}_metrics_s{s}.csv')
        T = pd.read_csv(f)
        T.insert(0, 'Seed', s)
        T.insert(0, 'Ctrl', c)
        frames.append(T)
A = pd.concat(frames, ignore_index=True)
out = os.path.join(ROOT, 'Result', 'Compare', 'DREWS_v2_summary', 'DREWS_v2_all_runs.csv')
A.to_csv(out, index=False)
print(len(A), 'rows,', A['Ctrl'].nunique(), 'controllers ->', out)
print(A[A['Window'] == 'whole case'].groupby(['Ctrl', 'Case'])[['RMS_eT_Nm', 'S_Nm']].mean().round(4).to_string())
