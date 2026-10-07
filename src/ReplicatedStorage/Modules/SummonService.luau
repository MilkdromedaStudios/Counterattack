--[=[
    SUMMON SERVICE

    Temporary minions: 1x1x1x1's corrupted players, Guest's ghostly Guests, Gubby's swarm.

    WHAT A MINION IS
    ---------------
    A real R6 rig from `PlaceholderRig`, recoloured and rescaled, with a `Humanoid` that
    walks. Using the project's own placeholder rig rather than a bespoke two-brick figure
    is both cheaper to maintain and better looking: 1x1x1x1's minions are supposed to be
    corrupted Roblox players, and a classic noob IS that, exactly.

    They are shaped like deployables — `Role` of `"Summon"`, `HitboxPriority` on the root,
    `ExecutionsDisabled` — so every killer's normal attack can kill them with no special
    cases anywhere, which is the counterplay: minions die to one or two hits.

    Damage they DEAL goes through `Classes.Hitbox` credited to the SUMMONER, so a minion
    kill is the summoner's kill, lands in the kill feed under their name, and is subject to
    the same resistance, Fragile and escalation maths as everything else. There is no
    second damage path in the game.

    THE AI, AND WHY IT IS DELIBERATELY STUPID
    ----------------------------------------
    One shared think loop at 4 Hz for every minion in the server, no `PathfindingService`,
    no per-frame work: pick the nearest fighter inside the seek radius, `MoveTo` them, swing
    when close enough. That is the whole brain.

    Pathfinding a dozen minions would cost more than every other ability on the roster put
    together, and it would make them better at chasing than most of the killers. Minions
    that walk into walls are a FEATURE — they apply pressure, they don't win fights.

    BUDGET
    ------
    Hard caps per player and overall. The think loop is one connection shared by every
    minion and it disconnects itself the moment the last one dies.
]=]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local PlaceholderRig = require(ReplicatedStorage.Modules.PlaceholderRig)
local Utils = require(ReplicatedStorage.Modules.Utils)

local SummonService = {
    --- Minions one player may have alive at once, across all their abilities.
    MaxPerPlayer = 6,
    --- Minions alive in the server at once.
    MaxTotal = 30,
    --- How often the shared brain runs. Four times a second is plenty for "walk at them".
    ThinkRate = 0.25,
}

local Live: {any} = {}
local CountByPlayer: {[Player]: number} = {}
local ThinkThread: thread? = nil

Players.PlayerRemoving:Connect(function(player: Player)
    SummonService.ClearFor(player)
end)

--------------------------------------------------------------------------------
-- THE RIG
--------------------------------------------------------------------------------

