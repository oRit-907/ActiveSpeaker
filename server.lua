local REQUEST_COOLDOWN = 5000

local playerNames = {}
local lastRequest = {}
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
-- Exports
-- ============================================================================

-- exports.ActiveSpeaker:getName(source)
exports('getName', function(src)
    return playerNames[src]
end)

exports('refreshName', function(src)
    refresh(src)
end)

-- Hide or show a player without needing code on their client.
exports('setPlayerStealth', function(src, state)
    TriggerClientEvent('activespeaker:setStealth', src, state and true or false)
end)

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
