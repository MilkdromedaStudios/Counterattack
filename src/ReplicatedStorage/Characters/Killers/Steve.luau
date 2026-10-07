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
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    STEVE — BUILD, SHOOT, MINE, EAT.

      M1  TOOL SWING   Sword, axe or pickaxe. Chosen automatically by what he is hitting.
      Q   BLOCK PLACE  A block. Eight at a time. Walls, stairs, cover, chase redirection.
      E   BOW          Draw and release. Longer draw means faster, harder, further.
      R   MINE         Breaks structures fast. His own blocks come straight back.
      F   EAT          A long cooldown and a modest heal. He has to stand still for it.
      P   CRAFTING     The tool picks itself. No menu, no UI, no keybind.

    CRAFTING WITHOUT A CRAFTING SCREEN
    ----------------------------------
    The brief was firm: he alternates between predefined tools, and there must be no giant
    crafting interface. So the TOOL IS CHOSEN BY WHAT IS IN FRONT OF HIM, re-evaluated on
    every swing:

      PICKAXE  There is a structure in reach   -> huge structure damage, low player damage.
      AXE      Two or more fighters in reach   -> wider arc, hits everybody, knockback.
      SWORD    Anything else                   -> the best single-target damage.

    No keybind, no menu, and the choice is visible — the tool's name floats over his head as
    he swings, so both players can see which one he got. It also means his basic attack
    genuinely changes character between a duel, a scrum and a siege, which is the thing a
    tool-switching mechanic is for.

    HE IS THE SECOND ANSWER TO BUILDERS
    -----------------------------------
    Knuckles breaks structures with one enormous punch. Steve breaks them with `Mine`, which
    is faster, repeatable, and gives him his OWN blocks back — so he is the character who can
    fight a prepared position by dismantling it and rebuilding it facing the other way.

    WEAKNESSES
    ----------
    No mobility whatsoever — he has no dash, no teleport and no flight, and `Block Place` is
    the closest thing he has to repositioning. The bow roots him while drawn. `Eat` roots him
    completely. Everything he does is slow and deliberate, and he loses any fight that is
    purely about speed.
]=]

local DIAMOND = Color3.fromRGB(90, 220, 215)
local WOOD = Color3.fromRGB(150, 110, 60)
local STONE = Color3.fromRGB(130, 130, 130)
local GRASS = Color3.fromRGB(110, 170, 80)

--------------------------------------------------------------------------------
-- M1 — TOOL SWING
--------------------------------------------------------------------------------

--[=[
    Picks a tool and swings it.

    The decision is made fresh on every swing from the live state of the world, which is why
    there is no stored "current tool" anywhere: there is nothing to desync, nothing to
    replicate, and no way for the player's idea of their tool to differ from the server's.
]=]
local function ToolBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.3, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- WHICH TOOL
    ----------------------------------------------------------------------------

    local Ahead = Root.Position + Root.CFrame.LookVector * 4
    local Structures = DeployableService.GetInRadius(Ahead, self.Reach, nil)
    local Fighters = CombatUtils.GetFightersInRadius(Ahead, self.Reach, Char)

    local Tool, Colour

    if #Structures > 0 then
        Tool, Colour = "Pickaxe", STONE
    elseif #Fighters >= 2 then
        Tool, Colour = "Axe", WOOD
    else
        Tool, Colour = "Sword", DIAMOND
    end

    local Damage = self[Tool.."Damage"]
    local Wide = Tool == "Axe"

    AbilityFX.SoundOn(Root, self.UseSound, {
        Volume = 0.65,
        MinPitch = Tool == "Pickaxe" and 0.8 or 1.0,
        MaxPitch = Tool == "Pickaxe" and 0.9 or 1.15,
    })

    -- Public, so both players can see which tool he got.
    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), Tool, Colour, 0.7)

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A blocky arc in the tool's colour.
        local Centre = Root.Position + Root.CFrame.LookVector * 3.5 + Vector3.new(0, 1, 0)
        AbilityFX.Beam(
            Centre - Root.CFrame.RightVector * (Wide and 4.5 or 2.5),
            Centre + Root.CFrame.RightVector * (Wide and 4.5 or 2.5),
            Colour,
            {Width = 0.8, Duration = 0.2, Transparency = 0.2, Material = Enum.Material.SmoothPlastic}
        )

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = Wide and self.AxeHitbox or self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = Tool,
            ExecuteOnKill = true,
            Knockback = Wide and self.AxeKnockback or 3,
            HitMultiple = Wide,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, Colour, 8, 14)
                    end
                end,
            },
        })

        -- The pickaxe's real job.
        if Tool == "Pickaxe" then
            local Broken = DeployableService.DamageInRadius(Ahead, self.Reach, self.PickaxeStructureDamage, self.Owner)
            if Broken > 0 then
                AbilityFX.Sparks(Ahead, STONE, 14, 20)
                AbilityFX.Sound("rbxassetid://12222216", Ahead, {Volume = 0.6, MinPitch = 0.85, MaxPitch = 1})
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Q — BLOCK PLACE
--------------------------------------------------------------------------------

