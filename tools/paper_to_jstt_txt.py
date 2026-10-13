"""Make the journal version of the paper text (Documents/Paper/paper_jstt.txt) from the advisor-structure text (Documents/Paper/paper.txt).

The advisor's wording is kept; only what the JSTT Guide for Authors asks for is changed or added:
  - 'EPS controller performance' in the Abstract -> 'C-EPS controller performance' (EPS is not defined in the Abstract)
  - the early pointer to a table that is cited later (tables must be numbered in the order of citation) -> pointer to Section 4.1
  - a vertical fraction inside running text -> solidus
  - 'Acknowledgements' -> 'Acknowledgments' (American spelling)
  - the caption wording 'based on the original dynamic-result set' dropped
  - citations written as in the journal: [3,6] and [9-11]
  - sections added: Author contributions, Declaration of Generative AI
  - reference list in the journal style  [n]. Authors. (Year). Title. Journal, vol(issue), pages.
  - version 1: the sentence about a single noise realization is removed from the limitations (--v1)

Usage: python tools/paper_to_jstt_txt.py Documents/Paper/paper.txt Documents/Paper/paper_jstt.txt [--v1]
"""
import re
import sys

AUTHOR_CONTRIB = ('Tran Minh Tan: modeling, simulation, data analysis, writing – original draft. Phung Thanh Huy: supervision, review and editing. '
                  'All authors have approved the final article.')
AI_DECL = ('During the preparation of this work, the author(s) used Claude (Anthropic) in order to assist with simulation code, figure generation, '
           'data checking, and language editing. After using this tool, the author(s) reviewed and edited the content as needed and take full '
           'responsibility for the content of the published article.')
REFS = [
    '[1]. D. Lee, K.-S. Kim and S. Kim. (2018). Controller design of an electric power steering system. IEEE Transactions on Control Systems Technology, 26(2), 748–755. https://doi.org/10.1109/TCST.2017.2679062',
    '[2]. Y. Li, Z. Yang, D. Zhai, J. He and J. Fan. (2023). Study on control strategy of electric power steering for commercial vehicle based on multi-map. World Electric Vehicle Journal, 14(2), 33. https://doi.org/10.3390/wevj14020033',
    '[3]. Q. Li and C. Xia. (2012). Research of electric power steering system assistance characteristic based on the identification of the road. In Proceedings of the 2nd International Conference on Computer and Information Application (ICCIA 2012), Atlantis Press, pp 402-405. https://doi.org/10.2991/iccia.2012.97',
    '[4]. H.Q. Nguyen, V.T. Vu and O. Sename. (2025). Combining adaptive neural-fuzzy inference system with field-oriented control strategy for electric power steering system in cars. Advances in Mechanical Engineering, 17(9). https://doi.org/10.1177/16878132251369152',
    '[5]. D. Saifia, M. Chadli, H.R. Karimi and S. Labiod. (2015). Fuzzy control for electric power steering system with assist motor current input constraints. Journal of the Franklin Institute, 352(2), 562-576. https://doi.org/10.1016/j.jfranklin.2014.05.007',
    '[6]. X.A. Ren and Z.X. Deng. (2014). Research on ideal steering wheel effort characteristics of driver. China Mechanical Engineering, 25(16), 2261-2265.',
    '[7]. H.B. Pacejka. (2006). Tyre and vehicle dynamics (2nd ed.). Elsevier.',
    '[8]. R. Rajamani. (2012). Vehicle dynamics and control (2nd ed.). Springer.',
    '[9]. Valeo. Torque and/or angle sensors, product catalogue. https://www.valeo.com/en/catalogue/cda/torque-and-or-angle-sensors/',
    '[10]. Bosch Motorsport. (2026). Steering wheel angle sensor LWS, data sheet. https://www.bosch-motorsport.com',
    '[11]. Bosch Motorsport. (2020). Acceleration sensor MM5.10, data sheet. https://www.bosch-motorsport.com',
    '[12]. H. Ragab, S. Givigi and A. Noureldin. (2024). Automotive speed estimation: Sensor types and error characteristics from OBD-II to ADAS. arXiv:2501.00242.',
]


# equations longer than one column (8.4 cm): where the line is broken, given as (marker, break_after_marker)
ROW_BREAKS = {7: ('=', True), 9: ('e_c+', True), 23: ('=', True), 27: ('e_T(s)+', True),
              29: (r'\,\brack', False), 31: ('u_I[k]+', True), 35: (r'\,\paren{\dfrac{RMS', False)}


def break_equations(t):
    lines = t.split('\n')
    for i, l in enumerate(lines):
        m_ = re.match(r'^  \((\d+)\)  ', l)
        if m_ and int(m_.group(1)) in ROW_BREAKS and lines[i + 1].startswith('  [ '):
            marker, after = ROW_BREAKS[int(m_.group(1))]
            lx = lines[i + 1]
            k = lx.index(marker)
            k = k + len(marker) if after else k
            lines[i + 1] = lx[:k] + r' \\ ' + lx[k:]
    return '\n'.join(lines)


def sub(text, old, new):
    assert old in text, old
    return text.replace(old, new)


def main(src, dst, v1):
    t = open(src, encoding='utf-8').read()
    t = sub(t, 'when evaluating EPS controller performance.', 'when evaluating C-EPS controller performance.')
    t = sub(t, 'The tire-shape parameters are listed in Table 3.', 'The tire-shape parameters are listed in Section 4.1.')
    t = sub(t, '$\\frac{1}{1+s_m}$', '$1/(1+s_m)$')
    t = sub(t, ', based on the original dynamic-result set', '')
    t = sub(t, '\nAcknowledgements\n', '\nAcknowledgments\n')
    t = sub(t, '[3], [6]', '[3,6]')
    t = sub(t, '[7], [8]', '[7,8]')
    t = sub(t, '[9]–[11]', '[9–11]')
    t = re.sub(r'\bFigure (\d)', r'Fig. \1', t)           # the template writes Fig. n
    t = break_equations(t)
    t = sub(t, 'Figures/v5_Huypt/Figure_3_pareto.png', 'Figures/v5_Huypt/Figure_3_pareto_col.png')
    if v1:
        t = sub(t, 'Each controller was calibrated and evaluated using a single noise realization, without a statistical assessment across multiple noise sequences. ', '')
    m_ = re.search(r'\n(-{20,})\nReferences\n', t)
    bar = m_.group(1)
    head = t[:m_.start()]
    extra = ('\n' + bar + '\nAuthor contributions\n' + bar + '\n' + AUTHOR_CONTRIB + '\n\n' + bar + '\nDeclaration of Generative AI\n' + bar + '\n' + AI_DECL + '\n')
    # the Conflict of Interest section stays where it is; the new sections follow it
    out = head.rstrip('\n') + '\n' + extra + '\n' + bar + '\nReferences\n' + bar + '\n' + '\n'.join(REFS) + '\n'
    open(dst, 'w', encoding='utf-8').write(out)
    print('Wrote', dst, '(version 1)' if v1 else '')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], '--v1' in sys.argv[3:])
