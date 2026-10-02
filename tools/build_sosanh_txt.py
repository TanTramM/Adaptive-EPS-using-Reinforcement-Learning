"""Build Documents/Sim/SoSanh.txt from a template and the pair-comparison CSV files.

Usage:  python tools/build_sosanh_txt.py Documents/Sim/SoSanh_template.txt Documents/Sim/SoSanh.txt

The template is the chapter text in the Documents/ .txt convention (see tools/txt2docx.py). Lines starting with '@' are
replaced by a caption line plus the table rows read from Result/Compare/<A>_vs_<B>/<A>_vs_<B>_noise_study_summary.csv
(written by Model/Sim/script/make_pair_comparisons.m):
  @WHOLE A B | Bảng n: caption    metrics over the whole case, mean over the seeds, one row per test case
  @WINDOWS A B | Bảng n: caption  windows where the road is slippery: RMS e_T and signed mean e_T / mean |T_d,ref|
  @SENSORS | Bảng n: caption      sensor table from Model/data/sensors.json
  @STD A B | text with {x} {y}    one sentence with the largest relative std over the seeds ({x} RMS e_T [%], {y} TV [%])
Every table is followed by one blank line, as txt2docx.py expects.
"""
import json
import os
import sys

import pandas as pd

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES = [('TC1_dry_calibration', 'TC1'), ('TC2_road', 'TC2'), ('TC3_mu_drop_hard_corner', 'TC3'),
         ('TC4_wet_patch_lane_change', 'TC4'), ('TC5_sine_high_speed_low_mu', 'TC5'),
         ('TC6_mu_rise_mid_corner', 'TC6')]
WINDOWS = [('TC2_road', 'curve_0p25g_v80_mu_0p3', 'TC2', 'Cua 0.25 g, 80 km/h, $\\mu$ = 0.3'),
           ('TC2_road', 'curve_0p15g_v80_mu_0p3', 'TC2', 'Cua 0.15 g, 80 km/h, $\\mu$ = 0.3'),
           ('TC2_road', 'curve_0p2g_v100_mu_0p5', 'TC2', 'Cua 0.2 g, 100 km/h, $\\mu$ = 0.5'),
           ('TC3_mu_drop_hard_corner', 'after_mu_drop_steady', 'TC3', 'Sau khi $\\mu$ giảm (0.8 → 0.3), giữ góc'),
           ('TC4_wet_patch_lane_change', 'during_puddle', 'TC4', 'Trong vũng nước ($\\mu$ = 0.2)'),
           ('TC5_sine_high_speed_low_mu', 'sine_sustained', 'TC5', 'Lái hình sin duy trì, $\\mu$ = 0.2'),
           ('TC6_mu_rise_mid_corner', 'after_mu_rise_steady', 'TC6', 'Sau khi $\\mu$ tăng (0.3 → 0.8), giữ góc')]


def load(a, b):
    tag = '%s_vs_%s' % (a, b)
    return pd.read_csv(os.path.join(REPO, 'Result', 'Compare', tag, tag + '_noise_study_summary.csv'))


def fmt(x, kind='g'):
    if kind == 'tv':
        return '%.0f' % x if abs(x) >= 100 else '%.3g' % x
    if kind == 'pct':
        return '%+.2f' % x
    return '%.3g' % x


def row(G, ctrl, case, window, col):
    r = G[(G.Ctrl == ctrl) & (G.Case == case) & (G.Window == window)]
    assert len(r) == 1, (ctrl, case, window)
    return float(r.iloc[0][col])


def table_whole(a, b, caption):
    G = load(a, b)
    out = [caption, 'Ca | RMS $e_T$ %s [N.m] | RMS $e_T$ %s [N.m] | max $|e_T|$ %s [N.m] | max $|e_T|$ %s [N.m] | TV($T_a$) %s [N.m/s] | TV($T_a$) %s [N.m/s]'
           % (a, b, a, b, a, b)]
    for case, short in CASES:
        cells = [short]
        for col, kind in (('mean_RMS_eT_Nm', 'g'), ('mean_MaxAbs_eT_Nm', 'g'), ('mean_TV_Ta_Nm_per_s', 'tv')):
            cells += [fmt(row(G, a, case, 'whole case', col), kind), fmt(row(G, b, case, 'whole case', col), kind)]
        out.append(' | '.join(cells))
    return out


