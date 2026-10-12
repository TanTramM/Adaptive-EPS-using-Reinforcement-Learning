# -*- coding: utf-8 -*-
"""Build the two outline documents (thesis, paper) from the results already in Result/ and Model/data/.

Usage: python tools/build_outline_docx.py
Writes Documents/Thesis/dan_y_luan_van.docx and Documents/Thesis/dan_y_bai_bao.docx.
All numbers are read from csv/json files, not typed by hand.
"""
import csv
import json
import os
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Cm, Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'Documents', 'Thesis')
CASES = ['TC1_dry_calibration', 'TC2_road', 'TC3_mu_drop_hard_corner', 'TC4_wet_patch_lane_change',
         'TC5_sine_high_speed_low_mu', 'TC6_mu_rise_mid_corner']


def path(*p):
    return os.path.join(ROOT, *p)


def read_csv(*p):
    with open(path(*p), encoding='utf-8') as f:
        return list(csv.DictReader(f))


def summary(pair):
    """{(ctrl, case, window): row} from the compare summary of a pair."""
    rows = read_csv('Result', 'Compare', pair, pair + '_noise_study_summary.csv')
    return {(r['Ctrl'], r['Case'], r['Window']): r for r in rows}


def num(x, nd=3):
    try:
        v = float(x)
    except (TypeError, ValueError):
        return '-'
    if v != v:
        return '-'
    return ('%.' + str(nd) + 'g') % v if abs(v) < 10 else '%.0f' % v if abs(v) >= 100 else '%.1f' % v


class Doc:
    def __init__(self, title, subtitle):
        self.d = Document()
        st = self.d.styles['Normal']
        st.font.name = 'Times New Roman'
        st.font.size = Pt(12)
        for s in self.d.sections:
            s.left_margin = s.right_margin = Cm(2.5)
        self.d.add_heading(title, 0)
        p = self.d.add_paragraph(subtitle)
        p.runs[0].italic = True
        self.nfig = 0
        self.ntab = 0

    def h1(self, t):
        self.d.add_heading(t, 1)

    def h2(self, t):
        self.d.add_heading(t, 2)

    def p(self, t):
        self.d.add_paragraph(t)

    def b(self, t, level=0):
        para = self.d.add_paragraph(t, style='List Bullet' if level == 0 else 'List Bullet 2')
        return para

    def todo(self, t):
        para = self.d.add_paragraph()
        r = para.add_run('[Chưa có] ' + t)
        r.italic = True

    def fig(self, caption, rel, width=14):
        full = path(*rel.split('/'))
        self.nfig += 1
        if os.path.exists(full):
            self.d.add_picture(full, width=Cm(width))
            self.d.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
        else:
            self.d.add_paragraph('[khung hình trống: không thấy ' + rel + ']')
        c = self.d.add_paragraph('Hình %d: %s' % (self.nfig, caption))
        c.alignment = WD_ALIGN_PARAGRAPH.CENTER
        c.runs[0].italic = True

    def table(self, caption, header, rows):
        self.ntab += 1
        c = self.d.add_paragraph('Bảng %d: %s' % (self.ntab, caption))
        c.runs[0].italic = True
        t = self.d.add_table(rows=1, cols=len(header))
        t.style = 'Table Grid'
        for i, h in enumerate(header):
            t.rows[0].cells[i].text = h
            t.rows[0].cells[i].paragraphs[0].runs[0].bold = True
        for r in rows:
            cells = t.add_row().cells
            for i, v in enumerate(r):
                cells[i].text = str(v)
        for row in t.rows:
            for cell in row.cells:
                for para in cell.paragraphs:
                    for run in para.runs:
                        run.font.size = Pt(10)
        self.d.add_paragraph()

    def save(self, name):
        f = os.path.join(OUT, name)
        self.d.save(f)
        print('saved', f)


def compare_table(doc, ctrls, pairs, metric, caption, nd=3):
    """Table of a whole-case metric: rows = TC cases, columns = controllers (from the pair summaries)."""
    data = {}
    for pair in pairs:
        s = summary(pair)
        for (c, case, w), r in s.items():
            if w == 'whole case':
                data[(c, case)] = r[metric]
    rows = [[case.split('_')[0]] + [num(data.get((c, case)), nd) for c in ctrls] for case in CASES]
    doc.table(caption, ['Ca'] + ctrls, rows)