--[=[
    A block, where he is looking.

    It goes at ground level in front of him, UNLESS there is already a block there — in which
    case it stacks on top of it. That one rule is what makes stairs possible: place, step up,
    place again, and he climbs. It is the closest thing he has to mobility and it is entirely
    manual.

    Eight at a time. `DeployableService` removes his oldest to make room, which is both
    visible and the behaviour every build-limit in every game has.
]=]
local function BlockBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.2, Lock = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Spot = Root.Position + Root.CFrame.LookVector * self.Distance

    ----------------------------------------------------------------------------
    -- STACK OR GROUND
    ----------------------------------------------------------------------------

    local Position = nil

    --[[
        Already a block of his there? Stack on it.

        Checked against his OWN blocks only. Stacking on somebody else's wall would let him
        climb their structure, which is their wall doing work for him.
    ]]
    local Highest = nil
    for _, Handle in DeployableService.GetFor(self.Owner, "Block") do
        if not Handle.Alive or not Handle.Root then
            continue
        end

        local Flat = (Vector3.new(Handle.Root.Position.X, 0, Handle.Root.Position.Z) - Vector3.new(Spot.X, 0, Spot.Z)).Magnitude
        if Flat <= self.Size * 0.75 then
            if not Highest or Handle.Root.Position.Y > Highest.Root.Position.Y then
                Highest = Handle
            end
        end
    end

    if Highest then
        Position = Highest.Root.Position + Vector3.new(0, self.Size, 0)
    else
        local Ground = AbilityFX.GroundAt(Spot, {Char})
        if not Ground then
            self.OnCooldown = false
            self.CooldownTimer = 0
            return
        end
        Position = Ground + Vector3.new(0, self.Size * 0.5, 0)
    end

    ----------------------------------------------------------------------------
    -- PLACE IT
    ----------------------------------------------------------------------------

    AbilityFX.Sound(self.UseSound, Position, {Volume = 0.6, MinPitch = 0.9, MaxPitch = 1.1})

    local Block = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Block",
        Name = "Block",
        CFrame = CFrame.new(Position),
        Size = Vector3.one * self.Size,
        -- Cycles through the Minecraft palette so a stack of them looks built rather than
        -- cloned.
        Color = ({GRASS, WOOD, STONE})[math.random(1, 3)],
        Material = Enum.Material.WoodPlanks,
        Solid = true,
        Health = self.BlockHealth,
        Lifetime = self.BlockLifetime,
        Limit = self.Limit,
        OutlineColor = GRASS,
    })

    if Block then
        -- Snaps in, like a placed block should.
        local Final = Block.Root.Size
        Block.Root.Size = Final * 0.5
        TweenService:Create(
            Block.Root,
            TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = Final}
        ):Play()

        AbilityFX.Smoke(Position, Color3.fromRGB(200, 190, 170), 5, 1.5)
    end
end

--------------------------------------------------------------------------------
-- E — BOW
--------------------------------------------------------------------------------

