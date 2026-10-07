--[=[
    CAMERA SUBJECT MANAGER

    Keeps the local camera pointed at whatever body the player is currently wearing.

    WHY THIS EXISTS
    ---------------
    Roblox only hooks the camera up to a character by itself when that character came
    from `Player:LoadCharacter()` / `LoadCharacterAsync()`. Fighters do not come from
    there. Pressing PLAY runs `PlayerManager._RespawnPlayer`, which destroys the lobby
    body, builds the killer rig by hand and assigns `Player.Character = char` directly.
    Assigning that property does not move the camera.

    So `workspace.CurrentCamera.CameraSubject` stayed pointed at the lobby body's
    `Humanoid` — an instance that had just been destroyed. `BaseCamera:GetSubjectPosition()`
    can't read a usable position out of a destroyed subject, so it returns
    `self.lastSubjectPosition` instead and the camera parks itself in the lobby
    permanently. That is exactly the reported symptom: your fighter teleports into the
    arena and plays normally, and the camera never goes with it.

    The lobby never had this problem because respawning after a death goes through
    `LoadEmpty()`, which *does* call `LoadCharacterAsync` — the one path the engine
    attaches the camera for.

    WHAT THIS DOES
    --------------
    1. Re-aims the camera every time the local player gets a new character.
    2. Runs a cheap watchdog that repairs the camera whenever its subject goes stale.

    It deliberately keeps its hands off a subject that is still valid and still in the
    world, so spectating another player, emote close-ups and the death ragdoll camera
    all keep working — every one of those points at something that really is in
    `workspace`.

    Set `CameraSubjectManager.Enabled = false` to hand the camera back to your own code.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CameraSubjectManager = {
    Enabled = true,
    Initialized = false,

    --[=[
        Prints one line to the Output window every time the camera is handed a new body,
        saying what it locked onto and where that body actually is.

        Leave this on while you're building. If PLAY ever looks wrong again, this line
        tells you in one glance whether the camera failed or the *spawn* failed — those
        look identical on screen and have completely different fixes. Set it to `false`
        once the game is stable.
    ]=]
    Verbose = true,
}

--- How often the stale-subject watchdog looks. It only does work when the camera is
--- genuinely broken, so this is a handful of property reads four times a second.
local WATCHDOG_INTERVAL = 0.25

--- How long to keep re-aiming at a freshly spawned rig while it streams in. Parts of a
--- character arrive over several frames, so the ideal subject (a `Humanoid` with a live
--- `RootPart`) usually isn't there on the frame `CharacterAdded` fires.
local RIG_STREAM_TIMEOUT = 5

--- The character this module aimed at most recently. Used so a slow rig that finishes
--- streaming after you've already respawned can't drag the camera back onto a body
--- you're no longer wearing.
local TrackedCharacter: Model? = nil

--[=[
    Picks what the camera should follow for a given character.

    A `Humanoid` is the ideal subject — the default camera only applies the head-height
    offset and `Humanoid.CameraOffset` for humanoid subjects. A `Humanoid` with no
    `RootPart` is useless to it though, so while the rig is still assembling we fall back
    to a plain `BasePart`. `BaseCamera` handles that case too; the camera travels with
    the body correctly, it just sits at part height until the real subject is ready.
]=]
local function GetFollowTarget(Character: Model?): Instance?
    if not Character or not Character:IsDescendantOf(workspace) then
        return nil
    end

    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    if Humanoid and Humanoid.RootPart then
        return Humanoid
    end

    local Root = Character.PrimaryPart
        or Character:FindFirstChild("HumanoidRootPart")
        or Character:FindFirstChild("Torso")
        or Character:FindFirstChild("Head")

    if Root and Root:IsA("BasePart") then
        return Root
    end

    -- Nothing better available. A rootless Humanoid still beats a destroyed instance —
    -- the camera starts working by itself the moment `RootPart` populates.
    return Humanoid
end

--[=[
    Is the camera currently following nothing usable?

    Destroyed instances keep answering property reads, so "does it still have a value"
    proves nothing. "Is it still in the world" is the test that matters, and it is
    precisely the state the camera lands in after `PlayerManager._RespawnPlayer`
    destroys the old body.
]=]
local function IsSubjectBroken(Camera: Camera): boolean
    local Subject = Camera.CameraSubject
    if not Subject then
        return true
    end

    if not Subject:IsDescendantOf(workspace) then
        return true
    end

    -- In the world but with nothing to read a position from.
    if Subject:IsA("Humanoid") and not Subject.RootPart then
        return true
    end

    return false
end

--[=[
    Points the camera at a character.

    @param Character The body to follow.
    @param TakeControl `true` on a real spawn, where the player should get their camera
                       back no matter what a cutscene left it set to. The watchdog passes
                       `false` so it can repair a broken subject without stomping on code
                       that is deliberately driving the camera by hand.
    @return `true` only once the camera is on the *ideal* subject — a `Humanoid` with a
            live `RootPart`. A `BasePart` stand-in still moves the camera correctly, but
            it's worth upgrading away from, so it reports `false`.
]=]
function CameraSubjectManager.PointAt(Character: Model?, TakeControl: boolean?): boolean
    local Camera = workspace.CurrentCamera
    if not Camera then
        return false
    end

    local Target = GetFollowTarget(Character)
    if not Target then
        return false
    end

    if TakeControl and Camera.CameraType ~= Enum.CameraType.Custom then
        -- A spawn is the moment control belongs to the player again. Without this a
        -- cutscene camera that errored partway through would leave `Scriptable` set and
        -- the camera would sit still no matter what its subject is.
        Camera.CameraType = Enum.CameraType.Custom
    end

    if Camera.CameraSubject ~= Target then
        Camera.CameraSubject = Target
    end

    return Target:IsA("Humanoid") and Target.RootPart ~= nil
end

--[=[
    Handles a new local character.

    The camera is claimed immediately, then re-aimed as the rig streams in. Waiting for
    the complete rig first would strand the camera on the old body for however long
    replication takes — which, when the old body has just been destroyed, means a frozen
    screen.
]=]
function CameraSubjectManager._OnCharacterAdded(Character: Model)
    if not CameraSubjectManager.Enabled then
        return
    end

    TrackedCharacter = Character
    CameraSubjectManager.PointAt(Character, true)

    task.spawn(function()
        -- `time()`, not `os.clock()`. In Roblox `os.clock()` measures CPU time used, not
        -- wall time, so a deadline built on it drifts badly. `time()` is the monotonic
        -- game clock.
        local Deadline = time() + RIG_STREAM_TIMEOUT

        -- Note there's deliberately no `Character.Parent` check in this condition.
        -- `CharacterAdded` can fire on the client a moment before the model itself
        -- finishes replicating into `workspace`, and bailing on a not-yet-parented
        -- character would abandon the camera in exactly the case that needs it most.
        -- `PointAt` is a no-op until the body is really there, so polling costs nothing.
        while TrackedCharacter == Character and CameraSubjectManager.Enabled do
            -- Settled on the ideal subject, nothing left to do.
            if CameraSubjectManager.PointAt(Character, true) then
                CameraSubjectManager._Report(Character)
                return
            end

            if time() >= Deadline then
                break
            end

            task.wait(0.05)
        end

        -- Only worth complaining about the body the player is actually wearing. A rig
        -- that got replaced or destroyed while we waited is not a setup problem.
        if TrackedCharacter ~= Character or LocalPlayer.Character ~= Character or not Character:IsDescendantOf(workspace) then
            return
        end

        warn(
            "[CameraSubjectManager] \""..Character.Name.."\" never produced a `Humanoid` with a live "..
            "`RootPart` within "..RIG_STREAM_TIMEOUT.." seconds, so the camera is following a body part "..
            "instead. It'll still track you, it just won't sit at head height. Give the model a `Humanoid` "..
            "and a `HumanoidRootPart` in the root of the model, and set the model's `PrimaryPart` to that "..
            "`HumanoidRootPart`."
        )
    end)
end

--[=[
    Prints what the camera ended up following and where that body is.

    The point of the position is to separate two failures that look identical from the
    player's seat. If the camera is stuck and this line reports a position out in the
    arena, the camera is the problem. If it reports the lobby, or something like
    `0, 10, 0`, then the camera is working perfectly and your character never went
    anywhere — that's a spawn-point problem in the map, not a camera one.
]=]
function CameraSubjectManager._Report(Character: Model)
    if not CameraSubjectManager.Verbose then
        return
    end

    local Camera = workspace.CurrentCamera
    local Subject = Camera and Camera.CameraSubject

    local Where = "unknown"
    local Root = Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart")
    if Root and Root:IsA("BasePart") then
        local P = Root.Position
        Where = string.format("%.0f, %.0f, %.0f", P.X, P.Y, P.Z)
    end

    print(string.format(
        "[CameraSubjectManager] Following \"%s\" via %s (CameraType=%s). Body is at %s.",
        Character.Name,
        Subject and (Subject.ClassName.." \""..Subject.Name.."\"") or "NOTHING",
        Camera and Camera.CameraType.Name or "no camera",
        Where
    ))
end

--[=[
    Repairs the camera when its subject stops being something you can see out of.

    Only fires on a genuinely broken subject, which is why spectating, emotes and the
    ragdoll death camera are all safe from it — every one of those points at an instance
    that is still in `workspace`.
]=]
function CameraSubjectManager._Watchdog()
    if not CameraSubjectManager.Enabled then
        return
    end

    local Camera = workspace.CurrentCamera
    if not Camera then
        return
    end

    -- Something is driving the camera by hand. Leave it be; it restores `Custom` itself
    -- when it's finished.
    if Camera.CameraType == Enum.CameraType.Scriptable then
        return
    end

    if not IsSubjectBroken(Camera) then
        return
    end

    CameraSubjectManager.PointAt(LocalPlayer.Character, false)
end

function CameraSubjectManager:Init()
    if RunService:IsServer() or self.Initialized then
        return
    end
    self.Initialized = true

    -- Deliberately unconditional. If this line is missing from your Output, the fix is
    -- not in the running game — the place wasn't re-synced or wasn't republished — and
    -- nothing below this point ever ran.
    print("[CameraSubjectManager] Active. The camera will follow every body you spawn into.")

    -- A plain `CharacterAdded` connection on purpose, rather than
    -- `Utils.Character.ObserveCharacter`. That helper yields on
    -- `WaitForCharacterLoaded`, which waits for `PrimaryPart` and for a `Humanoid` with
    -- an `Animator`. A hand-built rig missing any of those would leave the camera stuck
    -- forever — the exact failure this module exists to prevent.
    LocalPlayer.CharacterAdded:Connect(function(Character: Model)
        CameraSubjectManager._OnCharacterAdded(Character)
    end)

    if LocalPlayer.Character then
        CameraSubjectManager._OnCharacterAdded(LocalPlayer.Character)
    end

    task.spawn(function()
        while true do
            task.wait(WATCHDOG_INTERVAL)

            local Success, Err = pcall(CameraSubjectManager._Watchdog)
            if not Success then
                warn("[CameraSubjectManager] Watchdog errored: "..tostring(Err))
            end
        end
    end)
end

return CameraSubjectManager
