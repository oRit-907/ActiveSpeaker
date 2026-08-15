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
        sprites = 0,
        sent = {}
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
function SetTextScale() end
function SetTextFont() end
function SetTextProportional() end
function SetTextCentre() end
function SetTextOutline() end
function SetTextDropShadow() end
function SetTextEntry() end
function SetTextColour(r, g, b, a) pending.color = { r, g, b, a } end
function AddTextComponentString(s) pending.text = s end
function DrawSprite() world.sprites = world.sprites + 1 end
function DrawText()
    world.drawn[#world.drawn + 1] = { text = pending.text, color = pending.color }
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

local function step(n)
    for _ = 1, n or 1 do
        for _, co in ipairs(threads) do
            if coroutine.status(co) == 'suspended' then
                local ok, err = coroutine.resume(co)
                if not ok then error(err, 0) end
            end
        end
    end
end

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
print('\n== line of sight ==')
boot(function() Config.RequireLineOfSight = true end)
addPlayer(1, { x = 0, talking = false })
addPlayer(2, { x = 5, los = false })
loadClient()
step(3)
check('behind a wall hidden', #talkerIds(), 0)

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

print(failures == 0 and '\nALL PASS' or ('\n' .. failures .. ' FAILURES'))
os.exit(failures == 0 and 0 or 1)
