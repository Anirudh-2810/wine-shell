# wine-shell (working title)

[![ci](https://github.com/Anirudh-2810/wine-shell/actions/workflows/ci.yml/badge.svg)](https://github.com/Anirudh-2810/wine-shell/actions/workflows/ci.yml)

CrossOver-style Wine wrapper for Apple Silicon Macs — Swift + SwiftUI.
GUI shell around prebuilt Wine: isolated bottles, run-with-options, per-bottle graphics backends, winetricks fixes.

**Status: Phase 3 core green.** `WineKit` (bottles, env builder, backends, GPTK gate, recipes, refusal incl. PE machine check, Steam detection, debug bundle, async launcher) is CI-proven on Linux (real Wine integration) + Apple Silicon macOS. `WineShell` SwiftUI app compiles on macOS; GUI behavior + D3DMetal live proof await hands-on-Mac (see `Spike0/Runbook.md`).
Full plan (errors, simulations, phases): vault `wiki/00-Current-Projects/wine-shell-plan.md` (private Second-Brain repo).

## Layout (grows per phase)

- `Spike0/` — Phase 0 test harness + Mac runbook. Deleted or archived once Phase 1 scaffolding lands.
- `Sources/` (Phase 1) — `Bottle`/`Program` models, launcher, setup wizard.
- `App/` (Phase 1) — SwiftUI shell.
