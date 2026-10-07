local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local DeployableService = require(ReplicatedStorage.Modules.DeployableService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    CREEPER — SILENCE, THEN A HISS, THEN NOTHING.

      M1  HEADBUTT          A shove. Almost no damage. It is not what he is for.
      Q   HISS & EXPLODE    Starts the fuse. Flashes, hisses, detonates. Then reassembles.
      E   GUNPOWDER         Drops a volatile pile that goes off if anyone walks near it.
      R   CHARGED           Twelve seconds electrified. The next detonation is much bigger.
      P   SILENT APPROACH   Completely silent footsteps until he attacks.

    THE DETONATION DOES NOT KILL HIM
    --------------------------------
    This was the one hard requirement, and the solution is a RECONSTRUCTION: the blast takes
    35% of his maximum health, then he spends three seconds pulled apart — invulnerable,
    rooted, visibly reassembling out of floating cubes — and comes back. The explosion goes
    on a 32 second cooldown.

    That is the real cost. Three seconds of being unable to move or act, in the middle of a
    free-for-all, immediately after announcing your position with an explosion. The
    invulnerability is not generosity: without it, detonating would be a guaranteed death
    because anybody nearby gets a free three seconds on a stationary target.

    THE WARNING IS ENORMOUS, AND DELIBERATELY SO
    -------------------------------------------
    1.7 seconds of fuse. In that time: a hiss audible for 150 studs, a body flashing white
    faster and faster, a filling telegraph circle on the ground showing the exact blast
    radius, and a growing white sphere. He can still walk during it, which is the threat —
    but you have well over a second and an exact map of where not to be.

    WHY THE BASIC ATTACK IS TERRIBLE
    -------------------------------
    13 damage. He is not a fighter; he is a delivery mechanism for one enormous hit. If his
    headbutt were competitive he would simply be a better brawler who also explodes.
]=]

local CREEPER = Color3.fromRGB(70, 190, 100)
local CHARGED = Color3.fromRGB(120, 220, 255)
local GUNPOWDER = Color3.fromRGB(80, 80, 85)

--- Attribute holding whether the next blast is empowered, so the client can read it too.
local CHARGED_ATTRIBUTE = "CreeperCharged"

--------------------------------------------------------------------------------
-- M1 — HEADBUTT
--------------------------------------------------------------------------------

local function HeadbuttBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.2, Lock = 0.35})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.55, MinPitch = 1.0, MaxPitch = 1.2})

    -- Attacking breaks the silence. See the passive.
    if Char then
        Char:SetAttribute("FootstepVolume", nil)
        Char:SetAttribute("CreeperLastAttack", os.clock())
    end

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Headbutt",
            ExecuteOnKill = true,
            Knockback = 4,
        })
    end)
end

--------------------------------------------------------------------------------
-- SHARED — THE DETONATION
--------------------------------------------------------------------------------

