local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    OVERSEER — the owner's killer. Not balanced, and not meant to be.

      M1  REBUKE       Flings somebody across the arena. Cannot kill them.
      Q   ARMAGEDDON   Everyone in the map, wherever they are. Non-lethal by default.
      E   UPHEAVAL     Throws everyone nearby into the air and scatters them.
      R   OMNISCIENCE  See everyone, everywhere, for ten minutes.
      F   DECREE       Switches between PLAYFUL and LETHAL.
      Passive          No cooldowns, fifty thousand health, immune to stuns.

    WHY IT IS NOT A DELETE BUTTON ANY MORE
    --------------------------------------
    Every ability on this character used to be an instant, unavoidable, map-wide kill.
    ARMAGEDDON did 100,000 damage to every alive fighter with no radius test; DECIMATE did
    2,500 in a 90 stud sphere; the basic attack did 5,000, against a roster whose highest
    health is 1,650. All four on a zero second cooldown.

    That is unusable in practice. Dropping in to mess about with the round meant ending it
    on the first keypress, every time, and then everybody sat through an intermission. The
    owner had a character that could only be used once.

    So the kit keeps all of its power and changes what the power DOES. Everything flings,
    scatters, blinds, marks and terrifies, and by default none of it kills anybody. The
    round keeps going, the players keep playing, and the Overseer gets to keep playing with
    them. The nuke is still here — it is on F, it says what it is, and it takes a
    deliberate press to arm.

    HOW "NON-LETHAL" IS ENFORCED
    ----------------------------
    Not by picking a damage number that happens to be survivable. `DamagePlayer` applies
    Resistance, Fragile, escalation multipliers and the attacker's own damage multiplier
    after the fact, so any fixed number is only survivable until somebody stacks Fragile.

    `Punish` instead records health BEFORE the hit and restores the floor AFTER it, so the
    target cannot end up below `HEALTH_FLOOR` however the modifiers landed. It is a clamp,
    not an estimate.

    ACCESS CONTROL
    --------------
    Locked to the accounts listed in `ServerScriptService.Managers.OwnerPerks`. That check
    is enforced in THREE independent places, because a killer that can reach every player
    in the map on a keypress is exactly the thing an exploiter would go looking for:

      1. `RoundManager.Utils.SetupFighter` refuses to spawn a non-owner as this character
         and falls them back to their previous killer.
      2. `Character.OnInit` kills the body of any non-owner wearing it, as a backstop if
         something else ever spawns it.
      3. Every ability behaviour checks again before doing anything.

    The abilities run on the SERVER, so a client can't invoke them by faking a remote —
    the server re-checks ownership on every single use.
]=]

--- Health every non-lethal hit leaves the target on, at minimum.
local HEALTH_FLOOR = 25

--- The attribute the mode lives in, on the Overseer's own character.
local MODE_ATTRIBUTE = "OverseerLethal"

--- Ownership check. Required lazily: `OwnerPerks` is server-only, and this module is
--- required on the client too (for the ability UI), where the check is irrelevant because
--- nothing the client does here has authority.
local function IsOwner(Player: Player?): boolean
    if not Player then
        return false
    end

    if not RunService:IsServer() then
        -- The client never gets to decide this. Returning `true` here only lets the local
        -- player's own UI and effects run; every consequence is gated server-side.
        return Players.LocalPlayer == Player
    end

    local Success, OwnerPerks = pcall(require, ServerScriptService.Managers.OwnerPerks)
    if not Success then
        warn("[Overseer] Couldn't load OwnerPerks to verify ownership — refusing to run.")
        return false
    end

    return OwnerPerks.IsOwner(Player)
end

--- Is the Overseer currently allowed to kill?
local function IsLethal(Char: Model?): boolean
    return Char ~= nil and Char:GetAttribute(MODE_ATTRIBUTE) == true
end

--------------------------------------------------------------------------------
-- THE ONE DAMAGE PATH
--------------------------------------------------------------------------------

