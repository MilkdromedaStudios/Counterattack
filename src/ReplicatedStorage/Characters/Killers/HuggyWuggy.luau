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
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    HUGGY WUGGY — ARMS.

      M1  LONG ARM SWIPE  Nine studs of reach and a horrible wind-up.
      Q   CRAWL           Drops onto all fours. Much faster, lower, and disarmed.
      E   GRAB            Throws an arm out. It drags whoever it catches toward him.
      R   VENT HUNT       Marks a point, then travels to it along the ceiling.
      P   LONG LIMBS      Permanently longer reach on everything, including the grab.

    HOW HE IS DIFFERENT FROM ENDERMAN
    ---------------------------------
    They are both long-armed ambushers, so the distinction is deliberate and total:

      * Enderman is about BEING LOOKED AT. Its reach is a slow, narrow, heavily telegraphed
        poke, and its mobility is a short validated teleport.
      * Huggy is about CLOSING. His reach is wide rather than deep, his grab physically
        drags you toward him, and his mobility is sustained running on all fours — he does
        not blink, he comes.

    CRAWL IS THE CHARACTER
    ----------------------
    A state, not a dash: 40% faster, swipe disarmed, and he can keep it up as long as he
    likes. That trade — the fastest sustained movement in the game in exchange for giving up
    his damage while using it — is what makes him read as the thing from the corridor rather
    than another killer with a sprint button.

    WEAKNESSES
    ----------
    No ranged damage. The grab is a slow, visible, audible projectile. Crawling gives up his
    swipe, so every approach is announced by him being unable to finish it. And his wind-up is
    the longest of any basic attack on the roster.
]=]

local HUGGY = Color3.fromRGB(70, 130, 220)
local HUGGY_TEETH = Color3.fromRGB(240, 240, 230)

--- Attribute marking the crawl, so the client and the grab both read the same state.
local CRAWL_ATTRIBUTE = "HuggyCrawling"

--------------------------------------------------------------------------------
-- M1 — LONG ARM SWIPE
--------------------------------------------------------------------------------

--[=[
    A wide sweep with both arms.

    WIDE, not deep — 11 studs across against Enderman's 4. The reach bonus from `Long Limbs`
    is already baked into the numbers here. The 0.26 second wind-up is the longest on the
    roster, and the arms are drawn during it, so there is real time to step out of the arc.
]=]
local function SwipeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.35, Lock = 0.75})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    -- Cannot swing on all fours. `Ability:CanUse` reads `PreventSlash`, so this should never
    -- be reachable — but an ability that silently works in a state it is not supposed to is
    -- worth a second guard rather than a comment.
    if Char:GetAttribute(CRAWL_ATTRIBUTE) then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.7, MinPitch = 0.7, MaxPitch = 0.85})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- Both arms, drawn as they come round. This IS the telegraph.
        local From = Root.Position + Vector3.new(0, 1.5, 0)
        for _, Side in {-1, 1} do
            AbilityFX.Beam(
                From + Root.CFrame.RightVector * (Side * 1.5),
                From + Root.CFrame.RightVector * (Side * 5.5) + Root.CFrame.LookVector * 6,
                HUGGY,
                {Width = 1.1, Duration = 0.25, Transparency = 0.25}
            )
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Long Arms",
            ExecuteOnKill = true,
            Knockback = 4,
            -- Both arms sweep through. It is an embrace, not a jab.
            HitMultiple = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, HUGGY_TEETH, 8, 14)
                        AbilityFX.ShakeFor(Victim, 2, 0.3)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — CRAWL
--------------------------------------------------------------------------------

