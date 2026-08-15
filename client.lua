local STEALTH_DECOR = 'txylor_stealth'
local STEALTH_DECOR_ALT = 'activespeaker_stealth'
local KVP_ENABLED = 'activespeaker:enabled'
local ICON_TIMEOUT = 10000

local playerNames = {}
local talkers = {}
local iconReady = false
local enabled = true
local receivedNames = false

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
    SetTextFont(Config.Font)
    SetTextProportional(1)
    SetTextCentre(true)
    SetTextColour(color[1], color[2], color[3], alpha)

    if Config.Outline then
        SetTextOutline()
    end

    if Config.Shadow then
        SetTextDropShadow()
    end

    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- ============================================================================
-- Stealth
-- ============================================================================

-- Both names are checked, so resources written against the original decor keep
-- working alongside the export.
local function isStealthy(ped)
    return (DecorExistOn(ped, STEALTH_DECOR) and DecorGetBool(ped, STEALTH_DECOR))
        or (DecorExistOn(ped, STEALTH_DECOR_ALT) and DecorGetBool(ped, STEALTH_DECOR_ALT))
end

-- Kept for anything still calling it by player index rather than ped.
function IsPlayerStealthy(player)
    return isStealthy(GetPlayerPed(player))
end

local function setStealth(state)
    local ped = PlayerPedId()
    state = state and true or false

    DecorSetBool(ped, STEALTH_DECOR, state)
    DecorSetBool(ped, STEALTH_DECOR_ALT, state)
    ASDebug(('stealth %s'):format(state and 'on' or 'off'))
end

-- ============================================================================
-- Toggle
-- ============================================================================

local function notify(message)
    local mode = Config.Notify

    if mode == 'none' then return end

    if mode == 'auto' then
        mode = GetResourceState('ox_lib') == 'started' and 'ox_lib' or 'chat'
    end

    if mode == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            title = 'Active Speaker',
            description = message,
            type = 'inform'
        })
        return
    end

    TriggerEvent('chat:addMessage', {
        color = { Config.RadioColor[1], Config.RadioColor[2], Config.RadioColor[3] },
        args = { 'Active Speaker', message }
    })
end

local function setEnabled(state, quiet)
    enabled = state and true or false

    if not enabled then
        talkers = {}
    end

    if Config.RememberToggle then
        SetResourceKvp(KVP_ENABLED, enabled and '1' or '0')
    end

    if not quiet then
        notify(enabled and L('toggle_on') or L('toggle_off'))
    end

    ASDebug(('display %s'):format(enabled and 'on' or 'off'))
end

-- ============================================================================
-- Names
-- ============================================================================

RegisterNetEvent('activespeaker:syncNames', function(names)
    playerNames = names or {}
    receivedNames = true

    if Config.Debug then
        local count = 0

        -- The list is keyed by server id, so # does not count it.
        for _ in pairs(playerNames) do
            count = count + 1
        end

        ASDebug(('received %d names'):format(count))
    end
end)

RegisterNetEvent('activespeaker:setName', function(serverId, name)
    -- false rather than nil, a trailing nil does not survive the trip.
    playerNames[serverId] = name ~= false and name or nil
end)

RegisterNetEvent('activespeaker:setStealth', function(state)
    setStealth(state)
end)

-- ============================================================================
-- Scan
-- ============================================================================

-- pma-voice replicates the range the player is talking at. Older versions do
-- not, and the shape has changed between them, so anything unexpected falls
-- back to the configured distance instead of hiding every label.
local function voiceRange(state)
    if not Config.MatchVoiceRange or not state then
        return Config.MaxDistance
    end

    local proximity = state.proximity
    local range

    if type(proximity) == 'number' then
        range = proximity
    elseif type(proximity) == 'table' then
        range = tonumber(proximity.distance or proximity.range)
    end

    if not range or range <= 0 then
        return Config.MaxDistance
    end

    return math.min(range, Config.MaxDistance)
end

local function byDistance(a, b)
    return a.distance < b.distance
end

-- Builds the list the draw thread works from. Running this on an interval
-- rather than every frame is what keeps the resource cheap while nobody is
-- talking, which is nearly all of the time.
local function scan()
    local found = {}
    local me = PlayerId()
    local myPed = PlayerPedId()
    local origin = GetEntityCoords(myPed)

    for _, player in ipairs(GetActivePlayers()) do
        -- Cheapest and most selective check first.
        if NetworkIsPlayerTalking(player) then
            local isSelf = player == me

            if not isSelf or Config.ShowSelf then
                local ped = GetPlayerPed(player)

                if ped ~= 0 and DoesEntityExist(ped) then
                    local serverId = GetPlayerServerId(player)
                    local coords = GetEntityCoords(ped)
                    local distance = #(origin - coords)

                    -- Only worth reading the state bag when something actually
                    -- uses it.
                    local state
                    if Config.ShowRadio or Config.MatchVoiceRange then
                        state = Player(serverId).state
                    end

                    local maxDist = voiceRange(state)

                    local visible = isSelf
                        or not Config.IgnoreInvisible
                        or IsEntityVisible(ped)

                    local inSight = isSelf
                        or not Config.RequireLineOfSight
                        or HasEntityClearLosToEntity(myPed, ped, 17)

                    local hidden = Config.EnableStealthMode and isStealthy(ped)

                    if distance <= maxDist and visible and inSight and not hidden then
                        local onRadio = Config.ShowRadio and state ~= nil and state.radioActive == true
                        local label = onRadio and Config.RadioLabel or Config.Label
                        local name = Config.ShowNames and playerNames[serverId]

                        found[#found + 1] = {
                            ped = ped,
                            serverId = serverId,
                            text = name and (name .. ' - ' .. label) or label,
                            color = onRadio and Config.RadioColor or Config.Color,
                            maxDist = maxDist,
                            distance = distance
                        }
                    end
                end
            end
        end
    end

    -- Nearest first, so a cap drops the labels furthest away rather than
    -- whichever players happened to come back last from GetActivePlayers.
    if Config.MaxLabels > 0 and #found > Config.MaxLabels then
        table.sort(found, byDistance)

        for i = #found, Config.MaxLabels + 1, -1 do
            found[i] = nil
        end
    end

    return found
