local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SideBar = require(script.Parent.SideBar)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

local Rules = {
    Enabled = true,
    UIInstance = nil,
    Opened = false,
}

--[=[
    RULES / HOW TO PLAY

    Doubles as the tutorial, since Counterattack doesn't explain itself the way the
    classic killer-versus-survivors mode did. Keep the "How it works" section in sync
    with `ReplicatedStorage.Modules.GameMode` if you retune the round rules.
]=]
local Ruleset: {{
        Type: "Separator" | "SectionEntry" | "Text",
        Text: string,
    }} = {
    {
        Type = "Separator",
        Text = "How it works",
    },
    {
        Type = "SectionEntry",
        Text = "Everyone here is a killer. There are no teams and no survivors — everyone can hurt everyone.",
    },
    {
        Type = "SectionEntry",
        Text = "Wait out the intermission in the lobby. When the timer hits zero the round starts and everybody goes in together.",
    },
    {
        Type = "Text",
        Text = "There's no button to press. If you're in the server when a round starts, you're in the round.",
    },
    {
        Type = "SectionEntry",
        Text = "You get a few seconds of protection when you land, so nobody can delete you the instant you arrive.",
    },
    {
        Type = "SectionEntry",
        Text = "Last one breathing wins. If the clock runs out first, nobody does.",
    },

    {
        Type = "Separator",
        Text = "Dying",
    },
    {
        Type = "SectionEntry",
        Text = "Death is elimination. You're out for the rest of the round.",
    },
    {
        Type = "SectionEntry",
        Text = "You go back to the lobby and can watch the rest of it play out.",
    },
    {
        Type = "Text",
        Text = "You're in again automatically when the next round starts. Nothing to press, nothing to wait for beyond the intermission.",
    },

    {
        Type = "Separator",
        Text = "Winning",
    },
    {
        Type = "SectionEntry",
        Text = "Down to the last two, the clock is cut short and you're shown to each other. No hiding it out.",
    },
    {
        Type = "SectionEntry",
        Text = "The winner takes the biggest payout. Everyone who made it into the round gets something.",
    },
    {
        Type = "Text",
        Text = "Kills pay out on their own too, so a good round you don't win is still worth having.",
    },

    {
        Type = "Separator",
        Text = "Kills make you stronger",
    },
    {
        Type = "SectionEntry",
        Text = "Every kill gives you a small boost — more health, more damage, a little more speed. It stops growing after ten.",
    },
    {
        Type = "SectionEntry",
        Text = "3 KILLS — BLOODSCENT. You see every fighter's aura through walls, for the rest of the round.",
    },
    {
        Type = "SectionEntry",
        Text = "5 KILLS — SECOND WIND. Kills heal you for a third of your maximum health.",
    },
    {
        Type = "SectionEntry",
        Text = "7 KILLS — FRENZY. Cooldowns run 35% faster and you take 15% less damage.",
    },
    {
        Type = "SectionEntry",
        Text = "10 KILLS — APEX. Everything you've earned so far, doubled. There is nothing above it.",
    },
    {
        Type = "Text",
        Text = "Every one of those lights you up to the whole server. Getting strong means everyone knows exactly where you are.",
    },
    {
        Type = "Text",
        Text = "Dying takes all of it. Streaks are announced server-wide at 3, 5, 7 and 10.",
    },

    {
        Type = "Separator",
        Text = "Controls",
    },
    {
        Type = "SectionEntry",
        Text = "Left Mouse — basic attack. Every killer has one and they all hit differently.",
    },
    {
        Type = "SectionEntry",
        Text = "Q, E, R — your killer's three abilities. Check More Info in the Inventory to see what yours do.",
    },
    {
        Type = "SectionEntry",
        Text = "Left Shift — sprint. It burns stamina, and stamina only regenerates when nobody is nearby.",
    },
    {
        Type = "SectionEntry",
        Text = "G — emote wheel. Tab — player list. Left Ctrl — shift lock.",
    },

    {
        Type = "Separator",
        Text = "Server rules",
    },
    {
        Type = "SectionEntry",
        Text = "No exploiting. The anti-cheat handles flying, noclipping and teleporting on its own.",
    },
    {
        Type = "SectionEntry",
        Text = "No harassment, slurs or targeted abuse in chat.",
    },
    {
        Type = "SectionEntry",
        Text = "Teaming is allowed — it's a free for all, so betrayal is part of the game. Don't complain when it happens to you.",
    },
    {
        Type = "Text",
        Text = "Sitting in the lobby without pressing PLAY is fine. Nobody is forced into the arena.",
    },
}

local PrefabFolder = Utils.Instance.FindFirstChild(script, "Prefabs")
local Prefabs = {
    Separator = Utils.Instance.FindFirstChild(PrefabFolder, "Separator"),
    SectionEntry = Utils.Instance.FindFirstChild(PrefabFolder, "SectionEntry"),
    Text = Utils.Instance.FindFirstChild(PrefabFolder, "PlainText"),
}

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
function Rules:Init()
    if Rules.UIInstance then
        Rules.UIInstance.Parent = UIParent
        Rules.UIInstance.Size = Utils.UDim.Zero
        Rules.UIInstance.Visible = false
        return
    end

    local UI = Utils.Instance.FindFirstChild(script, "Rules")
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    Rules.UIInstance = UI
    UI.Parent = UIParent

    local Content = UI.Content

    Utils.Instance.ObserveProperty(Rules.UIInstance, "Size", function(value: UDim2)
        Rules.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)

    for order, entry in Ruleset do
        local Inst = Prefabs[entry.Type]:Clone()
        Inst.Title.Text = entry.Text
        Inst.LayoutOrder = order
        Inst.Parent = Content
    end
end

function Rules.Open(Time: number)
    --[[
        `Utils.Character.GetRole` rather than `LocalPlayer.Character.Role`.

        The old form THREW twice over: `LocalPlayer.Character` is nil between death and
        respawn, and indexing a Model for a `Role` child that hasn't replicated yet is an
        error in Roblox, not a nil. Either one killed the click — the menu button did
        nothing at all and the only trace was a line in the developer console.
    ]]
    if not Rules.Enabled or Utils.Character.GetRole(LocalPlayer.Character) ~= "Spectator" or not SideBar.Enabled then
        return "Prevented"
    end

    if Time > 0 then
        TweenService:Create(Rules.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.4, 0.7)}):Play()
    else
        Rules.UIInstance.Size = UDim2.fromScale(0.4, 0.7)
    end
    Rules.Opened = true

    return
end

function Rules.Close(Time: number)
    if Time > 0 then
        TweenService:Create(Rules.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        Rules.UIInstance.Size = Utils.UDim.Zero
    end
    Rules.Opened = false
end

function Rules.Toggle(toggle: boolean)
    --[[
        A menu whose `Init` never produced a UI has nothing to hide.

        `SideBar` calls this on every character spawn, and the teardown below used to
        dereference `UIInstance` unconditionally — so a menu that failed to build threw
        here once per spawn, forever. `SideBar` used to paper over it by skipping menus
        with no `UIInstance`, but that check also skipped menus that DESTROY their UI on
        teardown and rebuild it later, so it had to go.
    ]]
    if not Rules.Enabled and toggle then
        Rules:Init()
    end
    if not toggle and Rules.Enabled and Rules.UIInstance then
        Rules.UIInstance.Parent = script
        Rules.UIInstance.Size = Utils.UDim.Zero
    end
    Rules.Enabled = toggle
end

return Rules