def overassist_table(doc, ctrls_pairs, case, caption, only=None):
    """Mean signed e_T as a percentage of T_d,ref per window of one test case (negative = too much assist)."""
    cols = []
    for pair, ctrl in ctrls_pairs:
        s = summary(pair)
        cols.append((ctrl, {w: r['mean_Mean_eT_signed_pct_of_Tdref'] for (c, cs, w), r in s.items() if c == ctrl and cs == case}))
    wins = [w for w in cols[0][1] if w != 'whole case' and (only is None or w in only)]
    doc.table(caption, ['Cửa sổ'] + [c for c, _ in cols], [[w] + [num(d.get(w), 3) for _, d in cols] for w in wins])


# ---------------------------------------------------------------------------------------------------------------------------------

def thesis():
    M = json.load(open(path('Model', 'data', 'map.json'), encoding='utf-8'))['design']
    PI = json.load(open(path('Model', 'data', 'pi.json'), encoding='utf-8'))['design']
    res = read_csv('Result', 'Controllers', 'PI', 'Design', 'PI_plant_resonance.csv')
    ref = read_csv('Result', 'PRSM', 'Reference', 'Reference_Ta_max_by_speed_mu0p8.csv')

    D = Doc('Dàn ý luận văn: Adaptive C-EPS', 'Dàn ý, chưa lý luận sâu. Chỗ đã có kết quả thì điền số và hình; chỗ chưa có ghi "[Chưa có]". '
            'Số liệu đọc từ Result/ và Model/data/ ngày 2026-10-10. Nhiễu cảm biến, seed chung 99999.')
    D.h1('Khung luận văn: 7 chương')

    D.h2('Chương 1. Tổng quan')
    D.b('Trợ lực lái điện cột lái (C-EPS), hiện tượng trợ lực thừa khi hệ số bám mu đổi; bản đồ trợ lực vòng hở là thực hành hiện tại.')
    D.b('Tài liệu: Lee 2018, Multi-Map EPS (Li 2023), Saifia 2015, các tài liệu trong References.txt; khoảng trống; mục tiêu; phạm vi.')
    D.todo('Chưa viết. Cần chốt với GVHD: tên đề tài khi RL được thay bằng SMC và ISMC.')

    D.h2('Chương 2. Mô hình môi trường PRSM (Plant, Ref, Sensors, Actuator)')
    D.b('Đã xong, mọi test đạt: Plant (cột lái, lốp Pacejka, 2-DOF), Ref (giá trị đặt T_d,ref), Sensors (nhiễu, lượng tử), AssistLimit và Actuator (giới hạn T_a,max, trễ motor 100 Hz).')
    D.b('Giới hạn trợ lực T_a,max = T_a,req + F, với F = T_f = 2.0 N.m (dự phòng cho ma sát Coulomb).')
    pick = {r['v_kmh']: r for r in ref} if ref and 'v_kmh' in ref[0] else {}
    if pick:
        rows = []
        for v in ('20', '30', '60', '100'):
            if v in pick:
                rows.append([v] + [num(pick[v][k], 4) for k in ('Ta_req_Nm', 'F_Nm', 'Ta_max_Nm')])
        D.table('Giới hạn T_a,max theo vận tốc (mu 0.8)', ['v (km/h)', 'T_a,req (N.m)', 'F (N.m)', 'T_a,max (N.m)'], rows)
    D.fig('Mô-men T_r và hệ số bám mu', 'Result/PRSM/Plant/sweep_Tr_vs_mu.png', 12)
    D.fig('Bảng giá trị đặt T_d,ref theo a_y và vận tốc', 'Result/PRSM/Reference/Reference_Tdref_table4_vs_ay_by_speed.png', 12)
    D.todo('Sơ đồ khối vòng kín Plant, Sensors, bộ điều khiển, Actuator (Figures/, vẽ tay).')

    D.h2('Chương 3. Khung đánh giá')
    D.b('Ca thiết kế CALIB (đường khô mu 0.8, khối 20/60/100 km/h; cửa sổ static 0.1-0.3 g vào R và cổng e_rel, cửa sổ ext 0.4 g chỉ báo cáo); chỉ tiêu R (độ bám), S (độ ồn T_a sau lọc cao qua 5 Hz), TV, e_rel, trợ lực ngược.')
    D.b('Năm ca chấm DREWS: DRY, RAMP, SLIP, EDGE, WEAVE (QuyChuan 3.2). Seed local mỗi bộ; seed chung 99999 khi so sánh.')
    D.b('Quy chuẩn phiên bản 5 (đặt trước khi chạy): cổng ổn định có độ dư đo bằng mô phỏng, rồi e_rel <= 5 %; bang-bang và trợ lực ngược chỉ báo cáo. Chọn điểm: J = R x S nhỏ nhất kèm ràng buộc dải lái (khâu lọc hoặc làm chậm giữ độ lợi >= 0.707 tại 2 Hz). So cả mặt Pareto.')
    D.b('Đã có: QuyChuan.txt phiên bản 5, cases.txt.')

    D.h2('Chương 4. Map (bộ đối chứng)')
    D.b('Cấu trúc: bản đồ T_a = sgn(T_s) M(v, |T_s|), vùng chết 0.3 N.m, giới hạn độ dốc K_max, rồi khâu bù lead-lag (một lead nhân một lag, độ lợi một chiều bằng 1).')
    D.b('Hiệu chỉnh trên đường khô (mu 0.8): 979 điểm, T_s + T_a = T_r khớp tính độc lập đến 1e-14 N.m; mọi điểm nằm dưới T_a,max.')
    D.fig('Hiệu chỉnh: T_a theo T_s', 'Result/Controllers/Map/Design/Map_calibration_Ta_vs_Ts.png', 13)
    D.b('Khâu bù: lead z = %s, p = %s rad/s; lag z1 = %s, p1 = %s rad/s (độ lợi của lag tại 2 Hz = %s, ràng buộc dải lái >= 0.707); dự trữ pha tuyến tính %s độ (chỉ báo cáo).'
        % (num(M['lead']['z'], 4), num(M['lead']['p'], 5), num(M['lag']['z1'], 4), num(M['lag']['p1'], 4), num(M['lag_gain_2Hz'], 3), num(M['PM_deg'], 3)))
    D.fig('Đáp ứng tần số của khâu bù lead-lag', 'Result/Controllers/Map/Design/Map_bode.png', 13)
    D.b('Chọn điểm: g_min = %s, K_max = %s, theo J = R x S nhỏ nhất trong các điểm qua cổng ổn định có độ dư, e_rel <= 5 %% và ràng buộc dải lái (73 cặp (g_min, K) mô phỏng, 36 cặp qua cổng).' % (M['g_min'], M['Kmax']))
    D.fig('J nhỏ nhất theo mức g_min: J giảm khi lag sâu hơn, ràng buộc dải lái chặn', 'Result/Controllers/Map/Calib/Map_CALIB_pick_s00000.png', 13)
    D.fig('Mặt (R, S) của các cặp (g_min, K)', 'Result/Controllers/Map/Calib/Map_CALIB_pareto_s00000.png', 13)
    D.table('Điểm chọn của Map trên ca CALIB (seed local 00000)', ['Chỉ tiêu', 'Giá trị'],
            [['K_max', M['Kmax']], ['g_min', M['g_min']], ['R (%)', num(M['CALIB_R_pct'], 4)], ['S (N.m)', num(M['CALIB_S_Nm'], 3)], ['J = R x S', num(M['CALIB_J'], 4)], ['TV (N.m/s)', num(M['CALIB_TV_Nm_per_s'], 4)],
             ['e_rel (%)', num(M['CALIB_erel_pct'], 3)], ['Trợ lực ngược (%)', num(M['CALIB_rev_pct'], 3)]])
    D.p('Lưu ý trung thực: ràng buộc dải lái được thêm SAU khi thấy J suy biến trên Map (lần thứ tư đổi quy tắc sau khi thấy kết quả); không có ràng buộc J chọn g_min 0.25, K 5.8 (R 37.7 %). '
        'Cửa sổ static của CALIB chỉ ở 20, 60, 100 km/h nên cổng e_rel không thấy sai số ở 40 km/h: ca DRY cho +13.0 % tại cửa sổ v40a0p3r.')

    D.h2('Chương 5. Bộ tuyến tính PI, PID')
    r0 = res[0]
    D.b('Nhận dạng đối tượng tuyến tính quanh giữ góc: cộng hưởng cột lái, tần số tự nhiên %s rad/s (%s Hz), tắt dần zeta = %s, đỉnh %s dB (đường khô).'
        % (num(r0['omega_n_rad_s'], 3), num(float(r0['omega_n_rad_s']) / 6.283185, 3), num(r0['zeta_column'], 3), num(r0['peak_dB'], 3)))
    D.fig('Nhận dạng đối tượng (đáp ứng tần số)', 'Result/Controllers/PI/Design/PI_plant_bode.png', 12)
    D.fig('Biên ổn định của PI (Kp, Ki)', 'Result/Controllers/PI/Design/PI_stability_boundary.png', 12)
    D.fig('Mặt Pareto sơ bộ của PI (quét thô 103 điểm)', 'Result/Controllers/PI/Sweep/PI_pareto_coarse.png', 12)
    D.table('Điểm chọn của PI trên ca TK (seed local 10000)', ['Chỉ tiêu', 'Giá trị'],
            [['Kp', PI['Kp']], ['Ki (1/s)', PI['Ki']], ['R (%)', num(PI['CALIB_R_pct'], 4)], ['S (N.m)', num(PI['CALIB_S_Nm'], 3)],
             ['TV (N.m/s)', num(PI['CALIB_TV_Nm_per_s'], 4)], ['e_rel (%)', num(PI['CALIB_erel_pct'], 3)], ['Trợ lực ngược (%)', num(PI['CALIB_rev_pct'], 3)]])
    D.p('Lưu ý: lưới mịn chưa đủ độ phân giải (fine_grid_resolution_sufficient = false); e_rel 3.25 % hơi vượt ngưỡng 3 %, chọn theo quy tắc điểm vi phạm ít nhất.')
    D.todo('PID: chưa có kết quả theo quy chuẩn mới (khung Linear đang làm).')

    D.h2('Chương 6. Bộ đề xuất: SMC và ISMC (thay RL)')
    D.b('SMC (lớp biên, không tích phân): s = dT_s/dt + lambda e_T, T_a = T_a,max sat(s/Phi), lambda 30, Phi 2, Tf 5 ms.')
    D.b('ISMC (có tích phân): lambda 20, Phi 2, Tf 5 ms. Thêm tích phân làm e_rel giảm từ 10.5 % xuống 1.95 % (số của khung SMC).')
    D.b('Bản đầu: bám tốt hơn Map nhưng T_a ồn quá cao (RMS T_a khoảng 7 N.m, gần T_a,max; TV khoảng 1800-2100 N.m/s), cần chỉnh.')
    D.todo('Quét lưới và chọn lại theo quy chuẩn, kiểm cổng không bang-bang (khung SMC).')

    D.h2('Chương 7. So sánh và kết luận')
    D.b('Map với PI, PID, SMC, ISMC trên năm ca DREWS, seed chung 99999.')
    D.todo('So sánh seed 99999 chưa chạy lại sau khi Map đổi sang lead-lag (v5): các bảng và hình Result/Compare/Map_vs_* cũ thuộc Map lead đơn cũ nên không đưa vào; chạy lại khi PI, PID, SMC chốt điểm chọn.')
    D.b('Hạn chế: mô phỏng thuần, nhiễu cảm biến tự chọn, chưa có bản PID và bản SMC chọn theo quy chuẩn.')
    D.b('Phụ lục: kết quả âm (PI hai bậc, Map hai bậc), chi tiết quét lưới.')
    D.save('dan_y_luan_van.docx')


