-- ============================================================
-- Limbo Rejoin
-- baseline: PS Hopper Tool v3.0 (Termux + root Android, single file)
-- UI: box rapi (title di dalam), menu [n] - item, English
-- Detect: logcat disconnect code -> halt on ban, rejoin otherwise
-- ============================================================

-- ---- single-instance guard ----------------------------------
-- Running two copies makes them fight (each force-stops the other's
-- clients -> endless "dead -> relaunch" and double hops). Kill any old
-- copy of this script before continuing.
--
-- BUGFIX: this used to read the pid via io.popen("cat /proc/self/stat"),
-- but io.popen runs a CHILD SHELL, so /proc/self is the shell, not lua.
-- The lock therefore stored a dead/wrong pid (verified on device: popen
-- gave 14117 while the real lua pid was 14106), the "is old alive?" check
-- never matched, and TWO tools could run at once -> they force-stopped each
-- other's clients -> the cascade. io.open("/proc/self/stat") reads the
-- interpreter's OWN pid, which is correct.
local LOCK_FILE = "/sdcard/.limbo_rejoin.pid"
do
    local mypid = nil
    local f = io.open("/proc/self/stat", "r")
    if f then local t = f:read("*l"); f:close(); mypid = t and t:match("^(%d+)") end
    if mypid then
        local old = nil
        local lf = io.open(LOCK_FILE, "r")
        if lf then old = tonumber(lf:read("*l")); lf:close() end
        if old and old ~= tonumber(mypid) then
            -- is the old pid still a running rejoin script?
            local alive = false
            local c = io.open("/proc/" .. old .. "/cmdline", "r")
            if c then
                local cl = c:read("*a") or ""; c:close()
                if cl:match("rejoin") then alive = true end
            end
            if alive then
                os.execute("kill -9 " .. old .. " 2>/dev/null")
                os.execute("sleep 1")
            end
        end
        local w = io.open(LOCK_FILE, "w")
        if w then w:write(mypid .. "\n"); w:close() end
    end
end

local CFG_PATH = "/sdcard/limbo_rejoin.cfg"
local CONF_DIR = "/sdcard/limbo_configs"
local PS_FILE  = "/sdcard/private_servers.txt"
local LOG_FILE = "/sdcard/limbo_rejoin.log"
local DEF_PREFIX = "com.roblox"

-- disconnect codes
local STOP_CODES  = { [267] = true, [600] = true }         -- ban: never rejoin
local HEARTBEAT_GRACE = 45                                  -- don't call a client "dead" before it has booted
local FAIL_LIMIT  = 3                                       -- relaunch failures
local FAIL_WINDOW = 60                                      -- within this many seconds -> halt

-- lebar tampilan. stty size = paling andal (baca tty asli).
-- fallback 50 seperti baseline (bukan 60) supaya tidak wrap di terminal sempit.
local function detect_cols()
    local env = os.getenv("LIMBO_WIDTH") or os.getenv("COLUMNS")
    if env then local e = tonumber(env); if e and e >= 20 then return e end end
    local h = io.popen("stty size 2>/dev/null")
    if h then
        local t = h:read("*l"); h:close()
        if t then local c = tonumber(t:match("(%d+)%s*$")); if c and c >= 20 then return c end end
    end
    local h2 = io.popen("stty -F /dev/tty size 2>/dev/null")
    if h2 then
        local t = h2:read("*l"); h2:close()
        if t then local c = tonumber(t:match("(%d+)%s*$")); if c and c >= 20 then return c end end
    end
    local h3 = io.popen("tput cols 2>/dev/null")
    if h3 then local c = tonumber(h3:read("*l")); h3:close(); if c and c >= 20 then return c end end
    return 50
end
local W  = detect_cols()
local IN = W - 2

-- ============================================================
-- CONFIG
-- ============================================================
local function split(s, sep)
    local t = {}
    for part in (s .. sep):gmatch("(.-)" .. sep) do table.insert(t, part) end
    return t
end
local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function load_cfg()
    local cfg = {
        launch_delay = 10,
        place_id = "", autoexec_path = "", autoexec_script = "",
        prefix = DEF_PREFIX, ps = {}, pkgs = {},
        mode = "hopper",
    }
    local f = io.open(CFG_PATH, "r")
    if not f then
        return cfg, false
    end
    for line in f:lines() do
        local lv = trim(line)
        if lv ~= "" and not lv:match("^#") then
            local k, v = lv:match("^([%w_]+)%s*=%s*(.*)$")
            if k then
                if k == "prefix" then
                    if v ~= "" then cfg.prefix = v end
                elseif k == "launch_delay" then cfg.launch_delay = tonumber(v) or cfg.launch_delay
                elseif k == "place_id" then cfg.place_id = v
                elseif k == "mode" then
                    if v == "hopper" or v == "rejoin" then cfg.mode = v end
                elseif k == "autoexec_path" then cfg.autoexec_path = v
                elseif k == "autoexec_script" then cfg.autoexec_script = v
                elseif k == "pkg" then
                    local fl = split(v, ",")
                    local name = trim(fl[1] or "")
                    if name ~= "" then
                        -- ps is field 6+ joined back (it may contain commas -> saved as ';')
                        local ps_parts = {}
                        for i = 6, #fl do table.insert(ps_parts, fl[i]) end
                        local ps_val = table.concat(ps_parts, ","):gsub(";", ",")
                        cfg.pkgs[name] = {
                            selected  = tonumber(fl[2]) or 1,
                            on        = tonumber(fl[3]) or 1,
                            heartbeat = tonumber(fl[4]) or 10,
                            rejoin    = tonumber(fl[5]) or 0,
                            ps        = trim(ps_val),
                        }
                    end
                end
            end
        end
    end
    f:close()
    if cfg.prefix == "" then cfg.prefix = DEF_PREFIX end
    return cfg, true
end

local function save_cfg(cfg)
    local f = io.open(CFG_PATH, "w")
    if not f then return false end
    f:write("# Limbo Rejoin -- editable by hand or via menu\n")
    f:write("launch_delay=" .. cfg.launch_delay .. "\n")
    f:write("place_id=" .. cfg.place_id .. "\n")
    f:write("autoexec_path=" .. cfg.autoexec_path .. "\n")
    f:write("autoexec_script=" .. cfg.autoexec_script .. "\n")
    f:write("prefix=" .. cfg.prefix .. "\n")
    f:write("mode=" .. (cfg.mode or "hopper") .. "\n")
    for name, p in pairs(cfg.pkgs) do
        local ps_str = (p.ps or ""):gsub(",", ";")
        f:write(string.format("pkg=%s,%d,%d,%d,%d,%s\n",
            name, p.selected, p.on, p.heartbeat, p.rejoin, ps_str))
    end
    f:close()
    return true
end

-- ---- config presets -----------------------------------------
-- Save the ENTIRE current config under a name, and load it back later.
-- Files live in CONF_DIR, one per preset:  /sdcard/limbo_configs/<name>.cfg
local function preset_path(name)
    name = tostring(name or ""):gsub("[^%w_%-]", "")
    if name == "" then return nil end
    return CONF_DIR .. "/" .. name .. ".cfg"
end

