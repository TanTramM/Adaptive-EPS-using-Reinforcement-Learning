"""Tạo PNG mẫu MapPID; không ghi hoặc sửa bất kỳ tệp Draw.io nào."""
import os
from drawio_kit import Diagram


def main():
    d = Diagram(3000, 1140, font='Times New Roman')
    b = dict(rounded=False, fs=27, lw=1.6)
    def label(x, y, s):
        d.text(x, y, s, fs=29)

    # Tuyến vận tốc đo dùng chung.
    d.block(130, 30, 240, 100, ['Speed sensor', r'$v_m=H_v(v)$'], **b)
    d.line([(20, 80), (130, 80)], arrow=True)
    label(55, 52, r'$v$')
    d.line([(370, 80), (1960, 80), (1960, 545)], arrow=True)
    label(420, 52, r'$v_m$')
    for x, target in [(300, 545), (880, 190)]:
        # Nhánh reference cần tách sau speed sensor.
        sx = 430 if x == 300 else x
        d.dot(sx, 80)
        d.line([(sx, 80), (sx, 160), (x, 160), (x, target)], arrow=True)

    # Nhánh Map được cộng vào tổng lệnh sau PID.
    d.block(740, 190, 280, 110,
            ['Assist map', r'$M(v_m,T_{s,m})$'], **b)
    d.block(1160, 190, 280, 110,
            ['Lead-lag', r'$C_{map}(s)$'], **b)
    d.line([(1020, 245), (1160, 245)], arrow=True)
    label(1090, 212, r'$T_{map}$')
    d.line([(1440, 245), (1650, 245), (1650, 575)], arrow=True)
    label(1540, 212, r'$u_{map}$')

    # Sai số của P/I có chiều tác động đúng với mô-men trợ lực.
    d.block(160, 545, 280, 110,
            ['Reference', r'$T_{ref}(v_m,a_{y,m})$'], **b)
    d.sumj(530, 600, r=24, signs={'left': '-', 'bottom': '+'}, fs=26)
    d.line([(440, 600), (506, 600)], arrow=True)
    label(475, 562, r'$T_{ref}$')
    d.line([(554, 600), (740, 600)], arrow=True)
    label(630, 565, r'$e_T$')
    d.dot(680, 600)
    d.line([(680, 600), (680, 435), (740, 435)], arrow=True)

    d.block(740, 385, 420, 100,
            ['Proportional (P)', r'$K_p e_T$'], **b)
    d.block(740, 540, 470, 120,
            ['Integral (I)',
             r'$\int_0^t[K_i e_T(\tau)+K_{aw}\Delta T_a(\tau)]\,d\tau$'], **b)
    d.block(740, 810, 420, 110,
            ['Derivative (D)', r'$\frac{K_d s}{T_f s+1}T_{s,m}$'], **b)
    d.sumj(1380, 600, r=24,
           signs={'top': '+', 'left': '+', 'bottom': '+'}, fs=26)
    d.line([(1160, 435), (1380, 435), (1380, 576)], arrow=True)
    d.line([(1210, 600), (1356, 600)], arrow=True)
    d.line([(1160, 865), (1380, 865), (1380, 624)], arrow=True)
    d.line([(1404, 600), (1626, 600)], arrow=True)
    label(1500, 565, r'$u_{PID}$')
    d.sumj(1650, 600, r=24, signs={'left': '+', 'top': '+'}, fs=26)
    d.line([(1674, 600), (1820, 600)], arrow=True)
    label(1740, 562, r'$T_{a,cmd}$')

    # Giới hạn chung cho tổng Map + PID, rồi tới motor và Plant.
    d.block(1820, 545, 280, 110,
            ['Assist limit', r'$L(T_{a,cmd},v_m)$'], **b)
    d.block(2220, 545, 180, 110, ['Motor', r'$G_a(s)$'], **b)
    d.line([(2100, 600), (2220, 600)], arrow=True)
    label(2160, 562, r'$T_{a,lim}$')
    d.line([(2400, 600), (2510, 600)], arrow=True)
    label(2450, 562, r'$T_a$')
    d.block(2510, 500, 360, 200,
            ['Nonlinear C-EPS plant',
             r'$x=[\theta_2,\dot{\theta}_2,\beta,\gamma]^T$',
             r'$\dot{x}=f(x,T_a,\theta_1,v,\mu)$',
             r'$[T_s,a_y]^T=h(x,T_a,\theta_1,v,\mu)$'], **b)
    d.line([(2690, 370), (2690, 500)], arrow=True)
    label(2790, 390, r'$[\theta_1,v,\mu]^T$')
    d.line([(2870, 600), (2970, 600)], arrow=True)
    label(2920, 560, r'$T_s,a_y$')

    # Hiệu anti-windup lấy từ lệnh tổng, trước động học motor.
    d.sumj(1740, 745, r=23, signs={'top': '-', 'right': '+'}, fs=26)
    d.dot(1740, 600)
    d.line([(1740, 600), (1740, 722)], arrow=True, dashed=True)
    d.dot(2160, 600)
    d.line([(2160, 600), (2160, 745), (1763, 745)], arrow=True, dashed=True)
    d.line([(1717, 745), (975, 745), (975, 660)], arrow=True, dashed=True)
    label(1510, 712, r'$\Delta T_a$')

    # Hai kênh đo có ngõ vào từ Plant, vận tốc đo ở nhánh riêng phía trên.
    d.block(2210, 970, 390, 125,
            ['Measurement models', r'$T_{s,m}=H_T(T_s)$',
             r'$a_{y,m}=H_{a_y}(a_y)$'], **b)
    d.dot(2920, 600)
    d.line([(2920, 600), (2920, 1030), (2600, 1030)], arrow=True)
    d.line([(2210, 1010), (530, 1010), (530, 624)], arrow=True)
    label(2110, 975, r'$T_{s,m}$')
    d.dot(530, 865)
    d.line([(530, 865), (740, 865)], arrow=True)
    d.dot(530, 950)
    d.line([(530, 950), (600, 950), (600, 330), (880, 330), (880, 300)], arrow=True)
    d.line([(2210, 1060), (300, 1060), (300, 655)], arrow=True)
    label(2110, 1095, r'$a_{y,m}$')

    base = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                        'Figures', 'new', 'Fig_MapPID_preview')
    d.save_preview(base, scale=1.5, pdf=False)
    print(base + '.png')


if __name__ == '__main__':
    main()
