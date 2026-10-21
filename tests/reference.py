# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Python twin of Seq.mqh: the 9-13 setup and countdown in the variant of docs/SPEC.md, step for step, so the
indicators' output can be compared bar by bar (tests/check_parity.py).

    from reference import run
    rows = run(high, low, close)        # one dict per bar
"""


def run(high, low, close):
    n = len(close)
    bcnt = scnt = 0
    bcd = scd = 0                     # countdown counts; active flags below
    b_on = s_on = False
    b_c8 = s_c8 = 0.0
    b_lvl = s_lvl = None              # level of the setup that started the active countdown
    rows = []
    for k in range(n):
        ev_setup = 0                  # +1 buy 9, -1 sell 9
        perf = False
        ev_cd = 0                     # +1 buy 13, -1 sell 13
        defer = 0
        bmark = smark = 0             # countdown number printed on this bar (0 none)
        if k >= 5:
            c = close
            if c[k] < c[k - 4]:
                if bcnt > 0:
                    bcnt += 1
                elif c[k - 1] > c[k - 5]:
                    bcnt = 1
            else:
                bcnt = 0
            if c[k] > c[k - 4]:
                if scnt > 0:
                    scnt += 1
                elif c[k - 1] < c[k - 5]:
                    scnt = 1
            else:
                scnt = 0
            if bcnt == 9:
                ev_setup = 1
                perf = min(low[k], low[k - 1]) <= min(low[k - 3], low[k - 2])
                res = max(high[k - 8:k + 1])         # the setup's resistance
                bcnt = 0
                s_on, scd = False, 0                 # a buy setup cancels the sell countdown
                b_on, bcd, b_lvl = True, 0, res      # and starts (or recycles) the buy countdown
            elif scnt == 9:
                ev_setup = -1
                perf = max(high[k], high[k - 1]) >= max(high[k - 3], high[k - 2])
                sup = min(low[k - 8:k + 1])          # the setup's support
                scnt = 0
                b_on, bcd = False, 0
                s_on, scd, s_lvl = True, 0, sup
        if k >= 2:
            if b_on and close[k] > b_lvl:
                b_on, bcd = False, 0                 # closed above the setup's resistance: cancelled
            if s_on and close[k] < s_lvl:
                s_on, scd = False, 0
            if b_on and close[k] <= low[k - 2]:
                if bcd < 12:
                    bcd += 1
                    bmark = bcd
                    if bcd == 8:
                        b_c8 = close[k]
                elif low[k] <= b_c8:
                    bcd, ev_cd, b_on, bmark = 13, 1, False, 13
                else:
                    defer = 1
            if s_on and close[k] >= high[k - 2]:
                if scd < 12:
                    scd += 1
                    smark = scd
                    if scd == 8:
                        s_c8 = close[k]
                elif high[k] >= s_c8:
                    scd, ev_cd, s_on, smark = 13, -1, False, 13
                else:
                    defer = -1
        rows.append(dict(bcnt=bcnt if ev_setup != 1 else 9, scnt=scnt if ev_setup != -1 else 9,
                         bcd=bcd if (b_on or ev_cd == 1) else 0, scd=scd if (s_on or ev_cd == -1) else 0,
                         ev_setup=ev_setup, perf=perf, bmark=bmark, smark=smark, ev_cd=ev_cd, defer=defer))
        if ev_cd == 1:
            bcd = 0
        if ev_cd == -1:
            scd = 0
    return rows
