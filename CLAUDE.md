# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`cocktail` is a pure Elixir library (no Phoenix, no database) that generates infinite streams of recurring datetimes from iCalendar-style recurrence rules. Published to Hex.pm.

## Commands

```bash
mix deps.get          # install dependencies
mix test              # run all tests
mix test test/cocktail/daily_test.exs   # run a single test file
mix test test/cocktail/daily_test.exs:42  # run a single test by line
mix format            # format code
mix format --check-formatted  # CI format check
mix credo             # lint
mix dialyzer          # type checking (slow on first run, builds PLT)
mix coveralls         # test coverage report
mix docs              # generate ExDoc HTML docs
```

## Architecture

Occurrence generation is a lazy stream pipeline:

```
Schedule.occurrences/2
  → Stream.unfold(ScheduleState, ...)
      → ScheduleState picks next candidate across all RuleStates
          → RuleState runs a chain of Validation modules (shift pipeline)
```

**Core types:**
- `Cocktail.Schedule` — public struct; holds start time, list of `Rule`s, recurrence times, exception times
- `Cocktail.Rule` — RRULE struct (frequency + options: interval, days, hours, minutes, seconds, day_of_month, time_of_day, time_range, count, until)
- `Cocktail.Span` — `{start, duration}` used when schedules have duration set

**Internal state (not public API):**
- `Cocktail.ScheduleState` — merges candidate datetimes from multiple `RuleState`s and recurrence_times; skips exception_times; returns the next occurrence
- `Cocktail.RuleState` — holds one rule + current cursor datetime; calls `Validation.next_time/2` to advance

**Validation pipeline** (`lib/cocktail/validation/`):
Each module implements `validate(time, rule)` → `{:ok, time}` or `{:needs_shift, time}`. `Validation.Shift` provides the `shift_by/3` helper. Validators chain in this order (innermost = most granular):
`ScheduleLock → Interval → Day → DayOfMonth → HourOfDay → MinuteOfHour → SecondOfMinute → TimeOfDay → TimeRange`

**Serialization:**
- `Cocktail.Parser.ICalendar` — parses `DTSTART`/`RRULE`/`RDATE`/`EXDATE` text → `Schedule`
- `Cocktail.Builder.ICalendar` — `Schedule` → iCalendar string (round-trips with parser)
- `Cocktail.Builder.String` — `Schedule` → human-readable description

## Key design constraint

The validation shift pipeline must be **monotonically advancing** — each validator can only move the cursor forward, never backward. Adding a new validator or option must preserve this invariant or occurrence generation will loop infinitely.

## Test layout

Tests mirror `lib/`: per-frequency tests (`daily_test`, `weekly_test`, etc.), `reversibility_test` (iCal round-trip), `edge_cases_test`, and per-validator tests under `validation/`. `test/support/` has shared helpers loaded only in `:test` env (see `elixirc_paths` in `mix.exs`).
