# -*- coding: utf-8 -*-
"""Numbers of thesis sections 5.6 to 5.8 (called by make_ch5_numbers.py with the sections 'why', 'robust', 'vdb').
Each function takes put(key, value) and the dictionary N of the numbers collected so far."""
import os
import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PVM = os.path.join(ROOT, 'Result', 'Compare', 'PID_vs_MapPID')
WIN = ['ctr', 'lane1', 'lane2', 'sw0p3', 'sw0p8', 'sw1p5', 'mu3']


def why(put, N):
    # W0: five seeds, per window (Result/Compare/PID_vs_MapPID/PID_vs_MapPID_WEAVE_windows_5seeds.csv)
    a = pd.read_csv(os.path.join(PVM, 'PID_vs_MapPID_WEAVE_windows_5seeds.csv')).set_index('window')
    for w in WIN + ['whole']:
        r = a.loc[w]
        put('w0_gap_%s_mean' % w, r.gap_RMS_pct_mean)
        put('w0_gap_%s_std' % w, r.gap_RMS_pct_std)
        put('w0_rmsPID_%s' % w, r.RMS_eT_PID_mean)
        put('w0_rmsMapPID_%s' % w, r.RMS_eT_MapPID_mean)
        if w != 'whole':
            put('w0_period_%s' % w, r.P_s)
            put('w0_damp_%s_mean' % w, r.dAmp_pct_mean)
            put('w0_damp_%s_std' % w, r.dAmp_pct_std)
            put('w0_ddelay_%s_mean' % w, r.dDelay_ms_mean)
            put('w0_ddelay_%s_std' % w, r.dDelay_ms_std)
            put('w0_ampPID_%s' % w, r.amp_PID_mean)
            put('w0_ampMapPID_%s' % w, r.amp_MapPID_mean)
    # W2: branch magnitudes, seed 99999 (PID_vs_MapPID_WEAVE_branch_windows_s99999.csv) and around the zero crossings of T_ref
    b = pd.read_csv(os.path.join(PVM, 'PID_vs_MapPID_WEAVE_branch_windows_s99999.csv')).set_index('window')
    for w in WIN:
        r = b.loc[w]
        for k, col in (('umap', 'RMS_umap'), ('uP', 'RMS_uP'), ('uI', 'RMS_uI'), ('uD', 'RMS_uD'), ('uPID', 'RMS_uPID'), ('fdz', 'frac_dz_meas'),
                       ('opp', 'opp_frac'), ('ampTref', 'Amp_Tdref')):
            put('w2_%s_%s' % (k, w), r[col])
    x = pd.read_csv(os.path.join(PVM, 'PID_vs_MapPID_WEAVE_branch_crossings_mean_s99999.csv')).set_index('window')
    for w in WIN:
        put('w2x_rmsPID_%s' % w, x.loc[w].RMS_eT_PID)
        put('w2x_rmsMapPID_%s' % w, x.loc[w].RMS_eT_MapPID)
        put('w2x_ncross_%s' % w, x.loc[w].n_cross)
        put('w2x_opprms_%s' % w, x.loc[w].opp_RMS)
        put('w2x_dzrun_%s' % w, x.loc[w].dz_run_ms)
    # the zoom of Figure 5.7: window 59 to 61 s (three cycles of the 0.667 s period), seed 99999, 1 ms data
    P = pd.read_csv(os.path.join(ROOT, 'Result', 'Controllers', 'PID', 'Cases_ssw_1ms', 'PID_WEAVE_sig1ms_s99999.csv'))
    B = pd.read_csv(os.path.join(ROOT, 'Result', 'Controllers', 'MapPID', 'Cases_ssw_branch', 'MapPID_WEAVE_branch_s99999.csv'))
    mp = (P.t >= 59) & (P.t <= 61)
    mb = (B.t >= 59) & (B.t <= 61)
    put('w2z_maxabs_eT_PID', P.e_T[mp].abs().max())
    put('w2z_maxabs_eT_MapPID', B.e_T[mb].abs().max())
    put('w2z_rms_umap', np.sqrt((B.u_map[mb] ** 2).mean()))
    put('w2z_rms_uPID', np.sqrt(((B.u_P + B.u_I + B.u_D)[mb] ** 2).mean()))
    put('w2z_rms_Ta_diff', np.sqrt(((P.T_a[mp].to_numpy() - B.T_a[mb].to_numpy()) ** 2).mean()))
    put('w2z_rms_Ta_PID', np.sqrt((P.T_a[mp] ** 2).mean()))
    # W3: diagnostics, seed 99999
    c = pd.read_csv(os.path.join(PVM, 'PID_vs_MapPID_WEAVE_diag_s99999.csv')).set_index('window')
    for w in ['whole'] + WIN:
        r = c.loc[w]
        for v in ('PID', 'MapPID', 'D1', 'D2', 'D3'):
            put('w3_rms_%s_%s' % (v, w), r['RMS_eT_' + v])
        put('w3_gap_%s' % w, r.gap_MapPID_vs_PID_pct)
        for v in ('D1', 'D2', 'D3'):
            put('w3_change_%s_%s' % (v, w), r['change_%s_vs_MapPID_pct' % v])
            put('w3_closed_%s_%s' % (v, w), r['gap_closed_%s_pct' % v])
    # five-seed whole-sequence gap, also from the metrics (cross-check of section 5.4)
    put('w0_check_gap_whole', N.get('paired_E_WEAVE_mean', np.nan))
    # PID branch parameters of the two controllers (Table 4.4)
    sel = pd.read_csv(os.path.join(ROOT, 'Documents', 'Thesis', 'figures', 'ch4_selected.csv'), index_col=0)
    for k in ('Kp', 'Ti_ms', 'Td_ms', 'Kd_s', 'tauf_ms', 'Ki_per_s'):
        put('pid_%s_PID' % k, sel.loc[k, 'PID'])
        put('pid_%s_MapPID' % k, sel.loc[k, 'MapPID'])
    put('map_tau2_out_ms', sel.loc['tau2_out_ms', 'MapPID'])
    put('map_tau2_in_ms', sel.loc['tau2_in_ms', 'MapPID'])
    put('map_Ts0', sel.loc['Ts0_Nm', 'MapPID'])
    put('map_Kmax', sel.loc['Kmax', 'MapPID'])


