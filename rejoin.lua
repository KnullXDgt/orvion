-- ============================================================
-- Limbo Rejoin
-- baseline: PS Hopper Tool v3.0 (Termux + root Android, single file)
-- UI: box rapi (title di dalam), menu [n] - item, English
-- ============================================================

local CFG_PATH = "/sdcard/limbo_rejoin.cfg"
local PS_FILE  = "/sdcard/private_servers.txt"
local LOG_FILE = "/sdcard/limbo_rejoin.log"
local DEF_PREFIX = "com.roblox"

-- lebar tampilan: ikut terminal, fallback 60
local function term_cols()
    local h = io.popen("tput cols 2>/dev/null || stty size < /dev/tty 2>/dev/null | awk '{print $2}'")
    local v
    if h then v = h:read("*l"); h:close() end
    local n = tonumber(v)
    if not n or n < 56 then n = 60 end
    if n > 110 then n = 110 end
    return n
end
local W  = term_cols()
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
        launch_delay = 10, margin = 24,
        place_id = "", autoexec_path = "", autoexec_script = "",
        prefixes = {}, ps = {}, pkgs = {},
    }
    local f = io.open(CFG_PATH, "r")
    if not f then
        table.insert(cfg.prefixes, DEF_PREFIX)
        return cfg, false
    end
    for line in f:lines() do
        line = trim(line)
        if line ~= "" and not line:match("^#") then
            local k, v = line:match("^([%w_]+)%s*=%s*(.*)$")
            if k then
                if k == "prefix" then
                    if v ~= "" then table.insert(cfg.prefixes, v) end
                elseif k == "launch_delay" then cfg.launch_delay = tonumber(v) or cfg.launch_delay
                elseif k == "margin" then cfg.margin = tonumber(v) or cfg.margin
                elseif k == "place_id" then cfg.place_id = v
                elseif k == "autoexec_path" then cfg.autoexec_path = v
                elseif k == "autoexec_script" then cfg.autoexec_script = v
                elseif k == "pkg" then
                    local fl = split(v, ",")
                    local name = trim(fl[1] or "")
                    if name ~= "" then
                        cfg.pkgs[name] = {
                            selected  = tonumber(fl[2]) or 1,
                            on        = tonumber(fl[3]) or 1,
                            heartbeat = tonumber(fl[4]) or 10,
                            rejoin    = tonumber(fl[5]) or 0,
                            ps_index  = tonumber(fl[6]) or 1,
                        }
                    end
                end
            end
        end
    end
    f:close()
    if #cfg.prefixes == 0 then table.insert(cfg.prefixes, DEF_PREFIX) end
    return cfg, true
end

local function save_cfg(cfg)
    local f = io.open(CFG_PATH, "w")
    if not f then return false end
    f:write("# Limbo Rejoin -- editable by hand or via menu\n")
    f:write("launch_delay=" .. cfg.launch_delay .. "\n")
    f:write("margin=" .. cfg.margin .. "\n")
    f:write("place_id=" .. cfg.place_id .. "\n")
    f:write("autoexec_path=" .. cfg.autoexec_path .. "\n")
    f:write("autoexec_script=" .. cfg.autoexec_script .. "\n")
    for _, p in ipairs(cfg.prefixes) do f:write("prefix=" .. p .. "\n") end
    for name, p in pairs(cfg.pkgs) do
        f:write(string.format("pkg=%s,%d,%d,%d,%d,%d\n",
            name, p.selected, p.on, p.heartbeat, p.rejoin, p.ps_index))
    end
    f:close()
    return true
end

-- private server: file is source of truth, auto-written on change
local function load_ps(cfg)
    local f = io.open(PS_FILE, "r")
    if not f then return end
    cfg.ps = {}
    for line in f:lines() do
        line = trim(line)
        if line ~= "" then table.insert(cfg.ps, line) end
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

local function uw(s)
    s = strip(s)
    local n = 0
    for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
end
local function pad(s, w)
    local d = w - uw(s)
    if d > 0 then return s .. string.rep(" ", d) end
    return s
end
local function cut(s, m)
    if not s then return "-" end
    if uw(s) <= m then return s end
    return m > 2 and (s:sub(1, m - 2) .. "..") or s:sub(1, m)
end

-- box: title INSIDE, no border-breaking separator
local function box_open(title)
    print("┌" .. string.rep("─", IN) .. "┐")
    if title and title ~= "" then
        col("1;36"); io.write("│ " .. pad(title:upper(), IN - 2) .. " │"); off(); print("")
    end
