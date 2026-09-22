#!/usr/bin/env python3
"""
FULL simulator test suite for rejoin.lua (runs the REAL tool against a fake
device). Asserts FEATURES, not bugs.

Usage:
  python3 sim_suite.py                 # test ./rejoin.lua
  REJOIN_PATH=/tmp/x.lua python3 sim_suite.py
"""
import os, sys, importlib.util, json

HERE = os.path.dirname(os.path.abspath(__file__))
REJOIN = os.environ.get("REJOIN_PATH") or os.path.join(HERE, "rejoin.lua")
spec = importlib.util.spec_from_file_location("device_sim", os.path.join(HERE, "device_sim.py"))
sim = importlib.util.module_from_spec(spec); spec.loader.exec_module(sim)

PS = "https://www.roblox.com/share?code=12d8d8be58c20842abcf5426ffd61323&type=Server"
# heartbeat 2s -> quick scans; launch_delay 0
CFG = ("launch_delay=0\nplace_id=\nprefix=com.moons\nmode=rejoin\n"
       "pkg=com.moons.litesc,1,1,2,0,\n"
       "pkg=com.moons.litesd,1,1,2,0,\n"
       "pkg=com.moons.litese,1,1,2,0,")
CL = {"com.moons.litesc": {"pid":4001,"alive":True},
      "com.moons.litesd": {"pid":4002,"alive":True},
      "com.moons.litese": {"pid":4003,"alive":True}}
ALL = ("com.moons.litesc","com.moons.litesd","com.moons.litese")

PASS=0; FAIL=0; FAILDETAIL=[]
def ck(cond, msg):
    global PASS, FAIL
    if cond: PASS+=1
    else: FAIL+=1; FAILDETAIL.append(msg)

def rl(log, pkg):
    """relaunches of pkg via ANY path (rejoin/disconnect/dead)."""
    return log.count("LAUNCH " + pkg + " [")

def run(name, events, dur, expect):
    sc = {"duration":dur,"cfg":CFG,"ps":PS,"clones":dict(CL),"stdin":"1\n","events":events}
    r = sim.run_scenario(sc)
    log = r["log"]
    for e in expect: e(log, r["final"]["clones"])
    print("  done: " + name, flush=True)

print("== suite against %s ==" % REJOIN, flush=True)

# T1: one disconnect -> exactly one relaunch
run("T1", [{"at_sec":6,"pkg":ALL[0],"code":285}], 20, [
  lambda l,f: ck(rl(l,ALL[0])==1, "T1 litesc relaunch 1x (got %d)"%rl(l,ALL[0])),
  lambda l,f: ck(rl(l,ALL[1])==0, "T1 litesd untouched"),
  lambda l,f: ck(rl(l,ALL[2])==0, "T1 litese untouched")])

# T2: two disconnect same scan -> both relaunch
run("T2", [{"at_sec":6,"pkg":ALL[0],"code":285},
           {"at_sec":6,"pkg":ALL[1],"code":285}], 26, [
  lambda l,f: ck(rl(l,ALL[0])>=1, "T2 litesc relaunch"),
  lambda l,f: ck(rl(l,ALL[1])>=1, "T2 litesd relaunch (must not skip)")])

# T3: three disconnect -> all relaunch
run("T3", [{"at_sec":6,"pkg":ALL[0],"code":285},
           {"at_sec":6,"pkg":ALL[1],"code":285},
           {"at_sec":6,"pkg":ALL[2],"code":285}], 30, [
  lambda l,f: ck(rl(l,ALL[0])>=1, "T3 litesc relaunch"),
  lambda l,f: ck(rl(l,ALL[1])>=1, "T3 litesd relaunch"),
  lambda l,f: ck(rl(l,ALL[2])>=1, "T3 litese relaunch")])

# T4: ban 267 -> halt
run("T4", [{"at_sec":6,"pkg":ALL[0],"code":267}], 20, [
  lambda l,f: ck("HALT "+ALL[0] in l, "T4 litesc halt 267"),
  lambda l,f: ck(rl(l,ALL[0])==0, "T4 litesc no relaunch"),
  lambda l,f: ck(rl(l,ALL[1])==0, "T4 litesd untouched")])

# T4b: ban 600 -> halt
run("T4b", [{"at_sec":6,"pkg":ALL[1],"code":600}], 20, [
  lambda l,f: ck("HALT "+ALL[1] in l, "T4b litesd halt 600"),
  lambda l,f: ck(rl(l,ALL[1])==0, "T4b litesd no relaunch"),
  lambda l,f: ck(rl(l,ALL[0])==0, "T4b litesc untouched")])

# T4c: ban 267 (c) + disconnect 285 (d)
run("T4c", [{"at_sec":6,"pkg":ALL[0],"code":267},
            {"at_sec":6,"pkg":ALL[1],"code":285}], 26, [
  lambda l,f: ck("HALT "+ALL[0] in l, "T4c litesc halt 267"),
  lambda l,f: ck(rl(l,ALL[0])==0, "T4c litesc no relaunch"),
  lambda l,f: ck(rl(l,ALL[1])>=1, "T4c litesd relaunch")])

# T5: two bans at once -> both halt, third untouched
run("T5", [{"at_sec":6,"pkg":ALL[0],"code":600},
           {"at_sec":6,"pkg":ALL[1],"code":267}], 20, [
  lambda l,f: ck("HALT "+ALL[0] in l, "T5 litesc halt 600"),
  lambda l,f: ck("HALT "+ALL[1] in l, "T5 litesd halt 267"),
  lambda l,f: ck(rl(l,ALL[2])==0, "T5 litese untouched")])

# T6: halted client is never relaunched again
run("T6", [{"at_sec":6,"pkg":ALL[0],"code":267},
           {"at_sec":12,"pkg":ALL[0],"code":285}], 24, [
  lambda l,f: ck(rl(l,ALL[0])==0, "T6 halted stays halted")])

# T7: two dead (heartbeat) -> both relaunch after grace
run("T7", [{"at_sec":6,"pkg":ALL[0],"code":285,"force_stop":ALL[0]},
           {"at_sec":6,"pkg":ALL[1],"code":285,"force_stop":ALL[1]}], 65, [
  lambda l,f: ck(rl(l,ALL[0])>=1, "T7 litesc relaunch (dead)"),
  lambda l,f: ck(rl(l,ALL[1])>=1, "T7 litesd relaunch (dead)")])

# T8: three dead -> all relaunch after grace
run("T8", [{"at_sec":6,"pkg":ALL[0],"code":285,"force_stop":ALL[0]},
           {"at_sec":6,"pkg":ALL[1],"code":285,"force_stop":ALL[1]},
           {"at_sec":6,"pkg":ALL[2],"code":285,"force_stop":ALL[2]}], 75, [
  lambda l,f: ck(rl(l,ALL[0])>=1, "T8 litesc relaunch"),
  lambda l,f: ck(rl(l,ALL[1])>=1, "T8 litesd relaunch"),
  lambda l,f: ck(rl(l,ALL[2])>=1, "T8 litese relaunch")])

print("")
print("RESULT: %d PASS, %d FAIL" % (PASS, FAIL))
for m in FAILDETAIL: print("  FAIL: " + m)
sys.exit(0 if FAIL==0 else 1)
