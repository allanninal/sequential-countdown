# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Compare what the indicator wrote (DumpIndicator CSVs on MT5, Dump4 CSVs on MT4) with tests/reference.py, bar by bar.

    python3 tests/check_parity.py <dump dir>          (needs numpy and pandas; looks in <dump dir>/dump)
    python3 tests/check_parity.py <dump dir> --mt4    (the MT4 edition, dumps from the MT4 tester)

Buffers: b0 buy 13 arrow (at the low), b1 sell 13 arrow (at the high), b2/b3 buy/sell setup count (9 complete,
10 perfected 9), b4/b5 buy/sell countdown number (-1 deferred). The indicator counts the last InpHistory closed bars."""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import run  # noqa: E402

HIST = {"sq_default": 1500, "sq_long": 6000}
# DumpIndicator InpParams for MT5 in input order (each input group counts as a string parameter); as tests/configs.tsv
HEAD = ("s:Display|i:{h}|b:true|b:true|i:8|c:6465062|c:4606690|c:14064726|c:3968214|s:Alerts on|b:{a}|b:{a}|"
        "s:Alerts|b:false|b:false|s:alert.wav|b:false|b:false")
MT5_PARAMS = {"sq_default": HEAD.format(h=1500, a="false"), "sq_long": HEAD.format(h=6000, a="true")}


def num(col):
    return pd.to_numeric(col, errors="coerce").to_numpy(float)


def check(csv: Path, hist: int, mt4=False):
    d = pd.read_csv(csv)
    n = len(d)
    # MT4 tester: the indicator was attached with far fewer than InpHistory bars, so it counts from bar 0 and keeps
    # feeding; its 13 arrows sit a multiple of ATR away from the candle, so only where they are is compared
    start = 0 if mt4 else max(0, n - 1 - hist)
    h, l, c = (d[k].to_numpy(float) for k in ("high", "low", "close"))
    rows = run(h[start:n - 1], l[start:n - 1], c[start:n - 1])
    exp = {k: np.full(n, np.nan) for k in ("b0", "b1", "b2", "b3", "b4", "b5")}
    for i, r in enumerate(rows):
        k = start + i
        exp["b2"][k] = 10 if (r["ev_setup"] == 1 and r["perf"]) else r["bcnt"]
        exp["b3"][k] = 10 if (r["ev_setup"] == -1 and r["perf"]) else r["scnt"]
        exp["b4"][k] = -1 if r["defer"] == 1 else r["bmark"]
        exp["b5"][k] = -1 if r["defer"] == -1 else r["smark"]
        if r["ev_cd"] == 1:
            exp["b0"][k] = l[k]
        if r["ev_cd"] == -1:
            exp["b1"][k] = h[k]
    ok, msgs = True, []
    for b in exp:
        if mt4 and b in ("b0", "b1"):
            good = np.isnan(num(d[b])[:n - 1]) == np.isnan(exp[b][:n - 1])
        else:
            good = np.isclose(num(d[b])[:n - 1], exp[b][:n - 1], rtol=1e-12, atol=0, equal_nan=True)
        ok &= bool(good.all())
        msgs.append(f"{b} {'OK' if good.all() else f'{(~good).sum()} differ (first bar {int(np.flatnonzero(~good)[0])})'}")
    n9 = sum(1 for r in rows if r["ev_setup"])
    n13 = sum(1 for r in rows if r["ev_cd"])
    return ok, f"{csv.stem:30} bars {n:>6} counted {n - 1 - start:>5} 9s {n9:>4} 13s {n13:>3}  " + " ".join(msgs)


if __name__ == "__main__":
    mt4 = "--mt4" in sys.argv          # dumps of the MT4 Strategy Tester run
    root = Path([a for a in sys.argv[1:] if a != "--mt4"][0])
    allok, k = True, 0
    for tag, hist in HIST.items():
        for f in sorted(root.glob(f"dump/{tag}_*.csv")):
            ok, msg = check(f, hist, mt4)
            allok &= ok
            k += 1
            print(("PASS " if ok else "FAIL ") + msg)
    print(f"\n{'ALL PASS' if allok and k else 'FAILURES'} ({k} files)")
    sys.exit(0 if allok and k else 1)
