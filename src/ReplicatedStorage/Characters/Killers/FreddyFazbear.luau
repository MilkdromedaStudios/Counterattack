local Lighting = game:GetService("Lighting")
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
    FREDDY FAZBEAR — HE DOES NOT RUN. HE ARRIVES.

      M1  ANIMATRONIC GRAB  Slow, heavy, and it does not let go gently.
      Q   POWER OUTAGE      Kills the lights in an area. You can still see. Barely.
      E   CAMERA STALK      Plants a camera. It watches a room and tells him who is in it.
      R   FAZBEAR AMBUSH    Relocates to one of his own cameras, with a music sting first.
      P   DARKNESS          He is stronger and quieter in the dark — including his own.

    HE IS SLOW ON PURPOSE
    ---------------------
    Joint-slowest base speed on the roster with Builderman, and the lowest sprint multiplier
    of anybody. He cannot win a footrace and is not meant to try. What he has instead is the
    ability to be somewhere else: `Camera Stalk` plants an eye, `Fazbear Ambush` moves him to
    it, and `Power Outage` makes the ground in between miserable to cross.

    THE WHOLE KIT FEEDS ONE LOOP
    ----------------------------
    Plant a camera on the route people use. See them walk into it. Kill the lights. Relocate
    onto them in the dark, where his passive makes him faster, harder-hitting and silent.

    Every step of that is visible to the people it is happening to. The outage is announced,
    the cameras are physical objects anyone can smash, and the ambush plays a laugh and a
    music sting a full second before he appears.

    DARKNESS IS NEVER BLINDNESS
    ---------------------------
    `Power Outage` dims the screen to a hard floor — about 55% — and nothing more. The brief
    was explicit that survivors must still be able to navigate, and a killer who can make you
    unable to see is a killer with no counterplay. What darkness actually does is make HIM
    stronger, which is a far more interesting threat than taking away your eyes.
]=]

local FREDDY = Color3.fromRGB(150, 95, 50)
local FREDDY_DARK = Color3.fromRGB(70, 40, 20)

--------------------------------------------------------------------------------
-- DARKNESS
--------------------------------------------------------------------------------

--[=[
    Is he in the dark?

    Two sources, either of which counts:

      * THE MAP IS DARK. Read from `Lighting.Brightness` and `ClockTime`, which the server
        owns — so this works on night maps and in dark interiors with no per-map setup.
      * HE IS STANDING IN HIS OWN OUTAGE. The outage is a real deployable with a real
        position, so this is just a distance check.

    Written as one function because three separate things read it — the passive loop, the
    basic attack's damage, and the ambush's availability — and they must agree.
]=]
local function InDarkness(player: Player, char: Model): boolean
    if not char then
        return false
    end

    -- A dim map, or night.
    if Lighting.Brightness <= 1 then
        return true
    end
    if Lighting.ClockTime >= 19 or Lighting.ClockTime <= 5 then
        return true
    end

    local Root = Utils.Character.GetRootPart(char)
    if not Root then
        return false
    end

    for _, Outage in DeployableService.GetFor(player, "Outage") do
        if Outage.Alive and Outage.Root and Outage.Root.Parent then
            if (Outage.Root.Position - Root.Position).Magnitude <= (Outage.State.Radius or 0) then
                return true
            end
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- M1 — ANIMATRONIC GRAB
--------------------------------------------------------------------------------

--[=[
    A heavy mechanical lunge.

    Slow (2.3 seconds), hits hard, and gets a flat bonus in the dark. The servo whine on the
    wind-up is deliberately long: you should be able to hear him decide to swing.
]=]
local function GrabBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.96, Duration = 0.4, Lock = 0.8, Shake = 0.4, ShakeTime = 0.2})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Dark = InDarkness(self.Owner, Char)
    local Damage = Dark and self.Damage + self.DarkBonus or self.Damage

    -- Servos. Lower and slower than anything else on the roster.
    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.8, MinPitch = 0.6, MaxPitch = 0.72})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = Dark and "Animatronic Grab (dark)" or "Animatronic Grab",
            ExecuteOnKill = true,
            Knockback = 6,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if not VictimRoot then
                        return
                    end

                    AbilityFX.Sparks(VictimRoot.Position, FREDDY, 10, 16)
                    AbilityFX.ShakeFor(Victim, 2.5, 0.4)

                    -- The jumpscare is on the HIT, not on the cast. It is a reaction, not a
                    -- warning, so it costs the victim nothing they could have avoided.
                    AbilityFX.ScreenFor(Victim, "Flash", 0.3, 0.5)
                    AbilityFX.Sound(self.ScareSound, VictimRoot.Position, {Volume = 1, RollOffMaxDistance = 60})
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — POWER OUTAGE
--------------------------------------------------------------------------------