--[=[
    Draw, then release. Longer draw is better.

    THE TOGGLE IS HOW A HOLD-TO-CHARGE ABILITY IS BUILT HERE. The input system delivers
    discrete presses, so: the first press starts the draw, and either a second press fires
    early at partial power or the full draw fires on its own. That gives the real mechanic —
    an arrow's speed, damage and range all scale with how long it was drawn — without needing
    a hold input the engine does not provide.

    He is rooted to a crawl while drawing, which is the cost, and the bowstring is visibly
    pulled further the longer he holds it.
]=]
local function BowBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Zoom(self, 0.8)
        self:AddConnection(task.delay(self.FullDraw + 0.2, function()
            AbilityClient.ReleaseZoom(self)
        end))
        AbilityClient.LockHead(self, self.FullDraw)
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    ----------------------------------------------------------------------------
    -- RELEASE EARLY
    ----------------------------------------------------------------------------

    if Cache.DrawStartedAt then
        local Held = os.clock() - Cache.DrawStartedAt
        Cache.DrawStartedAt = nil
        self:Fire(math.clamp(Held / self.FullDraw, self.MinimumDraw, 1))
        return
    end

    ----------------------------------------------------------------------------
    -- START DRAWING
    ----------------------------------------------------------------------------

    Cache.DrawStartedAt = os.clock()

    AbilityFX.Sound(self.DrawSound, Root.Position, {Volume = 0.6, MinPitch = 1.0, MaxPitch = 1.1})
    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.DrawSpeedMultiplier)

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.FullDraw do
            Elapsed += task.wait(0.08)

            -- Released early, or he died, or the round ended.
            if not Cache.DrawStartedAt or not Char or not Char.Parent then
                PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
                return
            end

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            -- Interrupted: the draw is lost.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                Cache.DrawStartedAt = nil
                PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "lost the draw", WOOD, 1)
                return
            end

            -- The string pulling back: a line that lengthens as the draw deepens.
            local Progress = Elapsed / self.FullDraw
            local From = Live.Position + Vector3.new(0, 1.2, 0)
            AbilityFX.Beam(From, From + Live.CFrame.LookVector * (6 + Progress * 26), DIAMOND, {
                Width = 0.15 + Progress * 0.25,
                Duration = 0.1,
                Transparency = 0.7 - Progress * 0.35,
            })
        end

        -- Full draw fires on its own.
        if Cache.DrawStartedAt then
            Cache.DrawStartedAt = nil
            PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
            self:Fire(1)
        end
    end)
end

--------------------------------------------------------------------------------
-- R — MINE
--------------------------------------------------------------------------------

--[=[
    Breaks structures quickly, and recovers his own.

    Three things in one press, which is what makes it his siege tool rather than a worse
    Charged Punch:
      * Heavy structure damage in a radius — enough to clear a sentry and a wall together.
      * HIS OWN BLOCKS ARE RECOVERED rather than destroyed, which frees their slots so he
        can immediately rebuild somewhere better. Dismantle and re-place is the play.
      * A small heal per block recovered, so mining his own cover is a genuine resource.
]=]
local function MineBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.06, Duration = 0.5, Lock = 0.6, Shake = 1.5, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Root.CFrame.LookVector * 5

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.9})
    AbilityFX.Ring(Origin, self.Radius, STONE, {Duration = 0.5, Thickness = 1})
    AbilityFX.ShakeInRadius(Origin, self.Radius * 1.5, 2.5, 0.4)

    ----------------------------------------------------------------------------
    -- HIS OWN BLOCKS COME BACK
    ----------------------------------------------------------------------------

    local Recovered = 0

    for _, Handle in DeployableService.GetFor(self.Owner, "Block") do
        if not Handle.Alive or not Handle.Root then
            continue
        end

        if (Handle.Root.Position - Origin).Magnitude <= self.Radius then
            AbilityFX.Smoke(Handle.Root.Position, Color3.fromRGB(200, 190, 170), 6, 1.5)
            AbilityFX.Sparks(Handle.Root.Position, GRASS, 6, 12)
            Handle:Destroy()
            Recovered += 1
        end
    end

    ----------------------------------------------------------------------------
    -- EVERYBODY ELSE'S DO NOT
    ----------------------------------------------------------------------------

    local Broken = DeployableService.DamageInRadius(Origin, self.Radius, self.StructureDamage, self.Owner)

    AbilityFX.Sparks(Origin, STONE, 20, 26)

    ----------------------------------------------------------------------------
    -- THE PAYOFF
    ----------------------------------------------------------------------------

    if Recovered > 0 then
        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if Humanoid then
            Humanoid.Health = math.min(Humanoid.Health + self.HealPerBlock * Recovered, Humanoid.MaxHealth)
        end

        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "+"..tostring(Recovered).." blocks", GRASS, 1.2)
    elseif Broken <= 0 then
        -- Nothing to mine at all. Refund.
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nothing to mine", STONE, 0.9)
    end
