-- Harness: stubs the FiveM natives client.lua uses and drives its threads by
-- hand, so the scan filters and the fade maths can be checked outside the game.
local ROOT = os.getenv('AS_ROOT') or '../'

-- ------------------------------------------------------------------ vector3
local vmt = {}
vmt.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vmt) end
vmt.__len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end

-- ------------------------------------------------------------------- world
local world = {}
local function reset()
    world = {
        me = 1,
        time = 0,
        kvp = {},
        players = {},
        commands = {},
        drawn = {},
        sprites = {},
        rects = {},
        sent = {},
        paused = false,
        faded = false,
        frameTime = 0.1
    }
end

local function addPlayer(index, opts)
    world.players[index] = {
        index = index,
        ped = 1000 + index,
        serverId = 100 + index,
        coords = vector3(opts.x or 0, 0, 0),
        talking = opts.talking ~= false,
        visible = opts.visible ~= false,
        los = opts.los ~= false,
        stealth = opts.stealth or false,
        dead = opts.dead or false,
        state = opts.state or {}
    }
    return world.players[index]
end

local function byPed(ped)
    for _, p in pairs(world.players) do
        if p.ped == ped then return p end
    end
end

-- ----------------------------------------------------------------- natives
function IsDuplicityVersion() return false end
function GetGameTimer() return world.time end
function PlayerId() return world.me end
function PlayerPedId() return world.players[world.me].ped end
function GetPlayerPed(i) return world.players[i] and world.players[i].ped or 0 end
function GetPlayerServerId(i) return world.players[i] and world.players[i].serverId or 0 end
function GetEntityCoords(ped) local p = byPed(ped); return p and p.coords or vector3(0, 0, 0) end
function DoesEntityExist(ped) return byPed(ped) ~= nil end
function IsEntityVisible(ped) local p = byPed(ped); return p and p.visible or false end
function HasEntityClearLosToEntity(_, ped) local p = byPed(ped); return p and p.los or false end
function NetworkIsPlayerTalking(i) return world.players[i] and world.players[i].talking or false end
function IsPedInAnyVehicle() return false end
function IsPedDeadOrDying(ped) local p = byPed(ped); return p and p.dead or false end
function IsPauseMenuActive() return world.paused end
function IsScreenFadedOut() return world.faded end
function GetFrameTime() return world.frameTime end
function GetCurrentResourceName() return 'ActiveSpeaker' end
function GetResourceMetadata() return '2.2.0' end

