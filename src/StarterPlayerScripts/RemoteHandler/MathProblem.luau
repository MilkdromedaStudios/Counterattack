--[=[
    MATH PROBLEM

    The little quiz Baldi puts on your screen.

    WHY IT IS A REAL PROMPT
    ----------------------
    It would have been much easier to make "Math Problem" a debuff with a maths-themed name,
    and it would have missed the point entirely. The character is from a game about being
    asked questions and getting them wrong, so the ability has to actually ask you one.

    HOW IT STAYS FAIR
    -----------------
      * IT DOES NOT PAUSE THE GAME. No input is captured, the mouse is not locked, nothing is
        modal. You can ignore it completely and keep running — ignoring it simply counts as
        getting it wrong, which is the honest outcome.
      * THE SUMS ARE EASY ON PURPOSE. Single-digit arithmetic. It is a two-second decision
        under pressure, not a test.
      * THE PENALTY IS INFORMATION, NOT DAMAGE. Getting it wrong marks you and speeds Baldi
        up against you for a few seconds. Getting it right does nothing at all, which is the
        reward.

    SECURITY
    --------
    The client is sent the question and three answers and nothing else. It replies with an
    INDEX. The server knows which index is correct and checks the reply against the token it
    issued, so a client cannot answer a question it was not asked, answer twice, answer
    somebody else's question, or tell the server it was right.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)

local LocalPlayer = Players.LocalPlayer

--- The prompt currently on screen, so a second question replaces it instead of stacking.
local Current: ScreenGui? = nil

local function Clear()
    if Current then
        Current:Destroy()
        Current = nil
    end
end

--[=[
    Builds the prompt.

    Procedural, like the buy window and for the same reason: a Studio asset that can go
    missing turns an ability into a silent no-op, and this one has to work in any copy of the
    project.
]=]
local function Build(question: string, choices: {string}, seconds: number, answer: (index: number?) -> ())
    Clear()

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "MathProblem"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    -- Below the menus, above the HUD.
    Gui.DisplayOrder = 6
    Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    Current = Gui

    local Panel = Instance.new("Frame")
    Panel.AnchorPoint = Vector2.new(0.5, 0)
    Panel.Position = UDim2.fromScale(0.5, 0.08)
    Panel.Size = UDim2.fromScale(0.3, 0.16)
    Panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    Panel.BorderSizePixel = 0
    Panel.Parent = Gui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Panel

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(80, 200, 110)
    Stroke.Thickness = 2
    Stroke.Parent = Panel

    local Prompt = Instance.new("TextLabel")
    Prompt.Size = UDim2.fromScale(1, 0.45)
    Prompt.BackgroundTransparency = 1
    Prompt.Font = Enum.Font.GothamBold
    Prompt.Text = question
    Prompt.TextColor3 = Color3.fromRGB(255, 255, 255)
    Prompt.TextScaled = true
    Prompt.Parent = Panel

    local PromptSize = Instance.new("UITextSizeConstraint")
    PromptSize.MaxTextSize = 30
    PromptSize.Parent = Prompt

    --- The timer bar. The only pressure the prompt applies.
    local Bar = Instance.new("Frame")
    Bar.Position = UDim2.fromScale(0, 0.45)
    Bar.Size = UDim2.fromScale(1, 0.05)
    Bar.BackgroundColor3 = Color3.fromRGB(80, 200, 110)
    Bar.BorderSizePixel = 0
    Bar.Parent = Panel

    local Answered = false

    local function Resolve(index: number?)
        if Answered then
            return
        end
        Answered = true

        answer(index)

        -- Flash and go, so there is feedback that the click registered.
        TweenService:Create(Panel, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        task.delay(0.25, Clear)
    end

    for Index, Text in choices do
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.fromScale(0.3, 0.38)
        Button.Position = UDim2.fromScale(0.035 + (Index - 1) * 0.325, 0.56)
        Button.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
        Button.BorderSizePixel = 0
        Button.Font = Enum.Font.GothamBold
        Button.Text = Text
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextScaled = true
        Button.Parent = Panel

        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 6)
        ButtonCorner.Parent = Button

        local ButtonSize = Instance.new("UITextSizeConstraint")
        ButtonSize.MaxTextSize = 24
        ButtonSize.Parent = Button

        Button.MouseButton1Click:Connect(function()
            Resolve(Index)
        end)
    end

    TweenService:Create(Bar, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(0, 0.05)}):Play()

    --[[
        Timeout counts as a wrong answer, reported as `nil`.

        Reporting it rather than going silent matters: the server is holding a pending token
        for this question, and a question that is never answered either way would keep that
        entry alive until its own expiry. Answering `nil` closes it immediately and, more
        importantly, means ignoring the prompt has a defined consequence instead of being
        the strictly best play.
    ]]
    task.delay(seconds, function()
        Resolve(nil)
    end)
end

return function()
    Network:SetConnection("MathProblem", "REMOTE_EVENT", function(token: string, question: string, choices: {string}, seconds: number)
        if typeof(token) ~= "string" or typeof(question) ~= "string" or typeof(choices) ~= "table" then
            return
        end

        -- Sanity-check the payload before building UI out of it.
        if #choices < 2 or #choices > 4 then
            return
        end

        local Safe = {}
        for _, Choice in choices do
            table.insert(Safe, tostring(Choice):sub(1, 8))
        end

        Build(question:sub(1, 48), Safe, math.clamp(tonumber(seconds) or 5, 2, 10), function(index: number?)
            Network:FireServerConnection("MathProblemAnswer", "REMOTE_EVENT", token, index)
        end)
    end)

    -- A new round, or a death, should not leave a question hanging on screen.
    Network:SetConnection("MathProblemClear", "REMOTE_EVENT", Clear)
end