--[=[
    Turns a placeholder noob into a minion.

    Recolours every limb, scales the whole rig, strips the "no model yet" name tag (which
    is for developers, not for something that is deliberately a minion), and bolts on the
    attributes the hitbox needs.
]=]
local function BuildRig(settings): Model
    local Rig = PlaceholderRig.Build(settings.Name or "Minion")

    -- The placeholder's name tag exists to tell developers which unbuilt character they're
    -- looking at. A minion is not an unbuilt character.
    local Head = Rig:FindFirstChild("Head")
    local Tag = Head and Head:FindFirstChild("PlaceholderNameTag")
    if Tag then
        Tag:Destroy()
    end
    Rig:SetAttribute("PlaceholderRig", nil)

    local Appearance = settings.Appearance or {}

    for _, Part: Instance in Rig:GetDescendants() do
        if not Part:IsA("BasePart") then
            continue
        end

        if Appearance.Color then
            Part.Color = Appearance.Color
        end
        if Appearance.Material then
            Part.Material = Appearance.Material
        end
        if Appearance.Transparency and Part.Name ~= "HumanoidRootPart" then
            Part.Transparency = Appearance.Transparency
        end
    end

    -- A separate head colour is what makes a minion read as a *kind* of minion rather
    -- than a monochrome blob.
    if Appearance.HeadColor and Head then
        Head.Color = Appearance.HeadColor
    end

    local Humanoid = Rig:FindFirstChildWhichIsA("Humanoid") :: Humanoid
    Humanoid.MaxHealth = settings.Health or 40
    Humanoid.Health = Humanoid.MaxHealth
    Humanoid.WalkSpeed = settings.Speed or 13
    Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
    -- Nothing summoned should be climbing or swimming its way across the arena.
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

    -- Scale. `Humanoid.*Scale` values only apply to R15; for an R6 rig the parts and the
    -- joints have to be scaled by hand, which is why this walks the Motor6Ds too.
    local Scale = settings.Scale or 1
    if Scale ~= 1 then
        for _, Part: Instance in Rig:GetDescendants() do
            if Part:IsA("BasePart") then
                Part.Size *= Scale
            elseif Part:IsA("Motor6D") then
                Part.C0 = Part.C0 + (Part.C0.Position * (Scale - 1))
                Part.C1 = Part.C1 + (Part.C1.Position * (Scale - 1))
            elseif Part:IsA("SpecialMesh") then
                Part.Scale *= Scale
            end
        end
        Humanoid.HipHeight = 2 * (Scale - 1)
    end

    local Root = Rig.PrimaryPart
    if Root then
        -- Legal hitbox target: this is what lets anyone kill a minion with a normal swing.
        Root:SetAttribute("HitboxPriority", 1)
    end

    local Role = Instance.new("StringValue")
    Role.Name = "Role"
    Role.Value = "Summon"
    Role.Parent = Rig

    Rig:SetAttribute("ExecutionsDisabled", true)
    Rig:SetAttribute("Summon", true)

    if Appearance.Glow then
        local Glow = Instance.new("Highlight")
        Glow.FillColor = Appearance.Glow
        Glow.OutlineColor = Appearance.Glow
        Glow.FillTransparency = 0.7
        Glow.OutlineTransparency = 0.4
        Glow.DepthMode = Enum.HighlightDepthMode.Occluded
        Glow.Adornee = Rig
        Glow.Parent = Rig
    end

    return Rig
end

--------------------------------------------------------------------------------
-- THE BRAIN
--------------------------------------------------------------------------------

--[=[
    One minion's turn to think.

    Returns `false` when it's finished, which tells the loop to drop it.
]=]
local function Think(minion): boolean
    local Rig: Model? = minion.Model
    if not Rig or not Rig.Parent then
        return false
    end

    local Humanoid: Humanoid? = minion.Humanoid
    if not Humanoid or Humanoid.Health <= 0 then
        return false
    end

    if os.clock() >= minion.ExpiresAt then
        return false
    end

    local Root = Rig.PrimaryPart
    if not Root then
        return false
    end

    -- The owner leaving or dying doesn't kill the minion outright — it just loses its
    -- "don't attack my summoner" exclusion, which is correct: a summon outliving its
    -- caster for a few seconds is a fair trade for the cooldown they paid.
    local OwnerChar = minion.Owner and minion.Owner.Character

    local Target = CombatUtils.GetClosestFighter(Root.Position, minion.SeekRadius, OwnerChar)

    if not Target then
        -- Nothing to chase. Wander a little so a swarm doesn't stand in a frozen clump.
        if minion.Wander then
            local Drift = Root.Position + Vector3.new(
                (math.random() - 0.5) * 24,
                0,
                (math.random() - 0.5) * 24
            )
            Humanoid:MoveTo(Drift)
        end
        return true
    end

    local TargetRoot = Utils.Character.GetRootPart(Target)
    if not TargetRoot then
        return true
    end

    Humanoid:MoveTo(TargetRoot.Position)

    -- ATTACK, if it's close enough and off its own swing cooldown.
    local Distance = (TargetRoot.Position - Root.Position).Magnitude
    local Now = os.clock()

    if Distance <= minion.AttackRange and Now >= (minion.NextAttack or 0) then
        minion.NextAttack = Now + minion.AttackInterval

        -- Damage is the OWNER's, through the one damage pipeline the game has.
        if minion.Owner and minion.Damage > 0 then
            Hitbox.New(minion.Owner, {
                CFrame = function(): CFrame
                    return (Root and Root.Parent and Root.CFrame) or CFrame.new(0, -5000, 0)
                end,
                CFrameOffset = CFrame.new(0, 0, -minion.AttackRange * 0.5),
                Size = Vector3.new(4, 5, minion.AttackRange),
                Time = 0.18,
                Damage = minion.Damage,
                Reason = minion.Reason,
                Knockback = 0,
                EffectsToApply = minion.Effects,
                HitMultiple = false,
                PredictVelocity = false,
                -- A minion must never trigger an execution cutscene on the owner's behalf.
                ExecuteOnKill = false,
            })
        end

        if minion.OnAttack then
            local Ok, Err = pcall(minion.OnAttack, minion, Target)
            if not Ok then
                warn("[SummonService] A minion's `OnAttack` errored: "..tostring(Err))
            end
        end

        AbilityFX.Sparks(Root.Position + Root.CFrame.LookVector * 2, minion.Colour, 6, 14)
    end

    return true
