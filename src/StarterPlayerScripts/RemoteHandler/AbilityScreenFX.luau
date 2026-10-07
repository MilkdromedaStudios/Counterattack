--[=[
    ABILITY SCREEN FX

    Post-process and overlay effects a killer's ability can ask a client to run on itself.

    WHY THIS HAS TO BE A CLIENT SCRIPT
    ---------------------------------
    Everything else in `Modules.AbilityFX` is parts and particles, which the server can
    create and let replicate. Post-processing effects live in `Lighting` and are per-player
    by nature, the camera is client-owned, and a full-screen overlay belongs to one
    `PlayerGui`. There is no server-side way to dim one person's screen.

    So the server names a KIND and a strength, and this decides what that looks like. The
    vocabulary is closed on purpose: a server message cannot ask for arbitrary properties on
    arbitrary instances, only for one of the effects below.

    DESIGN RULES, WHICH ARE BALANCE RULES
    ------------------------------------
      * NOTHING HERE FULLY BLINDS ANYONE. `Dark` bottoms out at a dim screen you can still
        navigate, and `Flash` fades from partial white. An effect that takes away a player's
        ability to see is a stun with extra steps, and the engine already has `Blindness`
        for a graded version of that.
      * Everything is time-boxed and self-removing. A dropped remote, a death mid-effect or
        a round ending cannot leave somebody with a permanently green screen: the instances
        are parented under one folder that is wiped on respawn.
      * Overlapping effects of the same kind refresh rather than stack, so being hit by four
        glitch projectiles is not four times as unreadable as one.
]=]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

--- One effect of each kind at a time, keyed by kind.
local Active: {[string]: any} = {}

--- Where the post-process instances live, so they can all be cleared at once.
local Holder: Folder? = nil

local function GetHolder(): Folder
    if Holder and Holder.Parent then
        return Holder
    end

    Holder = Instance.new("Folder")
    Holder.Name = "AbilityScreenFX"
    Holder.Parent = Lighting

    return Holder
end

--- Full-screen overlay parent, for the washes that aren't post-processing.
local function GetOverlay(): Frame?
    local Gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not Gui then
        return nil
    end

    local Screen = Gui:FindFirstChild("AbilityScreenFXGui")
    if not Screen then
        Screen = Instance.new("ScreenGui")
        Screen.Name = "AbilityScreenFXGui"
        Screen.ResetOnSpawn = false
        Screen.IgnoreGuiInset = true
        -- Above gameplay HUD, below menus. Menus sit at 10+ in this project.
        Screen.DisplayOrder = 5
        Screen.Parent = Gui
    end

    local Frame = Screen:FindFirstChild("Overlay")
    if not Frame then
        Frame = Instance.new("Frame")
        Frame.Name = "Overlay"
        Frame.Size = UDim2.fromScale(1, 1)
        Frame.BackgroundColor3 = Color3.new(0, 0, 0)
        Frame.BackgroundTransparency = 1
        Frame.BorderSizePixel = 0
        Frame.ZIndex = 0
        Frame.Active = false
        -- Must never eat clicks. An overlay that swallows input is a soft stun.
        Frame.Selectable = false
        Frame.Parent = Screen
    end

    return Frame
end

--------------------------------------------------------------------------------
-- PRIMITIVES
--------------------------------------------------------------------------------

--[=[
    Runs `apply(alpha)` from 0 to 1 and back to 0 over `duration`.

    Every effect below is some property driven by this envelope, which is what makes them
    all fade in and out instead of snapping — and what guarantees they all end at zero even
    if the player dies halfway through, because the loop is bounded by elapsed time rather
    than waiting for a second message.
]=]
local function Envelope(kind: string, duration: number, apply: (alpha: number) -> (), cleanup: () -> ())
    -- Refresh rather than stack: a second hit extends the effect, it doesn't double it.
    local Existing = Active[kind]
    if Existing then
        Existing.Cancelled = true
    end

    local State = {Cancelled = false}
    Active[kind] = State

    task.spawn(function()
        local Elapsed = 0
        -- Quarter of the window rising, quarter falling, half held.
        local Rise = math.min(duration * 0.25, 0.25)

        while Elapsed < duration and not State.Cancelled do
            Elapsed += task.wait()

            local Alpha
            if Elapsed < Rise then
                Alpha = Elapsed / Rise
            elseif Elapsed > duration - Rise then
                Alpha = math.max((duration - Elapsed) / Rise, 0)
            else
                Alpha = 1
            end

            apply(math.clamp(Alpha, 0, 1))
        end

        if Active[kind] == State then
            Active[kind] = nil
        end

        cleanup()
    end)
end

