--[[
    Checks the version in this resources fxmanifest against the one on GitHub
    and prints the result to the server console on start.
]]

local function parseVersion(value)
    local parts = {}

    for number in tostring(value):gmatch('%d+') do
        parts[#parts + 1] = tonumber(number)
    end

    return parts
end

-- Compares piece by piece rather than as text, so 1.0.10 counts as newer than
-- 1.0.9 instead of older.
local function isOlder(current, latest)
    local a, b = parseVersion(current), parseVersion(latest)

    for i = 1, math.max(#a, #b) do
        local mine, theirs = a[i] or 0, b[i] or 0

        if mine ~= theirs then
            return theirs > mine
        end
    end

    return false
end

local function checkVersion()
    local resource = GetCurrentResourceName()
    local current = GetResourceMetadata(resource, 'version', 0)

    if not current then
        ASWarn('no version set in fxmanifest, skipping the update check')
        return
    end

    ASDebug(('checking %s for a newer version than %s'):format(Config.VersionUrl, current))

    PerformHttpRequest(Config.VersionUrl, function(status, body)
        if status ~= 200 or not body then
            ASWarn(('could not reach GitHub for the update check (status %s)'):format(status))
            return
        end

        local latest = body:match("version%s+['\"]([%d%.]+)['\"]")

        if not latest then
            ASWarn('could not read the latest version from GitHub')
            return
        end

        if isOlder(current, latest) then
            ASError(('out of date. You are running %s, %s is available.'):format(current, latest))
            ASError('https://github.com/oRit-907/ActiveSpeaker')
        else
            ASPrint(('^2up to date (%s)^7'):format(current))
        end
    end, 'GET', '', { ['User-Agent'] = 'ActiveSpeaker' })
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() and Config.VersionCheck then
        checkVersion()
    end
end)
