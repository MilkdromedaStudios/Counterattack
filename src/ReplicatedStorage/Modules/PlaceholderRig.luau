--[=[
    PLACEHOLDER RIG

    Builds a classic Roblox noob — yellow head and arms, blue torso, green legs — for any
    character whose real model hasn't been made yet.

    Every killer on the roster ships as a script, but the models are built by hand. Rather
    than refusing to spawn somebody whose rig doesn't exist, the game gives them this body
    and carries on. They still play the character they actually picked: their abilities,
    health, speed, animations and stats are all the real ones. Only the body is a stand-in.

    It's built from code rather than stored as a Studio asset so it can never go missing,
    and it's a standard R6 rig with the canonical Motor6D joints, which means the engine's
    R6 animations drive it correctly.

    Delete a character's placeholder simply by building its real model — the game prefers
    a real rig whenever one exists.
]=]

local PlaceholderRig = {}

--- The classic noob palette.
local Colors = {
    Head = BrickColor.new("Bright yellow"),
    Torso = BrickColor.new("Bright blue"),
    ["Left Arm"] = BrickColor.new("Bright yellow"),
    ["Right Arm"] = BrickColor.new("Bright yellow"),
    ["Left Leg"] = BrickColor.new("Br. yellowish green"),
    ["Right Leg"] = BrickColor.new("Br. yellowish green"),
}

--- R6 body part sizes.
local Sizes = {
    HumanoidRootPart = Vector3.new(2, 2, 1),
    Head = Vector3.new(2, 1, 1),
    Torso = Vector3.new(2, 2, 1),
    ["Left Arm"] = Vector3.new(1, 2, 1),
    ["Right Arm"] = Vector3.new(1, 2, 1),
    ["Left Leg"] = Vector3.new(1, 2, 1),
    ["Right Leg"] = Vector3.new(1, 2, 1),
}

--[=[
    The canonical R6 joint table.

    These `C0`/`C1` values are the exact ones Roblox uses on a real R6 character, written
    in the 12-argument `CFrame.new(x, y, z, R00…R22)` form. They have to be exact — R6
    animation data is authored against these offsets, so an approximation here shows up as
    limbs bending from the wrong pivot.
]=]
local Joints = {
    {
        Name = "RootJoint",
        Part0 = "HumanoidRootPart",
        Part1 = "Torso",
        C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
        C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
    },
    {
        Name = "Neck",
        Part0 = "Torso",
        Part1 = "Head",
        C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
        C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
    },
    {
        Name = "Right Shoulder",
        Part0 = "Torso",
        Part1 = "Right Arm",
        C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
    },
    {
        Name = "Left Shoulder",
        Part0 = "Torso",
        Part1 = "Left Arm",
        C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
    },
    {
        Name = "Right Hip",
        Part0 = "Torso",
        Part1 = "Right Leg",
        C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
    },
    {
        Name = "Left Hip",
        Part0 = "Torso",
        Part1 = "Left Leg",
        C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
    },
}

--- Creates one body part with the properties every R6 limb shares.
local function MakePart(name: string): Part
    local Part = Instance.new("Part")
    Part.Name = name
    Part.Size = Sizes[name]
    Part.BrickColor = Colors[name] or BrickColor.new("Bright yellow")
    Part.Material = Enum.Material.Plastic
    Part.TopSurface = Enum.SurfaceType.Smooth
    Part.BottomSurface = Enum.SurfaceType.Smooth
    -- Collidable, like a real character. The visible limbs are what the Humanoid stands
    -- on — make everything non-collidable and the rig falls through the map.
    -- `HumanoidRootPart` is the one exception and is turned off in `Build`.
    Part.CanCollide = true

    return Part
end

