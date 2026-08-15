local playerNames = {}
local framework
local QBCore

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
        return exports.qbx_core:GetPlayer(src)
    end

    return QBCore and QBCore.Functions.GetPlayer(src) or nil
end

-- Resolves the character name for a player and hands it to cb. QBCore and Qbox
-- answer straight away, ESX has to go to the database for it.
local function fetchName(src, cb)
    if framework == 'qbcore' or framework == 'qbox' then
        cb(charInfoName(qbPlayer(src)) or GetPlayerName(src))
        return
    end

    local identifier = framework == 'esx' and GetPlayerIdentifier(src, 0) or nil

    -- Servers without mysql-async, and players with no row in users, fall back
    -- to the name they connected with instead of getting no label at all.
    if not identifier or not MySQL or not MySQL.Async then
        cb(GetPlayerName(src))
        return
    end

    MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(fullname)
        cb(fullname or GetPlayerName(src))
    end)
end

local function refresh(src)
    fetchName(src, function(name)
        playerNames[src] = name
        TriggerClientEvent('txylor:updateNames', -1, playerNames)
    end)
end

AddEventHandler('playerDropped', function()
    local src = source
    playerNames[src] = nil
    TriggerClientEvent('txylor:updateNames', -1, playerNames)
end)

RegisterNetEvent('txylor:requestNames')
AddEventHandler('txylor:requestNames', function()
    refresh(source)
end)

-- Picking the name up the moment a character loads, so nobody is stuck with
-- their connection name until the next refresh comes round.
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player and player.PlayerData then
        refresh(player.PlayerData.source)
    end
end)

-- ESX passes the player id as the first argument rather than setting source,
-- and triggers this server side, so it must not be a net event.
AddEventHandler('esx:playerLoaded', function(playerId)
    refresh(playerId)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    framework = detectFramework()

    if framework == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
    end

    print(('[ActiveSpeaker] using %s for character names'):format(framework))
end)
