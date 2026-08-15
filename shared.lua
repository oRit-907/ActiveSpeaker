--[[
    Console helpers and config validation, shared by the client and the server.

    Every option in config.lua is checked once on start. A bad value is put back
    to its default rather than being left to break something later, and each fix
    is printed with the option name and what it was changed to, so a typo shows
    up in the console instead of as a missing label nobody can explain.
]]

local PREFIX = '^5[ActiveSpeaker]^7 '

function ASPrint(message)
    print(PREFIX .. message)
end

function ASWarn(message)
    print(PREFIX .. '^3' .. message .. '^7')
end

function ASError(message)
    print(PREFIX .. '^1' .. message .. '^7')
end

function ASDebug(message)
    if Config.Debug then
        print(PREFIX .. '^6debug^7 ' .. message)
    end
end

-- Looks a locale string up, falling back to English and then to the key itself,
-- so a half translated locale still shows something readable.
function L(key)
    local locale = Locales[Config.Locale] or Locales.en

    return locale[key] or Locales.en[key] or key
end

-- ============================================================================
-- Validation
-- ============================================================================

local problems = {}

local function fix(key, value, reason)
    problems[#problems + 1] = ('Config.%s %s, using %s'):format(key, reason, tostring(value))
    return value
end

local function asNumber(key, default, min, max)
    local value = tonumber(Config[key])

    if value == nil then
        Config[key] = fix(key, default, 'is not a number')
        return
    end

    if min and value < min then
        Config[key] = fix(key, min, ('is below the minimum of %s'):format(min))
        return
    end

    if max and value > max then
        Config[key] = fix(key, max, ('is above the maximum of %s'):format(max))
        return
    end

    Config[key] = value
end

local function asBool(key, default)
    if type(Config[key]) ~= 'boolean' then
        Config[key] = fix(key, default, 'is not true or false')
    end
end

-- Clamps a { r, g, b, a } table in place. Returns nil when it is past saving,
-- so the caller can drop in its own default.
local function normalizeColor(value, name)
    if type(value) ~= 'table' then
        return nil
    end

    -- Three channels is the easiest mistake to make here, and the colour would
    -- be fully transparent without the fourth, so fill it in rather than
    -- throwing the whole thing away.
    if #value == 3 then
        value[4] = 255
        problems[#problems + 1] = ('Config.%s had no alpha, using 255'):format(name)
    end

    for i = 1, 4 do
        local channel = tonumber(value[i])

        if channel == nil then
            return nil
        end

        value[i] = math.max(0, math.min(255, math.floor(channel)))
    end

    return value
end

local function asColor(key, default)
    if not normalizeColor(Config[key], key) then
        Config[key] = fix(key, default, 'is not a { r, g, b, a } table of numbers')
    end
end

local function asChoice(key, default, allowed)
    local value = Config[key]

    if type(value) == 'string' then
        value = value:lower()
    end

    for _, option in ipairs(allowed) do
        if value == option then
            Config[key] = value
            return
        end
    end

    Config[key] = fix(key, default, ("is not one of '" .. table.concat(allowed, "', '") .. "'"))
end

-- Same checks, one level down, for the nested Icon and List tables.
local function asSubNumber(tbl, name, key, default, min, max)
    local value = tonumber(tbl[key])

    if value == nil then
        tbl[key] = fix(name .. '.' .. key, default, 'is not a number')
        return
    end

    if min and value < min then
        tbl[key] = fix(name .. '.' .. key, min, ('is below the minimum of %s'):format(min))
        return
    end

    if max and value > max then
        tbl[key] = fix(name .. '.' .. key, max, ('is above the maximum of %s'):format(max))
        return
    end

    tbl[key] = value
end

local function asSubBool(tbl, name, key, default)
    if type(tbl[key]) ~= 'boolean' then
        tbl[key] = fix(name .. '.' .. key, default, 'is not true or false')
    end
end

-- Returns the icon table when it is usable, or nil with a reason recorded.
local function checkIcon(icon, name)
    if type(icon) ~= 'table'
        or type(icon.dict) ~= 'string'
        or type(icon.texture) ~= 'string' then
        problems[#problems + 1] = ('Config.%s needs a dict and a texture'):format(name)
        return nil
    end

    icon.size = tonumber(icon.size) or 0.06

    if icon.size <= 0 then
        problems[#problems + 1] = ('Config.%s.size is not above zero'):format(name)
        return nil
    end

    return icon
end

local function asCommand(key, default)
    -- false is a valid answer, it removes the command.
    if Config[key] == false then return end

    if type(Config[key]) ~= 'string' or Config[key] == '' then
        Config[key] = fix(key, default, 'is not a command name or false')
        return
    end

    Config[key] = Config[key]:gsub('^/', '')
end

local function asLabel(key, localeKey)
    local value = Config[key]

    if type(value) ~= 'string' or value == '' then
        Config[key] = L(localeKey)
    end
end

local function validate()
    -- Locale first, the label defaults are read out of it.
    if type(Config.Locale) ~= 'string' or not Locales[Config.Locale] then
        Config.Locale = fix('Locale', 'en', 'is not a locale in locales.lua')
    end

    asLabel('Label', 'speaking')
    asLabel('RadioLabel', 'radio')

    asColor('Color', { 255, 255, 255, 230 })
    asColor('RadioColor', { 90, 200, 255, 230 })

    asNumber('HeightOffset', 1.15, -5.0, 10.0)
    asNumber('VehicleHeightOffset', 0.25, -5.0, 10.0)
    asNumber('Font', 4, 0, 7)
    asBool('Outline', true)
    asBool('Shadow', false)

    asNumber('MinScale', 0.18, 0.0, 2.0)
    asNumber('MaxScale', 0.55, 0.01, 5.0)

    -- Crossed over, the label would be pinned to whichever was checked last.
    if Config.MinScale > Config.MaxScale then
        Config.MinScale, Config.MaxScale = Config.MaxScale, Config.MinScale
        problems[#problems + 1] = 'Config.MinScale was above Config.MaxScale, they have been swapped'
    end

    asNumber('PulseAmount', 0.15, 0.0, 5.0)
    asNumber('PulseSpeed', 200, 1, 100000)
    asNumber('HoldTime', 400, 0, 10000)
    asNumber('FadeTime', 200, 0, 10000)

    asBool('ShowIcon', true)

    if Config.ShowIcon and not checkIcon(Config.Icon, 'Icon') then
        Config.ShowIcon = false
        problems[#problems + 1] = 'the icon is off'
    end

    -- nil is a valid answer, it means use the same icon on the radio.
    if Config.RadioIcon ~= nil and not checkIcon(Config.RadioIcon, 'RadioIcon') then
        Config.RadioIcon = nil
        problems[#problems + 1] = 'the radio icon falls back to Config.Icon'
    end

    asNumber('MaxDistance', 20.0, 1.0, 500.0)
    asNumber('FadeStart', 0.75, 0.0, 1.0)
    asBool('MatchVoiceRange', false)
    asBool('RequireLineOfSight', false)
    asNumber('OccludedAlpha', 0.35, 0.0, 1.0)
    asBool('IgnoreInvisible', true)
    asBool('HideWhenDead', true)
    asBool('HideInPauseMenu', true)
    asBool('ShowSelf', false)
    asNumber('MaxLabels', 0, 0, 128)
    asNumber('ScanInterval', 200, 50, 5000)

    asBool('ShowRadio', true)

    asBool('ShowList', false)

    if type(Config.List) ~= 'table' then
        Config.List = {}
        problems[#problems + 1] = 'Config.List is not a table, the list uses its defaults'
    end

    asSubNumber(Config.List, 'List', 'x', 0.015, 0.0, 1.0)
    asSubNumber(Config.List, 'List', 'y', 0.30, 0.0, 1.0)
    asSubNumber(Config.List, 'List', 'scale', 0.35, 0.05, 2.0)
    asSubNumber(Config.List, 'List', 'lineHeight', 0.026, 0.005, 0.5)
    asSubNumber(Config.List, 'List', 'rows', 5, 1, 32)
    asSubNumber(Config.List, 'List', 'width', 0.16, 0.01, 1.0)
    asSubNumber(Config.List, 'List', 'padding', 0.008, 0.0, 0.1)
    asSubBool(Config.List, 'List', 'background', true)
    asSubBool(Config.List, 'List', 'title', true)

    if not normalizeColor(Config.List.backgroundColor, 'List.backgroundColor') then
        Config.List.backgroundColor = { 0, 0, 0, 120 }
        problems[#problems + 1] = 'Config.List.backgroundColor is not a { r, g, b, a } table of numbers, using black'
    end

    asCommand('ToggleCommand', 'activespeaker')
    asCommand('AdminCommand', 'asmute')
    asCommand('StatusCommand', 'asstatus')

    asBool('RememberToggle', true)
    asChoice('Notify', 'auto', { 'auto', 'chat', 'ox_lib', 'none' })

    asBool('ShowNames', true)
    asNumber('NameRefreshInterval', 0, 0, 3600000)
    asChoice('Framework', 'auto', { 'auto', 'qbcore', 'qbox', 'esx', 'none' })

    asBool('VersionCheck', true)

    if type(Config.VersionUrl) ~= 'string' or Config.VersionUrl == '' then
        Config.VersionCheck = false
        problems[#problems + 1] = 'Config.VersionUrl is not a url, the update check is off'
    end

    asBool('EnableStealthMode', true)
end

if type(Config) ~= 'table' then
    -- Nothing below can run without it, and the error this prints is a lot
    -- easier to act on than the nil index the rest of the resource would throw.
    Config = {}
    ASError('config.lua did not load, every option is on its default')
end

if type(Locales) ~= 'table' then
    Locales = { en = {} }
    ASError('locales.lua did not load, labels fall back to their config values')
end

if type(Config.Debug) ~= 'boolean' then
    Config.Debug = false
end

validate()

-- The server console is where an owner will actually see this. Clients only
-- print it with Debug on, otherwise every player gets the same warnings in F8.
if #problems > 0 and (IsDuplicityVersion() or Config.Debug) then
    ASWarn(('%d config %s corrected:'):format(#problems, #problems == 1 and 'problem' or 'problems'))

    for _, problem in ipairs(problems) do
        ASWarn('  - ' .. problem)
    end
end
