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
| `ShowNames` | Prefix the label with the players character name. |
| `NameRefreshInterval` | How often (ms) each client asks the server for the name list. |
| `EnableStealthMode` | Let other resources hide a player from the display. |

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


