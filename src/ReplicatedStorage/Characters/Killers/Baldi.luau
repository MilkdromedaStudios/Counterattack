local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Network = require(ReplicatedStorage.Modules.Network)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local DeployableService = require(ReplicatedStorage.Modules.DeployableService)
local MeterService = require(ReplicatedStorage.Modules.MeterService)

local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    BALDI — HE GETS FASTER. THAT IS THE WHOLE THING.

      M1  RULER SLAP     A ruler. Loud, fast, and it hurts more than it has any right to.
      Q   MATH PROBLEM   Puts an actual arithmetic question on somebody's screen.
      E   DETENTION      Slams a locker door across a route and locks it.
      R   I'M COMING     Stops dead for a second, then comes for you much faster.
      P   ANGER          A meter that only ever goes up, and everything scales off it.

    THE ANGER METER IS THE CHARACTER
    --------------------------------
    It starts at zero and climbs on its own. It jumps when somebody gets a question wrong,
    when he lands a slap, and whenever anybody dies anywhere in the arena. It NEVER goes
    down.

    Anger drives his speed and his ruler damage, and — the part that sells him — the
    INTERVAL BETWEEN HIS FOOTSTEPS. At zero anger the slaps are slow and spaced. At full
    anger they are a rhythm you can hear from across the map getting closer. That audio is
    the character; it is also the counterplay, because it is a continuous readout of exactly
    how dangerous he currently is and exactly where he is.

    WHY THE SPEED IS CAPPED
    ----------------------
    At full anger he is at +32% base speed, which is fast but still inside sprint range for
    everybody else. An uncapped ramp would eventually make him unoutrunnable, which turns a
    chase into a countdown. The cap means a late-round Baldi is terrifying and still
    kiteable — you just cannot make a mistake.

    He has no ranged attack at all and nothing that closes a gap except running. If you keep
    a wall between you and him, he has no answer.
]=]

local BALDI = Color3.fromRGB(70, 200, 110)
local ANGER_METER = "Anger"

--------------------------------------------------------------------------------
-- ANGER
--------------------------------------------------------------------------------

--- 0 to 1.
local function AngerFraction(char: Model?): number
    return MeterService.Fraction(char, ANGER_METER)
end

--[=[
    Re-applies the speed that matches the current anger.

    Called whenever the meter moves, rather than on a timer, so there is exactly one place
    that decides how fast he is and no chance of two systems fighting over it.
]=]
local function ApplyAngerSpeed(player: Player, char: Model, maximumBonus: number)
    if not RunService:IsServer() or not char then
        return
    end

    PlayerSpeedManager.AddSpeedFactor(player, "Anger", 1 + AngerFraction(char) * maximumBonus)
end

--- Adds anger, clamped by the meter itself.
local function Anger(self: Types.Ability, amount: number)
    local Char = self.OwnerProperties and self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Add(Char, ANGER_METER, amount)
end

--------------------------------------------------------------------------------
-- M1 — RULER SLAP
--------------------------------------------------------------------------------

--[=[
    The ruler.

    Scales with anger — 26 damage at calm, 40 at full — and feeds the meter on every
    connection, so landing slaps makes the next ones land harder. It is the only damage he
    has, which is why it is the hardest-hitting basic attack on the roster at full anger.
]=]
local function RulerBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.2, Lock = 0.45})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Fraction = AngerFraction(Char)
    local Damage = self.Damage + self.DamagePerAnger * Fraction

    -- Pitch rises with anger. Small thing; it is most of why he reads as escalating.
    AbilityFX.SoundOn(Root, self.UseSound, {
        Volume = 0.95,
        MinPitch = 0.92 + Fraction * 0.25,
        MaxPitch = 1.04 + Fraction * 0.3,
    })

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = "Ruler",
            ExecuteOnKill = true,
            Knockback = 3,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    Anger(self, self.AngerOnHit)

                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, BALDI, 8, 14)
                        AbilityFX.ShakeFor(Victim, 1.4, 0.25)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — MATH PROBLEM
--------------------------------------------------------------------------------

