local Config = {
    NameRefreshInterval = 60000, -- milliseconds
    EnableStealthMode = true,
    ShowNames = true,
    -- The GTA text font has no emoji, so keep this plain text.
    Label = "Speaking..."
}

local playerNames = {}

function DrawText3DAnimated(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoord()
    local distance = #(vector3(x, y, z) - p)
    local scaleBase = 200 / (GetGameplayCamFov() * distance)

    -- Add animation pulse
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

-- The decor has to be registered before it can be read, otherwise DecorExistOn
-- is always false and stealth mode never applies. Other resources hide a player
-- with DecorSetBool(ped, "txylor_stealth", true) on their own client.
Citizen.CreateThread(function()
    DecorRegister("txylor_stealth", 2) -- 2 = bool
end)

-- Helper to check if a player has stealth mode enabled
function IsPlayerStealthy(player)
    local ped = GetPlayerPed(player)
    return DecorExistOn(ped, "txylor_stealth") and DecorGetBool(ped, "txylor_stealth")
end

RegisterNetEvent('txylor:updateNames')
AddEventHandler('txylor:updateNames', function(names)
    playerNames = names or {}
end)

Citizen.CreateThread(function()
    while true do
        TriggerServerEvent('txylor:requestNames')
        Wait(Config.NameRefreshInterval)
    end
end)

-- Only show animated Speaking... above talking players
Citizen.CreateThread(function()
    while true do
        Wait(0)
        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)

            if Config.EnableStealthMode and IsPlayerStealthy(player) then
                goto continue
            end

            if NetworkIsPlayerTalking(player) then
                local name = Config.ShowNames and playerNames[GetPlayerServerId(player)]
                DrawText3DAnimated(coords.x, coords.y, coords.z + 1.15, name and (name .. " - " .. Config.Label) or Config.Label)
            end
            ::continue::
        end
    end
end)