end
local function box_line(t) print("│ " .. pad(t or "", IN - 2) .. " │") end
local function box_blank() print("│ " .. string.rep(" ", IN - 2) .. " │") end
local function box_close() print("└" .. string.rep("─", IN) .. "┘") end

local function head(name)
    cls()
    print("┌" .. string.rep("─", IN) .. "┐")
    col("1;36"); io.write("│ " .. pad("Limbo  >  " .. name, IN - 2) .. " │"); off(); print("")
    print("└" .. string.rep("─", IN) .. "┘")
    print("")
end

local function read_line()
    local tty = io.open("/dev/tty", "r")
    local r
    if tty then r = tty:read("*l"); tty:close() else r = io.read("*l") end
    return r
end
local function read_key(t)
    local h = io.popen("bash -c 'read -t " .. (t or 1) .. " -n 1 k < /dev/tty 2>/dev/null && echo $k' 2>/dev/null")
    if not h then sleep(t or 1); return nil end
    local k = h:read("*l"); h:close()
    return (k and k ~= "") and k or nil
end

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
    local h = io.popen("su -c '" .. cmd:gsub("'", "'\\''") .. "' 2>&1")
    if not h then return "" end
    local r = h:read("*a"); h:close()
    return strip(r or "")
end
local function su_exec(cmd)
    os.execute("su -c '" .. cmd:gsub("'", "'\\''") .. "' >/dev/null 2>&1")
end
local function hlog(msg)
    local f = io.open(LOG_FILE, "a")
    if f then f:write(os.date("%H:%M:%S ") .. msg .. "\n"); f:close() end
end

-- ============================================================
-- RESOURCE (cpu/ram) -- delta sampling, no sleep, cached
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

-- cache 2s to stay light
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
local function detect_offset()
    local off = 0
    local v = su_cmd("dumpsys window | grep mStable | head -1"):match("mStable=%[%d+,(%d+)%]")
    if v then off = tonumber(v) or 0 end
    if off == 0 then
        local d = su_cmd("wm density"):match("(%d+)")
        off = d and math.ceil(24 * tonumber(d) / 160) or 48
    end
    return off
end
local function detect_screen()
    local off = detect_offset()
    local r = su_cmd("wm size")
    local sw, sh = r:match("(%d+)x(%d+)")
    if not sw then return nil, nil, off end
    sw, sh = tonumber(sw), tonumber(sh)
    return math.min(sw, sh), math.max(sw, sh), off
end

local _pkg_cache, _pkg_t = nil, 0
local function all_packages()
    local now = os.time()
    if _pkg_cache and (now - _pkg_t) < 8 then return _pkg_cache end
    local h = io.popen("pm list packages 2>/dev/null")
    local r = ""
    if h then r = h:read("*a") or ""; h:close() end
    local out = {}
    for line in r:gmatch("[^\r\n]+") do
        local p = line:match("package:(.+)")
        if p then p = clean_pkg(p); if p then table.insert(out, p) end end
    end
    _pkg_cache, _pkg_t = out, now
    return out
end
local function drop_cache() _pkg_cache, _pkg_t = nil, 0 end