def robust(put, N):
    """Section 5.7: parameter deviations of +-20 % (Result/Compare/Robust/). Seed 99999 for all 17 variants, five seeds for the nominal and eight variants."""
    RB = os.path.join(ROOT, 'Result', 'Compare', 'Robust')
    R = pd.read_csv(os.path.join(RB, 'Robust_summary_s99999.csv'))
    S5 = pd.read_csv(os.path.join(RB, 'Robust_seeds_summary.csv'))
    groups = ['Tf', 'Jcol', 'Ccol', 'Mass', 'Calpha', 'Trail', 'Caster', 'Motor']
    put('rb_n_variants', R.Variant.nunique())
    put('rb_n_runs', len(R))
    put('rb_n_5seed_variants', S5.Variant.nunique())
    for c in ('Map', 'PID', 'MapPID'):
        for case in ('STEADY', 'SLIP', 'WEAVE'):
            d = R[(R.Ctrl == c) & (R.Case == case)]
            v = d[d.Variant != 'nom']
            i = v.dE_pct.abs().idxmax()
            put('rb_maxabs_dE_%s_%s' % (case, c), abs(v.dE_pct.loc[i]))
            put('rb_maxabs_dS_%s_%s' % (case, c), v.dS_pct.abs().max())
            put('rb_nom_E_%s_%s' % (case, c), d[d.Variant == 'nom'].E_RMS_Nm.iloc[0])
            for g in groups:
                for sgn, tag in (('p20', 'p'), ('m20', 'm')):
                    put('rb_dE_%s_%s_%s%s' % (case, c, g, tag), d[d.Variant == g + sgn].dE_pct.iloc[0])
            if case == 'STEADY':
                put('rb_meaneps_min_%s' % c, d.MeanEps_pct.min())
                put('rb_meaneps_max_%s' % c, d.MeanEps_pct.max())
                put('rb_maxabseps_STEADY_%s' % c, d.MaxAbsEps_pct.max())
                put('rb_maxabseps_STEADY_nom_%s' % c, d[d.Variant == 'nom'].MaxAbsEps_pct.iloc[0])
            if case == 'SLIP':
                put('rb_maxabseps_SLIP_min_%s' % c, d.MaxAbsEps_pct.min())
                put('rb_maxabseps_SLIP_max_%s' % c, d.MaxAbsEps_pct.max())
    for g in groups:
        put('rb_group_maxabs_%s' % g, R[R.Variant.isin([g + 'p20', g + 'm20'])].dE_pct.abs().max())
    for c in ('Map', 'PID', 'MapPID'):
        for case in ('STEADY', 'SLIP', 'WEAVE'):
            d = R[(R.Ctrl == c) & (R.Case == case)]
            nom = d[d.Variant == 'nom'].E_RMS_Nm.iloc[0]
            put('rb_maxabs_dEabs_%s_%s' % (case, c), (d[d.Variant != 'nom'].E_RMS_Nm - nom).abs().max())
    # time at the assist limit (Sat_pct of the whole-case row) for PID and MapPID, seed 99999
    for c in ('PID', 'MapPID'):
        for v in ('nom', 'Massp20', 'Massm20', 'Casterp20', 'Trailp20'):
            d = pd.read_csv(os.path.join(RB, v, '%s_metrics_s99999.csv' % c))
            for case in ('STEADY', 'SLIP'):
                put('rb_sat_%s_%s_%s' % (c, v, case), d[(d.Window == 'whole case') & (d.Case == case)].Sat_pct.iloc[0])
    # how often the gap between MapPID and PID exceeds 5 % at five seeds (SLIP and WEAVE), and Map last everywhere?
    P = S5.pivot_table(index=['Variant', 'Case'], columns='Ctrl', values='E_mean')
    last = 0
    for (var, case), r in P.iterrows():
        last += int(r['Map'] > max(r['PID'], r['MapPID']) * 1.05)
    put('rb5_map_clearly_worse_count', last)
    put('rb5_conditions', len(P))
    for case in ('STEADY', 'SLIP', 'WEAVE'):
        q = P.xs(case, level='Case')
        put('rb5_Map_over_best_min_%s' % case, (q['Map'] / q[['PID', 'MapPID']].min(axis=1)).min())
        gap = 100 * (q['MapPID'] / q['PID'] - 1)
        put('rb5_gap_MapPID_vs_PID_min_%s' % case, gap.min())
        put('rb5_gap_MapPID_vs_PID_max_%s' % case, gap.max())
        put('rb5_gap_nom_%s' % case, gap.loc['nom'])


