# Pager line components — design

## Goal

Extend the pager tab (bottom-right overlay) so it can render up to two lines of
dynamic text to the left of the space-number badge — matching the mockup where
wattage (`6.7w`) sits above a slightly larger clock (`19:27`), with the badge
(`2`) anchored bottom-right.

Today `Pager` renders only the badge and redraws solely on space change. The new
content is dynamic (the clock ticks, wattage drifts), so the pager gains an
optional, self-refreshing line system.

## Non-goals

- More than two lines.
- Arbitrary self-positioned components (icons, gauges). Lines are text only.
- Changing how the badge/tab shape behaves when no lines are configured.

## Config surface

`init.lua` already exposes `obj.pager = { enabled = false }`. Extend it:

```lua
obj.pager = {
  enabled = true,
  lines = {                          -- optional, 0–2 entries, top-to-bottom
    { text = fn, size = 10, refresh = 30 },
    { text = fn, size = 14, refresh = "minute" },
  },
}
```

- No `lines` (or `enabled = true` alone) → exactly today's behavior: badge only.
  Full backward compatibility; existing pager tests stay green.
- `init.lua` passes `lines` into `Pager.new({ telemetry, lines, hsTimer })`.
- `update(virtualSpace)` keeps its signature. The badge number comes from the
  event; each line's value comes from its own `text` function.

## Component contract

Each line is a table:

| field     | type                     | default            | meaning |
|-----------|--------------------------|--------------------|---------|
| `text`    | `function() -> string`   | required           | value producer, re-evaluated on every redraw |
| `size`    | number                   | inherited default  | font size in points |
| `color`   | hs color                 | white              | text color |
| `refresh` | number \| string \| nil  | nil                | number = seconds; `"minute"` = minute-aligned; nil = redraws only on space change |

- Lines render top-to-bottom, right-aligned as a block, in the column left of the
  badge.
- Cap is 2. A third-or-later entry is logged (telemetry) and ignored.

## Refresh / timer lifecycle

The pager owns its clock.

On `update()`:
- Re-evaluate all `text` functions and redraw (already happens on space change).
- Ensure a timer exists per distinct `refresh` spec; each fires a full redraw
  (re-evaluates every line — cheap, keeps the canvas consistent):
  - `refresh = N` (number) → `hsTimer.doEvery(N, redraw)`.
  - `refresh = "minute"` → self-rescheduling timer aligned to the next minute
    boundary, so the clock flips exactly at `:00` rather than up to 60s late.
- `refresh = nil` → no timer; the line only refreshes when the pager redraws for
  another reason (space change).

`delete()` stops all timers and nils the canvas.

`hsTimer` is injected (`deps.hsTimer or hs.timer`) so tests drive ticks
deterministically.

## Geometry

The badge stays anchored bottom-right (unchanged). The tab grows leftward and, if
needed, taller to fit the two-line block:

- Tab width = swoop + text-column + badge + paddings, where text-column width is
  the widest rendered line.
- The existing swoop/shoulder/corner math is all fractions of `frame.w`/`frame.h`,
  so the shape rescales proportionally once the frame grows.
- Vertically, two stacked lines sized to fit within `TAB_HEIGHT` (`TAB_HEIGHT` may
  be nudged up).

Geometry constants are tuned during implementation against a real screen; the
mockup is the reference.

## Testing (TDD)

Mock canvas + injected `hsTimer`/`hsScreen`, as today. New tests:

- Both configured lines render their text.
- `size` reaches the text element.
- A captured timer callback re-evaluates `text`: a changing return value produces
  a changed canvas.
- `"minute"` refresh schedules an aligned (not fixed-60s-from-now) timer.
- Tab grows to fit the block (widest line + badge still flush bottom-right).
- Regression: no `lines` → no timer started, badge-only render unchanged.
- `delete()` stops all timers.

## Open tuning items (implementation-time, not blocking)

- Exact `TAB_HEIGHT` / text-column padding values.
- Default line font size and vertical spacing between the two lines.