--[=[
    The blast itself, and the reassembly afterwards.

    Shared by the fuse and by anything else that wants to set him off, so there is exactly
    one place that decides what a Creeper explosion does.

    Damage FALLS OFF with distance — full at the centre, a quarter at the edge. That is what
    makes positioning during the fuse matter: being at the edge of the circle is survivable,
    standing on him is not.
]=]
local function Detonate(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = Char and Utils.Character.GetRootPart(Char)
    if not Char or not Root then
        return
    end

    local Empowered = Char:GetAttribute(CHARGED_ATTRIBUTE) == true
    local Radius = Empowered and self.Radius * self.ChargedRadiusMultiplier or self.Radius
    local Damage = Empowered and self.Damage * self.ChargedDamageMultiplier or self.Damage
    local Colour = Empowered and CHARGED or CREEPER

    local Origin = Root.Position

    ----------------------------------------------------------------------------
    -- THE BANG
    ----------------------------------------------------------------------------

    AbilityFX.Sound(self.BlastSound, Origin, {Volume = 1, RollOffMinDistance = 25, RollOffMaxDistance = 260})
    AbilityFX.Burst(Origin, Radius, Colour, {Duration = 0.4, StartSize = 6})
    AbilityFX.Ring(Origin, Radius, Colour, {Duration = 0.6, Thickness = 1.6})
    AbilityFX.Sparks(Origin, Colour, 40, 70)
    AbilityFX.Smoke(Origin, Color3.fromRGB(70, 70, 70), 25, 8)
    AbilityFX.ShakeInRadius(Origin, Radius * 2, 5, 0.6)

    if Empowered then
        -- Arcs lashing out in every direction, so a charged blast is unmistakable.
        for _ = 1, 8 do
            local Angle = math.random() * math.pi * 2
            AbilityFX.Bolt(
                Origin,
                Origin + Vector3.new(math.cos(Angle) * Radius, math.random() * 8, math.sin(Angle) * Radius),
                CHARGED,
                {Segments = 6, Spread = 4, Width = 0.7, Duration = 0.3}
            )
        end
    end

    ----------------------------------------------------------------------------
    -- THE DAMAGE
    ----------------------------------------------------------------------------

    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, Radius, Char) do
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not Humanoid or not TargetRoot then
            continue
        end

        -- Full damage at the centre, a quarter at the rim.
        local Distance = (TargetRoot.Position - Origin).Magnitude
        local Falloff = 1 - 0.75 * math.clamp(Distance / Radius, 0, 1)

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = Damage * Falloff,
            Reason = Empowered and "Charged Creeper" or "Creeper",
            KnockbackDirection = (TargetRoot.Position - Origin).Magnitude > 0
                and (TargetRoot.Position - Origin).Unit
                or Vector3.yAxis,
            KnockbackMagnitude = self.Knockback * Falloff,
        })

        CombatUtils.ApplyEffectTo(Target, "Fragile", 3, 8)
        AbilityFX.ShakeFor(Target, 4 * Falloff, 0.5)

        if Empowered then
            CombatUtils.ApplyEffectTo(Target, "Electrified", 2, 1.5)
            AbilityFX.ScreenFor(Target, "Zap", 0.8, 1.2)
        end
    end

    ----------------------------------------------------------------------------
    -- CHAIN THE GUNPOWDER
    ----------------------------------------------------------------------------

    --[[
        His own gunpowder piles go off with him.

        This is the reason to place them: a blast plus three primed piles covers far more
        ground than the blast alone, and setting that up takes planning rather than a
        keypress.
    ]]
    for _, Pile in DeployableService.GetFor(self.Owner, "Gunpowder") do
        if Pile.Alive and Pile.Root and (Pile.Root.Position - Origin).Magnitude <= Radius * 1.6 then
            -- Deferred so the chain visibly ripples outward instead of all going at once.
            task.delay(0.1 + math.random() * 0.2, function()
                if Pile.Alive and Pile.Detonate then
                    Pile.Detonate()
                end
            end)
        end
    end

    ----------------------------------------------------------------------------
    -- THE COST
    ----------------------------------------------------------------------------

    local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
    if Humanoid then
        Humanoid:TakeDamage(Humanoid.MaxHealth * self.SelfDamage)
    end

    -- Spent. A charged blast is one blast.
    Char:SetAttribute(CHARGED_ATTRIBUTE, false)

    -- Dying to his own blast means no reassembly; he is simply dead.
    if not Humanoid or Humanoid.Health <= 0 then
        return
    end

    ----------------------------------------------------------------------------
    -- RECONSTRUCTION
    ----------------------------------------------------------------------------

    --[=[
        Three seconds in pieces.

        Invulnerable and rooted. The invulnerability is required rather than generous —
        a rooted player who has just announced their exact position with an explosion would
        otherwise be free damage for everyone nearby, which would make detonating strictly
        suicidal and the whole character pointless.

        Rooted with `Snared` at level 5 rather than by anchoring the part, so it shows in his
        effects list, other systems understand it, and nothing can leave his root anchored if
        this function is interrupted.
    ]=]
    Char:SetAttribute("Invincible", true)
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.ReformTime)
    -- Can't swing while scattered across the floor.
    Char:SetAttribute("PreventSlash", true)

    AbilityFX.Text(Origin + Vector3.new(0, 6, 0), "reassembling", CREEPER, self.ReformTime)

    -- Cubes of him, orbiting back in. Twelve parts for three seconds.
    local Pieces = {}
    for Index = 1, 12 do
        local Piece = AbilityFX.Part({
            Name = "CreeperPiece",
            Size = Vector3.one * (0.8 + math.random() * 0.7),
            CFrame = CFrame.new(Origin + Vector3.new(
                (math.random() - 0.5) * 14,
                math.random() * 8,
                (math.random() - 0.5) * 14
            )),
            Color = Index % 3 == 0 and Color3.fromRGB(40, 120, 60) or CREEPER,
            Material = Enum.Material.Grass,
            Transparency = 0.1,
        })
        Piece.Parent = AbilityFX.Folder()
        table.insert(Pieces, Piece)

        TweenService:Create(
            Piece,
            TweenInfo.new(self.ReformTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {CFrame = CFrame.new(Origin + Vector3.new(0, 2, 0)), Size = Vector3.one * 0.2}
        ):Play()
    end

    -- Raw delay: he must come back even if something else interrupts this thread's owner.
    task.delay(self.ReformTime, function()
        for _, Piece in Pieces do
            if Piece.Parent then
                Piece:Destroy()
            end
        end

        if not Char or not Char.Parent then
            return
        end

        Char:SetAttribute("Invincible", false)
        Char:SetAttribute("PreventSlash", nil)

        local Live = Utils.Character.GetRootPart(Char)
        if Live then
            AbilityFX.Burst(Live.Position, 8, CREEPER, {Duration = 0.4})
            AbilityFX.Sound(self.ReformSound, Live.Position, {Volume = 0.8, MinPitch = 0.7, MaxPitch = 0.85})
        end
    end)
end

--------------------------------------------------------------------------------
-- Q — HISS & EXPLODE
--------------------------------------------------------------------------------

local function HissBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- The view pulls IN during the fuse and snaps out on the bang. Winding up, then
        -- releasing — the opposite shape to every other ability's punch.
        AbilityClient.Zoom(self, 0.9)
        self:AddConnection(task.delay(self.Fuse, function()
            AbilityClient.ReleaseZoom(self)
            AbilityClient.Shake(6, 0.6)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    if not Char or not Root then
        return
    end

    local Empowered = Char:GetAttribute(CHARGED_ATTRIBUTE) == true
    local Radius = Empowered and self.Radius * self.ChargedRadiusMultiplier or self.Radius
    local Colour = Empowered and CHARGED or CREEPER

    -- Fusing announces him. No more silent footsteps.
    Char:SetAttribute("FootstepVolume", nil)
    Char:SetAttribute("CreeperLastAttack", os.clock())

    ----------------------------------------------------------------------------
    -- THE WARNING
    ----------------------------------------------------------------------------

    AbilityFX.Sound(self.UseSound, Root.Position, {
        Volume = 1,
        RollOffMinDistance = 30,
        RollOffMaxDistance = 150,
    })

    -- The exact blast radius, filling for exactly the fuse. This is the counterplay.
    local Marker = AbilityFX.Telegraph(Root.Position, Radius, Colour, self.Fuse)

    -- The growing sphere and the flashing body, both accelerating.
    task.spawn(function()
        local Elapsed = 0
        local Flash = 0

        while Elapsed < self.Fuse and Char and Char.Parent do
            local Step = task.wait(0.08)
            Elapsed += Step
            Flash += Step

            local Progress = Elapsed / self.Fuse

            -- Flashes faster as it gets closer: 0.3s apart at the start, 0.07s at the end.
            local Interval = 0.3 - 0.23 * Progress
            if Flash >= Interval then
                Flash = 0
                AbilityFX.Tint(Char, Color3.new(1, 1, 1), 0.06, {FillTransparency = 0.25})
            end

            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                -- The telegraph is on the ground where he STARTED; this follows him, so
                -- between them you can see both where he was aiming and where he is.
                AbilityFX.Burst(Live.Position, 3 + Progress * 6, Colour, {
                    Duration = 0.2,
                    StartSize = 2,
                    Transparency = 0.6,
                })
            end
        end
    end)

    ----------------------------------------------------------------------------
    -- THE BANG
    ----------------------------------------------------------------------------

    task.delay(self.Fuse, function()
        Marker:Destroy()

        if not Char or not Char.Parent then
            return
        end

        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then
            return
        end

        --[[
            A fuse that was interrupted does not go off.

            Being stunned mid-fuse cancels it — that is the one thing that beats this
            ability outright, and it is why stuns are worth holding for a hissing Creeper.
        ]]
        if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
            AbilityFX.Smoke(Utils.Character.GetRootPart(Char).Position, GUNPOWDER, 12, 4)
            AbilityFX.Text(Utils.Character.GetRootPart(Char).Position + Vector3.new(0, 5, 0), "fizzle", GUNPOWDER, 1)
            return
        end

        Detonate(self)
    end)
end

--------------------------------------------------------------------------------
-- E — GUNPOWDER
--------------------------------------------------------------------------------

--[=[
    A pile of gunpowder on the floor.

    Two ways it goes off: somebody walks within 8 studs of it, or the Creeper detonates
    nearby and chains it. It is the only part of his kit that rewards planning, and the only
    way he threatens an area he is not standing in.

    Visible — a dark mound with drifting black particles — and destructible like every other
    deployable. Walking carefully around it is free; the point is that it takes a route away.
]=]
local function GunpowderBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.25, Lock = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Ground = AbilityFX.GroundAt(Root.Position + Root.CFrame.LookVector * 4, {Char})
    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.5, MinPitch = 0.9, MaxPitch = 1.1})

    local Pile
    Pile = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Gunpowder",
        Name = "Gunpowder",
        CFrame = CFrame.new(Ground + Vector3.new(0, 0.4, 0)),
        Size = Vector3.new(4, 0.8, 4),
        Color = GUNPOWDER,
        Material = Enum.Material.Sand,
        Solid = false,
        Health = self.PileHealth,
        Lifetime = self.PileLifetime,
        Limit = self.Limit,
        TriggerRadius = self.TriggerRadius,
        TriggerOnce = true,
        OutlineColor = CREEPER,
        OnTrigger = function(handle)
            if handle.Detonate then
                handle.Detonate()
            end
        end,
        OnDestroyed = function(handle)
            -- Shot rather than stepped on: it still goes off. Gunpowder does that.
            if handle.Detonate then
                handle.Detonate()
            end
        end,
    })

    if not Pile then
        return
    end

    --[=[
        The pile's own detonation, hung on the handle.

        On the handle rather than captured in a local, so `Detonate` above can find it
        through `DeployableService.GetFor` and chain it — the chain has to work on piles
        placed by an earlier cast, which a closure in this call could not reach.

        Guarded against going off twice: triggering and being destroyed both route here, and
        a pile shot in the same frame somebody steps on it would otherwise double-damage.
    ]=]
    function Pile.Detonate()
        if Pile.State.Spent or not Pile.Root or not Pile.Root.Parent then
            return
        end
        Pile.State.Spent = true

        local Origin = Pile.Root.Position

        AbilityFX.Sound(self.BlastSound, Origin, {Volume = 0.85, RollOffMaxDistance = 160})
        AbilityFX.Burst(Origin, self.BlastRadius, CREEPER, {Duration = 0.35})
        AbilityFX.Ring(Origin, self.BlastRadius, CREEPER, {Duration = 0.5})
        AbilityFX.Sparks(Origin, CREEPER, 22, 45)
        AbilityFX.ShakeInRadius(Origin, self.BlastRadius * 2, 2.5, 0.4)

        for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.BlastRadius, nil) do
            local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
            local TargetRoot = Utils.Character.GetRootPart(Target)
            if not Humanoid or not TargetRoot then
                continue
            end

            --[[
                His own piles hurt HIM too.

                Not an oversight. The chain reaction is the strong play, and letting him
                stand in the middle of his own minefield with impunity would remove the only
                thing that makes placing them a decision.
            ]]
            local Distance = (TargetRoot.Position - Origin).Magnitude
            local Falloff = 1 - 0.6 * math.clamp(Distance / self.BlastRadius, 0, 1)

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.BlastDamage * Falloff,
                Reason = "Gunpowder",
                KnockbackDirection = Distance > 0 and (TargetRoot.Position - Origin).Unit or Vector3.yAxis,
                KnockbackMagnitude = 6 * Falloff,
            })

            CombatUtils.ApplyEffectTo(Target, "Fragile", 2, 5)
        end

        Pile:Destroy()
    end

    -- Drifting black grains, so it is visible but not loud.
    AbilityFX.Attach(Pile.Root, {
        Texture = AbilityFX.Textures.Smoke,
        Color = ColorSequence.new(GUNPOWDER),
        Rate = 6,
        Speed = NumberRange.new(0.5, 2),
        Size = NumberSequence.new(1.6),
        Lifetime = NumberRange.new(0.8, 1.4),
        LightEmission = 0,
    })