def vdb(put, N):
    """Section 5.8: Plant blocks replaced by Vehicle Dynamics Blockset blocks (Model/VDB/temp_test/Summary/VDB_body_summary_s99999.csv, seed 99999)."""
    import re
    S = pd.read_csv(os.path.join(ROOT, 'Model', 'VDB', 'temp_test', 'Summary', 'VDB_body_summary_s99999.csv'))
    variants = ['VDBBody', 'VDBTireBody', 'VDBTireLag', 'VDBTireLagBody']
    for v in variants:
        d = S[S.variant == v]
        put('vdb_dE_min_%s' % v, d.dRMS_eT_pct.min())
        put('vdb_dE_max_%s' % v, d.dRMS_eT_pct.max())
        put('vdb_dE_maxabs_%s' % v, d.dRMS_eT_pct.abs().max())
        put('vdb_dS_maxabs_%s' % v, d.dS_pct.abs().max())
        for case in ('STEADY', 'SLIP', 'WEAVE'):
            for c in ('Map', 'PID', 'MapPID'):
                r = d[(d.case == case) & (d.controller == c)].iloc[0]
                put('vdb_dE_%s_%s_%s' % (v, case, c), r.dRMS_eT_pct)
                put('vdb_dS_%s_%s_%s' % (v, case, c), r.dS_pct)
    lag = S[S.variant.isin(['VDBTireLag', 'VDBTireLagBody'])]
    put('vdb_lag_dE_min', lag.dRMS_eT_pct.min())
    put('vdb_lag_dE_max', lag.dRMS_eT_pct.max())
    put('vdb_lag_dS_maxabs', lag.dS_pct.abs().max())
    put('vdb_all_dS_maxabs', S.dS_pct.abs().max())
    nolag = S[S.variant.isin(['VDBBody', 'VDBTireBody'])]
    put('vdb_nolag_dE_maxabs', nolag.dRMS_eT_pct.abs().max())
    put('vdb_nolag_dS_maxabs', nolag.dS_pct.abs().max())
    # gap of MapPID against PID in SLIP: baseline and the variants with the lag (tie order flips, both inside 5 %)
    for v in ['Plant'] + variants:
        d = S[(S.variant == v) & (S.case == 'SLIP')].set_index('controller').RMS_eT_Nm
        put('vdb_slipgap_%s' % v, 100 * (d['MapPID'] / d['PID'] - 1))
    # relaxation length of the block and the lag time constant tau = sigma / v (read from the comment of build_plant_variants.m)
    txt = open(os.path.join(ROOT, 'Model', 'VDB', 'Plants', 'script', 'build_plant_variants.m'), encoding='utf-8').read()
    m = re.search(r'measured ([0-9.]+) m, tau = ', txt)
    sigma = float(m.group(1))
    put('vdb_sigma_m', sigma)
    for kmh in (25, 60, 100):
        put('vdb_tau_ms_%d' % kmh, 1000 * sigma / (kmh / 3.6))
    m2 = re.search(r'FyRelFreqLwrLim = 200\*pi rad/s \(100 Hz\), which\s*%\s*holds the lag at ([0-9.]+) ms', txt)
    put('vdb_lag_default_ms', float(m2.group(1)))
    # SLIP: extremes of T_s when the adhesion returns (87 s and 66.5 s), Plant against the tire with lag (seed 99999, 10 ms files)
    for c in ('Map', 'PID', 'MapPID'):
        for tag, path in (('Plant', os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_ssw', '%s_SLIP_sig_s99999.csv' % c)),
                          ('Lag', os.path.join(ROOT, 'Model', 'VDB', 'temp_test', c, 'Result', '%s_VDBTireLag_SLIP_sig_s99999.csv' % c))):
            d = pd.read_csv(path)
            put('vdb_slip87_peak_%s_%s' % (c, tag), d.T_s[(d.t >= 86.9) & (d.t <= 88.5)].max())
            put('vdb_slip66_min_%s_%s' % (c, tag), d.T_s[(d.t >= 66.4) & (d.t <= 69)].min())
    # open-loop comparison of the blocks with the same assumptions as the Plant (DRY, no assist torque)
    vd = os.path.join(ROOT, 'Result', 'PRSM', 'Plant_VDB', 'Variants')
    for name in ('Plant_VDBBody', 'Plant_VDBTire', 'Plant_VDBTireBody', 'Plant_VDBTireLagBody'):
        line = open(os.path.join(vd, name + '_compare.txt'), encoding='utf-8').read().splitlines()[0]
        put('vdb_ol_Ts_%s' % name, float(re.search(r'T_s ([0-9.]+) %', line).group(1)))
        put('vdb_ol_ay_%s' % name, float(re.search(r'a_y ([0-9.]+) %', line).group(1)))


def friction(put, N):
    """Section 5.3 and 4.5: Map rerun with T_f = 0 (Result/Compare/Friction/, plan Documents/Shared/KeHoach_MaSatCotLai.txt)."""
    fd = os.path.join(ROOT, 'Result', 'Compare', 'Friction')
    w = pd.read_csv(os.path.join(fd, 'Friction_SSW_windows.csv'))
    w = w[pd.to_numeric(w.Seed, errors='coerce').notna()]                      # drop the mean and sd rows
    for win in ('ramp_dn', 'ramp_up'):
        r = w[(w.Ctrl == 'Map') & (w.Case == 'SLIP') & (w.Window == win)]
        put('fr_%s_nom_mean' % win, r.eps_nom_pct.mean())
        put('fr_%s_nom_std' % win, r.eps_nom_pct.std(ddof=1))
        put('fr_%s_tf0_mean' % win, r.eps_Tf0_pct.mean())
        put('fr_%s_tf0_std' % win, r.eps_Tf0_pct.std(ddof=1))
        put('fr_%s_static' % win, r.eps_static_pct.mean())
        put('fr_%s_gap' % win, abs(r.eps_Tf0_pct.mean() - r.eps_static_pct.mean()))
    s = pd.read_csv(os.path.join(fd, 'Map_CALIB_erel_friction_summary.csv'))
    s = s[pd.to_numeric(s.Seed, errors='coerce').notna()]                      # drop the mean and max rows
    put('fr_calib_nom_mean', s.erelMax_nom.mean())
    put('fr_calib_nom_max', s.erelMax_nom.max())
    put('fr_calib_tf0_mean', s.erelMax_Tf0.mean())
    put('fr_calib_tf0_max', s.erelMax_Tf0.max())
    put('fr_calib_nwin_nom', (s.window_nom == 'static_v30_apos0p30g').sum())
    put('fr_calib_nwin_tf0', (s.window_Tf0 == 'static_v30_apos0p30g').sum())
    c3 = pd.read_csv(os.path.join(ROOT, 'Documents', 'Thesis', 'figures', 'ch3_numbers.csv'))
    put('fr_calib_static_max', dict(zip(c3.iloc[:, 0], c3.iloc[:, 1]))['static_erel_max_analytic_pct'])
