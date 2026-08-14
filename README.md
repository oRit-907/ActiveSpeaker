# Active Speaker :microphone:

This will add a Visual display using pma-voice that shows above players head to allow others see who is talking.

It has pulsing animation when speaking/talking.

You can customize Icon and text to your liking using the client.lua file.

Buy the latest version of [Active Speaker](https://store.ragecity.online/package/active-speaker) for only $4.99.

|                             |                    |
|-----------------------------|--------------------|
| dependencies | [pma-voice](https://github.com/AvarianKnight/pma-voice)       |
| Latest Version | 1.0.2       |

# Installation

1. Drop the `ActiveSpeaker` folder into your `resources` directory.
2. Add `ensure ActiveSpeaker` to your `server.cfg`, after `pma-voice`.
3. Restart the server.

pma-voice is not declared as a hard dependency, so servers running a renamed
copy of it still start. If it is missing you get a console warning instead, and
nothing is drawn. Point `Config.voiceResource` in `server.lua` at your own copy
to silence it.

Type `/activespeaker` in game to force the indicator above your own head. Handy
for tuning `heightOffset` and `icon.size` without a second player, and it prints
the current values to the F8 console.

# Configuration

Every option lives in the `Config` table at the top of `client.lua`:

| Option | Description |
|--------|-------------|
| `showSelf` | Also draw the indicator above your own head (handy for testing). |
| `maxDistance` | Draw distance in metres. The indicator fades out over the last quarter. |
| `requireLineOfSight` | Hide the indicator when the player is behind cover. |
| `hideInvisible` | Hide it for players the game is not rendering, so invisible admins are not given away. |
| `heightOffset` | How far above the head bone the indicator sits. |
| `display` | `'icon'`, `'text'` or `'both'`. |
| `icon` | Texture dictionary, frames, frame time, size and colour of the icon. |
| `text` | Label, font, size, colour and spacing of the text. |
| `radio` | Alternate label/colour used while the player talks on the radio. |
| `pulse` | Speed, scale and alpha of the pulsing animation. |

The default icon uses the built in `mpleaderboard` dictionary and cycles through
`leaderboard_audio_1` to `leaderboard_audio_3`. Swap `icon.dict` and
`icon.frames` for your own streamed texture dictionary to use a custom icon.

`display` controls the icon and the static label only. Names and tags are turned
on server side, so they keep showing even with `display = 'icon'`.

# Server side

`server.lua` owns the data the client cannot work out on its own. Its own
`Config` table decides what gets replicated:

| Option | Description |
|--------|-------------|
| `showNames` | Draw the players name under the icon. |
| `showServerIds` | Append the server id, e.g. `John Doe [12]`. |
| `showTags` | Draw tags set through the exports below. |
| `nameFormat` | Applied to the name before sending, `%s` is the player name. |
| `maxLength` | Names and tags longer than this are cut short. |
| `voiceResource` | Name of your voice resource, only used for the startup warning. |

Player names are stripped of text codes before they are sent, so nobody can
colour their own name or push extra lines above their head by renaming
themselves. `nameFormat` is not stripped, so codes like `~b~` still work there
if you want to colour the whole line.

Values are replicated with state bags, so players that join late or come back
into scope always get the current data. Anything turned off here is never sent,
so a server with `showNames` and `showTags` off replicates no player data at
all.

## Exports

Attach a tag to a player to show their job, rank or callsign while they talk.
The optional colour also recolours their name.

```lua
-- shows "Police" under the name, in blue
exports.ActiveSpeaker:setSpeakerTag(source, 'Police', { 60, 120, 255 })

-- removes it again
exports.ActiveSpeaker:clearSpeakerTag(source)

-- { name = 'John Doe', tag = 'Police', color = { 60, 120, 255 } }
local data = exports.ActiveSpeaker:getSpeakerData(source)
```



# Preview
https://github.com/user-attachments/assets/9ad421a6-4b65-4c9b-97c9-579fcd1262d0


