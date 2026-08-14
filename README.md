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

# Configuration

Everything lives in the `Config` table at the top of `client.lua`:

| Option | Description |
|--------|-------------|
| `Label` | The text drawn above a talking player. Plain text only, the GTA font has no emoji. |
| `Color` | Colour of the label and icon, `{ r, g, b, a }`. |
| `ShowNames` | Prefix the label with the players character name. |
| `NameRefreshInterval` | How often (ms) each client asks the server for the name list. |
| `ShowSelf` | Also draw the label above your own head. |
| `MaxDistance` | Draw distance in metres. The label fades out over the last quarter. |
| `HeightOffset` | How far above the player the label sits. |
| `PulseAmount` | How much the label grows at the peak of the pulse. `0` disables the animation. |
| `PulseSpeed` | How long (ms) one pulse takes. |
| `ShowRadio` | Use a separate label and colour while the player talks on the radio. |
| `RadioLabel` | Text shown instead of `Label` on the radio. |
| `RadioColor` | Colour used instead of `Color` on the radio. |
| `ShowIcon` | Draw a small speaker icon above the label. |
| `Icon` | Texture dictionary, texture and size of that icon. |
| `EnableStealthMode` | Let other resources hide a player from the display. |

The icon uses the built in `mpleaderboard` dictionary. Point `Icon.dict` and
`Icon.texture` at your own streamed dictionary to use a custom one.

Radio detection reads the `radioActive` state pma-voice replicates. If your
version of pma-voice does not set it the label simply stays on `Label`, which is
what the script did before.

# Names

`server.lua` looks the character name up from the ESX style `users` table
through mysql-async and broadcasts the list to every client, which shows it as
`John Doe - Speaking...`.

Servers without mysql-async, and players with no row in `users`, fall back to
the name the player connected with, so the label still appears. Set
`ShowNames = false` to skip names entirely.

# Stealth mode

Any resource can hide a player from the display by setting a decor on their own
client:

```lua
DecorSetBool(PlayerPedId(), "txylor_stealth", true)
```

The decor is registered by this resource, so nothing else needs to declare it.



# Preview
https://github.com/user-attachments/assets/9ad421a6-4b65-4c9b-97c9-579fcd1262d0


