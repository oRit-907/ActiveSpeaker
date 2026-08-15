# Tests

These are not part of the resource. FiveM only loads what `fxmanifest.lua`
lists, so this folder is ignored at runtime and you can delete it before
uploading if you would rather not ship it.

Each spec stubs the natives it needs and drives the real files from the folder
above, so they run anywhere Lua 5.4 does, with no server involved:

```
sh tests/run.sh
```

| Spec | Covers |
|------|--------|
| `config_spec.lua` | Every option in `config.lua` being validated, clamped and defaulted, the nested `Icon`, `RadioIcon` and `List` tables, locale selection, `Config.Label` overriding the locale, and every locale having every key. |
| `client_spec.lua` | The scan filters (distance, self, stealth, line of sight, invisible peds, dead peds, `MaxLabels`), scale clamping, hold time and the fade in and out, occlusion dimming, radio labels and icons, voice range matching, the pause menu, the corner list, the toggle command with its arguments and saved state, and the name sync. |
| `server_spec.lua` | Name resolution on QBCore, Qbox, ESX and no framework, the request rate limit, names only being sent when they change, players dropping, deferred framework detection, the admin and status commands, the debug reply, and the version comparison. |

The client spec fakes the game loop by resuming each `CreateThread` body by
hand. `step(n)` means n passes over every thread, and moves the clock on by
250ms each time so the hold and fade timings behave like they would in game;
`warp(ms)` moves the clock without running anything.

Two things to know when adding assertions there: drawing happens every frame, so
`world.drawn` accumulates and usually wants clearing before the frame you want
to look at, and the draw thread works from the list the scan produced on the
previous pass, so give it a step to catch up.

Adding a spec: copy the harness header from one of the existing files, stub any
extra native you touch, and add the file to the list in `run.sh`.
