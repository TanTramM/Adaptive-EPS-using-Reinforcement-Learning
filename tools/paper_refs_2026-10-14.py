import re

p = 'Documents/Paper/paper.txt'
L = open(p, encoding='utf-8').read().split('\n')
iref = max(i for i, l in enumerate(L) if l == 'References')
head, tail = L[:iref + 2], L[iref + 2:]          # tail starts after the dashed separator line

# 1. renumber the citations in the body: [7]->[6], [8]->[7], [9]->[8]  ([6] and [10]-[15] are dropped, see the reference list)
mp = {'7': '6', '8': '7', '9': '8'}
body = '\n'.join(head)
body = re.sub(r'\[(7|8|9)\]', lambda m_: '[%s]' % mp[m_.group(1)], body)

# 2. cite the sensor sources where Table 4 is introduced
old = ('Sensor noise, quantization, and update periods are modeled according to Table 4. The noise standard deviation equals one resolution step '
       'for each sensor, except for vehicle speed, for which 0.38 km/h is adopted.')
new = ('Sensor noise, quantization, and update periods are modeled according to Table 4, with resolutions taken from the sensor data sheets [9]–[11]. '
       'The noise standard deviation equals one resolution step for each sensor, except for vehicle speed, for which 0.38 km/h is adopted [12].')
assert old in body
body = body.replace(old, new)

refs = [
    '[1] D. Lee, K.-S. Kim, and S. Kim, “Controller design of an electric power steering system,” *IEEE Transactions on Control Systems Technology*, vol. 26, no. 2, pp. 748–755, 2018. https://doi.org/10.1109/TCST.2017.2679062.',
    '[2] Y. Li, Z. Yang, D. Zhai, J. He, and J. Fan, “Study on control strategy of electric power steering for commercial vehicle based on multi-map,” *World Electric Vehicle Journal*, vol. 14, no. 2, article 33, 2023. https://doi.org/10.3390/wevj14020033.',
    '[3] Q. Li and C. Xia, “Research of electric power steering system assistance characteristic based on the identification of the road,” in *Proceedings of the 2nd International Conference on Computer and Information Application (ICCIA 2012)*, Atlantis Press, 2012, pp. 402–405. https://doi.org/10.2991/iccia.2012.97.',
    '[4] H. Q. Nguyen, V. T. Vu, and O. Sename, “Combining adaptive neural-fuzzy inference system with field-oriented control strategy for electric power steering system in cars,” *Advances in Mechanical Engineering*, vol. 17, no. 9, 2025. https://doi.org/10.1177/16878132251369152.',
    '[5] D. Saifia, M. Chadli, H. R. Karimi, and S. Labiod, “Fuzzy control for electric power steering system with assist motor current input constraints,” *Journal of the Franklin Institute*, vol. 352, no. 2, pp. 562–576, 2015. https://doi.org/10.1016/j.jfranklin.2014.05.007.',
    '[6] X. A. Ren and Z. X. Deng, “Research on ideal steering wheel effort characteristics of driver,” *China Mechanical Engineering*, vol. 25, no. 16, pp. 2261–2265, 2014.',
    '[7] H. B. Pacejka, *Tyre and Vehicle Dynamics*, 2nd ed. Elsevier, 2006.',
    '[8] R. Rajamani, *Vehicle Dynamics and Control*, 2nd ed. Springer, 2012.',
    '[9] Valeo, “Torque and/or angle sensors,” product catalogue. https://www.valeo.com/en/catalogue/cda/torque-and-or-angle-sensors/.',
    '[10] Bosch Motorsport, “Steering wheel angle sensor LWS,” data sheet, 27 January 2026. https://www.bosch-motorsport.com.',
    '[11] Bosch Motorsport, “Acceleration sensor MM5.10,” data sheet, 18 August 2020. https://www.bosch-motorsport.com.',
    '[12] H. Ragab, S. Givigi, and A. Noureldin, “Automotive speed estimation: Sensor types and error characteristics from OBD-II to ADAS,” *arXiv preprint*, arXiv:2501.00242, 2024.',
]
open(p, 'w', encoding='utf-8').write(body + '\n' + '\n'.join(refs) + '\n')
cites = sorted({int(n) for m_ in re.finditer(r'\[(\d+(?:[,–-]\s*\d+)*)\]', body.split('\nReferences')[0]) for n in re.findall(r'\d+', m_.group(1))})
print('cited in body:', cites)
print(len(re.findall(r'to be verified|to be sourced|to add', '\n'.join(refs) + body)), 'bracket notes left')
