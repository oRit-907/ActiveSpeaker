"""Load client.lua under stubbed FiveM natives and exercise the draw path.

Checks the maths that is awkward to eyeball in game: sprite aspect, distance
scaling, the fade near maxDistance and the order and colour of the text lines.
It says nothing about how any of it looks on screen.

    pip install lupa
    python3 tests/render_test.py

Not part of the resource. The server never loads this directory.
"""
import os
from lupa import LuaRuntime

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "client.lua")

PRELUDE = r'''
-- vector3 stand-in supporting the "#(a - b)" distance idiom
local vmt = {}
vmt.__index = vmt
vmt.__sub = function(a, b) return setmetatable({x=a.x-b.x, y=a.y-b.y, z=a.z-b.z}, vmt) end
vmt.__len = function(v) return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) end
function vec3(x, y, z) return setmetatable({x=x, y=y, z=z}, vmt) end

drawn = { sprites = {}, texts = {} }
scene = {
    target = vec3(0.0, 0.0, 0.0),   -- head bone of the player being drawn
    cam    = vec3(0.0, -8.0, 0.0),  -- camera position
    time   = 0,
    state  = {},                    -- statebag contents per server id
    global = nil,
}

function AddStateBagChangeHandler() end
function CreateThread() end
function Wait() end
function RegisterCommand() end
function AddEventHandler() end
function GetCurrentResourceName() return 'ActiveSpeaker' end
function RequestStreamedTextureDict() end
function HasStreamedTextureDictLoaded() return true end
function SetStreamedTextureDictAsNoLongerNeeded() end

function Player(id) return { state = scene.state[id] } end
GlobalState = setmetatable({}, { __index = function(_, k)
    return k == 'activeSpeaker' and scene.global or nil
end })

function MumbleIsPlayerTalking() return false end
function NetworkIsPlayerTalking() return false end

function GetPedBoneCoords() return scene.target end
function GetGameplayCamCoord() return scene.cam end
function GetGameplayCamFov() return 50.0 end
function GetGameTimer() return scene.time end
function GetAspectRatio() return 1.777 end
function World3dToScreen2d() return true, 0.5, 0.5 end

function DrawSprite(dict, tex, x, y, w, h, rot, r, g, b, a)
    drawn.sprites[#drawn.sprites+1] = { tex=tex, x=x, y=y, w=w, h=h, r=r, g=g, b=b, a=a }
end

local pending = {}
function SetTextFont() end
function SetTextScale(_, s) pending.scale = s end
function SetTextColour(r, g, b, a) pending.r, pending.g, pending.b, pending.a = r, g, b, a end
function SetTextCentre() end
function SetTextOutline() end
function SetTextEntry() end
function AddTextComponentString(t) pending.text = t end
function DrawText(x, y)
    pending.x, pending.y = x, y
    drawn.texts[#drawn.texts+1] = pending
    pending = {}
end

function PlayerId() return 1 end
function PlayerPedId() return 100 end
function GetActivePlayers() return {} end
function GetPlayerPed() return 0 end
function GetPlayerServerId(i) return i end
function GetEntityCoords() return vec3(0.0, 0.0, 0.0) end
function DoesEntityExist() return true end
function IsEntityVisible() return true end
function IsPauseMenuActive() return false end
function HasEntityClearLosToEntity() return true end
'''

EPILOGUE = r'''
return {
    Config = Config,
    drawIndicator = drawIndicator,
    buildLines = buildLines,
    setServerConfig = function(t) serverConfig = t end,
}
'''

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(PRELUDE)
mod = lua.execute(open(SRC).read() + EPILOGUE)
G = lua.globals()

failures = []


def check(name, cond, detail=""):
    print(("PASS  " if cond else "FAIL  ") + name + (f"   {detail}" if detail else ""))
    if not cond:
        failures.append(name)


def reset(**kw):
    G.drawn.sprites = lua.table()
    G.drawn.texts = lua.table()
    G.scene.state = lua.table()
    G.scene.global_ = None
    for k, v in kw.items():
        setattr(G.scene, k, v)


def sprites():
    return list(G.drawn.sprites.values())


def texts():
    return list(G.drawn.texts.values())


