# Active Speaker :microphone:

This will add a Visual display using pma-voice that shows above players head to allow others see who is talking.

It has pulsing animation when speaking/talking.

You can customize Icon and text to your liking using the config.lua file.

|                             |                    |
|-----------------------------|--------------------|
| dependencies | [pma-voice](https://github.com/AvarianKnight/pma-voice)       |
| Latest Version | 2.1.0       |

# Installation

1. Drop the `ActiveSpeaker` folder into your `resources` directory.
2. Add `ensure ActiveSpeaker` to your `server.cfg`, after `pma-voice`.
3. Restart the server.

Nothing else is required. On start the console prints which framework it found
for names, and warns you if pma-voice does not look like it is running.

# Commands

| Command | Who | Does |
|---------|-----|------|
| `/activespeaker` | everyone | Turns the labels on or off, for that player only. The choice is remembered on their machine across reconnects. |

Rename it with `Config.ToggleCommand`, or set that to `false` to remove it.

# Configuration

Every option lives in `config.lua`, which the client and the server share, so
it is the only file you need to edit.

Values are checked when the resource starts. Anything missing, of the wrong
type or out of range is put back to a sane default and printed to the server
console with the option name, so a typo shows up as a line you can act on
rather than as a label that quietly never appears:

```
[ActiveSpeaker] 2 config problems corrected:
  - Config.Color had no alpha, using 255
  - Config.MaxDistance is below the minimum of 1.0, using 1.0
```

### Label

| Option | Description |
|--------|-------------|
| `Locale` | Language used for the built in text. `en`, `de`, `es`, `fr`, `nl`, `pt`. |
| `Label` | Overrides the locale text drawn above a talking player. `nil` uses the locale. Plain text only, the GTA font has no emoji. |
| `RadioLabel` | The same, for players on the radio. |
| `Color` | Colour of the label and icon, `{ r, g, b, a }`. |
| `HeightOffset` | How far above the player the label sits. |
| `VehicleHeightOffset` | Added to that while the player is in a vehicle, so the label clears the roof. |
| `Font` | GTA text font. `0` chalet, `1` sign, `2` slab, `4` chalet comprime, `7` pricedown. |
| `Outline` | Thick border around the text. |
| `Shadow` | Softer drop shadow behind the text. Can be used with the outline. |

### Animation

| Option | Description |
|--------|-------------|
| `PulseAmount` | How much the label grows at the peak of the pulse. `0` disables the animation. |
| `PulseSpeed` | How long (ms) one pulse takes. |

### Icon

| Option | Description |
|--------|-------------|
| `ShowIcon` | Draw a small speaker icon above the label. |
| `Icon` | Texture dictionary, texture and size of that icon. |

The icon uses the built in `mpleaderboard` dictionary. Point `Icon.dict` and
`Icon.texture` at your own streamed dictionary to use a custom one. If the
dictionary never loads, the icon turns itself off and says so in `F8` rather
than retrying forever.

### Range

| Option | Description |
|--------|-------------|
| `MaxDistance` | Draw distance in metres. |
| `FadeStart` | Where the fade out begins, as a fraction of that distance. `0.75` fades over the last quarter, `1.0` disables the fade. |
| `MatchVoiceRange` | Match the range to how loud the player is actually talking. See below. |
| `RequireLineOfSight` | Only draw the label when nothing is in the way. |
| `IgnoreInvisible` | Skip players whose ped is not being rendered, so invisible admins do not give themselves away. |
| `ShowSelf` | Also draw the label above your own head. |
| `MaxLabels` | Most labels drawn at once, nearest first. `0` is unlimited. |
| `ScanInterval` | How often (ms) each client looks for who is talking. See below. |

### Radio

| Option | Description |
|--------|-------------|
| `ShowRadio` | Use a separate label and colour while the player talks on the radio. |
| `RadioColor` | Colour used instead of `Color` on the radio. |

Radio detection reads the `radioActive` state pma-voice replicates. If your
version of pma-voice does not set it the label simply stays on `Label`.

### Toggle

| Option | Description |
|--------|-------------|
| `ToggleCommand` | Name of the command players use to hide the labels. `false` removes it. |
| `RememberToggle` | Remember that choice across reconnects. |
| `Notify` | How the toggle confirms itself. `auto`, `chat`, `ox_lib` or `none`. |

### Names

| Option | Description |
|--------|-------------|
| `ShowNames` | Prefix the label with the players character name. |
| `Framework` | Where character names come from. See below. |
| `NameRefreshInterval` | Optional safety resync, in ms. `0` disables it, which is the default. |

### Other

| Option | Description |
|--------|-------------|
| `EnableStealthMode` | Let other resources hide a player from the display. |
| `VersionCheck` | Check GitHub for a newer version on start. |
| `VersionUrl` | The file the check reads the latest version from. |
| `Debug` | Print what the resource is doing to the server console and to `F8`. |

# Range and voice

`MaxDistance` is a flat range: everyone within it gets a label, whether they are
whispering or shouting. `MatchVoiceRange` reads the proximity pma-voice
replicates and uses that instead, so someone whispering across the street stops
getting a label you cannot hear. `MaxDistance` still applies as a hard cap, and
if your pma-voice does not replicate proximity the option quietly does nothing.

`RequireLineOfSight` stops labels showing through walls. It costs one ray per
talking player per scan, which is cheap, but it also hides people behind thin
cover, so it is off by default.

# Performance

The search for who is talking runs on `ScanInterval`, not every frame. Only the
labels that search finds are drawn every frame, and when nobody nearby is
talking, which is nearly all of the time, the drawing thread sleeps instead of
waking up to find an empty list. Lower `ScanInterval` if you want labels to
appear faster, raise it if you want the resource cheaper. 200ms is already
faster than anyone notices.

`MaxLabels` caps how many labels can be on screen at once, nearest first, for
servers where a crowd all talking together costs frames.

# Names

`server.lua` resolves each players character name and gives it to every client,
which shows it as `John Doe - Speaking...`. Set `ShowNames = false` to skip
names entirely, and the server does no name work at all.

| Framework | Detected by | Name comes from |
|-----------|-------------|-----------------|
| QBCore | `qb-core` | `PlayerData.charinfo`, no query needed |
| Qbox | `qbx_core` | `PlayerData.charinfo`, no query needed |
| ESX | `es_extended` | `xPlayer.getName()`, no query needed |
| None | nothing else running | the name the player connected with |

Detection is automatic. `Config.Framework` forces a specific one, using
`'qbcore'`, `'qbox'`, `'esx'` or `'none'`. Whichever is picked is printed to the
server console on start. If your framework is still starting when this resource
does, it keeps looking for a few seconds rather than settling on connection
names for the rest of the session.

Anyone the framework has no character for falls back to the connection name, so
the label still appears. Names are picked up as soon as a character loads, so
nobody waits for a refresh.

Names are sent as they change rather than on a timer: one copy of the list when
a client starts, then a single entry whenever someone loads a character or
leaves.

# Stealth mode

Any resource can hide a player from the display, from their client:

```lua
exports.ActiveSpeaker:setStealth(true)
```

or from the server, for any player:

```lua
exports.ActiveSpeaker:setPlayerStealth(source, true)
```

The decor used before this still works, and is still registered by this
resource, so anything already using it needs no changes:

```lua
DecorSetBool(PlayerPedId(), "txylor_stealth", true)
```

# Exports

### Client

| Export | Returns | Does |
|--------|---------|------|
| `setStealth(state)` | | Hide or show the local player. |
| `isStealth()` | boolean | Whether the local player is hidden. |
| `setEnabled(state)` | | Turn the display on or off, without the chat message the command posts. |
| `isEnabled()` | boolean | Whether the display is on. |
| `getTalkers()` | table | Server ids of everyone currently labelled, nearest first. |

### Server

| Export | Returns | Does |
|--------|---------|------|
| `getName(source)` | string | The character name currently being shown for that player. |
| `refreshName(source)` | | Look the name up again, after a character rename. |
| `setPlayerStealth(source, state)` | | Hide or show that player. |

# Version check

On start the server compares the `version` in `fxmanifest.lua` against the copy
on GitHub and prints one line to the console:

```
[ActiveSpeaker] up to date (2.1.0)
[ActiveSpeaker] out of date. You are running 2.0.0, 2.1.0 is available.
```

Releasing a new version is just bumping `version` in `fxmanifest.lua` and
pushing. No GitHub release or tag is needed, because `Config.VersionUrl` reads
the manifest on the `main` branch directly.

Versions are compared piece by piece rather than as text, so 1.0.10 is treated
as newer than 1.0.9. Set `Config.VersionCheck = false` to stop the resource
contacting GitHub at all. A failed check prints a warning and nothing else, it
never blocks the resource from starting.

# Translating

`locales.lua` holds the text players see. Copy a block, give it a key, and point
`Config.Locale` at it. Anything you leave out falls back to English rather than
showing a blank label. `Config.Label` and `Config.RadioLabel` override the
locale if you would rather just set the two strings directly.

`speaking` and `radio` are drawn in the world with the GTA text font, which has
no emoji and no non latin alphabets.

# Tests

`tests/` holds specs that stub the natives and run the real files, so the config
validation, the scan filters and the name sync can be checked without a server:

```
sh tests/run.sh
```

They need `lua5.4` and nothing else. FiveM only loads what `fxmanifest.lua`
lists, so the folder is ignored at runtime.

# Preview
https://github.com/user-attachments/assets/9ad421a6-4b65-4c9b-97c9-579fcd1262d0
