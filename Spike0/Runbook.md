# Spike0 Runbook — execute ON an Apple Silicon Mac with Xcode CLT

Goal: prove `main.swift` end-to-end. Any step failing after 2 sittings = Phase 0 kill criteria → park project.

## 0. Pre-flight (Terminal)

```sh
pgrep oahd >/dev/null || softwareupdate --install-rosetta --agree-to-license  # Rosetta 2
sw_vers -productVersion   # need 14+
df -h ~ | awk 'NR==2{print $4}'  # need 2 GB+ free
```

## 1. Get a pinned Wine build (Gcenx `macOS_Wine_builds`)

1. Open https://github.com/Gcenx/macOS_Wine_builds/releases — pick a **Staging** tag (11.x era known-good; re-verify at run time, never "latest").
2. Download the `wine-staging-<ver>.tar.xz` (Apple Silicon / ARM64 asset) **+ its published SHA-256**, verify:
   ```sh
   shasum -a 256 wine-staging-*.tar.xz   # must match release page
   ```
3. Extract with `tar` (preserves symlinks — never unzip here):
   ```sh
   mkdir -p ~/wine-shell/runtime && tar -xJf wine-staging-*.tar.xz -C ~/wine-shell/runtime
   ls ~/wine-shell/runtime/*/bin/wine64 ~/wine-shell/runtime/*/bin/wineserver  # both must exist
   export WINEBIN=~/wine-shell/runtime/*/bin
   ```
4. First-run quarantine (expected once — unsigned binaries):
   ```sh
   xattr -dr com.apple.quarantine ~/wine-shell/runtime   # one-time; document, don't script blindly
   ```

## 2. Prove the harness

```sh
swift ~/wine-shell/Spike0/main.swift "$WINEBIN" ~/wine-shell/bottle0 winecfg
# winecfg window must appear. Close it → expect "[spike] PROVED".
swift ~/wine-shell/Spike0/main.swift "$WINEBIN" ~/wine-shell/bottle0 notepad
# Notepad opens, you can type. Close it → PROVED.
```

## 3. Wrapper-bundle check (S2 simulation)

If windows spawn invisible/offscreen: wrap Wine in a `Wine.app` bundle
(`Info.plist` with `LSUIElement=false` foreground policy) and relaunch via
`open Wine.app --args …`. Whisky/Scotch both needed this — treat as mandatory, not polish.

## 4. Record the verdict

- All green → Phase 0 PASSED: paste terminal tail into `wine-shell-plan.md` §5, start Phase 1.
- Any red after 2 sittings → Phase 0 KILLED: note the failing step + log tail, park until post-laptop-hunt.
