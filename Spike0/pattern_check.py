"""Spike0 pattern check (runs HERE on Windows/Python).
Mirrors main.swift's design rules with a dummy child instead of Wine:
argv arrays (no shell), caller-env merge, async pipe drainage, timeout+kill.
Proves the harness PATTERN; the Wine/Rosetta/GUI proof still needs the Mac runbook.
"""
import os, subprocess, sys, threading, time

def run(argv, env_extra, timeout):
    env = dict(os.environ); env.update(env_extra)  # caller extras win
    p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, bufsize=1, shell=False, env=env)  # shell=False == argv rule
    lines = []
    def drain():
        for line in p.stdout:
            lines.append(line)
    t = threading.Thread(target=drain, daemon=True); t.start()  # async drainage
    try:
        rc = p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        p.kill(); rc = "TIMEOUT-KILLED"
    t.join(timeout=2)
    return rc, "".join(lines)

if __name__ == "__main__":
    dummy = [sys.executable, "-c",
             "import os,time; print('WINEPREFIX='+os.environ.get('WINEPREFIX','<unset>')); "
             "print('streamburst'); time.sleep(0.5); print('child-done')"]
    rc, out = run(dummy, {"WINEPREFIX": "C:/fake-bottle", "WINEDEBUG": "fixme-all"}, timeout=10)
    print("rc:", rc); print("captured:\n" + out)
    assert rc == 0, "child failed"
    assert "WINEPREFIX=C:/fake-bottle" in out, "env passthrough broken"
    assert "child-done" in out, "async drainage lost output"
    # Timeout path: child sleeps past deadline -> must be killed, not hang.
    rc2, _ = run([sys.executable, "-c", "import time; time.sleep(60)"], {}, timeout=3)
    assert rc2 == "TIMEOUT-KILLED", "timeout kill broken"
    print("PATTERN PROVED: argv + env-merge + async-drain + timeout-kill all green")