--[=[
    Hurts a fighter, and in PLAYFUL mode refuses to finish them.

    THE CLAMP IS AFTER THE DAMAGE, ON PURPOSE. `CommonFunctions.DamagePlayer` is where
    Resistance, Fragile, `EscalationDamageMultiplier` and `AbilityDamageMultiplier` are
    applied, and all four of those land after the number this function was given. Working
    out in advance what damage would leave somebody on 25 health means reimplementing that
    whole chain here and keeping the copy in step with it forever.

    Reading health before, letting the real pipeline do its work, and then putting the
    floor back is exact, and it stays exact when somebody adds a fifth modifier.

    @param reason Shown in the kill feed and the damage log.
    @return Whether the target was left alive.
]=]
local function Punish(self: Types.Ability, Target: Model, Damage: number, reason: string): boolean
    local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then
        return false
    end

    local Lethal = IsLethal(self.OwnerProperties.Character)
    local Before = Humanoid.Health

    CommonFunctions.DamagePlayer({
        SourcePlayer = self.Owner,
        TargetHumanoid = Humanoid,
        Damage = Damage,
        Reason = reason,
    })

    if Lethal then
        return Humanoid.Health > 0
    end

    --[[
        The floor.

        `Before > 0` is already established above, so anybody this touched was alive when
        it started and is therefore entitled to the floor. Somebody who was ALREADY below
        it keeps whatever they had rather than being healed — the Overseer is not a medic,
        and healing a player who was about to die to somebody else's hit would be a far
        stranger thing to do than leaving them alone.
    ]]
    if Humanoid.Health < HEALTH_FLOOR then
        Humanoid.Health = math.min(HEALTH_FLOOR, Before)
    end

    return Humanoid.Health > 0
end

--[=[
    Throws a fighter around.

    This is what the kit does INSTEAD of killing, so it is worth being generous with: the
    whole point of a playful Overseer is that being hit by one is memorable rather than
    fatal. `RigImpulse` flings the whole assembly above magnitude 15.
]=]
local function Fling(Target: Model, direction: Vector3, magnitude: number)
    local Root = Utils.Character.GetRootPart(Target)
    if not Root then
        return
    end

    CommonFunctions.RigImpulse(Target, magnitude, direction.Unit, true)
end

--------------------------------------------------------------------------------
-- REBUKE (M1) — the basic attack
--------------------------------------------------------------------------------

