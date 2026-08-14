--[[
    Active Speaker
    Draws a pulsing speaker icon above the head of every nearby player that is
    currently talking through pma-voice.

    Everything you are meant to touch lives in the Config table below.
]]

local Config = {
    -- Draw the indicator above your own head as well (useful while testing).
    showSelf = false,

    -- Players further away than this (in metres) are never drawn.
    maxDistance = 20.0,

    -- Hide the indicator when the player is behind a wall / out of sight.
    requireLineOfSight = false,

    -- Hide the indicator for players the game is not rendering, so admins in
    -- noclip or with an invisible ped are not given away by it.
    hideInvisible = true,

    -- How far above the head bone the indicator sits, in metres.
    heightOffset = 0.35,

    -- How often (ms) we rebuild the list of nearby players.
    scanInterval = 500,

    -- 'icon', 'text' or 'both'.
    display = 'icon',

    icon = {
        dict = 'mpleaderboard',
        -- Frames are cycled to fake the classic GTA:O volume bars. Use a single
        -- entry if you only want one static icon.
        frames = { 'leaderboard_audio_1', 'leaderboard_audio_2', 'leaderboard_audio_3' },
        frameTime = 120,
        size = 0.055,
        color = { 255, 255, 255 },
    },

    text = {
        -- Static label drawn under the icon. Set to '' to only show the name
        -- and tag supplied by server.lua.
        label = 'Speaking',
        font = 4,
        size = 0.5,
        color = { 255, 255, 255 },
        -- Vertical gap between the icon and the first line, in screen units.
        gap = 0.018,
        -- Vertical gap between two lines of text, in screen units.
        lineGap = 0.022,
    },

    -- Shown instead of the values above while the player talks on the radio.
    radio = {
        enabled = true,
        label = 'Radio',
        color = { 90, 200, 255 },
    },

    pulse = {
        enabled = true,
        -- Lower is faster. Time (ms) of a full pulse cycle.
        speed = 700.0,
        -- How much the indicator grows at the peak of the pulse (0.25 = +25%).
        scale = 0.25,
        -- How much the indicator fades at the trough of the pulse.
        alpha = 0.35,
    },
}

local SKEL_HEAD = 31086

-- Mirrors the Config table in server.lua. These are only used until the server
-- replicates its own values, or if server.lua is not running at all.
local serverConfig = {
    showNames = false,
    showServerIds = false,
    showTags = false,
}

-- server.lua replicates its Config through GlobalState. The change handler
-- covers later edits, the thread covers the resource starting before the value
-- has made it to us.
AddStateBagChangeHandler('activeSpeaker', 'global', function(_, _, value)
    if type(value) == 'table' then
        serverConfig = value
    end
end)

CreateThread(function()
    for _ = 1, 10 do
        if type(GlobalState.activeSpeaker) == 'table' then
            serverConfig = GlobalState.activeSpeaker
            return
        end

        Wait(500)
    end
end)

local nearby = {}
local dictLoaded = false
local debugMode = false

local function loadTextureDict()
    if dictLoaded or Config.display == 'text' then
        return
    end

    RequestStreamedTextureDict(Config.icon.dict, false)
    while not HasStreamedTextureDictLoaded(Config.icon.dict) do
        Wait(0)
    end

    dictLoaded = true
end

local function isTalking(serverId, playerIdx)
    if debugMode and playerIdx == PlayerId() then
        return true
    end

    local state = Player(serverId).state

    if state and state.talking ~= nil then
        return state.talking
    end

    return MumbleIsPlayerTalking(playerIdx) or NetworkIsPlayerTalking(playerIdx)
end

local function isOnRadio(serverId)
    if not Config.radio.enabled then
        return false
    end

    local state = Player(serverId).state

    return state ~= nil and state.radioActive == true
end

-- Name and tag replicated by server.lua. Returns nil when the server side is
-- not running or has nothing for this player yet.
local function speakerData(serverId)
    local state = Player(serverId).state

    return state and state.activeSpeaker or nil
end

local function drawText(text, x, y, scale, r, g, b, a)
    SetTextFont(Config.text.font)
    SetTextScale(0.0, Config.text.size * scale)
    SetTextColour(r, g, b, a)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Text drawn under the icon, top to bottom: player name, tag, static label.
