local LoadingGui = script:WaitForChild("LoadingGui")
local Main = LoadingGui:WaitForChild("LoadingScreen"):WaitForChild("Main")
local Percent = Main:WaitForChild("Percent")
local AmountTxt = Main:WaitForChild("Amount")
local CurrentlyInitting = Main:WaitForChild("CurrentlyInitting")
local Skip = Main:WaitForChild("Skip")

LoadingGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

while not game:IsLoaded() do
    task.wait()
end

task.wait(1)

--[=[
    WHAT ACTUALLY NEEDS PRELOADING.

    This used to collect EVERY descendant of four services — Folders, Scripts, Values,
    Motor6Ds, the lot — and hand each one to `ContentProvider:PreloadAsync` individually.

    Two costs, both real:
      * Time. Most of those instances reference no content at all, so the call does nothing
        but cost a round trip. On a full place that's thousands of pointless calls.
      * Memory. Everything that IS content gets pulled into the cache up front whether the
        player ever sees it or not — every skin texture, every map mesh, every sound.

    Only these classes actually hold a content ID. Filtering to them cuts the list by a
    large factor without preloading one asset fewer that matters.
]=]
local PRELOADABLE = {
    Decal = true, Texture = true, Sky = true,
    ImageLabel = true, ImageButton = true,
    Sound = true, Animation = true,
    MeshPart = true, SpecialMesh = true,
    ParticleEmitter = true, Beam = true, Trail = true,
    Shirt = true, Pants = true, ShirtGraphic = true,
}

local assets = {}
local loadedAssets = {}
local function addAssetsToLoad(assetList)
    for _, asset in assetList do
        if PRELOADABLE[asset.ClassName] then
            table.insert(assets, asset)
        end
    end
end

--[=[
    In Studio, skip the workspace sweep entirely.

    A test session runs a server and a client process side by side, each with its own copy
    of everything — which is where "it eats all my memory" comes from. The map is by far
    the largest thing in the world and Roblox streams it on demand perfectly well, so
    preloading it buys a test session nothing and costs it the most.

    Published servers still preload the lot; players there only run one process, and the
    smoother first impression is worth the memory.
]=]
if not game:GetService("RunService"):IsStudio() then
    addAssetsToLoad(workspace:GetDescendants())
end

addAssetsToLoad(game:GetService("ReplicatedStorage"):GetDescendants())
addAssetsToLoad(game:GetService("StarterPlayer"):GetDescendants())
addAssetsToLoad(game:GetService("StarterGui"):GetDescendants())