--[=[
    A backhand that sends somebody over the arena wall.

    It replaced a 5,000 damage swing on a zero second cooldown, which one-shot every
    character on the roster through any amount of Resistance. 180 damage is still the
    hardest single hit in the game by a factor of four, and in PLAYFUL mode it cannot
    finish anybody, so what it actually does is relocate them.
]=]
local function RebukeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.08)
        self:AddConnection(task.delay(0.3, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    if not IsOwner(self.Owner) then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position
    local Forward = Root.CFrame.LookVector

    Sounds.PlaySound(self.UseSound, {Position = Origin, Volume = 0.9, RollOffMaxDistance = 400})

    local Targets = AbilityFX.ConeTargets(Origin, Forward, self.Range, self.Angle, Char)

    AbilityFX.Cone(Origin + Vector3.new(0, 1, 0), Forward, self.Range, self.Angle, Color3.fromRGB(255, 236, 190), {
        Duration = 0.25,
    })

    for _, Target: Model in Targets do
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not TargetRoot then
            continue
        end

        local Away = (TargetRoot.Position - Origin)
        if Away.Magnitude < 0.1 then
            Away = Forward
        end

        -- Up and out, so they travel rather than skid.
        local Direction = (Away.Unit + Vector3.new(0, 0.85, 0)).Unit

        if Punish(self, Target, self.Damage, "Rebuke") then
            Fling(Target, Direction, self.Knockback)
            AbilityFX.ShakeFor(Target, 2.2, 0.5)
            AbilityFX.ScreenFor(Target, "Flash", 0.4, 0.7)
        end

        AbilityFX.Burst(TargetRoot.Position, 7, Color3.fromRGB(255, 236, 190), {Duration = 0.3})
    end
end

--------------------------------------------------------------------------------
-- ARMAGEDDON (Q) — everyone, everywhere
--------------------------------------------------------------------------------

--- The visual: a pillar of light, an expanding shockwave, and a whiteout.
local function ArmageddonVFX(origin: Vector3, radius: number)
    local Folder = CombatUtils.GetInGameFolder()

    -- The column.
    local Pillar = CombatUtils.MakePart({
        Name = "ArmageddonPillar",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(2000, 40, 40),
        CFrame = CFrame.new(origin + Vector3.new(0, 900, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Color = Color3.fromRGB(255, 244, 214),
        Material = Enum.Material.Neon,
        Transparency = 0.15,
    })
    Pillar.Parent = Folder
    TweenService:Create(Pillar, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(2000, 400, 400),
        Transparency = 1,
    }):Play()
    Debris:AddItem(Pillar, 1.6)

    -- The shockwave.
    local Wave = CombatUtils.MakePart({
        Name = "ArmageddonWave",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * 8,
        CFrame = CFrame.new(origin),
        Color = Color3.fromRGB(255, 168, 60),
        Material = Enum.Material.Neon,
        Transparency = 0.2,
    })
    Wave.Parent = Folder
    TweenService:Create(Wave, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = Vector3.one * radius * 2,
        Transparency = 1,
    }):Play()
    Debris:AddItem(Wave, 1.3)
end

local function ArmageddonBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Screen-shake equivalent: a hard FOV punch on the caster.
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.45)
        self:AddConnection(task.delay(1.2, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    -- Server-side ownership re-check on every use. This is the one that matters.
    if not IsOwner(self.Owner) then
        warn("[Overseer] "..tostring(self.Owner and self.Owner.Name).." tried to use ARMAGEDDON without owner access. Refused.")
        return
    end

    local Char = self.OwnerProperties.Character
    local Origin = self.OwnerProperties.HRP.Position
    local Lethal = IsLethal(Char)

    Sounds.PlaySound(self.UseSound, {Position = Origin, Volume = 1, RollOffMaxDistance = 5000})
    ArmageddonVFX(Origin, self.VisualRadius)

    -- Everyone, everywhere. `GetAliveFighters` walks the whole player folder, so there is
    -- deliberately no radius test — that's the entire point of the ability.
    local Hit = 0
    for _, Target: Model in GameMode.GetAliveFighters() do
        if Target == Char then
            continue
        end

        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            continue
        end

        --[[
            SPAWN PROTECTION IS SUSPENDED, AND PUT BACK.

            An ability whose premise is "everybody, wherever they are" reads as broken when
            a late arrival shrugs it off, so the flag comes off for the duration of the hit.

            It used to be set to `false` and LEFT there. `Invincible` is what the spawn
            protection window writes, so clearing it permanently meant one press of this
            key stripped the protection off every player who happened to be respawning —
            and nothing ever put it back, because the window had already started its own
            timer and only ever clears the flag at the end. The next few seconds of their
            spawn were silently unprotected.

            Saving the previous value and restoring it on the next frame keeps the bypass
            to exactly the hit it was meant for.
        ]]
        local HadInvincible = Target:GetAttribute("Invincible")
        Target:SetAttribute("Invincible", false)

        local Alive = Punish(self, Target, self.Damage, "Armageddon")

        task.defer(function()
            if Target.Parent then
                Target:SetAttribute("Invincible", HadInvincible)
            end
        end)

        local TargetRoot = Utils.Character.GetRootPart(Target)
        if Alive and TargetRoot then
            --[[
                Straight up, hard.

                In PLAYFUL mode this is the whole payload: everybody in the arena is thrown
                into the air at the same moment, lands scattered, and gets up. It is the
                thing the ability is FOR now, rather than a flourish on top of a kill.
            ]]
            Fling(Target, Vector3.new(
                (math.random() - 0.5) * 0.6,
                1,
                (math.random() - 0.5) * 0.6
            ), self.Launch)

            AbilityFX.ShakeFor(Target, 5, 1.2)
            CombatUtils.ApplyEffectTo(Target, "Blindness", 1, 1.5)
        end

        Hit += 1
    end

    -- Whiteout for every client, cast or not.
    for _, Player: Player in Players:GetPlayers() do
        Utils.Player.Fade(Player, "In", 0.15, false, 1, {R = 255, G = 255, B = 255})
        task.delay(0.35, function()
            Utils.Player.Fade(Player, "Out", 1.1, false)
        end)
    end

    Utils.Misc.Print(("[Overseer] ARMAGEDDON hit %d fighter(s) in %s mode.")
        :format(Hit, Lethal and "LETHAL" or "PLAYFUL"))
end

--------------------------------------------------------------------------------
-- UPHEAVAL (E) — throw the room
--------------------------------------------------------------------------------

--[=[
    Everyone nearby goes up, and comes down somewhere else.

    This replaced DECIMATE, which was a 2,500 damage sphere — an instant kill on every
    character in the game, in a 90 stud radius, with no cooldown. It was ARMAGEDDON with a
    radius, so it was never worth pressing.

    UPHEAVAL does something the other abilities do not: it moves people. A fight gets
    picked up and put down scattered, which is disruptive and funny and leaves everybody
    alive to be annoyed about it.
]=]
local function UpheavalBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.15)
        self:AddConnection(task.delay(0.5, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    if not IsOwner(self.Owner) then
        return
    end

    local Char = self.OwnerProperties.Character
    local Origin = self.OwnerProperties.HRP.Position

    Sounds.PlaySound(self.UseSound, {Position = Origin, Volume = 0.95, RollOffMaxDistance = 600})

    AbilityFX.Shockwave(Origin, self.Radius, Color3.fromRGB(255, 150, 70), 24)
    AbilityFX.Ring(Origin, self.Radius, Color3.fromRGB(255, 200, 120), {Duration = 0.7, Thickness = 2})
    AbilityFX.ShakeInRadius(Origin, self.Radius, 4, 0.9, Char)

    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.Radius, Char) do
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not TargetRoot then
            continue
        end

        if not Punish(self, Target, self.Damage, "Upheaval") then
            continue
        end

        --[[
            Thrown outward and up, harder the closer they were.

            Scaling with proximity rather than flinging everybody identically means the
            blast reads as having a centre, and it stops somebody at the very edge of the
            radius being launched as far as somebody standing on top of it.
        ]]
        local Away = TargetRoot.Position - Origin
        local Distance = Away.Magnitude
        local Closeness = 1 - math.clamp(Distance / self.Radius, 0, 1)

        local Direction = Distance > 0.1
            and (Away.Unit + Vector3.new(0, 1.4, 0)).Unit
            or Vector3.new(0, 1, 0)

        Fling(Target, Direction, self.Launch * (0.45 + Closeness * 0.55))

        CombatUtils.ApplyEffectTo(Target, "Disoriented", 1, 2.5)
        AbilityFX.ScreenFor(Target, "Woozy", 2, 0.8)
    end
end

--------------------------------------------------------------------------------
-- OMNISCIENCE (R) — see everyone forever
--------------------------------------------------------------------------------

local function OmniscienceBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    if not IsOwner(self.Owner) then
        return
    end

    local Char = self.OwnerProperties.Character

    Sounds.PlaySound(self.UseSound, {Parent = self.OwnerProperties.HRP, Volume = 0.7})

    -- A long pulse rather than a single reveal, so people who spawn in later are lit up
    -- too. Ends with the character.
    self:AddStunnableConnection(task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char.Parent and self.Owner.Character == Char do
            for _, Target: Model in GameMode.GetAliveFighters() do
                if Target == Char then
                    continue
                end

                Utils.Player.RevealPlayerAuraTo(self.Owner, Target, 2.5, Color3.fromRGB(255, 220, 120))
            end

            Elapsed += task.wait(2)
        end
    end))
end

--------------------------------------------------------------------------------
-- DECREE (F) — the safety catch
--------------------------------------------------------------------------------

--[=[
    Switches between PLAYFUL and LETHAL.

    THE WHOLE KIT HANGS OFF THIS, and it defaults to PLAYFUL — see `OnInit`.

    An ability that is sometimes an instant kill and sometimes is not has to say which it
    is right now, loudly, or the owner cannot tell whether pressing Q is going to end the
    round. So flipping it writes a floating label, recolours the Overseer, and prints to
    the Output, and the state lives in an attribute on the character so it replicates to
    every client for free and resets itself on death.

    IT RESETS TO PLAYFUL ON RESPAWN. Deliberately: a mode this consequential should not be
    something you can leave armed and forget about between rounds.
]=]
local function DecreeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 0.94)
        self:AddConnection(task.delay(0.35, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    if not IsOwner(self.Owner) then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Lethal = not IsLethal(Char)
    Char:SetAttribute(MODE_ATTRIBUTE, Lethal)

    local Colour = Lethal and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(120, 220, 255)

    AbilityFX.Text(
        Root.Position + Vector3.new(0, 4, 0),
        Lethal and "LETHAL" or "PLAYFUL",
        Colour,
        2
    )
    AbilityFX.Ring(Root.Position, 12, Colour, {Duration = 0.5, Thickness = 1.2})
    AbilityFX.Tint(Char, Colour, 1.2, {})
    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 0.8, RollOffMaxDistance = 300})

    --[[
        An outline the owner can see at a glance, replaced rather than stacked.

        Without clearing the old one, every press leaves another `Highlight` on the
        character and the colours fight. Named so it can be found again.
    ]]
    local Existing = Char:FindFirstChild("OverseerModeHighlight")
    if Existing then
        Existing:Destroy()
    end

    if Lethal then
        local Highlight = Instance.new("Highlight")
        Highlight.Name = "OverseerModeHighlight"
        Highlight.FillTransparency = 1
        Highlight.OutlineColor = Colour
        Highlight.OutlineTransparency = 0.2
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        Highlight.Adornee = Char
        Highlight.Parent = Char
    end

    Utils.Misc.Print("[Overseer] "..(Lethal
        and "LETHAL — abilities will kill."
        or "PLAYFUL — abilities will not kill anybody."))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Overseer: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Overseer",
        Quote = "You were never playing against me.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",

        --- Unbuyable. Ownership is what grants it, not money.
        Price = math.huge,

        --[=[
            Read by `RoundManager.Utils.SetupFighter` and by the shop and inventory UI.
            Any character with this flag can only be equipped by an account listed in
            `ServerScriptService.Managers.OwnerPerks`.
        ]=]
        OwnerOnly = true,

        Origin = {
            TooltipText = "Wrote the rules. Doesn't follow them.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        --[=[
            `Type`, not `Title`.

            Every section here used to be written as `{Title = ..., Text = ...}`, but the
            More Info page's renderer keys off `Section.Type` to pick a template:
            `Templates[Section.Type]:Clone()`. With `Type` nil that is `Templates[nil]`,
            which throws and takes the whole page down.

            Only the FIRST section escaped, by accident: `Character.CreateKiller` deep-merges
            over a default `Description` whose one entry has `Type = "Text"`, so index 1
            inherited a type and indices 2 to 4 did not. Opening this character's info page
            errored every time.
        ]=]
        Role = "Debug",
        Difficulty = 1,

        Description = {
            {Type = "Separator", Text = "GENERAL INFO"},
            {Type = "Header", Text = "OVERSEER"},
            {
                Type = "Text",
                Text = "A debug character. It is not balanced, it is not meant to be, and it is tagged `Dev` so it never appears in the shop. It starts in PLAYFUL mode, where nothing it does can kill anybody — so a round survives it being used.",
            },
            {Type = "Separator", Text = "ABILITIES"},
            {Type = "Header", Text = "REBUKE"},
            {
                Type = "Text",
                Text = "A backhand in a wide cone. The hardest single hit in the game, and in PLAYFUL mode it relocates people rather than killing them.",
            },
            {Type = "Header", Text = "ARMAGEDDON"},
            {
                Type = "Text",
                Text = "Reaches every other fighter in the map at once, wherever they are. In PLAYFUL mode it throws the entire arena into the air and blinds them for a second and a half; in LETHAL mode it kills them.",
            },
            {Type = "Header", Text = "UPHEAVAL"},
            {
                Type = "Text",
                Text = "Throws everyone within 90 studs up and outward, harder the closer they were, and leaves them Disoriented. Scatters a fight instead of ending it.",
            },
            {Type = "Header", Text = "OMNISCIENCE"},
            {
                Type = "Text",
                Text = "Every fighter's aura, through every wall, for ten minutes.",
            },
            {Type = "Header", Text = "DECREE"},
            {
                Type = "Text",
                Text = "Switches between PLAYFUL and LETHAL. PLAYFUL is the default and it comes back on every respawn. In LETHAL the damage numbers are what they look like and ARMAGEDDON ends the round.",
            },
            {Type = "Header", Text = "PASSIVE — AUTHOR"},
            {
                Type = "Text",
                Text = "No ability cooldowns at all. Fifty thousand health. Cannot be stunned.",
            },
        },
    },

    GameplayConfig = {
        Health = 50000,
        BaseSpeed = 16,
        SprintSpeedMultiplier = 34 / 16,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 1000,
            StaminaDrain = 0,
            StaminaGain = 1000,
        },

        Abilities = {
            --[=[
                A CUSTOM BASIC ATTACK, not `Ability.Slash`.

                `Slash` would do its own damage through `Classes.Hitbox`, and the hitbox
                pipeline has no idea about PLAYFUL mode — it would kill people in it. The
                cone here is read through `AbilityFX.ConeTargets` and every hit goes
                through `Punish`, so there is exactly one place in this character where
                damage happens and exactly one place the floor has to be applied.
            ]=]
            Slash = Ability.New({
                --[=[
                    The TABLE KEY is `Slash`, the display name is not.

                    The key is what the rest of the engine reaches for — and what the
                    balance readout reads — so it stays. `Name` is what the ability GUI
                    prints, and the two engine checks that care about the basic attack
                    (`SlashPrevented` and `AbilitiesLocked` in `Classes/Ability`) both
                    accept `InputName == "Slash"` as well as the name, so renaming the
                    label costs nothing.
                ]=]
                Name = "Rebuke",
                InputName = "Slash",
                Cooldown = 0.6,
                Duration = 0.35,

                --- Four times the hardest swing on the roster. Still cannot kill in PLAYFUL.
                Damage = 180,
                Range = 16,
                Angle = 120,
                --- Well past the flinging threshold in `RigImpulse`.
                Knockback = 85,

                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Behaviour = RebukeBehaviour,
            }),

            Armageddon = Ability.New({
                Name = "Armageddon",
                InputName = "FirstAbility",
                --- No cooldown, as asked. `SetOnCooldown` short-circuits on 0.
                Cooldown = 0,
                Duration = 0.6,

                --- Enough to delete anything on the roster through any resistance, when
                --- LETHAL is armed. `Punish` clamps it otherwise.
                Damage = 100000,
                --- Only affects the size of the shockwave; the damage has no radius.
                VisualRadius = 250,
                --- How hard everybody in the map is thrown upward in PLAYFUL mode.
                Launch = 110,

                UseSound = "rbxassetid://9083889906",

                Behaviour = ArmageddonBehaviour,
            }),

            Upheaval = Ability.New({
                Name = "Upheaval",
                InputName = "SecondAbility",
                Cooldown = 0,
                Duration = 0.45,

                Radius = 90,
                Damage = 420,
                Launch = 125,

                UseSound = "rbxassetid://9046319808",

                Behaviour = UpheavalBehaviour,
            }),

            Omniscience = Ability.New({
                Name = "Omniscience",
                InputName = "ThirdAbility",
                Cooldown = 0,
                Duration = 0.3,

                --- How long the reveal pulse keeps running, in seconds.
                Duration_ = 600,

                UseSound = "rbxassetid://9118823103",

                Behaviour = OmniscienceBehaviour,
            }),

            Decree = Ability.New({
                Name = "Decree",
                InputName = "FourthAbility",
                --- Short, not zero: this one has a consequence worth not fat-fingering.
                Cooldown = 1,
                Duration = 0.3,

                UseSound = "rbxassetid://9118823103",

                Behaviour = DecreeBehaviour,
            }),
        },
    },

    --[=[
        Backstop #2 of the three ownership checks.

        If anything ever spawns this character for somebody who shouldn't have it — a
        corrupted save, a bad admin command, a future bug — this notices on the server and
        removes the body rather than letting the round get ended by an ability nobody
        should be holding.
    ]=]
    OnInit = function(self, Char: Model)
        if not RunService:IsServer() then
            return
        end

        if IsOwner(self.Owner) then
            -- The passive, applied here so it survives however the character was spawned.
            Char:SetAttribute("CooldownMultiplier", 0)
            Char:SetAttribute("StunImmune", true)
            Char:SetAttribute("BypassStunProtection", true)

            --[=[
                PLAYFUL EVERY TIME.

                Written explicitly rather than left nil so `IsLethal` has a real value to
                read and so the attribute shows up in the explorer while testing. A mode
                that can end the round should never be inherited from the last life — the
                owner has to press F for it, this round, on purpose.
            ]=]
            Char:SetAttribute(MODE_ATTRIBUTE, false)
            return
        end

        warn(
            "[Overseer] "..tostring(self.Owner and self.Owner.Name).." spawned as Overseer without owner "..
            "access. Removing the character. Check `ServerScriptService.Managers.OwnerPerks.Owners`."
        )

        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if Humanoid then
            Humanoid.Health = 0
        end
    end,
})

return Overseer