--[=[
    Puts a sum on the nearest person's screen.

    See `StarterPlayerScripts.RemoteHandler.MathProblem` for the UI and the security model.
    The short version: the server generates the question and the three answers, keeps the
    correct INDEX, and the client can only reply with a number. It cannot answer a question
    it was not asked, answer twice, or claim to be right.

    WRONG, OR IGNORED
      * The victim is `Marked` for 8 seconds — visible to the whole arena.
      * Baldi gets a burst of anger.

    RIGHT
      * Nothing happens. That is the reward, and it is why the sums are single-digit: this is
        a two-second decision under pressure, not an exam.

    The question is cosmetically harsher at high anger (bigger numbers, a tighter timer) but
    never actually hard. Baldi being angry should feel worse, not be unfair.
]=]
local function MathProblemBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.12, Duration = 0.4, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Target = CombatUtils.GetClosestFighter(Root.Position, self.Range, Char)
    if not Target then
        -- Nobody to quiz. Refund rather than eat the cooldown for nothing.
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    local Victim = Players:GetPlayerFromCharacter(Target)
    if not Victim then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9})

    ----------------------------------------------------------------------------
    -- THE QUESTION
    ----------------------------------------------------------------------------

    local Fraction = AngerFraction(Char)
    -- Single digits when calm, up to 12 when furious. Still arithmetic a child can do.
    local Ceiling = 5 + math.floor(Fraction * 7)

    local Left = math.random(1, Ceiling)
    local Right = math.random(1, Ceiling)
    local Subtract = math.random() < 0.4

    -- Never phrase a subtraction that gives a negative answer.
    if Subtract and Right > Left then
        Left, Right = Right, Left
    end

    local Correct = Subtract and (Left - Right) or (Left + Right)
    local Question = ("%d %s %d = ?"):format(Left, Subtract and "-" or "+", Right)

    --[[
        Three answers: the right one and two near misses.

        Near misses rather than random numbers, so the question cannot be answered by
        eliminating the obviously silly options — it has to actually be worked out.
    ]]
    local Options = {Correct}
    while #Options < 3 do
        local Offset = math.random(1, 3) * (math.random() < 0.5 and -1 or 1)
        local Candidate = Correct + Offset

        if Candidate >= 0 and not table.find(Options, Candidate) then
            table.insert(Options, Candidate)
        end
    end

    -- Shuffle, then record where the right answer ended up.
    for Index = #Options, 2, -1 do
        local Swap = math.random(1, Index)
        Options[Index], Options[Swap] = Options[Swap], Options[Index]
    end

    local CorrectIndex = table.find(Options, Correct)

    local Choices = {}
    for _, Value in Options do
        table.insert(Choices, tostring(Value))
    end

    ----------------------------------------------------------------------------
    -- THE TOKEN
    ----------------------------------------------------------------------------

    --[[
        A one-shot token.

        The reply is matched on BOTH the token and the player, and the entry is removed the
        moment it resolves. So a stolen token is useless to anybody else, and a replayed one
        is useless to its owner.
    ]]
    local Pending = self.Pending
    local Token = tostring(os.clock())..":"..tostring(math.random(100000, 999999))

    Pending[Token] = {
        Player = Victim,
        Correct = CorrectIndex,
        ExpiresAt = os.clock() + self.AnswerTime + 2,
    }

    Network:FireClientConnection(Victim, "MathProblem", "REMOTE_EVENT", Token, Question, Choices, self.AnswerTime)

    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), Question, BALDI, 1.6)

    --[[
        A hard expiry on the server side as well as the client's timeout.

        The client is supposed to answer `nil` when its timer runs out, but a client that
        disconnects, crashes or is simply hostile will not — and an unanswered token that
        never expires is a slow leak in a table that lives as long as the round.
    ]]
    task.delay(self.AnswerTime + 2.5, function()
        local Entry = Pending[Token]
        if not Entry then
            return
        end
        Pending[Token] = nil

        -- Treated as wrong, same as an explicit timeout.
        self:Punish(Victim)
    end)
end