--[=[
    Drops onto all fours.

    A TOGGLE, not a timed buff. Press to start, press again to stand up, and it costs almost
    nothing to switch — which is what makes it a movement MODE rather than a cooldown.

    While crawling:
      * 40% faster. The fastest sustained movement on the roster.
      * HIS SWIPE IS DISARMED, through the engine's `PreventSlash` attribute, which
        `Ability:CanUse` reads. `Grab` still works — see its own note for why that one
        exception is correct.
      * Visibly lower, and leaving a trail along the floor.

    Losing his damage is the entire price. A Huggy crawling toward you is a Huggy who has to
    stop and stand up before he can hurt you, and standing up takes a moment you can see.

    `AbilitiesLocked` is deliberately NOT used. `Ability:CanUse` checks it before
    `UseConditions` and exempts only the basic attack by name, so setting it here would lock
    `Crawl` itself out — and the only way to stand up is to press `Crawl` again.
]=]
local function CrawlBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Low and fast: the view drops and widens.
        local Char = self.OwnerProperties.Character
        if Char and Char:GetAttribute(CRAWL_ATTRIBUTE) then
            AbilityClient.ReleaseZoom(self)
        else
            AbilityClient.Zoom(self, 1.25)
        end
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Humanoid = self.OwnerProperties.Humanoid

    ----------------------------------------------------------------------------
    -- STAND UP
    ----------------------------------------------------------------------------

    if Char:GetAttribute(CRAWL_ATTRIBUTE) then
        Char:SetAttribute(CRAWL_ATTRIBUTE, false)

        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        Char:SetAttribute("PreventSlash", nil)

        if Humanoid then
            Humanoid.HipHeight = self.NormalHipHeight or 0
        end

        AbilityFX.Sound(self.StandSound, Root.Position, {Volume = 0.7, MinPitch = 0.8, MaxPitch = 0.95})
        AbilityFX.Smoke(Root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 200, 200), 6, 2)

        return
    end

    ----------------------------------------------------------------------------
    -- DROP DOWN
    ----------------------------------------------------------------------------

    Char:SetAttribute(CRAWL_ATTRIBUTE, true)

    --[[
        Remembered rather than assumed, so standing back up restores whatever the rig
        actually had — a future Huggy model with a different hip height would otherwise be
        permanently lowered by one crawl.
    ]]
    if Humanoid then
        self.NormalHipHeight = Humanoid.HipHeight
        Humanoid.HipHeight = math.max(Humanoid.HipHeight - self.Drop, 0)
    end

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

    -- Disarmed. `Ability:CanUse` reads `PreventSlash` and refuses the basic attack while
    -- it is set; everything else he has stays available.
    Char:SetAttribute("PreventSlash", true)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8, MinPitch = 0.65, MaxPitch = 0.8})
    AbilityFX.Smoke(Root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 200, 200), 8, 2.5)

    -- A low trail while it lasts, so people can see him coming along the floor.
    task.spawn(function()
        while Char and Char.Parent and Char:GetAttribute(CRAWL_ATTRIBUTE) do
            task.wait(0.15)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            if Live.AssemblyLinearVelocity.Magnitude > 10 then
                AbilityFX.Burst(Live.Position - Vector3.new(0, 1.5, 0), 2.5, HUGGY, {
                    Duration = 0.3,
                    StartSize = 1.5,
                    Transparency = 0.8,
                })
            end
        end

        --[[
            Cleanup for every way the crawl can end that ISN'T pressing Q again: dying, the
            round ending, the character being removed. `PreventSlash` surviving onto a new
            body would be a Huggy who can never attack.
        ]]
        if Char then
            Char:SetAttribute(CRAWL_ATTRIBUTE, false)
            Char:SetAttribute("PreventSlash", nil)
        end
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)
end

--------------------------------------------------------------------------------
-- E — GRAB
--------------------------------------------------------------------------------

