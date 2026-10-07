--[=[
    PROXIMITY SHOP

    Opens the shop when you walk up to the shop kiosk in the lobby, and closes it when you
    walk away.

    WHAT WAS WRONG WITH IT
    ----------------------
    It looked for exactly one thing:

        workspace.Lobby["1x1x1x1 REWORK"]

    That model does not exist in this place. `getShopModelPosition()` therefore returned
    `nil` on every single pass, the loop `continue`d, and the shop was never opened by
    proximity — which on its own is survivable, because the sidebar button is the other way
    in.

    The damaging half was that this script ALSO owned the shop's lifecycle. It called
    `Shop.Toggle(false)` — which DESTROYS the shop's UI — whenever the player stopped being
    a spectator, duplicating work `SideBar` already does on every character spawn. Two
    owners tearing down and rebuilding the same menu on the same event is how you get a
    shop that exists on some spawns and not others.

    So this now does one job: open and close. Whether the shop EXISTS is `SideBar`'s
    business, and if there's no kiosk in the world this script simply stands down and lets
    the sidebar button be the way in.
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local SideBar = require(script.Parent.UI.SideBar)
local Shop = require(script.Parent.UI.Shop)
local PlayerInitter = require(script.Parent.PlayerInitter)

local PROXIMITY_RANGE = 12
local POLL_INTERVAL = 0.3

--[=[
    Names the kiosk might go by, in order of preference.

    A list rather than one hardcoded path because this is set dressing, and set dressing
    gets renamed and moved. Tagging a part `ShopKiosk` with CollectionService is the tidy
    option and is checked first.
]=]
local KIOSK_NAMES = {"ShopKiosk", "Shop", "1x1x1x1 REWORK"}

local function FindKiosk(): BasePart?
    for _, Tagged in CollectionService:GetTagged("ShopKiosk") do
        if Tagged:IsA("BasePart") then
            return Tagged
        end
        if Tagged:IsA("Model") then
            return Tagged.PrimaryPart or Tagged:FindFirstChildWhichIsA("BasePart", true)
        end
    end

    --[[
        Search the lobby first and the whole workspace second.

        Not `workspace` alone: the round map can legitimately contain something called
        "Shop", and opening the menu because you walked past a shopfront prop mid-fight
        would be worse than not having proximity at all.
    ]]
    local Roots = {workspace:FindFirstChild("Lobby"), workspace}

    for _, Root in Roots do
        if not Root then
            continue
        end

        for _, Name in KIOSK_NAMES do
            local Found = Root:FindFirstChild(Name, true)
            if not Found then
                continue
            end

            if Found:IsA("BasePart") then
                return Found
            end
            if Found:IsA("Model") then
                local Part = Found.PrimaryPart or Found:FindFirstChildWhichIsA("BasePart", true)
                if Part then
                    return Part
                end
            end
        end
    end

    return nil
end

local function IsSpectator(): boolean
    local Character = LocalPlayer.Character
    if not Character then
        return false
    end

    local Role = Character:FindFirstChild("Role")
    return Role ~= nil and Role:IsA("StringValue") and Role.Value == "Spectator"
end

local function IsAnotherMenuOpen(): boolean
    for Name, Menu in SideBar.MenuModules do
        if Name ~= "Shop" and Menu.Opened then
            return true
        end
    end
    return false
end

-- Wait for `PlayerInitter` to finish, so `Shop` and `SideBar` are both built.
while not PlayerInitter.Loaded do
    task.wait(0.5)
end

local Kiosk = FindKiosk()

if not Kiosk then
    --[[
        No kiosk, no proximity. Say so once and stop, rather than spinning a poll loop
        forever over a search that will never succeed.

        This is not an error: the sidebar's SHOP button works regardless, so a place with
        no kiosk model simply has one way into the shop instead of two.
    ]]
    print("[ProximityShop] No shop kiosk in the world, so walk-up shopping is off — the sidebar's SHOP button still works. Tag a part `ShopKiosk`, or name one of "..table.concat(KIOSK_NAMES, " / ").." inside Workspace.Lobby, to turn it back on.")
    return
end

while task.wait(POLL_INTERVAL) do
    if not Kiosk.Parent then
        Kiosk = FindKiosk()
        if not Kiosk then
            break
        end
    end

    -- `Shop.Open` refuses when the player isn't a spectator anyway, but checking here
    -- saves running the distance maths for every fighter in every round.
    if not IsSpectator() or not Shop.UIInstance then
        continue
    end

    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not Root then
        continue
    end

    local Distance = ((Root :: BasePart).Position - Kiosk.Position).Magnitude

    if Distance <= PROXIMITY_RANGE then
        if not Shop.Opened and not IsAnotherMenuOpen() then
            SideBar.CloseAll(Shop)
            Shop.Open(0.5)
        end
    elseif Shop.Opened then
        Shop.Close(0.5)
    end
end