end

--- Starts the shared think loop if it isn't already running.
local function EnsureBrain()
    if ThinkThread then
        return
    end

    ThinkThread = task.spawn(function()
        while #Live > 0 do
            task.wait(SummonService.ThinkRate)

            for Index = #Live, 1, -1 do
                local Minion = Live[Index]

                local Continuing = false
                local Ok, Err = pcall(function()
                    Continuing = Think(Minion)
                end)

                -- One broken minion must not freeze every other minion in the server.
                if not Ok then
                    warn("[SummonService] A minion errored while thinking and was removed: "..tostring(Err))
                    Continuing = false
                end

                if not Continuing then
                    table.remove(Live, Index)
                    Minion:Destroy()
                end
            end
        end

        ThinkThread = nil
    end)
end

--------------------------------------------------------------------------------
-- SUMMONING
--------------------------------------------------------------------------------

export type SummonSettings = {
    --- Who it fights for, and who gets the kill credit. Required.
    SourcePlayer: Player,
    --- Where it appears. Spread out automatically when summoning several.
    Position: Vector3,
    --- How many. Clamped by the per-player cap.
    Count: number?,

    Name: string?,
    --- Seconds before it dissolves.
    Lifetime: number?,
    --- How much damage it takes to kill.
    Health: number?,
    --- Walk speed. Should be below the killers' so they can be outrun.
    Speed: number?,
    --- Overall rig scale. `0.5` is a Gubby, `1` is a Guest.
    Scale: number?,

    --- Damage per swing. `0` makes it a harmless distraction, which is a valid design.
    Damage: number?,
    --- How close it has to get to swing.
    AttackRange: number?,
    --- Seconds between its swings.
    AttackInterval: number?,
    --- Statuses its swing applies.
    Effects: {{Name: string, Level: number?, Duration: number?, Subfolder: string?, OverwriteExisting: boolean?}}?,
    --- Kill feed text.
    Reason: string?,

    --- How far it looks for somebody to chase.
    SeekRadius: number?,
    --- Whether it drifts around when there's nobody to chase. Defaults to `true`.
    Wander: boolean?,

    --- Looks.
    Appearance: {
        Color: Color3?,
        HeadColor: Color3?,
        Material: Enum.Material?,
        Transparency: number?,
        Glow: Color3?,
    }?,

    --- Called once per minion, just after it appears.
    OnSpawn: ((minion: any) -> ())?,
    --- Called when it lands a swing.
    OnAttack: ((minion: any, target: Model) -> ())?,
    --- Called when it's removed, however that happened.
    OnEnd: ((minion: any) -> ())?,
}