def table_windows(a, b, caption):
    G = load(a, b)
    out = [caption, 'Ca | Cửa sổ | RMS $e_T$ %s [N.m] | RMS $e_T$ %s [N.m] | $e_{rel}$ %s [%%] | $e_{rel}$ %s [%%]' % (a, b, a, b)]
    for case, win, short, label in WINDOWS:
        cells = [short, label]
        cells += [fmt(row(G, a, case, win, 'mean_RMS_eT_Nm')), fmt(row(G, b, case, win, 'mean_RMS_eT_Nm')),
                  fmt(row(G, a, case, win, 'mean_Mean_eT_signed_pct_of_Tdref'), 'pct'),
                  fmt(row(G, b, case, win, 'mean_Mean_eT_signed_pct_of_Tdref'), 'pct')]
        out.append(' | '.join(cells))
    return out


def table_sensors(caption):
    raw = json.load(open(os.path.join(REPO, 'Model', 'data', 'sensors.json'), encoding='utf-8'))
    names = {'T_s': '$T_s$ (mô-men thanh xoắn)', 'theta1': '$\\theta_1$ (góc vô-lăng)', 'theta2_dot': '$\\dot\\theta_2$ (tốc độ cột lái)',
             'v': '$v$ (vận tốc xe)', 'gamma': '$\\gamma$ (tốc độ quay thân xe)', 'a_y': '$a_y$ (gia tốc ngang)'}
    units = {'T_s': 'N.m', 'theta1': 'rad', 'theta2_dot': 'rad/s', 'v': 'm/s', 'gamma': 'rad/s', 'a_y': 'm/s$^2$'}
    src = {'T_s': '[7]', 'theta1': '[7], [8]', 'theta2_dot': '[8]', 'v': '[10]', 'gamma': '[9]', 'a_y': '[9]'}
    out = [caption, 'Tín hiệu | Độ phân giải (bước lượng tử) | Chu kỳ cập nhật [ms] | Độ lệch chuẩn nhiễu trắng | Nguồn']
    for k in ('T_s', 'theta1', 'theta2_dot', 'v', 'gamma', 'a_y'):
        s = raw['signals'][k]
        sigma = s.get('sigma_high', s['resolution'])
        out.append(' | '.join([names[k], '%.4g %s' % (s['resolution'], units[k]), '%g' % (s['update_period'] * 1000),
                               '%.4g %s' % (sigma, units[k]), src[k]]))
    return out


def sentence_std(a, b, text):
    G = load(a, b)
    W = G[G.Window == 'whole case']
    x = (W.std_RMS_eT_Nm / W.mean_RMS_eT_Nm).max() * 100
    y = (W.std_TV_Ta_Nm_per_s / W.mean_TV_Ta_Nm_per_s).max() * 100
    return text.format(x='%.1f' % x, y='%.1f' % y)


def main(tpl, dst):
    lines = open(os.path.join(REPO, tpl), encoding='utf-8').read().split('\n')
    out = []
    for ln in lines:
        if not ln.startswith('@'):
            out.append(ln)
            continue
        head, _, rest = ln.partition('|')
        parts = head[1:].split()
        kind = parts[0]
        if kind == 'WHOLE':
            out += table_whole(parts[1], parts[2], rest.strip())
        elif kind == 'WINDOWS':
            out += table_windows(parts[1], parts[2], rest.strip())
        elif kind == 'SENSORS':
            out += table_sensors(rest.strip())
        elif kind == 'STD':
            out.append(sentence_std(parts[1], parts[2], rest.strip()))
        else:
            raise ValueError(ln)
    open(os.path.join(REPO, dst), 'w', encoding='utf-8', newline='\n').write('\n'.join(out))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
