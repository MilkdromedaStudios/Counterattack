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
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    KIRBY — HE EATS THINGS AND THEN HE IS THAT THING.

      M1  STAR STRIKE  A hammer. Small radius, decent damage, a star on impact.
      Q   INHALE       A cone that drags people in and SWALLOWS projectiles and small objects.
      E   COPY         Uses whatever he swallowed. One of three powers, never more.
      R   WARP STAR    Rides a star. The longest single reposition in the game.
      P   FLOAT        Falls slowly and can stay in the air.

    HOW COPY IS IMPLEMENTED, AND WHY IT IS NOT ARBITRARY
    ----------------------------------------------------
    The brief was explicit: keep it to supported CATEGORIES and do NOT dynamically execute
    other characters' ability code. Running another killer's `Behaviour` with Kirby as the
    owner would be a security and stability problem — those functions assume their own
    character's abilities, attributes and cached state exist.

    So `Inhale` classifies what it swallowed into one of exactly three powers, and `Copy`
    implements all three itself:

      PROJECTILE  He swallowed somebody's shot        -> he spits a star back.
      GUARD       He swallowed a structure or trap    -> a few seconds of heavy resistance.
      DASH        He swallowed nothing but a fighter  -> a short burst of speed.

    Three fixed powers, written here, with no code path that runs anything from elsewhere.

    SWALLOWING IS THE SKILL
    -----------------------
    `Copy` does nothing at all with an empty mouth, and `Inhale` only fills it if there was
    something in the cone. The payoff is reading what is coming — eating a Gaster Blaster's
    beam, a sentry round or Steve's arrow is a real moment, and it is the only way he gets
    his own ranged attack.
]=]

local KIRBY = Color3.fromRGB(255, 150, 190)
local STAR = Color3.fromRGB(255, 235, 110)

--- What he currently has in his mouth. Replicated so the owner's UI could show it.
local POWER_ATTRIBUTE = "KirbyPower"

--------------------------------------------------------------------------------
-- M1 — STAR STRIKE
--------------------------------------------------------------------------------

local function StarStrikeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.25, Lock = 0.5, Shake = 0.4, ShakeTime = 0.2})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.65, MinPitch = 1.0, MaxPitch = 1.15})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Star Strike",
            ExecuteOnKill = true,
            Knockback = 5,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if not VictimRoot then
                        return
                    end

                    -- A five-pointed star of short beams. Cheap, and unmistakably his.
                    for Index = 0, 4 do
                        local Angle = (Index / 5) * math.pi * 2
                        AbilityFX.Beam(
                            VictimRoot.Position,
                            VictimRoot.Position + Vector3.new(math.cos(Angle) * 4, math.sin(Angle) * 4, 0),
                            STAR,
                            {Width = 0.5, Duration = 0.22, Transparency = 0.1}
                        )
                    end

                    AbilityFX.Sparks(VictimRoot.Position, STAR, 10, 18)
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — INHALE
--------------------------------------------------------------------------------

