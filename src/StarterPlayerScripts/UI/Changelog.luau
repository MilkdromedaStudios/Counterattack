local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SideBar = require(script.Parent.SideBar)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

local Changelog = {
    Enabled = true,
    UIInstance = nil,
    Opened = false,
}

--- The format to follow in `CurrentChangelog`'s 
type ChangelogFormat = {
    --- The version of the place containing the update.
    --- Can be found by printing `game.PlaceVersion`.
    PlaceVersion: number,
    --- The text that'll be shown in the menu's title.
    MenuTitle: string,
    --- The title of the update for the beginning of the changelog.
    UpdateTitle: string,
    --- The ID of the update's thumbnail's image.
    --- May also be a banner if you modify the UI yourself.
    UpdateThumbnailID: string,
    --- The date of the update.
    --- Can be anything, but preferably the date.
    --- Will show under the thumbnail.
    UpdateDate: string,
    --- The entries of the changelog.
    Entries: {{
        Type: "Separator" | "SectionEntry" | "Text",
        Text: string,
    }},
}
--[=[
    THE LIVE CHANGELOG

    This is what players see. Update `PlaceVersion` to the version this update ships on
    (print `game.PlaceVersion` from the command bar in the published place to find it) —
    the menu pops open by itself for anybody whose last seen version is older than this.

    Leaving `PlaceVersion` at 0 means it never auto-opens, which is what you want while
    you're still building.
]=]
local CurrentChangelog: ChangelogFormat = {
    PlaceVersion = 0,
    MenuTitle = "Changelog",
    UpdateTitle = "COUNTERATTACK",
    UpdateThumbnailID = "rbxasset://textures/ui/GuiImagePlaceholder.png",
    UpdateDate = "16/08/2026",
    Entries = {
        {
            Type = "Separator",
            Text = "The whole game changed",
        },
        {
            Type = "SectionEntry",
            Text = "There are no survivors any more. Everyone is a killer, and everyone can hurt everyone.",
        },
        {
            Type = "SectionEntry",
            Text = "Rounds. Wait out the intermission, then everybody drops into the arena together.",
        },
        {
            Type = "Text",
            Text = "There's nothing to press. If you're in the server when a round starts, you're in the round.",
        },
        {
            Type = "SectionEntry",
            Text = "Last one breathing wins. If the clock runs out first, nobody does.",
        },
        {
            Type = "SectionEntry",
            Text = "Death is elimination — you're out until the next round starts. Then you're straight back in.",
        },
        {
            Type = "SectionEntry",
            Text = "Down to the last two, the clock is cut short and you're shown to each other. No hiding it out.",
        },
        {
            Type = "SectionEntry",
            Text = "You get a few seconds of spawn protection on arrival so nobody can delete you as you land.",
        },
        {
            Type = "Text",
            Text = "Killstreaks are announced to the whole server at 3, 5, 7 and 10 kills. Dying resets yours.",
        },

        {
            Type = "Separator",
            Text = "Ten new killers",
        },
        {
            Type = "SectionEntry",
            Text = "VERITY — blinds anyone who looks at it and marks anyone who doesn't. There is no right answer.",
        },
        {
            Type = "SectionEntry",
            Text = "SUPERMAN — flies, burns and freezes. The toughest fighter in the arena and the easiest one to read.",
        },
        {
            Type = "SectionEntry",
            Text = "1x1x1x1 — takes your controls, takes your abilities, and takes back the last four seconds.",
        },
        {
            Type = "SectionEntry",
            Text = "FOG — fills the map with blinding mist that only it can see through.",
        },
        {
            Type = "SectionEntry",
            Text = "GUBBY — fastest thing here. Bounces off everything and glues the floor shut behind it.",
        },
        {
            Type = "SectionEntry",
            Text = "NUKER — biggest numbers in the game. Every single one of them hurts him too.",
        },
        {
            Type = "SectionEntry",
            Text = "MINI-GUNNER — the only killer with real range, and the only one who can't run away.",
        },
        {
            Type = "SectionEntry",
            Text = "HOLLOWMARK — brands people, teleports to them, then calls the whole list in at once.",
        },
        {
            Type = "SectionEntry",
            Text = "SCRAPHEAP — its armour and its ammunition are the same pile. Spend one, lose the other.",
        },
        {
            Type = "SectionEntry",
            Text = "RAVEL — no burst damage at all. Everything it does was decided several seconds ago.",
        },
        {
            Type = "Text",
            Text = "Every killer's full kit is in the Inventory under More Info.",
        },

        {
            Type = "Separator",
            Text = "Twenty-seven more killers",
        },
        {
            Type = "SectionEntry",
            Text = "The roster is now 39. Faces you already know, with kits built specifically for this arena.",
        },
        {
            Type = "SectionEntry",
            Text = "Prices go from 2,600 up to 40,000 — the expensive ones are genuinely stronger, not just rarer.",
        },
        {
            Type = "Text",
            Text = "Every kit is in the Inventory under More Info. Read them before you spend.",
        },

        {
            Type = "Separator",
            Text = "Kills make you stronger",
        },
        {
            Type = "SectionEntry",
            Text = "Every kill gives a small boost. At 3, 5, 7 and 10 you unlock a named perk.",
        },
        {
            Type = "Text",
            Text = "Each one lights you up to the whole server. Dying takes all of it.",
        },

        {
            Type = "Separator",
            Text = "New status effects",
        },
        {
            Type = "SectionEntry",
            Text = "BURNING — damage over time that scales with its level.",
        },
        {
            Type = "SectionEntry",
            Text = "IRRADIATED — chips your health and stops stamina regenerating entirely.",
        },
        {
            Type = "SectionEntry",
            Text = "FRAGILE — you take 10% more damage from everything, per level.",
        },
        {
            Type = "SectionEntry",
            Text = "SNARED — rooted in place. You can still fight back, you just can't leave.",
        },
        {
            Type = "SectionEntry",
            Text = "GROUNDED — no sprinting, and your stamina is emptied.",
        },
        {
            Type = "SectionEntry",
            Text = "MARKED — your aura is visible to every fighter in the arena.",
        },

        {
            Type = "Separator",
            Text = "Fixes",
        },
        {
            Type = "SectionEntry",
            Text = "PLAY now takes your camera with you. It used to leave it behind in the lobby while your fighter dropped into the arena without it.",
        },
        {
            Type = "SectionEntry",
            Text = "Fighters no longer had infinite stamina. Sprinting drains properly again.",
        },
        {
            Type = "SectionEntry",
            Text = "Resistance no longer errors when you're hit while it's active.",
        },
        {
            Type = "SectionEntry",
            Text = "Piercing attacks no longer stop dead the moment they kill their first target.",
        },
        {
            Type = "SectionEntry",
            Text = "Abilities that disarm your basic attack actually disarm it now.",
        },
        {
            Type = "SectionEntry",
            Text = "Nullex Voyd's Callback Ping no longer leaves him permanently slowed for the rest of the match.",
        },
        {
            Type = "SectionEntry",
            Text = "Chase music now triggers correctly instead of never playing.",
        },
    },
}

