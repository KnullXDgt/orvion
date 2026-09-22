-- Limbo Rejoin
-- Engine ported from deng-tool-rejoin; layout follows the local grid.
-- Single state file holds config + runtime status + relaunch trace.

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local STATE_PATH = os.getenv("LIMBO_STATE") or (HOME .. "/.limbo/limbo-state.json")
local DATA_DIR = STATE_PATH:match("^(.*)/") or "."
local LOG_PATH = DATA_DIR .. "/limbo.log"

local function ensure_dir(p)
    if p and p ~= "" then os.execute("mkdir -p '" .. p .. "' 2>/dev/null") end
end
ensure_dir(DATA_DIR)

local json = {}
do
    local function esc(s)
        return (s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
                 :gsub("\r", "\\r"):gsub("\t", "\\t"))
    end
    local enc
    enc = function(v, out)
        local t = type(v)
        if t == "nil" then out[#out+1] = "null"
        elseif t == "boolean" then out[#out+1] = v and "true" or "false"
        elseif t == "number" then
            if v ~= v or v == math.huge or v == -math.huge then out[#out+1] = "null"
            elseif math.floor(v) == v then out[#out+1] = string.format("%d", v)
            else out[#out+1] = string.format("%.6g", v) end
        elseif t == "string" then out[#out+1] = '"' .. esc(v) .. '"'
        elseif t == "table" then
            local n = #v
            local isarr = n > 0
            if isarr then
                for i = 1, n do if v[i] == nil then isarr = false break end end
            end
            if isarr then
                out[#out+1] = "["
                for i = 1, n do
                    if i > 1 then out[#out+1] = "," end
                    enc(v[i], out)
                end
                out[#out+1] = "]"
            else
                out[#out+1] = "{"
                local first = true
                local keys = {}
                for k in pairs(v) do keys[#keys+1] = tostring(k) end
                table.sort(keys)
                for _, k in ipairs(keys) do
                    if not first then out[#out+1] = "," end
                    first = false
                    out[#out+1] = '"' .. esc(k) .. '":'
                    enc(v[k], out)
                end
                out[#out+1] = "}"
            end
        else out[#out+1] = "null" end
    end
    function json.encode(v)
        local out = {}
        enc(v, out)
        return table.concat(out)
    end

    local function dec(str)
        local pos = 1
        local function skip()
            while pos <= #str do
                local c = str:sub(pos, pos)
                if c == " " or c == "\t" or c == "\n" or c == "\r" then pos = pos + 1 else break end
            end
        end
        local parse_value
        local function parse_string()
            pos = pos + 1
            local buf = {}
            while pos <= #str do
                local c = str:sub(pos, pos)
                if c == '"' then pos = pos + 1 break
                elseif c == "\\" then
                    local n = str:sub(pos+1, pos+1)
                    if n == "n" then buf[#buf+1] = "\n"
                    elseif n == "t" then buf[#buf+1] = "\t"
                    elseif n == "r" then buf[#buf+1] = "\r"
                    elseif n == "u" then
                        local cp = tonumber(str:sub(pos+2, pos+5), 16) or 63
                        buf[#buf+1] = cp < 128 and string.char(cp) or "?"
                        pos = pos + 4
                    else buf[#buf+1] = n end
                    pos = pos + 2
                else buf[#buf+1] = c pos = pos + 1 end
            end
            return table.concat(buf)
        end
        local function parse_number()
            local s = pos
            while pos <= #str and str:sub(pos, pos):match("[%d%.eE%+%-]") do pos = pos + 1 end
            return tonumber(str:sub(s, pos-1))
        end
        parse_value = function()
            skip()
            local c = str:sub(pos, pos)
            if c == "{" then
                pos = pos + 1
                local obj = {}
                skip()
                if str:sub(pos, pos) == "}" then pos = pos + 1 return obj end
                while true do
                    skip()
                    local k = parse_string()
                    skip()
                    if str:sub(pos, pos) == ":" then pos = pos + 1 end
                    obj[k] = parse_value()
                    skip()
                    local d = str:sub(pos, pos)
                    if d == "," then pos = pos + 1
                    elseif d == "}" then pos = pos + 1 break
                    else break end
                end
                return obj
            elseif c == "[" then
                pos = pos + 1
                local arr = {}
                skip()
                if str:sub(pos, pos) == "]" then pos = pos + 1 return arr end
                while true do
                    arr[#arr+1] = parse_value()
                    skip()
                    local d = str:sub(pos, pos)
                    if d == "," then pos = pos + 1
                    elseif d == "]" then pos = pos + 1 break
                    else break end
                end
                return arr
            elseif c == '"' then return parse_string()
            elseif str:sub(pos, pos+3) == "true" then pos = pos + 4 return true
            elseif str:sub(pos, pos+4) == "false" then pos = pos + 5 return false
            elseif str:sub(pos, pos+3) == "null" then pos = pos + 4 return nil
            else return parse_number() end
        end
        local ok, res = pcall(parse_value)
        if ok then return res end
        return nil
    end
    function json.decode(s)
        if not s or s == "" then return nil end
        return dec(s)
    end
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function split(s, sep)
    local t = {}
    for part in (tostring(s) .. sep):gmatch("(.-)" .. sep) do t[#t+1] = part end
    return t
end
local function shell(cmd)
    local h = io.popen(cmd .. " 2>/dev/null")
    if not h then return "" end
    local r = h:read("*a") or ""
    h:close()
    return trim(r)
end
local function root(cmd)
    local q = cmd:gsub("'", "'\\''")
    local h = io.popen("su -c '" .. q .. "' </dev/null 2>&1")
    if not h then return "" end
    local r = h:read("*a") or ""
    h:close()
    return trim(r)
end
local function root_exec(cmd)
    local q = cmd:gsub("'", "'\\''")
    os.execute("su -c '" .. q .. "' </dev/null >/dev/null 2>&1")
end
local function has_root()
    return root("id"):match("uid=0") ~= nil
end
local function sleep(s) if s and s > 0 then os.execute("sleep " .. tostring(s)) end end
local function now() return os.time() end
local function iso(t) return os.date("%Y-%m-%dT%H:%M:%SZ", t or now()) end
local function log(msg, level)
    local f = io.open(LOG_PATH, "a")
    if f then
        f:write(string.format("%s [%s] %s\n", os.date("%H:%M:%S"), level or "INFO", msg))
        f:close()
    end
end

-- ---------------------------------------------------------------- state
local DEFAULT_STATE = {
    version = 1,
    device_name = "",
    created_at = nil,
    updated_at = nil,
    first_setup_completed = false,
    prefix = "com.moons",
    roblox_packages = {},
    private_url_mode = "global",
    private_server_url = "",
    screen_mode = "portrait",
    launch_mode = "deeplink",
    launch_delay_seconds = 10,
    reconnect_delay_seconds = 8,
    health_check_interval_seconds = 90,
    foreground_grace_seconds = 45,
    auto_rejoin_enabled = true,
    root_mode_enabled = true,
    freeform_enabled = false,
    low_graphics_enabled = true,
    keep_screen_awake = true,
    webhook_enabled = false,
    webhook_url = "",
    webhook_interval_minutes = 5,
    webhook_last_sent_at = 0,
    auto_execute_scripts = {},
    max_restart_attempts_per_hour = 10,
    backoff_min_seconds = 10,
    backoff_max_seconds = 300,
    stop_codes = { 267, 600 },
    runtime = {
        started_at = nil,
        pid = nil,
        headless = false,
        freeform_configured_at = nil,
    },
    status = {},
    trace = {
        launches = {},
        relaunches = {},
        halts = {},
        events = {},
    },
}

local function deep_copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = deep_copy(val) end
    return out
end

local function merge_defaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = deep_copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            merge_defaults(dst[k], v)
        end
    end
    return dst
end

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local r = f:read("*a")
    f:close()
    return r
end

local function write_file_atomic(p, content)
    local tmp = p .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(content)
    f:close()
    os.rename(tmp, p)
    return true
end

local function load_state()
    local raw = read_file(STATE_PATH)
    local st = json.decode(raw)
    if type(st) ~= "table" then st = {} end
    merge_defaults(st, DEFAULT_STATE)
    return st
end

local function save_state(st)
    st.updated_at = iso()
    write_file_atomic(STATE_PATH, json.encode(st))
end

local function record_trace(st, kind, entry)
    local t = st.trace[kind]
    if type(t) ~= "table" then t = {}; st.trace[kind] = t end
    entry.at = now()
    entry.at_iso = iso()
    t[#t+1] = entry
    while #t > 200 do table.remove(t, 1) end
end

-- ---------------------------------------------------------------- device
local function detect_screen()
    local out = root("wm size; wm density")
    local sw, sh = out:match("(%d+)x(%d+)")
    local d = out:match("density[^%d]*(%d+)") or out:match("(%d+)%s*$")
    if not sw then return nil end
    return tonumber(sw), tonumber(sh), tonumber(d or 320)
end

local function detect_packages(prefix)
    local out = root("pm list packages")
    local list = {}
    for line in out:gmatch("[^\n]+") do
        local p = line:match("package:(.+)")
        if p then p = trim(p) end
        if p and p:sub(1, #prefix) == prefix then list[#list+1] = p end
    end
    table.sort(list)
    return list
end

local function pidof(pkg)
    local r = root("pidof " .. pkg)
    local pid = r:match("(%d+)")
    return pid and tonumber(pid) or nil
end

local function read_username(pkg)
    local f = "/data/data/" .. pkg .. "/shared_prefs/prefs.xml"
    local out = root("if [ -f '" .. f .. "' ]; then sed -n 's/.*name=\"username\">\\([^<]*\\)<.*/\\1/p' '" .. f .. "' | head -1; fi")
    if out == "" then
        out = root("if [ -f '" .. f .. "' ]; then sed -n 's/.*name=\"displayName\">\\([^<]*\\)<.*/\\1/p' '" .. f .. "' | head -1; fi")
    end
    return out
end

-- ---------------------------------------------------------------- layout (local grid)
local function grid_bounds(i, n, sw, sh, inset)
    if n == 1 then return 0, 0, sw, sh end
    local gh = math.floor((sh - inset) / n)
    local row = i - 1
    return 0, (row * gh) + inset, sw, ((row + 1) * gh) + inset
end

local function apply_clone_prefs(pkg, L, T, R, B)
    local pref = "/data/data/" .. pkg .. "/shared_prefs/" .. pkg .. "_preferences.xml"
    local parts = { "chmod 666 " .. pref }
    local keys = {
        { "app_cloner_current_window_left", L },
        { "app_cloner_current_window_top", T },
        { "app_cloner_current_window_right", R },
        { "app_cloner_current_window_bottom", B },
    }
    for _, f in ipairs(keys) do
        local pat = 's/name="' .. f[1] .. '" value="[^"]*"/name="' .. f[1] .. '" value="' .. f[2] .. '"/g'
        parts[#parts+1] = "sed -i '" .. pat .. "' " .. pref
    end
    parts[#parts+1] = "chmod 444 " .. pref
    root_exec(table.concat(parts, "; "))
end

-- ---------------------------------------------------------------- freeform
local FREEFORM_KEYS = {
    { "global", "enable_freeform_support" },
    { "global", "force_resizable_activities" },
    { "global", "freeform_window_management" },
    { "global", "development_settings_enabled" },
}

local function freeform_status()
    local res = {}
    for _, k in ipairs(FREEFORM_KEYS) do
        local v = root("settings get " .. k[1] .. " " .. k[2])
        res[#res+1] = { ns = k[1], key = k[2], value = v }
    end
    return res
end

local function freeform_enable_once(st)
    if st.runtime.freeform_configured_at then return false, "already" end
    local changed = 0
    for _, k in ipairs(FREEFORM_KEYS) do
        local cur = root("settings get " .. k[1] .. " " .. k[2])
        if cur ~= "1" then
            root_exec("settings put " .. k[1] .. " " .. k[2] .. " 1")
            changed = changed + 1
        end
    end
    st.runtime.freeform_configured_at = iso()
    st.freeform_enabled = true
    return true, changed
end

-- ---------------------------------------------------------------- launch
local function build_deeplink(url)
    if not url or url == "" then return nil end
    local code = url:match("code=([%w%-]+)")
    local typ = url:match("type=([%w]+)") or "Server"
    if not code then return nil end
    return "roblox://navigation/share_links?code=" .. code .. "&type=" .. typ
end

-- find task id + stack id for a package
local function get_task_id(pkg)
    local out = root("dumpsys activity activities 2>/dev/null | grep -oE 'TaskRecord\\{[^}]*" .. pkg .. "[^}]*' | head -1")
    local tid = out:match("#(%d+)")
    return tid and tonumber(tid) or nil
end

local function get_stack_id(pkg)
    local out = root("dumpsys activity activities 2>/dev/null | grep -oE 'TaskRecord\\{[^}]*" .. pkg .. "[^}]*' | head -1")
    local sid = out:match("StackId=(%d+)")
    return sid and tonumber(sid) or nil
end

-- read actual window bounds for package (largest frame = main window)
local function read_bounds(pkg)
    local out = root("dumpsys window windows 2>/dev/null | grep -A8 '" .. pkg .. "/com.roblox.client.ActivityNativeMain' | grep -oE 'mFrame=\\[[0-9-]+,[0-9-]+\\]\\[[0-9-]+,[0-9-]+\\]' | head -6")
    local best, bestarea = nil, -1
    for l, t, r, b in out:gmatch("%[(%-?%d+),(%-?%d+)%]%[(%-?%d+),(%-?%d+)%]") do
        local L, T, R, B = tonumber(l), tonumber(t), tonumber(r), tonumber(b)
        local area = (R-L) * (B-T)
        if area > bestarea then bestarea = area; best = { L, T, R, B } end
    end
    if best then return best end
    -- fallback: grep all moons frames, take largest
    local out2 = root("dumpsys window windows 2>/dev/null | grep -E 'Window #.*" .. pkg .. "|mFrame=' | grep -A1 -i '" .. pkg .. "' | grep -oE '\\[[0-9-]+,[0-9-]+\\]\\[[0-9-]+,[0-9-]+\\]' | head -8")
    for l, t, r, b in out2:gmatch("%[(%-?%d+),(%-?%d+)%]%[(%-?%d+),(%-?%d+)%]") do
        local L, T, R, B = tonumber(l), tonumber(t), tonumber(r), tonumber(b)
        local area = (R-L) * (B-T)
        if area > bestarea then bestarea = area; best = { L, T, R, B } end
    end
    return best
end

local function bounds_close(a, want, tol)
    tol = tol or 32
    if not a then return false end
    return math.abs(a[1]-want[1]) <= tol and math.abs(a[2]-want[2]) <= tol
       and math.abs(a[3]-want[3]) <= tol and math.abs(a[4]-want[4]) <= tol
end

-- deng's direct-resize chain: try every known command until bounds verify
local function direct_resize(pkg, want)
    local tid = get_task_id(pkg)
    if not tid then return false, "no_task_id" end
    local sid = get_stack_id(pkg)
    local l, t, r, b = want[1], want[2], want[3], want[4]
    local candidates = {}
    candidates[#candidates+1] = string.format("am task resizeable %d 2", tid)
    if sid then
        candidates[#candidates+1] = string.format("am stack resize %d %d %d %d %d", sid, l, t, r, b)
        candidates[#candidates+1] = string.format("am stack resize-animated %d %d %d %d %d", sid, l, t, r, b)
    end
    candidates[#candidates+1] = string.format("am task resize %d %d %d %d %d", tid, l, t, r, b)
    candidates[#candidates+1] = string.format("cmd activity resize-task %d %d %d %d %d", tid, l, t, r, b)
    candidates[#candidates+1] = string.format("wm task resize %d %d %d %d %d", tid, l, t, r, b)
    local last = ""
    for _, c in ipairs(candidates) do
        root(c)
        sleep(0.6)
        local got = read_bounds(pkg)
        if bounds_close(got, want) then
            return true, c:match("^(%S+ %S+)") .. " verified"
        end
        last = c
    end
    return false, "resize failed (last: " .. last .. ")"
end

-- launch one package with deng's full fallback chain
local function launch_package(st, pkg, url, rect)
    local deep = build_deeplink(url)
    if not deep then return false, "no_url" end
    local L, T, R, B = rect[1], rect[2], rect[3], rect[4]
    root_exec("am force-stop " .. pkg)
    sleep(1.2)
    local bounds = string.format("%d %d %d %d", L, T, R, B)
    local method = "unknown"

    -- 1) full: windowingMode 5 + activity-launch-bounds + url + flags
    local cmd1 = string.format(
        'am start --windowingMode 5 --activity-launch-bounds %s ' ..
        '-a android.intent.action.VIEW -c android.intent.category.BROWSABLE ' ..
        '-f 0x14208000 -d "%s" %s', bounds, deep, pkg)
    local out = root(cmd1)
    if not (out:match("Exception") or out:match("Unknown option")) then
        method = "windowingMode5+bounds"
    else
        -- 2) windowingMode 5 only (no bounds)
        local cmd2 = string.format(
            'am start --windowingMode 5 -a android.intent.action.VIEW ' ..
            '-c android.intent.category.BROWSABLE -f 0x14208000 -d "%s" %s', deep, pkg)
        local out2 = root(cmd2)
        if not (out2:match("Exception") or out2:match("Unknown option")) then
            method = "windowingMode5"
        else
            -- 3) plain deeplink
            root_exec(string.format(
                'am start -a android.intent.action.VIEW ' ..
                '-c android.intent.category.BROWSABLE -f 0x14208000 -d "%s" %s', deep, pkg))
            method = "deeplink"
        end
    end

    -- 4) post-launch direct resize (deng's chain) — only if bounds supported/needed
    sleep(3)
    local rok, rmsg = direct_resize(pkg, rect)
    if rok then method = method .. "+resize" end

    record_trace(st, "launches", {
        package = pkg, method = method, rect = bounds,
        resize = rok and "ok" or rmsg,
    })
    return true
end

-- ---------------------------------------------------------------- detector
local function logcat_pid_disconnect(pid)
    local out = root("logcat -d -t 400 --pid " .. tostring(pid))
    local code, key
    for line in out:gmatch("[^\n]+") do
        local c = line:match("reason:%s*(%d+)")
        if c then
            code = tonumber(c)
            key = line:match("(%d%d%d%d%-%d%d%-%d%dT[%d:%.]+Z)") or line:sub(1, 60)
        end
    end
    return code, key
end

local function presence_check(user_id, cookie)
    if not user_id then return nil end
    local body = string.format('{"userIds":[%s]}', tostring(user_id))
    local cmd = string.format(
        'curl -s --max-time 8 -X POST https://presence.roblox.com/v1/presence/users ' ..
        '-H "Content-Type: application/json" %s -d %s',
        (cookie and cookie ~= "") and ("-H \"Cookie: .ROBLOSECURITY=" .. cookie .. "\"") or "",
        ("'" .. body:gsub("'", "") .. "'"))
    local out = shell(cmd)
    if out == "" then return nil end
    local ptype = out:match('"userPresenceType":%s*(%d+)')
    local gid = out:match('"gameId":"([^"]*)"')
    return tonumber(ptype or "0"), gid
end

-- ---------------------------------------------------------------- relaunch
local function pick_rect(st, pkg, sw, sh, inset)
    local names = {}
    for _, e in ipairs(st.roblox_packages) do
        if e.enabled then names[#names+1] = e.package end
    end
    table.sort(names)
    local idx
    for i, n in ipairs(names) do if n == pkg then idx = i end end
    if not idx then idx = 1 end
    return { grid_bounds(idx, math.max(#names, 1), sw, sh, inset) }
end

local function relaunch(st, pkg, reason)
    local sw, sh, dens = detect_screen()
    if not sw then return false, "no_screen" end
    local inset = math.ceil(24 * (dens or 320) / 160)
    local rect = pick_rect(st, pkg, sw, sh, inset)
    local entry
    for _, e in ipairs(st.roblox_packages) do if e.package == pkg then entry = e end end
    local url = (entry and entry.private_server_url ~= "" and entry.private_server_url)
                or st.private_server_url
    apply_clone_prefs(pkg, rect[1], rect[2], rect[3], rect[4])
    local ok, err = launch_package(st, pkg, url, rect)
    record_trace(st, "relaunches", { package = pkg, reason = reason, rect = table.concat(rect, ",") })
    if entry then entry.last_relaunch_at = now() end
    return ok, err
end

-- ---------------------------------------------------------------- ui (deng/kaeru style)
local GREEN  = "\27[1;92m"
local YELLOW = "\27[1;93m"
local RED    = "\27[1;91m"
local CYAN   = "\27[1;96m"
local WHITE  = "\27[1;97m"
local PINK   = "\27[38;5;205m"
local RESET  = "\27[0m"

local function sep(char)
    char = (char or "="):sub(1, 1)
    return CYAN .. string.rep(char, 30) .. RESET
end
local function emit(t) print(t or "") end
local function header(title)
    emit()
    emit(sep("="))
    emit(CYAN .. title .. RESET)
    emit(sep("="))
    emit()
end
local function section(title)
    emit()
    emit(CYAN .. title .. RESET)
    emit(sep("-"))
end
local function menuitem(n, label)
    emit(YELLOW .. n .. "." .. RESET .. " " .. WHITE .. label .. RESET)
end
local function prompt_line(t)
    if not t:match("^%[%?%]") then t = "[?] " .. t end
    if t:sub(-1) ~= ":" then t = t .. ":" end
    return CYAN .. t .. RESET
end
local function ok_line(t)
    if not t:match("^%[!%]") then t = "[!] " .. t end
    if t:sub(-1) ~= "." then t = t .. "." end
    return GREEN .. t .. RESET
end
local function warn_line(t)
    if not t:match("^%[!%]") then t = "[!] " .. t end
    if t:sub(-1) ~= "." then t = t .. "." end
    return YELLOW .. t .. RESET
end
local function err_line(t)
    if t:match("^%[!%]") then t = t:gsub("%[!%]", "[x]", 1)
    elseif not t:match("^%[x%]") then t = "[x] " .. t end
    if t:sub(-1) ~= "." then t = t .. "." end
    return RED .. t .. RESET
end
local function ok(t) emit(ok_line(t)) end
local function warn(t) emit(warn_line(t)) end
local function err(t) emit(err_line(t)) end

local function read_line()
    io.flush()
    local r = io.read("*l")
    if r == nil then
        local tty = io.open("/dev/tty", "r")
        if tty then r = tty:read("*l"); tty:close() end
    end
    return r
end
local function ask(label, default)
    io.write(prompt_line(label .. (default and (" [" .. default .. "]") or "")) .. " ")
    io.flush()
    local r = read_line()
    if r == nil then return default end
    r = trim(r)
    if r == "" then return default end
    return r
end
local function pause()
    emit()
    io.write(CYAN .. "[?] Press Enter to continue..." .. RESET)
    io.flush()
    read_line()
end

-- ---------------------------------------------------------------- wizard
local function wizard_packages(st)
    header("Setup  >  packages")
    print("detecting clones with prefix: " .. st.prefix)
    local pkgs = detect_packages(st.prefix)
    if #pkgs == 0 then
        print("")
        err("no package found for prefix " .. st.prefix)
        print("set the prefix first.")
        pause()
        return
    end
    print("")
    for i, p in ipairs(pkgs) do
        print(string.format("  %2d. %s", i, p))
    end
    print("")
    local sel = ask("select (e.g. 1,2,3 or 1-3 or all)", "all")
    local chosen = {}
    if sel == "all" or sel == "a" or sel == "" then
        chosen = pkgs
    else
        for tok in sel:gmatch("[^,;%s]+") do
            local a, b = tok:match("^(%d+)%-(%d+)$")
            if a then
                for i = tonumber(a), tonumber(b) do if pkgs[i] then chosen[#chosen+1] = pkgs[i] end end
            else
                local n = tonumber(tok)
                if n and pkgs[n] then chosen[#chosen+1] = pkgs[n] end
            end
        end
    end
    if #chosen == 0 then print("nothing selected."); pause(); return end
    st.roblox_packages = {}
    for _, p in ipairs(chosen) do
        st.roblox_packages[#st.roblox_packages+1] = {
            package = p, enabled = true,
            account_username = read_username(p),
            private_server_url = "",
            low_graphics_enabled = true,
            auto_reopen_enabled = true,
        }
    end
    save_state(st)
    print("")
    ok(#chosen .. " package(s) saved.")
    pause()
end

local function wizard_url(st)
    header("Setup  >  private server url")
    print("current: " .. (st.private_server_url ~= "" and st.private_server_url or "(none)"))
    print("")
    local u = ask("paste roblox share url", st.private_server_url)
    if u and u ~= "" then
        local code = u:match("code=([%w%-]+)")
        if not code then
            err("! url must contain code="); pause(); return
        end
        st.private_server_url = u
        save_state(st)
        ok("url saved (code " .. code:sub(1, 8) .. "..)")
    end
    pause()
end

local function wizard_layout(st)
    header("Setup  >  layout")
    print("layout is the local grid (top-to-bottom stack).")
    local sw, sh, d = detect_screen()
    if sw then print(string.format("screen: %dx%d  density: %d", sw, sh, d or 0)) end
    print("")
    print("  screen_mode: " .. st.screen_mode)
    local m = ask("screen_mode (portrait/landscape)", st.screen_mode)
    if m == "portrait" or m == "landscape" then st.screen_mode = m end
    print("")
    local g = ask("enable freeform now? (once per boot) (y/n)", "n")
    if g and g:lower() == "y" then
        print("")
        print("current freeform settings:")
        for _, r in ipairs(freeform_status()) do
            print(string.format("  %s = %s", r.key, r.value ~= "" and r.value or "(unset)"))
        end
        print("")
        local ok, ch = freeform_enable_once(st)
        if ok then ok("freeform enabled (" .. tostring(ch) .. " keys written)")
        else warn("freeform: " .. tostring(ch)) end
    end
    save_state(st)
    pause()
end

local function wizard_run(st)
    local step = 1
    while step <= 4 do
        if step == 1 then
            header("Setup  >  device")
            print("device name: " .. (st.device_name ~= "" and st.device_name or "(auto)"))
            print("")
            local n = ask("device name", st.device_name ~= "" and st.device_name or "Redfinger")
            st.device_name = n
            print("")
            print("prefix: " .. st.prefix)
            local p = ask("clone prefix", st.prefix)
            st.prefix = p
            save_state(st)
            step = 2
        elseif step == 2 then
            wizard_packages(st)
            step = 3
        elseif step == 3 then
            wizard_url(st)
            step = 4
        elseif step == 4 then
            wizard_layout(st)
            st.first_setup_completed = true
            save_state(st)
            step = 5
        end
    end
    header("Setup  >  done")
    ok("setup complete.")
    print("")
    print("packages: " .. #st.roblox_packages)
    print("url: " .. (st.private_server_url ~= "" and "set" or "none"))
    print("state: " .. STATE_PATH)
    pause()
end

-- ---------------------------------------------------------------- backoff
local function backoff_seconds(fail_count, min_s, max_s)
    min_s = math.max(1, tonumber(min_s) or 10)
    max_s = math.max(min_s, tonumber(max_s) or 300)
    fail_count = math.max(0, math.floor(tonumber(fail_count) or 0))
    if fail_count <= 0 then return min_s end
    local delay = min_s * (2 ^ (fail_count - 1))
    if delay < min_s then delay = min_s end
    if delay > max_s then delay = max_s end
    return math.floor(delay)
end

-- ---------------------------------------------------------------- webhook
local function webhook_send(st, content)
    if not st.webhook_enabled or st.webhook_url == "" then return false end
    local body = st.json.encode({ content = content })
    local safe = body:gsub("'", "'\\''")
    local cmd = string.format(
        "curl -s --max-time 10 -X POST -H 'Content-Type: application/json' -d '%s' '%s'",
        safe, st.webhook_url)
    shell(cmd)
    st.webhook_last_sent_at = now()
    return true
end

local function webhook_should_send(st)
    if not st.webhook_enabled then return false end
    local iv = (st.webhook_interval_minutes or 5) * 60
    return (now() - (st.webhook_last_sent_at or 0)) >= iv
end

-- ---------------------------------------------------------------- auto execute
local EXECUTORS = {
    delta = { subpath = "files/gloop/external/Autoexecute" },
    codex = { subpath = "files/gloop/external/Autoexecute" },
    arceus = { subpath = "files/gloop/external/Autoexecute" },
}

local function autoexec_dir(pkg, executor)
    local spec = EXECUTORS[executor or "delta"] or EXECUTORS.delta
    return "/storage/emulated/0/Android/data/" .. pkg .. "/" .. spec.subpath
end

local function autoexec_write(st, pkg, filename, content, executor)
    local dir = autoexec_dir(pkg, executor)
    root_exec("mkdir -p '" .. dir .. "'")
    local tmp = "/sdcard/.limbo_autoexec_tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(content)
    f:close()
    root_exec("cp '" .. tmp .. "' '" .. dir .. "/" .. filename .. "'")
    root_exec("chmod 644 '" .. dir .. "/" .. filename .. "'")
    os.remove(tmp)
    return true
end

local function autoexec_remove(st, pkg, filename, executor)
    local dir = autoexec_dir(pkg, executor)
    root_exec("rm -f '" .. dir .. "/" .. filename .. "'")
    return true
end

-- ---------------------------------------------------------------- account detect
local function detect_user_id(pkg)
    local roots = {
        "/data/data/" .. pkg .. "/shared_prefs/",
        "/data/user/0/" .. pkg .. "/shared_prefs/",
    }
    for _, r in ipairs(roots) do
        local out = root("grep -rho 'userId[^0-9]*\\([0-9]\\{5,\\}\\)' '" .. r .. "' 2>/dev/null | head -1")
        local id = out:match("(%d+)")
        if id then return tonumber(id) end
    end
    return nil
end

local function detect_cookie(pkg)
    local paths = {
        "/data/data/" .. pkg .. "/app_webview/Default/Cookies",
        "/data/data/" .. pkg .. "/files/appData/rbx-storage.db",
    }
    for _, p in ipairs(paths) do
        local out = root("strings '" .. p .. "' 2>/dev/null | grep -o '\\.ROBLOSECURITY[[:space:]]*[A-Z0-9_%-]\\{50,\\}' | head -1")
        local c = out:match("(%-?[A-Z0-9_%-]+)$")
        if c and #c > 50 then return c end
    end
    return nil
end

-- ---------------------------------------------------------------- low graphics / screen
local function set_low_graphics(pkg)
    local f = "/data/data/" .. pkg .. "/files/appData/ClientSettings/IxpSettings.json"
    root_exec("chmod 666 '" .. f .. "' 2>/dev/null")
    root_exec("sed -i 's/\"DFIntTaskSchedulerTargetFps\"[^,}]*/\"DFIntTaskSchedulerTargetFps\":30/' '" .. f .. "' 2>/dev/null")
    root_exec("chmod 444 '" .. f .. "' 2>/dev/null")
end

local function keep_screen_awake(on)
    if on then
        root_exec("svc power stayon true")
    else
        root_exec("svc power stayon false")
    end
end

-- ---------------------------------------------------------------- cache clear
local CACHE_PATHS = {
    "/cache", "/code_cache",
    "/files/appData/rbx-storage-sc",
}

local function clear_cache(pkg)
    local parts = {}
    for _, sub in ipairs(CACHE_PATHS) do
        parts[#parts+1] = "rm -rf '/data/data/" .. pkg .. sub .. "'/* 2>/dev/null"
    end
    root_exec(table.concat(parts, "; "))
    return true
end

local function clear_cache_all(st)
    for _, e in ipairs(st.roblox_packages) do
        if e.enabled then clear_cache(e.package) end
    end
end

-- ---------------------------------------------------------------- termux minimize
local function find_termux_task()
    local out = root("dumpsys activity activities 2>/dev/null | grep -oE 'taskId=[0-9]+.*com\\.termux|com\\.termux.*taskId=[0-9]+'")
    if out == "" then
        out = shell("dumpsys activity activities 2>/dev/null | grep -B2 'com.termux' | grep -oE '#[0-9]+' | head -1")
    end
    return tonumber(out:match("(%d+)"))
end

local function minimize_termux()
    local tid = find_termux_task()
    if not tid then return false, "no_task" end
    root_exec("cmd activity set-task-windowing-mode " .. tid .. " 5 2>/dev/null")
    root_exec("cmd activity resize-task " .. tid .. " 0 0 1 1 2>/dev/null")
    return true, tid
end

-- ---------------------------------------------------------------- boot
local BOOT_DIR = HOME .. "/.termux/boot"

local function termux_boot_install(st)
    ensure_dir(BOOT_DIR)
    local f = io.open(BOOT_DIR .. "/limbo.sh", "w")
    if not f then return false end
    f:write("#!/data/data/com.termux/files/usr/bin/sh\n")
    f:write("termux-wake-lock\n")
    f:write("lua " .. HOME .. "/limbo.lua\n")
    f:close()
    os.execute("chmod 755 '" .. BOOT_DIR .. "/limbo.sh'")
    st.termux_boot_enabled = true
    return true
end

local function termux_boot_remove(st)
    os.remove(BOOT_DIR .. "/limbo.sh")
    st.termux_boot_enabled = false
    return true
end

-- ---------------------------------------------------------------- engine
local function fmt_uptime(sec)
    if not sec or sec < 0 then sec = 0 end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if h > 0 then return string.format("%dh%dm", h, m) end
    if m > 0 then return string.format("%dm%ds", m, s) end
    return string.format("%ds", s)
end

local function run_engine(st)
    local names = {}
    for _, e in ipairs(st.roblox_packages) do
        if e.enabled then names[#names+1] = e.package end
    end
    table.sort(names)
    if #names == 0 then
        header("Start"); err("no package enabled."); pause(); return
    end
    if st.private_server_url == "" then
        header("Start"); err("no private server url.")
        print("run setup first."); pause(); return
    end
    local sw, sh, dens = detect_screen()
    if not sw then
        header("Start"); err("failed to read screen size."); pause(); return
    end
    local inset = math.ceil(24 * (dens or 320) / 160)

    -- freeform once per boot
    local fok, fmsg = freeform_enable_once(st)
    save_state(st)

    -- start prep: cache clear + keep awake
    if st.keep_screen_awake then keep_screen_awake(true) end
    clear_cache_all(st)

    -- initial launch
    header("Start  >  launching")
    print(string.format("screen %dx%d  inset %d  freeform: %s", sw, sh, inset, fok and "enabled" or tostring(fmsg)))
    print("")
    local st_map = {}
    for i, name in ipairs(names) do
        local rect = { grid_bounds(i, #names, sw, sh, inset) }
        apply_clone_prefs(name, rect[1], rect[2], rect[3], rect[4])
        if st.low_graphics_enabled then set_low_graphics(name) end
        print(string.format("  [%d/%d] %s", i, #names, name))
        io.flush()
        local entry
        for _, e in ipairs(st.roblox_packages) do if e.package == name then entry = e end end
        local url = (entry and entry.private_server_url ~= "" and entry.private_server_url) or st.private_server_url
        local pid = pidof(name)
        if pid then
            record_trace(st, "events", { package = name, event = "start_skip", reason = "already_running" })
        else
            launch_package(st, name, url, rect)
        end
        st_map[name] = { born = now(), joined = now(), disc_key = nil, halted = false, status = "join", fails = 0 }
        if i < #names then sleep(st.launch_delay_seconds) end
    end
    save_state(st)

    -- monitor loop
    local quit = false
    local last_status = 0
    local restart_window = {}
    local SCAN = math.max(5, st.health_check_interval_seconds)
    local next_scan = 0
    while not quit do
        local t = now()
        if t >= next_scan then
            next_scan = t + SCAN
            local any_action = false
            for _, name in ipairs(names) do
                local s = st_map[name]
                if not s.halted then
                    local pid = pidof(name)
                    local need_relaunch, reason = false, nil
                    if not pid then
                        if (t - s.born) >= st.foreground_grace_seconds then
                            need_relaunch, reason = true, "dead"
                        end
                    else
                        local code, key = logcat_pid_disconnect(pid)
                        if code and key ~= s.disc_key then
                            s.disc_key = key
                            if st.stop_codes[code] then
                                s.halted = true
                                record_trace(st, "halts", { package = name, code = code })
                                log("HALT " .. name .. " code " .. code)
                                webhook_send(st, string.format("**HALT** `%s` code `%d`", name, code))
                            else
                                need_relaunch, reason = true, "code " .. code
                                record_trace(st, "events", { package = name, event = "disconnect", code = code })
                            end
                        end
                    end
                    if need_relaunch then
                        -- restart-per-hour cap
                        restart_window[name] = restart_window[name] or {}
                        local w = restart_window[name]
                        while #w > 0 and (t - w[1]) > 3600 do table.remove(w, 1) end
                        if #w >= st.max_restart_attempts_per_hour then
                            s.halted = true
                            record_trace(st, "halts", { package = name, reason = "restart_cap" })
                            log("HALT " .. name .. " (restart cap)")
                        else
                            -- backoff on consecutive failures
                            s.fails = s.fails + 1
                            local wait = backoff_seconds(s.fails, st.backoff_min_seconds, st.backoff_max_seconds)
                            if (t - s.born) >= wait or reason == "dead" then
                                relaunch(st, name, reason)
                                s.born = t
                                s.fails = 0
                                table.insert(w, t)
                                any_action = true
                                webhook_send(st, string.format("**REJOIN** `%s` reason `%s`", name, tostring(reason)))
                            end
                        end
                    end
                end
            end
            if any_action then save_state(st) end
            if t - last_status >= 60 then
                last_status = t
                for _, name in ipairs(names) do
                    local s = st_map[name]
                    st.status[name] = {
                        package = name,
                        alive = pidof(name) ~= nil,
                        halted = s.halted,
                        uptime = fmt_uptime(t - s.joined),
                        last_relaunch = s.born,
                    }
                end
                save_state(st)
                if webhook_should_send(st) then
                    local parts = {}
                    for _, name in ipairs(names) do
                        local pid = pidof(name)
                        parts[#parts+1] = string.format("%s: %s", name, pid and ("up " .. fmt_uptime(t - st_map[name].joined)) or "down")
                    end
                    webhook_send(st, "**Limbo status**\n" .. table.concat(parts, "\n"))
                end
            end
        end
        -- redraw
        header("Running  [" .. (st.device_name ~= "" and st.device_name or "device") .. "]")
        print(string.format("  scan every %ds   grace %ds   url %s",
            SCAN, st.foreground_grace_seconds, st.private_server_url ~= "" and "set" or "none"))
        print("")
        print(string.format("  %-22s %-8s %-10s %s", "package", "pid", "uptime", "status"))
        for _, name in ipairs(names) do
            local s = st_map[name]
            local pid = pidof(name)
            local mark = s.halted and "HALTED" or (pid and "in-game?" or "dead")
            print(string.format("  %-22s %-8s %-10s %s",
                name, pid and tostring(pid) or "-", fmt_uptime(t - s.joined), mark))
        end
        print("")
        warn("  press q + enter to stop")
        io.flush()
        io.write("> "); io.flush()
        local k = read_line()
        if k and (k:lower() == "q" or k:lower() == "quit" or k:lower() == "0") then quit = true end
    end
    for _, name in ipairs(names) do st.status[name] = nil end
    save_state(st)
    header("Stopped")
    print("engine stopped.")
    pause()
end

-- ---------------------------------------------------------------- main menu
local function screen_status(st)
    header("Status")
    local sw, sh = detect_screen()
    if sw then print(string.format("device: %s   screen: %dx%d", st.device_name, sw, sh)) end
    print("state file: " .. STATE_PATH)
    print("")
    section("packages (" .. #st.roblox_packages .. ")")
    if #st.roblox_packages == 0 then
        emit("(none, run setup)")
    else
        for i, e in ipairs(st.roblox_packages) do
            local pid = pidof(e.package)
            emit(string.format("%d. %-22s %s", i, e.package,
                pid and ("pid " .. pid) or "stopped"))
        end
    end
    print("")
    print("url: " .. (st.private_server_url ~= "" and st.private_server_url:sub(1, 40) .. ".." or "(none)"))
    print("")
    local tr = st.trace
    print("trace: launches=" .. #tr.launches .. "  relaunches=" .. #tr.relaunches .. "  halts=" .. #tr.halts)
    pause()
end

local function screen_settings(st)
    header("Settings")
    menuitem("1", "Device name      : " .. st.device_name)
    menuitem("2", "Prefix           : " .. st.prefix)
    menuitem("3", "Private server   : " .. (st.private_server_url ~= "" and "set" or "(none)"))
    menuitem("4", "Scan interval    : " .. st.health_check_interval_seconds .. "s")
    menuitem("5", "Reconnect delay  : " .. st.reconnect_delay_seconds .. "s")
    menuitem("6", "Launch delay     : " .. st.launch_delay_seconds .. "s")
    menuitem("7", "Foreground grace : " .. st.foreground_grace_seconds .. "s")
    menuitem("8", "Webhook          : " .. (st.webhook_enabled and st.webhook_url:sub(1, 24) or "off"))
    menuitem("0", "Back")
    print("")
    local c = ask("select", "0")
    if c == "1" then st.device_name = ask("device name", st.device_name); save_state(st)
    elseif c == "2" then st.prefix = ask("prefix", st.prefix); save_state(st)
    elseif c == "3" then
        local u = ask("url", st.private_server_url)
        if u and u:match("code=") then st.private_server_url = u end
        save_state(st)
    elseif c == "4" then st.health_check_interval_seconds = tonumber(ask("scan seconds", tostring(st.health_check_interval_seconds))) or st.health_check_interval_seconds; save_state(st)
    elseif c == "5" then st.reconnect_delay_seconds = tonumber(ask("reconnect delay", tostring(st.reconnect_delay_seconds))) or st.reconnect_delay_seconds; save_state(st)
    elseif c == "6" then st.launch_delay_seconds = tonumber(ask("launch delay", tostring(st.launch_delay_seconds))) or st.launch_delay_seconds; save_state(st)
    elseif c == "7" then st.foreground_grace_seconds = tonumber(ask("grace", tostring(st.foreground_grace_seconds))) or st.foreground_grace_seconds; save_state(st)
    elseif c == "8" then
        local u = ask("webhook url", st.webhook_url)
        if u then st.webhook_url = u; st.webhook_enabled = (u ~= "") end
        save_state(st)
    end
end

local function screen_tools(st)
    while true do
        header("Tools")
        menuitem("1", "Auto-execute: add script")
        menuitem("2", "Auto-execute: remove all")
        menuitem("3", "Clear cache (all clones)")
        menuitem("4", "Minimize Termux")
        menuitem("5", "Termux boot: " .. (st.termux_boot_enabled and "ON" or "off"))
        menuitem("6", "Detect accounts (userid/cookie)")
        menuitem("7", "Keep screen awake: " .. (st.keep_screen_awake and "ON" or "off"))
        menuitem("8", "Low graphics: " .. (st.low_graphics_enabled and "ON" or "off"))
        menuitem("0", "Back")
        print("")
        local c = ask("select", "0")
        if c == "0" or c == nil then return end
        if c == "1" then
            header("Auto-execute")
            local names = {}
            for _, e in ipairs(st.roblox_packages) do if e.enabled then names[#names+1] = e.package end end
            if #names == 0 then print("no package."); pause()
            else
                print("script will be written to each clone's Autoexecute folder.")
                print("")
                local fn = ask("filename", "limbo.lua")
                print("")
                print("paste script content (single line ok), or blank to cancel:")
                local content = read_line()
                if content and trim(content) ~= "" then
                    local okc = 0
                    for _, p in ipairs(names) do
                        if autoexec_write(st, p, fn, content) then okc = okc + 1 end
                    end
                    st.auto_execute_scripts[fn] = content
                    save_state(st)
                    ok("written to " .. okc .. " clone(s).")
                else print("cancelled.") end
                pause()
            end
        elseif c == "2" then
            local names = {}
            for _, e in ipairs(st.roblox_packages) do if e.enabled then names[#names+1] = e.package end end
            for fn in pairs(st.auto_execute_scripts) do
                for _, p in ipairs(names) do autoexec_remove(st, p, fn) end
            end
            st.auto_execute_scripts = {}
            save_state(st)
            header("Auto-execute"); ok("removed all managed scripts."); pause()
        elseif c == "3" then
            header("Cache")
            print("clearing cache for all enabled clones...")
            clear_cache_all(st)
            ok("done."); pause()
        elseif c == "4" then
            header("Minimize Termux")
            local ok, tid = minimize_termux()
            if ok then ok("termux task " .. tostring(tid) .. " minimized.")
            else err("failed: " .. tostring(tid)) end
            pause()
        elseif c == "5" then
            if st.termux_boot_enabled then termux_boot_remove(st) else termux_boot_install(st) end
            save_state(st)
            header("Boot"); ok("boot: " .. (st.termux_boot_enabled and "ON" or "off")); pause()
        elseif c == "6" then
            header("Accounts")
            print("scanning...")
            print("")
            for _, e in ipairs(st.roblox_packages) do
                local uid = detect_user_id(e.package)
                local ck = detect_cookie(e.package)
                print(string.format("%-22s userid=%s cookie=%s",
                    e.package, uid and tostring(uid) or "-", ck and "found" or "-"))
            end
            pause()
        elseif c == "7" then
            st.keep_screen_awake = not st.keep_screen_awake
            keep_screen_awake(st.keep_screen_awake)
            save_state(st)
            header("Screen"); ok("keep awake: " .. (st.keep_screen_awake and "ON" or "off")); pause()
        elseif c == "8" then
            st.low_graphics_enabled = not st.low_graphics_enabled
            save_state(st)
            header("Graphics"); ok("low graphics: " .. (st.low_graphics_enabled and "ON" or "off")); pause()
        end
    end
end

local function screen_menu(st)
    while true do
        header("Main")
        section("device")
        emit("name  : " .. (st.device_name ~= "" and st.device_name or "(not set)"))
        emit("pkgs  : " .. #st.roblox_packages .. " selected")
        emit("url   : " .. (st.private_server_url ~= "" and "set" or "not set"))
        emit("state : " .. (st.first_setup_completed and "configured" or "setup needed"))
        print("")
        menuitem("1", "Start engine")
        menuitem("2", "Setup wizard")
        menuitem("3", "Status")
        menuitem("4", "Settings")
        menuitem("5", "Tools")
        menuitem("6", "Freeform check")
        menuitem("7", "View state file")
        menuitem("0", "Exit")
        print("")
        local c = ask("select", "0")
        if c == "0" or c == nil then return "exit"
        elseif c == "1" then run_engine(st)
        elseif c == "2" then wizard_run(st)
        elseif c == "3" then screen_status(st)
        elseif c == "4" then screen_settings(st)
        elseif c == "5" then screen_tools(st)
        elseif c == "6" then
            header("Freeform")
            print("freeform settings (read-only):")
            print("")
            for _, r in ipairs(freeform_status()) do
                print(string.format("  %-34s = %s", r.key, r.value ~= "" and r.value or "(unset)"))
            end
            print("")
            print("configured_at: " .. (st.runtime.freeform_configured_at or "(not yet this session)"))
            pause()
        elseif c == "7" then
            header("State file")
            print(STATE_PATH)
            print("")
            local raw = read_file(STATE_PATH)
            if raw then
                local shown = 0
                for l in raw:gmatch("[^\n]+") do
                    print(l:sub(1, IN - 2))
                    shown = shown + 1
                    if shown >= 30 then print("..."); break end
                end
            else
                print("(no state file yet)")
            end
            pause()
        end
    end
end

-- ---------------------------------------------------------------- main
if _G.LIMBO_NO_MAIN then
    return {
        HOME = HOME, STATE_PATH = STATE_PATH, DATA_DIR = DATA_DIR, LOG_PATH = LOG_PATH,
        DEFAULT_STATE = DEFAULT_STATE,
        json = json, trim = trim, split = split,
        shell = shell, root = root, root_exec = root_exec, has_root = has_root,
        sleep = sleep, now = now, iso = iso, log = log, ensure_dir = ensure_dir,
        load_state = load_state, save_state = save_state, record_trace = record_trace,
        read_file = read_file, write_file_atomic = write_file_atomic,
        detect_screen = detect_screen, detect_packages = detect_packages,
        pidof = pidof, read_username = read_username,
        grid_bounds = grid_bounds, apply_clone_prefs = apply_clone_prefs,
        freeform_status = freeform_status, freeform_enable_once = freeform_enable_once,
        build_deeplink = build_deeplink, launch_package = launch_package,
        get_task_id = get_task_id, get_stack_id = get_stack_id,
        read_bounds = read_bounds, direct_resize = direct_resize,
        logcat_pid_disconnect = logcat_pid_disconnect, presence_check = presence_check,
        pick_rect = pick_rect, relaunch = relaunch,
        wizard_run = wizard_run,
        backoff_seconds = backoff_seconds, webhook_send = webhook_send,
        autoexec_dir = autoexec_dir, autoexec_write = autoexec_write,
        detect_user_id = detect_user_id, detect_cookie = detect_cookie,
        clear_cache = clear_cache, clear_cache_all = clear_cache_all,
        minimize_termux = minimize_termux, termux_boot_install = termux_boot_install,
        set_low_graphics = set_low_graphics, keep_screen_awake = keep_screen_awake,
    }
end

local function main()
    local st = load_state()
    if st.device_name == "" then
        st.device_name = trim(shell("getprop ro.product.model"))
        if st.device_name == "" then st.device_name = "Redfinger" end
    end
    st.runtime.started_at = iso()
    st.runtime.pid = tostring(shell("echo $$"))
    save_state(st)
    log("limbo started")
    while true do
        if screen_menu(st) == "exit" then break end
    end
    st.runtime.stopped_at = iso()
    save_state(st)
    os.exit(0)
end

if not _G.LIMBO_NO_MAIN then main() end
