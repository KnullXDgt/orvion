#!/usr/bin/env python3
"""
Device simulator: run an UNMODIFIED rejoin.lua against a fake Android device.

Only the shell the tool talks to is faked (su / pm / stty / tput), plus a
scheduled-event injector playing the role of Roblox clients disconnecting.
/sdcard is used verbatim so the tool's hardcoded paths work unchanged.
"""
import os, sys, json, subprocess, tempfile, threading, time, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REJOIN = os.environ.get("REJOIN_PATH") or os.path.join(HERE, "rejoin.lua")
SDCARD = "/sdcard"

SHIM = r'''#!/usr/bin/env python3
import sys, os, json, re, fcntl, tempfile, time
STF = os.environ["DEVSIM_STATE"]
LOCK = STF + ".lock"

argv = sys.argv[1:]
name = os.path.basename(sys.argv[0])
if name == "su" and "-c" in argv:
    cmd = argv[argv.index("-c")+1]
elif name == "pm":
    cmd = "pm " + " ".join(argv)
else:
    cmd = " ".join(argv)

out_lines = []

def process(s):
    # ---- for p in ...; do echo "P $p=$(pidof $p)"; done ----
    mloop = re.search(r'for p in ([^;]+); do echo "P \$p=\$\(pidof \$p\)"', cmd)
    if mloop:
        for pkg in mloop.group(1).split():
            c = s["clones"].get(pkg)
            out_lines.append("P %s=%s" % (pkg, (str(c["pid"]) if c and c.get("alive") else "")))
    if re.search(r'echo "F \S+=\$\(', cmd):
        for pkg in re.findall(r'echo "F (\S+)=', cmd):
            c = s["clones"].get(pkg)
            out_lines.append("F %s=%s" % (pkg, (str(c["pid"]) if c and c.get("alive") else "")))

    done_logcat = False
    for seg in cmd.split(";"):
        seg = seg.strip()
        if not seg:
            continue
        m = re.search(r"am\s+force-stop\s+(\S+)", seg)
        if m:
            pkg = m.group(1)
            if pkg in s["clones"]:
                s["clones"][pkg]["alive"] = False
            continue
        m = re.search(r"package=([A-Za-z0-9_.]+)", seg)
        if m:
            pkg = m.group(1)
            c = s["clones"].setdefault(pkg, {"pid": 3000, "alive": True})
            c["alive"] = True
            c["pid"] = c.get("pid", 3000) + 1
            continue
        if "logcat" in seg and not done_logcat:
            for ln in s.get("loglines", []):
                out_lines.append(ln)
            done_logcat = True
            continue
        if "list packages" in seg:
            for pkg in s["clones"]:
                out_lines.append("package:" + pkg)
            continue
        if "dumpsys window" in seg or "wm size" in seg:
            out_lines.append("mStable=[0,0][720,1280]")
            out_lines.append("Physical density: 320")
            out_lines.append("Physical size: 720x1280")
            continue
        if "pidof" in seg and not mloop:
            for pkg in re.findall(r"pidof\s+(\S+)", seg):
                c = s["clones"].get(pkg)
                out_lines.append(str(c["pid"]) if c and c.get("alive") else "")

# single atomic read-modify-write under one lock
lf = open(LOCK, "w")
fcntl.flock(lf, fcntl.LOCK_EX)
try:
    try:
        with open(STF) as fh:
            s = json.load(fh)
    except Exception:
        s = {"clones": {}, "loglines": [], "events": []}
    process(s)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(STF))
    with os.fdopen(fd, "w") as fh:
        json.dump(s, fh)
    os.replace(tmp, STF)
finally:
    fcntl.flock(lf, fcntl.LOCK_UN)
    lf.close()

for ln in out_lines:
    sys.stdout.write(ln + "\n")
sys.exit(0)
'''

def build_shims(bindir):
    p = os.path.join(bindir, "su")
    open(p, "w").write(SHIM); os.chmod(p, 0o755)
    q = os.path.join(bindir, "pm")
    open(q, "w").write(SHIM); os.chmod(q, 0o755)
    for t in ("stty", "tput"):
        r = os.path.join(bindir, t)
        open(r, "w").write("#!/bin/sh\nexit 0\n"); os.chmod(r, 0o755)

def disc_line(pid, code, iso):
    sec = iso % 60
    return ("09-22 08:%02d:00.000 %5d %5d I Roblox : disconnect with reason: %d "
            "userid: 11078738315 time: 2026-09-22T08:%02d:00.000Z"
            % (sec, pid, pid, code, sec))

