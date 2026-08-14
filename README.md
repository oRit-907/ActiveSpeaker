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

Every option lives in the `Config` table at the top of `client.lua`:

| Option | Description |
|--------|-------------|
| `showSelf` | Also draw the indicator above your own head (handy for testing). |
| `maxDistance` | Draw distance in metres. The indicator fades out over the last quarter. |
| `requireLineOfSight` | Hide the indicator when the player is behind cover. |
| `heightOffset` | How far above the head bone the indicator sits. |
| `display` | `'icon'`, `'text'` or `'both'`. |
| `icon` | Texture dictionary, frames, frame time, size and colour of the icon. |
| `text` | Label, font, size, colour and spacing of the text. |
| `radio` | Alternate label/colour used while the player talks on the radio. |
| `pulse` | Speed, scale and alpha of the pulsing animation. |

The default icon uses the built in `mpleaderboard` dictionary and cycles through
`leaderboard_audio_1` to `leaderboard_audio_3`. Swap `icon.dict` and
`icon.frames` for your own streamed texture dictionary to use a custom icon.



# Preview
https://github.com/user-attachments/assets/9ad421a6-4b65-4c9b-97c9-579fcd1262d0


