local STEALTH_DECOR = 'txylor_stealth'
local STEALTH_DECOR_ALT = 'activespeaker_stealth'
local KVP_ENABLED = 'activespeaker:enabled'
local ICON_TIMEOUT = 10000

local playerNames = {}
local talkers = {}
local tracked = {}
local iconReady = {}
local enabled = true
local receivedNames = false

-- ============================================================================
-- Drawing
-- ============================================================================

function DrawText3DAnimated(x, y, z, text, color, fade, icon)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local p = GetGameplayCamCoord()
    local distance = #(vector3(x, y, z) - p)
    local scaleBase = 200 / (GetGameplayCamFov() * math.max(distance, 0.1))

    -- Add animation pulse. It multiplies the scale rather than being added to
    -- it, so it stays proportional at any distance - added on, a fixed 0.05 is
    -- a tenth of the size up close and several times the size far away.
    local pulse = 1.0 + Config.PulseAmount * math.sin(GetGameTimer() / Config.PulseSpeed)

    -- Distance alone puts the label somewhere between filling the screen point
    -- blank and an unreadable smudge at MaxDistance, so hold it in a band that
    -- can actually be read. The pulse goes on after the clamp, otherwise it
    -- flattens out at either end.
    local base = math.min(math.max(0.35 * scaleBase, Config.MinScale), Config.MaxScale)
    local scale = base * pulse
    local alpha = math.floor(color[4] * fade)

    if alpha <= 0 then return end

    icon = icon or Config.Icon

    if Config.ShowIcon and icon and iconReady[icon.dict] then
        -- Sized off the clamped scale, so the icon keeps its proportion to the
        -- text rather than shrinking away on its own.
        local w = icon.size * (base / 0.35) * pulse
        local h = w * GetAspectRatio(false)

        DrawSprite(icon.dict, icon.texture, _x, _y - h * 0.6, w, h, 0.0,
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

local function drawListRow(x, y, text, color, alpha)
    SetTextScale(Config.List.scale, Config.List.scale)
    SetTextFont(Config.Font)
    SetTextProportional(1)
    SetTextCentre(false)
    SetTextColour(color[1], color[2], color[3], alpha)

    if Config.Outline then
        SetTextOutline()
    end

    if Config.Shadow then
        SetTextDropShadow()
    end

    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- The list in the corner. Everyone in the label list is in here too, so it
-- follows the same range, stealth and hold rules without any extra work.
-- Rows use the label's fade in and out but not its distance fade - a name at
-- the edge of the range should still be readable in a HUD panel.
local function drawList(list, count)
    local cfg = Config.List
    local rows = {}

    for i = 1, count do
        if #rows >= cfg.rows then break end

        local entry = list[i]

        if (entry.alpha or 0) > 0.01 then
            rows[#rows + 1] = entry
        end
    end

    local shown = #rows
    if shown == 0 then return end

    local titled = cfg.title and 1 or 0
    local x, y = cfg.x, cfg.y

    if cfg.background then
        local w = cfg.width + cfg.padding * 2
        local h = (shown + titled) * cfg.lineHeight + cfg.padding * 2
        local bg = cfg.backgroundColor

        -- DrawRect works from the centre, the rows work from the top left.
        DrawRect(x - cfg.padding + w * 0.5, y - cfg.padding + h * 0.5, w, h,
            bg[1], bg[2], bg[3], bg[4])
    end

    if cfg.title then
        drawListRow(x, y, L('list_title'), Config.Color, 160)
    end

    for i = 1, shown do
        local entry = rows[i]

        drawListRow(x, y + (titled + i - 1) * cfg.lineHeight,
            entry.name or (L('player') .. ' ' .. entry.serverId),
            entry.color, math.floor(entry.color[4] * entry.alpha))
    end
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
        tracked = {}
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
-- Diagnostics
-- ============================================================================

local function nameCount()
    local count = 0

    -- Keyed by server id, so # does not count it.
    for _ in pairs(playerNames) do
        count = count + 1
    end

    return count
end

-- Everything someone would otherwise have to ask for on a forum thread. The
-- server fills in its half through activespeaker:debugReply.
local function printDiagnostics()
    local players, withRadio, withProximity = 0, 0, 0

    for _, player in ipairs(GetActivePlayers()) do
        players = players + 1

        local state = Player(GetPlayerServerId(player)).state

        if state then
            if state.radioActive ~= nil then withRadio = withRadio + 1 end
            if state.proximity ~= nil then withProximity = withProximity + 1 end
        end
    end

    ASPrint('---- diagnostics ----')
    ASPrint(('version         %s'):format(GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'))
    ASPrint(('labels          %s'):format(enabled and 'on' or 'off (turn them back on with the command)'))
    ASPrint(('pma-voice       %s'):format(GetResourceState('pma-voice')))
    ASPrint(('icon            %s'):format(
        not Config.ShowIcon and 'off'
        or (iconReady[Config.Icon.dict] and ('loaded (%s)'):format(Config.Icon.dict)
            or ('NOT loaded (%s)'):format(Config.Icon.dict))))
    ASPrint(('names           %s'):format(
        not Config.ShowNames and 'off'
        or (receivedNames and ('%d received'):format(nameCount())
            or 'nothing received from the server yet')))
    ASPrint(('talking nearby  %d'):format(#talkers))
    ASPrint(('players near    %d, replicating radioActive %d, proximity %d'):format(players, withRadio, withProximity))
    ASPrint(('range           %.1fm, fade from %.0f%%, scale %.2f to %.2f'):format(
        Config.MaxDistance, Config.FadeStart * 100, Config.MinScale, Config.MaxScale))
    ASPrint(('hold %dms, fade %dms, scan %dms'):format(Config.HoldTime, Config.FadeTime, Config.ScanInterval))

    if GetResourceState('pma-voice') ~= 'started' then
        ASWarn('pma-voice is not started under that name, so nobody will ever show as talking')
    end

    if Config.ShowRadio and players > 0 and withRadio == 0 then
        ASWarn('ShowRadio is on but nobody is replicating radioActive, the radio label will never appear')
    end

    if Config.MatchVoiceRange and players > 0 and withProximity == 0 then
        ASWarn('MatchVoiceRange is on but nobody is replicating proximity, MaxDistance is being used instead')
    end

    if Config.ShowNames and not receivedNames then
        ASWarn('no name list has arrived, check the server console for the framework line')
    end

    TriggerServerEvent('activespeaker:requestDebug')
end

RegisterNetEvent('activespeaker:debugReply', function(info)
    ASPrint(('framework       %s (from the server)'):format(info.framework or 'unknown'))
    ASPrint(('names resolved  %d (from the server)'):format(info.names or 0))
    ASPrint('---- end ----')
end)

-- ============================================================================
-- Names
-- ============================================================================

RegisterNetEvent('activespeaker:syncNames', function(names)
    playerNames = names or {}
    receivedNames = true
    ASDebug(('received %d names'):format(nameCount()))
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
    local now = GetGameTimer()
    local me = PlayerId()
    local myPed = PlayerPedId()
    local origin = GetEntityCoords(myPed)
    local linger = Config.HoldTime + Config.FadeTime

    -- Only worth paying for the server id lookup on silent players while
    -- somebody is still inside their hold window.
    local anyTracked = next(tracked) ~= nil

    for _, player in ipairs(GetActivePlayers()) do
        local talking = NetworkIsPlayerTalking(player)

        if talking or anyTracked then
            local serverId = GetPlayerServerId(player)
            local entry = tracked[serverId]

            if talking then
                if not entry then
                    entry = { firstSeen = now, occ = 1.0 }
                    tracked[serverId] = entry
                end

                entry.lastTalking = now
            end

            -- Voice detection drops out between words, so a player counts as
            -- talking until their hold and fade have run out. Without this the
            -- label flickers through an ordinary sentence.
            local held = entry and (now - entry.lastTalking) <= linger

            if held then
                local isSelf = player == me

                if not isSelf or Config.ShowSelf then
                    local ped = GetPlayerPed(player)

                    if ped ~= 0 and DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        local distance = #(origin - coords)

                        local state
                        if Config.ShowRadio or Config.MatchVoiceRange then
                            state = Player(serverId).state
                        end

                        local maxDist = voiceRange(state)

                        local visible = isSelf
                            or not Config.IgnoreInvisible
                            or IsEntityVisible(ped)

                        local alive = isSelf
                            or not Config.HideWhenDead
                            or not IsPedDeadOrDying(ped, true)

                        local hidden = Config.EnableStealthMode and isStealthy(ped)

                        -- Checked last, it is the only one that costs a ray.
                        local occluded = false
                        if not isSelf and Config.RequireLineOfSight then
                            occluded = not HasEntityClearLosToEntity(myPed, ped, 17)
                        end

                        local dropped = occluded and Config.OccludedAlpha <= 0.0

                        if distance <= maxDist and visible and alive and not hidden and not dropped then
                            local onRadio = Config.ShowRadio and state ~= nil and state.radioActive == true
                            local label = onRadio and Config.RadioLabel or Config.Label
                            local name = Config.ShowNames and playerNames[serverId] or nil

                            found[#found + 1] = {
                                ped = ped,
                                serverId = serverId,
                                name = name,
                                text = name and (name .. ' - ' .. label) or label,
                                color = onRadio and Config.RadioColor or Config.Color,
                                icon = onRadio and (Config.RadioIcon or Config.Icon) or Config.Icon,
                                occluded = occluded,
                                maxDist = maxDist,
                                distance = distance
                            }
                        end
                    end
                end
            end
        end
    end

    -- Nearest first, so the list reads sensibly, getTalkers is ordered and a
    -- cap drops the labels furthest away rather than whichever players happened
    -- to come back last from GetActivePlayers.
    table.sort(found, byDistance)

    if Config.MaxLabels > 0 and #found > Config.MaxLabels then
        for i = #found, Config.MaxLabels + 1, -1 do
            found[i] = nil
        end
    end

    -- Anyone whose hold and fade are well past is dropped, which is also how
    -- players who disconnected leave the table.
    for serverId, entry in pairs(tracked) do
        if now - entry.lastTalking > linger + 1000 then
            tracked[serverId] = nil
        end
    end

    return found
end

-- How solid a label should be right now: fading in when it appears, holding
-- while they talk, fading out once they stop, and dimmed behind cover.
local function timeAlpha(entry, now)
    local state = tracked[entry.serverId]
    if not state then return 0.0 end

    local alpha = 1.0
    local since = now - state.lastTalking

    if since > Config.HoldTime then
        if Config.FadeTime <= 0 then return 0.0 end

        alpha = 1.0 - (since - Config.HoldTime) / Config.FadeTime
    end

    if Config.FadeTime > 0 then
        local appearing = (now - state.firstSeen) / Config.FadeTime

        if appearing < alpha then
            alpha = appearing
        end
    end

    -- Eased rather than snapped, so walking behind a pillar dims the label
    -- instead of blinking it.
    local target = entry.occluded and Config.OccludedAlpha or 1.0
    state.occ = state.occ + (target - state.occ) * math.min(1.0, GetFrameTime() * 10.0)

    return math.min(alpha, 1.0) * state.occ
end

-- ============================================================================
-- Threads
-- ============================================================================

local function loadDict(dict)
    if iconReady[dict] then return true end

    RequestStreamedTextureDict(dict, false)

    -- Giving up matters here. A dictionary that is never going to load, because
    -- of a typo or because it is not streamed, used to leave this thread
    -- spinning at frame rate for the rest of the session.
    local deadline = GetGameTimer() + ICON_TIMEOUT

    while not HasStreamedTextureDictLoaded(dict) do
        if GetGameTimer() > deadline then
            return false
        end

        Wait(50)
    end

    iconReady[dict] = true
    ASDebug(('icon dictionary %s loaded'):format(dict))

    return true
end

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
        RegisterCommand(Config.ToggleCommand, function(_, args)
            local sub = args and args[1] and tostring(args[1]):lower() or nil

            if sub == 'debug' or sub == 'status' then
                printDiagnostics()
            elseif sub == 'on' then
                setEnabled(true)
            elseif sub == 'off' then
                setEnabled(false)
            else
                setEnabled(not enabled)
            end
        end, false)

        TriggerEvent('chat:addSuggestion', '/' .. Config.ToggleCommand, L('toggle_cmd'), {
            { name = 'on|off|debug', help = 'optional' }
        })
    end

    if Config.ShowIcon then
        if not loadDict(Config.Icon.dict) then
            Config.ShowIcon = false
            ASWarn(("could not load texture dictionary '%s', the icon is off")
                :format(Config.Icon.dict))
            return
        end

        if Config.RadioIcon and not loadDict(Config.RadioIcon.dict) then
            ASWarn(("could not load texture dictionary '%s', the radio icon falls back to the normal one")
                :format(Config.RadioIcon.dict))
            Config.RadioIcon = nil
        end
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
        local list = talkers
        local count = #list

        if count == 0 then
            -- Nothing to draw is the normal state, so sleep properly instead of
            -- waking up every frame to find an empty list.
            Wait(200)
        elseif Config.HideInPauseMenu and (IsPauseMenuActive() or IsScreenFadedOut()) then
            Wait(200)
        else
            Wait(0)

            local now = GetGameTimer()
            local origin = GetEntityCoords(PlayerPedId())

            for i = 1, count do
                local entry = list[i]
                entry.alpha = 0.0

                if DoesEntityExist(entry.ped) then
                    local coords = GetEntityCoords(entry.ped)
                    local distance = #(origin - coords)
                    local fadeStart = entry.maxDist * Config.FadeStart

                    -- Kept separately from the distance fade, the corner list
                    -- wants this half of it on its own.
                    entry.alpha = timeAlpha(entry, now)

                    local fade = entry.alpha

                    if distance > fadeStart then
                        fade = fade * (1.0 - (distance - fadeStart) / math.max(entry.maxDist - fadeStart, 0.001))
                    end

                    if fade > 0.0 then
                        local height = Config.HeightOffset

                        if IsPedInAnyVehicle(entry.ped, false) then
                            height = height + Config.VehicleHeightOffset
                        end

                        DrawText3DAnimated(coords.x, coords.y, coords.z + height,
                            entry.text, entry.color, fade, entry.icon)
                    end
                end
            end

            if Config.ShowList then
                drawList(list, count)
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

-- Server ids of everyone currently labelled, nearest first. Useful for a HUD or
-- a subtitle resource.
exports('getTalkers', function()
    local list = talkers
    local ids = {}

    for i = 1, #list do
        ids[i] = list[i].serverId
    end

    return ids
end)
