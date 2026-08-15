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

local function asColor(key, default)
    local value = Config[key]

    if type(value) ~= 'table' then
        Config[key] = fix(key, default, 'is not a { r, g, b, a } table')
        return
    end

    -- Three channels is the easiest mistake to make here, and the label would
    -- be fully transparent without the fourth, so fill it in rather than
    -- throwing the whole colour away.
    if #value == 3 then
        value[4] = 255
        problems[#problems + 1] = ('Config.%s had no alpha, using 255'):format(key)
    end

    for i = 1, 4 do
        local channel = tonumber(value[i])

        if channel == nil then
            Config[key] = fix(key, default, 'has a channel that is not a number')
            return
        end

        value[i] = math.max(0, math.min(255, math.floor(channel)))
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

    asNumber('PulseAmount', 0.15, 0.0, 5.0)
    asNumber('PulseSpeed', 200, 1, 100000)

    asBool('ShowIcon', true)

    if type(Config.Icon) ~= 'table'
        or type(Config.Icon.dict) ~= 'string'
        or type(Config.Icon.texture) ~= 'string' then
        Config.ShowIcon = false
        problems[#problems + 1] = 'Config.Icon needs a dict and a texture, the icon is off'
    else
        Config.Icon.size = tonumber(Config.Icon.size) or 0.06

        if Config.Icon.size <= 0 then
            Config.ShowIcon = false
            problems[#problems + 1] = 'Config.Icon.size is not above zero, the icon is off'
        end
    end

    asNumber('MaxDistance', 20.0, 1.0, 500.0)
    asNumber('FadeStart', 0.75, 0.0, 1.0)
    asBool('MatchVoiceRange', false)
    asBool('RequireLineOfSight', false)
    asBool('IgnoreInvisible', true)
    asBool('ShowSelf', false)
    asNumber('MaxLabels', 0, 0, 128)
    asNumber('ScanInterval', 200, 50, 5000)

    asBool('ShowRadio', true)

    -- false is a valid answer here, it removes the command.
    if Config.ToggleCommand ~= false then
        if type(Config.ToggleCommand) ~= 'string' or Config.ToggleCommand == '' then
            Config.ToggleCommand = fix('ToggleCommand', 'activespeaker', 'is not a command name or false')
        else
            Config.ToggleCommand = Config.ToggleCommand:gsub('^/', '')
        end
    end

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
