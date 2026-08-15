local REQUEST_COOLDOWN = 5000
local DEBUG_COOLDOWN = 3000

local playerNames = {}
local lastRequest = {}
local lastDebug = {}
local stealthed = {}
local framework = 'none'
local QBCore
local ESX

-- ============================================================================
-- Framework
-- ============================================================================

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end

    return 'none'
end

-- QBCore and Qbox both keep the character name on the player object, so no
-- query is needed and the name is there as soon as the character loads.
local function charInfoName(player)
    local info = player and player.PlayerData and player.PlayerData.charinfo

    if not info or not info.firstname then
        return nil
    end

    return info.lastname and (info.firstname .. ' ' .. info.lastname) or info.firstname
end

local function qbPlayer(src)
    if framework == 'qbox' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)

        return ok and player or nil
    end

    if not QBCore then return nil end

    local ok, player = pcall(function()
        return QBCore.Functions.GetPlayer(src)
    end)

    return ok and player or nil
end

-- ESX exposes the shared object through an export on 1.9 and legacy, and only
-- through an event on older builds, so try both before giving up.
local function esxObject()
    if ESX then return ESX end

    local ok, obj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if ok and obj then
        ESX = obj
        return ESX
    end

    TriggerEvent('esx:getSharedObject', function(obj)
        ESX = obj
    end)

    return ESX
end

-- The character name is on the xPlayer already. Reading it there instead of
-- querying the users table means it works on oxmysql servers, where the old
-- MySQL.Async path simply did not exist and every player silently fell back to
-- the name they connected with.
local function esxName(src)
    local obj = esxObject()
    local xPlayer = obj and obj.GetPlayerFromId and obj.GetPlayerFromId(src)

    if not xPlayer then return nil end

    if type(xPlayer.getName) == 'function' then
        local name = xPlayer.getName()

        if name and name ~= '' then
            return name
        end
    end

    local vars = xPlayer.variables

    if vars and vars.firstName then
        return vars.lastName and (vars.firstName .. ' ' .. vars.lastName) or vars.firstName
    end

    return nil
end

-- Resolves the character name for a player and hands it to cb.
local function fetchName(src, cb)
    if framework == 'qbcore' or framework == 'qbox' then
        cb(charInfoName(qbPlayer(src)) or GetPlayerName(src))
        return
    end

    if framework == 'esx' then
        local name = esxName(src)

        if name then
            cb(name)
            return
        end

        -- Last resort for servers old enough to have neither the shared object
        -- nor a loaded character yet.
        local identifier = GetPlayerIdentifier(src, 0)

        if identifier and MySQL and MySQL.Async then
            MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) FROM users WHERE identifier = @identifier', {
                ['@identifier'] = identifier
            }, function(fullname)
                cb(fullname or GetPlayerName(src))
            end)
            return
        end
    end

    cb(GetPlayerName(src))
end

-- ============================================================================
-- Sync
-- ============================================================================

-- Names change twice an hour at most, so only the entry that changed goes out,
-- and only when it actually changed. Every client used to be sent the whole
-- list every time any client asked for it.
local function setName(src, name)
    if playerNames[src] == name then return end

    playerNames[src] = name
    TriggerClientEvent('activespeaker:setName', -1, src, name or false)
    ASDebug(('%s is now %s'):format(src, name or 'gone'))
end

local function refresh(src)
    if not Config.ShowNames then return end

    fetchName(src, function(name)
        setName(src, name)
    end)
end

AddEventHandler('playerDropped', function()
    local src = source

    lastRequest[src] = nil
    lastDebug[src] = nil
    stealthed[src] = nil
    setName(src, nil)
end)

-- One full copy per client, when it starts. The optional resync goes to the
-- client that asked rather than to everyone, and is rate limited, so a client
-- spamming it costs that client and nobody else.
RegisterNetEvent('activespeaker:requestNames', function()
    local src = source
    local now = GetGameTimer()

    if lastRequest[src] and now - lastRequest[src] < REQUEST_COOLDOWN then
        return
    end

    lastRequest[src] = now
    refresh(src)
    TriggerClientEvent('activespeaker:syncNames', src, playerNames)
end)

-- Picking the name up the moment a character loads, so nobody is stuck with
-- their connection name until the next refresh comes round.
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player and player.PlayerData then
        refresh(player.PlayerData.source)
    end
end)

-- Qbox fires its own event as well as the QBCore one.
AddEventHandler('qbx_core:playerLoaded', function(player)
    if player and player.PlayerData then
        refresh(player.PlayerData.source)
    end
end)

-- ESX passes the player id as the first argument rather than setting source,
-- and triggers this server side, so it must not be a net event. The xPlayer
-- comes with it, which saves looking the player up again.
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if xPlayer and type(xPlayer.getName) == 'function' then
        local name = xPlayer.getName()

        if name and name ~= '' then
            setName(playerId, name)
            return
        end
    end

    refresh(playerId)
end)

-- ============================================================================
-- Diagnostics
-- ============================================================================

local function resolvedCount()
    local count = 0

    for _ in pairs(playerNames) do
        count = count + 1
    end

    return count
end

