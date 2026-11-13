# -*- coding: utf-8 -*-
"""Back matter of the thesis (Documents/Thesis/luanvan.txt): list of publications, appendices A-C and the curriculum vitae page.

The tables of the appendices are generated from the result files; nothing is typed by hand except the fixed sentences.
Writes Documents/Thesis/draft/back_parts/01_publications.txt and 02_appendix_cv.txt. The first part goes before the line 'TÀI LIỆU THAM KHẢO' of
luanvan.txt (tools/insert_thesis_part.py), the second is appended at the end of luanvan.txt.
Run: C:/Users/Admin/anaconda3/python.exe -I -X utf8 tools/make_thesis_back.py
"""
import os
import re
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'Documents', 'Thesis', 'draft', 'back_parts')
CT = ['Map', 'PID', 'MapPID']
SEEDS = list(range(99995, 100000))
MINUS = '\u2212'


def num(x, nd=4):
    return ('%.' + str(nd) + 'f') % x


def tnum(x):
    s = ('%.2f' % x).rstrip('0').rstrip('.')
    return s


# ---------------------------------------------------------------- list of publications
PUB = """DANH MỤC CÔNG TRÌNH CÔNG BỐ

1. Trần Minh Tân, Phùng Thanh Huy. Plug-in steering-torque feedback for column electric power steering with a calibrated assist map. Bản thảo bài báo tiếng Anh dự kiến đăng Tạp chí Khoa học và Công nghệ (JSTT), chưa công bố.
"""

# ---------------------------------------------------------------- appendix A: windows
def appendix_a():
    out = ['PHỤ LỤC A. CỬA SỔ CHẤM ĐIỂM', '', 'A.1. Các cửa sổ của CALIB', '']
    out.append('Ca CALIB (mục 4.2) có 68 cửa sổ chấm điểm. Bảng A.1 liệt kê thời điểm bắt đầu và kết thúc của từng cửa sổ trên trục thời gian của ca, theo thứ tự thời gian, cùng nhóm mà cửa sổ '
               'thuộc về khi tính $R$ (mục 4.2). Nhãn static_v<v>_a<a> là cửa sổ 1 s cuối của mức giữ cua có gia tốc ngang danh nghĩa <a> g ở <v> km/h, và trans_v<v>_a<a> là đoạn quá độ 2 s gồm '
               'đoạn tăng gia tốc ngang lên mức đó và 1 s đầu của mức. Nhãn sine_v<v>_f0p5 và sine_v<v>_f1 là các đoạn đánh lái hình sin qua không có chu kỳ 2 s và 1 s. mu_drop và mu_rise là hai giây '
               'sau mỗi bậc đổi hệ số bám.')
    out.append('')
    w = pd.read_csv(os.path.join(ROOT, 'Result', 'Compare', 'CALIB_profile', 'CALIB_windows.csv')).sort_values(['t0', 't1']).reset_index(drop=True)
    assert len(w) == 68
    grp = lambda lab: 'static' if lab.startswith('static') else ('mu' if lab.startswith('mu_') else 'dyn')
    out.append('@@W 36 9 9 11')
    out.append('Bảng A.1: Các cửa sổ chấm điểm của CALIB (68 cửa sổ, theo thứ tự thời gian).')
    out.append('Cửa sổ | Từ (s) | Đến (s) | Nhóm')
    for _, r in w.iterrows():
        out.append('%s | %s | %s | %s' % (r.label, tnum(r.t0), tnum(r.t1), grp(r.label)))
    out += ['', 'A.2. Các cửa sổ của STEADY, SLIP và WEAVE', '']
    out.append('Bảng A.2 liệt kê 31 cửa sổ chấm của ba chuỗi đánh giá (mục 5.1): 11 của STEADY, 12 của SLIP và 8 của WEAVE. Ở STEADY, nhãn v<v>a<a><l|r> là giây cuối của mức giữ cua ở <v> km/h, gia tốc '
               'ngang danh nghĩa <a> g, l là gia tốc ngang dương và r là âm. Với SLIP và WEAVE, cột cuối ghi nội dung của cửa sổ theo Bảng 5.1.')
    out.append('')
    s = pd.read_csv(os.path.join(ROOT, 'Result', 'Compare', 'SSW_summary', 'SSW_windows.csv'))
    assert len(s) == 31
    note = {
        'ramp_hi': 'ở 90 km/h, trước khi giảm tốc', 'ramp_dn': 'giảm tốc từ 90 xuống 45 km/h', 'ramp_lo': 'giữ ở 45 km/h', 'ramp_up': 'tăng tốc từ 45 lên 90 km/h',
        'stair_ref': 'μ = 0.8, trước thang hệ số bám (đối chứng)', 'stair_m0p5': '2 s cuối của bậc μ = 0.5', 'stair_m0p33': '2 s cuối của bậc μ = 0.33',
        'stair_m0p24': '2 s cuối của bậc μ = 0.24', 'stair_rec': '6 s sau khi μ trở về 0.8',
        'pud_ref': 'trước vũng nước (đối chứng)', 'pud_in': 'trong vũng nước, μ giảm xuống 0.2 trong 2 s', 'pud_rec': '3 s sau khi μ trở về 0.8',
        'ctr': 'đánh lái quanh tâm, 95 km/h, chu kỳ 5 s', 'lane_ref': 'chuyển làn thứ nhất, đường khô (đối chứng)',
        'lane_in': 'chuyển làn thứ hai, trong vũng μ = 0.2 dài 0.4 s', 'lane_rec': 'sau vũng nước của chuyển làn thứ hai',
        'sw0p3': 'đánh lái hình sin, 70 km/h, chu kỳ 3.3333 s', 'sw0p8': 'đánh lái hình sin, 70 km/h, chu kỳ 1.2500 s', 'sw1p5': 'đánh lái hình sin, 70 km/h, chu kỳ 0.6667 s',
        'mu3': 'đánh lái hình sin, 60 km/h, μ = 0.3, chu kỳ 1.3333 s'}
    out.append('@@W 12 14 9 9 38')
    out.append('Bảng A.2: Các cửa sổ chấm điểm của STEADY, SLIP và WEAVE.')
    out.append('Chuỗi | Cửa sổ | Từ (s) | Đến (s) | Nội dung')
    for _, r in s.iterrows():
        if r.case == 'STEADY':
            m = re.match(r'^v(\d+)a0p(\d+)([lr])$', r.label)
            sign = '+' if m.group(3) == 'l' else MINUS
            txt = 'giây cuối của mức giữ, %s km/h, %s0.%s g' % (m.group(1), sign, m.group(2))
        else:
            txt = note[r.label]
        out.append('%s | %s | %s | %s | %s' % (r.case, r.label, tnum(r.t0), tnum(r.t1), txt))
    return out