--- A `ColorCorrectionEffect` that removes itself.
local function Correction(): ColorCorrectionEffect
    local Effect = Instance.new("ColorCorrectionEffect")
    Effect.Parent = GetHolder()
    return Effect
end

--------------------------------------------------------------------------------
-- THE EFFECTS
--------------------------------------------------------------------------------

local Effects = {}

--[=[
    GLITCH — 1x1x1x1's corruption.

    Hue rotation plus a saturation lift, flickering on a stutter rather than a smooth curve.
    The stutter is the whole effect: a smooth hue shift reads as "pretty", a jittering one
    reads as "something is wrong with the game".
]=]
function Effects.Glitch(duration: number, intensity: number)
    local Effect = Correction()

    Envelope("Glitch", duration, function(alpha)
        local Jitter = math.random() < 0.35 and 1 or 0.15
        Effect.TintColor = Color3.fromRGB(
            255 - 90 * alpha * Jitter * intensity,
            255,
            255 - 60 * alpha * Jitter * intensity
        )
        Effect.Saturation = 0.6 * alpha * Jitter * intensity
        Effect.Contrast = 0.35 * alpha * Jitter * intensity
    end, function()
        Effect:Destroy()
    end)
end

--[=[
    DARK — Freddy's power outage.

    Brightness down and a black wash up, both capped: at full strength this is a dim room,
    not a black screen. Deliberately short of blinding, as the header says.
]=]
function Effects.Dark(duration: number, intensity: number)
    local Effect = Correction()
    local Overlay = GetOverlay()

    Envelope("Dark", duration, function(alpha)
        local Strength = alpha * math.clamp(intensity, 0, 1)
        Effect.Brightness = -0.25 * Strength
        Effect.Contrast = -0.12 * Strength

        if Overlay then
            -- 0.55 at the very worst. You can still see the map and the people in it.
            Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
            Overlay.BackgroundTransparency = 1 - 0.55 * Strength
        end
    end, function()
        Effect:Destroy()
        if Overlay then
            Overlay.BackgroundTransparency = 1
        end
    end)
end

--[=[
    FLASH — Luigi's Strobulb, Pikachu's bolts, a camera going off.

    A hard white wash with a very fast rise and a slow fall, which is what a real flash does
    to your eyes. Peaks below full white on purpose.
]=]
function Effects.Flash(duration: number, intensity: number)
    local Overlay = GetOverlay()
    if not Overlay then
        return
    end

    local Effect = Correction()

    Envelope("Flash", duration, function(alpha)
        local Strength = alpha * math.clamp(intensity, 0, 1)
        Overlay.BackgroundColor3 = Color3.new(1, 1, 1)
        Overlay.BackgroundTransparency = 1 - 0.7 * Strength
        Effect.Brightness = 0.1 * Strength
    end, function()
        Overlay.BackgroundTransparency = 1
        Effect:Destroy()
    end)
end

--[=[
    MIST — Fog's banks, and anything else that should make the world unreadable at range
    without taking away what's in front of you.

    A blur plus a desaturating grey wash. Blur is the right tool here precisely because it
    degrades DISTANCE first: you can still fight the person next to you.
]=]
function Effects.Mist(duration: number, intensity: number)
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 0
    Blur.Parent = GetHolder()

    local Effect = Correction()
    local Overlay = GetOverlay()

    Envelope("Mist", duration, function(alpha)
        local Strength = alpha * math.clamp(intensity, 0, 2)
        Blur.Size = 10 * Strength
        Effect.Saturation = -0.4 * Strength

        if Overlay then
            Overlay.BackgroundColor3 = Color3.fromRGB(205, 210, 215)
            Overlay.BackgroundTransparency = 1 - 0.3 * Strength
        end
    end, function()
        Blur:Destroy()
        Effect:Destroy()
        if Overlay then
            Overlay.BackgroundTransparency = 1
        end
    end)
end

--[=[
    ZAP — being electrified.

    A yellow-white tint with a high-frequency flicker and a contrast spike. Short by design;
    this is an on-hit punctuation mark, not a status.
]=]
function Effects.Zap(duration: number, intensity: number)
    local Effect = Correction()

    Envelope("Zap", duration, function(alpha)
        local Flicker = math.random() < 0.5 and 1 or 0.3
        local Strength = alpha * Flicker * math.clamp(intensity, 0, 2)
        Effect.TintColor = Color3.fromRGB(255, 255, 255 - 70 * Strength)
        Effect.Brightness = 0.12 * Strength
        Effect.Contrast = 0.3 * Strength
    end, function()
        Effect:Destroy()
    end)
end