--[=[
    The lights go out in an area.

    A deployable with a large radius, no collision and almost no health — it is a volume, not
    an object, and it exists as a deployable so that `InDarkness` can find it and so it
    cleans itself up with everything else.

    Anyone inside gets the `Dark` screen effect topped up continuously. It bottoms out at a
    dim screen: you can see the map, the people in it, and the exits. What you cannot do is
    see him coming as early.
]=]
local function OutageBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.9, Duration = 0.5, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 220})
    AbilityFX.Text(Origin + Vector3.new(0, 6, 0), "POWER OUT", FREDDY_DARK, 1.5)
    AbilityFX.Ring(Origin, self.Radius, FREDDY_DARK, {Duration = 0.9, Thickness = 2, Transparency = 0.6})

    local Outage = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Outage",
        Name = "PowerOutage",
        CFrame = CFrame.new(Origin),
        -- Tiny physical marker; the radius is the point, not the box.
        Size = Vector3.new(2, 2, 2),
        Color = FREDDY_DARK,
        Material = Enum.Material.Neon,
        Transparency = 0.75,
        Solid = false,
        --[[
            Five health, so a single hit ends it.

            That IS the counterplay, and it is why the marker is visible and stays put: if
            you can reach the thing making it dark, you can turn the lights back on.
        ]]
        Health = 5,
        Lifetime = self.Duration_,
        Limit = 1,
        TickRate = 0.4,
        OutlineColor = FREDDY_DARK,
        OnTick = function(handle)
            for _, Target: Model in CombatUtils.GetFightersInRadius(handle.Root.Position, self.Radius, Char) do
                -- Topped up every tick rather than applied once, so walking into the area
                -- after it started still darkens, and walking out of it clears within a
                -- second.
                AbilityFX.ScreenFor(Target, "Dark", 0.9, 1)
            end
        end,
        OnEnd = function(handle)
            AbilityFX.Burst(handle.Root.Position, 8, FREDDY, {Duration = 0.4})
            AbilityFX.Sound("rbxassetid://12222216", handle.Root.Position, {Volume = 0.7, MinPitch = 1.2, MaxPitch = 1.4})
        end,
    })

    if Outage then
        -- Stored on the handle so `InDarkness` can test against the real radius rather
        -- than a constant that would drift if this number were ever tuned.
        Outage.State.Radius = self.Radius

        -- A dome, so the affected area is unmistakable from outside it.
        local Dome = AbilityFX.Part({
            Name = "OutageDome",
            Shape = Enum.PartType.Ball,
            Size = Vector3.one * self.Radius * 2,
            CFrame = CFrame.new(Origin),
            Color = FREDDY_DARK,
            Material = Enum.Material.Neon,
            Transparency = 0.93,
        })
        Dome.Parent = Outage.Model
    end
end

--------------------------------------------------------------------------------
-- E — CAMERA STALK
--------------------------------------------------------------------------------

