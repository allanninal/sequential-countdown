# Sequential Countdown: the 9-13 variant in this repository

The public 9-13 setup and countdown method exists in several variants whose counts differ between tools. This file states
the one variant implemented here. The exact rules are `tests/reference.py` (the source of truth; the MQL engine `Seq.mqh`
is checked against it bar by bar). All decisions are on CLOSED bars; `k` is the bar just closed.

## Setup
- Buy setup bar: `close[k] < close[k-4]`. It starts at 1 only after a flip: `close[k-1] > close[k-5]`; following bars count
  2, 3 ... while the condition holds; any other bar resets the count to 0. At 9 the setup is complete and the count resets
  (a new setup needs a new flip). A sell setup mirrors it (`close > close` 4 bars earlier, flip `<`).
- Perfected buy 9: the low of bar 8 or 9 is `<=` the lows of bars 6 and 7. Sell: the high of bar 8 or 9 is `>=` the highs of
  bars 6 and 7. A 9 that is not perfected is shown as `9'`.
- Setup level: a completed buy setup records its resistance = the highest high of its 9 bars; a completed sell setup records
  its support = the lowest low of its 9 bars. The level cancels the countdown it started (below).

## Countdown
- A completed buy setup starts (or restarts, "recycle") a buy countdown, counting from its bar 9 itself. A buy countdown
  bar: `close[k] <= low[k-2]`. Bars need not be consecutive.
- Bar 13 needs `low[k] <=` the close of countdown bar 8. A bar that meets the close rule but not this one is deferred (shown
  as `+`, not counted). 13 completes and ends the countdown.
- A buy countdown is cancelled by a completed sell setup, or by a close above the resistance level of the setup that started
  it. A sell countdown mirrors it (`close[k] >= high[k-2]`; 13 needs `high[k] >=` the close of bar 8; cancelled by a buy
  setup or a close below its setup's support level).
- A completed setup cancels the opposite countdown.

## On the chart
Setup numbers 1-9 (perfected 9s marked) and countdown numbers 1-13 on one chart; alerts on 9 and 13; buffers for other
programs (see the README).