end

-- ============================================================================
-- Threads
-- ============================================================================

CreateThread(function()
    -- The decor has to be registered before it can be read, otherwise
    -- DecorExistOn is always false and stealth mode never applies.
    DecorRegister(STEALTH_DECOR, 2) -- 2 = bool
    DecorRegister(STEALTH_DECOR_ALT, 2)

    if Config.RememberToggle then
        local saved = GetResourceKvpString(KVP_ENABLED)

        if saved ~= nil then
            enabled = saved == '1'
        end
    end

    if Config.ToggleCommand then
        RegisterCommand(Config.ToggleCommand, function()
            setEnabled(not enabled)
        end, false)

        TriggerEvent('chat:addSuggestion', '/' .. Config.ToggleCommand, L('toggle_cmd'))
    end

    if Config.ShowIcon then
        RequestStreamedTextureDict(Config.Icon.dict, false)

        -- Giving up matters here. A dictionary that is never going to load,
        -- because of a typo or because it is not streamed, used to leave this
        -- thread spinning at frame rate for the rest of the session.
        local deadline = GetGameTimer() + ICON_TIMEOUT

        while not HasStreamedTextureDictLoaded(Config.Icon.dict) do
            if GetGameTimer() > deadline then
                Config.ShowIcon = false
                ASWarn(("could not load texture dictionary '%s', the icon is off")
                    :format(Config.Icon.dict))
                return
            end

            Wait(50)
        end

        iconReady = true
        ASDebug(('icon dictionary %s loaded'):format(Config.Icon.dict))
    end
end)

CreateThread(function()
    if not Config.ShowNames then return end

    -- A few tries, in case the first goes out before the session is ready. The
    -- full list only arrives when a client asks for it, so a request that gets
    -- lost would otherwise mean no names until somebody else changed theirs.
    -- They stop as soon as one lands, and are spaced past the servers five
    -- second cooldown so a retry is never thrown away.
    for _ = 1, 3 do
        TriggerServerEvent('activespeaker:requestNames')
        Wait(6000)

        if receivedNames then break end
    end

    if Config.NameRefreshInterval <= 0 then return end

    while true do
        Wait(Config.NameRefreshInterval)
        TriggerServerEvent('activespeaker:requestNames')
    end
end)

CreateThread(function()
    local previous = 0

    while true do
        Wait(Config.ScanInterval)

        talkers = enabled and scan() or {}

        if Config.Debug and #talkers ~= previous then
            previous = #talkers
            ASDebug(('%d talking nearby'):format(previous))
        end
    end
end)

CreateThread(function()
    while true do
        -- Nothing to draw is the normal state, so sleep properly instead of
        -- waking up every frame to find an empty list.
        local list = talkers
        local count = #list

        if count == 0 then
            Wait(200)
        else
            Wait(0)

            local origin = GetEntityCoords(PlayerPedId())

            for i = 1, count do
                local entry = list[i]

                if DoesEntityExist(entry.ped) then
                    local coords = GetEntityCoords(entry.ped)
                    local distance = #(origin - coords)
                    local fadeStart = entry.maxDist * Config.FadeStart
                    local fade = 1.0

                    if distance > fadeStart then
                        fade = 1.0 - (distance - fadeStart) / math.max(entry.maxDist - fadeStart, 0.001)
                    end

                    if fade > 0.0 then
                        local height = Config.HeightOffset

                        if IsPedInAnyVehicle(entry.ped, false) then
                            height = height + Config.VehicleHeightOffset
                        end

                        DrawText3DAnimated(coords.x, coords.y, coords.z + height,
                            entry.text, entry.color, fade)
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- Exports
-- ============================================================================

-- exports.ActiveSpeaker:setStealth(true)
exports('setStealth', function(state)
    setStealth(state)
end)

exports('isStealth', function()
    return isStealthy(PlayerPedId())
end)

-- Quiet, so a resource turning the display off does not also post in chat.
exports('setEnabled', function(state)
    setEnabled(state, true)
end)

exports('isEnabled', function()
    return enabled
end)

-- Server ids of everyone currently labelled, nearest first when MaxLabels caps
-- the list. Useful for a HUD or a subtitle resource.
exports('getTalkers', function()
    local list = talkers
    local ids = {}

    for i = 1, #list do
        ids[i] = list[i].serverId
    end

    return ids
end)
