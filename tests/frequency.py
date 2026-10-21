# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Count completed setups (9), perfected 9s and countdown 13s per 1,000 closed bars from the OHLC columns of dump CSVs
(aggregate numbers only).

    python3 tests/frequency.py <dump dir> M15 H1 H4 > docs/data/count-frequency.json
Reads <dump dir>/dump/sq_default_<SYMBOL>_<TF>.csv; every closed bar is counted with tests/reference.py."""
import json
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import run  # noqa: E402

root = Path(sys.argv[1])
result = {}
for tf in sys.argv[2:]:
    bars = nine = perf = c13 = 0
    per_symbol = {}
    for f in sorted(root.glob(f"dump/sq_default_*_{tf}.csv")):
        d = pd.read_csv(f)
        h, l, c = (d[k].to_numpy(float)[:-1] for k in ("high", "low", "close"))
        rows = run(h, l, c)
        n9 = sum(1 for r in rows if r["ev_setup"])
        np_ = sum(1 for r in rows if r["ev_setup"] and r["perf"])
        n13 = sum(1 for r in rows if r["ev_cd"])
        per_symbol[f.stem.split("_")[2]] = dict(bars=len(c), setups_9=n9, perfected=np_, countdown_13=n13)
        bars += len(c); nine += n9; perf += np_; c13 += n13
    result[tf] = dict(closed_bars=bars, per_symbol=per_symbol, setups_9_per_1000_bars=round(1000 * nine / bars, 2),
                      perfected_share_of_9s=round(perf / max(1, nine), 3),
                      countdown_13_per_1000_bars=round(1000 * c13 / bars, 2),
                      thirteens_per_nine=round(c13 / max(1, nine), 3))
print(json.dumps(result, indent=1))