--[=[
    A cone that pulls, and swallows.

    IT DOES NOT SWALLOW PLAYERS. The brief was explicit and it is the right call — removing
    somebody from the game for a few seconds is a stun with a costume on. Fighters in the cone
    are dragged a short distance toward him and that is all.

    What it DOES swallow, in priority order:
      1. A PROJECTILE in flight. The best outcome, and the hardest to get.
      2. A small DEPLOYABLE — a trap, a sentry, a block. Destroys it outright.
      3. Nothing but a fighter, which gives him the weakest power.

    The priority order is the skill expression: all three are the same keypress, and which
    one you get depends entirely on what you chose to point it at.
]=]
local function InhaleBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Pulls IN, so the view narrows while it runs.
        AbilityClient.Zoom(self, 0.88)
        self:AddConnection(task.delay(self.Duration, function()
            AbilityClient.ReleaseZoom(self)
        end))
        AbilityClient.LockHead(self, self.Duration)
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1, 0)
    local Direction = Root.CFrame.LookVector

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.85})
    AbilityFX.Cone(Origin, Direction, self.Range, self.Angle, KIRBY, {Rays = 9, Duration = self.Duration, Width = 0.7})

    local Power = nil

    ----------------------------------------------------------------------------
    -- 1. PROJECTILES
    ----------------------------------------------------------------------------

    local Centre = Origin + Direction * (self.Range * 0.5)
    if ProjectileService.Consume(Centre, self.Range * 0.55, self.Owner) > 0 then
        Power = "Projectile"
        AbilityFX.Burst(Centre, 6, STAR, {Duration = 0.3})
        AbilityFX.Sound(self.SwallowSound, Origin, {Volume = 0.9, MinPitch = 1.2, MaxPitch = 1.35})
    end

    ----------------------------------------------------------------------------
    -- 2. DEPLOYABLES
    ----------------------------------------------------------------------------

    if not Power then
        for _, Handle in DeployableService.GetInRadius(Centre, self.Range * 0.55, self.Owner) do
            -- Not solid walls: he is a small round thing and a brick wall is not food.
            -- Traps, sentries, markers and blocks are.
            if Handle.Root and Handle.Root.Size.Magnitude <= self.MaximumMouthful then
                Power = "Guard"
                AbilityFX.Burst(Handle.Root.Position, 6, KIRBY, {Duration = 0.3})
                AbilityFX.Sound(self.SwallowSound, Origin, {Volume = 0.9, MinPitch = 0.85, MaxPitch = 1})
                Handle:Destroy()
                break
            end
        end
    end

    ----------------------------------------------------------------------------
    -- 3. FIGHTERS
    ----------------------------------------------------------------------------

    local Pulled = 0

    for _, Target: Model in AbilityFX.ConeTargets(Origin, Direction, self.Range, self.Angle, Char) do
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not Humanoid or not TargetRoot then
            continue
        end

        Pulled += 1

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = self.Damage,
            Reason = self.Name,
        })

        --[[
            A SHORT drag, never a capture.

            `PullDistance` studs, clamped so it never pulls past him — a pull that ends with
            the victim inside Kirby's collision gets them flung by the physics solver, which
            looks like a bug and occasionally is one.
        ]]
        local Delta = Root.Position - TargetRoot.Position
        local Travel = math.min(self.PullDistance, math.max(Delta.Magnitude - 5, 0))

        if Travel > 0.5 then
            CombatUtils.Blink(Target, TargetRoot.Position + Delta.Unit * Travel)
        end

        AbilityFX.ShakeFor(Target, 1.2, 0.25)
    end

    if not Power and Pulled > 0 then
        Power = "Dash"
        AbilityFX.Sound(self.SwallowSound, Origin, {Volume = 0.8, MinPitch = 1.0, MaxPitch = 1.1})
    end

    ----------------------------------------------------------------------------
    -- STORE IT
    ----------------------------------------------------------------------------

    if Power then
        Char:SetAttribute(POWER_ATTRIBUTE, Power)
        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), Power:upper().."!", STAR, 1.3)
        AbilityFX.Tint(Char, STAR, 0.8, {FillTransparency = 0.7})
    else
        -- Nothing in the cone. Refund — a miss should cost tempo, not twelve seconds.
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nothing", KIRBY, 0.8)
    end
end

--------------------------------------------------------------------------------
-- E — COPY
--------------------------------------------------------------------------------