local PrefabFolder = Utils.Instance.FindFirstChild(script, "Prefabs")
local Prefabs = {
    Separator = Utils.Instance.FindFirstChild(PrefabFolder, "Separator"),
    SectionEntry = Utils.Instance.FindFirstChild(PrefabFolder, "SectionEntry"),
    Text = Utils.Instance.FindFirstChild(PrefabFolder, "PlainText"),
}

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
function Changelog:Init()
    if Changelog.UIInstance then
        Changelog.UIInstance.Parent = UIParent
        Changelog.UIInstance.Size = Utils.UDim.Zero
        Changelog.UIInstance.Visible = false
        return
    end

    local UI = Utils.Instance.FindFirstChild(script, "Changelog")
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    Changelog.UIInstance = UI
    UI.Parent = UIParent

    local Content = UI.Content
    local Top = Content.Top
    Top.Title.Text = CurrentChangelog.UpdateTitle
    Top.Thumbnail.Image = CurrentChangelog.UpdateThumbnailID
    Top.Date.Text = CurrentChangelog.UpdateDate

    UI.Label.TextLabel.Text = CurrentChangelog.MenuTitle

    Utils.Instance.ObserveProperty(Changelog.UIInstance, "Size", function(value: UDim2)
        Changelog.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)

    for order, entry in CurrentChangelog.Entries do
        local Inst = Prefabs[entry.Type]:Clone()
        Inst.Title.Text = entry.Text
        Inst.LayoutOrder = order
        Inst.Parent = Content
    end

    local Log = Utils.Instance.FindFirstChild(LocalPlayer, "PlayerData.Misc.LastSeenLog")
    if Log.Value < CurrentChangelog.PlaceVersion and Log.Value < ReplicatedStorage.PlaceVersion.Value and CurrentChangelog.PlaceVersion <= ReplicatedStorage.PlaceVersion.Value then
        SideBar.OpenMenu(Changelog)
    end
end

function Changelog.Open(Time: number)
    --[[
        `Utils.Character.GetRole` rather than `LocalPlayer.Character.Role`.

        The old form THREW twice over: `LocalPlayer.Character` is nil between death and
        respawn, and indexing a Model for a `Role` child that hasn't replicated yet is an
        error in Roblox, not a nil. Either one killed the click — the menu button did
        nothing at all and the only trace was a line in the developer console.
    ]]
    if not Changelog.Enabled or Utils.Character.GetRole(LocalPlayer.Character) ~= "Spectator" or not SideBar.Enabled then
        return "Prevented"
    end

    if Time > 0 then
        TweenService:Create(Changelog.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.4, 0.7)}):Play()
    else
        Changelog.UIInstance.Size = UDim2.fromScale(0.4, 0.7)
    end
    Changelog.Opened = true

    return
end

function Changelog.Close(Time: number)
    if Time > 0 then
        TweenService:Create(Changelog.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        Changelog.UIInstance.Size = Utils.UDim.Zero
    end
    Changelog.Opened = false
end

function Changelog.Toggle(toggle: boolean)
    --[[
        A menu whose `Init` never produced a UI has nothing to hide.

        `SideBar` calls this on every character spawn, and the teardown below used to
        dereference `UIInstance` unconditionally — so a menu that failed to build threw
        here once per spawn, forever. `SideBar` used to paper over it by skipping menus
        with no `UIInstance`, but that check also skipped menus that DESTROY their UI on
        teardown and rebuild it later, so it had to go.
    ]]
    if not Changelog.Enabled and toggle then
        Changelog:Init()
    end
    if not toggle and Changelog.Enabled and Changelog.UIInstance then
        Changelog.UIInstance.Parent = script
        Changelog.UIInstance.Size = Utils.UDim.Zero
    end
    Changelog.Enabled = toggle
end

return Changelog
