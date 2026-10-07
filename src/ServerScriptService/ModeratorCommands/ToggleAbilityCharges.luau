return {
    --[=[
        OWNER ONLY. Mirrors the copy in `ReplicatedStorage.Security.ModeratorCommands`.

        THIS FOLDER IS NOT LOADED BY ANYTHING. `CommonFunctions:Init` and `ModPanel` both
        require out of `ReplicatedStorage.Security.ModeratorCommands`, so these files are
        an unreferenced duplicate set. The flag is kept in step anyway: a duplicate whose
        PERMISSIONS differ from the live copy is exactly the sort of thing that gets wired
        up later and quietly reopens the hole.
    ]=]
    OwnerOnly = true,
    Name = "Toggle Ability Charges",
    DisplayedAttribute = "ChargesEnabled",
    Executed = function()
        local Enabled = workspace:GetAttribute("ChargesEnabled")
        workspace:SetAttribute("ChargesEnabled", not Enabled)
    end,
}