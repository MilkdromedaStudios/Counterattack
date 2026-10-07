local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)

return {
    Init = function(_)
        local TimeStats = ReplicatedStorage.RoundInfo

        local TimeRemaining = TimeStats.TimeRemaining
        local State = TimeStats.CurrentState
        local Fighters = TimeStats.PlayersRemaining

        local Frame = Utils.Instance.FindFirstChild(script, "TimeInfo")
        Frame.Parent = Utils.Instance.FindFirstChild(game:GetService("Players").LocalPlayer.PlayerGui, "Time")
        local TimeLabel = Frame.TimeLabel
        local Label = Frame.Label

        --[=[
            THE OPEN ARENA HAS NO CLOCK.

            Rounds count down to something; the open arena never ends, so the timer would
            sit frozen at 0:00 reading "Round ends in…", which looks broken.

            The same two labels get reused there for something that IS true: how many
            people are in the arena right now. `PlayersRemaining` already replicates one
            entry per live fighter, so this needs no new networking.

            Counterattack skips all of this and uses the real clock below — it has an
            intermission to count down and a round to time.
        ]=]
        if GameMode.Enabled and not GameMode.UseRounds then
            local function UpdateCount()
                local Count = #Fighters:GetChildren()
                TimeLabel.Text = tostring(Count)
                Label.Text = Count == 1 and "fighter in the arena" or "fighters in the arena"
            end

            Fighters.ChildAdded:Connect(UpdateCount)
            Fighters.ChildRemoved:Connect(UpdateCount)
            UpdateCount()

            return
        end

        local EnoughPlayers = ReplicatedStorage.RoundInfo.EnoughPlayers

        local LabelTexts = GameMode.IsRoundBased() and {
            Lobby = "Next round in...",
            InRound = "Round ends in...",
            NotEnough = "Waiting for fighters...",
            Frozen = "Time frozen!",
        } or {
        	Lobby = "Round begins in...",
        	InRound = "Round ends in...",
        	NotEnough = "Waiting for players...",
            Frozen = "Time frozen!",
        }

        --[=[
            LAST ONE STANDING — the round with no clock.

            `GameMode.Config.UseMatchTimer` off means a round runs until one fighter is
            left, so there is nothing for a countdown to count down TO. The timer would sit
            at 0:00 under "Round ends in..." for the whole match, which reads as a bug
            rather than as a rule.

            The clock is still correct and still shown for the INTERMISSION — that does end
            at a fixed time. Only the in-round half is swapped, for the number that
            actually decides the round: how many people are still alive.

            Written as a wrapper around the same two labels rather than as a second UI, so
            flipping `UseMatchTimer` back on restores the original display exactly and
            there is only ever one place that owns these labels.
        ]=]
        local ShowFighterCount = GameMode.IsRoundBased() and not GameMode.HasMatchTimer()

        local function InRoundDisplay()
            local Count = #Fighters:GetChildren()

            if Count <= 0 then
                -- Between the round starting and the server filling the folder. Showing a
                -- confident "0 fighters left" in that window looks like the round ended.
                TimeLabel.Text = "—"
                Label.Text = "Last one standing"
                return
            end

            TimeLabel.Text = tostring(Count)
            Label.Text = Count == 1 and "fighter left" or "fighters left"
        end

        local function Refresh()
            if ShowFighterCount and State.Value == "InRound" then
                InRoundDisplay()
                return
            end

            TimeLabel.Text = Utils.Math.ConvertToMinSec(math.ceil(TimeRemaining.Value))

            if workspace:GetAttribute("FreezeTime") then
                Label.Text = LabelTexts.Frozen
            elseif State.Value == "Lobby" and not EnoughPlayers.Value then
                Label.Text = LabelTexts.NotEnough
            else
                Label.Text = LabelTexts[State.Value] or "PLACEHOLDER"
            end
        end

        TimeRemaining.Changed:Connect(Refresh)
        State.Changed:Connect(Refresh)
        EnoughPlayers.Changed:Connect(Refresh)
        Utils.Instance.ObserveAttribute(workspace, "FreezeTime", Refresh)

        if ShowFighterCount then
            Fighters.ChildAdded:Connect(Refresh)
            Fighters.ChildRemoved:Connect(Refresh)
        end

        Refresh()
    end,
}
