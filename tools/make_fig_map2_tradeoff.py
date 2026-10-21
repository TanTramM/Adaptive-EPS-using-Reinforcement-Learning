"""Map (K, g_min) grid on CALIB v2: accuracy against robustness (PhuongPhap_TimThamSo 14.9, step 2 of the Map report).
Top: worst steady-state error e_rel against K. Bottom: calib_margin gain ratio R(gain x2)/R against K. One dot per simulated pair of the grid (seed 0).
Reads Result/Controllers/Map/Calib_v2/Grid2/Map_CALIB_grid2_w*_s00000.csv, writes Map_CALIB_grid2_tradeoff_s00000.png in the same folder."""
import glob
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
grid = os.path.join(root, "Result", "Controllers", "Map", "Calib_v2", "Grid2")
P = pd.concat([pd.read_csv(f) for f in sorted(glob.glob(os.path.join(grid, "Map_CALIB_grid2_w*_s00000.csv")))])
P = P.drop_duplicates(["K", "g_min"])
S = P[(P.simulated == 1) & P.ratio_gain.notna()]
ok = S.ratio_gain <= 2

fig, ax = plt.subplots(2, 1, figsize=(7.2, 6.4), sharex=True, constrained_layout=True)
for a, col, lab in ((ax[0], "erel_pct", "worst $e_{rel}$ over 26 static windows (%)"), (ax[1], "ratio_gain", "$R_{gain\\times 2}/R$")):
    a.scatter(S.K[ok], S[col][ok], s=22, c="#2a7ab0", label="passes calib_margin")
    a.scatter(S.K[~ok], S[col][~ok], s=22, c="#c9482b", label="fails calib_margin (ratio > 2)")
    a.set_ylabel(lab)
    a.set_xscale("log")
    a.grid(True, alpha=0.3)
ax[0].set_yscale("log")
ax[0].axhline(10, color="k", lw=1, ls="--")
ax[0].text(S.K.min(), 10.6, "$e_{max}$ = 10 %", fontsize=9)
ax[1].axhline(2, color="k", lw=1, ls="--")
ax[1].text(S.K.min(), 2.07, "limit 2", fontsize=9)
ax[1].set_xlabel("K (N.m per N.m)")
ax[0].legend(loc="upper right", fontsize=9)
fig.suptitle("Map: accuracy against robustness, CALIB v2 seed 0", fontsize=11)
out = os.path.join(grid, "Map_CALIB_grid2_tradeoff_s00000.png")
fig.savefig(out, dpi=150)
print(out, len(S), "pairs")