end

--------------------------------------------------------------------------------
-- F — EAT
--------------------------------------------------------------------------------

--[=[
    He stops and eats.

    Rooted and disarmed for the whole duration, with an audible chewing loop and a visible
    progress ring. If he is hit at all, the meal is interrupted and he gets NOTHING — so
    eating is a decision about whether you are actually safe, which is exactly what it is in
    the game it comes from.
]=]
local function EatBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.95, Duration = self.Duration_, Lock = self.Duration_})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Humanoid = self.OwnerProperties.Humanoid

    if not Humanoid then
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7, MinPitch = 0.9, MaxPitch = 1.1})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "eating", GRASS, self.Duration_)

    -- Rooted and disarmed. No attacking while your hands are full.
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.Duration_)
    Char:SetAttribute("PreventSlash", true)

    local StartHealth = Humanoid.Health

    task.spawn(function()
        local Elapsed = 0
        local Interrupted = false

        while Elapsed < self.Duration_ do
            Elapsed += task.wait(0.15)

            if not Char or not Char.Parent or Humanoid.Health <= 0 then
                Interrupted = true
                break
            end

            --[[
                ANY damage interrupts it.

                Compared against the health he started with rather than watched through
                `OnDamage`, so it catches damage-over-time, zones and chip damage as well as
                hits — anything that actually hurt him while he was eating.
            ]]
            if Humanoid.Health < StartHealth - 0.01 then
                Interrupted = true
                break
            end

            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Sparks(Live.Position + Vector3.new(0, 1.5, 0), GRASS, 3, 5)
            end
        end

        -- Restored on every path out, including death: `PreventSlash` surviving onto his
        -- next body would be a Steve who can never attack.
        if Char then
            Char:SetAttribute("PreventSlash", nil)
        end

        local Live = Char and Utils.Character.GetRootPart(Char)

        if Interrupted then
            if Live then
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "interrupted", WOOD, 1.1)
            end
            return
        end

        Humanoid.Health = math.min(Humanoid.Health + self.Heal, Humanoid.MaxHealth)

        if Live then
            AbilityFX.Burst(Live.Position, 6, GRASS, {Duration = 0.4})
            AbilityFX.Text(Live.Position + Vector3.new(0, 5.5, 0), "+"..tostring(self.Heal), GRASS, 1.3)
        end
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Steve: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Steve",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 8200,

        Role = "Trapper",
        Difficulty = 4,

        Origin = {
            TooltipText = "He has been digging for a very long time.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Solid health, average speed, and NO mobility ability at all. Everything he does
            is slow and deliberate; he loses any fight that is purely about speed.
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

                Cooldown = 1.8,
                Duration = 0.3,
                Delay = 0.12,
                Reach = 7,

                --- Best single target.
                SwordDamage = 31,
                --- Wide, multi-target, heavy knockback, less damage each.
                AxeDamage = 22,
                AxeKnockback = 10,
                AxeHitbox = Vector3.new(10, 6, 6),
                --- Poor against people, enormous against structures.
                PickaxeDamage = 14,
                PickaxeStructureDamage = 70,

                HitboxSize = Vector3.new(5.5, 6, 6),
                HitboxOffset = CFrame.new(0, 0, -3),

                Behaviour = ToolBehaviour,
            }),

            Block = Ability.New({
                Name = "Block",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                --- Short, because placing one block is a small action.
                Cooldown = 2.5,
                Duration = 0.2,

                Size = 6,
                Distance = 8,
                BlockHealth = 85,
                BlockLifetime = 30,
                Limit = 8,

                UseSound = "rbxassetid://12222216",
                Behaviour = BlockBehaviour,
            }),

            Bow = Ability.New({
                Name = "Bow",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 7,
                Duration = 0.3,

                FullDraw = 1.2,
                --- Firing immediately still does something, just not much.
                MinimumDraw = 0.3,
                DrawSpeedMultiplier = 0.55,

                --- All three scale with draw.
                MinimumDamage = 18,
                MaximumDamage = 78,
                MinimumSpeed = 70,
                MaximumSpeed = 210,
                MinimumRange = 60,
                MaximumRange = 190,

                DrawSound = "rbxassetid://12222216",
                FireSound = "rbxassetid://12222030",
                Behaviour = BowBehaviour,

                --[=[
                    Looses the arrow at `draw` of full power.

                    A method on the ability rather than a local function, because the draw
                    loop and the early-release branch both need it and both live inside
                    `BowBehaviour` — a local would have had to be declared above it and
                    forward-referenced.
                ]=]
                Fire = function(self: Types.Ability, draw: number)
                    if not RunService:IsServer() then
                        return
                    end

                    local Char = self.OwnerProperties.Character
                    local Root = Char and Utils.Character.GetRootPart(Char)
                    if not Root then
                        return
                    end

                    PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)

                    local Damage = self.MinimumDamage + (self.MaximumDamage - self.MinimumDamage) * draw
                    local Speed = self.MinimumSpeed + (self.MaximumSpeed - self.MinimumSpeed) * draw
                    local Range = self.MinimumRange + (self.MaximumRange - self.MinimumRange) * draw

                    AbilityFX.Sound(self.FireSound, Root.Position, {
                        Volume = 0.5 + draw * 0.45,
                        MinPitch = 1.0 + draw * 0.2,
                        MaxPitch = 1.1 + draw * 0.25,
                    })

                    ProjectileService.Fire({
                        SourcePlayer = self.Owner,
                        Name = "Arrow",
                        Origin = Root.Position + Root.CFrame.LookVector * 2.5 + Vector3.new(0, 1.2, 0),
                        Direction = Root.CFrame.LookVector,
                        Speed = Speed,
                        --[[
                            Gravity scales DOWN with draw. A fully drawn arrow flies nearly
                            flat and a weak one lobs, which is the correct behaviour and
                            also the clearest possible visual read on how charged it was.
                        ]]
                        Gravity = 60 * (1 - draw * 0.8),
                        Lifetime = Range / Speed,
                        Radius = 1.8,
                        Damage = Damage,
                        Reason = "Arrow",
                        FaceTravel = true,
                        Visual = {
                            Shape = Enum.PartType.Block,
                            Size = Vector3.new(0.3, 0.3, 4),
                            Color = WOOD,
                            Material = Enum.Material.Wood,
                            Trail = draw > 0.6,
                            TrailColor = DIAMOND,
                        },
                        OnHit = function(_projectile, humanoid: Humanoid)
                            local Victim = humanoid.Parent
                            local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                            if VictimRoot then
                                AbilityFX.Sparks(VictimRoot.Position, DIAMOND, 10, 18)
                                AbilityFX.ShakeFor(Victim, 1 + draw * 2.5, 0.3)
                            end
                            return nil
                        end,
                    })
                end,
            }),

            Mine = Ability.New({
                Name = "Mine",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 15,
                Duration = 0.6,

                Radius = 16,
                StructureDamage = 85,
                HealPerBlock = 25,

                UseSound = "rbxassetid://9046319808",
                Behaviour = MineBehaviour,
            }),

            Eat = Ability.New({
                Name = "Eat",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 48,
                Duration = 2.2,

                Duration_ = 2.2,
                Heal = 260,

                UseSound = "rbxassetid://12222216",
                Behaviour = EatBehaviour,
            }),

            Crafting = Ability.New({
                Name = "Crafting",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(90, 220, 215)\">"..Steve.Config.Name.."</font>"
local Abilities = Steve.GameplayConfig.Abilities

Steve.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Steve.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." has <b>no mobility ability at all</b> — no dash, no teleport, no flight. Everything he does is slow and deliberate.",
            "What he has is eight blocks, a bow that rewards patience, and the ability to take somebody's fortification apart and rebuild it facing the other way.",
            "His tool picks itself based on what is in front of him. There is no crafting menu.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Steve.Config.Role,
            "Difficulty: "..string.rep("★", Steve.Config.Difficulty)..string.rep("☆", 5 - Steve.Config.Difficulty),
            "Price: "..tostring(Steve.Config.Price).."$",
            "Health: "..tostring(Steve.GameplayConfig.Health),
            "Base Speed: "..tostring(Steve.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Steve.GameplayConfig.BaseSpeed * Steve.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "TOOL SWING"},
    {
        Type = "Text",
        Text = {
            "Every "..tostring(Abilities.Slash.Cooldown).." seconds, and the tool is chosen for him:",
            "<b>Pickaxe</b> — a structure in reach. "..tostring(Abilities.Slash.PickaxeDamage).." to people, <b>"..tostring(Abilities.Slash.PickaxeStructureDamage).." to structures</b>.",
            "<b>Axe</b> — two or more fighters in reach. "..tostring(Abilities.Slash.AxeDamage).." damage in a wide arc that hits everybody, with heavy knockback.",
            "<b>Sword</b> — anything else. "..tostring(Abilities.Slash.SwordDamage).." damage, single target.",
            "The tool's name floats over his head as he swings. You always know which one he got.",
        },
    },

    {Type = "Header", Text = "BLOCK  (Q)"},
    {
        Type = "Text",
        Text = {
            "Places a "..tostring(Abilities.Block.Size).." stud block in front of him. "..tostring(Abilities.Block.BlockHealth).." health, "..tostring(Abilities.Block.BlockLifetime).." seconds, "..tostring(Abilities.Block.Limit).." at a time.",
            "<b>It stacks on his own blocks</b>, so place-step-place builds stairs. It is the closest thing he has to mobility.",
            "Cooldown: "..tostring(Abilities.Block.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "BOW  (E)"},
    {
        Type = "Text",
        Text = {
            "Press to draw, press again to release early, or hold for "..tostring(Abilities.Bow.FullDraw).." seconds and it fires itself.",
            "A snap shot does "..tostring(Abilities.Bow.MinimumDamage).." damage and lobs. A full draw does <b>"..tostring(Abilities.Bow.MaximumDamage).."</b>, flies nearly flat, and reaches "..tostring(Abilities.Bow.MaximumRange).." studs.",
            "He moves at 55% speed while drawing, and <b>being stunned loses the draw entirely</b>.",
            "Cooldown: "..tostring(Abilities.Bow.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "MINE  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Mine.StructureDamage).." damage to every structure within "..tostring(Abilities.Mine.Radius).." studs.",
            "<b>His own blocks are recovered instead of broken</b>, freeing their slots — and each one heals him "..tostring(Abilities.Mine.HealPerBlock)..". Dismantle and re-place is the play.",
            "Cooldown: "..tostring(Abilities.Mine.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "EAT  (F)"},
    {
        Type = "Text",
        Text = {
            "Heals "..tostring(Abilities.Eat.Heal).." over "..tostring(Abilities.Eat.Duration_).." seconds. He is <b>rooted and disarmed</b> for all of it.",
            "<b>Any damage at all interrupts it and he gets nothing.</b>",
            "Cooldown: "..tostring(Abilities.Eat.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "CRAFTING  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "The tool is chosen fresh on every swing from what is actually in front of him. No menu, no keybind, nothing to remember.",
            "It means his basic attack genuinely changes character between a duel, a scrum and a siege.",
        },
    },
}

return Steve
