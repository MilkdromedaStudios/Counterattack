--[=[
    THE WEATHER MACHINE

    The physical machine in the world that decides HOW MUCH weather a round gets. Charge
    it and the next round runs several events at once instead of one.

    WHY THIS REPLACES THE NDS SCRIPTS
    ---------------------------------
    NDS's machine came with two scripts, `Weather Machine Power` and `OrbSpinyScript`, and
    both of them open with a run of `WaitForChild` calls:

        local powerLevelTag = sp:WaitForChild('PowerLevel')
        local screenFrame = sp:WaitForChild('Screen'):WaitForChild('SurfaceGui'):WaitForChild('TextLabelFull')
        local emitter1 = sp:WaitForChild('Stacks'):WaitForChild('Union1'):WaitForChild('ParticleEmitter')
        ...

    Every one of those is mandatory. The machine model in this repository is a stub — a
    Globe and a couple of scripts — so the very first `WaitForChild` never returns and the
    script hangs there forever. It doesn't error, it doesn't warn, it just silently never
    reaches the line that would make the machine do anything. That is the whole of "the
    weather machine doesn't work".

    They also drove NOTHING but themselves: `PowerLevel` was read by NDS's MainScript, which
    isn't running here, so even a fully-built machine had no effect on this game.

    This script fixes both halves. EVERY part of the machine is optional — it lights up
    whatever it finds and ignores what it doesn't — and the power level it manages is the
    one `Runner` actually reads. A machine that is missing its screen still works; a world
    with no machine at all still gets weather, just one event at a time.
]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local MachineConfig = Config.Machine

if not Config.Enabled or not RunService:IsServer() then
    return
end

local Machine = {
    Model = nil :: Instance?,
    Power = 0,
}

local function Log(...)
    if Config.Debug then
        print("[WeatherMachine]", ...)
    end
end

--------------------------------------------------------------------------------
-- FINDING THE MACHINE
--------------------------------------------------------------------------------

--[=[
    Looks for the machine anywhere in the workspace.

    A recursive search rather than a fixed path on purpose: the machine is set dressing and
    people move set dressing. It can sit in the lobby, in a map, or at the top level — and
    it can be tagged `WeatherMachine` instead of named it, which is the tidier option when
    you have more than one.
]=]
local function FindMachine(): Instance?
    local Tagged = CollectionService:GetTagged(MachineConfig.ModelName)
    if Tagged[1] then
        return Tagged[1]
    end

    --[[
        Skip anything under `Workspace.NDS`.

        That folder is on its way to ReplicatedStorage, and while it's still here it holds
        a SECOND machine model — adopting that one would light up a machine nobody can
        reach standing on an island the game no longer uses.
    ]]
    local NDS = workspace:FindFirstChild("NDS")

    for _, Descendant in workspace:GetDescendants() do
        if Descendant.Name ~= MachineConfig.ModelName then
            continue
        end
        if not Descendant:IsA("Model") and not Descendant:IsA("Folder") then
            continue
        end
        if NDS and Descendant:IsDescendantOf(NDS) then
            continue
        end
        return Descendant
    end

    return nil
end

--[=[
    Switches off NDS's own machine scripts wherever they are inside the model we adopt.

    Left enabled they sit forever on a `WaitForChild` that will never resolve, holding a
    thread each and — the moment somebody DOES finish building the model — start fighting
    this script over the same `PowerLevel`, the same screen and the same globe.
]=]
local function DisableLegacyScripts(Model: Instance)
    for _, Descendant in Model:GetDescendants() do
        if not Descendant:IsA("BaseScript") then
            continue
        end

        if Descendant.Name == "Weather Machine Power" or Descendant.Name == "OrbSpinyScript" then
            Descendant.Enabled = false
            Log("disabled legacy script", Descendant:GetFullName())
        end
    end
end

--------------------------------------------------------------------------------
-- COSMETICS — EVERY ONE OF THESE IS OPTIONAL
--------------------------------------------------------------------------------

local ENGINE_COLORS = {
    [0] = Color3.fromRGB(27, 42, 53),
    [1] = Color3.fromRGB(128, 187, 219),
    [2] = Color3.fromRGB(177, 167, 255),
    [3] = Color3.fromRGB(180, 128, 255),
    [4] = Color3.fromRGB(255, 152, 220),
    [5] = Color3.fromRGB(255, 137, 100),
    [6] = Color3.fromRGB(196, 40, 28),
    [7] = Color3.fromRGB(255, 0, 0),
    [8] = Color3.fromRGB(0, 255, 255),
    [9] = Color3.fromRGB(0, 255, 0),
}

--- Depth-first search by name that never throws and never yields.
local function Find(Root: Instance?, ...: string): Instance?
    local Current = Root
    for _, Name in {...} do
        if not Current then
            return nil
        end
        Current = Current:FindFirstChild(Name, true)
    end
    return Current
end

local function UpdateCosmetics(Model: Instance, Power: number)
    local Screen = Find(Model, "TextLabelFull") or Find(Model, "PowerLabel")
    if Screen and (Screen:IsA("TextLabel") or Screen:IsA("TextBox")) then
        Screen.Text = tostring(Power)
    end

    for Index, Name in {"Tube1", "Tube2", "Tube3", "Tube4"} do
        local Tube = Model:FindFirstChild(Name, true)
        if Tube and Tube:IsA("BasePart") then
            local Lit = Power >= Index * 2 - 1
            Tube.Color = Lit and Color3.fromRGB(4, 175, 236) or Color3.fromRGB(159, 195, 226)
            Tube.Material = Lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
        end
    end

    local Engine = Model:FindFirstChild("EngineColor", true)
    if Engine and Engine:IsA("BasePart") then
        Engine.Color = ENGINE_COLORS[math.clamp(math.floor(Power), 0, 9)]
        Engine.Material = Power > 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic
    end

    local Stacks = Model:FindFirstChild("Stacks", true)
    if Stacks then
        local Index = 0
        for _, Descendant in Stacks:GetDescendants() do
            if not Descendant:IsA("ParticleEmitter") then
                continue
            end
            Index += 1
            Descendant.Enabled = Power >= Index * 2
        end
    end

    local Globe = Model:FindFirstChild("Globe", true)
    if Globe then
        local Spin = Globe:FindFirstChild("SpinGlobeEnabled")
        if Spin and Spin:IsA("BoolValue") then
            Spin.Value = Power > 0
        end
    end
end

--[=[
    Spins the globe's rings.

    NDS did this with BodyPosition and BodyAngularVelocity on unanchored unions, which is
    a physics simulation running forever for a decoration and which drifts apart if
    anything ever touches it. Rotating anchored parts in place costs nothing and can't come
    off its mounting.
]=]
local function DriveGlobe(Model: Instance)
    local Globe = Model:FindFirstChild("Globe", true)
    if not Globe then
        return
    end

    local Rings = {}
    for _, Descendant in Globe:GetDescendants() do
        if Descendant:IsA("BasePart") and Descendant.Name:find("SpinningRing") then
            Descendant.Anchored = true
            table.insert(Rings, {
                Part = Descendant,
                Axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit,
                Speed = 0.4 + math.random() * 0.8,
                Origin = Descendant.CFrame,
            })
        end
    end

    if #Rings == 0 then
        return
    end

    local Angle = 0
    RunService.Heartbeat:Connect(function(Delta: number)
        if Machine.Power <= 0 then
            return
        end

        Angle += Delta
        for _, Ring in Rings do
            Ring.Part.CFrame = Ring.Origin * CFrame.fromAxisAngle(Ring.Axis, Angle * Ring.Speed * Machine.Power)
        end
    end)
end

--------------------------------------------------------------------------------
-- POWER
--------------------------------------------------------------------------------

local function SetPower(Value: number)
    Machine.Power = math.clamp(math.floor(Value), 0, MachineConfig.MaxPower)

    -- The attribute is the real contract — `Runner` reads this and nothing else. The
    -- `PowerLevel` value below is kept in step for anything in the map that watches it,
    -- including NDS's own screens if somebody re-enables them.
    workspace:SetAttribute("WeatherPower", Machine.Power)

    if Machine.Model then
        local Tag = Machine.Model:FindFirstChild("PowerLevel", true)
        if Tag and Tag:IsA("IntValue") then
            Tag.Value = Machine.Power
        end

        UpdateCosmetics(Machine.Model, Machine.Power)
    end

    Log("power", Machine.Power)
end

local function Charge(By: number?)
    local Before = Machine.Power
    SetPower(Machine.Power + (By or 1))

    if Machine.Power > Before and Machine.Model then
        local Sound = Machine.Model:FindFirstChild("PowerUpSound", true)
        if Sound and Sound:IsA("Sound") then
            Sound:Play()
        end
    end
end

--------------------------------------------------------------------------------
-- SETUP
--------------------------------------------------------------------------------

--[[
    `WeatherPower` is published before the machine is even looked for.

    `Runner` reads it on its very first cycle, and an unset attribute means the weather
    would run at the default anyway — but publishing a real zero here means the value is
    always a number, so nothing downstream has to guess whether "nil" meant off or unbuilt.
]]
workspace:SetAttribute("WeatherPower", 0)

local Model = FindMachine()

if not Model then
    Log("no machine model in the workspace — the weather will run at "..Config.BaseSimultaneousEvents.." event(s) per round.")
else
    Machine.Model = Model
    DisableLegacyScripts(Model)
    DriveGlobe(Model)
    Log("adopted", Model:GetFullName())

    if MachineConfig.AllowManualCharge then
        --[[
            The prompt goes on the machine's own primary part when it has one, and on its
            largest part otherwise.

            "Largest" rather than "first": `GetDescendants` order is arbitrary, and on a
            model like this the first part is as likely to be a bolt on the back as the
            console on the front. The biggest part is reliably the body of the thing.
        ]]
        local Anchor = (Model :: any).PrimaryPart
        if not Anchor then
            local Best, BestVolume = nil, 0
            for _, Descendant in Model:GetDescendants() do
                if not Descendant:IsA("BasePart") then
                    continue
                end
                local Volume = Descendant.Size.X * Descendant.Size.Y * Descendant.Size.Z
                if Volume > BestVolume then
                    Best, BestVolume = Descendant, Volume
                end
            end
            Anchor = Best
        end

        if Anchor then
            local Prompt = Instance.new("ProximityPrompt")
            Prompt.Name = "ChargeWeatherMachine"
            Prompt.ActionText = "Charge"
            Prompt.ObjectText = "Weather Machine"
            Prompt.HoldDuration = MachineConfig.ChargeTime
            Prompt.MaxActivationDistance = 12
            Prompt.RequiresLineOfSight = false
            Prompt.Parent = Anchor

            Prompt.Triggered:Connect(function()
                if Machine.Power >= MachineConfig.MaxPower then
                    return
                end
                Charge(1)
            end)
        else
            Log("machine has no parts, so there's nowhere to put the charge prompt.")
        end
    end
end

SetPower(0)

--------------------------------------------------------------------------------
-- DRAIN
--------------------------------------------------------------------------------

if MachineConfig.DrainPerRound > 0 then
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RoundInfo = ReplicatedStorage:WaitForChild("RoundInfo", 30)
    local RoundState = RoundInfo and RoundInfo:FindFirstChild("CurrentState")

    if RoundState and RoundState:IsA("StringValue") then
        local WasInRound = RoundState.Value == "InRound"

        RoundState.Changed:Connect(function(State: string)
            -- Drain on the round ENDING, not on it starting. Charging during the
            -- intermission is the point of the machine; spending it at the start of the
            -- round and then draining again would cost two levels per round.
            if WasInRound and State ~= "InRound" then
                SetPower(Machine.Power - MachineConfig.DrainPerRound)
            end
            WasInRound = State == "InRound"
        end)
    end
end

--------------------------------------------------------------------------------
-- ADMIN HOOK
--------------------------------------------------------------------------------

--[=[
    `workspace:SetAttribute("WeatherPower", n)` from the command bar or the mod panel sets
    the power directly, so the weather can be turned up for testing without walking over to
    the machine and holding E nine times.
]=]
workspace:GetAttributeChangedSignal("WeatherPower"):Connect(function()
    local Value = workspace:GetAttribute("WeatherPower")
    if typeof(Value) == "number" and math.floor(Value) ~= Machine.Power then
        SetPower(Value)
    end
end)
