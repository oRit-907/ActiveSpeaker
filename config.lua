--[[
    Active Speaker configuration

    Shared by the client and the server, so this is the only file you need to
    edit. Everything below is safe to change without touching the scripts.
]]

Config = {}

-- ============================================================================
-- Label
-- ============================================================================

-- Text drawn above a talking player. The GTA text font has no emoji, so keep
-- this plain text.
Config.Label = "Speaking..."

-- Colour of the label and the icon, { red, green, blue, alpha }.
Config.Color = { 255, 255, 255, 230 }

-- How far above the player the label sits, in metres.
Config.HeightOffset = 1.15

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

-- Point dict and texture at your own streamed dictionary for a custom icon.
Config.Icon = {
    dict = "mpleaderboard",
    texture = "leaderboard_audio_3",
    size = 0.06
}

-- ============================================================================
-- Range
-- ============================================================================

-- Players further away than this are skipped. The label fades out over the last
-- quarter of the distance.
Config.MaxDistance = 20.0

-- Draw the label above your own head too. Off by default, you already know when
-- you are talking. Handy for checking HeightOffset and Icon.size on your own.
Config.ShowSelf = false

-- ============================================================================
-- Radio
-- ============================================================================

-- Use a separate label and colour while the player talks on a radio channel.
-- Reads the radioActive state pma-voice replicates - if your version does not
-- set it, the normal label is used.
Config.ShowRadio = true
Config.RadioLabel = "Radio"
Config.RadioColor = { 90, 200, 255, 230 }

-- ============================================================================
-- Names
-- ============================================================================

-- Prefix the label with the players character name, "John Doe - Speaking...".
Config.ShowNames = true

-- How often (ms) each client asks the server for the name list.
Config.NameRefreshInterval = 60000

-- Where character names come from: 'auto', 'qbcore', 'qbox', 'esx' or 'none'.
-- Auto picks whichever of qb-core, qbx_core or es_extended is running, and falls
-- back to the name the player connected with when none of them are.
Config.Framework = 'auto'

-- ============================================================================
-- Stealth
-- ============================================================================

-- Let other resources hide a player from the display with
-- DecorSetBool(PlayerPedId(), "txylor_stealth", true) on their own client.
Config.EnableStealthMode = true
