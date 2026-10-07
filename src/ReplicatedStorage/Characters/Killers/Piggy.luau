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
local DeployableService = require(ReplicatedStorage.Modules.DeployableService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    PIGGY — ROUTES AND TRAPS. NOTHING CLEVER.

      M1  BAT SWING   A bat. Simple, heavy, slow.
      Q   BEAR TRAP   A trap on the floor. Caught means held — briefly, and escapably.
      E   PATROL      Shows where everybody has recently BEEN. Not where they are.
      R   RAGE        A long speed boost. Longer every time somebody dies.
      P   RELENTLESS  No cleverness at all. She just keeps coming, and she heals on a kill.

    DELIBERATELY THE SIMPLEST KILLER HERE
    -------------------------------------
    Two stars of difficulty and no resources, no meters, no modes, no cycles. The brief asked
    for "simple, threatening, route-control focused" and resisting the urge to give her a
    gimmick is the design.

    THE TRAP HOLDS, AND IT LETS GO
    ------------------------------
    `Snared` at level 4 for two seconds. That is a near-total root — and `Snared` is
    specifically not a stun, so a caught player keeps every ability and their basic attack
    for the whole time. It also has a visible break: the trap's own health drops while
    somebody is struggling in it, and when it breaks they are free early.

    So being trapped by Piggy is dangerous, loud, and survivable, which is what makes it a
    chase tool rather than a kill.

    PATROL IS INFORMATION ABOUT THE PAST
    ------------------------------------
    Not a reveal. It marks the places people have recently walked, with the OLDEST marks
    faintest — so it tells you which way somebody went rather than where they are now. That
    is both more interesting and much weaker than an aura reveal, which suits a character
    whose whole job is working out which corridor you took.

    WEAKNESSES
    ----------
    No ranged attack, no mobility, no burst. Her damage is unremarkable and her trap is a
    visible object that can be destroyed from range. Everything she has is about chasing you
    down a corridor, and she has no answer at all to open ground.
]=]

local PIGGY = Color3.fromRGB(240, 150, 180)
local BLOOD = Color3.fromRGB(190, 40, 50)
local IRON = Color3.fromRGB(120, 120, 125)

--------------------------------------------------------------------------------
-- M1 — BAT SWING
--------------------------------------------------------------------------------

local function BatBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.3, Lock = 0.6, Shake = 0.5, ShakeTime = 0.2})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.7, MinPitch = 0.9, MaxPitch = 1.05})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A heavy horizontal arc.
        local Centre = Root.Position + Root.CFrame.LookVector * 3.5 + Vector3.new(0, 1, 0)
        AbilityFX.Beam(
            Centre - Root.CFrame.RightVector * 3.5,
            Centre + Root.CFrame.RightVector * 3.5,
            IRON,
            {Width = 0.9, Duration = 0.2, Transparency = 0.3, Material = Enum.Material.Metal}
        )

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Bat",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, BLOOD, 9, 15)
                        AbilityFX.ShakeFor(Victim, 2.5, 0.3)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — BEAR TRAP
--------------------------------------------------------------------------------