--[=[
    A security camera.

    It does not shoot. It reveals: anybody who walks within its radius has their aura shown
    to Freddy through walls for a few seconds. It is also what `Fazbear Ambush` relocates to,
    which makes placing one a commitment to a route rather than a free scout.

    Two at a time, destructible, and it makes a soft mechanical pan noise on a timer so the
    people being watched can hear that they are.
]=]
local function CameraBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.3, Lock = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Spot = Root.Position + Root.CFrame.LookVector * 6 + Vector3.new(0, 6, 0)

    AbilityFX.Sound(self.UseSound, Spot, {Volume = 0.6, MinPitch = 1.1, MaxPitch = 1.25})

    local Camera = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Camera",
        Name = "SecurityCamera",
        CFrame = CFrame.lookAt(Spot, Spot + Root.CFrame.LookVector),
        Size = Vector3.new(1.6, 1.4, 2.6),
        Color = Color3.fromRGB(60, 60, 65),
        Material = Enum.Material.Metal,
        Solid = false,
        Health = self.CameraHealth,
        Lifetime = self.CameraLifetime,
        Limit = self.Limit,
        TickRate = 0.5,
        OutlineColor = Color3.fromRGB(255, 60, 60),
        OnTick = function(handle)
            local Spotted = false

            for _, Target: Model in CombatUtils.GetFightersInRadius(handle.Root.Position, self.WatchRadius, Char) do
                Spotted = true
                Utils.Player.RevealPlayerAuraTo(self.Owner, Target, self.RevealTime, Color3.fromRGB(255, 60, 60))
            end

            --[[
                It only makes noise when it sees somebody.

                A camera that pans constantly is background noise nobody parses. A camera
                that clicks the moment you step into its cone is information for BOTH
                players — he learns where you are, you learn that he learned.
            ]]
            if Spotted and not handle.State.Alerting then
                handle.State.Alerting = true
                AbilityFX.Sound(self.AlertSound, handle.Root.Position, {Volume = 0.55, MinPitch = 1.3, MaxPitch = 1.45})
                AbilityFX.Ring(handle.Root.Position, self.WatchRadius, Color3.fromRGB(255, 60, 60), {Duration = 0.5, Transparency = 0.75})
                task.delay(2, function()
                    handle.State.Alerting = false
                end)
            end
        end,
    })

    if Camera then
        -- A red indicator lamp, blinking. The cheapest possible "this is watching you".
        local Lamp = AbilityFX.Part({
            Name = "Lamp",
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.5, 0.5, 0.5),
            CFrame = Camera.Root.CFrame * CFrame.new(0, 0.6, -1.2),
            Color = Color3.fromRGB(255, 40, 40),
            Material = Enum.Material.Neon,
        })
        Lamp.Parent = Camera.Model

        task.spawn(function()
            while Camera.Alive and Lamp.Parent do
                task.wait(0.8)
                Lamp.Transparency = Lamp.Transparency > 0.5 and 0 or 0.8
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- R — FAZBEAR AMBUSH
--------------------------------------------------------------------------------

--[=[
    Relocates him to one of his own cameras.

    THE WARNING IS LOUD AND IT IS WHERE HE IS GOING, NOT WHERE HE IS. A laugh and a music
    sting play at the destination a full second before he arrives, and a telegraph circle
    appears under it. Anybody standing there has a second to not be standing there.

    It requires a camera. He cannot teleport to an arbitrary point, so his mobility is
    exactly as good as his earlier planning — which is the correct shape for a stalker and
    the reason the camera has a cooldown of its own.
]=]
local function AmbushBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = self.Warning + 0.3, Shake = 1, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- PICK A CAMERA
    ----------------------------------------------------------------------------

    -- The one with the most people near it, so the ability makes its own decision sensibly
    -- rather than requiring him to aim at something he cannot see.
    local Best, BestCount = nil, -1

    for _, Camera in DeployableService.GetFor(self.Owner, "Camera") do
        if not Camera.Alive or not Camera.Root or not Camera.Root.Parent then
            continue
        end

        local Count = #CombatUtils.GetFightersInRadius(Camera.Root.Position, self.WatchRadius, Char)
        if Count > BestCount then
            Best, BestCount = Camera, Count
        end
    end

    if not Best then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "no cameras", FREDDY, 1)
        return
    end

    ----------------------------------------------------------------------------
    -- THE WARNING
    ----------------------------------------------------------------------------

    local Below = AbilityFX.GroundAt(Best.Root.Position, {Char, Best.Model}, 30)
    local Destination = Below and Below + Vector3.new(0, 3, 0) or nil

    if not Destination then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.LaughSound, Destination, {Volume = 1, RollOffMinDistance = 20, RollOffMaxDistance = 140})
    AbilityFX.Telegraph(Destination, 12, FREDDY, self.Warning)

    -- Heavy footsteps approaching, at the destination. He is not there yet; the sound is.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Warning do
            Elapsed += task.wait(self.Warning / 4)
            AbilityFX.Sound(self.StepSound, Destination, {
                Volume = 0.6 + Elapsed / self.Warning * 0.4,
                MinPitch = 0.6,
                MaxPitch = 0.7,
            })
        end
    end)

    for _, Target: Model in CombatUtils.GetFightersInRadius(Destination, 20, Char) do
        AbilityFX.ScreenFor(Target, "Rage", self.Warning + 0.5, 1)
    end

    ----------------------------------------------------------------------------
    -- ARRIVAL
    ----------------------------------------------------------------------------

    task.delay(self.Warning, function()
        if not Char or not Char.Parent then
            return
        end

        local Mine = Utils.Character.GetRootPart(Char)
        if not Mine then
            return
        end

        AbilityFX.Smoke(Mine.Position, FREDDY_DARK, 14, 4)
        CombatUtils.Blink(Char, Destination)
        AbilityFX.Smoke(Destination, FREDDY_DARK, 14, 4)
        AbilityFX.Ring(Destination, 14, FREDDY, {Duration = 0.5, Thickness = 1.2})
        AbilityFX.Sound(self.ArriveSound, Destination, {Volume = 1})
        AbilityFX.ShakeInRadius(Destination, 30, 3, 0.5)

        -- A hit on arrival for anyone who did not use the second they were given.
        for _, Target: Model in CombatUtils.GetFightersInRadius(Destination, self.ImpactRadius, Char) do
            local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
            if not Humanoid then
                continue
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.Damage,
                Reason = self.Name,
            })

            CombatUtils.ApplyEffectTo(Target, "Fragile", 2, 6)
            AbilityFX.ScreenFor(Target, "Flash", 0.4, 0.7)
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — DARKNESS
--------------------------------------------------------------------------------

