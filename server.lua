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
    MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(fullname)
        if not fullname then fullname = GetPlayerName(src) end
        playerNames[src] = fullname
        TriggerClientEvent('txylor:updateNames', -1, playerNames)
    end)
end)