"""Flow chart of the CURRENT parameter-search method (Documents/Shared/PhuongPhap_TimThamSo.txt, sections 13-16): grid search, gates, Pareto selection,
then the common-seed Pareto comparison. Replaces the surrogateopt flow of Fig_search_flow (kept as a record of the old method).
One description gives Figures/new/Fig_search_flow_grid.drawio (editable source) and .png/.pdf (preview).

Usage: python tools/make_fig_search_flow_grid.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    d = Diagram(980, 1010, math=False, font='Times New Roman')
    bx, bw, bh, gap = 190, 600, 84, 38
    steps = [
        (['1. Biến thiết kế và hộp', 'Map 2 biến (K, g_min); PID 4 (Kp, Ki, Kd, Tf); MapPID: Map khóa, 4 biến PID'], '#ffffff'),
        (['2. Đánh giá MỘT thiết kế trên CALIB v2', 'sàng lọc tuyến tính (PM, GM, độ lợi lag) → mô phỏng 140 s → R, S, TV, e_rel'], '#ffffff'),
        (['3. QUÉT LƯỚI thô rồi mịn, seed tìm riêng của bộ', 'Map 00000, PID 10000, MapPID 30000; mỗi dòng ghi csv, chạy tiếp được'], '#f0f0f0'),
        (['4. CỔNG và CHỌN trên mặt Pareto (R, S)', 'PM ≥ 30°, GM ≥ 2, lag ≥ 0.707, e_rel ≤ 10 %, calib_margin; J = R·S'], '#ffffff'),
        (['5. TẬP DỰ TUYỂN CHUNG: mọi điểm qua cổng tuyến tính', 'Map 149, PID 168, MapPID 211 = 528 điểm (cùng một bộ lọc cho ba bộ)'], '#f0f0f0'),
        (['6. ĐÁNH GIÁ LẠI trên 5 seed chung 99990–99994', 'pha 1: mặt ở seed tìm; pha 2: điểm trong dải nhiễu 3σ (cùng luật cho ba bộ)'], '#f0f0f0'),
        (['7. MARGIN và HAI MẶT, so mặt Pareto theo R_tb, S_tb', 'calib_margin (seed 99990) cho điểm trên mặt; mặt an toàn, mặt đủ cổng'], '#f0f0f0'),
        (['8. KIỂM điểm đã chọn trên DREWS v2 (chỉ báo cáo, không chọn)', 'DRY, RAMP, SLIP, EDGE, WEAVE; năm seed 99995–99999'], '#ffffff'),
    ]
    y = 36
    centres = []
    for lines, fill in steps:
        d.block(bx, y, bw, bh, lines, fill=fill, fs=16, bold_first=True, rounded=False, lw=1.6)
        centres.append((bx + bw // 2, y, y + bh))
        y += bh + gap
    for (cx, _, y1), (_, y0, _) in zip(centres[:-1], centres[1:]):
        d.line([(cx, y1), (cx, y0)], arrow=True)
    # side notes: cost of each stage
    d.text(bx - 20, centres[2][1] + 42, 'Map 100–570 s,\nPID ≈ 10 s,\nMapPID ≈ 47 s\nmỗi lần', fs=14, ha='right')
    d.text(bx - 20, centres[5][1] + 42, '5 seed × điểm\ntrong tập', fs=14, ha='right')
    # loop 2 -> 3: the grid calls the evaluation of step 2 at every point
    xr = bx + bw + 40
    d.line([(bx + bw, centres[2][1] + 42), (xr, centres[2][1] + 42), (xr, centres[1][1] + 42), (bx + bw, centres[1][1] + 42)], arrow=True, dashed=True)
    d.text(xr + 10, (centres[1][1] + centres[2][1]) / 2 + 42, 'gọi\nbước 2', fs=14, ha='left')
    # the comparison reuses step 2 on other seeds
    d.line([(bx + bw, centres[5][1] + 42), (xr + 60, centres[5][1] + 42), (xr + 60, centres[1][1] + 62), (bx + bw, centres[1][1] + 62)], arrow=True, dashed=True)
    d.text(xr + 70, (centres[3][1] + centres[4][1]) / 2 + 42, 'gọi\nbước 2\nở seed\nchung', fs=14, ha='left')
    out = os.path.join(REPO, 'Figures', 'new')
    os.makedirs(out, exist_ok=True)
    d.save(os.path.join(out, 'Fig_search_flow_grid'))
    print('written', out)


if __name__ == '__main__':
    main()