def paper():
    M = json.load(open(path('Model', 'data', 'map.json'), encoding='utf-8'))['design']
    PI = json.load(open(path('Model', 'data', 'pi.json'), encoding='utf-8'))['design']
    res = read_csv('Result', 'Controllers', 'PI', 'Design', 'PI_plant_resonance.csv')
    r0 = res[0]

    D = Doc('Dàn ý bài báo: Map với PI, PID', 'Dàn ý, chưa lý luận sâu. Bài so sánh công bằng giữa bản đồ trợ lực Map và bộ hồi tiếp tuyến tính '
            '(PI, PID) trên cùng mô hình và cùng nhiễu cảm biến. SMC để dành cho luận văn.')
    D.h2('Đóng góp chính')
    D.b('Quy chuẩn đặt cổng trước khi chạy, có cổng chống rung (không bang-bang).')
    D.b('So cả mặt Pareto (đường đánh đổi giữa bám và êm), không chỉ một điểm.')
    D.b('Phân tích cộng hưởng cột lái khoảng 6.2 Hz giới hạn PI.')

    D.h1('I. Giới thiệu')
    D.b('Trợ lực thừa khi mu đổi; bản đồ trợ lực là thực hành chuẩn; thiếu so sánh công bằng với hồi tiếp dưới nhiễu cảm biến; ba đóng góp.')
    D.h1('II. Mô hình và giá trị đặt')
    D.b('PRSM tóm tắt: cột lái, lốp, 2-DOF, Actuator có T_a,max(v) và trễ 100 Hz, cảm biến có nhiễu và lượng tử; giá trị đặt T_d,ref(v, a_y).')
    D.fig('Bảng giá trị đặt T_d,ref', 'Result/PRSM/Reference/Reference_Tdref_table4_vs_ay_by_speed.png', 12)
    D.todo('Sơ đồ khối vòng kín (vẽ tay).')
    D.h1('III. Quy chuẩn đánh giá')
    D.b('Ca CALIB và năm ca DREWS; chỉ tiêu R, S, TV, e_rel, trợ lực thừa; cổng đặt trước (ổn định có độ dư đo bằng mô phỏng, e_rel <= 5 %); quy tắc chọn J = R x S kèm ràng buộc dải lái (độ lợi >= 0.707 tại 2 Hz); seed local và seed chung 99999.')
    D.h1('IV. Các bộ điều khiển')
    D.b('Map: bản đồ M(v, |T_s|) + lead (z = %s, p = %s rad/s) nhân lag (z1 = %s, p1 = %s rad/s), K_max = %s, hai tham số chỉnh bằng mô phỏng (K và g_min).'
        % (num(M['lead']['z'], 4), num(M['lead']['p'], 5), num(M['lag']['z1'], 4), num(M['lag']['p1'], 4), M['Kmax']))
    D.b('PI: Kp = %s, Ki = %s 1/s (hai tham số chỉnh).' % (PI['Kp'], PI['Ki']))
    D.todo('PID (Kp, Ki, Kd, Tf): chờ khung Linear.')
    D.h1('V. Kết quả')
    D.b('Phân tích cộng hưởng: tần số tự nhiên %s rad/s (%s Hz), zeta %s; giới hạn băng thông PI.'
        % (num(r0['omega_n_rad_s'], 3), num(float(r0['omega_n_rad_s']) / 6.283185, 3), num(r0['zeta_column'], 3)))
    D.fig('Biên ổn định của PI', 'Result/Controllers/PI/Design/PI_stability_boundary.png', 12)
    D.fig('Mặt Pareto sơ bộ của PI', 'Result/Controllers/PI/Sweep/PI_pareto_coarse.png', 12)
    D.fig('Mặt (R, S) của Map (73 cặp g_min, K)', 'Result/Controllers/Map/Calib/Map_CALIB_pareto_s00000.png', 12)
    D.todo('Pareto chung Map, PI, PID cùng trục và so sánh seed 99999: chưa chạy lại sau khi Map đổi sang lead-lag; số liệu Result/Compare/Map_vs_* cũ không dùng.')
    D.h1('VI. Thảo luận và hạn chế')
    D.b('Giới hạn Actuator ở TC1 (đỉnh |e_T| là do T_a chạm T_a,max, không phải lỗi bộ điều khiển); mô phỏng thuần; nhiễu tự chọn; chưa có động học vòng dòng motor.')
    D.h1('VII. Kết luận')
    D.todo('Viết sau khi có PID và Pareto chung.')
    D.save('dan_y_bai_bao.docx')


if __name__ == '__main__':
    thesis()
    paper()