function GetActivePlayers()
    local list = {}
    for i in pairs(world.players) do list[#list + 1] = i end
    table.sort(list)
    return list
end

function Player(serverId)
    for _, p in pairs(world.players) do
        if p.serverId == serverId then return { state = p.state } end
    end
    return { state = nil }
end

local decors = {}
function DecorRegister() end
function DecorSetBool(ped, name, v) decors[ped .. name] = v end
function DecorExistOn(ped, name)
    local p = byPed(ped)
    if p and p.stealth and (name == 'txylor_stealth') then return true end
    return decors[ped .. name] ~= nil
end
function DecorGetBool(ped, name)
    local p = byPed(ped)
    if p and p.stealth and name == 'txylor_stealth' then return true end
    return decors[ped .. name] or false
end

function GetResourceKvpString(k) return world.kvp[k] end
function SetResourceKvp(k, v) world.kvp[k] = v end
function GetResourceState() return 'missing' end
function RegisterCommand(name, fn) world.commands[name] = fn end
local netEvents = {}
function RegisterNetEvent(name, fn) netEvents[name] = fn end
function TriggerEvent() end
function TriggerServerEvent(name) world.sent[#world.sent + 1] = name end
function RequestStreamedTextureDict() end
function HasStreamedTextureDictLoaded() return true end

-- drawing
local pending = {}
function World3dToScreen2d() return true, 0.5, 0.5 end
function GetGameplayCamCoord() return world.players[world.me].coords end
function GetGameplayCamFov() return 50.0 end
function GetAspectRatio() return 1.77 end
function SetTextScale(s) pending.scale = s end
function SetTextFont() end
function SetTextProportional() end
function SetTextCentre(v) pending.centre = v end
function SetTextOutline() end
function SetTextDropShadow() end
function SetTextEntry() end
function SetTextColour(r, g, b, a) pending.color = { r, g, b, a } end
function AddTextComponentString(s) pending.text = s end

function DrawSprite(dict, texture)
    world.sprites[#world.sprites + 1] = { dict = dict, texture = texture }
end

function DrawRect(x, y, w, h) world.rects[#world.rects + 1] = { x = x, y = y, w = w, h = h } end

-- The 3d labels centre their text, the corner list does not, which is how the
-- two are told apart here.
function DrawText(x, y)
    world.drawn[#world.drawn + 1] = {
        text = pending.text,
        color = pending.color,
        scale = pending.scale,
        centre = pending.centre,
        x = x,
        y = y
    }
end

local function labels()
    local out = {}
    for _, d in ipairs(world.drawn) do
        if d.centre then out[#out + 1] = d end
    end
    return out
end

local function rows()
    local out = {}
    for _, d in ipairs(world.drawn) do
        if not d.centre then out[#out + 1] = d end
    end
    return out
end

-- exports + threads
local registered = {}
exports = setmetatable({}, {
    __call = function(_, name, fn) registered[name] = fn end,
    __index = function() return setmetatable({}, { __index = function() return function() end end }) end
})

local threads = {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end

-- One step is one pass over every thread, and moves the clock on by a scan
-- interval, so the hold and fade timings behave like they would in game.
local TICK = 250

local function step(n)
    for _ = 1, n or 1 do
        world.time = world.time + TICK

        for _, co in ipairs(threads) do
            if coroutine.status(co) == 'suspended' then
                local ok, err = coroutine.resume(co)
                if not ok then error(err, 0) end
            end
        end
    end
end

-- Jump the clock without running anything, for testing what happens after a
-- player has been quiet for a while.
local function warp(ms) world.time = world.time + ms end

-- ------------------------------------------------------------------- tests
local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(('  FAIL %s: got %s, want %s'):format(label, tostring(got), tostring(want)))
    else
        print(('  ok   %s = %s'):format(label, tostring(got)))
    end
end

local function checkNear(label, got, want, tol)
    if type(got) ~= 'number' or math.abs(got - want) > (tol or 0.01) then
        failures = failures + 1
        print(('  FAIL %s: got %s, want about %s'):format(label, tostring(got), tostring(want)))
    else
        print(('  ok   %s = %.3f'):format(label, got))
    end
end

local function boot(configure)
    reset()
    threads, registered, decors, pending = {}, {}, {}, {}
    assert(loadfile(ROOT .. 'config.lua'))()
    assert(loadfile(ROOT .. 'locales.lua'))()
    Config.Debug = false
    if configure then configure() end
    assert(loadfile(ROOT .. 'shared.lua'))()
end

local function loadClient() assert(loadfile(ROOT .. 'client.lua'))() end
local function talkerIds() return registered.getTalkers() end

-- 1: range
print('\n== distance filter ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
addPlayer(3, { x = 50 })
loadClient()
step(3)
check('labelled count', #talkerIds(), 1)
check('who', talkerIds()[1], 102)

-- 2: self
print('\n== ShowSelf ==')
boot()
addPlayer(1, { x = 0, talking = true })
loadClient()
step(3)
check('self hidden', #talkerIds(), 0)

boot(function() Config.ShowSelf = true end)
addPlayer(1, { x = 0, talking = true })
loadClient()
step(3)
check('self shown', #talkerIds(), 1)

-- 3: stealth
print('\n== stealth ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, stealth = true })
loadClient()
step(3)
check('stealthed hidden', #talkerIds(), 0)

boot(function() Config.EnableStealthMode = false end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, stealth = true })
loadClient()
step(3)
check('stealth off shows', #talkerIds(), 1)

-- 4: line of sight
-- Behind cover the label is dimmed rather than dropped, so it stays in the
-- list. What that dimming looks like is checked further down.
print('\n== line of sight ==')
boot(function() Config.RequireLineOfSight = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, los = false })
loadClient()
step(3)
check('behind a wall still listed, dimmed', #talkerIds(), 1)

boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, los = false })
loadClient()
step(3)
check('option off shows', #talkerIds(), 1)

-- 5: invisible
print('\n== invisible ped ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, visible = false })
loadClient()
step(3)
check('invisible hidden', #talkerIds(), 0)

-- 6: max labels, nearest first
print('\n== MaxLabels ==')
boot(function() Config.MaxLabels = 2 end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 15 })
addPlayer(3, { x = 2 })
addPlayer(4, { x = 8 })
loadClient()
step(3)
local ids = talkerIds()
check('capped', #ids, 2)
check('nearest first', ids[1], 103)
check('second nearest', ids[2], 104)

-- 7: radio
print('\n== radio ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, state = { radioActive = true } })
loadClient()
step(4)
check('drew something', #world.drawn > 0, true)
check('radio label', world.drawn[1].text, 'Radio')
check('radio colour', world.drawn[1].color[1], 90)

-- 8: voice range
print('\n== MatchVoiceRange ==')
boot(function() Config.MatchVoiceRange = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 10, state = { proximity = { distance = 5.0 } } })
loadClient()
step(3)
check('outside whisper range', #talkerIds(), 0)

boot(function() Config.MatchVoiceRange = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 10, state = { proximity = 15.0 } })
loadClient()
step(3)
check('numeric proximity works', #talkerIds(), 1)

boot(function() Config.MatchVoiceRange = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 10, state = {} })
loadClient()
step(3)
check('no proximity replicated falls back', #talkerIds(), 1)

boot(function() Config.MatchVoiceRange = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 25, state = { proximity = 40.0 } })
loadClient()
step(3)
check('MaxDistance still caps', #talkerIds(), 0)

-- 9: toggle
print('\n== toggle ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(3)
check('on by default', #talkerIds(), 1)
world.commands['activespeaker']()
step(3)
check('off after command', #talkerIds(), 0)
check('saved to kvp', world.kvp['activespeaker:enabled'], '0')
world.commands['activespeaker']()
step(3)
check('back on', #talkerIds(), 1)
check('kvp updated', world.kvp['activespeaker:enabled'], '1')

print('\n== toggle is remembered ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
world.kvp['activespeaker:enabled'] = '0'
loadClient()
step(3)
check('starts off', #talkerIds(), 0)

-- 10: fade
print('\n== fade ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(4)
check('full alpha up close', world.drawn[1].color[4], 230)

boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 19.9 })  -- inside range, nearly faded out
loadClient()
step(4)
check('faded at the edge', world.drawn[1].color[4] < 20, true)
check('still drawn', #world.drawn > 0, true)

boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 20.5 }) -- just outside
loadClient()
step(6)
check('nothing past MaxDistance', #world.drawn, 0)

-- 11: idle
print('\n== nobody talking ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, talking = false })
loadClient()
step(5)
check('no labels', #talkerIds(), 0)
check('nothing drawn', #world.drawn, 0)

-- 12: names
print('\n== names ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(1)
check('asked the server', world.sent[1], 'activespeaker:requestNames')

-- The list arriving stops the retries, and NameRefreshInterval is 0, so the
-- thread is done rather than polling for the rest of the session.
netEvents['activespeaker:syncNames']({ [102] = 'John Doe' })
step(10)
check('stopped asking once the list arrived', #world.sent, 1)
check('name is used in the label', world.drawn[1].text, 'John Doe - Speaking...')

print('\n== a lost request is retried ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(10)
check('retried', #world.sent, 3)
step(30)
check('but gives up rather than asking forever', #world.sent, 3)

print('\n== a single name update ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(1)
netEvents['activespeaker:setName'](102, 'Jane Roe')
step(3)
check('label picks it up', world.drawn[1].text, 'Jane Roe - Speaking...')
netEvents['activespeaker:setName'](102, false)
step(3)
check('and drops it when they leave', world.drawn[#world.drawn].text, 'Speaking...')

print('\n== ShowNames off never asks ==')
boot(function() Config.ShowNames = false end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(10)
check('no request sent', #world.sent, 0)

-- 13: scale clamping
-- Without the clamp the label is 1.4 / distance, so it fills the screen point
-- blank and is an unreadable 0.07 at the default 20m range.
print('\n== scale is clamped into a readable band ==')
local function scaleAt(distance, configure)
    boot(function()
        Config.PulseAmount = 0 -- so the recorded scale is exactly the clamp
        if configure then configure() end
    end)
    addPlayer(1, { x = 0, talking = false })
    addPlayer(2, { x = distance })
    loadClient()
    step(4)
    local l = labels()
    return l[#l] and l[#l].scale
end

-- 14m rather than the full 20m: at exactly MaxDistance the distance fade has
-- reached zero and there is no label left to measure.
checkNear('point blank is capped at MaxScale', scaleAt(1), 0.55)
checkNear('14m is lifted to MinScale', scaleAt(14), 0.18)
checkNear('mid range is left alone', scaleAt(5), 0.273)
checkNear('MinScale 0 restores the old scaling', scaleAt(14, function()
    Config.MinScale = 0
end), 0.0997, 0.002)

-- 14: hold time
print('\n== the label is held through a pause in speech ==')
boot()
addPlayer(1, { x = 0, talking = false })
local speaker = addPlayer(2, { x = 5 })
loadClient()
step(4)
check('talking', #talkerIds(), 1)

speaker.talking = false
step(1)
check('still held just after they stop', #talkerIds(), 1)

warp(1000)
step(1)
check('gone once the hold and fade have run out', #talkerIds(), 0)

print('\n== hold time of 0 drops it immediately ==')
boot(function()
    Config.HoldTime = 0
    Config.FadeTime = 0
end)
addPlayer(1, { x = 0, talking = false })
speaker = addPlayer(2, { x = 5 })
loadClient()
step(4)
check('talking', #talkerIds(), 1)
speaker.talking = false
step(1)
check('gone at once', #talkerIds(), 0)

-- 15: fade in and out
print('\n== fade in and out ==')
boot(function() Config.PulseAmount = 0 end)
addPlayer(1, { x = 0, talking = false })
speaker = addPlayer(2, { x = 5 })
loadClient()
step(4)
check('full alpha while talking', labels()[#labels()].color[4], 230)

speaker.talking = false
-- 400ms hold then a 200ms fade, and a step is 250ms, so this lands 500ms
-- after they stopped: halfway through the fade out.
warp(250)
step(1)
local faded = labels()[#labels()]
check('halfway through the fade out', faded.color[4] > 90 and faded.color[4] < 140, true)

-- 16: occlusion
print('\n== dimmed behind cover rather than hidden ==')
boot(function()
    Config.RequireLineOfSight = true
    Config.PulseAmount = 0
end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, los = false })
loadClient()
step(4)
check('still listed', #talkerIds(), 1)
-- frameTime 0.1 makes the ease land on the target in one frame
check('drawn at OccludedAlpha', labels()[#labels()].color[4], math.floor(230 * 0.35))

print('\n== OccludedAlpha 0 hides it completely ==')
boot(function()
    Config.RequireLineOfSight = true
    Config.OccludedAlpha = 0
end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, los = false })
loadClient()
step(4)
check('dropped', #talkerIds(), 0)
check('nothing drawn', #labels(), 0)

print('\n== the dim is eased, not snapped ==')
boot(function()
    Config.RequireLineOfSight = true
    Config.PulseAmount = 0
end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, los = false })
loadClient()
world.frameTime = 0.016 -- a real frame
step(4)
local eased = labels()[#labels()].color[4]
check('part way between full and dimmed', eased < 230 and eased > math.floor(230 * 0.35), true)

-- 17: dead players
print('\n== dead players ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, dead = true })
loadClient()
step(4)
check('hidden', #talkerIds(), 0)

boot(function() Config.HideWhenDead = false end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, dead = true })
loadClient()
step(4)
check('shown with the option off', #talkerIds(), 1)

-- 18: pause menu
print('\n== pause menu and screen fades ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(4)
check('drawn normally', #labels() > 0, true)

boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
world.paused = true
step(6)
check('nothing drawn while paused', #labels(), 0)
check('but still tracked', #talkerIds(), 1)

boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
world.faded = true
step(6)
check('nothing drawn while faded out', #labels(), 0)

-- 19: radio icon
print('\n== a different icon on the radio ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(4)
check('normal icon', world.sprites[#world.sprites].texture, 'leaderboard_audio_3')

boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, state = { radioActive = true } })
loadClient()
step(4)
check('radio icon', world.sprites[#world.sprites].texture, 'leaderboard_audio_1')

boot(function() Config.RadioIcon = nil end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, state = { radioActive = true } })
loadClient()
step(4)
check('falls back to the normal icon', world.sprites[#world.sprites].texture, 'leaderboard_audio_3')

-- 20: the corner list
print('\n== the corner list ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(4)
check('off by default', #rows(), 0)
check('no panel drawn', #world.rects, 0)

boot(function() Config.ShowList = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(1)
netEvents['activespeaker:setName'](102, 'John Doe')
step(3)
-- Rows are redrawn every frame, so clear and take a single frame to look at.
world.drawn, world.rects = {}, {}
step(1)
local listed = rows()
check('a title and a name', #listed, 2)
check('title first', listed[1].text, 'Speaking')
check('then the name', listed[2].text, 'John Doe')
check('panel drawn behind it', #world.rects, 1)

print('\n== the list falls back to a player id ==')
boot(function() Config.ShowList = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(4)
world.drawn = {}
step(1)
check('id used when there is no name', rows()[2].text, 'Player 102')

print('\n== the list is capped and ordered ==')
boot(function()
    Config.ShowList = true
    Config.List.rows = 2
    Config.List.title = false
end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 15 })
addPlayer(3, { x = 2 })
addPlayer(4, { x = 8 })
loadClient()
step(4)
world.drawn = {}
step(1)
listed = rows()
check('capped to List.rows', #listed, 2)
check('nearest first', listed[1].text, 'Player 103')
check('then the next nearest', listed[2].text, 'Player 104')

print('\n== the list follows the toggle ==')
boot(function() Config.ShowList = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(4)
check('shown', #rows() > 0, true)
world.commands['activespeaker']()
world.drawn = {}
step(4)
check('hidden with the labels', #rows(), 0)

-- 21: command arguments
print('\n== command arguments ==')
boot()
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5 })
loadClient()
step(2)
world.commands['activespeaker']({}, { 'off' })
step(2)
check('off', #talkerIds(), 0)
world.commands['activespeaker']({}, { 'off' })
step(2)
check('off again is still off', #talkerIds(), 0)
world.commands['activespeaker']({}, { 'on' })
step(2)
check('on', #talkerIds(), 1)
world.commands['activespeaker']({}, { 'debug' })
check('debug asked the server for its half', world.sent[#world.sent], 'activespeaker:requestDebug')

print(failures == 0 and '\nALL PASS' or ('\n' .. failures .. ' FAILURES'))
os.exit(failures == 0 and 0 or 1)
