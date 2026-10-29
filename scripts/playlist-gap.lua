-- playlist-gap.lua
-- Мягкий переход между файлами плейлиста.
-- В конце файла mpv замирает на последнем кадре, показывает, что будет дальше,
-- и запускает следующий только после паузы (или после подтверждения).
--
-- Enter — включить следующий сразу
-- Esc   — отменить автопереход и остаться на последнем кадре
--
-- Настройки: script-opts/playlist-gap.conf

local options = require 'mp.options'

local o = {
    enabled = true,
    mode = "countdown",      -- countdown = пауза с обратным отсчётом, ask = ждать нажатия
    delay = 6,               -- секунд паузы перед следующим файлом (mode=countdown)
    manage_keep_open = true, -- скрипт сам включает keep-open там, где есть следующий файл
    font_size = 30,
    bar = true,              -- полоска-индикатор отсчёта
    bar_width = 420,
}
options.read_options(o, "playlist-gap")

-- В исходнике намеренно нет ни одного обратного слэша: теги ASS пишутся
-- через "@", а ass() подставляет настоящий символ.
local BS = string.char(92)
local function ass(s)
    return (s:gsub("@", BS))
end

local overlay = mp.create_osd_overlay("ass-events")
overlay.res_y = 720
overlay.z = 100

local timer = nil
local deadline = 0
local waiting = false
local keys_bound = false
local orig_keep_open = mp.get_property("keep-open") or "no"

local function esc(s)
    -- фигурные скобки в имени файла сломали бы разметку ASS
    s = tostring(s):gsub("%c", " ")
    s = s:gsub("{", "("):gsub("}", ")")
    return s
end

local function next_index()
    local pos = mp.get_property_number("playlist-pos", -1)
    local count = mp.get_property_number("playlist-count", 0)
    if pos < 0 or pos + 1 >= count then return nil end
    return pos + 1
end

local function pretty_title(idx)
    local t = mp.get_property("playlist/" .. idx .. "/title")
    if t and t ~= "" then return t end
    local f = mp.get_property("playlist/" .. idx .. "/filename") or "?"
    local base = f:match("([^" .. BS .. "/]+)$") or f
    base = base:gsub("%.[%a%d]+$", "")
    return base
end

local function bar_ass(frac)
    if not o.bar then return nil end
    local w, h = o.bar_width, 5
    local fw = math.floor(w * frac + 0.5)
    local function box(width, color)
        if width <= 0 then return "" end
        return ass(string.format(
            "{@1c&H%s&@alpha&H20&@bord0@shad0@p1}m 0 0 l %d 0 l %d %d l 0 %d{@p0}",
            color, width, width, h, h))
    end
    return box(fw, "FFFFFF") .. box(w - fw, "606060")
end

local function render()
    local idx = next_index()
    if not idx then return end
    local small = math.floor(o.font_size * 0.7)
    local lines = {}

    lines[#lines + 1] = ass(string.format(
        "{@an2@fs%d@bord2@shad0@1c&HFFFFFF&}Далее:  %s",
        o.font_size, esc(pretty_title(idx))))

    if o.mode == "ask" then
        lines[#lines + 1] = ass(string.format(
            "{@fs%d@bord2@shad0@1c&HBBBBBB&}Enter — включить   ·   Esc — остаться", small))
    else
        local left = math.max(0, deadline - mp.get_time())
        local frac = (o.delay > 0) and math.max(0, math.min(1, left / o.delay)) or 0
        local b = bar_ass(frac)
        if b then lines[#lines + 1] = b end
        lines[#lines + 1] = ass(string.format(
            "{@fs%d@bord2@shad0@1c&HBBBBBB&}через %d с   ·   Enter — сейчас   ·   Esc — отмена",
            small, math.ceil(left)))
    end

    lines[#lines + 1] = " "
    overlay.data = table.concat(lines, ass("@N"))
    overlay:update()
end

local function unbind()
    if not keys_bound then return end
    mp.remove_key_binding("playlist-gap-yes")
    mp.remove_key_binding("playlist-gap-no")
    keys_bound = false
end

local function stop()
    waiting = false
    if timer then timer:kill(); timer = nil end
    unbind()
    overlay:remove()
end

local function play_next()
    stop()
    mp.commandv("playlist-next", "force")
    mp.set_property_bool("pause", false)
end

local function cancel()
    stop()
    mp.osd_message("Автопереход отменён", 2)
end

local function bind()
    if keys_bound then return end
    mp.add_forced_key_binding("ENTER", "playlist-gap-yes", play_next)
    mp.add_forced_key_binding("ESC", "playlist-gap-no", cancel)
    keys_bound = true
end

local function tick()
    if not waiting then return end
    if mp.get_time() >= deadline then
        play_next()
    else
        render()
    end
end

local function start()
    if waiting or not o.enabled then return end
    if not next_index() then return end
    waiting = true
    bind()
    deadline = mp.get_time() + o.delay
    render()
    if o.mode ~= "ask" then
        timer = mp.add_periodic_timer(0.1, tick)
    end
end

-- keep-open включаем только там, где реально есть следующий файл,
-- чтобы одиночные файлы вели себя как раньше.
local function sync_keep_open()
    if not o.manage_keep_open then return end
    if o.enabled and next_index() then
        mp.set_property("keep-open", "always")
        mp.set_property("keep-open-pause", "yes")
    else
        mp.set_property("keep-open", orig_keep_open)
    end
end

mp.observe_property("playlist-pos", "number", sync_keep_open)
mp.observe_property("playlist-count", "number", sync_keep_open)

mp.observe_property("eof-reached", "bool", function(_, v)
    if v then start() else stop() end
end)

mp.register_event("start-file", stop)
mp.register_event("shutdown", stop)

mp.register_script_message("playlist-gap-toggle", function()
    o.enabled = not o.enabled
    if not o.enabled then stop() end
    sync_keep_open()
    mp.osd_message("Мягкий переход: " .. (o.enabled and "вкл" or "выкл"), 2)
end)