--[=[
    Sets up the answer listener.

    One connection per Baldi, filtered to its own owner's victims, torn down with the
    character by `AddConnection`. `OnServerEvent` supports multiple listeners, so two Baldis
    in one server each handle their own questions without interfering.
]=]
local function MathProblemInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    self.Pending = {}

    self:AddConnection(Network:SetConnection("MathProblemAnswer", "REMOTE_EVENT", function(player: Player, token: string, index: number?)
        if typeof(token) ~= "string" then
            return
        end

        local Entry = self.Pending[token]
        if not Entry then
            -- Not ours, already answered, or expired. All three are the same answer: no.
            return
        end

        -- The reply has to come from the player the question was sent to.
        if Entry.Player ~= player then
            warn("[Baldi] "..player.Name.." tried to answer a Math Problem that was asked of "..Entry.Player.Name..".")
            return
        end

        self.Pending[token] = nil

        if os.clock() > Entry.ExpiresAt then
            self:Punish(player)
            return
        end

        if index == Entry.Correct then
            self:Reward(player)
        else
            self:Punish(player)
        end
    end))
end

--------------------------------------------------------------------------------
-- E — DETENTION
--------------------------------------------------------------------------------

--[=[
    A locker door slammed across a route.

    A solid, destructible wall placed just in front of him and snapped to the floor. It does
    not trap anybody in a room — it closes ONE line, which is what makes it a chase tool
    rather than a cage: he uses it to take away the route you were about to use and force you
    onto a longer one.

    Counterplay is built into the object: 90 health, and any killer's basic attack breaks it
    because `DeployableService` shapes deployables so the normal hitbox can hurt them. Two
    swings and it is gone. It also times out on its own in 14 seconds.
]=]
local function DetentionBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.3, Lock = 0.5, Shake = 0.6, ShakeTime = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Ahead = Root.Position + Root.CFrame.LookVector * self.Distance
    local Ground = AbilityFX.GroundAt(Ahead, {Char})

    if not Ground then
        -- Nothing to stand it on — a ledge, or thin air. Refund.
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.95})

    local Door = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Detention",
        Name = "LockerDoor",
        -- Faces the way he was looking, so it blocks the line he was looking down.
        CFrame = CFrame.lookAt(Ground + Vector3.new(0, self.Height * 0.5, 0), Ground + Root.CFrame.LookVector),
        Size = Vector3.new(self.Width, self.Height, 0.8),
        Color = Color3.fromRGB(70, 130, 90),
        Material = Enum.Material.Metal,
        Solid = true,
        Health = self.DoorHealth,
        Lifetime = self.DoorLifetime,
        Limit = self.Limit,
        OutlineColor = BALDI,
        OnDestroyed = function(handle)
            AbilityFX.Sound("rbxassetid://9118823103", handle.Root.Position, {Volume = 0.8, MinPitch = 0.8, MaxPitch = 0.95})
        end,
    })

    if Door then
        AbilityFX.Ring(Ground, self.Width, BALDI, {Duration = 0.4})
        -- Slams up out of the floor rather than appearing.
        local Final = Door.Root.CFrame
        Door.Root.CFrame = Final * CFrame.new(0, -self.Height, 0)
        game:GetService("TweenService"):Create(
            Door.Root,
            TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {CFrame = Final}
        ):Play()
    end
end

--------------------------------------------------------------------------------
-- R — I'M COMING
--------------------------------------------------------------------------------