--[=[
    A bear trap.

    It is a `DeployableService` deployable with a trigger radius, which gets it the lifetime
    management, the per-player cap and the destructibility for free. The parts that are
    specific to it:

      * `TriggerOnce = false`, so the trap stays armed until something actually springs it
        AND it re-arms if the victim escapes — a trap you can tiptoe past once is not a trap.
      * The STRUGGLE. Once somebody is caught, the trap's own health drains, and when it hits
        zero they are released early. That gives a visible, readable escape rather than just
        waiting out a timer.
]=]
local function TrapBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.3, Lock = 0.4})
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

    AbilityFX.Sound(self.SetSound, Ground, {Volume = 0.65, MinPitch = 1.0, MaxPitch = 1.15})

    local Trap
    Trap = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Trap",
        Name = "BearTrap",
        CFrame = CFrame.new(Ground + Vector3.new(0, 0.3, 0)),
        Size = Vector3.new(4, 0.6, 4),
        Color = IRON,
        Material = Enum.Material.Metal,
        Solid = false,
        Health = self.TrapHealth,
        Lifetime = self.TrapLifetime,
        Limit = self.Limit,
        TriggerRadius = self.TriggerRadius,
        --- Re-arms. See the header.
        TriggerOnce = false,
        OutlineColor = IRON,
        OnTrigger = function(handle, victim: Model)
            -- Already holding somebody.
            if handle.State.Holding then
                return
            end

            local Humanoid = victim:FindFirstChildWhichIsA("Humanoid")
            local VictimRoot = Utils.Character.GetRootPart(victim)
            if not Humanoid or not VictimRoot then
                return
            end

            handle.State.Holding = victim

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.Damage,
                Reason = "Bear Trap",
            })

            -- Near-total root, and still not a stun: every ability and the basic attack
            -- stay available for the whole hold.
            CombatUtils.ApplyEffectTo(victim, "Snared", self.SnareLevel, self.HoldTime)

            AbilityFX.Sound(self.SnapSound, VictimRoot.Position, {Volume = 1, RollOffMaxDistance = 170})
            AbilityFX.Burst(VictimRoot.Position, 6, BLOOD, {Duration = 0.35})
            AbilityFX.Sparks(VictimRoot.Position, IRON, 14, 20)
            AbilityFX.ScreenFor(victim, "Rage", 1.2, 1)
            AbilityFX.Text(VictimRoot.Position + Vector3.new(0, 5.5, 0), "CAUGHT", BLOOD, 1.3)

            -- Piggy is told where it went off, which is the trap's real job.
            Utils.Player.RevealPlayerAuraTo(self.Owner, victim, self.RevealTime, BLOOD)

            --[=[
                THE STRUGGLE.

                The trap's own health drains while it holds somebody, and reaching zero
                frees them before the timer. It makes escape a visible process with a
                readable finish rather than an invisible countdown — and it means a trap
                that has already caught somebody is a trap on its way out.
            ]=]
            task.spawn(function()
                local Elapsed = 0

                while Elapsed < self.HoldTime and handle.Alive do
                    Elapsed += task.wait(0.2)

                    if not victim.Parent or Humanoid.Health <= 0 then
                        break
                    end

                    handle.Humanoid:TakeDamage(self.TrapHealth / (self.HoldTime / 0.2))

                    if handle.Humanoid.Health <= 0 then
                        -- Broken out of. Free early.
                        CommonFunctions.RemoveEffect(victim, "Snared")

                        local Live = Utils.Character.GetRootPart(victim)
                        if Live then
                            AbilityFX.Sparks(Live.Position, IRON, 16, 24)
                            AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "BROKE FREE", PIGGY, 1.2)
                        end
                        break
                    end
                end

                handle.State.Holding = nil
            end)
        end,
    })

    if Trap then
        AbilityFX.Ring(Ground, 5, IRON, {Duration = 0.3})

        -- Jaws, so it reads as a trap rather than a plate.
        for _, Side in {-1, 1} do
            local Jaw = AbilityFX.Part({
                Name = "Jaw",
                Size = Vector3.new(0.4, 1.8, 4),
                CFrame = Trap.Root.CFrame * CFrame.new(Side * 1.8, 0.8, 0) * CFrame.Angles(0, 0, math.rad(Side * 25)),
                Color = IRON,
                Material = Enum.Material.Metal,
            })
            Jaw.Parent = Trap.Model
        end
    end
end

--------------------------------------------------------------------------------
-- E — PATROL
--------------------------------------------------------------------------------

--[=[
    Shows where people have recently been.

    NOT A REVEAL. It drops markers at everybody's CURRENT positions and then keeps dropping
    them for a few seconds as they move, with each mark fading — so what Piggy gets is a set
    of trails, and reading them tells her which way somebody went.

    It is deliberately weaker than an aura. An aura says "he is there"; this says "he was
    there, and then there, so he is heading that way" — which is a chase tool rather than a
    targeting one, and it suits the one character on the roster whose entire job is working
    out which corridor you took.

    Everybody being tracked can SEE their own trail, so they know they are leaking position
    and can double back deliberately.
]=]
local function PatrolBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.94, Duration = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8, RollOffMaxDistance = 160})
    AbilityFX.Ring(Root.Position, self.Range, PIGGY, {Duration = 0.8, Thickness = 1, Transparency = 0.7})

    local Found = false

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(self.Interval)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.Range, Char) do
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not TargetRoot then
                    continue
                end

                Found = true

                local Ground = AbilityFX.GroundAt(TargetRoot.Position, {Target, Char}) or TargetRoot.Position

                -- A footprint. Fainter the older the trail gets, so the direction of travel
                -- is readable from the gradient.
                local Age = Elapsed / self.Duration_
                local Mark = AbilityFX.Part({
                    Name = "PatrolMark",
                    Size = Vector3.new(1.6, 0.15, 2.2),
                    CFrame = CFrame.lookAt(Ground + Vector3.new(0, 0.12, 0), Ground + TargetRoot.CFrame.LookVector),
                    Color = BLOOD,
                    Material = Enum.Material.Neon,
                    Transparency = 0.35 + Age * 0.45,
                })
                Mark.Parent = AbilityFX.Folder()
                game:GetService("Debris"):AddItem(Mark, self.MarkLifetime)
            end
        end

        if not Found then
            -- Nobody in range the whole time. Refund — it cost her a cooldown for no
            -- information at all.
            self.OnCooldown = false
            self.CooldownTimer = 0
        end
    end)
