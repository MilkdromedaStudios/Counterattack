--[=[
    ABILITY CLIENT

    The client half of an ability: what the CASTER feels when they press the button.

    Every killer's `Behaviour` runs on both sides. The server half does the damage; the
    client half is lens punch, camera shake, and locking the head so the character looks
    where the animation points instead of where the mouse is. That half was previously
    copy-pasted into every single ability in the game, identically:

        if not RunService:IsServer() then
            self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.1)
            self:AddConnection(task.delay(0.4, function()
                self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
            end))
            return
        end

    Nine lines, thirty-odd characters, the same 1.1 and the same 0.4 — which is why pressing
    Q felt the same whoever you were playing. Collapsing it to one call is worth doing for
    the duplication alone; the real win is that a Gaster Blaster and a banana peel can now
    cheaply have DIFFERENT feel, because specifying it is one argument instead of a block.

    Everything here no-ops on the server, so an ability can call it unconditionally.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(ReplicatedStorage.Modules.Utils)

local AbilityClient = {}

--[=[
    A lens punch on the caster.

    `scale` above 1 widens the view (speed, power, rushing forward); below 1 narrows it
    (focus, aiming, winding up). That distinction is most of what makes abilities feel
    different from the inside, so it is worth picking deliberately per ability rather than
    taking the old universal 1.1.
]=]
function AbilityClient.Punch(self, scale: number?, duration: number?)
    if RunService:IsServer() then
        return
    end

    local FOVManager = self.OwnerProperties and self.OwnerProperties.FOVManager
    if not FOVManager then
        return
    end

    FOVManager:AddFOVFactor(self.Name, scale or 1.1)

    self:AddConnection(task.delay(duration or 0.4, function()
        FOVManager:RemoveFOVFactor(self.Name)
    end))
end

--[=[
    A sustained zoom with no automatic end.

    For states rather than casts: the Mini-Gunner spinning up, Superman flying, Cuphead
    holding a parry. Pair with `AbilityClient.ReleaseZoom`.
]=]
function AbilityClient.Zoom(self, scale: number)
    if RunService:IsServer() then
        return
    end

    local FOVManager = self.OwnerProperties and self.OwnerProperties.FOVManager
    if FOVManager then
        FOVManager:AddFOVFactor(self.Name, scale)
    end
end

--- Ends an `AbilityClient.Zoom`.
function AbilityClient.ReleaseZoom(self)
    if RunService:IsServer() then
        return
    end

    local FOVManager = self.OwnerProperties and self.OwnerProperties.FOVManager
    if FOVManager then
        FOVManager:RemoveFOVFactor(self.Name)
    end
end

--- Camera shake on the caster. Impacts, slams, explosions, heavy footfalls.
function AbilityClient.Shake(magnitude: number, duration: number)
    if RunService:IsServer() then
        return
    end

    Utils.Player.ShakeCamera(magnitude, duration)
end

--[=[
    Stops the head tracking the mouse for a moment.

    Anything with a real animation wants this — a wind-up reads as a wind-up only if the
    character is actually looking where it's swinging. `Slash` already does it; abilities
    never did, which is why a Gaster Blaster could be cast while staring at the floor.
]=]
function AbilityClient.LockHead(self, duration: number)
    if RunService:IsServer() then
        return
    end

    local Turn = self.OwnerProperties and self.OwnerProperties.TurnToMoveDirection
    if not Turn then
        return
    end

    Turn:AddHeadPreventionFactor(self.Name)

    self:AddConnection(task.delay(duration, function()
        Turn:RemoveHeadPreventionFactor(self.Name)
    end))
end

--[=[
    The common case: a punch and a head lock together.

    @param self     The ability.
    @param settings `Scale` and `Duration` for the punch, `Lock` for the head lock,
                    `Shake` and `ShakeTime` for the camera.
]=]
function AbilityClient.Cast(self, settings: {
    Scale: number?,
    Duration: number?,
    Lock: number?,
    Shake: number?,
    ShakeTime: number?,
}?)
    if RunService:IsServer() then
        return
    end

    settings = settings or {}

    AbilityClient.Punch(self, settings.Scale, settings.Duration)

    if settings.Lock then
        AbilityClient.LockHead(self, settings.Lock)
    end

    if settings.Shake then
        AbilityClient.Shake(settings.Shake, settings.ShakeTime or 0.3)
    end
end

return AbilityClient