--[=[
    An arm, thrown.

    A slow visible projectile that drags whoever it catches 60% of the way toward him and
    leaves them `Snared` briefly. It is the engage, and it is beatable three ways: the arm is
    slow enough to sidestep, walls stop it, and `Snared` leaves the victim their abilities and
    their basic attack — so being grabbed by Huggy is dangerous, not decided.

    It can be used while crawling, which is the one exception to being harmless on all fours.
    The arm still does its damage, but using it does not stand him up — so a crawling Huggy
    who grabs you has closed the distance and still has to get upright before he can swing.
]=]
local function GrabBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.4, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1, 0) + Root.CFrame.LookVector * 2

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.85, MinPitch = 0.8, MaxPitch = 0.95})

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "HuggyArm",
        Origin = Origin,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 3,
        Damage = self.Damage,
        Reason = self.Name,
        FaceTravel = true,
        Visual = {
            Shape = Enum.PartType.Block,
            Size = Vector3.new(1.6, 1.6, 7),
            Color = HUGGY,
            Material = Enum.Material.Fabric,
            Trail = true,
            TrailColor = HUGGY,
        },
        OnStep = function(projectile, _delta, position)
            -- Drawn as an arm stretching back to him, which is what makes it read as a
            -- grab rather than a thrown object.
            if Root and Root.Parent and projectile.Age % 0.07 < 0.03 then
                AbilityFX.Beam(Root.Position + Vector3.new(0, 1, 0), position, HUGGY, {
                    Width = 1.3,
                    Duration = 0.1,
                    Transparency = 0.3,
                    Material = Enum.Material.Fabric,
                })
            end
        end,
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            if not Victim or not Victim:IsA("Model") then
                return nil
            end

            local VictimRoot = Utils.Character.GetRootPart(Victim)
            local Live = Char and Utils.Character.GetRootPart(Char)
            if not VictimRoot or not Live then
                return nil
            end

            -- Dragged most of the way, never all of it, and never inside his collision.
            local Delta = Live.Position - VictimRoot.Position
            local Distance = math.max(Delta.Magnitude - 7, 0)
            local Destination = VictimRoot.Position + Delta.Unit * Distance * self.PullFraction

            CombatUtils.Blink(Victim, Destination)
            CombatUtils.ApplyEffectTo(Victim, "Snared", 2, self.SnareTime)

            AbilityFX.Beam(Live.Position + Vector3.new(0, 1, 0), Destination, HUGGY, {Width = 1.8, Duration = 0.3})
            AbilityFX.Ring(Destination, 8, HUGGY, {Duration = 0.4})
            AbilityFX.ShakeFor(Victim, 2.5, 0.4)
            AbilityFX.Sound(self.CatchSound, Destination, {Volume = 0.95})

            return nil
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Smoke(position, HUGGY, 6, 2)
        end,
    })
end

--------------------------------------------------------------------------------
-- R — VENT HUNT
--------------------------------------------------------------------------------

