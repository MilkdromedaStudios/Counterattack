local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local TimeManager = RunService:IsServer() and require(ServerScriptService.Managers.TimeManager) or nil

return {
    --[=[
        OWNER ONLY.

        With no flag at all this defaulted to `Utils.Ranks.ServerOwner` (20) in
        `CommonFunctions.ExecuteCommand`, and that check is `Rank < 20` — so Moderator
        (15) and Developer (18) both passed it. This toggle changes the round for every
        player in the server, so it belongs with the round controls, not with moderation.

        A FLAG RATHER THAN A RANK, for two reasons. `PlayerHasPermissionRank` compares
        `Rank < MandatoryRank` strictly, and the lowest rank that exists is `Owner = 1`,
        so there is no number that means "only the owner" — `RankRequired = 1` asks for
        `Rank < 1` and refuses everybody, including the owner. And ownership is not a
        position on the moderation ladder: it is membership of `OwnerPerks.Owners`, which
        is what `ExecuteCommand` checks when it sees this.

        `ModPanel.SetupCmd` reads `RankRequired` and would hide anything stricter than the
        viewer's rank; leaving it unset means the panel shows these to anyone who already
        passed its own owner gate, and the server decides for real.
    ]=]
    OwnerOnly = true,
    Name = "Freeze Timer",
    DisplayedAttribute = "FreezeTime",
    Type = "Bool",
    Executed = function()
        local Enabled = workspace:GetAttribute("FreezeTime")
        workspace:SetAttribute("FreezeTime", not Enabled)
        TimeManager.FreezeTime = not Enabled

        return workspace:GetAttribute("FreezeTime")
    end,
}