# Mac Session Pack — hands-on checklist (MAC-HANDS, ~1 hour)

Do this on an Apple Silicon Mac (yours or borrowed). CI already proves everything
below the GUI line; this pack proves pixels, windows, and Apple-only behavior.
Copy each VERDICT line + any log tail into `wine-shell-plan.md` §5 when done.

Conventions: `✅ PASS` / `❌ FAIL + log tail`. Any FAIL → file it, continue the
rest, two sittings max per step (kill criteria from the plan).

## A. Own Mac, full session (~60 min)

### A0. Pre-flight — EXPECTED: three oks
```sh
pgrep oahd >/dev/null && echo ROSETTA-OK            # EXPECTED: ROSETTA-OK
sw_vers -productVersion                              # EXPECTED: 14+ (15/26 fine)
df -h ~ | awk 'NR==2{print $4}'                     # EXPECTED: 2 GB+ free
xcode-select -p                                     # EXPECTED: a path (install CLT if missing)
```
VERDICT A0: ____

### A1. Runtime — EXPECTED: hash matches, both binaries present
Follow `Spike0/Runbook.md` §1 (pinned Gcenx Staging + SHA-256 + tar + one-time
quarantine clear). Then:
```sh
ls ~/wine-shell/runtime/*/bin/wine64 ~/wine-shell/runtime/*/bin/wineserver
```
EXPECTED: both paths listed, no error.
VERDICT A1: ____

### A2. Bottle init — EXPECTED: `drive_c` created, exit 0
```sh
export WINEPREFIX=~/wine-shell/bottle0 WINEDEBUG=fixme-all
~/wine-shell/runtime/*/bin/wine64 wineboot --init; echo EXIT:$?
ls ~/wine-shell/bottle0/drive_c
```
EXPECTED: `EXIT:0` + `drive_c` listing.
VERDICT A2: ____

### A3. winecfg window — EXPECTED: visible config window (MAC-HANDS #1)
```sh
~/wine-shell/runtime/*/bin/wine64 winecfg
```
EXPECTED: Wine configuration window appears, editable, closes cleanly.
If invisible/offscreen → wrapper-bundle work is confirmed mandatory (plan §4 S2).
VERDICT A3: ____

### A4. Notepad types — EXPECTED: visible editor, typed text (MAC-HANDS #2)
```sh
~/wine-shell/runtime/*/bin/wine64 notepad
```
EXPECTED: window, you type, close, exit 0.
VERDICT A4: ____

### A5. Swift shell — EXPECTED: app launches, bottle CRUD works
```sh
cd ~/wine-shell && swift run
```
EXPECTED: bottle list window → create bottle → appears in list → Run sheet opens
→ with no runtime set, status reads "set Wine runtime first".
VERDICT A5: ____

### A6. Backend + winetricks smoke — EXPECTED: verbs install, DLLs land
Pick one bottle, backend DXVK (needs Gcenx/monolithic DXVK-macOS DLLs per plan),
run winetricks `corefonts` via the future UI/CLI. EXPECTED: exit 0, fonts dir grows.
VERDICT A6: ____ (may defer to Phase 2 UI)

### A7. D3DMetal import — EXPECTED: validator accepts your GPTK DMG (MAC-HANDS #3)
Apple Developer → download Game Porting Toolkit DMG → mount → point the
importer at it. EXPECTED: `D3DMetal.framework` found, forwarders validate.
NEVER commit, upload, or share the DMG (Apple license).
VERDICT A7: ____ (may defer — needs free Apple Developer account)

## B. Borrowed Mac, minimal footprint (~30 min, no Xcode install)

Needs only: Rosetta (A0 line 1) + Command Line Tools (`xcode-select --install`).
Skip A6/A7. Do A0–A5, then clean up:
```sh
rm -rf ~/wine-shell/bottle0 ~/wine-shell/runtime
```
Leave the repo clone or delete it — your call. VERDICT B: ____

## C. After the session

- [ ] Paste all VERDICTs + tails into the plan (§5 execution log)
- [ ] Any FAIL older than 2 sittings → kill criteria: park per plan
- [ ] All PASS → Phase 0 fully closed; open Phase 1 UI wiring + packaging
