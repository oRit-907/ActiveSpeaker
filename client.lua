local Config = {
    NameRefreshInterval = 100, -- milliseconds
    EnableStealthMode = true,
    StealthDecoratorKey = "orit_stealth",
    SpeakingText = "🎤 Speaking..."
}

function DrawText3DAnimated(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = #(vector3(x, y, z) - p)
    local scaleBase = 200 / (GetGameplayCamFov() * distance)

    local pulse = 0.05 * math.sin(GetGameTimer() / 200)
    local scale = 0.35 * scaleBase + pulse

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextCentre(true)
        SetTextColour(255, 255, 255, 230)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function IsPlayerStealthy(player)
    local ped = GetPlayerPed(player)
    return DecorExistOn(ped, Config.StealthDecoratorKey) and DecorGetBool(ped, Config.StealthDecoratorKey)
end

Citizen.CreateThread(function()
    while true do
        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)

            if not (Config.EnableStealthMode and IsPlayerStealthy(player)) and NetworkIsPlayerTalking(player) then
                DrawText3DAnimated(coords.x, coords.y, coords.z + 1.15, Config.SpeakingText)
            end
        end
        Wait(Config.NameRefreshInterval)
    end
end)