--[=[
    Uses whatever is in his mouth, then empties it.

    Three branches, all written here. See the header for why this is a fixed set rather than
    anything that runs another character's code.
]=]
local function CopyBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.35, Lock = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Power = Char:GetAttribute(POWER_ATTRIBUTE)

    if not Power then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nothing to copy", KIRBY, 1)
        return
    end

    -- Spent, whatever happens next.
    Char:SetAttribute(POWER_ATTRIBUTE, nil)

    ----------------------------------------------------------------------------

    if Power == "Projectile" then
        AbilityFX.Sound(self.SpitSound, Root.Position, {Volume = 0.9, MinPitch = 1.1, MaxPitch = 1.25})

        local Muzzle = Root.Position + Root.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)

        ProjectileService.Fire({
            SourcePlayer = self.Owner,
            Name = "KirbyStar",
            Origin = Muzzle,
            Direction = Root.CFrame.LookVector,
            Speed = self.StarSpeed,
            Lifetime = self.StarRange / self.StarSpeed,
            Radius = 3,
            Damage = self.StarDamage,
            Reason = "Star Spit",
            Knockback = 7,
            Pierce = 2,
            Spin = 520,
            Visual = {
                Shape = Enum.PartType.Block,
                Size = Vector3.new(3, 3, 0.8),
                Color = STAR,
                Material = Enum.Material.Neon,
                Trail = true,
                TrailColor = KIRBY,
                Light = true,
                LightRange = 14,
            },
            OnHit = function(_projectile, humanoid: Humanoid)
                local Victim = humanoid.Parent
                local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                if VictimRoot then
                    AbilityFX.Shockwave(VictimRoot.Position, 7, STAR, 16)
                end
                return nil
            end,
            OnImpact = function(_projectile, position: Vector3)
                AbilityFX.Burst(position, 5, STAR, {Duration = 0.3})
            end,
        })

        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "ptooey", STAR, 0.9)

    ----------------------------------------------------------------------------

    elseif Power == "Guard" then
        AbilityFX.Sound(self.GuardSound, Root.Position, {Volume = 0.8, MinPitch = 0.8, MaxPitch = 0.9})

        CombatUtils.ApplyEffectTo(Char, "Resistance", self.GuardLevel, self.GuardTime)

        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "GUARD", KIRBY, 1.2)
        AbilityFX.Ring(Root.Position, 8, KIRBY, {Duration = 0.5})

        -- A shell around him for the duration, so opponents can see it is up.
        task.spawn(function()
            local Elapsed = 0
            while Elapsed < self.GuardTime and Char and Char.Parent do
                Elapsed += task.wait(0.3)
                local Live = Utils.Character.GetRootPart(Char)
                if Live then
                    AbilityFX.Burst(Live.Position, 5, KIRBY, {
                        Duration = 0.35,
                        StartSize = 4.5,
                        Transparency = 0.8,
                    })
                end
            end
        end)

    ----------------------------------------------------------------------------

    else
        AbilityFX.Sound(self.DashSound, Root.Position, {Volume = 0.75, MinPitch = 1.15, MaxPitch = 1.3})

        CombatUtils.Dash(Char, self.DashSpeed, self.DashTime, true)
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "zoom", KIRBY, 0.9)

        task.spawn(function()
            local Elapsed = 0
            while Elapsed < self.DashTime and Char and Char.Parent do
                Elapsed += task.wait(0.05)
                local Live = Utils.Character.GetRootPart(Char)
                if Live then
                    AbilityFX.Burst(Live.Position, 3, KIRBY, {Duration = 0.25, StartSize = 2, Transparency = 0.7})
                end
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- R — WARP STAR
--------------------------------------------------------------------------------

--[=[
    Rides a star.

    The longest single reposition in the game — 1.6 seconds of very fast travel that follows
    his camera, with a visible star under him and a trail behind. He cannot attack during it
    and he arrives with no damage at all.

    It is pure mobility on a long cooldown, deliberately: Kirby's problem is getting into
    position for a cone and a hammer, and this solves exactly that problem and nothing else.
]=]
local function WarpStarBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.3, Duration = self.FlightTime})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.95})

    -- Steerable, so it is a ride rather than a launch — it is the one movement ability on
    -- the roster that is explicitly about going somewhere rather than hitting something.
    CombatUtils.Dash(Char, self.Speed, self.FlightTime, true)

    -- Harmless in flight.
    Char:SetAttribute("PreventSlash", true)

    local Star = AbilityFX.Part({
        Name = "WarpStar",
        Size = Vector3.new(7, 1, 7),
        CFrame = Root.CFrame * CFrame.new(0, -2.5, 0),
        Color = STAR,
        Material = Enum.Material.Neon,
    })
    Star.Parent = AbilityFX.Folder()
    AbilityFX.Trail(Star, STAR, {Lifetime = 0.5, Width = 5})

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.FlightTime and Char and Char.Parent and Star.Parent do
            Elapsed += task.wait(0.03)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            Star.CFrame = Live.CFrame * CFrame.new(0, -2.5, 0)
        end

        if Star.Parent then
            AbilityFX.Burst(Star.Position, 7, STAR, {Duration = 0.4})
            Star:Destroy()
        end

        -- Raw path, not a Janitor thread: `PreventSlash` must come off even if he dies in
        -- the air, or his next body cannot attack.
        if Char then
            Char:SetAttribute("PreventSlash", nil)
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — FLOAT
--------------------------------------------------------------------------------

