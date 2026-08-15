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

print(failures == 0 and '\nALL PASS' or ('\n' .. failures .. ' FAILURES'))
os.exit(failures == 0 and 0 or 1)