end

--------------------------------------------------------------------------------
-- R — CHARGED
--------------------------------------------------------------------------------

--[=[
    Struck by lightning, on purpose.

    Twelve seconds of being visibly electrified. The NEXT detonation — whether that is the
    fuse or a chained pile — is 40% wider and 50% harder.

    It is a long cooldown and a loud, obvious state: crackling blue arcs all over him, which
    everybody can see. That visibility is the balance. A charged Creeper walking towards you
    is the single clearest "leave now" signal in the game, and if the window expires without
    a blast it is simply wasted.
]=]
local function ChargedBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.12, Duration = 0.6, Shake = 2, ShakeTime = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    if not Char or not Root then
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 200})

    -- A bolt out of the sky.
    AbilityFX.Bolt(Root.Position + Vector3.new(0, 80, 0), Root.Position, CHARGED, {
        Segments = 10,
        Spread = 6,
        Width = 1.4,
        Duration = 0.4,
    })
    AbilityFX.Ring(Root.Position, 16, CHARGED, {Duration = 0.6, Thickness = 1.2})

    Char:SetAttribute(CHARGED_ATTRIBUTE, true)

    -- Arcs for the whole window, so the state is unmissable.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Window and Char and Char.Parent and Char:GetAttribute(CHARGED_ATTRIBUTE) do
            Elapsed += task.wait(0.25)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            AbilityFX.Tint(Char, CHARGED, 0.3, {FillTransparency = 0.7})
            AbilityFX.Bolt(
                Live.Position + Vector3.new(0, 3, 0),
                Live.Position + Vector3.new((math.random() - 0.5) * 8, math.random() * 4, (math.random() - 0.5) * 8),
                CHARGED,
                {Segments = 3, Spread = 1.5, Width = 0.3, Duration = 0.15}
            )
        end
    end)

    -- Raw delay: the charge must expire even if he dies holding it.
    task.delay(self.Window, function()
        if Char then
            Char:SetAttribute(CHARGED_ATTRIBUTE, false)
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — SILENT APPROACH
--------------------------------------------------------------------------------

--[=[
    No footsteps and no chase music until he attacks.

    Two mechanisms, both already in the engine and neither invented for him:

      * `FootstepVolume = 0` on his character. `FootstepPlayer` reads it and plays nothing.
        Set generically so anything can be quiet, rather than branching the footstep system
        on this one character.
      * The `Undetectable` effect, which `TerrorRadiusManager` already honours by suppressing
        his chase theme for everybody else.

    Both drop the moment he attacks or starts a fuse, and come back after three quiet
    seconds. So silence is a STATE HE CAN LEAVE, which is what keeps it from being a flat
    advantage — committing to an attack means being audible for the next few seconds.
]=]
local function SilentInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.5)

            local Last = Char:GetAttribute("CreeperLastAttack") or 0
            local Quiet = os.clock() - Last >= self.QuietAfter

            if Quiet then
                Char:SetAttribute("FootstepVolume", 0)

                -- Re-applied rather than applied once: the effect has a duration, and
                -- topping it up is how a continuous passive is expressed in this engine.
                if not Utils.Instance.FindFirstChild(Char, "Effects.Undetectable", 0) then
                    CombatUtils.ApplyEffectTo(Char, "Undetectable", 1, 4)
                end
            else
                Char:SetAttribute("FootstepVolume", nil)
                CommonFunctions.RemoveEffect(Char, "Undetectable")
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Creeper: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Creeper",
        Quote = "...",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 22000,

        Role = "Ambusher",
        Difficulty = 3,

        Origin = {
            TooltipText = "It was behind you the whole time.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Soft, and silenced entirely by the passive most of the time.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Fast and fragile. He has to get close, and he has to survive the three seconds
            after he gets there — being quick is how he does the first and being made of
            paper is why the second is in doubt.
        ]]
        Health = 1150,
        BaseSpeed = 11.4,
        SprintSpeedMultiplier = 26.5 / 11.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 11,
            StaminaGain = 21,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                --- The weakest basic attack in the game. He is not supposed to win with it.
                Damage = 13,
                Cooldown = 1.3,
                Duration = 0.25,
                Delay = 0.07,
                HitboxSize = Vector3.new(4.5, 5.5, 4),
                HitboxOffset = CFrame.new(0, 0, -2.2),

                Behaviour = HeadbuttBehaviour,
            }),

            Hiss = Ability.New({
                Name = "Hiss",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 32,
                --- The whole fuse, so nothing else is usable during it.
                Duration = 1.7,

                Fuse = 1.7,
                Radius = 26,
                Damage = 190,
                Knockback = 14,
                --- 35% of his own maximum health.
                SelfDamage = 0.35,
                ReformTime = 3,
                ChargedRadiusMultiplier = 1.4,
                ChargedDamageMultiplier = 1.5,

                UseSound = "rbxassetid://9125402735",
                BlastSound = "rbxassetid://9118823103",
                ReformSound = "rbxassetid://9046319808",

                Behaviour = HissBehaviour,
            }),

            Gunpowder = Ability.New({
                Name = "Gunpowder",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 9,
                Duration = 0.3,

                PileHealth = 25,
                PileLifetime = 30,
                TriggerRadius = 8,
                BlastRadius = 14,
                BlastDamage = 55,
                Limit = 3,

                UseSound = "rbxassetid://12222216",
                BlastSound = "rbxassetid://9046319808",

                Behaviour = GunpowderBehaviour,
            }),

            Charged = Ability.New({
                Name = "Charged",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 70,
                Duration = 0.6,

                Window = 12,

                UseSound = "rbxassetid://9118823103",
                Behaviour = ChargedBehaviour,
            }),

            SilentApproach = Ability.New({
                Name = "Silent Approach",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Seconds of not attacking before he goes quiet again.
                QuietAfter = 3,

                ExtraInit = SilentInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(70, 190, 100)\">"..Creeper.Config.Name.."</font>"
local Abilities = Creeper.GameplayConfig.Abilities

Creeper.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Creeper.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Creeper.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the weakest basic attack in the arena and the biggest single hit in the game.",
            "He walks in silence — no footsteps, no chase music — until he attacks. Then he lights a fuse you can hear from 150 studs away, and a circle appears on the floor showing you exactly where not to be.",
            "Surviving him is a matter of listening, then moving.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Creeper.Config.Role,
            "Difficulty: "..string.rep("★", Creeper.Config.Difficulty)..string.rep("☆", 5 - Creeper.Config.Difficulty),
            "Price: "..tostring(Creeper.Config.Price).."$",
            "Health: "..tostring(Creeper.GameplayConfig.Health),
            "Base Speed: "..tostring(Creeper.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Creeper.GameplayConfig.BaseSpeed * Creeper.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "HEADBUTT"},
    {
        Type = "Text",
        Text = {
            "A shove for "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds. The weakest attack in the game.",
            "It also breaks his silence for three seconds, so even using it costs him something.",
        },
    },

    {Type = "Header", Text = "HISS  (Q)"},
    {
        Type = "Text",
        Text = {
            "Lights the fuse. "..tostring(Abilities.Hiss.Fuse).." seconds of hissing and flashing, then "..tostring(Abilities.Hiss.Damage).." damage across "..tostring(Abilities.Hiss.Radius).." studs — falling off to a quarter of that at the edge.",
            "He can still walk during the fuse. A circle on the ground shows the exact radius, filling as the fuse burns.",
            "<b>It does not kill him.</b> It takes 35% of his health and leaves him in pieces for "..tostring(Abilities.Hiss.ReformTime).." seconds — invulnerable, rooted, unable to attack — before he reassembles.",
            "A <b>stun</b> during the fuse cancels it outright.",
            "Cooldown: "..tostring(Abilities.Hiss.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GUNPOWDER  (E)"},
    {
        Type = "Text",
        Text = {
            "Drops a pile that goes off for "..tostring(Abilities.Gunpowder.BlastDamage).." damage across "..tostring(Abilities.Gunpowder.BlastRadius).." studs if anybody comes within "..tostring(Abilities.Gunpowder.TriggerRadius).." of it. Three at a time.",
            "His own detonation chains every pile near it — which is the strong play, and also why the piles hurt him too.",
            "Cooldown: "..tostring(Abilities.Gunpowder.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "CHARGED  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Charged.Window).." seconds electrified. The next detonation is 40% wider and 50% harder, and leaves everyone it touches <b>Electrified</b>.",
            "He crackles with blue arcs the entire time. Everybody can see it coming.",
            "Cooldown: "..tostring(Abilities.Charged.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SILENT APPROACH  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Completely silent footsteps, and no chase music, while he has not attacked for "..tostring(Abilities.SilentApproach.QuietAfter).." seconds.",
            "Attacking or lighting a fuse breaks it. He goes quiet again three seconds later.",
        },
    },
}

return Creeper
