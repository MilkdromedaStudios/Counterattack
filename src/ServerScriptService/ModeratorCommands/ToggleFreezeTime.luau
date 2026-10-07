local ServerScriptService = game:GetService("ServerScriptService")

local TimeManager = require(ServerScriptService.Managers.TimeManager)

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
    Name = "Freeze Timer",
    DisplayedAttribute = "FreezeTime",
    Executed = function()
        local Enabled = workspace:GetAttribute("FreezeTime")
        workspace:SetAttribute("FreezeTime", not Enabled)
        TimeManager.FreezeTime = not Enabled
    end,
}