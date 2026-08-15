-- Harness: loads the shared files the way FiveM would and checks validation.
local ROOT = os.getenv('AS_ROOT') or '../'

function IsDuplicityVersion() return true end

local function load(file)
    local chunk = assert(loadfile(ROOT .. file))
    chunk()
end

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(('  FAIL %s: got %s, want %s'):format(label, tostring(got), tostring(want)))
    else
        print(('  ok   %s = %s'):format(label, tostring(got)))
    end
end

-- ---------------------------------------------------------------- defaults
print('\n== default config ==')
load('config.lua')
load('locales.lua')
load('shared.lua')

check('Label', Config.Label, 'Speaking...')
check('RadioLabel', Config.RadioLabel, 'Radio')
check('MaxDistance', Config.MaxDistance, 20.0)
check('ScanInterval', Config.ScanInterval, 200)
check('ToggleCommand', Config.ToggleCommand, 'activespeaker')
check('L(toggle_on)', L('toggle_on'), 'Speaker labels are now on.')

-- ---------------------------------------------------------------- locale
print('\n== locale de ==')
load('config.lua')
Config.Locale = 'de'
load('shared.lua')
check('Label', Config.Label, 'Spricht...')
check('RadioLabel', Config.RadioLabel, 'Funk')

-- ---------------------------------------------------------------- overrides win
print('\n== explicit label beats locale ==')
load('config.lua')
Config.Locale = 'de'
Config.Label = 'Talking'
load('shared.lua')
check('Label', Config.Label, 'Talking')
check('RadioLabel', Config.RadioLabel, 'Funk')

-- ---------------------------------------------------------------- broken config
print('\n== broken config gets corrected ==')
load('config.lua')
Config.Locale = 'klingon'
Config.Color = { 255, 0, 0 }          -- missing alpha
Config.MaxDistance = -5               -- below minimum
Config.PulseSpeed = 'fast'            -- not a number
Config.FadeStart = 2.5                -- above maximum
Config.Framework = 'qb'               -- typo
Config.Notify = 'popup'               -- not a mode
Config.ShowSelf = 'yes'               -- not a boolean
Config.ScanInterval = 1               -- too low
Config.Icon = { dict = 'x' }          -- no texture
Config.ToggleCommand = '/speak'       -- leading slash
Config.MaxLabels = 500                -- above maximum
load('shared.lua')

check('Locale', Config.Locale, 'en')
check('Color alpha', Config.Color[4], 255)
check('MaxDistance', Config.MaxDistance, 1.0)
check('PulseSpeed', Config.PulseSpeed, 200)
check('FadeStart', Config.FadeStart, 1.0)
check('Framework', Config.Framework, 'auto')
check('Notify', Config.Notify, 'auto')
check('ShowSelf', Config.ShowSelf, false)
check('ScanInterval', Config.ScanInterval, 50)
check('ShowIcon', Config.ShowIcon, false)
check('ToggleCommand', Config.ToggleCommand, 'speak')
check('MaxLabels', Config.MaxLabels, 128)
check('Label still set', Config.Label, 'Speaking...')

-- ---------------------------------------------------------------- toggle off
print('\n== ToggleCommand = false is kept ==')
load('config.lua')
Config.ToggleCommand = false
load('shared.lua')
check('ToggleCommand', Config.ToggleCommand, false)

-- ---------------------------------------------------------------- colours clamp
print('\n== colour channels clamp ==')
load('config.lua')
Config.Color = { 300, -20, 12.7, 999 }
load('shared.lua')
check('r', Config.Color[1], 255)
check('g', Config.Color[2], 0)
check('b', Config.Color[3], 12)
check('a', Config.Color[4], 255)

-- ---------------------------------------------------------------- scale
print('\n== scale clamps ==')
load('config.lua')
load('shared.lua')
check('MinScale', Config.MinScale, 0.18)
check('MaxScale', Config.MaxScale, 0.55)

load('config.lua')
Config.MinScale = 0.9
Config.MaxScale = 0.2
load('shared.lua')
check('crossed over, min', Config.MinScale, 0.2)
check('crossed over, max', Config.MaxScale, 0.9)

-- ---------------------------------------------------------------- timing
print('\n== hold and fade ==')
load('config.lua')
Config.HoldTime = -100
Config.FadeTime = 'slow'
load('shared.lua')
check('HoldTime', Config.HoldTime, 0)
check('FadeTime', Config.FadeTime, 200)

-- ---------------------------------------------------------------- occlusion
print('\n== occluded alpha ==')
load('config.lua')
Config.OccludedAlpha = 5
load('shared.lua')
check('clamped to 1', Config.OccludedAlpha, 1.0)

-- ---------------------------------------------------------------- radio icon
print('\n== radio icon ==')
load('config.lua')
load('shared.lua')
check('kept', Config.RadioIcon.texture, 'leaderboard_audio_1')

load('config.lua')
Config.RadioIcon = { dict = 'x' } -- no texture
load('shared.lua')
check('dropped back to the normal icon', Config.RadioIcon, nil)
check('the normal icon is untouched', Config.ShowIcon, true)

load('config.lua')
Config.RadioIcon = nil
load('shared.lua')
check('nil stays nil', Config.RadioIcon, nil)

load('config.lua')
Config.Icon = { dict = 'x' } -- no texture
load('shared.lua')
check('a broken main icon turns the icon off', Config.ShowIcon, false)

-- ---------------------------------------------------------------- list
print('\n== list ==')
load('config.lua')
Config.List.rows = 0
Config.List.scale = 'big'
Config.List.x = 5
Config.List.background = 'yes'
Config.List.backgroundColor = { 0, 0, 0 }
load('shared.lua')
check('rows', Config.List.rows, 1)
check('scale', Config.List.scale, 0.35)
check('x', Config.List.x, 1.0)
check('background', Config.List.background, true)
check('background alpha filled in', Config.List.backgroundColor[4], 255)

load('config.lua')
Config.List = 'somewhere'
load('shared.lua')
check('a list that is not a table gets defaults', Config.List.rows, 5)
check('and a usable colour', Config.List.backgroundColor[4], 120)

-- ---------------------------------------------------------------- commands
print('\n== commands ==')
load('config.lua')
Config.AdminCommand = '/hide'
Config.StatusCommand = 12
load('shared.lua')
check('leading slash stripped', Config.AdminCommand, 'hide')
check('a number is not a command name', Config.StatusCommand, 'asstatus')

load('config.lua')
Config.AdminCommand = false
Config.StatusCommand = false
load('shared.lua')
check('false is kept for AdminCommand', Config.AdminCommand, false)
check('false is kept for StatusCommand', Config.StatusCommand, false)

-- ---------------------------------------------------------------- locales
print('\n== every locale has every key ==')
load('config.lua')
load('locales.lua')
load('shared.lua')

local missing = 0
for name, locale in pairs(Locales) do
    for key in pairs(Locales.en) do
        if locale[key] == nil then
            missing = missing + 1
            print(('  FAIL %s is missing %s'):format(name, key))
        end
    end
end
check('no missing keys', missing, 0)

print(failures == 0 and '\nALL PASS' or ('\n' .. failures .. ' FAILURES'))
os.exit(failures == 0 and 0 or 1)
