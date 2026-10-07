local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    BACON HAIR — THE JOKE IS THAT HE IS GOOD.

    He has no magic, no corruption, no summons and no gimmick. He has a classic sword, three
    pieces of starter gear out of a 2010 catalogue, and fundamentals.

      M1  CLASSIC SWORD     A linked sword. Lunges on the swing, like the real one.
      Q   OOF RUSH          Two and a half seconds of actual speed, announced by that noise.
      E   STARTER GEAR      Fires the gear in his hand, then swaps to the next one.
                            Slingshot, then Superball, then a thrown sword. Round and round.
      R   BEGINNER'S LUCK   Eight seconds where everything comes back faster.
      P   UNDERESTIMATED    A swing that MISSES refunds most of its cooldown.

    THE PASSIVE IS THE WHOLE CHARACTER
    ----------------------------------
    `Underestimated` means whiffing barely punishes him. Everyone else on the roster pays a
    real price for a missed basic attack; he pays 40% of one. That makes him the only killer
    who can throw out speculative swings and keep pressure through them, which is precisely
    the thing a beginner does by accident and a good player does on purpose.

    The rest of his kit is deliberately plain. No telegraph to read, no resource to track, no
    state to manage — the lowest difficulty rating on the roster. He is what a new player can
    pick up and what an experienced player can still win with.

    WHAT HE IS NOT
    --------------
    A hacker. 1x1x1x1 is the corrupted-Roblox character and Guest is the nostalgia one;
    Bacon Hair is the DEFAULT one, and giving him glitch powers would have made three
    characters out of one idea.
]=]

local BACON = Color3.fromRGB(226, 155, 64)
local STEEL = Color3.fromRGB(190, 195, 205)

--------------------------------------------------------------------------------
-- STARTER GEAR
--------------------------------------------------------------------------------

--[=[
    The three pieces of gear, in rotation.

    A table rather than three abilities, because the brief asked for ONE slot that cycles —
    and because three separate ranged abilities on Q, E and R would have left no room for
    anything else and made him a turret.

    They are balanced against each other rather than all being "good": the slingshot is fast
    and weak, the superball is awkward and rewards geometry, the thrown sword is the real
    damage and the slowest. Which one is in his hand is public — it floats over his head on
    every swap — so opponents can play around the cycle.
]=]
local GEAR = {
    {
        Name = "Slingshot",
        Damage = 18,
        Speed = 140,
        Range = 110,
        Radius = 1.6,
        Bounces = 0,
        Gravity = 0,
        Colour = Color3.fromRGB(120, 85, 50),
        Size = Vector3.new(1, 1, 1),
        Shape = Enum.PartType.Ball,
        Sound = "rbxassetid://12222030",
    },
    {
        Name = "Superball",
        Damage = 24,
        Speed = 95,
        Range = 160,
        Radius = 2,
        --- The point of it: it comes back off walls, so it threatens around corners.
        Bounces = 4,
        Gravity = 45,
        Restitution = 0.85,
        Colour = Color3.fromRGB(255, 60, 60),
        Size = Vector3.new(1.8, 1.8, 1.8),
        Shape = Enum.PartType.Ball,
        Sound = "rbxassetid://12222216",
    },
    {
        Name = "Sword Throw",
        Damage = 34,
        Speed = 110,
        Range = 90,
        Radius = 2.4,
        Bounces = 0,
        Gravity = 15,
        --- Goes through the first person it hits. His only piercing attack.
        Pierce = 2,
        Colour = STEEL,
        Size = Vector3.new(0.6, 0.6, 5),
        Shape = Enum.PartType.Block,
        FaceTravel = true,
        Sound = "rbxassetid://12222200",
    },
}

--- Which gear is in his hand. Stored on the per-player module copy, not on the ability.
local function GearState(self: Types.Ability)
    local Cache = self.CharModule.GameplayConfig.Cache
    Cache.BaconGear = Cache.BaconGear or 1
    return Cache
