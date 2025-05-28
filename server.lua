local playerNames = {}

-- Handle player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    playerNames[src] = nil
    TriggerClientEvent('orit:updateNames', -1, playerNames)
end)

-- Handle name request from client
RegisterNetEvent('orit:requestNames', function()
    local src = source
    local identifier = GetPlayerIdentifier(src, 0)

    if not identifier then
        print(("Failed to get identifier for player %d"):format(src))
        return
    end

    -- Fetch full name from database (fallback to game name if not found)
    MySQL.Async.fetchScalar([[
        SELECT CONCAT(firstname, " ", lastname) FROM users WHERE identifier = @identifier
    ]], {
        ['@identifier'] = identifier
    }, function(fullname)
        if not fullname or fullname == "" then
            fullname = GetPlayerName(src)
        end

        playerNames[src] = fullname
        TriggerClientEvent('orit:updateNames', -1, playerNames)
    end)
end)
