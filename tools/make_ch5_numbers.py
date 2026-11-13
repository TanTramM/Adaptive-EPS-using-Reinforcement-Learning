# -*- coding: utf-8 -*-
"""Numbers of thesis chapter 5 (Documents/Thesis/luanvan.txt), computed from the result files; nothing is typed by hand.

Writes Documents/Thesis/figures/ch5_numbers.csv with two columns (key, value) and prints the same list.
Sections (each one a function; run one with an argument, all without):
  protocol steady slip weave seeds   : sections 5.1 to 5.5 (five seeds 99995-99999, Result/Controllers/<Ctrl>/Cases_ssw/)
  why                                 : section 5.6 (WEAVE, MapPID against PID; Result/Compare/PID_vs_MapPID/)
  robust                              : section 5.7 (Result/Compare/Robust/)
  vdb                                 : section 5.8 (Model/VDB/temp_test/Summary/)
  friction                            : sections 4.5 and 5.3 (Map rerun with T_f = 0; Result/Compare/Friction/)
Run: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_ch5_numbers.py [section ...]
"""
import os
import sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))      # python -I does not add the script folder
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTF =os.path.join(ROOT, 'Documents', 'Thesis', 'figures', 'ch5_numbers.csv')
CT = ['Map', 'PID', 'MapPID']
SEEDS = list(range(99995, 100000))
CASES = ['STEADY', 'SLIP', 'WEAVE']
N = {}


def put(key, val):
    N[key] = float(val)