end

--------------------------------------------------------------------------------
-- M1 — CLASSIC SWORD
--------------------------------------------------------------------------------

--[=[
    The linked sword, lunge included.

    The lunge is what makes it feel like the real thing rather than a generic swing: the
    swing carries him forward a few studs, which both closes distance and commits him to the
    direction he swung in. That commitment is the counterplay — a Bacon Hair who swings is a
    Bacon Hair who is briefly going one way.

    It also implements `Underestimated`. The hitbox hands back a details table whose
    `HumanoidsHit` list is empty if nothing connected, so the `Ended` callback can tell a
    whiff from a hit and refund the cooldown.
]=]
local function SwordBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.06, Duration = 0.25, Lock = 0.55})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.6, MinPitch = 0.95, MaxPitch = 1.08})

    -- The lunge. Short and shallow — it is flavour and a small gap-closer, not a dash.
    CombatUtils.Dash(Char, self.LungeSpeed, self.LungeTime, false)

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        local Details = Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Classic Sword",
            ExecuteOnKill = true,
            Knockback = 2,
            Connections = {
                Ended = function()
                    --[[
                        UNDERESTIMATED.

                        Nothing hit, so most of the cooldown comes back. Clearing
                        `OnCooldown` and `CooldownTimer` IS the refund — those are the two
                        flags `Ability:SetOnCooldown` sets and `Ability:CanUse` reads; there
                        is no separate API for shortening a cooldown.

                        Done on the SERVER, which is the side that actually gates the remote.
                        The client keeps its own copy of the cooldown for UI purposes and
                        will run slightly behind, which is the correct direction for the
                        error to go: the server is never the one saying no to a legal swing.
                    ]]
                    if #Details.HumanoidsHit <= 0 then
                        self.OnCooldown = false
                        self.CooldownTimer = 0

                        if Root and Root.Parent then
                            AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "whiff", BACON, 0.7)
                        end
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — OOF RUSH
--------------------------------------------------------------------------------

local function OofBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.18, Duration = self.Boost})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 120})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "OOF", BACON, 1.1)
    AbilityFX.Ring(Root.Position, 7, BACON, {Duration = 0.4})

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

    --[[
        A raw `task.delay`, NOT `self:AddConnection`.

        `AddConnection` hands the thread to the ability's Janitor, which cancels it when the
        character is destroyed — so dying mid-boost would leave a speed factor attached to a
        player whose body is gone, and the next body would inherit it. Cleanup that MUST
        happen has to outlive its caller.
    ]]
    task.delay(self.Boost, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)

    -- A dust trail for the duration, so the boost is visible to the people being chased.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Boost and Char and Char.Parent and Root and Root.Parent do
            Elapsed += task.wait(0.12)
            AbilityFX.Smoke(Root.Position - Vector3.new(0, 2.4, 0), BACON, 3, 2)
        end
    end)
end

--------------------------------------------------------------------------------
-- E — STARTER GEAR
--------------------------------------------------------------------------------