local function buildLines(serverId, onRadio)
    local lines = {}
    local data = speakerData(serverId)
    local dataColor = (data and data.color) or Config.text.color

    if data and serverConfig.showNames and data.name then
        local name = data.name

        if serverConfig.showServerIds then
            name = ('%s [%d]'):format(name, serverId)
        end

        lines[#lines + 1] = { text = name, color = dataColor }
    end

    if data and serverConfig.showTags and data.tag then
        lines[#lines + 1] = { text = data.tag, color = dataColor }
    end

    if Config.display ~= 'icon' then
        local label = (onRadio and Config.radio.label) or Config.text.label

        if label ~= '' then
            lines[#lines + 1] = {
                text = label,
                color = (onRadio and Config.radio.color) or Config.text.color,
            }
        end
    end

    return lines
end

local function drawIndicator(ped, serverId, distance, onRadio)
    local coords = GetPedBoneCoords(ped, SKEL_HEAD, 0.0, 0.0, 0.0)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + Config.heightOffset)

    if not onScreen then
        return
    end

    -- Keep the indicator roughly the same physical size regardless of distance
    -- and of how far the player has zoomed in. Measured from the camera rather
    -- than from your ped, because that is what the projection above uses - in
    -- third person the camera sits several metres further back.
    local camDistance = math.max(0.1, #(GetGameplayCamCoord() - coords))
    local scale = math.min(1.5, math.max(0.3, (1.0 / camDistance) * (70.0 / GetGameplayCamFov()) * 2.0))
    local alpha = 255

    -- Fade out over the last quarter of the draw distance. This one stays on the
    -- distance from your ped so it lines up with where maxDistance culls.
    local fadeStart = Config.maxDistance * 0.75
    if distance > fadeStart then
        alpha = math.floor(255 * (1.0 - (distance - fadeStart) / (Config.maxDistance - fadeStart)))
    end

    if Config.pulse.enabled then
        local wave = (math.sin(GetGameTimer() / Config.pulse.speed * math.pi * 2.0) + 1.0) * 0.5
        scale = scale * (1.0 + wave * Config.pulse.scale)
        alpha = math.floor(alpha * (1.0 - Config.pulse.alpha + wave * Config.pulse.alpha))
    end

    if alpha <= 0 then
        return
    end

    local color = (onRadio and Config.radio.color) or Config.icon.color
    local textY = y

    if Config.display ~= 'text' then
        local frames = Config.icon.frames
        local frame = frames[(math.floor(GetGameTimer() / Config.icon.frameTime) % #frames) + 1]
        local width = Config.icon.size * scale
        local height = width * GetAspectRatio(false)

        DrawSprite(Config.icon.dict, frame, x, y, width, height, 0.0, color[1], color[2], color[3], alpha)
        textY = y + (height * 0.5) + (Config.text.gap * scale)
    end

    for _, line in ipairs(buildLines(serverId, onRadio)) do
        drawText(line.text, x, textY, scale, line.color[1], line.color[2], line.color[3], alpha)
        textY = textY + (Config.text.lineGap * scale)
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local origin = GetEntityCoords(ped)
        local myPlayer = PlayerId()
        local found = {}

        for _, playerIdx in ipairs(GetActivePlayers()) do
            if playerIdx ~= myPlayer or Config.showSelf or debugMode then
                local targetPed = GetPlayerPed(playerIdx)

                if DoesEntityExist(targetPed) then
                    local distance = #(origin - GetEntityCoords(targetPed))

                    -- Only the player index is kept. Ped handles are replaced on
                    -- respawn and model change, and the engine reuses them, so a
                    -- handle cached for a whole scanInterval can end up pointing
                    -- at something else entirely.
                    if distance <= Config.maxDistance then
                        found[#found + 1] = {
                            playerIdx = playerIdx,
                            serverId = GetPlayerServerId(playerIdx),
                        }
                    end
                end
            end
        end

        nearby = found
        Wait(Config.scanInterval)
    end
end)

CreateThread(function()
    loadTextureDict()

    while true do
        local count = #nearby

        if count == 0 or IsPauseMenuActive() then
            Wait(250)
        else
            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)

            for i = 1, count do
                local player = nearby[i]
                local targetPed = GetPlayerPed(player.playerIdx)

                if targetPed ~= 0 and DoesEntityExist(targetPed)
                    and (not Config.hideInvisible or IsEntityVisible(targetPed))
                    and isTalking(player.serverId, player.playerIdx) then
                    local distance = #(origin - GetEntityCoords(targetPed))

                    if distance <= Config.maxDistance
                        and (not Config.requireLineOfSight or HasEntityClearLosToEntity(ped, targetPed, 17)) then
                        drawIndicator(targetPed, player.serverId, distance, isOnRadio(player.serverId))
                    end
                end
            end

            Wait(0)
        end
    end
end)

-- Forces the indicator above your own head so the placement and size can be
-- tuned without a second player. Takes effect within one scanInterval.
RegisterCommand('activespeaker', function()
    debugMode = not debugMode

    print(('[ActiveSpeaker] debug %s. heightOffset = %.2f, icon.size = %.3f, text.size = %.2f')
        :format(debugMode and 'on' or 'off', Config.heightOffset, Config.icon.size, Config.text.size))
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and dictLoaded then
        SetStreamedTextureDictAsNoLongerNeeded(Config.icon.dict)
    end
end)