end

--------------------------------------------------------------------------------
-- R — RAGE
--------------------------------------------------------------------------------

--[=[
    A long speed boost that gets longer as the round empties.

    `Duration_` plus `BonusPerDeath` seconds for every fighter already out, capped. Early in
    a round it is a solid chase tool; in the last two minutes it is a very long one, which
    suits a killer with no mobility and no ranged attack.

    It is loud and it is visible — she glows red and screams — so it is a declared chase
    rather than a surprise.
]=]
local function RageBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.2, Duration = 0.6, Shake = 2, ShakeTime = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Fallen = Char:GetAttribute("PiggyFallen") or 0
    local Duration = self.Duration_ + math.min(Fallen * self.BonusPerDeath, self.MaximumBonus)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 220})
    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "RUN", BLOOD, 1.6)
    AbilityFX.Ring(Root.Position, 14, BLOOD, {Duration = 0.6, Thickness = 1.3})

    -- Everybody nearby is told. There is nothing subtle about this.
    AbilityFX.ScreenInRadius(Root.Position, self.WarnRadius, "Rage", 1.5, 1, Char)

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

    task.spawn(function()
        local Elapsed = 0
        while Elapsed < Duration and Char and Char.Parent do
            Elapsed += task.wait(0.3)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Tint(Char, BLOOD, 0.35, {FillTransparency = 0.78})
            end
        end
    end)

    -- Raw delay: the boost must come off even if she dies wearing it.
    task.delay(Duration, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — RELENTLESS
--------------------------------------------------------------------------------

--[=[
    She heals when somebody dies, and `Rage` lasts longer for each one.

    Watching `workspace.Players` for children leaving is the cheapest honest signal for "a
    fighter is out" and needs no hook into the round manager. It counts ANY death, not just
    hers — she is the character who benefits from the round grinding down, however it grinds.

    No cleverness anywhere. That is the point of her.
]=]
local function RelentlessInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    Char:SetAttribute("PiggyFallen", 0)

    self:AddConnection(workspace.Players.ChildRemoved:Connect(function(Removed: Instance)
        if Removed == Char or not Char.Parent then
            return
        end

        Char:SetAttribute("PiggyFallen", (Char:GetAttribute("PiggyFallen") or 0) + 1)

        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if Humanoid and Humanoid.Health > 0 then
            Humanoid.Health = math.min(Humanoid.Health + self.HealPerDeath, Humanoid.MaxHealth)
        end

        local Root = Utils.Character.GetRootPart(Char)
        if Root then
            AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "+"..tostring(self.HealPerDeath), PIGGY, 1.1)
            AbilityFX.Burst(Root.Position, 6, PIGGY, {Duration = 0.35})
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Piggy: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Piggy",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 9000,

        Role = "Trapper",
        Difficulty = 2,

        Origin = {
            TooltipText = "It started as a game.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Good health, average speed, unremarkable damage, and no mobility at all. She is
            the baseline the rest of the roster is measured against.
        ]]
        Health = 1400,
        BaseSpeed = 11,
        SprintSpeedMultiplier = 25.5 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 120,
            StaminaDrain = 10,
            StaminaGain = 21,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 30,
                Cooldown = 1.9,
                Duration = 0.32,
                Delay = 0.14,
                HitboxSize = Vector3.new(6, 6, 5.5),
                HitboxOffset = CFrame.new(0, 0, -2.8),
                Knockback = 7,

                Behaviour = BatBehaviour,
            }),

            Trap = Ability.New({
                Name = "Trap",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 14,
                Duration = 0.35,

                Damage = 25,
                HoldTime = 2,
                --- Near-total root. Still not a stun.
                SnareLevel = 4,
                TriggerRadius = 4,
                TrapHealth = 40,
                TrapLifetime = 50,
                RevealTime = 4,
                Limit = 3,

                SetSound = "rbxassetid://12222216",
                SnapSound = "rbxassetid://9046319808",
                Behaviour = TrapBehaviour,
            }),

            Patrol = Ability.New({
                Name = "Patrol",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 20,
                Duration = 0.5,

                Range = 100,
                Duration_ = 5,
                Interval = 0.6,
                MarkLifetime = 7,

                UseSound = "rbxassetid://9125402735",
                Behaviour = PatrolBehaviour,
            }),

            Rage = Ability.New({
                Name = "Rage",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 38,
                Duration = 0.6,

                Duration_ = 6,
                BonusPerDeath = 1.5,
                MaximumBonus = 7,
                SpeedMultiplier = 1.4,
                WarnRadius = 90,

                UseSound = "rbxassetid://9118823103",
                Behaviour = RageBehaviour,
            }),

            Relentless = Ability.New({
                Name = "Relentless",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                HealPerDeath = 150,

                ExtraInit = RelentlessInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(240, 150, 180)\">"..Piggy.Config.Name.."</font>"
local Abilities = Piggy.GameplayConfig.Abilities

Piggy.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Piggy.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." is the simplest killer here, on purpose. No meters, no modes, no cycles — a bat, a trap, and the willingness to keep walking after you.",
            "She has no ranged attack, no mobility and no burst. Everything she has is about chasing you down a corridor, and she has no answer at all to open ground.",
            "She gets stronger the emptier the round gets.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Piggy.Config.Role,
            "Difficulty: "..string.rep("★", Piggy.Config.Difficulty)..string.rep("☆", 5 - Piggy.Config.Difficulty),
            "Price: "..tostring(Piggy.Config.Price).."$",
            "Health: "..tostring(Piggy.GameplayConfig.Health),
            "Base Speed: "..tostring(Piggy.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Piggy.GameplayConfig.BaseSpeed * Piggy.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "BAT SWING"},
    {
        Type = "Text",
        Text = tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, with solid knockback. There is nothing else to it.",
    },

    {Type = "Header", Text = "TRAP  (Q)"},
    {
        Type = "Text",
        Text = {
            "A bear trap. Stepping within "..tostring(Abilities.Trap.TriggerRadius).." studs costs "..tostring(Abilities.Trap.Damage).." damage and a "..tostring(Abilities.Trap.HoldTime).." second near-total <b>Snare</b>, and tells Piggy exactly where you are.",
            "<b>Snared is not a stun</b> — you keep every ability and your basic attack the whole time.",
            "<b>You can break out early.</b> The trap's own health drains while it holds you, and when it breaks you are free.",
            tostring(Abilities.Trap.Limit).." at a time, and they re-arm. They are visible objects and can be destroyed from range.",
            "Cooldown: "..tostring(Abilities.Trap.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "PATROL  (E)"},
    {
        Type = "Text",
        Text = {
            "For "..tostring(Abilities.Patrol.Duration_).." seconds it marks the ground where everybody within "..tostring(Abilities.Patrol.Range).." studs walks, with older marks fainter.",
            "<b>It is not a reveal.</b> It tells her which way you WENT, not where you are — and you can see your own trail, so doubling back deliberately works.",
            "Refunds itself if nobody was in range.",
            "Cooldown: "..tostring(Abilities.Patrol.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "RAGE  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Rage.Duration_).." seconds at 40% more speed, plus "..tostring(Abilities.Rage.BonusPerDeath).." seconds for every fighter already out — up to "..tostring(Abilities.Rage.Duration_ + Abilities.Rage.MaximumBonus).." seconds late in a round.",
            "She glows and screams, and everybody within "..tostring(Abilities.Rage.WarnRadius).." studs sees red. It is a declared chase.",
            "Cooldown: "..tostring(Abilities.Rage.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "RELENTLESS  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "She heals <b>"..tostring(Abilities.Relentless.HealPerDeath).."</b> whenever anybody in the round dies — whoever killed them — and Rage lasts longer for each one.",
            "No cleverness. She just keeps coming.",
        },
    },
}

return Piggy
