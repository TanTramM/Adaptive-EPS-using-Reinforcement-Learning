"""Flag content words that repeat within a window of N words (default 100).

Usage: python tools/check_repeat.py <file.md|txt> [--window 100] [--start "## Abstract"] [--stop "## Bang A"] [--model]
Only the text between the start and stop markers is checked (whole file when omitted).
Technical terms listed in TECH and function words are ignored, see Tracking/CLAUDE.md rule D8.
"""
import re
import sys

STOP = set("""a an the of and or but nor so yet to in on at by for with from as into onto over under than then that this these those
it its is are was were be been being has have had do does did not no can could may might would will shall should must
which who whom whose what when where while whereas although because since if both each any all some more most less
also only just such other another same between about through during after before above below up down out off per via
we our us he she they them their his her you your i me my one two three four five""".split())

TECH = set("""map torque steering assist driver controller controllers vehicle speed road tire tires adhesion friction error tracking
noise sensor sensors loop mappid pid mcu eps wheel stability torsion bar target structure structures feedback slope
compensator lead lag dry branch parallel parameters parameter column motor pareto front test tests paper study torsion-bar lead-lag""".split())

MODEL = set("""plant body angle angles slip force forces axle axles lateral acceleration trail moment pneumatic zero caster
reference state states column lower upper gear pinion rack contact patch brush offset caster length floor aligning limit steady friction coefficient longitudinal plane dashed line equation equations table figure
figures section sections symmetry reaction balance coupled objective measured measures output outputs command value
derivative integral proportional gain gains term terms stage stages lead lag filter resonance calibration breakpoint breakpoints characteristic integrator anti-windup back-calculation tracking closed-loop signal flow slope steady-state residual assistance dry-road dead zone setpoint time load disturbance disturbances
full safe front fronts point points staircase period periods accuracy accurate local locally delay step steps group groups grid final calib
window windows level levels input hold evaluation design designs cycle cycles coarse fine check bounds bound block blocks acceptance nominal
nonlinear passing passed pass selected selection variation variable variables response simulation quantization noise-seed seed seeds""".split())

LABEL = re.compile(r"\*\*\[[A-Z0-9.]+\]\*\*")
CITE = re.compile(r"\[[0-9,\s–-]+\]")


def stem(w):
    for suf in ("ation", "ion", "ing", "ed", "es", "ly", "s", "d", "e"):
        if w.endswith(suf) and len(w) - len(suf) >= 3:
            return w[: -len(suf)]
    return w


def words(text):
    """list of (word, label of the labelled sentence it belongs to)"""
    text = re.sub(r"^#.*$", " ", text, flags=re.M)
    text = re.sub(r"\$\$.*?\$\$", " ", text, flags=re.S)
    text = re.sub(r"\$[^$\n]*\$", " ", text)
    text = CITE.sub(" ", text)
    out, label = [], "-"
    pos = 0
    for m in list(LABEL.finditer(text)) + [None]:
        end = m.start() if m else len(text)
        seg = re.sub(r"[*_`#|]", " ", text[pos:end])
        out += [(w, label) for w in re.findall(r"[A-Za-z][A-Za-z\-]*", seg)]
        if m:
            label = m.group(0)[3:-3]
            pos = m.end()
    return out


def check(text, window):
    toks = words(text)
    last = {}
    hits = []
    for i, (w, lab) in enumerate(toks):
        lw = w.lower()
        if lw in STOP or lw in TECH or (USE_MODEL and lw in MODEL) or len(lw) < 4:
            continue
        s = stem(lw)
        if s in last and i - last[s][0] <= window:
            hits.append((s, last[s][1], w, i - last[s][0], last[s][2], lab))
        last[s] = (i, w, lab)
    return hits


USE_MODEL = False


def main():
    global USE_MODEL
    args = sys.argv[1:]
    if "--model" in args:
        USE_MODEL = True
        args.remove("--model")
    path = args[0]
    window = 100
    start = stop = None
    i = 1
    while i < len(args):
        if args[i] == "--window":
            window = int(args[i + 1]); i += 2
        elif args[i] == "--start":
            start = args[i + 1]; i += 2
        elif args[i] == "--stop":
            stop = args[i + 1]; i += 2
        else:
            i += 1
    text = open(path, encoding="utf-8").read()
    if start:
        text = text[text.index(start):]
    if stop:
        text = text[: text.index(stop)]
    parts = re.split(r"^## 1\. Introduction", text, flags=re.M)
    for name, part in zip(("Abstract", "Introduction"), parts):
        hits = check(part, window)
        print(f"[{name}] {len(hits)} repeat(s) within {window} words")
        for s, a, b, d, la, lb in hits:
            print(f"  {a} / {b}  (distance {d})  [{la}] -> [{lb}]")


if __name__ == "__main__":
    main()
