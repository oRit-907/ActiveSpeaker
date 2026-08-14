local Config = {
    NameRefreshInterval = 60000, -- milliseconds
    EnableStealthMode = true,
    ShowNames = true,

    -- Draw the label above your own head too. Off by default, you already know
    -- when you are talking.
    ShowSelf = false,

    -- Players further away than this are skipped. The label fades out over the
    -- last quarter of it.
    MaxDistance = 20.0,

    -- How far above the players origin the label sits.
    HeightOffset = 1.15,

    -- The GTA text font has no emoji, so keep this plain text.
    Label = "Speaking...",
    Color = { 255, 255, 255, 230 },

    -- How much the label grows at the peak of the pulse, and how long (ms) a
    -- pulse takes. Set PulseAmount to 0 for no animation.
    PulseAmount = 0.15,
    PulseSpeed = 200,

    -- Shown instead of the two above while the player talks on the radio.
    ShowRadio = true,
    RadioLabel = "Radio",
    RadioColor = { 90, 200, 255, 230 },

    -- Small speaker icon above the label.
    ShowIcon = true,
    Icon = {
        dict = "mpleaderboard",
        texture = "leaderboard_audio_3",
        size = 0.06
    }
}

local playerNames = {}
local iconReady = false

function DrawText3DAnimated(x, y, z, text, color, fade)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local p = GetGameplayCamCoord()
    local distance = #(vector3(x, y, z) - p)
    local scaleBase = 200 / (GetGameplayCamFov() * math.max(distance, 0.1))

    -- Add animation pulse. It multiplies the scale rather than being added to
    -- it, so it stays proportional at any distance - added on, a fixed 0.05 is
    -- a tenth of the size up close and several times the size far away.
    local pulse = 1.0 + Config.PulseAmount * math.sin(GetGameTimer() / Config.PulseSpeed)
    local scale = 0.35 * scaleBase * pulse
    local alpha = math.floor(color[4] * fade)

    if alpha <= 0 then return end

    if Config.ShowIcon and iconReady then
        local w = Config.Icon.size * scaleBase * pulse
        local h = w * GetAspectRatio(false)

        DrawSprite(Config.Icon.dict, Config.Icon.texture, _x, _y - h * 0.6, w, h, 0.0,
            color[1], color[2], color[3], alpha)
    end

    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextCentre(true)
    SetTextColour(color[1], color[2], color[3], alpha)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- The decor has to be registered before it can be read, otherwise DecorExistOn
-- is always false and stealth mode never applies. Other resources hide a player
-- with DecorSetBool(ped, "txylor_stealth", true) on their own client.
Citizen.CreateThread(function()
    DecorRegister("txylor_stealth", 2) -- 2 = bool

    if Config.ShowIcon then
        RequestStreamedTextureDict(Config.Icon.dict, false)
        while not HasStreamedTextureDictLoaded(Config.Icon.dict) do
            Wait(0)
        end
        iconReady = true
    end
end)

-- Helper to check if a player has stealth mode enabled
function IsPlayerStealthy(player)
    local ped = GetPlayerPed(player)
    return DecorExistOn(ped, "txylor_stealth") and DecorGetBool(ped, "txylor_stealth")
end

-- pma-voice replicates this while the player transmits on a radio channel.
function IsPlayerOnRadio(player)
    if not Config.ShowRadio then return false end

    local state = Player(GetPlayerServerId(player)).state
    return state ~= nil and state.radioActive == true
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
    local fadeStart = Config.MaxDistance * 0.75

    while true do
        Wait(0)
        local myPlayer = PlayerId()
        local origin = GetEntityCoords(PlayerPedId())

        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)
            local distance = #(origin - coords)

            if distance > Config.MaxDistance then
                goto continue
            end

            if player == myPlayer and not Config.ShowSelf then
                goto continue
            end

            if Config.EnableStealthMode and IsPlayerStealthy(player) then
                goto continue
            end

            if NetworkIsPlayerTalking(player) then
                local onRadio = IsPlayerOnRadio(player)
                local label = onRadio and Config.RadioLabel or Config.Label
                local color = onRadio and Config.RadioColor or Config.Color
                local name = Config.ShowNames and playerNames[GetPlayerServerId(player)]
                local fade = 1.0

                if distance > fadeStart then
                    fade = 1.0 - (distance - fadeStart) / (Config.MaxDistance - fadeStart)
                end

                DrawText3DAnimated(coords.x, coords.y, coords.z + Config.HeightOffset,
                    name and (name .. " - " .. label) or label, color, fade)
            end
            ::continue::
        end
    end
end)
