# wine-shell (working title)

CrossOver-style Wine wrapper for Apple Silicon Macs — Swift + SwiftUI.
GUI shell around prebuilt Wine: isolated bottles, run-with-options, per-bottle graphics backends, winetricks fixes.

**Status: Phase 0 viability spike (kill-or-go).** See `Spike0/Runbook.md`.
Full plan (errors, simulations, phases): vault `wiki/00-Current-Projects/wine-shell-plan.md`.

## Layout (grows per phase)

- `Spike0/` — Phase 0 test harness + Mac runbook. Deleted or archived once Phase 1 scaffolding lands.
- `Sources/` (Phase 1) — `Bottle`/`Program` models, launcher, setup wizard.
- `App/` (Phase 1) — SwiftUI shell.