local assetAmount = #assets
local loaded = false
function updateProgress()
    if not loaded then
        -- The asset list is filtered now, so it can legitimately be empty on a bare place.
        -- Dividing by it would put "nan%" on the loading screen.
        if assetAmount <= 0 then
            Percent.Text = "100%"
            AmountTxt.Text = "(0/0)"
            return
        end

        Percent.Text = tostring(math.floor(#loadedAssets / assetAmount * 100 - 1)).."%"
        AmountTxt.Text = "("..tostring(#loadedAssets - 1).."/"..tostring(assetAmount)..")"
    end
end

local ContentProvider = game:GetService("ContentProvider")
for index, asset in assets do
    task.delay(index / (assetAmount / 0.75), function()
        ContentProvider:PreloadAsync({
            asset
        })
        table.insert(loadedAssets, asset)
        updateProgress()
    end)
end

local TweenService = game:GetService("TweenService")

--- Set when the player presses Skip. Stops the preload wait; does NOT skip initialization.
local Skipped = false
--- Longest the preload wait is allowed to take before the game gives up and carries on.
local MAX_PRELOAD_SECONDS = 45

--- Guard so `Finish` can only ever run once, however many paths reach it.
local Finished = false

local function Finish()
    if Finished then
        return
    end
    Finished = true

    if not game:GetService("RunService"):IsStudio() then
        --don't remove this or you'll get in trouble! salutations! (unless you mention the engine in the game's description)
        print(require(game:GetService("ReplicatedStorage").Modules.Utils).Credits)
    end
    
    task.spawn(function()
        require(game:GetService("ReplicatedStorage").Modules.Network):FireServerConnection("AddLoadedPlayer", "REMOTE_EVENT")
    end)

    loaded = true

    Percent.Text = "100%"
    AmountTxt.Text = "("..tostring(assetAmount).."/"..tostring(assetAmount)..")"

    TweenService:Create(CurrentlyInitting, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    TweenService:Create(Percent.UIStroke, TweenInfo.new(0.666), {
        Transparency = 1
    }):Play()
    TweenService:Create(Percent.UIStroke, TweenInfo.new(2), {
        Thickness = 20
    }):Play()
    TweenService:Create(AmountTxt.UIStroke, TweenInfo.new(0.666), {
        Transparency = 1
    }):Play()
    TweenService:Create(AmountTxt.UIStroke, TweenInfo.new(2), {
        Thickness = 20
    }):Play()
    TweenService:Create(Skip, TweenInfo.new(0.666), {
        TextTransparency = 1
    }):Play()
    task.wait(1)
    TweenService:Create(Percent, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    TweenService:Create(AmountTxt, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    task.wait(0.5)
    TweenService:Create(Main, TweenInfo.new(0.75), {
        BackgroundTransparency = 1
    }):Play()

    game:GetService("Debris"):AddItem(LoadingGui, 0.8)
    game:GetService("StarterGui"):SetCore("ResetButtonCallback", true)

    task.wait(0.8)

    workspace:SetAttribute("ClientLoaded", true)
end

task.delay(10, function()
    if not loaded and not Skipped then
        Skip.Visible = true
        TweenService:Create(Skip, TweenInfo.new(1), {
            TextTransparency = 0
        }):Play()

        --[[
            Skip only abandons the ASSET PRELOAD. It used to set `loaded = true` and call
            `Finish()` straight from here, which tore the loading screen down before the
            game had initialised anything.

            Everything below still has to run — `InitScripts` is what starts
            `PlayerInitter`, and therefore every UI menu and `CharacterInitter` (which is
            what calls `AnimationManager:Init()` on your character). Skipping past it left
            you with a playable-looking lobby, no walk animation and menus that wouldn't
            open.
        ]]
        Skip.MouseButton1Click:Once(function()
            Skipped = true
        end)
    end
end)

--[[
    Wait for the assets — but not forever, and not past a Skip.

    This condition used to read `... or loaded`, which is inverted: pressing Skip set
    `loaded = true` and made the condition permanently TRUE, so the loop never exited and
    NOTHING below this line ever ran. That single word is why skipping left the game
    half-alive.

    The deadline is new. Preloading walks every descendant of Workspace, ReplicatedStorage,
    StarterPlayer and StarterGui one at a time, so a big place can sit here for a very long
    while with no way out but the Skip button. Now it gives up on its own.
]]
local PreloadDeadline = time() + MAX_PRELOAD_SECONDS
while #loadedAssets < math.max(0, #assets - math.min(100, #assets * 0.1)) and not Skipped and time() < PreloadDeadline do
    task.wait()
end

if not Skipped and #loadedAssets < math.max(0, #assets - math.min(100, #assets * 0.1)) then
    warn(("[Loading] Gave up preloading after %ds (%d/%d assets). Carrying on — some textures may pop in."):format(MAX_PRELOAD_SECONDS, #loadedAssets, #assets))
end

--- Longest to wait for one initter before assuming it's never going to finish.
local MAX_INIT_SECONDS = 60

local function InitScripts(module: ModuleScript)
    local ModuleCode = require(module)
    task.spawn(function()
        ModuleCode:Init()
    end)

    --[[
        Bounded, because this used to be able to wait forever.

        `Loaded` is only set on the last line of an initter's loop, so anything that killed
        that loop partway left this spinning with the loading screen up and no way out but
        the Skip button. Both initters `pcall` their modules now, which should make that
        impossible — this is the backstop for when "should be impossible" turns out not to
        be, because a player staring at a frozen loading screen has no idea what to do.
    ]]
    local Deadline = time() + MAX_INIT_SECONDS

    while not ModuleCode.Loaded do
        if ModuleCode.CurrentlyInitting then
            CurrentlyInitting.Text = "Initializing "..ModuleCode.CurrentlyInitting.."..."
        else
            CurrentlyInitting.Text = ""
        end

        if time() > Deadline then
            warn(
                "[Loading] `"..module:GetFullName().."` didn't finish initialising within "..MAX_INIT_SECONDS..
                "s (stuck on \""..tostring(ModuleCode.CurrentlyInitting).."\"). Carrying on without it — "..
                "expect some UI to be missing."
            )
            break
        end

        task.wait()
    end
end

InitScripts(game:GetService("ReplicatedStorage").Initter)
InitScripts(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerInitter)

while not workspace:GetAttribute("ServerLoaded") do
    task.wait()
end

-- `Finish` guards against running twice on its own, so there's no early-return here any
-- more. There used to be one, and it meant a Skip could leave `ClientLoaded` never set.
Finish()
