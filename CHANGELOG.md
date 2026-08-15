# Changelog

## 2.0.0

### Upgrading

Replace every file, then move your settings into `config.lua`. Options that used
to live at the top of `client.lua` and `server.lua` are all there now, under the
same names, so it is a copy across rather than a rewrite. Editing the old files
has no effect any more.

### Fixed

- The label never appeared. `DrawText3DAnimated` called `GetGameplayCamCoords`,
  which is not a native, so the function threw on every frame a player talked.
  The native is `GetGameplayCamCoord`.
- `server.lua` was never loaded, because `fxmanifest.lua` only declared
  `client_script`. Its name lookup and both of its events were dead code.
- Stealth mode never applied. Nothing registered the `txylor_stealth` decor, so
  `DecorExistOn` always returned false.
- The label used an emoji the GTA text font cannot render.
- The pulse was added to the scale rather than multiplied into it, so a fixed
  amount that looked right up close swamped the label at a distance.

### Added

- `config.lua`, shared by the client and the server, holding every option.
- `MaxDistance`, with the label fading out over the last quarter of it. Labels no
  longer appear above players across the map.
- Character names from QBCore, Qbox and ESX, detected automatically and
  overridable with `Config.Framework`. QBCore and Qbox read the name off the
  player object with no query. Names arrive as soon as a character loads.
- A separate label and colour for players talking on the radio.
- An optional speaker icon above the label, with a configurable dictionary and
  texture.
- `ShowSelf`, off by default. The label used to be drawn above your own head.
- A version check on server start, comparing `fxmanifest.lua` against GitHub.
- `HeightOffset`, `Color`, `PulseAmount` and `PulseSpeed` as options.
- MIT licence.

## 1.0.0

First release.