local function save_preset(cfg, name)
    local path = preset_path(name)
    if not path then return false end
    os.execute("mkdir -p " .. CONF_DIR .. " 2>/dev/null")
    local f = io.open(path, "w")
    if not f then return false end
    f:write("# Limbo preset: " .. name .. "\n")
    f:write("saved=" .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    f:write("launch_delay=" .. cfg.launch_delay .. "\n")
    f:write("place_id=" .. cfg.place_id .. "\n")
    f:write("autoexec_path=" .. cfg.autoexec_path .. "\n")
    f:write("autoexec_script=" .. cfg.autoexec_script .. "\n")
    f:write("prefix=" .. cfg.prefix .. "\n")
    f:write("mode=" .. (cfg.mode or "hopper") .. "\n")
    for name2, p in pairs(cfg.pkgs) do
        local ps_str = (p.ps or ""):gsub(",", ";")
        f:write(string.format("pkg=%s,%d,%d,%d,%d,%s\n",
            name2, p.selected, p.on, p.heartbeat, p.rejoin, ps_str))
    end
    f:close()
    return true
end

local function list_presets()
    local out = {}
    local h = io.popen("ls " .. CONF_DIR .. "/*.cfg 2>/dev/null")
    if not h then return out end
    for line in h:lines() do
        local n = line:match("([^/]+)%.cfg$")
        if n then table.insert(out, n) end
    end
    h:close()
    table.sort(out)
    return out
end

-- load a preset: copy it over the live config, then re-read it into cfg
local function load_preset(cfg, name)
    local path = preset_path(name)
    if not path then return false end
    local f = io.open(path, "r")
    if not f then return false end
    f:close()
    -- apply preset file -> live config file
    os.execute("cp " .. path .. " " .. CFG_PATH .. " 2>/dev/null")
    -- re-read the live config into the existing cfg table
    local nc = load_cfg()
    cfg.launch_delay = nc.launch_delay
    cfg.place_id = nc.place_id
    cfg.autoexec_path = nc.autoexec_path
    cfg.autoexec_script = nc.autoexec_script
    cfg.prefix = nc.prefix
    cfg.mode = nc.mode
    cfg.pkgs = nc.pkgs
    return true
end

local function delete_preset(name)
    local path = preset_path(name)
    if not path then return false end
    os.execute("rm -f " .. path .. " 2>/dev/null")
    return true
end

-- private server: file is source of truth, auto-written on change
local function load_ps(cfg)
    local f = io.open(PS_FILE, "r")
    if not f then return end
    cfg.ps = {}
    for line in f:lines() do
        local lv = trim(line)
        if lv ~= "" then table.insert(cfg.ps, lv) end
    end
    f:close()
end

local function save_ps(cfg)
    local f = io.open(PS_FILE, "w")
    if not f then return false end
    for _, u in ipairs(cfg.ps) do f:write(u .. "\n") end
    f:close()
    return true
end

-- ============================================================
-- UI
-- ============================================================
local function sleep(s) if s and s > 0 then os.execute("sleep " .. tostring(s)) end end
local function col(c) io.write("\27[" .. c .. "m"); io.flush() end
local function off() io.write("\27[0m"); io.flush() end
local function cls() io.write("\27[2J\27[3J\27[H\27[0m"); io.flush() end
local function strip(s) return (s:gsub("\27%[[%d;]*m", "")) end

-- display width: ASCII only now, so #s is exact
local function _uw(s)
    return #strip(s)
end
local function pad(s, w)
    s = s or ""
    local d = w - #s
    if d > 0 then return s .. string.rep(" ", d) end
    if d < 0 then return s:sub(1, w) end
    return s
end
local function cut(s, m)
    if not s then return "-" end
    if #s <= m then return s end
    return m > 2 and (s:sub(1, m - 2) .. "..") or s:sub(1, m)
end

-- box: plain ASCII borders (safe on any terminal / font width)
local function box_open(title)
    print("+" .. string.rep("-", IN) .. "+")
    if title and title ~= "" then
        col("1;36"); io.write("| " .. pad(title:upper(), IN - 2) .. " |"); off(); print("")
    end
end
local function box_line(t) print("| " .. pad(t or "", IN - 2) .. " |") end
local function box_blank() print("| " .. string.rep(" ", IN - 2) .. " |") end
local function box_close() print("+" .. string.rep("-", IN) .. "+") end

local function head(name)
    cls()
    print("+" .. string.rep("-", IN) .. "+")
    col("1;36"); io.write("| " .. pad("Limbo  >  " .. name, IN - 2) .. " |"); off(); print("")
    print("+" .. string.rep("-", IN) .. "+")
    print("")
end

-- input: /dev/tty dulu (sama seperti baseline), fallback stdin
-- read a line: stdin first (it IS the keyboard when running `lua file.lua`),
-- /dev/tty only as fallback (avoids double-read race on a real terminal).
local function read_line()
    io.flush()
    local r = io.read("*l")
    if r == nil then
        local tty = io.open("/dev/tty", "r")
        if tty then r = tty:read("*l"); tty:close() end
    end
    return r
end

-- PERF: detect whether we are attached to a real terminal. When the tool runs
-- headless (e.g. `... > log 2>&1 < /dev/null` as in _go.sh), there is NO ONE
-- watching the screen, yet the old code still cleared+redrew the whole UI and
-- spawned a `bash` every second for read_key -> pure waste on a loaded device.
local HEADLESS = false
do
    local f = io.open("/dev/tty", "r")
    if f then f:close() else HEADLESS = true end
    -- also treat stdout redirected to a file as headless
    local h = io.popen("test -t 1 && echo tty || echo notty 2>/dev/null")
    if h then local r = (h:read("*a") or ""):gsub("%s", ""); h:close(); if r == "notty" then HEADLESS = true end end
end

-- single key, waits up to t seconds.
--   nil  -> timeout (NO key pressed)  <-- must NOT be treated as Enter
--   ""   -> Enter pressed
--   "x"  -> the key
-- We use the shell exit code: `read -t` returns >128 on timeout, 0 on a real key.
-- PERF: in headless mode there is no keyboard; just sleep the interval without
-- spawning a shell at all (was: a `bash` spawn every single second).
local function read_key(t)
    if HEADLESS then sleep(t or 1); return nil end
    local cmd = "bash -c 'read -t " .. (t or 1) .. " -n 1 k < /dev/tty 2>/dev/null; " ..
                "if [ $? -eq 0 ]; then printf \"K%s\" \"$k\"; else printf __TO__; fi' 2>/dev/null"
    local h = io.popen(cmd)
    if not h then sleep(t or 1); return nil end
    local k = h:read("*a"); h:close()
    if k == nil then return nil end
    k = k:gsub("[\r\n]", "")
    if k == "__TO__" or k == "" then return nil end   -- timeout / no tty
    if k == "K" then return "" end                    -- Enter
    if k:sub(1, 1) == "K" then return k:sub(2) end
    return k
end

-- prompt input dengan pesan (opsional). "!" prefix = error (merah), lain = ok (hijau)
local function prompt(note, label)
    if note then
        if note:sub(1, 1) == "!" then col("31"); print(note:sub(2)); off()
        else col("32"); print(note); off() end
    end
    io.write("? " .. (label or "Select") .. " : "); io.flush()
    local r = read_line()
    if r == nil then return nil end
    return trim(r)
end

local function pause()
    io.write("\n"); col("90"); io.write("[enter]"); off(); io.write(" back..."); io.flush()
    read_line()
end

-- ============================================================
-- SYSTEM (root)
-- ============================================================
local function su_cmd(cmd)
    local h = io.popen("su -c '" .. cmd:gsub("'", "'\\''") .. "' </dev/null 2>&1")
    if not h then return "" end
    local r = h:read("*a"); h:close()
    return strip(r or "")
end
local function su_exec(cmd)
    os.execute("su -c '" .. cmd:gsub("'", "'\\''") .. "' </dev/null >/dev/null 2>&1")
end
local function hlog(msg)
    local f = io.open(LOG_FILE, "a")
    if f then f:write(os.date("%H:%M:%S ") .. msg .. "\n"); f:close() end
end

-- ============================================================
-- RESOURCE (cpu/ram) -- delta sampling, no sleep, cached 2s
-- ============================================================
local _cpu = { pi = 0, pt = 0, pct = 0 }
local function cpu_read()
    local f = io.open("/proc/stat", "r")
    if not f then return _cpu.pct end
    local l = f:read("*l"); f:close()
    if not l then return _cpu.pct end
    local vals = {}
    for v in l:gmatch("%d+") do table.insert(vals, tonumber(v)) end
    local idle  = (vals[4] or 0) + (vals[5] or 0)
    local total = 0
    for _, v in ipairs(vals) do total = total + v end
    if _cpu.pt > 0 and total > _cpu.pt then
        local dt = total - _cpu.pt
        if dt > 0 then
            local p = (1 - (idle - _cpu.pi) / dt) * 100
            if p < 0 then p = 0 elseif p > 100 then p = 100 end
            _cpu.pct = p
        end
    end
    _cpu.pi, _cpu.pt = idle, total
    return _cpu.pct
end

local function ram_read()
    local f = io.open("/proc/meminfo", "r")
    if not f then return nil, nil end
    local mt, ma
    for line in f:lines() do
        mt = mt or line:match("MemTotal:%s+(%d+)")
        ma = ma or line:match("MemAvailable:%s+(%d+)")
        if mt and ma then break end
    end
    f:close()
    if not mt then return nil, nil end
    return tonumber(mt), tonumber(ma)
end

local _res = { t = 0, cpu = 0, used = 0, total = 0 }
local function resources()
    local now = os.time()
    if now - _res.t < 2 and _res.t > 0 then return _res end
    _res.cpu = cpu_read()
    local mt, ma = ram_read()
    if mt then
        _res.total = mt / 1048576
        _res.used  = (mt - (ma or mt)) / 1048576
    end
    _res.t = now
    return _res
end

-- ============================================================
-- DETECTION
-- ============================================================
local function clean_pkg(p)
    if not p then return nil end
    local s = p:gsub("[^%w%._]", "")
    return s ~= "" and s or nil
end
-- PERF: was up to 3 separate su calls (mStable, wm density, wm size).
-- Combined into ONE su call that emits all three values on separate lines.
local function detect_screen()
    local out = su_cmd("dumpsys window | grep mStable | head -1; wm density; wm size")
    local inset = tonumber((out:match("mStable=%[%d+,(%d+)%]")) or "")
    local sw, sh = out:match("(%d+)x(%d+)")
    if not inset or inset == 0 then
        local d = out:match("density[^%d]*(%d+)") or out:match("(%d+)%s*$")
        inset = d and math.ceil(24 * tonumber(d) / 160) or 48
    end
    if not sw or not sh then return nil, nil, inset end
    sw, sh = tonumber(sw), tonumber(sh)
    if not sw or not sh then return nil, nil, inset end
    return math.min(sw, sh), math.max(sw, sh), inset
end

local _pkg_cache, _pkg_t = nil, 0
local _pkg_src = "?"   -- for display/debug: which sources contributed
local function parse_pkg_lines(r)
    local out = {}
    for line in r:gmatch("[^\r\n]+") do
        local p = line:match("package:(.+)")
        if p then p = clean_pkg(p); if p then table.insert(out, p) end end
    end
    return out
end
-- union of plain pm AND su pm (clone apps can be hidden from unprivileged pm)
local function all_packages()
    local now = os.time()
    if _pkg_cache and (now - _pkg_t) < 8 then return _pkg_cache end
    local seen, out = {}, {}
    local srcs = {}
    local function add(list, tag)
        if #list == 0 then return end
        srcs[#srcs + 1] = tag
        for _, p in ipairs(list) do
            if not seen[p] then seen[p] = true; table.insert(out, p) end
        end
    end
    -- 1) plain pm
    local h = io.popen("pm list packages 2>/dev/null")
    if h then add(parse_pkg_lines(h:read("*a") or ""), "pm"); h:close() end
    -- 2) su pm (covers clone/hidden apps)
    local h2 = io.popen("su -c 'pm list packages' </dev/null 2>/dev/null")
    if h2 then add(parse_pkg_lines(h2:read("*a") or ""), "su"); h2:close() end
    -- 3) last resort: full path via su
    if #out == 0 then
        local h3 = io.popen("su -c '/system/bin/pm list packages' </dev/null 2>/dev/null")
        if h3 then add(parse_pkg_lines(h3:read("*a") or ""), "su-path"); h3:close() end
    end
    table.sort(out)
    _pkg_src = (#srcs > 0) and table.concat(srcs, "+") or "none"
    _pkg_cache, _pkg_t = out, now
    return out
end
local function drop_cache() _pkg_cache, _pkg_t = nil, 0 end

-- filter starts-with (hard): only packages beginning with the prefix
local function detect(prefix, force)
    if force then drop_cache() end
    if not prefix or prefix == "" then return {} end
    local all = all_packages()
    local out = {}
    for _, p in ipairs(all) do
        if p:sub(1, #prefix) == prefix then table.insert(out, p) end
    end
    table.sort(out)
    return out
end

-- FIX: the detector cadence follows the HEARTBEAT, not a fixed 5s. A 5s scan
-- spawns `su` + reads logcat 12x/min (heavy on a 4GB device, and it fired the
-- relaunch within seconds of a 285 -> "instant detection" avalanche). With this
-- the scan runs once per heartbeat (e.g. heartbeat=90 -> detect every 90s).
local function scan_interval(cfg, names)
    local iv = nil
    for _, name in ipairs(names) do
        local p = cfg.pkgs[name]
        local hb = p and p.heartbeat or 0
        if hb and hb > 0 and (not iv or hb < iv) then iv = hb end
    end
    if not iv then iv = 10 end     -- no heartbeat set -> light 10s default
    if iv < 5 then iv = 5 end      -- never hammer faster than 5s
    if iv > 300 then iv = 300 end  -- sanity cap
    return iv
end

-- pkg -> pid AND recent disconnects in ONE su call (halves process spawns)
-- returns pm (pkg->pid), dis (pkg->{code,key})
--
-- PERF: read only the logcat lines that are NEW since the previous scan
-- (`logcat -d -T <ts>`) instead of re-dumping the last 2000 every time.
-- Measured on device: -t 2000 = ~92ms/call, -T incremental = ~16ms/call.
-- Safety: the marker is advanced with an 8s overlap, and the disc_key dedup
-- in the caller ignores re-read lines, so a disconnect can never slip through
-- the gap between two scans.
local _log_ts = nil
local function scan_state(names)
    local pm, dis = {}, {}
    if #names == 0 then return pm, dis end
    local logpart
    if _log_ts then
        logpart = "logcat -d -T '" .. _log_ts .. "' -s Roblox 2>/dev/null"
    else
        logpart = "logcat -d -t 300 -s Roblox 2>/dev/null"   -- first scan: small tail only
    end
    -- advance the marker to NOW minus the overlap, BEFORE the read, so events
    -- that happen while this su call runs are still caught by the next scan.
    _log_ts = os.date("%m-%d %H:%M:%S.000", os.time() - 8)
    local cmd = "for p in " .. table.concat(names, " ") .. "; do echo \"P $p=$(pidof $p)\"; done; " ..
        logpart .. " | grep -aE 'disconnect with reason|game_join_loadtime' | tail -60"
    local out = su_cmd(cmd)
    if out == "" then return pm, dis, {} end

    local pid2pkg = {}
    local loglines = {}
    for line in out:gmatch("[^\n]+") do
        local p, pid = line:match("^P (%S+)=(%d+)")
        if p then
            pm[p] = tonumber(pid); pid2pkg[tonumber(pid)] = p
        elseif line:match("%d+:%d+:%d+%.%d+") then
            table.insert(loglines, line)
        end
    end
    local uid = {}   -- pkg -> roblox userid
    for _, line in ipairs(loglines) do
        local pid  = line:match("^%d+-%d+%s+%d+:%d+:%d+%.%d+%s+(%d+)")
        local code = line:match("reason:%s*(%d+)")
        local key  = line:match("(%d%d%d%d%-%d%d%-%d%dT[%d:%.]+Z)")
        local u    = line:match("userid:%s*(%d+)")
        local pkg  = pid and pid2pkg[tonumber(pid)]
        if pkg then
            if code then dis[pkg] = { code = tonumber(code), key = key or line } end
            if u then uid[pkg] = u end
        end
    end
    return pm, dis, uid
end

-- username per package: read from each clone's prefs.xml (root). Always present.
local function read_usernames(names)
    if #names == 0 then return {} end
    local parts = {}
    for _, pk in ipairs(names) do
        local cmd = 'f=/data/data/' .. pk .. '/shared_prefs/prefs.xml; if [ -f "$f" ]; then '
        cmd = cmd .. 'u=$(sed -n ' .. "'" .. 's/.*name="username">\\([^<]*\\)<.*/\\1/p' .. "'" .. ' "$f" | head -1); '
        cmd = cmd .. 'd=$(sed -n ' .. "'" .. 's/.*name="displayName">\\([^<]*\\)<.*/\\1/p' .. "'" .. ' "$f" | head -1); '
        cmd = cmd .. 'echo "U ' .. pk .. '|$u|$d"; fi'
        parts[#parts + 1] = cmd
    end
    local out = su_cmd(table.concat(parts, '; '))
    local res = {}
    for line in out:gmatch("[^\n]+") do
        local pk, u, d = line:match("^U ([^|]+)|([^|]*)|(.*)$")
        if pk then
            res[pk] = { username = (u ~= "" and u or nil), display = (d ~= "" and d or nil) }
        end
    end
    return res
end

-- cached usernames for menu display (1 su call / 20s)
local _info = { t = 0, users = {} }
local function user_info(names)
    local now = os.time()
    if now - _info.t >= 20 then
        _info.users = read_usernames(names)
        _info.t = now
    end
    return _info.users
end

-- ============================================================
-- LAYOUT
-- ============================================================
-- PERF: was 6 separate `su -c` spawns (chmod + 4x sed + chmod). Each su spawn
-- is ~26ms on this device, so ~156ms per package. Now ONE su call runs the
-- whole chain -> ~30ms. Layout is only applied at launch, but on a 4-6 client
-- start that is 6x130ms of pure process churn we no longer pay.
local function apply_layout(pkg, L, T, R, B)
    local pref = "/data/data/" .. pkg .. "/shared_prefs/" .. pkg .. "_preferences.xml"
    local keys = {
        { "app_cloner_current_window_left", L },
        { "app_cloner_current_window_top", T },
        { "app_cloner_current_window_right", R },
        { "app_cloner_current_window_bottom", B },
    }
    local parts = { "chmod 666 " .. pref }
    for _, f in ipairs(keys) do
        -- sed pattern: match name="KEY" value="<anything>" and replace value.
        -- NOTE: exactly two backslashes before the quote (Lua \" -> shell \")
        local pat = 's/name=\"' .. f[1] .. '\" value=\"[^\"]*\"/name=\"' .. f[1] .. '\" value=\"' .. f[2] .. '\"/g'
        parts[#parts + 1] = "sed -i '" .. pat .. "' " .. pref
    end
    parts[#parts + 1] = "chmod 444 " .. pref
    su_exec(table.concat(parts, "; "))
end

local function grid_bounds(i, n, sw, sh, inset)
    if n == 1 then return 0, 0, sw, sh end
    local gh = math.floor((sh - inset) / n)
    local row = i - 1
    return 0, (row * gh) + inset, sw, ((row + 1) * gh) + inset
end

-- ============================================================
-- LAUNCH (always force-stop first, then start)
-- ============================================================
local function build_intent(pkg, ps_url, place_id)
    if ps_url and ps_url ~= "" then
        -- DIRECT roblox:// deep link. Opening the https share URL first goes
        -- through the browser/chooser (an extra app steals foreground -> the
        -- OTHER clients lose their surface and auto-leave ~15s later). The
        -- roblox://navigation/share_links form lands in the client directly.
        local code = ps_url:match("code=([%w]+)")
        local typ  = ps_url:match("type=(%w+)") or "Server"
        if code then
            return "intent://navigation/share_links?code=" .. code .. "&type=" .. typ ..
                "#Intent;scheme=roblox;package=" .. pkg .. ";action=android.intent.action.VIEW;end"
        end
        local dp = ps_url:match("^intent://(.-)#Intent") or ps_url:gsub("^https?://", "")
        return "intent://" .. dp .. "#Intent;scheme=roblox;package=" .. pkg .. ";action=android.intent.action.VIEW;end"
    end
    if place_id and place_id ~= "" then
        return "intent://experiences/start?placeId=" .. place_id ..
            "#Intent;scheme=roblox;package=" .. pkg .. ";action=android.intent.action.VIEW;end"
    end
    return nil
end
-- CASCADE FIX (per-app): the relaunch only ever touches the target app.
-- We deliberately do NOT stop services in other clones anymore: that was a
-- cross-app poke (not "per app") and did not help. Serialization (one
-- relaunch per cycle, in the monitor loop) is what keeps the device calm.
-- Cold start (force-stop + am start deep link) is KEPT: it is required to
-- actually enter a game (warm start lands on Home and never joins).
local ACTIVE_NAMES = nil   -- set by screen_start

local function launch(pkg, ps_url, place_id, reason, no_stop)
    local intent = build_intent(pkg, ps_url, place_id)
    if not intent then hlog("SKIP " .. pkg); return false end
    if not no_stop then
        su_exec("am force-stop " .. pkg .. "; sleep 1; am start --user 0 \"" .. intent .. "\"")
    else
        su_exec('am start --user 0 "' .. intent .. '"')
    end
    hlog("LAUNCH " .. pkg .. " [" .. (reason or "join") .. "]")
    return true
end

-- ============================================================
-- LISTS
-- ============================================================
local function active_list(cfg)
    -- a selected package IS active (no separate on/off switch)
    local out = {}
    for name, p in pairs(cfg.pkgs) do
        if p.selected == 1 then table.insert(out, name) end
    end
    table.sort(out); return out
end
local function selected_list(cfg)
    local out = {}
    for name, p in pairs(cfg.pkgs) do
        if p.selected == 1 then table.insert(out, name) end
    end
    table.sort(out); return out
end
local function ensure_pkg(cfg, name)
    cfg.pkgs[name] = cfg.pkgs[name] or { selected = 1, on = 1, heartbeat = 10, rejoin = 0, ps = "" }
    return cfg.pkgs[name]
end

-- range input: "1,2,3" / "1-10" / "2,5-8" / "1 2 3" / "2 - 7" / "1;4;7"
-- (this block used to be defined TWICE -- the first copy was dead code that
--  Lua silently shadowed. Removed the duplicate; kept the token-based parser.)
-- true if the input means "all servers" (empty, all, a, *, -1)
local function is_all_input(r)
    if r == nil then return false end
    local l = r:lower():gsub("%s", "")
    return l == "" or l == "all" or l == "a" or l == "*" or l == "semua" or l == "-"
end

-- parse "1" / "1,4,7" / "1-5" / "1-3,7,10-12" / "1 2 3" into a sorted unique list.
-- Ranges may appear anywhere in the string.
local function parse_range(input, max)
    local sel, seen = {}, {}
    local function add(v)
        v = tonumber(v)
        if v and v >= 1 and v <= max and not seen[v] then
            seen[v] = true; table.insert(sel, v)
        end
    end
    -- normalise: strip spaces so "2 - 7" and "2-7" behave the same
    local norm = tostring(input):gsub("%s+", "")
    -- walk the string: each token is either "A-B" (range) or "A" (single)
    for tok in norm:gmatch("[^,;]+") do
        local a, b = tok:match("^(%d+)%s*%-%s*(%d+)$")
        if a and b then
            local lo, hi = tonumber(a), tonumber(b)
            if lo > hi then lo, hi = hi, lo end
            for i = lo, hi do add(i) end
        else
            -- token may still contain digits (e.g. "3abc") -> take the number
            for n in tok:gmatch("(%d+)") do add(n) end
        end
    end
    table.sort(sel)
    return sel
end

-- resolve a package's assigned PS indexes. "" or invalid => all servers
local function ps_list_of(p, cfg)
    local idxs = parse_range(p.ps or "", #cfg.ps)
    if #idxs == 0 then
        for i = 1, #cfg.ps do table.insert(idxs, i) end
    end
    return idxs
end

-- short label for the ps column, e.g. "all" or "1,2" or "1-3"
local function ps_label(p, cfg)
    local idxs = ps_list_of(p, cfg)
    if #idxs == 0 then return "?" end
    if #idxs == 1 then return tostring(idxs[1]) end
    local contiguous = true
    for i = 2, #idxs do if idxs[i] ~= idxs[i-1] + 1 then contiguous = false end end
    if contiguous then return idxs[1] .. "-" .. idxs[#idxs] end
    return table.concat(idxs, ",")
end

local function fmt_res()
    local r = resources()
    return string.format("CPU %-6s used     RAM %.1f / %.1f GB",
        string.format("%.1f%%", r.cpu), r.used, r.total)
end

-- ============================================================
-- SCREENS (forward declare)
-- ============================================================
local screen_start, screen_rejoin, screen_prefix, screen_packages, screen_server, screen_config

-- ---- MAIN ----
local function screen_menu(cfg)
    local note
    while true do
        local _det = detect(cfg.prefix)
        local sel = selected_list(cfg)
        head("Main")

        box_open("resource")
        box_line(fmt_res())
        box_close()
        print("")

        box_open("selected (" .. #sel .. ")")
        if #sel == 0 then
            box_line("(none -- open [4] Packages to pick)")
        else
            local users = user_info(sel)
            for _, name in ipairs(sel) do
                local p = cfg.pkgs[name]
                local usr = users[name] and (users[name].username or users[name].display)
                local u = usr and (" (" .. cut(usr, 14) .. ")") or ""
                local srv = " [Server" .. ps_label(p, cfg) .. "]"
                local line = cut(name, 18) .. u .. srv
                box_line(line)
            end
        end
        box_close()
        print("")

        print("Main Menu:")
        print("  1. Start")
        print("  2. Rejoin")
        print("  3. Prefix")
        print("  4. Packages")
        print("  5. Server")
        print("  6. Config")
        print("  0. Exit")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return "exit" end
        if c == "1" then
            -- quick start with the last used mode
            screen_start(cfg, cfg.mode or "hopper")
        elseif c == "2" then
            -- Rejoin: choose the mode first
            head("Rejoin  >  mode")
            print("  1. Mode Hopper   (rotate private server every rejoin)")
            print("  2. Mode Rejoin   (stay on the same private server)")
            print("  0. Back")
            print("")
            local m = prompt(nil, "mode (1/2)")
            if m == "1" then cfg.mode = "hopper"; save_cfg(cfg); screen_rejoin(cfg, "hopper")
            elseif m == "2" then cfg.mode = "rejoin"; save_cfg(cfg); screen_rejoin(cfg, "rejoin") end
        elseif c == "3" then screen_prefix(cfg)
        elseif c == "4" then screen_packages(cfg)
        elseif c == "5" then screen_server(cfg)
        elseif c == "6" then screen_config(cfg)
        else note = "!invalid choice" end
    end
end


-- ---- START ----
local function fmt_clock(sec)
    return string.format("%02d:%02d:%02d",
        math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
end

-- how long a package has been on its current PS (like baseline fmt_elapsed)
local function fmt_elapsed(sec)
    if not sec or sec < 0 then sec = 0 end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local ss = sec % 60
    if h > 0 then return string.format("%dh %dm", h, m)
    elseif m > 0 then return string.format("%dm %ds", m, ss)
    else return string.format("%ds", ss) end
end

-- record a package ENTERING a PS index. Closes the previous visit
-- (accumulating its seconds) and opens a new one. Mirrors baseline:
--   - per-PS elapsed ACCUMULATES across visits
--   - per-PS hops COUNTS visits
--   - joined is OVERWRITTEN with the latest visit time
local function enter_ps(s, ps_idx, now)
    if s.cur_ps and s.ps_hist[s.cur_ps] then
        local h = s.ps_hist[s.cur_ps]
        h.sec = h.sec + (now - s.joined)
    end
    s.cur_ps = ps_idx
    s.joined = now
    local h = s.ps_hist[ps_idx] or { sec = 0, hops = 0, joined = now }
    h.hops = h.hops + 1
    h.joined = now
    s.ps_hist[ps_idx] = h
end

-- relaunch one package. scheduled=true means hopper timer (not a failure)
-- Per-app: only the target package is touched (no cross-app pokes).
local function relaunch(s, _p, cfg, name, reason, scheduled, now)
    local pi = (s.plist and s.plist[s.pptr]) or 1
    launch(name, cfg.ps[pi] or cfg.place_id or "", cfg.place_id, reason)
    s.born = now            -- (re)start the boot-grace window
    s.status = reason
    if not scheduled then
        table.insert(s.fails, now)
        while #s.fails > 0 and (now - s.fails[1]) > FAIL_WINDOW do table.remove(s.fails, 1) end
        if #s.fails >= FAIL_LIMIT then
            s.halted = true
            s.halt_code = "retry x" .. #s.fails
            hlog("HALT " .. name .. " (" .. #s.fails .. " fails in " .. FAIL_WINDOW .. "s)")
        end
    end
end

screen_start = function(cfg, mode)
    mode = mode or cfg.mode or "hopper"
    local names = active_list(cfg)
    if #names == 0 then
        head("Start"); col("31"); print("no package enabled."); off()
        print("turn it on in menu [2] Rejoin."); pause(); return
    end
    if #cfg.ps == 0 and cfg.place_id == "" then
        head("Start"); col("31"); print("no private server / place_id."); off()
        print("set it in menu [5] Server."); pause(); return
    end
    local sw, sh, off_ = detect_screen()
    if not sw then
        head("Start"); col("31"); print("failed to read screen size."); off(); pause(); return
    end

    ACTIVE_NAMES = names

    if cfg.autoexec_path ~= "" and cfg.autoexec_script ~= "" then
        su_exec("mkdir -p " .. (cfg.autoexec_path:match("^(.*)/") or "."))
        su_exec("cp " .. cfg.autoexec_path .. " " .. cfg.autoexec_path .. ".bak 2>/dev/null")
        local af = io.open(cfg.autoexec_path, "w")
        if af then af:write(cfg.autoexec_script); af:close(); su_exec("chmod 644 " .. cfg.autoexec_path) end
    end

    local st = {}
    local t0 = os.time()
    local lstat = {}   -- name -> "wait" | "starting" | "done"

    -- draw the launch screen: the package being launched shows "starting...",
    -- the ones still waiting for their turn show a live countdown.
    local function draw_launch(active_idx, wait_next)
        head("Start [" .. mode .. "]  (starting)")
        box_open("resource"); box_line(fmt_res()); box_close()
        print("")
        box_open("package")
        for i, name in ipairs(names) do
            local txt
            if lstat[name] == "done" then
                txt = "launched"
            elseif i == active_idx then
                txt = "starting..."
            else
                local w = wait_next + (i - active_idx - 1) * cfg.launch_delay
                if w < 0 then w = 0 end
                txt = "wait " .. w .. "s"
            end
            box_line(string.format("%-22s %s", cut(name, 22), txt))
        end
        box_close()
        print("")
        col("90"); print("launching clients..."); off()
        io.flush()
    end

    for _, name in ipairs(names) do lstat[name] = "wait" end

    for i, name in ipairs(names) do
        local p = cfg.pkgs[name]
        local L, T, R, B = grid_bounds(i, #names, sw, sh, off_)
        lstat[name] = "starting"
        draw_launch(i, cfg.launch_delay)
        -- CANDIDATE FIX: do NOT force-stop on start. force-stop kills the
        -- process and the cloner re-layouts -> cascade. Only cold-launch
        -- packages that are not already running; a running one is left alone
        -- (pressing Start no longer re-launches healthy clients).
        local alive = (su_cmd("pidof " .. name) ~= "")
        apply_layout(name, L, T, R, B)
        local plist = ps_list_of(p, cfg)
        if mode == "rejoin" then plist = { plist[1] } end   -- stay on ONE server
        if not alive then
            launch(name, cfg.ps[plist[1]] or cfg.place_id or "", cfg.place_id, "start", true)
        else
            hlog("START-SKIP " .. name .. " (already running)")
        end
        st[name] = {
            hb_next = os.time() + p.heartbeat,
            rj_next = os.time() + (p.rejoin * 60),   -- minutes -> seconds
            born    = os.time(),
            joined  = os.time(),
            hops    = 0,
            status  = "join",
            plist = plist,
            pptr = 1,
            ps_hist = {},          -- ps_idx -> { sec, hops, joined }
            cur_ps = nil,
            halted = false, halt_code = nil,
            fails = {},
            disc_key = nil,
        }
        enter_ps(st[name], plist[1], os.time())
        lstat[name] = "done"
        if i < #names then
            -- countdown until the next package starts
            local d = cfg.launch_delay
            while d > 0 do
                draw_launch(i, d)
                sleep(1)
                d = d - 1
            end
        end
    end

    -- IMPORTANT: timers were armed when each package launched, but the monitor
    -- loop only starts after the LAST launch (+ launch_delay each). By then the
    -- heartbeat timer is already expired and fires immediately -> false
    -- "dead -> relaunch". Re-arm every timer from the moment monitoring begins.
    local mon_start = os.time()
    for _, name in ipairs(names) do
        local s = st[name]; local p = cfg.pkgs[name]
        -- only re-arm the HEARTBEAT cadence from monitor start. rj_next/joined/
        -- born keep their per-package launch times, so hops stay staggered by
        -- launch_delay (same as the initial launch) instead of firing together.
        s.hb_next = mon_start + p.heartbeat
        s.disc_key = nil
    end

    local quit = false
    local pm, dis = {}, {}
    local next_scan = 0
    local primed = false
    local last_status = 0
    local SCAN_SEC = scan_interval(cfg, names)   -- FIX: follow heartbeat, not 5s
    while not quit do
        local now = os.time()
        if now >= next_scan then
            next_scan = now + SCAN_SEC
            pm, dis = scan_state(names)   -- ONE su call: pids + disconnect codes
            -- first scan: baseline any stale disconnect codes still in the
            -- logcat buffer so we don't relaunch on an OLD session's code.
            if not primed then
                primed = true
                for _, name in ipairs(names) do
                    if dis[name] then st[name].disc_key = dis[name].key end
                end
            end
            -- offline monitor: one STATUS line per package every 60s
            if now - last_status >= 60 then
                last_status = now
                for _, name in ipairs(names) do
                    local s = st[name]
                    local cur = s.plist[s.pptr] or 1
                    local txt
                    if s.halted then txt = "HALT " .. (s.halt_code or "")
                    elseif dis[name] then txt = "code " .. dis[name].code
                    elseif pm[name] then txt = "alive"
                    else txt = "dead" end
                    hlog(string.format("STATUS %s ps%d %s up=%s hops=%d next_hop=%ds",
                        name, cur, txt, fmt_elapsed(now - s.joined), s.hops,
                        math.max(0, s.rj_next - now)))
                end
            end
        end

        -- PERF: only redraw when someone is actually watching (a real tty).
        -- Headless runs skip the whole clear+repaint every second.
        if not HEADLESS then
        head("Start [" .. mode .. "]  (" .. fmt_clock(now - t0) .. ")")
        box_open("resource")
        box_line(fmt_res())
        box_close()
        print("")

        box_open("package")
        if mode == "hopper" then
            box_line(string.format("%-2s %-14s %-4s %-5s %-6s %-2s %s",
                "#", "package", "ps", "join", "up", "hp", "st"))
            box_blank()
            for i, name in ipairs(names) do
                local s = st[name]
                local mark
                if s.halted then mark = "HALT " .. (s.halt_code or "")
                elseif dis[name] then mark = "code " .. dis[name].code
                elseif pm[name] then mark = "alive"
                else mark = "dead" end
                local first = true
                for _, ps in ipairs(s.plist) do
                    local h = s.ps_hist[ps]
                    if h then
                        local secs = h.sec
                        if s.cur_ps == ps then secs = secs + (now - h.joined) end
                        box_line(string.format("%-2s %-14s ps%-2d %-5s %-6s %-2d %s",
                            first and tostring(i) or "", first and cut(name, 14) or "",
                            ps, os.date("%H:%M", h.joined),
                            fmt_elapsed(secs), h.hops, first and mark or ""))
                        first = false
                    end
                end
                if i < #names then box_line(string.rep("-", IN - 4)) end
            end
        else
            box_line(string.format("%-2s %-17s %-4s %-6s %s",
                "#", "package", "ps", "up", "status"))
            box_blank()
            for i, name in ipairs(names) do
                local s = st[name]
                local cur = s.plist[s.pptr] or 1
                local mark
                if s.halted then mark = "halted " .. (s.halt_code or "")
                elseif dis[name] then mark = "code " .. dis[name].code
                elseif pm[name] then mark = "alive"
                else mark = "dead" end
                box_line(string.format("%-2d %-17s %-4s %-6s %s",
                    i, cut(name, 17), "ps" .. cur,
                    fmt_elapsed(now - s.joined), mark))
            end
        end
        box_close()
        print("")
        col("90"); print("press y or Enter to stop & close all"); off()
        end

        local k
        if HEADLESS then
            -- PERF: no keyboard here -> don't pay read_key's per-second shell
            -- spawn. Sleep ONE chunk until the next thing that actually matters
            -- (next scan / soonest heartbeat / soonest hop), min 1s max SCAN_SEC.
            local nt = nil
            local function consider(t)
                if t then if not nt or t < nt then nt = t end end
            end
            consider(next_scan)
            for _, nm in ipairs(names) do consider(st[nm].hb_next) end
            if mode == "hopper" then
                for _, nm in ipairs(names) do consider(st[nm].rj_next) end
            end
            local wait = (nt and nt - os.time()) or 5
            if wait < 1 then wait = 1 end
            if wait > SCAN_SEC then wait = SCAN_SEC end
            os.execute("sleep " .. wait)   -- one spawn per wait, not per second
            k = nil
        else
            k = read_key(1)
        end
        if k == "" or (k and k:lower() == "y") then quit = true; break end

        now = os.time()
        -- PERF: collect which packages need a fresh liveness check THIS cycle,
        -- then do ONE su call for all of them (was: one su spawn per package
        -- whose heartbeat fired in the same second -> burst of N spawns).
        local need_fresh = {}
        for _, name in ipairs(names) do
            local s = st[name]; local p = cfg.pkgs[name]
            if not s.halted and p.heartbeat > 0 and now >= s.hb_next then
                need_fresh[name] = true
            end
        end
        local fresh_alive = {}
        if next(need_fresh) then
            local parts = {}
            for name in pairs(need_fresh) do
                parts[#parts + 1] = "echo \"F " .. name .. "=$(pidof " .. name .. ")\""
            end
            local fout = su_cmd(table.concat(parts, "; "))
            for line in fout:gmatch("[^\n]+") do
                local p = line:match("^F (%S+)=(%d+)")
                if p then fresh_alive[p] = true end
            end
        end
        -- CASCADE FIX (per-app, serialized): relaunch AT MOST ONE client per
        -- cycle. The old loop walked all names in one pass and cold-started
        -- every dead client within ~2s ("blind force-stop + am start" storm),
        -- which is the tool's own doing. One cold start at a time keeps the
        -- device calm and treats each app independently (no cross-app pokes).
        local did_relaunch = false
        for _, name in ipairs(names) do
            local s = st[name]; local p = cfg.pkgs[name]
            if s.halted then
                -- isolated: this account is done, others keep running untouched
            else
                local d = dis[name]
                if d and d.key ~= s.disc_key then
                    s.disc_key = d.key
                    if STOP_CODES[d.code] then
                        s.halted = true
                        s.halt_code = "ban " .. d.code
                        hlog("HALT " .. name .. " (code " .. d.code .. ")")
                    elseif not did_relaunch then
                        hlog("disconnect " .. name .. " code " .. d.code .. " -> relaunch")
                        relaunch(s, p, cfg, name, "rejoin " .. d.code, false, now)
                        did_relaunch = true
                        -- same PS: keep accumulating this PS's time (no new visit)
                    end
                elseif mode == "hopper" and p.rejoin > 0 and now >= s.rj_next and not did_relaunch then
                    s.rj_next = now + (p.rejoin * 60)
                    if #s.plist > 1 then
                        s.pptr = s.pptr + 1
                        if s.pptr > #s.plist then s.pptr = 1 end
                    end
                    enter_ps(s, s.plist[s.pptr] or 1, now)   -- close old PS, open new
                    hlog("hop " .. name .. " (ps " .. (s.plist[s.pptr] or 1) .. ")")
                    relaunch(s, p, cfg, name, "hop", true, now)
                    did_relaunch = true
                    s.hops = s.hops + 1
                elseif need_fresh[name] then
                    s.hb_next = now + p.heartbeat
                    -- FIX: do NOT trust the periodic scan snapshot here. With the
                    -- scan cadence tied to the heartbeat (90s) the snapshot can be
                    -- up to 90s old -- e.g. taken during boot when pidof was still
                    -- empty -- producing a FALSE "dead" -> endless relaunch storm
                    -- (and the force-stop+launch then cascades the other clients).
                    -- Do a fresh pidof at the exact decision moment (batched above).
                    local alive_now = fresh_alive[name] or false
                    if not pm[name] and alive_now then
                        hlog("heartbeat " .. name .. " STALE-SNAPSHOT pm=dead real=alive (skipped)")
                    elseif pm[name] and not alive_now then
                        hlog("heartbeat " .. name .. " pm=alive real=dead")
                    end
                    if not alive_now and (now - s.born) >= HEARTBEAT_GRACE and not did_relaunch then
                        hlog("heartbeat " .. name .. " dead -> relaunch")
                        relaunch(s, p, cfg, name, "dead", false, now)
                        s.born = now
                        did_relaunch = true
                        -- same PS: do not reset the PS visit accumulator
                    end
                end
            end
        end
    end

    head("Start")
    print("close all roblox?")
    local r = prompt(nil, "y / n")
    if r and r:lower() == "y" then
        for _, name in ipairs(names) do su_exec("am force-stop " .. name) end
        col("32"); print("all closed."); off()
    end
    if cfg.autoexec_path ~= "" then
        su_exec("cp " .. cfg.autoexec_path .. ".bak " .. cfg.autoexec_path .. " 2>/dev/null")
        su_exec("rm -f " .. cfg.autoexec_path .. ".bak 2>/dev/null")
    end
    pause()
end

-- ---- REJOIN ----
screen_rejoin = function(cfg, mode)
    mode = mode or cfg.mode or "hopper"
    local note
    while true do
        local sel = selected_list(cfg)
        head("Rejoin [" .. mode .. "]")
        col("90"); print("delay " .. cfg.launch_delay .. "s"); off()
        print("")
        box_open("package")
        if #sel == 0 then
            box_line("(none selected -- set it in menu [4] Packages)")
        else
            box_line(string.format("%-3s %-17s %-6s %-8s %s", "#", "package", "beat", "hop/min", "server"))
            box_blank()
            for i, name in ipairs(sel) do
                local p = cfg.pkgs[name]
                box_line(string.format("%-3d %-17s %-6s %-8s ps%s",
                    i, cut(name, 17),
                    p.heartbeat .. "s", p.rejoin > 0 and (p.rejoin .. "m") or "off", ps_label(p, cfg)))
            end
        end
        box_close()
        print("")
        print("  [e] - edit heartbeat / rejoin")
        print("  [p] - set private server (per package)")
        print("  [d] - set delay")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c:lower() == "p" then
            if #sel == 0 then note = "!no package selected"
            elseif #cfg.ps == 0 then note = "!no private server saved"
            else
                head("Rejoin  >  set ps")
                box_open("private server")
                for i, u in ipairs(cfg.ps) do box_line(string.format("%-3d %s", i, cut(u, IN - 7))) end
                box_close()
                print("")
                local n = tonumber(prompt(nil, "package number"))
                if n and n >= 1 and n <= #sel then
                    local name = sel[n]
                    local r = prompt(nil, "ps: 1-" .. #cfg.ps .. " or all")
                    if r ~= nil then
                        local idxs = parse_range(r, #cfg.ps)
                        if is_all_input(r) then
                            cfg.pkgs[name].ps = ""; save_cfg(cfg)
                            note = name .. " -> all"
                        elseif #idxs > 0 then
                            cfg.pkgs[name].ps = r; save_cfg(cfg)
                            note = name .. " -> " .. r
                        else
                            note = "!invalid: 1-" .. #cfg.ps .. ", or all"
                        end
                    end
                else note = "!invalid number" end
            end
        elseif c:lower() == "d" then
            local n = tonumber(prompt(nil, "delay seconds"))
            if n and n >= 0 then cfg.launch_delay = n; save_cfg(cfg); note = "delay " .. n .. "s"
            else note = "!invalid number" end
        elseif c:lower() == "e" then
            if #sel == 0 then note = "!no package selected"
            else
                local n = tonumber(prompt(nil, "package number"))
                if n and n >= 1 and n <= #sel then
                    local name = sel[n]; local p = cfg.pkgs[name]
                    head("Rejoin  >  edit")
                    print("edit  " .. name); print("")
                    io.write("heartbeat (seconds, 0=off)  [" .. p.heartbeat .. "] : "); io.flush()
                    local b = read_line(); b = b and trim(b) or ""
                    if b ~= "" then local bn = tonumber(b); if bn and bn >= 0 then p.heartbeat = bn end end
                    io.write("hop/rejoin (minutes, 0=off)  [" .. p.rejoin .. "] : "); io.flush()
                    local e = read_line(); e = e and trim(e) or ""
                    if e ~= "" then local en = tonumber(e); if en and en >= 0 then p.rejoin = en end end
                    save_cfg(cfg)
                    note = "saved: " .. name
                else note = "!invalid number" end
            end
        else
            note = "!invalid choice"
        end
    end
end

-- ---- PREFIX ---- (set prefix -> langsung detect)
screen_prefix = function(cfg)
    local note
    while true do
        local det = detect(cfg.prefix)
        head("Prefix")
        box_open("prefix")
        box_line(cfg.prefix)
        box_close()
        print("")
        box_open("detected (" .. #det .. ")")
        if #det == 0 then
            box_line("(none -- source: " .. _pkg_src .. ")")
        else
            for i, p in ipairs(det) do box_line(string.format("%-3d %s", i, p)) end
        end
        box_close()
        print("")
        print("  1. set prefix")
        print("  0. back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c == "1" then
            local p = prompt(nil, "new prefix (e.g. com.moons)")
            if p then
                p = p:gsub("%s", "")
                if p == "" then note = "!empty"
                elseif p:match("^[%w_%.]+$") then
                    cfg.prefix = p; save_cfg(cfg); drop_cache()
                    note = "prefix set: " .. p
                else note = "!invalid format" end
            end
        else note = "!invalid choice" end
    end
end

-- ---- PACKAGES ----
screen_packages = function(cfg)
    local note
    while true do
        local det = detect(cfg.prefix)
        head("Packages")
        box_open("detected (" .. #det .. ")")
        if #det == 0 then
            box_line("(none -- prefix: " .. cfg.prefix .. ")")
            box_line("source: " .. _pkg_src)
        else
            for i, p in ipairs(det) do
                local e = cfg.pkgs[p]
                local srv = e and ("  [Server" .. ps_label(e, cfg) .. "]") or ""
                box_line(string.format("[%s] %-3d %-20s%s", (e and e.selected == 1) and "x" or " ", i, cut(p, 20), srv))
            end
        end
        box_close()
        print("")
        print("  [1,2,3] or [1-10] - select these")
        print("  [s] - set server for a package")
        print("  [a] - select all")
        print("  [n] - select none")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c:lower() == "s" then
            if #det == 0 then note = "!no package"
            elseif #cfg.ps == 0 then note = "!no server saved (menu 5)"
            else
                head("Packages  >  set server")
                box_open("server list")
                for i, u in ipairs(cfg.ps) do box_line(string.format("%-3d %s", i, cut(u, IN - 7))) end
                box_close()
                print("")
                local n = tonumber(prompt(nil, "package number"))
                if n and n >= 1 and n <= #det then
                    local name = det[n]
                    local r = prompt(nil, "server: 1-" .. #cfg.ps .. " or all")
                    if r ~= nil then
                        local idxs = parse_range(r, #cfg.ps)
                        if is_all_input(r) then
                            ensure_pkg(cfg, name).ps = ""
                            save_cfg(cfg)
                            note = cut(name, 20) .. " -> all"
                        elseif #idxs > 0 then
                            ensure_pkg(cfg, name).ps = r
                            save_cfg(cfg)
                            note = cut(name, 20) .. " -> " .. r
                        else
                            note = "!invalid: 1-" .. #cfg.ps .. ", or all"
                        end
                    end
                else note = "!invalid number" end
            end
        elseif c:lower() == "a" then
            for _, p in ipairs(det) do ensure_pkg(cfg, p).selected = 1 end
            save_cfg(cfg); note = "all selected"
        elseif c:lower() == "n" then
            for _, p in ipairs(det) do ensure_pkg(cfg, p).selected = 0 end
            save_cfg(cfg); note = "none selected"
        else
            local idxs = parse_range(c, #det)
            if #idxs == 0 then
                note = "!invalid range"
            else
                for _, p in ipairs(det) do ensure_pkg(cfg, p).selected = 0 end
                for _, i in ipairs(idxs) do ensure_pkg(cfg, det[i]).selected = 1 end
                save_cfg(cfg)
                note = #idxs .. " selected"
            end
        end
    end
end

-- ---- SERVER ----
local function valid_ps(l)
    if not l or l == "" then return false end
    if not (l:match("^https?://") or l:match("^intent://")) then return false end
    if not l:lower():match("code=") then return false end
    if l:match("[;|`$%(%){}%z]") then return false end
    return true
end
screen_server = function(cfg)
    local note
    while true do
        head("Server")
        box_open("private server (" .. #cfg.ps .. ")")
        if #cfg.ps == 0 then
            box_line("(empty -- press a to add)")
        else
            for i, u in ipairs(cfg.ps) do
                box_line(string.format("%-3d %s", i, cut(u, IN - 7)))
            end
        end
        box_close()
        print("")
        print("  [a] - add url (auto-saved)")
        print("  [d] - delete")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c:lower() == "a" then
            local raw = prompt(nil, "paste url (space-separated ok)")
            if raw then
                local added, bad = 0, 0
                for tok in raw:gmatch("[^%s,]+") do
                    if valid_ps(tok) then
                        local dup = false
                        for _, x in ipairs(cfg.ps) do if x == tok then dup = true end end
                        if not dup then table.insert(cfg.ps, tok); added = added + 1 end
                    else bad = bad + 1 end
                end
                save_ps(cfg)
                if added > 0 then note = added .. " added"
                elseif bad > 0 then note = "!invalid url (must contain code=)"
                else note = "!already exists" end
            end
        elseif c:lower() == "d" then
            if #cfg.ps == 0 then note = "!none yet"
            else
                local n = tonumber(prompt(nil, "number to delete"))
                if n and n >= 1 and n <= #cfg.ps then
                    table.remove(cfg.ps, n); save_ps(cfg); note = "deleted"
                else note = "!invalid number" end
            end
        else note = "!invalid choice" end
    end
end

-- ---- LAYOUT ----
screen_config = function(cfg)
    local note
    while true do
        local presets = list_presets()
        head("Config")
        col("90"); print("mode: " .. (cfg.mode or "hopper")); off()
        print("")
        box_open("saved presets (" .. #presets .. ")")
        if #presets == 0 then
            box_line("(none -- press s to save current as a preset)")
        else
            for i, n in ipairs(presets) do box_line(string.format("%-3d %s", i, n)) end
        end
        box_close()
        print("")
        print("  [s] - save current config as preset")
        print("  [l] - load a preset")
        print("  [d] - delete a preset")
        print("  [r] - factory reset (restore ALL defaults)")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end

        if c:lower() == "s" then
            local n = prompt(nil, "preset name (e.g. hopper)")
            if n and n ~= "" then
                if save_preset(cfg, n) then note = "saved: " .. n
                else note = "!failed to save" end
            else note = "!empty name" end

        elseif c:lower() == "l" then
            if #presets == 0 then note = "!no preset saved"
            else
                local n = tonumber(prompt(nil, "number to load"))
                if n and n >= 1 and n <= #presets then
                    local name = presets[n]
                    if load_preset(cfg, name) then
                        note = "loaded: " .. name .. " (takes effect on next Start)"
                    else note = "!load failed" end
                else note = "!invalid number" end
            end

        elseif c:lower() == "d" then
            if #presets == 0 then note = "!no preset saved"
            else
                local n = tonumber(prompt(nil, "number to delete"))
                if n and n >= 1 and n <= #presets then
                    delete_preset(presets[n]); note = "deleted: " .. presets[n]
                else note = "!invalid number" end
            end

        elseif c:lower() == "r" then
            head("Config  >  reset")
            col("31"); print("are you sure you want to reset ALL settings?"); off()
            print("")
            print("WARNING: restores EVERYTHING to factory defaults:")
            print("  - package server choices (ps)  -> cleared")
            print("  - package selection            -> removed (main menu empty)")
            print("  - heartbeat -> 10s, rejoin -> off")
            print("  - mode -> hopper, launch_delay -> 10s")
            print("  - prefix -> " .. DEF_PREFIX)
            print("saved presets stay intact (reload them from here).")
            print("")
            local yn = prompt(nil, "y / n")
            if yn and yn:lower() == "y" then
                for _, p in pairs(cfg.pkgs) do
                    p.ps = ""; p.selected = 0; p.on = 1
                    p.heartbeat = 10; p.rejoin = 0
                end
                cfg.launch_delay = 10
                cfg.place_id = ""
                cfg.autoexec_path = ""
                cfg.autoexec_script = ""
                cfg.prefix = DEF_PREFIX
                cfg.mode = "hopper"
                save_cfg(cfg)
                note = "FACTORY RESET done -- restart the tool to see it"
            else
                note = "reset cancelled"
            end

        else note = "!invalid choice" end
    end
end

-- ============================================================
-- MAIN
-- ============================================================
local function main()
    local cfg, existed = load_cfg()
    load_ps(cfg)
    if not existed then save_cfg(cfg) end
    while true do
        if screen_menu(cfg) == "exit" then break end
    end
    cls()
    print("")
    print("bye.")
end

main()