-- filter starts-with (hard): only packages beginning with a prefix
local function detect(prefixes, force)
    if force then drop_cache() end
    local all = all_packages()
    local out, seen = {}, {}
    for _, p in ipairs(all) do
        for _, pref in ipairs(prefixes) do
            if pref ~= "" and p:sub(1, #pref) == pref and not seen[p] then
                table.insert(out, p); seen[p] = true; break
            end
        end
    end
    table.sort(out)
    return out
end

local function alive_map(names)
    if #names == 0 then return {} end
    local cmd = "for p in " .. table.concat(names, " ") ..
        "; do if pidof $p >/dev/null 2>&1; then echo \"$p=1\"; else echo \"$p=0\"; fi; done"
    local out = su_cmd(cmd)
    local m = {}
    for line in out:gmatch("[^\n]+") do
        local k, v = line:match("^(.-)=(%d)$")
        if k then m[k] = (v == "1") end
    end
    return m
end

-- ============================================================
-- LAYOUT
-- ============================================================
local function apply_layout(pkg, L, T, R, B)
    local pref = "/data/data/" .. pkg .. "/shared_prefs/" .. pkg .. "_preferences.xml"
    su_exec("chmod 666 " .. pref)
    local args = {}
    for _, f in ipairs({
        { "app_cloner_current_window_left", L }, { "app_cloner_current_window_top", T },
        { "app_cloner_current_window_right", R }, { "app_cloner_current_window_bottom", B },
    }) do
        table.insert(args, "-e 's/name=\\\\\"" .. f[1] .. "\\\\\" value=\\\\\"[^\\\\\"]*\\\\\"/name=\\\\\"" .. f[1] .. "\\\\\" value=\\\\\"" .. f[2] .. "\\\\\"/g'")
    end
    su_exec("sed -i " .. table.concat(args, " ") .. " " .. pref)
    su_exec("chmod 444 " .. pref)
end

local function grid_bounds(i, n, sw, sh, off, margin)
    if n <= 1 then return margin, off + margin, sw - margin, sh - margin end
    local gh = math.floor((sh - off) / n)
    local row = i - 1
    return margin, (row * gh) + off + margin, sw - margin, ((row + 1) * gh) + off - margin
end

-- ============================================================
-- LAUNCH
-- ============================================================
local function build_intent(pkg, ps_url, place_id)
    if ps_url and ps_url ~= "" then
        local dp = ps_url:match("^intent://(.-)#Intent") or ps_url:gsub("^https?://", "")
        return "intent://" .. dp .. "#Intent;scheme=https;package=" .. pkg .. ";action=android.intent.action.VIEW;end"
    end
    if place_id and place_id ~= "" then
        return "intent://experiences/start?placeId=" .. place_id ..
            "#Intent;scheme=roblox;package=" .. pkg .. ";action=android.intent.action.VIEW;end"
    end
    return nil
end
local function launch(pkg, ps_url, place_id, reason)
    su_exec("am force-stop " .. pkg)
    sleep(1)
    local intent = build_intent(pkg, ps_url, place_id)
    if not intent then hlog("SKIP " .. pkg); return false end
    su_exec('am start --user 0 "' .. intent .. '"')
    hlog("LAUNCH " .. pkg .. " [" .. (reason or "join") .. "]")
    return true
end

-- ============================================================
-- LISTS
-- ============================================================
local function active_list(cfg)
    local out = {}
    for name, p in pairs(cfg.pkgs) do
        if p.selected == 1 and p.on == 1 then table.insert(out, name) end
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
    cfg.pkgs[name] = cfg.pkgs[name] or { selected = 1, on = 1, heartbeat = 10, rejoin = 0, ps_index = 1 }
    return cfg.pkgs[name]
end

-- range input like baseline: "1,2,3" / "1-10" / "2,5-8"
local function parse_range(input, max)
    local sel, seen = {}, {}
    local a, b = input:match("^(%d+)%s*%-%s*(%d+)$")
    if a and b then
        for i = tonumber(a), tonumber(b) do
            if i >= 1 and i <= max and not seen[i] then table.insert(sel, i); seen[i] = true end
        end
        return sel
    end
    for n in input:gmatch("(%d+)") do
        local v = tonumber(n)
        if v and v >= 1 and v <= max and not seen[v] then table.insert(sel, v); seen[v] = true end
    end
    return sel
end

local function fmt_res()
    local r = resources()
    return string.format("CPU %-6s used     RAM %.1f / %.1f GB",
        string.format("%.1f%%", r.cpu), r.used, r.total)
end

-- ============================================================
-- SCREENS (forward declare)
-- ============================================================
local screen_start, screen_rejoin, screen_prefix, screen_packages, screen_server, screen_layout

-- ---- MAIN ----
local function screen_menu(cfg)
    local note
    while true do
        local sel = selected_list(cfg)
        head("Main")

        box_open("resource")
        box_line(fmt_res())
        box_close()
        print("")

        box_open("package")
        if #sel == 0 then
            box_line("(none selected)")
        else
            for _, name in ipairs(sel) do
                local p = cfg.pkgs[name]
                box_line(string.format("%-24s %s", cut(name, 24), p.on == 1 and "on" or "off"))
            end
        end
        box_close()
        print("")

        print("Main Menu:")
        print("  [1] - Start")
        print("  [2] - Rejoin")
        print("  [3] - Prefix")
        print("  [4] - Packages")
        print("  [5] - Server")
        print("  [6] - Layout")
        print("  [0] - Exit")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return "exit" end
        if c == "1" then screen_start(cfg)
        elseif c == "2" then screen_rejoin(cfg)
        elseif c == "3" then screen_prefix(cfg)
        elseif c == "4" then screen_packages(cfg)
        elseif c == "5" then screen_server(cfg)
        elseif c == "6" then screen_layout(cfg)
        else note = "!invalid choice" end
    end
end

-- ---- START ----
local function fmt_clock(sec)
    return string.format("%02d:%02d:%02d",
        math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
end
screen_start = function(cfg)
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

    if cfg.autoexec_path ~= "" and cfg.autoexec_script ~= "" then
        su_exec("mkdir -p " .. (cfg.autoexec_path:match("^(.*)/") or "."))
        su_exec("cp " .. cfg.autoexec_path .. " " .. cfg.autoexec_path .. ".bak 2>/dev/null")
        local af = io.open(cfg.autoexec_path, "w")
        if af then af:write(cfg.autoexec_script); af:close(); su_exec("chmod 644 " .. cfg.autoexec_path) end
    end

    local st = {}
    local t0 = os.time()
    for i, name in ipairs(names) do
        local p = cfg.pkgs[name]
        local L, T, R, B = grid_bounds(i, #names, sw, sh, off_, cfg.margin)
        apply_layout(name, L, T, R, B)
        local ps_url = cfg.ps[p.ps_index] or cfg.ps[1] or ""
        launch(name, ps_url, cfg.place_id, "start")
        st[name] = {
            hb_next = os.time() + p.heartbeat,
            rj_next = os.time() + p.rejoin,
            status = "rejoin",
            ps_index = p.ps_index,
        }
        if i < #names then sleep(cfg.launch_delay) end
    end

    local quit = false
    while not quit do
        local now = os.time()
        local am = alive_map(names)

        head("Start  (" .. fmt_clock(now - t0) .. ")")
        box_open("resource")
        box_line(fmt_res())
        box_close()
        print("")

        box_open("package")
        box_line(string.format("%-22s %-9s %-5s %s", "package", "status", "ps", "rejoin"))
        box_blank()
        for _, name in ipairs(names) do
            local s = st[name]; local p = cfg.pkgs[name]
            local alive = am[name]
            local status
            if s.status == "rejoin" and alive then status = "rejoin"
            else status = alive and "alive" or "dead" end
            box_line(string.format("%-22s %-9s %-5s %s",
                cut(name, 22), status, "ps" .. s.ps_index,
                p.rejoin > 0 and (p.rejoin .. "s") or "off"))
            if alive then s.status = "alive" end
        end
        box_close()
        print("")
        col("90"); print("press y to stop & close all   |   n continue"); off()

        local k = read_key(1)
        if k and k:lower() == "y" then quit = true; break end

        now = os.time()
        for _, name in ipairs(names) do
            local s = st[name]; local p = cfg.pkgs[name]
            local launched = false

            -- rejoin: force re-entry every N seconds (0 = off). This rotates PS.
            if p.rejoin > 0 and now >= s.rj_next then
                s.rj_next = now + p.rejoin
                if #cfg.ps > 1 then
                    s.ps_index = s.ps_index + 1
                    if s.ps_index > #cfg.ps then s.ps_index = 1 end
                end
                hlog("rejoin " .. name .. " (ps " .. s.ps_index .. ")")
                launch(name, cfg.ps[s.ps_index] or cfg.ps[1] or "", cfg.place_id, "rejoin")
                s.status = "rejoin"
                launched = true
            end

            -- heartbeat: cek hidup/mati, relaunch kalau mati
            if p.heartbeat > 0 and now >= s.hb_next then
                s.hb_next = now + p.heartbeat
                if not am[name] and not launched then
                    hlog("heartbeat " .. name .. " dead -> rejoin")
                    launch(name, cfg.ps[s.ps_index] or cfg.ps[1] or "", cfg.place_id, "heartbeat")
                    s.status = "rejoin"
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
screen_rejoin = function(cfg)
    local note
    while true do
        local sel = selected_list(cfg)
        head("Rejoin")
        col("90"); print("delay " .. cfg.launch_delay .. "s"); off()
        print("")
        box_open("package")
        if #sel == 0 then
            box_line("(none selected -- set it in menu [4] Packages)")
        else
            box_line(string.format("%-3s %-20s %-4s %-10s %s", "#", "package", "on", "heartbeat", "rejoin"))
            box_blank()
            for i, name in ipairs(sel) do
                local p = cfg.pkgs[name]
                box_line(string.format("%-3d %-20s %-4s %-10s %s",
                    i, cut(name, 20), p.on == 1 and "x" or "-",
                    p.heartbeat .. "s", p.rejoin > 0 and (p.rejoin .. "s") or "off"))
            end
        end
        box_close()
        print("")
        print("  [number] - toggle on/off")
        print("  [e] - edit heartbeat / rejoin")
        print("  [d] - set delay")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c:lower() == "d" then
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
                    io.write("rejoin    (seconds, 0=off)  [" .. p.rejoin .. "] : "); io.flush()
                    local e = read_line(); e = e and trim(e) or ""
                    if e ~= "" then local en = tonumber(e); if en and en >= 0 then p.rejoin = en end end
                    save_cfg(cfg)
                    note = "saved: " .. name
                else note = "!invalid number" end
            end
        else
            local n = tonumber(c)
            if n and n >= 1 and n <= #sel then
                local p = cfg.pkgs[sel[n]]
                p.on = (p.on == 1) and 0 or 1
                save_cfg(cfg)
            else note = "!invalid choice" end
        end
    end
end

-- ---- PREFIX ----
screen_prefix = function(cfg)
    local note, scan
    while true do
        head("Prefix")
        if scan then
            box_open("scan result (" .. #scan .. ")")
            if #scan == 0 then box_line("(no package matched)")
            else for i, p in ipairs(scan) do box_line(string.format("%-3d %s", i, p)) end end
            box_close()
        else
            box_open("active prefix")
            if #cfg.prefixes == 0 then box_line("(empty)")
            else for i, p in ipairs(cfg.prefixes) do box_line(string.format("%-3d %s", i, p)) end end
            box_close()
        end
        print("")
        print("  [a] - add prefix")
        print("  [d] - delete prefix")
        print("  [s] - scan package")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c:lower() == "a" then
            local p = prompt(nil, "new prefix (e.g. com.moons)")
            if p then
                p = p:gsub("%s", "")
                local dup = false
                for _, x in ipairs(cfg.prefixes) do if x == p then dup = true end end
                if dup then note = "!already exists"
                elseif p:match("^[%w_%.]+$") then
                    table.insert(cfg.prefixes, p); save_cfg(cfg); scan = nil
                    note = "added: " .. p
                else note = "!invalid format" end
            end
        elseif c:lower() == "d" then
            if #cfg.prefixes == 0 then note = "!no prefix yet"
            else
                local n = tonumber(prompt(nil, "number to delete"))
                if n and n >= 1 and n <= #cfg.prefixes then
                    table.remove(cfg.prefixes, n); save_cfg(cfg); scan = nil; note = "deleted"
                else note = "!invalid number" end
            end
        elseif c:lower() == "s" then
            scan = detect(cfg.prefixes, true)
            if #scan == 0 then note = "!no package matched" end
        else note = "!invalid choice" end
    end
end

-- ---- PACKAGES ----
screen_packages = function(cfg)
    local note
    while true do
        local det = detect(cfg.prefixes)
        head("Packages")
        box_open("detected (" .. #det .. ")")
        if #det == 0 then
            box_line("(none -- set prefix first in menu [3])")
        else
            for i, p in ipairs(det) do
                local e = cfg.pkgs[p]
                box_line(string.format("[%s] %-3d %s", (e and e.selected == 1) and "x" or " ", i, p))
            end
        end
        box_close()
        print("")
        print("  [1,2,3] or [1-10] - select these")
        print("  [a] - select all")
        print("  [n] - select none")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c:lower() == "a" then
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
screen_layout = function(cfg)
    local note
    while true do
        local sw, sh, off_ = detect_screen()
        head("Layout")
        box_open("info")
        box_line("screen   " .. (sw and (sw .. " x " .. sh) or "?") .. "     offset   " .. off_)
        box_line("margin   " .. cfg.margin .. " px")
        box_close()
        print("")
        print("  [1] - set margin")
        print("  [2] - apply layout")
        print("  [0] - Back")
        print("")
        local c = prompt(note, "Select")
        note = nil
        if c == nil or c == "0" then return end
        if c == "1" then
            local n = tonumber(prompt(nil, "margin px"))
            if n and n >= 0 and n <= 500 then cfg.margin = n; save_cfg(cfg); note = "margin " .. n .. "px"
            else note = "!number 0-500" end
        elseif c == "2" then
            local sel = selected_list(cfg)
            if #sel == 0 or not sw then note = "!no package / failed to read screen"
            else
                head("Layout  >  apply")
                box_open("result")
                for i, name in ipairs(sel) do
                    local L, T, R, B = grid_bounds(i, #sel, sw, sh, off_, cfg.margin)
                    apply_layout(name, L, T, R, B)
                    box_line(string.format("%-18s L%-5d T%-5d R%-5d B%d", cut(name, 18), L, T, R, B))
                end
                box_close()
                print(""); col("32"); print("layout applied."); off()
                pause()
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