--[=[
    In the dark he is a different character.

    While `InDarkness` is true: 18% faster, completely silent footsteps, and no chase music
    for anybody else. Step into the light and all three drop immediately.

    That inversion is the whole point of him being slow. His own `Power Outage` is the most
    reliable way to make it true, which ties his two abilities together without either of
    them referring to the other by name — they both just read the same condition.
]=]
local function DarknessInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        local Applied = false

        while Char and Char.Parent do
            task.wait(0.4)

            local Dark = InDarkness(self.Owner, Char)

            if Dark and not Applied then
                Applied = true
                PlayerSpeedManager.AddSpeedFactor(self.Owner, "Darkness", self.SpeedMultiplier)
                Char:SetAttribute("FootstepVolume", 0)

            elseif not Dark and Applied then
                Applied = false
                PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "Darkness")
                Char:SetAttribute("FootstepVolume", nil)
                CommonFunctions.RemoveEffect(Char, "Undetectable")
            end

            -- Re-applied while it holds: the effect has a duration, and topping it up is
            -- how a continuous passive is expressed in this engine.
            if Dark and not Utils.Instance.FindFirstChild(Char, "Effects.Undetectable", 0) then
                CombatUtils.ApplyEffectTo(Char, "Undetectable", 1, 3)
            end

            -- Glowing eyes in the dark, so the buff is visible to his victims as well.
            if Dark then
                local Root = Utils.Character.GetRootPart(Char)
                if Root then
                    AbilityFX.Tint(Char, Color3.fromRGB(255, 220, 120), 0.5, {FillTransparency = 0.92, Outline = Color3.fromRGB(255, 180, 60)})
                end
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Freddy: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Freddy Fazbear",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 17000,

        Role = "Stalker",
        Difficulty = 4,

        Origin = {
            TooltipText = "The show was cancelled. Nobody told him.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Heavy, mechanical, and silenced entirely by the passive in the dark.
            FootstepSounds = "rbxassetid://9046319808",
        },
    },

    GameplayConfig = {
        --[[
            Joint-slowest base speed, and the LOWEST sprint multiplier on the roster — he
            barely accelerates at all. He is a high-health character who cannot chase, and
            every ability he has exists to make chasing unnecessary.
        ]]
        Health = 1450,
        BaseSpeed = 10.4,
        SprintSpeedMultiplier = 22.5 / 10.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 13,
            StaminaGain = 17,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 32,
                --- +10 in the dark.
                DarkBonus = 10,
                Cooldown = 2.3,
                Duration = 0.4,
                Delay = 0.2,
                HitboxSize = Vector3.new(6, 7, 6),
                HitboxOffset = CFrame.new(0, 0, -3),

                ScareSound = "rbxassetid://9118823103",
                Behaviour = GrabBehaviour,
            }),

            Outage = Ability.New({
                Name = "Outage",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 30,
                Duration = 0.6,

                Radius = 55,
                Duration_ = 14,

                UseSound = "rbxassetid://9118823103",
                Behaviour = OutageBehaviour,
            }),

            Camera = Ability.New({
                Name = "Camera",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 14,
                Duration = 0.35,

                CameraHealth = 45,
                CameraLifetime = 45,
                WatchRadius = 30,
                RevealTime = 3,
                Limit = 2,

                UseSound = "rbxassetid://12222216",
                AlertSound = "rbxassetid://12222030",
                Behaviour = CameraBehaviour,
            }),

            Ambush = Ability.New({
                Name = "Ambush",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 32,
                Duration = 1.3,

                Warning = 1,
                WatchRadius = 30,
                ImpactRadius = 14,
                Damage = 45,

                LaughSound = "rbxassetid://9125402735",
                StepSound = "rbxassetid://9046319808",
                ArriveSound = "rbxassetid://9118823103",
                Behaviour = AmbushBehaviour,
            }),

            Darkness = Ability.New({
                Name = "Darkness",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                SpeedMultiplier = 1.18,
                ExtraInit = DarknessInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(150, 95, 50)\">"..Freddy.Config.Name.."</font>"
local Abilities = Freddy.GameplayConfig.Abilities

Freddy.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Freddy.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." is the slowest thing in the arena and barely accelerates when he sprints. He cannot chase anybody.",
            "What he does instead: plant a camera on a route, watch who uses it, kill the lights, and relocate onto them in the dark — where he is faster, hits harder, and makes no sound at all.",
            "Every piece of that is visible. The outage is announced and can be broken with one hit, the cameras are objects you can smash, and the relocation plays a laugh at the destination a full second before he arrives.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Freddy.Config.Role,
            "Difficulty: "..string.rep("★", Freddy.Config.Difficulty)..string.rep("☆", 5 - Freddy.Config.Difficulty),
            "Price: "..tostring(Freddy.Config.Price).."$",
            "Health: "..tostring(Freddy.GameplayConfig.Health),
            "Base Speed: "..tostring(Freddy.GameplayConfig.BaseSpeed).."  (joint lowest)",
            "Sprint Speed: "..tostring(math.round(Freddy.GameplayConfig.BaseSpeed * Freddy.GameplayConfig.SprintSpeedMultiplier * 10) / 10).."  (lowest)",
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "ANIMATRONIC GRAB"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds — "..tostring(Abilities.Slash.Damage + Abilities.Slash.DarkBonus).." in the dark.",
            "You can hear the servos wind up before it lands.",
        },
    },

    {Type = "Header", Text = "OUTAGE  (Q)"},
    {
        Type = "Text",
        Text = {
            "The lights go out across "..tostring(Abilities.Outage.Radius).." studs for "..tostring(Abilities.Outage.Duration_).." seconds.",
            "It dims your screen and nothing else — you can still see the map, the exits and the people in it. What it really does is turn his <b>Darkness</b> passive on.",
            "The marker in the middle has <b>5 health</b>. One hit turns the lights back on.",
            "Cooldown: "..tostring(Abilities.Outage.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "CAMERA  (E)"},
    {
        Type = "Text",
        Text = {
            "Mounts a camera. Anyone within "..tostring(Abilities.Camera.WatchRadius).." studs of it is revealed to him through walls for "..tostring(Abilities.Camera.RevealTime).." seconds.",
            "It clicks audibly when it sees somebody — so you know when you have been spotted.",
            tostring(Abilities.Camera.CameraHealth).." health, "..tostring(Abilities.Camera.CameraLifetime).." seconds, "..tostring(Abilities.Camera.Limit).." at a time.",
            "Cooldown: "..tostring(Abilities.Camera.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "AMBUSH  (R)"},
    {
        Type = "Text",
        Text = {
            "Relocates him to whichever of his cameras has the most people near it, and hits everybody within "..tostring(Abilities.Ambush.ImpactRadius).." studs for "..tostring(Abilities.Ambush.Damage).." damage.",
            "A laugh, approaching footsteps and a circle on the floor appear at the destination <b>"..tostring(Abilities.Ambush.Warning).." second before he does</b>.",
            "No camera, no ambush. His mobility is exactly as good as his planning was.",
            "Cooldown: "..tostring(Abilities.Ambush.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DARKNESS  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "In the dark — a night map, an unlit interior, or his own outage — he moves 18% faster, his footsteps go completely silent, and his chase music stops playing for everybody else.",
            "Step into the light and all three stop at once.",
        },
    },
}

return Freddy