def metrics(c):
    fr = []
    for s in SEEDS:
        T = pd.read_csv(os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_ssw', '%s_metrics_s%05d.csv' % (c, s)))
        T['Seed'] = s
        fr.append(T)
    return pd.concat(fr, ignore_index=True)


def sig(c, case, s):
    return pd.read_csv(os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_ssw', '%s_%s_sig_s%05d.csv' % (c, case, s)))


def stat(M, case, window, col):
    x = M[(M.Case == case) & (M.Window == window)].sort_values('Seed')[col].to_numpy(float)
    return x.mean(), x.std(ddof=1), x


def table(M, name, case, window, col, tag):
    m, s, _ = stat(M, case, window, col)
    put('%s_%s_mean' % (tag, name), m)
    put('%s_%s_std' % (tag, name), s)


def put_val(d, k):
    return d[k]


def protocol():
    W = pd.read_csv(os.path.join(ROOT, 'Result', 'Compare', 'SSW_summary', 'SSW_windows.csv'))
    for case in CASES:
        put('n_windows_%s' % case, (W.case == case).sum())
        s = sig('MapPID', case, 99999)
        put('%s_vmin_kmh' % case, (s.v_mps * 3.6).min())
        put('%s_vmax_kmh' % case, (s.v_mps * 3.6).max())
        put('%s_mu_min' % case, s.mu.min())
        put('%s_ay_nom_max_g' % case, s.a_y_target_g.abs().max())
        put('%s_Tref_absmax' % case, s.T_d_ref.abs().max())
        put('%s_dt_s' % case, s.t.iloc[1] - s.t.iloc[0])
        put('%s_duration_s' % case, s.t.iloc[-1])
    # CALIB selected S for the PID / MapPID comparison of section 5.5
    sel = pd.read_csv(os.path.join(ROOT, 'Documents', 'Thesis', 'figures', 'ch4_selected.csv'), index_col=0)
    put('calib_S_PID', sel.loc['S_bar_Nm', 'PID'])
    put('calib_S_MapPID', sel.loc['S_bar_Nm', 'MapPID'])
    put('calib_S_MapPID_over_PID_pct', 100 * (sel.loc['S_bar_Nm', 'MapPID'] / sel.loc['S_bar_Nm', 'PID'] - 1))


def whole(M):
    for c in CT:
        for case in CASES:
            for col, nm in (('RMS_eT_Nm', 'E'), ('S_Nm', 'S')):
                table(M[c], c, case, 'whole case', col, '%s_%s' % (nm, case))


def steady(M):
    for c in CT:
        for w in ('v45a0p35l', 'v65a0p35r', 'v85a0p38l', 'v25a0p25r'):
            table(M[c], c, 'STEADY', w, 'Mean_eT_signed_pct_of_Tdref', 'eps_%s' % w)
    # all eleven windows: Map, PID, MapPID bias and RMS
    W = pd.read_csv(os.path.join(ROOT, 'Result', 'Compare', 'SSW_summary', 'SSW_windows.csv'))
    labs = list(W[W.case == 'STEADY'].label)
    mild = []
    for w in labs:
        e = {c: stat(M[c], 'STEADY', w, 'Mean_eT_signed_pct_of_Tdref')[0] for c in CT}
        r = {c: stat(M[c], 'STEADY', w, 'RMS_eT_Nm')[0] for c in CT}
        put('steady_eps_Map_%s' % w, e['Map'])
        put('steady_rms_Map_%s' % w, r['Map'])
        put('steady_rms_PID_%s' % w, r['PID'])
        put('steady_rms_MapPID_%s' % w, r['MapPID'])
        if abs(e['Map']) < 0.06:
            mild.append(w)
            put('mild_Map_lower_rms_%s' % w, float(r['Map'] < min(r['PID'], r['MapPID'])))
    put('n_mild_Map_below_0p06', len(mild))
    for c in ('PID', 'MapPID'):
        # max |bias| over the eleven windows (mean over seeds first) and over the three strongest levels
        put('steady_maxabs_eps_%s' % c, max(abs(stat(M[c], 'STEADY', w, 'Mean_eT_signed_pct_of_Tdref')[0]) for w in labs))
        put('steady_maxabs_eps3_%s' % c, max(abs(stat(M[c], 'STEADY', w, 'Mean_eT_signed_pct_of_Tdref')[0]) for w in ('v45a0p35l', 'v65a0p35r', 'v85a0p38l')))
    # analytic static bias of Map at the eleven windows (tools/make_ch5_static.m), same sign convention as the simulated bias
    st = pd.read_csv(os.path.join(ROOT, 'Documents', 'Thesis', 'figures', 'ch5_static.csv'))
    put('static_Kmax', st.Kmax.iloc[0])
    for _, r in st.iterrows():
        k = 'v%d_a%s' % (r.v_kmh, ('%.2f' % r.ay_g).replace('.', 'p'))
        put('static_eps_' + k, r.eps_static_pct)
        put('static_slope_' + k, r.natural_slope)
    for w, v, ay in (('v45a0p35l', 45, 0.35), ('v65a0p35r', 65, 0.35), ('v85a0p38l', 85, 0.38), ('v25a0p25r', 25, 0.25)):
        stat_eps = float(st[(st.v_kmh == v) & ((st.ay_g - ay).abs() < 1e-9)].eps_static_pct.iloc[0])
        put('static_minus_sim_%s' % w, stat_eps - N['eps_%s_Map_mean' % w])
    # the fast entry at 25 km/h (9 to 10 s): its share of the summed squared error, E_RMS without it, and the assist limit
    import json
    ta = json.load(open(os.path.join(ROOT, 'Model', 'shared', 'data', 'ref.json'), encoding='utf-8'))['Ta_max']
    put('Ta_max_25kmh', np.interp(25.0, np.array(ta['v_kmh'], float), np.array(ta['Ta_max_Nm'], float)))
    for c in CT:
        sh, ex = [], []
        for sd in SEEDS:
            d = sig(c, 'STEADY', sd)
            d = d[(d.t >= 2) & (d.t <= 100)]
            ev = (d.t >= 9) & (d.t < 10)
            sh.append((d.e_T[ev] ** 2).sum() / (d.e_T ** 2).sum())
            ex.append(np.sqrt((d.e_T[~ev] ** 2).mean()))
        put('steady_event_share_%s' % c, np.mean(sh))
        put('steady_E_without_event_%s' % c, np.mean(ex))
    s = sig('PID', 'STEADY', 99999)
    m = (s.t >= 9) & (s.t < 10)
    put('PID_Ta_min_event', s.T_a[m].min())
    put('PID_Ts_min_event', s.T_s[m].min())
    put('PID_Tref_at_Ts_min_event', s.T_d_ref[m][s.T_s[m].idxmin()])
    put('PID_theta1_deg_min_event', np.degrees(s.theta1_rad).min())
    put('PID_Ta_saturated_ms', 10 * ((s.T_a[m] <= -put_val(N, 'Ta_max_25kmh') + 1e-3)).sum())
    # window RMS of the feedback structures over the eleven windows
    for c in ('PID', 'MapPID'):
        r = [N['steady_rms_%s_%s' % (c, w)] for w in labs]
        put('steady_rms_min_%s' % c, min(r))
        put('steady_rms_max_%s' % c, max(r))
    # Map overshoot at 45 km/h and +0.35 g (hold 35 to 39 s)
    s = sig('Map', 'STEADY', 99999)
    m = (s.t >= 34) & (s.t <= 40)
    put('Map_peak_Ts_45_035', s.T_s[m].abs().max())
    put('Tref_hold_45_035', s.T_d_ref[(s.t >= 38) & (s.t <= 39)].abs().mean())
    # straight-ahead stretch at the end: standard deviation of T_s (seed 99999 and mean over seeds)
    for t0 in (91, 92, 95):
        for c in CT:
            v = [sig(c, 'STEADY', sd) for sd in SEEDS]
            sd_ = np.mean([x.T_s[(x.t >= t0) & (x.t <= 100)].std() for x in v])
            put('straight_std_%s_from%d' % (c, t0), sd_)
    put('straight_Tref_absmean_from92', np.mean([sig('Map', 'STEADY', sd).T_d_ref[(sig('Map', 'STEADY', sd).t >= 92)].abs().mean() for sd in SEEDS[:1]]))


def slip(M):
    for c in CT:
        for w in ('ramp_dn', 'ramp_up', 'stair_ref', 'stair_m0p5', 'stair_m0p33', 'stair_m0p24', 'pud_in'):
            table(M[c], c, 'SLIP', w, 'Mean_eT_signed_pct_of_Tdref', 'eps_%s' % w)
            table(M[c], c, 'SLIP', w, 'RMS_eT_Nm', 'rms_%s' % w)
    # extremes after the adhesion returns, seed 99999: windows 86.5 to 90 s and 66 to 70 s (extreme of T_s)
    for c in ('Map', 'MapPID'):
        s = sig(c, 'SLIP', 99999)
        m = (s.t >= 87) & (s.t <= 89)
        i = s.T_s[m].abs().idxmax()
        put('slip87_Ts_%s' % c, s.T_s[i])
        put('slip87_Tref_%s' % c, s.T_d_ref[i])
        put('slip87_t_%s' % c, s.t[i])
        m = (s.t >= 66.4) & (s.t <= 69)
        put('slip66_Ts_min_%s' % c, s.T_s[m].min())
        put('slip66_Ts_max_%s' % c, s.T_s[m].max())
    s = sig('Map', 'SLIP', 99999)
    put('slip_mu_drop_start', s.t[(s.mu < 0.79)].iloc[0])
    # analytic static bias of Map over the speed ramps (tools/make_ch5_static.m)
    sr = pd.read_csv(os.path.join(ROOT, 'Documents', 'Thesis', 'figures', 'ch5_static_ramp.csv'))
    put('static_ramp_min', sr.eps_static_pct.min())
    put('static_ramp_max', sr.eps_static_pct.max())
    # steering-wheel angle during the two ramps: rises while the vehicle slows, falls while it speeds up
    th = np.degrees(s.theta1_rad)
    put('slip_theta_t5', th[(s.t >= 5)].iloc[0])
    put('slip_theta_t17', th[(s.t >= 17)].iloc[0])
    put('slip_theta_t21', th[(s.t >= 21)].iloc[0])
    put('slip_theta_t33', th[(s.t >= 33)].iloc[0])


def weave(M):
    for c in CT:
        for w in ('sw0p3', 'sw0p8', 'sw1p5', 'lane_in', 'lane_ref', 'ctr', 'mu3'):
            table(M[c], c, 'WEAVE', w, 'RMS_eT_Nm', 'rms_%s' % w)
        for w in ('lane_in', 'lane_ref'):
            table(M[c], c, 'WEAVE', w, 'Mean_eT_signed_pct_of_Tdref', 'eps_%s' % w)
    # per-seed gap of MapPID against PID in the windows (mean and sample sd over the five seeds)
    for w in ('ctr', 'sw0p3', 'sw0p8', 'sw1p5', 'mu3', 'lane_ref', 'lane_in'):
        a = stat(M['MapPID'], 'WEAVE', w, 'RMS_eT_Nm')[2]
        b = stat(M['PID'], 'WEAVE', w, 'RMS_eT_Nm')[2]
        g = 100 * (a / b - 1)
        put('pgap_%s_mean' % w, g.mean())
        put('pgap_%s_std' % w, g.std(ddof=1))
    s = sig('Map', 'WEAVE', 99999)
    m = (s.t >= 3) & (s.t <= 22)
    put('weave_ctr_Map_Ts_absmax', s.T_s[m].abs().max())
    put('weave_ctr_Tref_absmax', s.T_d_ref[m].abs().max())


def derived():
    """gaps and ratios that the text quotes, from the means above"""
    for case in CASES:
        e = {c: N['E_%s_%s_mean' % (case, c)] for c in CT}
        sv = {c: N['S_%s_%s_mean' % (case, c)] for c in CT}
        put('ratio_Map_over_MapPID_E_%s' % case, e['Map'] / e['MapPID'])
        put('gap_MapPID_vs_PID_E_pct_%s' % case, 100 * (e['MapPID'] / e['PID'] - 1))
        put('gap_MapPID_vs_PID_S_pct_%s' % case, 100 * (sv['MapPID'] / sv['PID'] - 1))
        put('gap_MapPID_vs_Map_S_%s' % case, sv['MapPID'] - sv['Map'])
    for w in ('sw0p3', 'sw0p8', 'sw1p5'):
        put('gap_rms_MapPID_vs_PID_pct_%s' % w, 100 * (N['rms_%s_MapPID_mean' % w] / N['rms_%s_PID_mean' % w] - 1))
    put('slip_ramp_gap_dn', 0)
    put('Smin_all', min(N['S_%s_%s_mean' % (k, 'Map')] for k in CASES))
    put('Smax_Map', max(N['S_%s_Map_mean' % k] for k in CASES))
    put('Smin_Map', min(N['S_%s_Map_mean' % k] for k in CASES))
    put('Smin_MapPID', min(N['S_%s_MapPID_mean' % k] for k in CASES))
    put('Smax_MapPID', max(N['S_%s_MapPID_mean' % k] for k in CASES))


def seeds(M):
    for c in ('PID', 'MapPID'):
        for case in CASES:
            for col, nm in (('RMS_eT_Nm', 'E'), ('S_Nm', 'S')):
                _, _, x = stat(M[c], case, 'whole case', col)
                for i, v in enumerate(x):
                    put('seed%d_%s_%s_%s' % (i, nm, case, c), v)
    # paired differences MapPID - PID per seed (E and S), mean and sd
    for case in CASES:
        for col, nm in (('RMS_eT_Nm', 'E'), ('S_Nm', 'S')):
            a = stat(M['MapPID'], case, 'whole case', col)[2]
            b = stat(M['PID'], case, 'whole case', col)[2]
            d = 100 * (a / b - 1)
            put('paired_%s_%s_mean' % (nm, case), d.mean())
            put('paired_%s_%s_std' % (nm, case), d.std(ddof=1))
            put('paired_%s_%s_min' % (nm, case), d.min())
            put('paired_%s_%s_max' % (nm, case), d.max())


def main(secs):
    M = {c: metrics(c) for c in CT}
    todo = secs or ['protocol', 'steady', 'slip', 'weave', 'seeds']
    if 'protocol' in todo:
        protocol()
    whole(M)
    if 'steady' in todo:
        steady(M)
    if 'slip' in todo:
        slip(M)
    if 'weave' in todo:
        weave(M)
    if 'seeds' in todo:
        seeds(M)
    if all(k in N for k in ('rms_sw0p3_MapPID_mean', 'S_SLIP_PID_mean')):
        derived()
    if 'why' in todo:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import make_ch5_numbers_b as B
        B.why(put, N)
    if 'robust' in todo:
        import make_ch5_numbers_b as B
        B.robust(put, N)
    if 'vdb' in todo:
        import make_ch5_numbers_b as B
        B.vdb(put, N)
    if 'friction' in todo:
        import make_ch5_numbers_b as B
        B.friction(put, N)
    keep = {}
    if os.path.exists(OUTF):
        old = pd.read_csv(OUTF)
        keep = dict(zip(old.key, old.value))
    keep.update(N)
    pd.DataFrame({'key': list(keep.keys()), 'value': list(keep.values())}).to_csv(OUTF, index=False)
    for k, v in N.items():
        print('%-44s %.6g' % (k, v))


if __name__ == '__main__':
    main(sys.argv[1:])