--[=[
    Builds a placeholder character.

    @param displayName The character this is standing in for. Shown on the name tag so
                       ten identical noobs are still tellable apart while you build.
    @return A complete R6 model, unparented, with its `PrimaryPart` set.
]=]
function PlaceholderRig.Build(displayName: string?): Model
    local Char = Instance.new("Model")
    Char.Name = displayName or "Placeholder"

    -- Root. Invisible and non-collidable, exactly as on a real character — it's the
    -- anchor the animations and the engine's hitboxes hang off, not a collider.
    local Root = MakePart("HumanoidRootPart")
    Root.Transparency = 1
    Root.CanCollide = false
    Root.Parent = Char
    Char.PrimaryPart = Root

    -- Torso
    local Torso = MakePart("Torso")
    Torso.Parent = Char

    -- Head, with the classic oversized mesh and face
    local Head = MakePart("Head")
    Head.Parent = Char

    local HeadMesh = Instance.new("SpecialMesh")
    HeadMesh.MeshType = Enum.MeshType.Head
    HeadMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
    HeadMesh.Parent = Head

    local Face = Instance.new("Decal")
    Face.Name = "face"
    Face.Texture = "rbxasset://textures/face.png"
    Face.Face = Enum.NormalId.Front
    Face.Parent = Head

    -- Limbs
    for _, name in {"Left Arm", "Right Arm", "Left Leg", "Right Leg"} do
        MakePart(name).Parent = Char
    end

    -- Humanoid. R6 specifically, because the engine's animations are R6.
    local Humanoid = Instance.new("Humanoid")
    Humanoid.RigType = Enum.HumanoidRigType.R6
    Humanoid.Parent = Char

    local Animator = Instance.new("Animator")
    Animator.Parent = Humanoid

    -- Wire the skeleton up.
    for _, Joint in Joints do
        local Motor = Instance.new("Motor6D")
        Motor.Name = Joint.Name
        Motor.Part0 = Char:FindFirstChild(Joint.Part0)
        Motor.Part1 = Char:FindFirstChild(Joint.Part1)
        Motor.C0 = Joint.C0
        Motor.C1 = Joint.C1
        -- Roblox parents RootJoint to the HumanoidRootPart and every other joint to the Torso.
        Motor.Parent = Joint.Name == "RootJoint" and Root or Torso
    end

    -- Marks this as a stand-in, so anything that cares can tell (and so you can spot
    -- them in the explorer at a glance).
    Char:SetAttribute("PlaceholderRig", true)

    PlaceholderRig._AddNameTag(Char, displayName)

    return Char
end

--[=[
    Floats the character's name above its head.

    Without this, a lobby of placeholders is ten identical noobs and you can't tell who
    is meant to be Verity and who is meant to be Nuker.
]=]
function PlaceholderRig._AddNameTag(char: Model, displayName: string?)
    local Head = char:FindFirstChild("Head")
    if not Head then
        return
    end

    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "PlaceholderNameTag"
    Billboard.Size = UDim2.new(0, 200, 0, 44)
    Billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
    Billboard.AlwaysOnTop = true
    Billboard.MaxDistance = 120
    Billboard.Parent = Head

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.fromScale(1, 0.6)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.GothamBold
    Label.Text = displayName or "Placeholder"
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextScaled = true
    Label.Parent = Billboard

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(0, 0, 0)
    Stroke.Thickness = 2
    Stroke.Parent = Label

    local Sub = Instance.new("TextLabel")
    Sub.Position = UDim2.fromScale(0, 0.6)
    Sub.Size = UDim2.fromScale(1, 0.4)
    Sub.BackgroundTransparency = 1
    Sub.Font = Enum.Font.Gotham
    Sub.Text = "no model yet"
    Sub.TextColor3 = Color3.fromRGB(255, 210, 90)
    Sub.TextScaled = true
    Sub.Parent = Billboard

    local SubStroke = Instance.new("UIStroke")
    SubStroke.Color = Color3.fromRGB(0, 0, 0)
    SubStroke.Thickness = 2
    SubStroke.Parent = Sub
end

return PlaceholderRig
