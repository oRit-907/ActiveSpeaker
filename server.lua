--[[
    Active Speaker - server side

    Owns the data the client cannot work out on its own: the player names shown
    under the icon, and any tag another resource wants to attach to a player
    (job, rank, callsign, ...).

    Everything is replicated with state bags, so late joiners and players that
    come back into scope get the current values without asking for them.
]]

local Config = {
    -- Draw the players name under the speaking icon.
    showNames = true,

    -- Append the server id, e.g. "John Doe [12]".
    showServerIds = false,

    -- Draw tags set through the exports below.
    showTags = true,

    -- Applied to the name before it is sent to clients. %s is the player name.
    nameFormat = '%s',

    -- Only used for the startup warning below. Change it if your server runs a
    -- renamed copy of pma-voice.
    voiceResource = 'pma-voice',
}

local tags = {}

-- Nothing is replicated that the config has turned off, so a server running
-- with names and tags disabled sends no player data at all.
local function playerData(source)
    local tag = tags[source]
    local data = {}

    if Config.showNames then
        data.name = Config.nameFormat:format(GetPlayerName(source) or 'Unknown')
    end

    if Config.showTags and tag then
        data.tag = tag.text
        data.color = tag.color
    end

    return (data.name or data.tag) and data or nil
end

local function refresh(source)
    if GetPlayerName(source) then
        Player(source).state:set('activeSpeaker', playerData(source), true)
    end
end

--- Attach a tag to a player, drawn under their name while they talk.
--- @param source number player server id
--- @param text string|nil tag text, nil or '' removes it
--- @param color table|nil { r, g, b }, colours the player name and tag
local function setSpeakerTag(source, text, color)
    source = tonumber(source)

    if not source or not GetPlayerName(source) then
        return false
    end

    if text == nil or text == '' then
        tags[source] = nil
    else
        tags[source] = { text = text, color = color }
    end

    refresh(source)

    return true
end

local function clearSpeakerTag(source)
    return setSpeakerTag(source, nil)
end

--- Read back what is currently replicated for a player.
local function getSpeakerData(source)
    source = tonumber(source)

    return source and GetPlayerName(source) and playerData(source) or nil
end

exports('setSpeakerTag', setSpeakerTag)
exports('clearSpeakerTag', clearSpeakerTag)
exports('getSpeakerData', getSpeakerData)

AddEventHandler('playerJoining', function()
    refresh(source)
end)

AddEventHandler('playerDropped', function()
    tags[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    GlobalState:set('activeSpeaker', Config, true)

    for _, id in ipairs(GetPlayers()) do
        refresh(tonumber(id))
    end

    -- Warn instead of refusing to start, so servers running a renamed voice
    -- resource are not blocked. Delayed because the voice resource may still be
    -- starting alongside this one.
    SetTimeout(5000, function()
        if GetResourceState(Config.voiceResource) ~= 'started' then
            print(('[ActiveSpeaker] %s is not running, so nothing will be drawn. Update Config.voiceResource in server.lua if your voice resource is named differently.')
                :format(Config.voiceResource))
        end
    end)
end)