--[=[
    Travels to a point along the ceiling.

    Two presses, like Enderman's block — and for the same reason: the interesting decision is
    WHERE, and a two-stage ability lets him commit to a destination and then arrive at it
    later.

      PRESS ONE  Plants a vent marker where he is standing, visible to everybody.
      PRESS TWO  He travels to it. A thin line of movement is drawn overhead for the whole
                 trip and the arrival is loud.

    The travel is not instant and not invisible. The marker is a physical object anyone can
    smash before he uses it, which is the counterplay: a Huggy who plants a vent in the middle
    of a fight has told everybody where he intends to be.
]=]
local function VentBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    ----------------------------------------------------------------------------
    -- TRAVEL
    ----------------------------------------------------------------------------

    local Marker = Cache.VentMarker

    if Marker and Marker.Alive and Marker.Root and Marker.Root.Parent then
        local Destination = AbilityFX.GroundAt(Marker.Root.Position, {Char, Marker.Model}, 40)

        if not Destination then
            self.OnCooldown = false
            self.CooldownTimer = 0
            return
        end

        local Start = Root.Position

        AbilityFX.Sound(self.EnterSound, Start, {Volume = 0.9, MinPitch = 0.7, MaxPitch = 0.85})
        AbilityFX.Smoke(Start, Color3.fromRGB(60, 60, 70), 14, 3)

        -- The route, drawn overhead. He is going along the ceiling, and everybody can see it.
        local High = math.max(Start.Y, Destination.Y) + self.Height
        AbilityFX.Beam(Start, Vector3.new(Start.X, High, Start.Z), HUGGY, {Width = 1, Duration = 0.5, Transparency = 0.45})
        AbilityFX.Beam(
            Vector3.new(Start.X, High, Start.Z),
            Vector3.new(Destination.X, High, Destination.Z),
            HUGGY,
            {Width = 1, Duration = 0.6, Transparency = 0.45}
        )
        AbilityFX.Beam(Vector3.new(Destination.X, High, Destination.Z), Destination, HUGGY, {Width = 1, Duration = 0.7, Transparency = 0.45})

        AbilityFX.Telegraph(Destination, 10, HUGGY, self.Travel)

        task.delay(self.Travel, function()
            if not Char or not Char.Parent then
                return
            end

            CombatUtils.Blink(Char, Destination + Vector3.new(0, 3, 0))

            AbilityFX.Smoke(Destination, Color3.fromRGB(60, 60, 70), 16, 3.5)
            AbilityFX.Ring(Destination, 12, HUGGY, {Duration = 0.5, Thickness = 1})
            AbilityFX.Sound(self.ArriveSound, Destination, {Volume = 1, RollOffMaxDistance = 170})
            AbilityFX.ShakeInRadius(Destination, 30, 3, 0.5)

            for _, Target: Model in CombatUtils.GetFightersInRadius(Destination, self.ImpactRadius, Char) do
                local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                if not Humanoid then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = self.ImpactDamage,
                    Reason = self.Name,
                })

                AbilityFX.ScreenFor(Target, "Rage", 1, 0.9)
            end

            -- The vent is spent.
            if Marker.Alive then
                Marker:Destroy()
            end
            Cache.VentMarker = nil
        end)

        return
    end

    ----------------------------------------------------------------------------
    -- PLANT
    ----------------------------------------------------------------------------

    local Ground = AbilityFX.GroundAt(Root.Position, {Char})
    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.PlantSound, Ground, {Volume = 0.7})

    Cache.VentMarker = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Vent",
        Name = "Vent",
        CFrame = CFrame.new(Ground + Vector3.new(0, 0.3, 0)),
        Size = Vector3.new(5, 0.6, 5),
        Color = Color3.fromRGB(50, 50, 60),
        Material = Enum.Material.DiamondPlate,
        Solid = false,
        --- Low, because planting it is free. Smashing it before he uses it is the answer.
        Health = self.MarkerHealth,
        Lifetime = self.MarkerLifetime,
        Limit = 1,
        OutlineColor = HUGGY,
        OnEnd = function()
            if Cache.VentMarker and not Cache.VentMarker.Alive then
                Cache.VentMarker = nil
            end
        end,
    })

    if Cache.VentMarker then
        AbilityFX.Ring(Ground, 6, HUGGY, {Duration = 0.4})
        --[[
            The cooldown is cut right down on the planting press.

            Planting is not the powerful half — travelling is. Charging a 36 second cooldown
            for putting a marker on the floor would mean the ability's real effect is on a
            72 second cycle, which is not what the number says.
        ]]
        self.OnCooldown = false
        self.CooldownTimer = 0
        self:SetOnCooldown(self.PlantCooldown)
    end
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local HuggyWuggy: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Huggy Wuggy",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 16000,

        Role = "Chaser",
        Difficulty = 3,

        Origin = {
            TooltipText = "He was a mascot.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Soft and wrong. He is made of fabric and there is a lot of him.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Average health, average standing speed, and the fastest sustained movement in
            the game while he cannot attack. All his pressure is positional.
        ]]
        Health = 1300,
        BaseSpeed = 11,
        SprintSpeedMultiplier = 25.5 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 115,
            StaminaDrain = 10,
            StaminaGain = 21,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 27,
                Cooldown = 1.9,
                Duration = 0.34,
                --- The longest wind-up on the roster. The arms are drawn during it.
                Delay = 0.26,
                --- Wide rather than deep. Eleven studs across, nine deep.
                HitboxSize = Vector3.new(11, 7, 9),
                HitboxOffset = CFrame.new(0, 0, -4.5),

                Behaviour = SwipeBehaviour,
            }),

            Crawl = Ability.New({
                Name = "Crawl",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                --- Short, because it is a toggle and switching should be nearly free.
                Cooldown = 1.5,
                Duration = 0.2,

                SpeedMultiplier = 1.4,
                Drop = 1.6,

                UseSound = "rbxassetid://9046319808",
                StandSound = "rbxassetid://12222216",
                Behaviour = CrawlBehaviour,
            }),

            Grab = Ability.New({
                Name = "Grab",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 14,
                Duration = 0.45,

                Damage = 22,
                Speed = 75,
                Range = 70,
                PullFraction = 0.6,
                SnareTime = 1,

                UseSound = "rbxassetid://9125402735",
                CatchSound = "rbxassetid://9046319808",
                Behaviour = GrabBehaviour,
            }),

            Vent = Ability.New({
                Name = "Vent",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 36,
                --- Short on the planting press. See the comment in the behaviour.
                PlantCooldown = 4,
                Duration = 0.5,

                Travel = 0.8,
                Height = 25,
                MarkerHealth = 30,
                MarkerLifetime = 60,
                ImpactRadius = 12,
                ImpactDamage = 35,

                PlantSound = "rbxassetid://12222216",
                EnterSound = "rbxassetid://9046319808",
                ArriveSound = "rbxassetid://9118823103",
                Behaviour = VentBehaviour,
            }),

            LongLimbs = Ability.New({
                Name = "Long Limbs",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(70, 130, 220)\">"..HuggyWuggy.Config.Name.."</font>"
local Abilities = HuggyWuggy.GameplayConfig.Abilities

HuggyWuggy.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = HuggyWuggy.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." closes distance. That is all he does, and he is better at it than anybody.",
            "On all fours he is the fastest sustained mover in the arena — and his swipe is disarmed the whole time. Every approach he makes is announced by the fact that he cannot hurt you during it.",
            "He has no ranged damage, and the longest basic-attack wind-up in the game.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..HuggyWuggy.Config.Role,
            "Difficulty: "..string.rep("★", HuggyWuggy.Config.Difficulty)..string.rep("☆", 5 - HuggyWuggy.Config.Difficulty),
            "Price: "..tostring(HuggyWuggy.Config.Price).."$",
            "Health: "..tostring(HuggyWuggy.GameplayConfig.Health),
            "Base Speed: "..tostring(HuggyWuggy.GameplayConfig.BaseSpeed),
            "Crawl Speed: "..tostring(math.round(HuggyWuggy.GameplayConfig.BaseSpeed * Abilities.Crawl.SpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "LONG ARM SWIPE"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, in an arc "..tostring(Abilities.Slash.HitboxSize.X).." studs wide that hits everybody in it.",
            "The longest wind-up of any basic attack here, and the arms are drawn as they come round. Step out of the arc.",
        },
    },

    {Type = "Header", Text = "CRAWL  (Q)"},
    {
        Type = "Text",
        Text = {
            "A <b>toggle</b>. On all fours he is 40% faster and lower to the ground, and <b>his swipe is disarmed</b>.",
            "There is no time limit — he can crawl as long as he likes. Standing back up takes a moment, and you can see it.",
            "Cooldown: "..tostring(Abilities.Crawl.Cooldown).." seconds between switches.",
        },
    },

    {Type = "Header", Text = "GRAB  (E)"},
    {
        Type = "Text",
        Text = {
            "Throws an arm up to "..tostring(Abilities.Grab.Range).." studs. On a hit it drags the victim 60% of the way to him for "..tostring(Abilities.Grab.Damage).." damage and a "..tostring(Abilities.Grab.SnareTime).." second <b>Snare</b>.",
            "The arm is slow enough to sidestep and walls stop it. Snared leaves you your abilities and your attack.",
            "Usable while crawling. A crawling Huggy can close the gap and drag you in — and then still has to stand up before he can swing.",
            "Cooldown: "..tostring(Abilities.Grab.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "VENT  (R)"},
    {
        Type = "Text",
        Text = {
            "Press once to plant a vent where he stands. Press again to travel to it along the ceiling, arriving for "..tostring(Abilities.Vent.ImpactDamage).." damage across "..tostring(Abilities.Vent.ImpactRadius).." studs.",
            "The marker is a visible object with "..tostring(Abilities.Vent.MarkerHealth).." health. <b>Smash it and he has nowhere to go.</b>",
            "The route is drawn overhead for the whole trip.",
            "Cooldown: "..tostring(Abilities.Vent.Cooldown).." seconds to travel, "..tostring(Abilities.Vent.PlantCooldown).." to plant.",
        },
    },

    {Type = "Header", Text = "LONG LIMBS  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Everything he does reaches further than it looks like it should — the swipe, the grab, the arc.",
            "It is already included in every number on this page. There is no hidden bonus; his reach simply IS the character.",
        },
    },
}

return HuggyWuggy
