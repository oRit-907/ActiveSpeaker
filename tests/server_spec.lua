-- Harness: stubs the server natives and checks the name sync, the rate limit
-- and the framework name lookups.
local ROOT = os.getenv('AS_ROOT') or '../'

local sent, netEvents, handlers, threads, registered, resources, players, names
local now, resourceStates, commands, consoled

local function reset()
    sent, netEvents, handlers, threads = {}, {}, {}, {}
    registered, resources, commands, consoled = {}, {}, {}, {}
    players, names = { 1, 2, 3 }, { [1] = 'Steam One', [2] = 'Steam Two', [3] = 'Steam Three' }
    now, resourceStates = 0, {}
end

local manifest = '2.2.0'

function IsDuplicityVersion() return true end
function GetCurrentResourceName() return 'ActiveSpeaker' end
function GetResourceMetadata() return manifest end
function GetGameTimer() return now end
function GetResourceState(r) return resourceStates[r] or 'missing' end
-- nil for an id nobody is using, the same as the real native.
function GetPlayerName(src) return names[src] end
function GetPlayerIdentifier(src) return 'license:' .. src end
function GetPlayers()
    local out = {}
    for _, id in ipairs(players) do out[#out + 1] = tostring(id) end
    return out
end

function TriggerClientEvent(event, target, ...)
    sent[#sent + 1] = { event = event, target = target, args = { ... } }
end

function TriggerEvent() end
function RegisterNetEvent(name, fn) netEvents[name] = fn end
function RegisterCommand(name, fn, restricted)
    commands[name] = { fn = fn, restricted = restricted }
end
function AddEventHandler(name, fn)
    handlers[name] = handlers[name] or {}
    table.insert(handlers[name], fn)
end
function CreateThread(fn) threads[#threads + 1] = fn end
function Wait() end

exports = setmetatable({}, {
    __call = function(_, name, fn) registered[name] = fn end,
    __index = function(_, resName)
        local r = resources[resName]
        if not r then error('no such resource: ' .. resName, 0) end
        return r
    end
})

local function fire(name, ...)
    for _, fn in ipairs(handlers[name] or {}) do fn(...) end
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

local function boot(configure)
    reset()
    assert(loadfile(ROOT .. 'config.lua'))()
    assert(loadfile(ROOT .. 'locales.lua'))()
    Config.Debug = false
    if configure then configure() end
    assert(loadfile(ROOT .. 'shared.lua'))()
    assert(loadfile(ROOT .. 'server.lua'))()
end

local function start() fire('onResourceStart', 'ActiveSpeaker') end

local function eventsFor(name)
    local out = {}
    for _, e in ipairs(sent) do
        if e.event == name then out[#out + 1] = e end
    end
    return out
end

-- ------------------------------------------------------- no framework
print('\n== no framework ==')
boot()
start()
local setEvents = eventsFor('activespeaker:setName')
check('one push per connected player', #setEvents, 3)
check('pushed to everyone', setEvents[1].target, -1)
check('connection name used', setEvents[1].args[2], 'Steam One')
check('name readable through the export', registered.getName(2), 'Steam Two')

-- ------------------------------------------------------- one client asking
print('\n== a client asking does not spam everyone ==')
boot()
start()
sent = {}
source = 2
netEvents['activespeaker:requestNames']()
local syncs = eventsFor('activespeaker:syncNames')
check('one sync', #syncs, 1)
check('sent only to the asker', syncs[1].target, 2)
check('no broadcast triggered', #eventsFor('activespeaker:setName'), 0)

-- ------------------------------------------------------- rate limit
print('\n== rate limit ==')
sent = {}
source = 2
netEvents['activespeaker:requestNames']()
check('immediate retry ignored', #sent, 0)

now = now + 4999
source = 2
netEvents['activespeaker:requestNames']()
check('still inside the cooldown', #sent, 0)

now = now + 2
source = 2
netEvents['activespeaker:requestNames']()
check('allowed after the cooldown', #eventsFor('activespeaker:syncNames'), 1)

sent = {}
source = 3
netEvents['activespeaker:requestNames']()
check('a different client is not blocked', #eventsFor('activespeaker:syncNames'), 1)

-- ------------------------------------------------------- unchanged names
print('\n== unchanged names are not resent ==')
boot()
start()
sent = {}
registered.refreshName(1)
check('nothing sent when the name is the same', #sent, 0)

names[1] = 'Renamed'
registered.refreshName(1)
check('sent once it changes', #eventsFor('activespeaker:setName'), 1)
check('new name', eventsFor('activespeaker:setName')[1].args[2], 'Renamed')

-- ------------------------------------------------------- dropping
print('\n== player dropped ==')
boot()
start()
sent = {}
source = 2
fire('playerDropped')
local dropped = eventsFor('activespeaker:setName')
check('one removal', #dropped, 1)
check('for that player', dropped[1].args[1], 2)
check('false rather than nil', dropped[1].args[2], false)
check('gone from the list', registered.getName(2), nil)

-- ------------------------------------------------------- qbcore
print('\n== qbcore ==')
boot()
resourceStates['qb-core'] = 'started'
resources['qb-core'] = {
    GetCoreObject = function()
        return {
            Functions = {
                GetPlayer = function(src)
                    if src ~= 1 then return nil end
                    return { PlayerData = { charinfo = { firstname = 'John', lastname = 'Doe' } } }
                end
            }
        }
    end
}
start()
check('charinfo name', registered.getName(1), 'John Doe')
check('no character falls back', registered.getName(2), 'Steam Two')

-- ------------------------------------------------------- qbox
print('\n== qbox ==')
boot()
resourceStates['qbx_core'] = 'started'
resources['qbx_core'] = {
    GetPlayer = function(_, src)
        if src ~= 1 then return nil end
        return { PlayerData = { charinfo = { firstname = 'Jane', lastname = 'Roe' } } }
    end
}
start()
check('charinfo name', registered.getName(1), 'Jane Roe')

-- ------------------------------------------------------- esx, no database
print('\n== esx reads the xPlayer, not the database ==')
boot()
resourceStates['es_extended'] = 'started'
local queried = {}
MySQL = {
    Async = {
        fetchScalar = function(_, params, cb)
            queried[params['@identifier']] = true
            cb(nil)
        end
    }
}
resources['es_extended'] = {
    getSharedObject = function()
        return {
            GetPlayerFromId = function(src)
                if src ~= 1 then return nil end
                return { getName = function() return 'Alice Smith' end }
            end
        }
    end
}
start()
check('name from the xPlayer', registered.getName(1), 'Alice Smith')
-- The whole point of the change: a loaded character costs no query.
check('no query for a loaded character', queried['license:1'], nil)
-- Someone still on the character picker has no xPlayer, so the old path is
-- still there for them rather than nothing at all.
check('query only without an xPlayer', queried['license:2'], true)
check('and that falls back too', registered.getName(2), 'Steam Two')
MySQL = nil

print('\n== esx on oxmysql, where MySQL.Async does not exist ==')
boot()
resourceStates['es_extended'] = 'started'
resources['es_extended'] = {
    getSharedObject = function()
        return {
            GetPlayerFromId = function(src)
                if src ~= 1 then return nil end
                return { getName = function() return 'Alice Smith' end }
            end
        }
    end
}
start()
check('loaded character still resolves', registered.getName(1), 'Alice Smith')
check('everyone else falls back cleanly', registered.getName(3), 'Steam Three')

print('\n== esx variables fallback ==')
boot()
resourceStates['es_extended'] = 'started'
resources['es_extended'] = {
    getSharedObject = function()
        return {
            GetPlayerFromId = function(src)
                if src ~= 1 then return nil end
                return { variables = { firstName = 'Carol', lastName = 'White' } }
            end
        }
    end
}
start()
check('name from variables', registered.getName(1), 'Carol White')

-- ------------------------------------------------------- esx playerLoaded
print('\n== esx playerLoaded ==')
boot()
resourceStates['es_extended'] = 'started'
resources['es_extended'] = {
    getSharedObject = function() return { GetPlayerFromId = function() return nil end } end
}
start()
sent = {}
fire('esx:playerLoaded', 2, { getName = function() return 'Bob Jones' end })
check('name set straight away', registered.getName(2), 'Bob Jones')
check('pushed to clients', #eventsFor('activespeaker:setName'), 1)

-- ------------------------------------------------------- qb playerLoaded
print('\n== qbcore playerLoaded ==')
boot()
resourceStates['qb-core'] = 'started'
resources['qb-core'] = {
    GetCoreObject = function()
        return {
            Functions = {
                GetPlayer = function()
                    return { PlayerData = { charinfo = { firstname = 'Late', lastname = 'Loader' } } }
                end
            }
        }
    end
}
start()
sent = {}
fire('QBCore:Server:PlayerLoaded', { PlayerData = { source = 2 } })
check('name updated on load', registered.getName(2), 'Late Loader')

-- ------------------------------------------------------- stealth export
print('\n== stealth export ==')
boot()
start()
sent = {}
registered.setPlayerStealth(3, true)
check('event sent', sent[1].event, 'activespeaker:setStealth')
check('to that player', sent[1].target, 3)
check('with the state', sent[1].args[1], true)

-- ------------------------------------------------------- names off
print('\n== ShowNames off ==')
boot(function() Config.ShowNames = false end)
start()
check('no name traffic at all', #eventsFor('activespeaker:setName'), 0)

-- ------------------------------------------------------- broken export
print('\n== framework export that throws ==')
boot()
resourceStates['qb-core'] = 'started'
resources['qb-core'] = { GetCoreObject = function() error('core not ready') end }
start()
check('falls back instead of erroring', registered.getName(1), 'Steam One')

-- ------------------------------------------------------- admin command
local function runCommand(name, src, args)
    local cmd = commands[name]
    if not cmd then error('command ' .. name .. ' was never registered', 0) end

    local realPrint = print
    consoled = {}
    print = function(msg) consoled[#consoled + 1] = msg end
    cmd.fn(src, args or {})
    print = realPrint

    return consoled
end

local function chatTo(target)
    local out = {}
    for _, e in ipairs(sent) do
        if e.event == 'chat:addMessage' and e.target == target then
            out[#out + 1] = e.args[1].args[2]
        end
    end
    return out
end

local function stealthEvents()
    local out = {}
    for _, e in ipairs(sent) do
        if e.event == 'activespeaker:setStealth' then out[#out + 1] = e end
    end
    return out
end

print('\n== admin command ==')
boot()
start()
check('registered', commands['asmute'] ~= nil, true)
check('behind an ace permission', commands['asmute'].restricted, true)

sent = {}
runCommand('asmute', 0, { '2' })
local hides = stealthEvents()
check('one event', #hides, 1)
check('to that player', hides[1].target, 2)
check('hiding them', hides[1].args[1], true)
check('tracked server side', registered.isPlayerStealthed(2), true)

sent = {}
runCommand('asmute', 0, { '2' })
check('running it again shows them', stealthEvents()[1].args[1], false)
check('no longer tracked', registered.isPlayerStealthed(2), false)

sent = {}
runCommand('asmute', 0, { '2', 'hide' })
check('explicit hide', stealthEvents()[1].args[1], true)
sent = {}
runCommand('asmute', 0, { '2', 'hide' })
check('explicit hide is not a toggle', stealthEvents()[1].args[1], true)
sent = {}
runCommand('asmute', 0, { '2', 'show' })
check('explicit show', stealthEvents()[1].args[1], false)

print('\n== admin command replies ==')
boot()
start()
sent = {}
local out = runCommand('asmute', 0, {})
check('usage on the console with no id', out[1]:find('usage') ~= nil, true)

sent = {}
out = runCommand('asmute', 0, { '99' })
check('rejects an id nobody is using', out[1]:find('no player is connected') ~= nil, true)
check('and sends nothing', #stealthEvents(), 0)

-- An admin in game cannot see the server console, so it answers in chat.
sent = {}
out = runCommand('asmute', 3, { '2' })
check('nothing printed to the console', #out, 0)
check('answered in chat instead', #chatTo(3), 1)
check('naming the player', chatTo(3)[1]:find('Steam Two') ~= nil, true)

print('\n== stealth is forgotten when the player leaves ==')
boot()
start()
runCommand('asmute', 0, { '2' })
check('hidden', registered.isPlayerStealthed(2), true)
source = 2
fire('playerDropped')
check('cleared on drop', registered.isPlayerStealthed(2), false)

-- ------------------------------------------------------- status command
print('\n== status command ==')
boot()
resourceStates['qb-core'] = 'started'
resources['qb-core'] = {
    GetCoreObject = function()
        return { Functions = { GetPlayer = function() return nil end } }
    end
}
start()
check('behind an ace permission', commands['asstatus'].restricted, true)

out = runCommand('asstatus', 0)
local text = table.concat(out, '\n')
check('reports the version', text:find('2%.2%.0') ~= nil, true)
check('reports the framework', text:find('qbcore') ~= nil, true)
check('reports how many names resolved', text:find('3 resolved of 3 connected') ~= nil, true)
check('warns that pma-voice is missing', text:find('pma%-voice is not started') ~= nil, true)

boot()
start()
out = runCommand('asstatus', 0)
check('warns when no framework was found', table.concat(out, '\n'):find('no framework was detected') ~= nil, true)

-- ------------------------------------------------------- debug reply
print('\n== debug reply ==')
boot()
resourceStates['es_extended'] = 'started'
resources['es_extended'] = {
    getSharedObject = function() return { GetPlayerFromId = function() return nil end } end
}
start()
sent = {}
source = 2
netEvents['activespeaker:requestDebug']()
local replies = eventsFor('activespeaker:debugReply')
check('one reply', #replies, 1)
check('to the client that asked', replies[1].target, 2)
check('with the framework', replies[1].args[1].framework, 'esx')
check('and the name count', replies[1].args[1].names, 3)

sent = {}
source = 2
netEvents['activespeaker:requestDebug']()
check('rate limited', #eventsFor('activespeaker:debugReply'), 0)

now = now + 3001
source = 2
netEvents['activespeaker:requestDebug']()
check('allowed again after the cooldown', #eventsFor('activespeaker:debugReply'), 1)

print('\n== commands can be turned off ==')
boot(function()
    Config.AdminCommand = false
    Config.StatusCommand = false
end)
start()
check('no admin command', commands['asmute'], nil)
check('no status command', commands['asstatus'], nil)

-- ------------------------------------------------------- late framework
print('\n== framework that starts after this resource ==')
boot()
start()
check('nothing found on the first look', registered.getName(1), 'Steam One')

-- qb-core finishes starting a second later
resourceStates['qb-core'] = 'started'
resources['qb-core'] = {
    GetCoreObject = function()
        return {
            Functions = {
                GetPlayer = function()
                    return { PlayerData = { charinfo = { firstname = 'Found', lastname = 'Later' } } }
                end
            }
        }
    end
}
threads[1]() -- the retry loop
check('picked up on a retry', registered.getName(1), 'Found Later')

print('\n== a forced framework is not second guessed ==')
boot(function() Config.Framework = 'none' end)
start()
resourceStates['qb-core'] = 'started'
resources['qb-core'] = { GetCoreObject = function() error('should not be asked') end }
threads[1]()
check('still none', registered.getName(1), 'Steam One')

-- ------------------------------------------------------- version check
print('\n== version check ==')
local printed

local function versionCheck(current, remote)
    reset()
    printed = {}
    manifest = current
    assert(loadfile(ROOT .. 'config.lua'))()
    assert(loadfile(ROOT .. 'locales.lua'))()
    assert(loadfile(ROOT .. 'shared.lua'))()

    local realPrint = print
    print = function(msg) printed[#printed + 1] = msg end
    assert(loadfile(ROOT .. 'version.lua'))()
    fire('onResourceStart', 'ActiveSpeaker')
    print = realPrint

    return table.concat(printed, '\n')
end

function PerformHttpRequest(_, cb)
    cb(200, ("version '%s'"):format(_G.__remote))
end

_G.__remote = '2.1.0'
check('same version is up to date', versionCheck('2.1.0'):find('up to date') ~= nil, true)

_G.__remote = '2.2.0'
check('newer remote is flagged', versionCheck('2.1.0'):find('out of date') ~= nil, true)

-- The reason the comparison is done piece by piece rather than as text.
_G.__remote = '1.0.9'
check('1.0.10 is newer than 1.0.9', versionCheck('1.0.10'):find('up to date') ~= nil, true)

_G.__remote = '1.0.10'
check('1.0.9 is older than 1.0.10', versionCheck('1.0.9'):find('out of date') ~= nil, true)

_G.__remote = '2.1'
check('shorter remote version is handled', versionCheck('2.1.0'):find('up to date') ~= nil, true)

print(failures == 0 and '\nALL PASS' or ('\n' .. failures .. ' FAILURES'))
os.exit(failures == 0 and 0 or 1)
