# Changelog

## 2.1.0

### Upgrading

Replace every file. `config.lua` has gained options rather than renamed any, so
your existing one still works as it is, with two things worth knowing:

- `NameRefreshInterval` now defaults to `0`. Names are pushed as they change, so
  the poll it used to drive is not needed. An existing value still works and is
  treated as an occasional resync.
- `Label` and `RadioLabel` now default to `nil`, which means "use `Config.Locale`".
  Setting them to a string still overrides the locale, so an existing config
  keeps the text it had.

Two new files are loaded by `fxmanifest.lua`, `locales.lua` and `shared.lua`, so
copying only `config.lua` across is not enough this time.

### Fixed

- ESX character names went through `MySQL.Async`, which only exists with
  mysql-async. On an oxmysql server the query was skipped and every player
  silently fell back to the name they connected with. The name is read off the
  xPlayer instead, which needs no database at all. The old query is still there
  for players with no loaded character on servers that have mysql-async.
- Every client asked the server for the name list on a timer, and each of those
  requests sent the whole list to every client. On a full server that was
  thousands of messages a minute to distribute data that changes twice an hour,
  and the event was unrated, so a modified client could use it to make the
  server broadcast on demand. The server now sends one copy when a client
  starts and a single entry when a name actually changes, and the request is
  rate limited and answered only to the client that asked.
- A texture dictionary that never loaded left a thread spinning at frame rate
  for the rest of the session. It gives up after ten seconds, turns the icon
  off and says which dictionary it was.
- Starting this resource before the framework it looks for meant connection
  names for the rest of the session. It keeps looking for a few seconds.

### Added

- `/activespeaker`, so players can hide the labels for themselves. Remembered
  across reconnects. Rename it with `Config.ToggleCommand` or remove it with
  `false`.
- Config validation on start. Anything missing, of the wrong type or out of
  range is put back to a default and printed with the option name.
- Exports, so hiding a player no longer means knowing a decor name:
  `setStealth`, `isStealth`, `setEnabled`, `isEnabled` and `getTalkers` on the
  client, `getName`, `refreshName` and `setPlayerStealth` on the server. The
  decor still works.
- `locales.lua`, with English, German, Spanish, French, Dutch and Portuguese.
- `MatchVoiceRange`, matching the draw distance to how loud the player is
  actually talking, so labels stop appearing for people you cannot hear.
- `RequireLineOfSight`, off by default, stopping labels showing through walls.
- `IgnoreInvisible`, so invisible admins and players in a cutscene do not give
  themselves away.
- `MaxLabels`, capping how many labels are drawn at once, nearest first.
- `FadeStart`, `Font`, `Outline`, `Shadow` and `VehicleHeightOffset`.
- `Debug`, printing the framework picked, names as they resolve and how many
  labels are being drawn.
- A warning when pma-voice does not look like it is running.
- `tests/`, specs that stub the natives and run the real files, so the config
  validation, scan filters and name sync can be checked without a server.

### Changed

- The search for who is talking runs on `Config.ScanInterval` (200ms) instead of
  every frame, and the drawing thread sleeps while nobody nearby is talking
  rather than waking every frame to find an empty list. Only the drawing itself
  still runs per frame.
- Internal events are named `activespeaker:*` rather than `txylor:*`. The
  `txylor_stealth` decor is unchanged, since that one is part of the API.

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
