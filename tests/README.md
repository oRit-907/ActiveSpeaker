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
| `config_spec.lua` | Every option in `config.lua` being validated, clamped and defaulted, locale selection, and `Config.Label` overriding the locale. |
| `client_spec.lua` | The scan filters (distance, self, stealth, line of sight, invisible peds, `MaxLabels`), radio labels, voice range matching, the toggle command and its saved state, and the fade at the edge of the draw distance. |
| `server_spec.lua` | Name resolution on QBCore, Qbox, ESX and no framework, the request rate limit, names only being sent when they change, players dropping, deferred framework detection, and the version comparison. |

The client spec fakes the game loop by resuming each `CreateThread` body by
hand, so `step(n)` in there means n ticks, not n milliseconds.

Adding a spec: copy the harness header from one of the existing files, stub any
extra native you touch, and add the file to the list in `run.sh`.
