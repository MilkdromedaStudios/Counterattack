--[=[
    KILL ESCALATION

    Every kill makes you a little stronger, and enough of them make you a different
    fighter entirely.

    THE DESIGN
    ----------
    Two layers stacked on top of each other:

      * A small linear boost per kill — health, damage, speed. Individually almost
        unnoticeable. Deliberately so: this is the layer that makes a good round FEEL like
        it's going well without deciding it.

      * Perks at 3, 5, 7 and 10 kills. These are real, named abilities that change how you
        play, and they're announced to the whole server so everyone knows who to gang up on.

    Both reset when you die. The whole thing lives and dies inside a single round.

    WHY IT'S BALANCED THE WAY IT IS
    -------------------------------
    A snowball mechanic in a free-for-all has an obvious failure mode: whoever gets the
    first kill wins the round. Three things stop that here.

      1. The per-kill boosts are TINY and they stop compounding at `SoftCap` kills.
      2. Every perk tier reveals you to the entire server. Power costs you your anonymity,
         and in a room where everyone can hurt everyone, being visible is a real price.
      3. Dying takes all of it, instantly. There's no partial decay to hide behind.

    Tune the numbers in `PerKill` and rewrite `Tiers` freely — each tier is just a name, a
    description and a function that runs on the server.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(ReplicatedStorage.Modules.Utils)

local KillEscalation = {
    Enabled = true,
}

--[=[
    The per-kill boost.

    Read once per kill and applied cumulatively, so at N kills you're carrying N times
    each of these — up to `SoftCap`.
]=]
KillEscalation.PerKill = {
    --[=[
        Max health added per kill, as a fraction of the character's STARTING max health.

        A fraction rather than a flat number on purpose: health across the roster runs
        from roughly 900 to 1400, so a flat "+5 health" is a rounding error on the tanky
        killers and actually noticeable on the fragile ones — the boost would quietly
        mean something different depending on who you picked.
    ]=]
    MaxHealth = 0.02,
    --- Outgoing damage, as a fraction. `0.02` is +2% per kill.
    Damage = 0.02,
    --- Movement speed, as a fraction. `0.015` is +1.5% per kill.
    Speed = 0.015,
}

--- Kills past this stop adding to the linear boosts. The perk tiers still fire.
---
--- This is the main dial against snowballing — raise it for a swingier game.
KillEscalation.SoftCap = 10

--- Character attribute the damage pipeline reads. Also read by the client HUD.
KillEscalation.DamageAttribute = "EscalationDamageMultiplier"
--- Character attribute holding the current kill count, for UI.
KillEscalation.CountAttribute = "EscalationKills"
--- Character attribute holding a comma-separated list of earned perk names, for UI.
KillEscalation.PerksAttribute = "EscalationPerks"

--[=[
    THE PERKS.

    Keyed by the kill count that unlocks them. `Apply` runs on the SERVER only, with the
    earning player and their character.

    Add your own by adding a key. Nothing else needs to change.
]=]
KillEscalation.Tiers = {
    [3] = {
        Name = "BLOODSCENT",
        Announcement = "can smell blood",
        Description = "You see every fighter's aura through walls, permanently.",
        Apply = function(Player: Player, _Char: Model)
            -- Handled by a repeating pulse rather than a one-off, since aura reveals
            -- expire and people spawn in after you earn this.
            KillEscalation._StartBloodscent(Player)
        end,
    },

    [5] = {
        Name = "SECOND WIND",
        Announcement = "won't stay down",
        Description = "Kills heal you for a third of your maximum health.",
        Apply = function(_Player: Player, Char: Model)
            Char:SetAttribute("EscalationLifesteal", true)
        end,
    },

    [7] = {
        Name = "FRENZY",
        Announcement = "is in a frenzy",
        Description = "Ability cooldowns run 35% faster and you take 15% less damage.",
        Apply = function(_Player: Player, Char: Model)
            Char:SetAttribute("CooldownMultiplier", 0.65)
            -- Resistance is the engine's own damage-reduction effect: incoming damage is
            -- divided by `1 + 0.1 * level`, so level 2 is a shade under 17% off.
            Char:SetAttribute("EscalationResistance", 2)
        end,
    },

    [10] = {
        Name = "APEX",
        Announcement = "has become the apex",
        Description = "Double the per-kill boosts you've already earned. There is no tier above this.",
        Apply = function(Player: Player, Char: Model)
            local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
            if Humanoid then
                -- Doubles the health they've accrued, using the same captured base as
                -- `ApplyKill` so the two layers agree on what "doubled" means.
                local Base = Char:GetAttribute("EscalationBaseHealth") or Humanoid.MaxHealth
                local Bonus = Base * KillEscalation.PerKill.MaxHealth * KillEscalation.SoftCap
                Humanoid.MaxHealth += Bonus
                Humanoid.Health = math.min(Humanoid.Health + Bonus, Humanoid.MaxHealth)
            end

            local Current = Char:GetAttribute(KillEscalation.DamageAttribute) or 1
            Char:SetAttribute(KillEscalation.DamageAttribute, 1 + (Current - 1) * 2)

            KillEscalation._Reveal(Player, 600)
        end,
    },
}

--------------------------------------------------------------------------------
-- SERVER
--------------------------------------------------------------------------------

--- Reveals this fighter to everybody else. Power costs you your anonymity.
function KillEscalation._Reveal(Player: Player, duration: number)
    if not RunService:IsServer() then
        return
    end

    local Char = Player.Character
    if not Char then
        return
    end

    for _, Other: Model in workspace.Players:GetChildren() do
        if Other == Char then
            continue
        end

        local Watcher = game:GetService("Players"):GetPlayerFromCharacter(Other)
        if Watcher then
            Utils.Player.RevealPlayerAuraTo(Watcher, Char, duration, Color3.fromRGB(255, 60, 60))
        end
    end
end

--- BLOODSCENT: keeps every other fighter lit up for as long as this character lives.
function KillEscalation._StartBloodscent(Player: Player)
    if not RunService:IsServer() then
        return
    end

    local Char = Player.Character
    if not Char then
        return
    end

    task.spawn(function()
        while Char.Parent and Player.Character == Char do
            for _, Other: Model in workspace.Players:GetChildren() do
                if Other == Char then
                    continue
                end

                local Role = Utils.Character.GetRole(Other)
                if Role == nil or Role == "Spectator" then
                    continue
                end

                Utils.Player.RevealPlayerAuraTo(Player, Other, 2.5, Color3.fromRGB(200, 40, 40))
            end

            task.wait(2)
        end
    end)
end

--[=[
    Applies everything owed at `kills` kills.

    Called from `RoundManager.Callables.RegisterKill` once the streak has been counted.
    Safe to call with any number; it only ever applies the boost for THIS kill plus any
    tier that lands exactly on it.
]=]
function KillEscalation.ApplyKill(Player: Player, kills: number)
    if not RunService:IsServer() or not KillEscalation.Enabled then
        return
    end

    local Char = Player and Player.Character
    if not Char then
        return
    end

    local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then
        return
    end

    Char:SetAttribute(KillEscalation.CountAttribute, kills)

    --[[
        Capture the starting max health once, on the first kill. Every subsequent boost is
        a fraction of THIS, not of the current value — compounding off the running total
        would make the tenth kill worth far more than the first, which is the opposite of
        what a soft cap is for.
    ]]
    local BaseHealth = Char:GetAttribute("EscalationBaseHealth")
    if not BaseHealth then
        BaseHealth = Humanoid.MaxHealth
        Char:SetAttribute("EscalationBaseHealth", BaseHealth)
    end

    -- The linear layer, while it's still compounding.
    if kills <= KillEscalation.SoftCap then
        local Gain = BaseHealth * KillEscalation.PerKill.MaxHealth
        Humanoid.MaxHealth += Gain
        Humanoid.Health = math.min(Humanoid.Health + Gain, Humanoid.MaxHealth)

        Char:SetAttribute(
            KillEscalation.DamageAttribute,
            (Char:GetAttribute(KillEscalation.DamageAttribute) or 1) + KillEscalation.PerKill.Damage
        )

        -- Speed goes through the engine's factor system so it composes with abilities and
        -- effects instead of fighting them for the same property.
        local SpeedManager = require(game:GetService("ServerScriptService").Managers.PlayerManager.PlayerSpeedManager)
        SpeedManager.AddSpeedFactor(Player, "KillEscalation", 1 + KillEscalation.PerKill.Speed * kills)
    end

    -- SECOND WIND, if they've earned it.
    if Char:GetAttribute("EscalationLifesteal") then
        Humanoid.Health = math.min(Humanoid.Health + Humanoid.MaxHealth / 3, Humanoid.MaxHealth)
    end

    local Tier = KillEscalation.Tiers[kills]
    if not Tier then
        return
    end

    local Success, Err = pcall(Tier.Apply, Player, Char)
    if not Success then
        warn("[KillEscalation] Perk \""..Tier.Name.."\" failed to apply: "..tostring(Err))
        return
    end

    -- Record it for the HUD.
    local Earned = Char:GetAttribute(KillEscalation.PerksAttribute)
    Char:SetAttribute(KillEscalation.PerksAttribute, Earned and (Earned..","..Tier.Name) or Tier.Name)

    -- Every tier lights you up. Power costs anonymity.
    KillEscalation._Reveal(Player, 20)

    return Tier
end

--- The perk unlocked at exactly this many kills, or `nil`.
function KillEscalation.GetTier(kills: number)
    return KillEscalation.Tiers[kills]
end

--- Every perk this character has earned, in order.
function KillEscalation.GetEarnedPerks(Char: Model?): {string}
    if not Char then
        return {}
    end

    local Raw = Char:GetAttribute(KillEscalation.PerksAttribute)
    if not Raw or #Raw <= 0 then
        return {}
    end

    return string.split(Raw, ",")
end

return KillEscalation
