#!/usr/bin/env python3
"""
Unit tests for pure Lua helper functions in rejoin.lua.
Extracts the functions by name and exercises them in a sandboxed lua run.
No device, instant.

Usage: python3 unit_tests.py [rejoin.lua]
"""
import os, sys, subprocess, re, tempfile, json

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "rejoin.lua")

src = open(SRC).read()

def grab(name):
    """Return the source of a top-level `local function <name>(...)` block."""
    m = re.search(r"local function " + re.escape(name) + r"\s*\(", src)
    if not m: raise SystemExit("function not found: " + name)
    i = src.index("(", m.start())
    # find matching close paren of the param list
    depth = 0
    j = i
    while j < len(src):
        if src[j] == "(": depth += 1
        elif src[j] == ")":
            depth -= 1
            if depth == 0: break
        j += 1
    # find end: next "\nend\n" at column 0
    k = src.index("\nend\n", j)
    return src[m.start():k+5]

FUNCS = ["split", "trim", "clean_pkg", "is_all_input", "parse_range", "fmt_elapsed", "fmt_clock"]
blocks = "\n".join(grab(f) for f in FUNCS)

# A tiny test harness appended in Lua
harness = r'''
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1 else fail=fail+1; print("  [FAIL] "..m) end end

-- parse_range
local r = parse_range("1,2,3", 5); ok(#r==3 and r[1]==1 and r[3]==3, "parse_range 1,2,3")
r = parse_range("2 - 7", 10); ok(#r==6 and r[1]==2 and r[6]==7, "parse_range '2 - 7'")
r = parse_range("1-3,5", 5); ok(#r==4 and r[4]==5, "parse_range 1-3,5")
r = parse_range("9", 5); ok(#r==0, "parse_range out-of-range -> empty")
r = parse_range("3,3,3", 5); ok(#r==1, "parse_range dedup")
r = parse_range("5-2", 10); ok(#r==4 and r[1]==2 and r[4]==5, "parse_range reversed 5-2")
r = parse_range("1;4;7", 10); ok(#r==3, "parse_range semicolon")
r = parse_range("", 5); ok(#r==0, "parse_range empty")

-- is_all_input
ok(is_all_input("")==true, "is_all '' true")
ok(is_all_input("all")==true, "is_all 'all'")
ok(is_all_input("a")==true, "is_all 'a'")
ok(is_all_input("*")==true, "is_all '*'")
ok(is_all_input("semua")==true, "is_all 'semua'")
ok(is_all_input("-")==true, "is_all '-'")
ok(is_all_input("1")==false, "is_all '1' false")
ok(is_all_input("1,2")==false, "is_all '1,2' false")
ok(is_all_input(nil)==false, "is_all nil false")

-- split
local s = split("a,b,c", ","); ok(#s==3 and s[1]=="a" and s[3]=="c", "split basic")
s = split("a,,c", ","); ok(#s==3 and s[2]=="", "split empty field")
s = split("", ","); ok(#s==1, "split empty string")

-- trim
ok(trim("  x  ")=="x", "trim spaces")
ok(trim("")=="", "trim empty")
ok(trim(nil)=="", "trim nil")

-- fmt_elapsed / fmt_clock smoke
ok(type(fmt_elapsed(0))=="string", "fmt_elapsed 0")
ok(type(fmt_elapsed(3661))=="string", "fmt_elapsed 3661")
ok(type(fmt_clock(0))=="string", "fmt_clock 0")

print(string.format("UNIT: %d PASS, %d FAIL", pass, fail))
os_exit = (fail==0)
'''

tmp = tempfile.mktemp(suffix=".lua")
open(tmp, "w").write("os = os or {}\n" + blocks + harness)
r = subprocess.run(["lua5.3", tmp], capture_output=True, text=True)
print(r.stdout, end="")
if r.stderr: print("STDERR:", r.stderr[-800:])
os.remove(tmp)
sys.exit(0 if "0 FAIL" in r.stdout else 1)
