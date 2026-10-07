local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)

type AchievementGroup = {
    Title: string,
    LayoutOrder: number,
    Achievements: {[string]: Types.Achievement}
}

--[=[
    COUNTERATTACK — ACHIEVEMENTS

    HOW THEY WORK
    -------------
    An achievement with a `Requirement` is a PROGRESS bar and is advanced with
    `CommonFunctions.IncrementAchievementProgress(Player, "Group.Name", amount)`. One
    without a `Requirement` is a one-off flag, granted with
    `CommonFunctions.CompleteAchievement(Player, "Group.Name")`.

    The path is always `GroupKey.AchievementKey` — `"Combat.FirstBlood"`, not the display
    title. Renaming a `Title` is safe; renaming a KEY breaks every call site and any
    progress already saved under the old key.

    WHERE THEY'RE AWARDED
    ---------------------
      Combat.*       `RoundManager.Callables.RegisterKill`
      Rounds.*       `RoundManager.Utils.GrantRoyaleRewards`
      Escalation.*   `RoundManager.Callables.RegisterKill`, off the perk tier
      General.*      `PlayerManager.OnPlayerLoad`

    `Icon` is a square image ID. They're all placeholders — swap them for real art and
    nothing else has to change.

    NOTE ON REWARDS: `RewardType = "Currency"` pays `Amount`. The engine also supports
    `"Emote"`, `"Skin"` and character grants — see `CommonFunctions.CompleteAchievement`.
]=]

local PLACEHOLDER = "rbxasset://textures/ui/GuiImagePlaceholder.png"

return {
    General = {
        Title = "General",
        LayoutOrder = 1,
        Achievements = {
            Welcome = {
                Title = "Welcome To Counterattack",
                Description = "Play Counterattack for the first time.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 300,
                LayoutOrder = 1,
            },
        },
    },

    Combat = {
        Title = "Combat",
        LayoutOrder = 2,
        Achievements = {
            FirstBlood = {
                Title = "First Blood",
                Description = "Kill another fighter.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 250,
                LayoutOrder = 1,
            },
            Bloodwork = {
                Title = "Bloodwork",
                Description = "Kill 25 fighters.",
                Icon = PLACEHOLDER,
                Requirement = 25,
                RewardType = "Currency",
                Amount = 1000,
                LayoutOrder = 2,
            },
            Prolific = {
                Title = "Prolific",
                Description = "Kill 250 fighters.",
                Icon = PLACEHOLDER,
                Requirement = 250,
                RewardType = "Currency",
                Amount = 6000,
                LayoutOrder = 3,
            },
            Rampage = {
                Title = "Rampage",
                Description = "Reach a 3 kill streak in a single round.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 500,
                LayoutOrder = 4,
            },
            Unstoppable = {
                Title = "Unstoppable",
                Description = "Reach a 5 kill streak in a single round.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 1500,
                LayoutOrder = 5,
            },
            DeathItself = {
                Title = "Death Itself",
                Description = "Reach a 10 kill streak in a single round.",
                HiddenTitle = "???",
                HideTitleIfLocked = true,
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 8000,
                LayoutOrder = 6,
            },
        },
    },

    Rounds = {
        Title = "Rounds",
        LayoutOrder = 3,
        Achievements = {
            LastOneBreathing = {
                Title = "Last One Breathing",
                Description = "Win a round.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 500,
                LayoutOrder = 1,
            },
            Regular = {
                Title = "Regular",
                Description = "Play 10 rounds.",
                Icon = PLACEHOLDER,
                Requirement = 10,
                RewardType = "Currency",
                Amount = 750,
                LayoutOrder = 2,
            },
            Veteran = {
                Title = "Veteran",
                Description = "Play 100 rounds.",
                Icon = PLACEHOLDER,
                Requirement = 100,
                RewardType = "Currency",
                Amount = 4000,
                LayoutOrder = 3,
            },
            Champion = {
                Title = "Champion",
                Description = "Win 25 rounds.",
                Icon = PLACEHOLDER,
                Requirement = 25,
                RewardType = "Currency",
                Amount = 10000,
                LayoutOrder = 4,
            },
        },
    },

    Escalation = {
        Title = "Escalation",
        LayoutOrder = 4,
        Achievements = {
            Bloodscent = {
                Title = "Bloodscent",
                Description = "Unlock the BLOODSCENT perk by reaching 3 kills in a round.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 400,
                LayoutOrder = 1,
            },
            SecondWind = {
                Title = "Second Wind",
                Description = "Unlock the SECOND WIND perk by reaching 5 kills in a round.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 900,
                LayoutOrder = 2,
            },
            Frenzy = {
                Title = "Frenzy",
                Description = "Unlock the FRENZY perk by reaching 7 kills in a round.",
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 2000,
                LayoutOrder = 3,
            },
            Apex = {
                Title = "Apex",
                Description = "Unlock the APEX perk by reaching 10 kills in a round.",
                HiddenDescription = "There is nothing above it.",
                HideDescriptionIfLocked = true,
                Icon = PLACEHOLDER,
                RewardType = "Currency",
                Amount = 12000,
                LayoutOrder = 4,
            },
        },
    },
} :: {[string]: AchievementGroup}
