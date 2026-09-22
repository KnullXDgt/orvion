#!/usr/bin/env python3
"""Run ONE e2e scenario by name. Usage: python3 run_one.py T2 [rejoin.lua]"""
import os, sys, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault("REJOIN_PATH", sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "rejoin.lua"))
spec = importlib.util.spec_from_file_location("device_sim", os.path.join(HERE, "device_sim.py"))
sim = importlib.util.module_from_spec(spec); spec.loader.exec_module(sim)

PS = "https://www.roblox.com/share?code=12d8d8be58c20842abcf5426ffd61323&type=Server"
CFG = ("launch_delay=0\nplace_id=\nprefix=com.moons\nmode=rejoin\n"
       "pkg=com.moons.litesc,1,1,2,0,\n"
       "pkg=com.moons.litesd,1,1,2,0,\n"
       "pkg=com.moons.litese,1,1,2,0,")
CL = {"com.moons.litesc": {"pid":4001,"alive":True},
      "com.moons.litesd": {"pid":4002,"alive":True},
      "com.moons.litese": {"pid":4003,"alive":True}}

SCEN = {
 "T1": ([{"at_sec":6,"pkg":"com.moons.litesc","code":285}], 20),
 "T2": ([{"at_sec":6,"pkg":"com.moons.litesc","code":285},
         {"at_sec":6,"pkg":"com.moons.litesd","code":285}], 26),
 "T3": ([{"at_sec":6,"pkg":"com.moons.litesc","code":285},
         {"at_sec":6,"pkg":"com.moons.litesd","code":285},
         {"at_sec":6,"pkg":"com.moons.litese","code":285}], 30),
 "T4": ([{"at_sec":6,"pkg":"com.moons.litesc","code":267}], 20),
 "T4b":([{"at_sec":6,"pkg":"com.moons.litesd","code":600}], 20),
 "T4c":([{"at_sec":6,"pkg":"com.moons.litesc","code":267},
         {"at_sec":6,"pkg":"com.moons.litesd","code":285}], 26),
 "T5": ([{"at_sec":6,"pkg":"com.moons.litesc","code":600},
         {"at_sec":6,"pkg":"com.moons.litesd","code":267}], 20),
 "T6": ([{"at_sec":6,"pkg":"com.moons.litesc","code":267},
         {"at_sec":12,"pkg":"com.moons.litesc","code":285}], 24),
 "T7": ([{"at_sec":6,"pkg":"com.moons.litesc","code":285,"force_stop":"com.moons.litesc"},
         {"at_sec":6,"pkg":"com.moons.litesd","code":285,"force_stop":"com.moons.litesd"}], 65),
 "T8": ([{"at_sec":6,"pkg":"com.moons.litesc","code":285,"force_stop":"com.moons.litesc"},
         {"at_sec":6,"pkg":"com.moons.litesd","code":285,"force_stop":"com.moons.litesd"},
         {"at_sec":6,"pkg":"com.moons.litese","code":285,"force_stop":"com.moons.litese"}], 75),
}

key = sys.argv[1]
events, dur = SCEN[key]
sc = {"duration": dur, "cfg": CFG, "ps": PS, "clones": CL, "stdin": "1\n", "events": events}
r = sim.run_scenario(sc)
log = r["log"]
print("=== %s (REJOIN=%s) ===" % (key, os.environ["REJOIN_PATH"]))
print(log[-2500:])
def L(p): return log.count("LAUNCH "+p+" [rejoin")
print("--- counts ---")
for p in ("com.moons.litesc","com.moons.litesd","com.moons.litese"):
    print("  %s relaunch=%d halted=%s" % (p, L(p), ("HALT "+p) in log))