_STARTED = []

def _kill_started():
    """Kill only the lua processes WE started (never a broad pkill -f)."""
    for pid in list(_STARTED):
        try:
            os.kill(pid, 9)
        except ProcessLookupError:
            pass
        except Exception:
            pass
    _STARTED.clear()

def run_scenario(sc):
    _kill_started()
    duration = sc.get("duration", 40)
    os.makedirs(SDCARD, exist_ok=True)
    bindir = tempfile.mkdtemp(prefix="devsim_bin_")
    build_shims(bindir)
    stf = tempfile.mktemp(prefix="devsim_state_")
    lockpath = stf + ".lock"
    json.dump({"clones": sc.get("clones", {}), "loglines": sc.get("loglines", []),
               "events": sc.get("events", [])}, open(stf, "w"))

    open(os.path.join(SDCARD, "limbo_rejoin.cfg"), "w").write(sc["cfg"])
    open(os.path.join(SDCARD, "private_servers.txt"), "w").write(sc.get("ps", "") + "\n")
    for f in ("limbo_rejoin.log", ".limbo_rejoin.pid"):
        try: os.remove(os.path.join(SDCARD, f))
        except FileNotFoundError: pass

    env = dict(os.environ)
    env["PATH"] = bindir + ":" + env["PATH"]
    env["DEVSIM_STATE"] = stf
    env["LIMBO_WIDTH"] = "60"

    p = subprocess.Popen(["lua5.3", REJOIN], stdin=subprocess.PIPE,
                         stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                         env=env, cwd=HERE, text=True,
                         start_new_session=True)
    _STARTED.append(p.pid)
    try:
        p.stdin.write(sc.get("stdin", "1\n")); p.stdin.flush()
    except Exception:
        pass

    import fcntl
    t0 = time.time()
    stop = threading.Event()

    def injector():
        while not stop.is_set() and time.time() - t0 < duration:
            now = time.time() - t0
            lf = open(lockpath, "w"); fcntl.flock(lf, fcntl.LOCK_EX)
            try:
                try:
                    s = json.load(open(stf))
                except Exception:
                    s = {"clones": {}, "loglines": [], "events": []}
                remaining = []
                for e in s.get("events", []):
                    if e["at_sec"] <= now:
                        pkg = e.get("pkg")
                        c = s["clones"].get(pkg)
                        pid = c["pid"] if c else 4000
                        s["loglines"].append(disc_line(pid, e["code"], int(now)))
                        if e.get("force_stop") and e["force_stop"] in s["clones"]:
                            s["clones"][e["force_stop"]]["alive"] = False
                    else:
                        remaining.append(e)
                s["events"] = remaining
                fd, tmp = tempfile.mkstemp(dir=os.path.dirname(stf))
                with os.fdopen(fd, "w") as fh:
                    json.dump(s, fh)
                os.replace(tmp, stf)
            finally:
                fcntl.flock(lf, fcntl.LOCK_UN); lf.close()
            time.sleep(0.15)

    th = threading.Thread(target=injector, daemon=True); th.start()
    try:
        p.wait(timeout=duration)
    except subprocess.TimeoutExpired:
        p.kill(); p.wait()
    stop.set(); th.join(timeout=2)
    stderr = p.stderr.read()
    # ensure the tool is fully gone before the next scenario reads /sdcard
    _kill_started()
    time.sleep(0.4)

    final = json.load(open(stf))
    log = open(os.path.join(SDCARD, "limbo_rejoin.log")).read() \
          if os.path.exists(os.path.join(SDCARD, "limbo_rejoin.log")) else ""
    return {"stderr": stderr, "final": final, "log": log}

if __name__ == "__main__":
    sc = json.load(open(sys.argv[1]))
    sc["events"] = sc.get("events", sc.get("raw_events", []))
    r = run_scenario(sc)
    print("=== TOOL LOG ==="); print(r["log"][-3000:])
    print("=== STDERR ==="); print(r["stderr"][-600:])
    print("=== FINAL CLONES ===")
    for k, v in sorted(r["final"]["clones"].items()):
        print("  %-24s pid=%s alive=%s" % (k, v.get("pid"), v.get("alive")))
    json.dump({"log": r["log"], "clones": r["final"]["clones"]},
              open("/tmp/sim_result.json", "w"), indent=2)