--[=[
    The windup, and then the sprint.

    He ROOTS HIMSELF for 1.2 seconds first. Everyone within 90 studs hears it and gets the
    `Rage` screen tint, so the entire arena knows it is happening and has over a second to do
    something about it. Then he gets 7 seconds at a very large speed bonus.

    The root is not a flourish, it is the cost. A 70% speed boost with no windup would be an
    unavoidable catch; a 70% speed boost that you can see coming from across the map and that
    starts from a dead stop is a threat you can answer by using the time.

    It also dumps anger to full, which permanently changes his footstep rhythm for the rest
    of the round — so using it is also a commitment to being heard.
]=]
local function ImComingBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.86, Duration = self.Windup, Lock = self.Windup, Shake = 1.4, ShakeTime = self.Windup})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 220})
    AbilityFX.Text(Root.Position + Vector3.new(0, 7, 0), "I'M COMING", Color3.fromRGB(255, 80, 60), self.Windup + 0.5)

    -- THE WARNING. Everybody nearby sees red for the length of the windup plus a moment.
    AbilityFX.ScreenInRadius(Root.Position, self.WarnRadius, "Rage", self.Windup + 1, 1.2, Char)

    ----------------------------------------------------------------------------
    -- ROOTED
    ----------------------------------------------------------------------------

    -- `Snared` rather than anchoring the part: it is an engine effect other systems already
    -- understand, it shows in his own effects list, and it leaves him able to swing — so
    -- standing next to him during the windup is still a bad idea.
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.Windup)

    -- A growing circle under him, filling for exactly the windup. The clearest possible
    -- "something happens when this finishes".
    AbilityFX.Telegraph(Root.Position, 12, Color3.fromRGB(255, 80, 60), self.Windup)

    task.delay(self.Windup, function()
        if not Char or not Char.Parent then
            return
        end

        local LiveRoot = Utils.Character.GetRootPart(Char)
        if not LiveRoot then
            return
        end

        AbilityFX.Ring(LiveRoot.Position, 20, Color3.fromRGB(255, 80, 60), {Duration = 0.5, Thickness = 1.4})

        -- Straight to maximum anger. Permanent, like everything else about the meter.
        MeterService.Set(Char, ANGER_METER, MeterService.GetMax(Char, ANGER_METER))

        PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

        -- Raw delay: the boost must come off even if he dies inside it.
        task.delay(self.Boost, function()
            PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        end)

        -- Dust kicked up for the whole sprint.
        task.spawn(function()
            local Elapsed = 0
            while Elapsed < self.Boost and Char and Char.Parent do
                Elapsed += task.wait(0.1)
                local Current = Utils.Character.GetRootPart(Char)
                if Current then
                    AbilityFX.Smoke(Current.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(190, 180, 150), 3, 2.2)
                end
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — ANGER
--------------------------------------------------------------------------------

--[=[
    The meter, the speed, and the footstep rhythm.

    THE RHYTHM IS THE POINT. One loop plays a ruler slap on an interval that shortens as
    anger rises: 1.1 seconds at calm, 0.3 at full. That is the sound the character is known
    for, and it doubles as the game's most honest threat indicator — everyone can hear
    exactly how angry he is and roughly where he is, continuously, for free.

    The slap only plays while he is actually MOVING, which is both correct (they are
    footsteps) and important (a stationary Baldi is not announcing himself, which is what
    makes ambushing possible).

    Anger also rises on its own, slowly, and on every death in the arena. It never falls.
]=]
local function AngerInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, ANGER_METER, {
        Max = 100,
        Start = 0,
        --- Rises on its own. Reaches full in a little over three minutes of doing nothing.
        RegenPerSecond = self.AngerPerSecond,
        DecayPerSecond = 0,
        OnChanged = function()
            ApplyAngerSpeed(self.Owner, Char, self.MaximumSpeedBonus)
        end,
    })

    ApplyAngerSpeed(self.Owner, Char, self.MaximumSpeedBonus)

    ----------------------------------------------------------------------------
    -- THE RULER RHYTHM
    ----------------------------------------------------------------------------

    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            local Fraction = AngerFraction(Char)
            -- 1.1s at calm down to 0.3s at full.
            local Interval = self.SlowStep - (self.SlowStep - self.FastStep) * Fraction

            task.wait(Interval)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            -- Only while moving. A standing Baldi is a silent Baldi.
            if Root.AssemblyLinearVelocity.Magnitude < 2 then
                continue
            end

            AbilityFX.Sound(self.StepSound, Root.Position, {
                Volume = 0.5 + Fraction * 0.45,
                RollOffMinDistance = 20,
                RollOffMaxDistance = 130 + Fraction * 70,
                MinPitch = 0.95 + Fraction * 0.2,
                MaxPitch = 1.05 + Fraction * 0.25,
            })
        end
    end))

    ----------------------------------------------------------------------------
    -- ANGER FROM THE ARENA
    ----------------------------------------------------------------------------

    --[=[
        Somebody died anywhere. He gets angrier.

        Watching `workspace.Players` for characters leaving is a cheap proxy for "a fighter
        is out" that needs no hook into the round manager — and it is correct either way,
        since a body leaving the fighters folder means that fighter is no longer in the
        round.
    ]=]
    self:AddConnection(workspace.Players.ChildRemoved:Connect(function(Removed: Instance)
        if Removed == Char then
            return
        end

        MeterService.Add(Char, ANGER_METER, self.AngerPerDeath)
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Baldi: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Baldi",
        Quote = "Oh, that's wrong! You know what that means...",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 24000,

        Role = "Chaser",
        Difficulty = 2,

        Origin = {
            TooltipText = "He only wanted to help with your homework.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- The ruler, as his footstep. His passive plays it on a rhythm too.
            FootstepSounds = "rbxassetid://12222216",
        },
    },

    GameplayConfig = {
        --[[
            Slowest base speed of any chaser, and the only one who grows out of it. He
            starts worse than everybody at the thing he is for, and ends better.
        ]]
        Health = 1400,
        BaseSpeed = 10.2,
        SprintSpeedMultiplier = 25 / 10.2,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 130,
            StaminaDrain = 9,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                --- 26 at calm, 40 at full anger. The hardest basic attack in the game, late.
                Damage = 26,
                DamagePerAnger = 14,
                Cooldown = 1.4,
                Duration = 0.28,
                Delay = 0.08,
                HitboxSize = Vector3.new(5, 6, 5.5),
                HitboxOffset = CFrame.new(0, 0, -2.8),

                AngerOnHit = 6,

                Behaviour = RulerBehaviour,
            }),

            MathProblem = Ability.New({
                Name = "Math Problem",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 18,
                Duration = 0.5,

                Range = 80,
                AnswerTime = 5,
                WrongMarkTime = 8,
                AngerOnWrong = 25,

                UseSound = "rbxassetid://9125402735",
                Behaviour = MathProblemBehaviour,
                ExtraInit = MathProblemInit,

                --[=[
                    Called when somebody gets it wrong, or ignores it.

                    Marked, not damaged. Baldi has no ranged attack, so what he wants from a
                    question is to know where you are — and `Marked` is public, so getting it
                    wrong in a free-for-all also paints you for everybody ELSE in the arena.
                    That is a real cost without being a hit he did not earn.
                ]=]
                Punish = function(self: Types.Ability, player: Player)
                    if not RunService:IsServer() then
                        return
                    end

                    local Target = player and player.Character
                    if not Target then
                        return
                    end

                    CombatUtils.ApplyEffectTo(Target, "Marked", 1, self.WrongMarkTime)

                    local Root = Utils.Character.GetRootPart(Target)
                    if Root then
                        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "WRONG", Color3.fromRGB(255, 70, 70), 1.3)
                        AbilityFX.Burst(Root.Position, 6, Color3.fromRGB(255, 70, 70), {Duration = 0.35})
                        AbilityFX.ScreenFor(Target, "Rage", 1.2, 0.9)
                    end

                    local Char = self.OwnerProperties and self.OwnerProperties.Character
                    if Char then
                        MeterService.Add(Char, ANGER_METER, self.AngerOnWrong)
                    end
                end,

                --- Called when somebody gets it right. Nothing happens, which IS the reward.
                Reward = function(_self: Types.Ability, player: Player)
                    if not RunService:IsServer() then
                        return
                    end

                    local Target = player and player.Character
                    local Root = Target and Utils.Character.GetRootPart(Target)
                    if Root then
                        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "CORRECT", BALDI, 1.1)
                    end
                end,
            }),

            Detention = Ability.New({
                Name = "Detention",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 20,
                Duration = 0.4,

                Distance = 10,
                Width = 16,
                Height = 11,
                DoorHealth = 90,
                DoorLifetime = 14,
                Limit = 2,

                UseSound = "rbxassetid://9046319808",
                Behaviour = DetentionBehaviour,
            }),

            ImComing = Ability.New({
                Name = "I'm Coming",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 55,
                --- The whole windup, so nothing else can be used during it.
                Duration = 1.2,

                Windup = 1.2,
                Boost = 7,
                SpeedMultiplier = 1.7,
                WarnRadius = 90,

                UseSound = "rbxassetid://9118823103",
                Behaviour = ImComingBehaviour,
            }),

            Anger = Ability.New({
                Name = "Anger",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Full in a little over three minutes of doing nothing at all.
                AngerPerSecond = 0.5,
                AngerPerDeath = 12,
                --- At full anger he is 32% faster. Capped deliberately — see the header.
                MaximumSpeedBonus = 0.32,

                SlowStep = 1.1,
                FastStep = 0.3,
                StepSound = "rbxassetid://12222216",

                ExtraInit = AngerInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(70, 200, 110)\">"..Baldi.Config.Name.."</font>"
local Abilities = Baldi.GameplayConfig.Abilities

Baldi.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Baldi.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Baldi.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." starts as the slowest chaser in the arena and ends as one of the fastest. <b>Anger</b> only ever goes up.",
            "It climbs on its own, it jumps when somebody gets a question wrong, and it jumps whenever anybody in the round dies. Everything he has scales off it — his speed, his ruler, and how often you hear him.",
            "He has no ranged attack and nothing that closes a gap except running. Put a wall between you and him and he has no answer at all.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Baldi.Config.Role,
            "Difficulty: "..string.rep("★", Baldi.Config.Difficulty)..string.rep("☆", 5 - Baldi.Config.Difficulty),
            "Price: "..tostring(Baldi.Config.Price).."$",
            "Health: "..tostring(Baldi.GameplayConfig.Health),
            "Base Speed: "..tostring(Baldi.GameplayConfig.BaseSpeed).."  (rising to "..tostring(math.round(Baldi.GameplayConfig.BaseSpeed * (1 + Abilities.Anger.MaximumSpeedBonus) * 10) / 10)..")",
            "Sprint Speed: "..tostring(math.round(Baldi.GameplayConfig.BaseSpeed * Baldi.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "RULER SLAP"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage at calm, rising to "..tostring(Abilities.Slash.Damage + Abilities.Slash.DamagePerAnger).." at full anger. Every "..tostring(Abilities.Slash.Cooldown).." seconds.",
            "Landing it makes him angrier, which makes the next one hurt more.",
        },
    },

    {Type = "Header", Text = "MATH PROBLEM  (Q)"},
    {
        Type = "Text",
        Text = {
            "Puts an arithmetic question on the nearest fighter's screen for "..tostring(Abilities.MathProblem.AnswerTime).." seconds.",
            "Get it right and nothing happens. Get it wrong — or ignore it — and you are <b>Marked</b> for the whole arena to see for "..tostring(Abilities.MathProblem.WrongMarkTime).." seconds, and he gets a large burst of anger.",
            "The sums are easy. The timer is the hard part.",
            "Cooldown: "..tostring(Abilities.MathProblem.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DETENTION  (E)"},
    {
        Type = "Text",
        Text = {
            "Slams a locker door across the route in front of him. "..tostring(Abilities.Detention.DoorHealth).." health, gone after "..tostring(Abilities.Detention.DoorLifetime).." seconds, two out at once.",
            "It closes one line, not a room. Any basic attack breaks it in a couple of swings.",
            "Cooldown: "..tostring(Abilities.Detention.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "I'M COMING  (R)"},
    {
        Type = "Text",
        Text = {
            "He stops dead for "..tostring(Abilities.ImComing.Windup).." seconds — rooted, shouting, and everybody within "..tostring(Abilities.ImComing.WarnRadius).." studs sees red — then moves "..tostring(math.round((Abilities.ImComing.SpeedMultiplier - 1) * 100)).."% faster for "..tostring(Abilities.ImComing.Boost).." seconds.",
            "It also takes his anger straight to maximum, permanently.",
            "You get well over a second of warning. Use it.",
            "Cooldown: "..tostring(Abilities.ImComing.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "ANGER  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "A meter that rises and never falls. It drives his speed, his ruler damage, and the <b>rhythm of his footsteps</b>.",
            "At calm the slaps are slow and spaced. At full anger they are a drumbeat you can hear from the other side of the map.",
            "He is only silent when he is standing still.",
        },
    },
}

return Baldi