-- Fills in the half of /activespeaker debug that only the server knows.
RegisterNetEvent('activespeaker:requestDebug', function()
    local src = source
    local now = GetGameTimer()

    if lastDebug[src] and now - lastDebug[src] < DEBUG_COOLDOWN then
        return
    end

    lastDebug[src] = now

    TriggerClientEvent('activespeaker:debugReply', src, {
        framework = framework,
        names = resolvedCount()
    })
end)

-- ============================================================================
-- Exports
-- ============================================================================

local function setStealth(src, state)
    state = state and true or false
    stealthed[src] = state or nil

    TriggerClientEvent('activespeaker:setStealth', src, state)

    return state
end

-- exports.ActiveSpeaker:getName(source)
exports('getName', function(src)
    return playerNames[src]
end)

exports('refreshName', function(src)
    refresh(src)
end)

-- Hide or show a player without needing code on their client.
exports('setPlayerStealth', function(src, state)
    setStealth(src, state)
end)

exports('isPlayerStealthed', function(src)
    return stealthed[src] == true
end)

-- ============================================================================
-- Commands
-- ============================================================================

-- The server console has no chat to reply into, and an admin in game cannot see
-- the console, so answer wherever the command came from.
local function reply(src, message)
    if src == 0 then
        ASPrint(message)
        return
    end

    TriggerClientEvent('chat:addMessage', src, {
        color = { 90, 200, 255 },
        args = { 'Active Speaker', message }
    })
end

if Config.AdminCommand then
    RegisterCommand(Config.AdminCommand, function(src, args)
        local target = tonumber(args[1])

        if not target then
            reply(src, ('usage: /%s <player id> [hide|show]'):format(Config.AdminCommand))
            return
        end

        -- Some builds answer nil for an id nobody is using, others an empty
        -- string.
        local targetName = GetPlayerName(target)

        if targetName == nil or targetName == '' then
            reply(src, ('no player is connected with id %d'):format(target))
            return
        end

        local wanted
        local choice = args[2] and tostring(args[2]):lower() or nil

        if choice == 'hide' then
            wanted = true
        elseif choice == 'show' then
            wanted = false
        else
            wanted = not stealthed[target]
        end

        setStealth(target, wanted)

        reply(src, (L(wanted and 'admin_hidden' or 'admin_shown')):format(playerNames[target] or targetName))
        ASDebug(('%s set stealth %s on %s'):format(src, tostring(wanted), target))
    end, true) -- restricted, needs the ace permission command.<name>
end

if Config.StatusCommand then
    RegisterCommand(Config.StatusCommand, function(src)
        reply(src, ('version %s, framework %s'):format(
            GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown', framework))
        reply(src, ('pma-voice %s'):format(GetResourceState('pma-voice')))
        reply(src, ('names %s, %d resolved of %d connected'):format(
            Config.ShowNames and 'on' or 'off', resolvedCount(), #GetPlayers()))

        local hidden = 0
        for _ in pairs(stealthed) do
            hidden = hidden + 1
        end

        reply(src, ('%d player(s) hidden from the display'):format(hidden))
        reply(src, ('range %.1fm, scale %.2f to %.2f, list %s'):format(
            Config.MaxDistance, Config.MinScale, Config.MaxScale,
            Config.ShowList and 'on' or 'off'))

        if GetResourceState('pma-voice') ~= 'started' then
            reply(src, 'pma-voice is not started under that name, nobody will show as talking')
        end

        if Config.ShowNames and framework == 'none' then
            reply(src, 'no framework was detected, names are the ones players connected with')
        end
    end, true) -- restricted, needs the ace permission command.<name>
end

-- ============================================================================
-- Start
-- ============================================================================

local function refreshEveryone()
    -- Catches everyone already connected when the resource is restarted mid
    -- session, rather than leaving them nameless until they reconnect.
    for _, id in ipairs(GetPlayers()) do
        refresh(tonumber(id))
    end
end

local function applyFramework(detected)
    framework = detected
    QBCore = nil

    if framework == 'qbcore' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)

        QBCore = ok and core or nil

        if not QBCore then
            ASWarn('qb-core is running but would not hand over its core object, names fall back to connection names')
        end
    elseif framework == 'esx' then
        esxObject()
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    applyFramework(detectFramework())
    ASPrint(('using %s for character names'):format(framework))
    refreshEveryone()

    -- Started before the framework it is looking for. On a cold boot every
    -- resource is starting at once, so a first look that finds nothing is not
    -- the same as there being nothing to find - keep looking for a few seconds
    -- before settling on connection names for the rest of the session.
    CreateThread(function()
        for _ = 1, 10 do
            if framework ~= 'none' or Config.Framework ~= 'auto' then return end

            Wait(1000)

            local detected = detectFramework()

            if detected ~= 'none' then
                applyFramework(detected)
                ASPrint(('%s finished starting, using it for character names'):format(detected))
                refreshEveryone()
                return
            end
        end
    end)

    -- Not a hard dependency in fxmanifest on purpose: plenty of servers run the
    -- folder under another name, and a wrong guess there would stop the
    -- resource from starting at all. A line in the console is enough, once
    -- everything else has had a chance to come up.
    CreateThread(function()
        Wait(10000)

        if GetResourceState('pma-voice') ~= 'started' then
            ASWarn('pma-voice does not look like it is running, nobody will ever be shown as talking')
            ASWarn('if your copy is in a folder under another name, ignore this')
        end
    end)
end)
