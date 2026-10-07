--[=[
    EQUIP ITEM — the server side of changing your loadout.

    WHAT WAS WRONG WITH THE OLD ONE
    -------------------------------
      * `Type` came straight off the wire and was concatenated into a data path:
        `GetPlayerEquipped(plr, Type, false).Value = name`. A client sending anything other
        than "Killer" or "Survivor" either wrote somewhere it shouldn't or threw on a nil.
      * `name` was never checked against the roster. It only checked OWNERSHIP, and
        ownership entries can outlive the thing they name — rename a killer's module and
        every player who bought it still has an entry under the old name, so the old name
        would still equip. The result is an equipped killer that doesn't exist, which is a
        player who cannot spawn.
      * The skin path was accepted verbatim with no validation at all: `SkinPath` was a
        client-supplied dotted path and `name` a client-supplied string, and the handler
        wrote one into the other.
      * Every write assumed the target `StringValue` existed, so any of the above threw
        inside the remote handler instead of failing quietly.

    The shape of the fix is the same as `BuyItem`'s: the client names a thing, and the
    server decides whether that thing exists, is owned, and may be equipped.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(ReplicatedStorage.Modules.CharacterRegistry)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

--- The only loadout slots that exist. Anything else is a malformed request.
local EQUIPPABLE = {
    Killer = true,
    Survivor = true,
}

return function()
    Network:SetConnection("EquipItem", "REMOTE_EVENT", function(plr: Player, name: string, Type: string, SkinPath: string?)
        if not plr or not plr.Parent or typeof(name) ~= "string" or typeof(Type) ~= "string" then
            return
        end

        ------------------------------------------------------------------------
        -- SKINS
        ------------------------------------------------------------------------

        if Type == "Skin" then
            --[[
                A skin equip needs to know WHICH CHARACTER it's for, and the client used to
                supply that as a free-form path. Instead of trusting the path, rebuild it:
                the only legal destination is
                `PlayerData.Equipped.Skins.<Character>`, so the only thing worth taking from
                the client is the character name — and that is then checked against both the
                roster and the player's ownership.

                `SkinPath` is still accepted for compatibility with the inventory's existing
                call, but only its LAST segment is used, as the character name.
            ]]
            if typeof(SkinPath) ~= "string" then
                return
            end

            local Steps = Utils.Type.SplitStringPath(SkinPath)
            local CharacterName = Steps[#Steps]
            if not CharacterName then
                return
            end

            -- Which role does this character belong to? Asking the registry rather than
            -- trusting the path means a nonexistent character can't be equipped onto.
            local Kind = CharacterRegistry.Exists("Killer", CharacterName) and "Killer"
                or CharacterRegistry.Exists("Survivor", CharacterName) and "Survivor"
                or nil

            if not Kind then
                warn("[EquipItem] "..plr.Name.." tried to equip a skin for \""..tostring(CharacterName).."\", which isn't a character.")
                return
            end

            --[[
                An empty name is how you UNEQUIP a skin and go back to the default look, so
                it skips the existence and ownership checks on purpose — there is nothing to
                own about wearing nothing.
            ]]
            if #name > 0 then
                if not Utils.Instance.GetCharacterModule(Kind, CharacterName, name, false) then
                    warn("[EquipItem] "..plr.Name.." tried to equip the skin \""..name.."\", which "..CharacterName.." doesn't have.")
                    return
                end

                if not Utils.PlayerData.GetPlayerOwned(plr, "Skins."..CharacterName.."."..name, false) then
                    return
                end
            end

            -- Creates the slot if this is the first skin they've ever equipped for them.
            local SkinValue = Utils.PlayerData.CreateMissingSkinValue(plr, CharacterName)
            if not SkinValue then
                return
            end

            SkinValue.Value = name
            return
        end

        ------------------------------------------------------------------------
        -- CHARACTERS
        ------------------------------------------------------------------------

        if not EQUIPPABLE[Type] then
            warn("[EquipItem] "..plr.Name.." tried to equip into a slot called \""..tostring(Type).."\", which doesn't exist.")
            return
        end

        --[[
            EXISTENCE BEFORE OWNERSHIP.

            Checking ownership alone was the bug: a `Purchased.Killers.OldName` entry
            survives the module being renamed or deleted, so the old handler would happily
            set `Equipped.Killer` to a name with no module behind it. `RoundManager` then
            cannot build that character, and the player spends the round unable to spawn.
        ]]
        if not CharacterRegistry.Exists(Type, name) then
            warn("[EquipItem] "..plr.Name.." tried to equip \""..name.."\", which isn't a "..Type..". Their save may name a character that has since been removed.")
            return
        end

        -- Free characters are owned by everybody. Without this, anything priced at 0 could
        -- be seen in the shop, shown as FREE, and then refuse to equip.
        if not CharacterRegistry.IsFree(Type, name) then
            if not Utils.PlayerData.GetPlayerOwned(plr, CharacterRegistry.Kinds[Type].Plural.."."..name, false) then
                return
            end
        end

        local Slot = Utils.PlayerData.GetPlayerEquipped(plr, Type, false)
        if not Slot then
            -- Save data not there yet. Nothing to do and nothing to complain about.
            return
        end

        Slot.Value = name
    end)
end