local function GearBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.96, Duration = 0.3, Lock = 0.4})
        return
    end

    local Cache = GearState(self)
    local Current = GEAR[Cache.BaconGear]
    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(Current.Sound, Root.Position, {Volume = 0.7})

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = Current.Name,
        Origin = Root.Position + Root.CFrame.LookVector * 2.5 + Vector3.new(0, 1.2, 0),
        Direction = Root.CFrame.LookVector,
        Speed = Current.Speed,
        Gravity = Current.Gravity,
        Lifetime = Current.Range / Current.Speed + (Current.Bounces > 0 and 1.5 or 0),
        Radius = Current.Radius,
        Damage = Current.Damage,
        Reason = Current.Name,
        Pierce = Current.Pierce or 1,
        Bounces = Current.Bounces,
        Restitution = Current.Restitution,
        FaceTravel = Current.FaceTravel,
        Spin = Current.FaceTravel and 0 or 180,
        Visual = {
            Shape = Current.Shape,
            Size = Current.Size,
            Color = Current.Colour,
            Material = Current.Name == "Sword Throw" and Enum.Material.Metal or Enum.Material.SmoothPlastic,
            Trail = true,
            TrailColor = Current.Colour,
        },
        OnBounce = function(_projectile, position: Vector3)
            AbilityFX.Sparks(position, Current.Colour, 6, 14)
            AbilityFX.Sound("rbxassetid://12222216", position, {Volume = 0.4, MinPitch = 1.1, MaxPitch = 1.4})
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Sparks(position, Current.Colour, 8, 16)
        end,
    })

    ----------------------------------------------------------------------------
    -- SWAP
    ----------------------------------------------------------------------------

    Cache.BaconGear = (Cache.BaconGear % #GEAR) + 1
    local Next = GEAR[Cache.BaconGear]

    -- Public, deliberately. Everybody nearby gets to see which gear is coming next, which
    -- is what makes the cycle something an opponent can play around.
    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), Next.Name, Next.Colour, 1)

    -- Replicated so the owner's own UI could show it, and so it is inspectable in Studio.
    if Char then
        Char:SetAttribute("StarterGear", Next.Name)
    end
end

--------------------------------------------------------------------------------
-- R — BEGINNER'S LUCK
--------------------------------------------------------------------------------