# ---------------------------------------------------------------- appendix B: extra results
def appendix_b():
    out = ['', 'PHỤ LỤC B. KẾT QUẢ BỔ SUNG', '', 'B.1. Kết quả theo từng seed', '']
    out.append('Bảng B.1 cho $E_{RMS}$ và $S$ toàn chuỗi (khoảng 2 đến 100 s) của từng seed trong năm seed 99995 đến 99999, là số liệu mà các bảng 5.2, 5.4 và 5.6 lấy trung bình và độ lệch chuẩn.')
    out.append('')
    out.append('@@W 11 9 10 10 10 10 10 10')
    out.append('Bảng B.1: $E_{RMS}$ và $S$ toàn chuỗi của từng seed, đơn vị N·m.')
    out.append('Chuỗi | Seed | $E_{RMS}$ Map | $S$ Map | $E_{RMS}$ PID | $S$ PID | $E_{RMS}$ MapPID | $S$ MapPID')
    for case in ('STEADY', 'SLIP', 'WEAVE'):
        for sd in SEEDS:
            cells = [case, str(sd)]
            for c in CT:
                M = pd.read_csv(os.path.join(ROOT, 'Result', 'Controllers', c, 'Cases_ssw', '%s_metrics_s%05d.csv' % (c, sd)))
                r = M[(M.Case == case) & (M.Window == 'whole case')].iloc[0]
                cells += [num(r.RMS_eT_Nm), num(r.S_Nm)]
            out.append(' | '.join(cells))
    out += ['', 'B.2. Sai số bám của các biến thể tham số xe ở seed 99999', '']
    out.append('Các bảng B.2 đến B.4 cho $E_{RMS}$ của ba bộ trong 17 biến thể của mục 5.7 (một nhóm tham số lệch −20 % hoặc +20 %), ở seed 99999, cho STEADY, SLIP và WEAVE; đây là số liệu của Hình 5.8. '
               'Cột cuối là thứ tự từ nhỏ đến lớn theo $E_{RMS}$, không áp ngưỡng ngang nhau.')
    out.append('')
    R = pd.read_csv(os.path.join(ROOT, 'Result', 'Compare', 'Robust', 'Robust_summary_s99999.csv'))
    names = {'Tf': '$T_f$', 'Jcol': '$J_{col}$', 'Ccol': '$C_{col}$', 'Mass': '$m$, $I_z$', 'Calpha': '$C_\\alpha$', 'Trail': '$t_0$', 'Caster': '$e_c$', 'Motor': '$f_m$'}
    order = ['nom'] + [k + s for k in names for s in ('m20', 'p20')]
    assert set(order) == set(R.Variant)
    def label(v):
        if v == 'nom':
            return 'Danh định'
        return '%s %s20 %%' % (names[v[:-3]], MINUS if v.endswith('m20') else '+')
    for k, case in enumerate(('STEADY', 'SLIP', 'WEAVE')):
        out.append('@@W 22 11 11 12 34')
        out.append('Bảng B.%d: $E_{RMS}$ (N·m) của ba bộ ở %s trong 17 biến thể, seed 99999.' % (k + 2, case))
        out.append('Biến thể | Map | PID | MapPID | Thứ tự')
        for v in order:
            vals = {c: float(R[(R.Variant == v) & (R.Ctrl == c) & (R.Case == case)].E_RMS_Nm.iloc[0]) for c in CT}
            rank = ' < '.join(c for c in sorted(CT, key=lambda c: vals[c]))
            out.append('%s | %s | %s | %s | %s' % (label(v), num(vals['Map']), num(vals['PID']), num(vals['MapPID']), rank))
        out.append('')
    return out