# --- icon geometry --------------------------------------------------------
# Peak of the pulse is deterministic: sin peaks at t = speed/4 = 175ms.
reset(time=175)
mod.drawIndicator(101, 1, 5.0, False)
s = sprites()
check("one sprite drawn for a talking player", len(s) == 1)
if s:
    check("sprite is square after aspect correction",
          abs(s[0]["h"] / s[0]["w"] - 1.777) < 0.001,
          f"w={s[0]['w']:.4f} h={s[0]['h']:.4f}")
    check("sprite alpha within byte range", 0 < s[0]["a"] <= 255, f"a={s[0]['a']}")

# --- camera distance drives scale, ped distance does not ------------------
reset(time=175)
mod.drawIndicator(101, 1, 5.0, False)
near_cam = sprites()[0]["w"]
G.scene.cam = G.vec3(0.0, -20.0, 0.0)
reset(time=175, cam=G.vec3(0.0, -20.0, 0.0))
mod.drawIndicator(101, 1, 5.0, False)
far_cam = sprites()[0]["w"]
check("moving only the camera back shrinks the icon", far_cam < near_cam,
      f"{near_cam:.4f} -> {far_cam:.4f}")

# --- distance fade --------------------------------------------------------
reset(time=175, cam=G.vec3(0.0, -8.0, 0.0))
mod.drawIndicator(101, 1, 5.0, False)
close_a = sprites()[0]["a"]
reset(time=175, cam=G.vec3(0.0, -8.0, 0.0))
mod.drawIndicator(101, 1, 18.0, False)   # inside the last quarter of 20m
fading = sprites()
check("indicator fades near max distance",
      len(fading) == 1 and fading[0]["a"] < close_a,
      f"{close_a} -> {fading[0]['a'] if fading else 'none'}")

reset(time=175, cam=G.vec3(0.0, -8.0, 0.0))
mod.drawIndicator(101, 1, 20.0, False)   # exactly at max distance
check("nothing drawn at max distance", len(sprites()) == 0 and len(texts()) == 0)

# --- scale clamps ---------------------------------------------------------
reset(time=175, cam=G.vec3(0.0, -0.05, 0.0))  # camera inside the head
mod.drawIndicator(101, 1, 1.0, False)
check("no divide-by-zero when the camera is on top of the ped",
      len(sprites()) == 1 and sprites()[0]["w"] < 1.0,
      f"w={sprites()[0]['w']:.4f}" if sprites() else "")

# --- server supplied lines ------------------------------------------------
reset(time=175, cam=G.vec3(0.0, -8.0, 0.0))
G.scene.state[7] = lua.table_from({
    "activeSpeaker": lua.table_from({
        "name": "John Doe",
        "tag": "Police",
        "color": lua.table_from([60, 120, 255]),
    })
})
mod.setServerConfig(lua.table_from({"showNames": True, "showServerIds": True, "showTags": True}))
mod.Config.display = "both"
mod.drawIndicator(101, 7, 5.0, False)
lines = [t["text"] for t in texts()]
check("name, tag and label stack in order",
      lines == ["John Doe [7]", "Police", "Speaking"], str(lines))
ys = [t["y"] for t in texts()]
check("each line sits below the last", ys == sorted(ys) and len(set(ys)) == 3,
      str([round(y, 4) for y in ys]))
check("server colour applied to name and tag, not the static label",
      texts()[0]["r"] == 60 and texts()[1]["r"] == 60 and texts()[2]["r"] == 255)

# --- radio ----------------------------------------------------------------
reset(time=175, cam=G.vec3(0.0, -8.0, 0.0))
mod.drawIndicator(101, 1, 5.0, True)
check("radio swaps the label and colours the icon",
      texts()[0]["text"] == "Radio" and sprites()[0]["b"] == 255
      and texts()[0]["r"] == 90, str([texts()[0]["text"], sprites()[0]["r"]]))

# --- names off ------------------------------------------------------------
reset(time=175, cam=G.vec3(0.0, -8.0, 0.0))
mod.setServerConfig(lua.table_from({"showNames": False, "showServerIds": False, "showTags": False}))
mod.Config.display = "icon"
mod.drawIndicator(101, 7, 5.0, False)
check("icon only display draws no text", len(texts()) == 0 and len(sprites()) == 1)

print()
print("FAILURES: " + (", ".join(failures) if failures else "none"))
raise SystemExit(1 if failures else 0)