--[=[
    CHILL — Superman's freeze breath, and anything else that slows.

    A cold blue tint and a slight vignette-ish darkening. Pairs with the `Slowness` effect
    so a slow has a visual, which it previously did not: being slowed was invisible except
    in the effects list.
]=]
function Effects.Chill(duration: number, intensity: number)
    local Effect = Correction()
    local Overlay = GetOverlay()

    Envelope("Chill", duration, function(alpha)
        local Strength = alpha * math.clamp(intensity, 0, 2)
        Effect.TintColor = Color3.fromRGB(255 - 60 * Strength, 255 - 25 * Strength, 255)
        Effect.Saturation = -0.2 * Strength

        if Overlay then
            Overlay.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
            Overlay.BackgroundTransparency = 1 - 0.18 * Strength
        end
    end, function()
        Effect:Destroy()
        if Overlay then
            Overlay.BackgroundTransparency = 1
        end
    end)
end

--[=[
    WOOZY — the Minion's banana, Fall Guy's shove, anything that should feel clumsy.

    Camera ROLL rather than a tint: the screen tilts and rights itself. It is disorienting
    without hiding anything, which is exactly the right trade for a comedy slip — you can
    see perfectly, you just can't aim for a second.
]=]
function Effects.Woozy(duration: number, intensity: number)
    local Camera = workspace.CurrentCamera
    if not Camera then
        return
    end

    local Connection: RBXScriptConnection? = nil
    local Roll = 0

    Connection = RunService.RenderStepped:Connect(function()
        local Current = workspace.CurrentCamera
        if Current then
            Current.CFrame = Current.CFrame * CFrame.Angles(0, 0, math.rad(Roll))
        end
    end)

    Envelope("Woozy", duration, function(alpha)
        -- A slow sine, so it sways rather than vibrates.
        Roll = math.sin(os.clock() * 4) * 9 * alpha * math.clamp(intensity, 0, 2)
    end, function()
        Roll = 0
        if Connection then
            Connection:Disconnect()
        end
    end)
end

--[=[
    RAGE — the warning that something has decided to come for you specifically.

    Red vignette and a pulse. Enderman's stare, Baldi's charge, a Rainbow Friend's roar.
    Reads as a threat indicator rather than an impairment, which is what it is: it costs
    nothing mechanically and it tells the player to move.
]=]
function Effects.Rage(duration: number, intensity: number)
    local Overlay = GetOverlay()
    local Effect = Correction()

    Envelope("Rage", duration, function(alpha)
        local Pulse = 0.65 + 0.35 * math.sin(os.clock() * 7)
        local Strength = alpha * Pulse * math.clamp(intensity, 0, 2)

        Effect.TintColor = Color3.fromRGB(255, 255 - 45 * Strength, 255 - 45 * Strength)
        Effect.Contrast = 0.15 * Strength

        if Overlay then
            Overlay.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
            Overlay.BackgroundTransparency = 1 - 0.22 * Strength
        end
    end, function()
        Effect:Destroy()
        if Overlay then
            Overlay.BackgroundTransparency = 1
        end
    end)
end

--------------------------------------------------------------------------------

return function()
    Network:SetConnection("AbilityScreenFX", "REMOTE_EVENT", function(kind: string, duration: number, intensity: number)
        if typeof(kind) ~= "string" then
            return
        end

        local Effect = Effects[kind]
        if not Effect then
            warn("[AbilityScreenFX] No screen effect called \""..kind.."\". Add it here, or fix the caller's spelling.")
            return
        end

        --[[
            CLAMPED, NOT TRUSTED.

            These numbers come off the network. A duration of a thousand seconds or an
            intensity of a hundred would be indistinguishable from a permanent blind, so
            the ceiling is enforced here rather than in each caller — a caller that gets it
            wrong should produce a short weak effect, not an unplayable one.
        ]]
        Effect(
            math.clamp(tonumber(duration) or 1, 0.05, 20),
            math.clamp(tonumber(intensity) or 1, 0, 2)
        )
    end)

    --[=[
        Clear everything on respawn.

        Dying mid-effect used to be impossible to recover from cleanly in any system that
        tweened a `Lighting` property, because the thing that was going to undo it was tied
        to the body that just stopped existing. Wiping the folder on every spawn means the
        worst case is one frame of a leftover tint.
    ]=]
    Utils.Character.ObserveCharacter(LocalPlayer, function()
        for Kind, State in Active do
            State.Cancelled = true
            Active[Kind] = nil
        end

        if Holder then
            Holder:ClearAllChildren()
        end

        local Overlay = GetOverlay()
        if Overlay then
            Overlay.BackgroundTransparency = 1
        end
    end)
end
