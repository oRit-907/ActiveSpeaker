local playerNames = {}

AddEventHandler('playerDropped', function()
    local src = source
    playerNames[src] = nil
    TriggerClientEvent('txylor:updateNames', -1, playerNames)
end)

RegisterNetEvent('txylor:requestNames')
AddEventHandler('txylor:requestNames', function()
    local src = source
    local identifier = GetPlayerIdentifier(src, 0)

    -- Servers without mysql-async, or players without a row in users, fall back
    -- to the name they connected with instead of getting no label at all.
    if not identifier or not MySQL or not MySQL.Async then
        playerNames[src] = GetPlayerName(src)
        TriggerClientEvent('txylor:updateNames', -1, playerNames)
        return
    end

    MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(fullname)
        if not fullname then fullname = GetPlayerName(src) end
        playerNames[src] = fullname
        TriggerClientEvent('txylor:updateNames', -1, playerNames)
    end)
end)