--[=[
    He falls slowly.

    A terminal velocity rather than flight: while he is moving downward faster than
    `TerminalVelocity`, the downward component is clamped. He gets no lift and no control he
    did not already have — he simply does not drop like a rock.

    WHY IT MATTERS MECHANICALLY: it makes every ledge in the arena a route for him, it makes
    Warp Star safe to end over a drop, and it is the quiet reason he can afford a cone-based
    kit — he can always get to the high ground the cone wants.

    The loop runs at 20 Hz and only writes velocity when it is actually falling too fast, so
    it costs nothing while he is on the floor.
]=]
local function FloatInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Humanoid = self.OwnerProperties.Humanoid
    if not Char or not Humanoid then
        return
    end

    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.05)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            local Velocity = Root.AssemblyLinearVelocity

            -- Only while genuinely falling. `Freefall` rather than a Y check alone, so
            -- walking down a slope does not trigger it.
            if Velocity.Y >= -self.TerminalVelocity then
                continue
            end

            local State = Humanoid:GetState()
            if State ~= Enum.HumanoidStateType.Freefall and State ~= Enum.HumanoidStateType.Jumping then
                continue
            end

            Root.AssemblyLinearVelocity = Vector3.new(Velocity.X, -self.TerminalVelocity, Velocity.Z)

            -- A puff, so the float is visible rather than feeling like lag.
            if math.random() < 0.3 then
                AbilityFX.Burst(Root.Position - Vector3.new(0, 1.5, 0), 2.5, KIRBY, {
                    Duration = 0.3,
                    StartSize = 1.5,
                    Transparency = 0.85,
                })
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Kirby: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Kirby",
        Quote = "Hi!",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 7800,

        Role = "Hybrid",
        Difficulty = 3,

        Origin = {
            TooltipText = "He is eight inches tall.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        Health = 1250,
        BaseSpeed = 11.2,
        SprintSpeedMultiplier = 25.5 / 11.2,
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
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 26,
                Cooldown = 1.9,
                Duration = 0.3,
                Delay = 0.14,
                --- Small. He is small.
                HitboxSize = Vector3.new(5, 5.5, 4.5),
                HitboxOffset = CFrame.new(0, 0, -2.4),

                Behaviour = StarStrikeBehaviour,
            }),

            Inhale = Ability.New({
                Name = "Inhale",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 12,
                Duration = 0.6,

                Range = 24,
                Angle = 70,
                Damage = 12,
                PullDistance = 8,
                --- A deployable bigger than this is not food. Keeps walls off the menu.
                MaximumMouthful = 14,

                UseSound = "rbxassetid://9125402735",
                SwallowSound = "rbxassetid://12222216",
                Behaviour = InhaleBehaviour,
            }),

            Copy = Ability.New({
                Name = "Copy",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 6,
                Duration = 0.4,

                StarDamage = 48,
                StarSpeed = 125,
                StarRange = 120,

                GuardLevel = 4,
                GuardTime = 4,

                DashSpeed = 80,
                DashTime = 0.4,

                SpitSound = "rbxassetid://9046319808",
                GuardSound = "rbxassetid://12222216",
                DashSound = "rbxassetid://12222030",
                Behaviour = CopyBehaviour,
            }),

            WarpStar = Ability.New({
                Name = "Warp Star",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 30,
                Duration = 1.6,

                Speed = 105,
                FlightTime = 1.6,

                UseSound = "rbxassetid://9118823103",
                Behaviour = WarpStarBehaviour,
            }),

            Float = Ability.New({
                Name = "Float",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Studs per second. Normal gravity reaches several times this.
                TerminalVelocity = 22,

                ExtraInit = FloatInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 150, 190)\">"..Kirby.Config.Name.."</font>"
local Abilities = Kirby.GameplayConfig.Abilities

Kirby.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Kirby.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Kirby.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." swallows things and then he is that thing.",
            "<b>Inhale</b> is one keypress with three outcomes, and which one you get depends entirely on what you pointed it at: somebody's projectile, a small structure, or just a person.",
            "He never swallows players. He drags them a few studs and lets go.",
            "With an empty mouth he is a short-range hammer and a very good jump.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Kirby.Config.Role,
            "Difficulty: "..string.rep("★", Kirby.Config.Difficulty)..string.rep("☆", 5 - Kirby.Config.Difficulty),
            "Price: "..tostring(Kirby.Config.Price).."$",
            "Health: "..tostring(Kirby.GameplayConfig.Health),
            "Base Speed: "..tostring(Kirby.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Kirby.GameplayConfig.BaseSpeed * Kirby.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "STAR STRIKE"},
    {
        Type = "Text",
        Text = tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds. Short reach, and a star where it lands.",
    },

    {Type = "Header", Text = "INHALE  (Q)"},
    {
        Type = "Text",
        Text = {
            "A "..tostring(Abilities.Inhale.Range).." stud cone. Drags fighters "..tostring(Abilities.Inhale.PullDistance).." studs toward him for "..tostring(Abilities.Inhale.Damage).." damage, and <b>swallows</b> what it can.",
            "Priority: a <b>projectile</b> in flight, then a small <b>structure or trap</b>, then whatever <b>fighter</b> it caught.",
            "Walls are too big to eat. It refunds itself if the cone was empty.",
            "Cooldown: "..tostring(Abilities.Inhale.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "COPY  (E)"},
    {
        Type = "Text",
        Text = {
            "Uses what is in his mouth, then empties it. One of three:",
            "<b>Projectile</b> — spits a star for "..tostring(Abilities.Copy.StarDamage).." damage that goes through two people. His only ranged attack.",
            "<b>Guard</b> — <b>Resistance "..tostring(Abilities.Copy.GuardLevel).."</b> for "..tostring(Abilities.Copy.GuardTime).." seconds.",
            "<b>Dash</b> — a short steerable burst of speed.",
            "Does nothing with an empty mouth, and refunds itself.",
            "Cooldown: "..tostring(Abilities.Copy.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "WARP STAR  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.WarpStar.FlightTime).." seconds of very fast steerable flight — the longest single reposition in the game.",
            "He cannot attack during it and it deals no damage. It is purely about getting somewhere.",
            "Cooldown: "..tostring(Abilities.WarpStar.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "FLOAT  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "He never falls faster than "..tostring(Abilities.Float.TerminalVelocity).." studs a second.",
            "No lift and no extra control — he just does not drop like a rock. It makes every ledge in the arena a route for him.",
        },
    },
}

return Kirby
