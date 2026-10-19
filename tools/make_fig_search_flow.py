"""Flow chart of the parameter-search method (Documents/Shared/PhuongPhap_TimThamSo.txt): steps 1-6 from the design variables to the scoring on five seeds.
One description gives Figures/new/Fig_search_flow.drawio (editable source) and .png/.pdf (preview).

Usage: python tools/make_fig_search_flow.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_kit import Diagram

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    d = Diagram(900, 820, math=False, font='Times New Roman')
    bx, bw, bh, gap = 150, 600, 80, 46
    steps = [
        (['1. Biến thiết kế và hộp tìm kiếm', 'x = (Kp, Ki, Kd, Tf) ↔ u, n biến, mỗi biến trong [0,1] (thang log)'], '#ffffff'),
        (['2. Đánh giá MỘT thiết kế x trên CALIB v2 (seed s)', 'sàng lọc tuyến tính → mô phỏng 140 s → R, S, J = R·S, e_rel'], '#ffffff'),
        (['3. TÌM toàn cục: surrogateopt, 3 chuỗi độc lập × 250 lần', 'seed tìm x0000; ràng buộc: PM, GM, dải lái, e_rel'], '#f0f0f0'),
        (['4. NHÓM TOP: 20 thiết kế khả thi, khác nhau, J nhỏ nhất', 'gộp mọi lần đánh giá của ba chuỗi'], '#ffffff'),
        (['5. CHỌN trên 5 seed x0001–x0005', 'J_tb = trung bình J, σ_J; cổng e_rel ở MỌI seed; hòa → PM lớn hơn'], '#f0f0f0'),
        (['6. KIỂM và CHẤM', 'calib_margin; chấm DREWS trên 5 seed 99999–99995; so theo cặp'], '#ffffff'),
    ]
    y = 40
    centres = []
    for lines, fill in steps:
        d.block(bx, y, bw, bh, lines, fill=fill, fs=17, bold_first=True, rounded=False, lw=1.6)
        centres.append((bx + bw // 2, y, y + bh))
        y += bh + gap
    for (cx, _, y1), (_, y0, _) in zip(centres[:-1], centres[1:]):
        d.line([(cx, y1), (cx, y0)], arrow=True)
    # side notes (what is kept at each stage)
    d.text(bx - 20, centres[2][1] + 40, 'ngân sách\nkhoảng 750 lần', fs=15, ha='right')
    d.text(bx - 20, centres[4][1] + 40, '20 × 5 = 100 lần', fs=15, ha='right')
    # loop 1 -> 2 -> 3: the optimiser calls the evaluation of step 2 at every iteration
    xr = bx + bw + 40
    d.line([(bx + bw, centres[2][1] + 40), (xr, centres[2][1] + 40), (xr, centres[1][1] + 40), (bx + bw, centres[1][1] + 40)], arrow=True, dashed=True)
    d.text(xr + 10, (centres[1][1] + centres[2][1]) / 2 + 40, 'gọi\nbước 2', fs=15, ha='left')
    out = os.path.join(REPO, 'Figures', 'new')
    os.makedirs(out, exist_ok=True)
    d.save(os.path.join(out, 'Fig_search_flow'))
    print('written', out)


if __name__ == '__main__':
    main()
