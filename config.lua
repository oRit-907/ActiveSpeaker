--[[
    Active Speaker configuration

    Shared by the client and the server, so this is the only file you need to
    edit. Everything below is safe to change without touching the scripts.

    Every value is checked when the resource starts. Anything missing, of the
    wrong type or out of range is clamped back to a sane default and printed to
    the server console, so a typo here never breaks the display.
]]

Config = {}

-- ============================================================================
-- Label
-- ============================================================================

-- Language used for the built in text, see locales.lua.
-- 'en', 'de', 'es', 'fr', 'nl' or 'pt' ship with the resource.
Config.Locale = 'en'

-- Text drawn above a talking player. Leave these nil to use the locale above,
-- or set a string to override it. The GTA text font has no emoji, so keep this
-- plain text.
Config.Label = nil
Config.RadioLabel = nil

-- Colour of the label and the icon, { red, green, blue, alpha }.
Config.Color = { 255, 255, 255, 230 }

-- How far above the player the label sits, in metres.
Config.HeightOffset = 1.15

-- Added to HeightOffset while the player is in a vehicle. Seat height puts the
-- label lower than it looks on foot, so a small nudge keeps it off the roof.
Config.VehicleHeightOffset = 0.25

-- GTA text font: 0 chalet, 1 sign, 2 slab, 4 chalet comprime (default), 7 pricedown.
Config.Font = 4

-- Outline is the thick border, shadow is the softer drop behind the text. Both
-- can be on at once.
Config.Outline = true
Config.Shadow = false

-- ============================================================================
-- Animation
-- ============================================================================

-- How much the label grows at the peak of the pulse. Set to 0 for no animation.
Config.PulseAmount = 0.15

-- How long (ms) one pulse takes. Lower is faster.
Config.PulseSpeed = 200

-- ============================================================================
-- Icon
-- ============================================================================

-- Small speaker icon above the label.
Config.ShowIcon = true

-- Point dict and texture at your own streamed dictionary for a custom icon. If
-- the dictionary never loads the icon turns itself off and says so in the
-- client console instead of hanging.
Config.Icon = {
    dict = "mpleaderboard",
    texture = "leaderboard_audio_3",
    size = 0.06
}

-- ============================================================================
-- Range
-- ============================================================================

-- Players further away than this are skipped, in metres.
Config.MaxDistance = 20.0

-- Where the fade out starts, as a fraction of the distance the label is drawn
-- over. 0.75 fades across the last quarter, 1.0 disables the fade.
Config.FadeStart = 0.75

-- Match the range to how loud the player is actually talking, reading the
-- proximity pma-voice replicates. Someone whispering across the street stops
-- getting a label you cannot hear. MaxDistance still applies as a hard cap, and
-- if your pma-voice does not replicate proximity this quietly does nothing.
Config.MatchVoiceRange = false

-- Only draw the label when nothing is in the way. Costs one ray per talking
-- player per scan, which is cheap, but it also hides people behind thin cover.
Config.RequireLineOfSight = false

-- Skip players whose ped is not being rendered, so invisible admins and players
-- in a cutscene do not give themselves away.
Config.IgnoreInvisible = true

-- Draw the label above your own head too. Off by default, you already know when
-- you are talking. Handy for checking HeightOffset and Icon.size on your own.
Config.ShowSelf = false

-- Most labels drawn at once, nearest first. 0 is unlimited. Worth setting on a
-- busy server if a crowd all talking at once costs you frames.
Config.MaxLabels = 0

-- How often (ms) each client looks for who is talking. The labels themselves
-- are drawn every frame, this is only the search, so 200 stays responsive while
-- doing a fraction of the work of checking every player every frame.
Config.ScanInterval = 200

-- ============================================================================
-- Radio
-- ============================================================================

-- Use a separate label and colour while the player talks on a radio channel.
-- Reads the radioActive state pma-voice replicates - if your version does not
-- set it, the normal label is used.
Config.ShowRadio = true
Config.RadioColor = { 90, 200, 255, 230 }

-- ============================================================================
-- Toggle
-- ============================================================================

-- Command players use to turn the display off for themselves. Set to false to
-- remove the command entirely.
Config.ToggleCommand = 'activespeaker'

-- Remember that choice across reconnects, stored on the players own machine.
Config.RememberToggle = true

-- How the toggle confirms itself: 'auto', 'chat', 'ox_lib' or 'none'.
-- Auto uses ox_lib when it is running and falls back to chat.
Config.Notify = 'auto'

-- ============================================================================
-- Names
-- ============================================================================

-- Prefix the label with the players character name, "John Doe - Speaking...".
Config.ShowNames = true

-- Optional safety resync, in ms. The server pushes names as they change, so
-- this is not needed. 0 disables it, anything lower than 5000 is treated as
-- 5000 by the server.
Config.NameRefreshInterval = 0

-- Where character names come from: 'auto', 'qbcore', 'qbox', 'esx' or 'none'.
-- Auto picks whichever of qb-core, qbx_core or es_extended is running, and falls
-- back to the name the player connected with when none of them are.
Config.Framework = 'auto'

-- ============================================================================
-- Version check
-- ============================================================================

-- Compare the version in fxmanifest.lua against the copy on GitHub when the
-- resource starts, and print the result to the server console. Set to false to
-- stop the resource contacting GitHub at all.
Config.VersionCheck = true

-- Read for a line like: version '1.0.0'
Config.VersionUrl = 'https://raw.githubusercontent.com/oRit-907/ActiveSpeaker/main/fxmanifest.lua'

-- ============================================================================
-- Stealth
-- ============================================================================

-- Let other resources hide a player from the display, either with the export
-- exports.ActiveSpeaker:setStealth(true) on their client, or the decor
-- DecorSetBool(PlayerPedId(), "txylor_stealth", true).
Config.EnableStealthMode = true

-- ============================================================================
-- Debug
-- ============================================================================

-- Print what the resource is doing to the server console and to F8, including
-- the framework it picked, names as they resolve and how many labels are drawn.
Config.Debug = false