# ---------------------------------------------------------------- appendix C: reproduction, and the curriculum vitae page
APP_C = """PHỤ LỤC C. TÁI LẬP KẾT QUẢ

C.1. Cấu trúc mã nguồn

Mã nguồn và kết quả của luận văn nằm trong cùng một kho mã với luận văn. Thư mục Model chứa mô hình MATLAB và Simulink. Model/shared có setup_paths.m, nơi duy nhất khai báo các thư mục mã, các hàm dùng chung, các file dữ liệu .json (tham số xe, bảng mô-men mục tiêu, cảm biến, motor và tham số của từng bộ điều khiển) và khung thử Sim, gồm các hàm dựng vòng kín, sinh ca, chạy ca và chấm điểm. Model/original chứa đối tượng, gồm các khối Plant (cột lái, lốp và thân xe), Ref (mô-men mục tiêu và giới hạn trợ lực), Sensors, AssistLimit và Actuator, cùng ba bộ điều khiển Map, PID và MapPID. Model/VDB chứa các khối VDB có cùng cổng với khối gốc và các biến thể đối tượng của mục 5.8. Thư mục Result chứa kết quả các lần chạy, theo bố cục Result/Controllers/<bộ điều khiển>/ cho từng bộ và Result/Compare/ cho các so sánh. Thư mục tools chứa các script Python và MATLAB tạo số liệu và hình của luận văn, và Documents/Thesis chứa luanvan.txt, nguồn duy nhất của luận văn, cùng các hình.

C.2. Cách chạy lại

Phần mềm dùng là MATLAB R2023a với Simulink và Vehicle Dynamics Blockset R2023a, và Python 3 với các thư viện pandas và numpy cho các bảng. Đầu mỗi phiên MATLAB chạy Model/shared/setup_paths.m. Với mỗi bộ điều khiển, load_map, load_pid hoặc load_mappid nạp tham số vào không gian làm việc, build_closed_loop sinh mô hình vòng kín Model_<bộ điều khiển>, calib_run chạy ca CALIB và chấm R, S và sai số xác lập, và run_cases(ctrl, seed, 'SSW', thư mục) chạy ba chuỗi STEADY, SLIP và WEAVE. Seed 99990 đến 99994 dùng để chọn tham số và seed 99995 đến 99999 dùng để chấm. Các phép thử của mục 5.7 và 5.8 chạy bằng run_robust_cases và các script trong Model/VDB. Các số trong chương 5 sinh bằng tools/make_ch5_numbers.py từ các file csv trong Result, và hình sinh bằng các script make_fig_thesis_ch<n>.m trong tools.

C.3. Tham số đã chọn

Tham số đã chọn của ba bộ điều khiển nằm trong trường design của map.json, pid.json và mappid.json ở Model/shared/data, và được liệt kê ở Bảng 4.4.

LÝ LỊCH TRÍCH NGANG

Họ và tên: Trần Minh Tân

Ngày sinh: [điền]

Nơi sinh: [điền]

Địa chỉ liên lạc: [điền]

Quá trình đào tạo: [điền]

Quá trình công tác: [điền]
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, '01_publications.txt'), 'w', encoding='utf-8', newline='').write(PUB.strip('\n') + '\n')
    parts = appendix_a() + appendix_b()
    txt = '\n'.join(parts).rstrip('\n') + '\n\n' + APP_C
    open(os.path.join(OUT, '02_appendix_cv.txt'), 'w', encoding='utf-8', newline='').write(txt)
    print('written; appendix lines:', txt.count('\n'))


if __name__ == '__main__':
    main()