--[=[
    Summons one or more minions.

    @return The handles that were actually created — fewer than `Count` if the cap was hit.
]=]
function SummonService.Summon(settings: SummonSettings): {any}
    if not RunService:IsServer() then
        return {}
    end

    local Player = settings.SourcePlayer
    if not Player then
        warn("[SummonService.Summon()] No `SourcePlayer`, so nothing could be given kill credit. Refused.")
        return {}
    end

    local Requested = math.clamp(settings.Count or 1, 1, SummonService.MaxPerPlayer)
    local Created = {}

    local Appearance = settings.Appearance or {}
    local Colour = Appearance.Glow or Appearance.Color or Color3.fromRGB(120, 255, 140)

    for Index = 1, Requested do
        if #Live >= SummonService.MaxTotal then
            break
        end
        if (CountByPlayer[Player] or 0) >= SummonService.MaxPerPlayer then
            break
        end

        local Rig = BuildRig(settings)

        -- Fan them out around the summon point. Spawning several on one spot wedges them
        -- inside each other and the physics solver spends the next second untangling it.
        local Angle = (Index / Requested) * math.pi * 2
        local Spread = Requested > 1 and 4 or 0
        local Spot = settings.Position + Vector3.new(math.cos(Angle) * Spread, 3, math.sin(Angle) * Spread)

        Rig:PivotTo(CFrame.new(Spot))
        Rig.Parent = AbilityFX.Folder()

        local Minion
        Minion = {
            Model = Rig,
            Humanoid = Rig:FindFirstChildWhichIsA("Humanoid"),
            Owner = Player,
            Colour = Colour,
            ExpiresAt = os.clock() + (settings.Lifetime or 14),
            Damage = settings.Damage or 10,
            AttackRange = settings.AttackRange or 7,
            AttackInterval = settings.AttackInterval or 1.4,
            Effects = settings.Effects,
            Reason = settings.Reason or (settings.Name or "Minion"),
            SeekRadius = settings.SeekRadius or 70,
            Wander = settings.Wander ~= false,
            NextAttack = 0,
            Alive = true,
            OnAttack = settings.OnAttack,
            --- Free-form storage for whichever ability summoned it.
            State = {},
        }

        function Minion:Destroy()
            if not Minion.Alive then
                return
            end
            Minion.Alive = false

            if CountByPlayer[Player] then
                CountByPlayer[Player] = math.max(CountByPlayer[Player] - 1, 0)
                if CountByPlayer[Player] <= 0 then
                    CountByPlayer[Player] = nil
                end
            end

            if settings.OnEnd then
                local Ok, Err = pcall(settings.OnEnd, Minion)
                if not Ok then
                    warn("[SummonService] A minion's `OnEnd` errored: "..tostring(Err))
                end
            end

            if Rig and Rig.Parent then
                local Root = Rig.PrimaryPart
                if Root then
                    AbilityFX.Smoke(Root.Position, Colour, 10, 3)
                end
                Debris:AddItem(Rig, 0.15)
            end

            Minion.Model = nil
        end

        CountByPlayer[Player] = (CountByPlayer[Player] or 0) + 1
        table.insert(Live, Minion)
        table.insert(Created, Minion)

        AbilityFX.Burst(Spot, 5, Colour, {Duration = 0.3})

        if settings.OnSpawn then
            local Ok, Err = pcall(settings.OnSpawn, Minion)
            if not Ok then
                warn("[SummonService] A minion's `OnSpawn` errored: "..tostring(Err))
            end
        end
    end

    if #Created > 0 then
        EnsureBrain()
    end

    return Created
end

--------------------------------------------------------------------------------
-- QUERIES AND CLEANUP
--------------------------------------------------------------------------------

--- How many minions this player has alive.
function SummonService.CountFor(player: Player): number
    return CountByPlayer[player] or 0
end

--- Every minion this player has alive.
function SummonService.GetFor(player: Player): {any}
    local Found = {}
    for _, Minion in Live do
        if Minion.Owner == player then
            table.insert(Found, Minion)
        end
    end
    return Found
end

--- Removes one player's minions. Called when they leave.
function SummonService.ClearFor(player: Player)
    for Index = #Live, 1, -1 do
        local Minion = Live[Index]
        if Minion.Owner == player then
            table.remove(Live, Index)
            Minion:Destroy()
        end
    end
end

--- Removes everything. Called at the end of a round.
function SummonService.ClearAll()
    for Index = #Live, 1, -1 do
        local Minion = Live[Index]
        table.remove(Live, Index)
        Minion:Destroy()
    end

    table.clear(CountByPlayer)
end

return SummonService
