local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effect = require(ReplicatedStorage.Classes.Effect)

--[=[
    The mirror image of `Resistance`.

    `CommonFunctions.DamagePlayer` divides incoming damage by `1 + 0.1 * Resistance`.
    This effect is read the same way but multiplies instead, so a Fragile III target
    takes 30% more damage from everything.

    It has no `ApplyEffect` of its own — the value living in `Character.Effects` is the
    whole mechanic, exactly like `Resistance` and `Undetectable`.
]=]
return Effect.New({
    Name = "Fragile",
    Description = "Increases the damage this character takes by 10% per level. Stacks badly with everything.",
    Duration = 8,
    Level = 1,
    ShowInGUI = true,
})