--[=[
    Everything comes back faster for eight seconds.

    Implemented with the engine's own `CooldownMultiplier` character attribute, which
    `Ability:SetOnCooldown` already reads and scales every cooldown by — the same hook the
    kill-escalation FRENZY perk uses. So this needed no new machinery at all, and it
    correctly stacks multiplicatively with FRENZY rather than one overwriting the other.

    Note it only affects cooldowns SET during the window, not ones already running. That is
    the engine's behaviour and it is the right one: an ability that retroactively shortened
    running cooldowns would be a reset button, which is a much stronger effect than this.
]=]
local function LuckBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9})
    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "LUCKY!", Color3.fromRGB(255, 225, 80), 1.4)
    AbilityFX.Ring(Root.Position, 10, Color3.fromRGB(255, 225, 80), {Duration = 0.6})

    local Previous = Char:GetAttribute("CooldownMultiplier") or 1
    Char:SetAttribute("CooldownMultiplier", Previous * self.Multiplier)

    -- A trail of coins-ish sparkle, so the buff is legible on him.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Boost and Char and Char.Parent and Root and Root.Parent do
            Elapsed += task.wait(0.35)
            AbilityFX.Sparks(Root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 225, 80), 5, 8)
        end
    end)

    -- Raw delay again: the multiplier must come off even if he dies wearing it, because the
    -- attribute would otherwise be inherited by whatever body replaces this one.
    task.delay(self.Boost, function()
        if Char then
            Char:SetAttribute("CooldownMultiplier", Previous)
        end
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local BaconHair: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Bacon Hair",
        Quote = "hi can i have robux",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 2600,

        Role = "Hybrid",
        Difficulty = 1,

        Origin = {
            TooltipText = "Signed up yesterday. Has been here for years.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Light, quick steps. He is wearing nothing heavier than a t-shirt.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Dead centre of the roster on every stat, which is the character: no numerical
            advantage anywhere, and a passive that forgives mistakes.
        ]]
        Health = 1250,
        BaseSpeed = 11.2,
        SprintSpeedMultiplier = 26 / 11.2,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 110,
            StaminaDrain = 10,
            StaminaGain = 22,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222200",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 24,
                Cooldown = 1.7,
                Duration = 0.32,
                Delay = 0.1,
                HitboxSize = Vector3.new(5, 6, 6),
                HitboxOffset = CFrame.new(0, 0, -3),

                --- The lunge. Deliberately modest: 26 studs/second for a fifth of a second.
                LungeSpeed = 26,
                LungeTime = 0.2,

                Behaviour = SwordBehaviour,
            }),

            Oof = Ability.New({
                Name = "Oof",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 13,
                Duration = 0.3,

                Boost = 2.5,
                SpeedMultiplier = 1.45,

                UseSound = "rbxassetid://5153734423",
                Behaviour = OofBehaviour,
            }),

            Gear = Ability.New({
                Name = "Gear",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                --[[
                    Short, because it is three weak attacks rather than one strong one, and
                    because cycling the gear is only an interesting decision if you get to
                    make it often.
                ]]
                Cooldown = 4.5,
                Duration = 0.35,

                Behaviour = GearBehaviour,
            }),

            Luck = Ability.New({
                Name = "Luck",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 45,
                Duration = 0.4,

                Boost = 8,
                --- 0.55 means cooldowns run 45% faster while it is up.
                Multiplier = 0.55,

                UseSound = "rbxassetid://9125402735",
                Behaviour = LuckBehaviour,
            }),

            Underestimated = Ability.New({
                Name = "Underestimated",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(226, 155, 64)\">"..BaconHair.Config.Name.."</font>"
local Abilities = BaconHair.GameplayConfig.Abilities

BaconHair.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = BaconHair.Config.Name:upper()},
    {Type = "Quote", Text = "\""..BaconHair.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has no powers. He has a sword, three bits of starter gear and no bad habits.",
            "Nothing in his kit needs managing — no resource, no stacks, no telegraph to time. He is the easiest character in the arena to pick up, and the one most likely to be underestimated by whoever he is fighting.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..BaconHair.Config.Role,
            "Difficulty: "..string.rep("★", BaconHair.Config.Difficulty)..string.rep("☆", 5 - BaconHair.Config.Difficulty),
            "Price: "..tostring(BaconHair.Config.Price).."$",
            "Health: "..tostring(BaconHair.GameplayConfig.Health),
            "Base Speed: "..tostring(BaconHair.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(BaconHair.GameplayConfig.BaseSpeed * BaconHair.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "CLASSIC SWORD"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, and the swing lunges him forward.",
            "The lunge closes a small gap, and commits him to the direction he swung in.",
        },
    },

    {Type = "Header", Text = "OOF  (Q)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Oof.Boost).." seconds at "..tostring(math.round((Abilities.Oof.SpeedMultiplier - 1) * 100)).."% extra speed.",
            "Everyone in the arena hears it. That is the trade.",
            "Cooldown: "..tostring(Abilities.Oof.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GEAR  (E)"},
    {
        Type = "Text",
        Text = {
            "Fires whatever is in his hand, then swaps to the next thing. The cycle is <b>Slingshot</b> → <b>Superball</b> → <b>Sword Throw</b>.",
            "Slingshot: "..tostring(GEAR[1].Damage).." damage, very fast, very light.",
            "Superball: "..tostring(GEAR[2].Damage).." damage and it bounces off walls four times, so it threatens around corners.",
            "Sword Throw: "..tostring(GEAR[3].Damage).." damage and goes through the first person it hits.",
            "What he's holding next floats over his head, so you always know what's coming.",
            "Cooldown: "..tostring(Abilities.Gear.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "LUCK  (R)"},
    {
        Type = "Text",
        Text = {
            "For "..tostring(Abilities.Luck.Boost).." seconds, every cooldown he sets runs 45% faster.",
            "Cooldowns already counting down are unaffected — it rewards using it before a fight rather than as a reset button in the middle of one.",
            "Cooldown: "..tostring(Abilities.Luck.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "UNDERESTIMATED  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "A basic attack that <b>misses</b> refunds its cooldown almost entirely.",
            "Everyone else pays for a whiff. He barely does, which is what lets him keep swinging through a chase where anyone else would have to wait.",
        },
    },
}

return BaconHair
