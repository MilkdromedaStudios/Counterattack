--Made by Stickmasterluke
	--OLD CODE


local sp = script.Parent

local debris = game:GetService("Debris")

local baseupvelocity = 40
local variety = 15
local colors = {"Bright blue", "Medium blue", "Pastel Blue"}

local originalPosition = Vector3.new(0,0,0)


wait(1)
if sp and sp.Parent then
	originalPosition = sp.Position
end

while sp and sp.Parent and ((sp.Position-originalPosition).magnitude<2) do
	local p = Instance.new("Part")
	p.Name = "FountainWater"
	p.formFactor = "Symmetric"
	p.Shape = "Ball"
	p.Material = 'Foil'
	p.Transparency = .5
	if math.random()<.5 then
		p.CanCollide = false
	end
	p.Size = Vector3.new(1,1,1)
	p.BrickColor = BrickColor.new(colors[math.random(1,#colors)])
	p.TopSurface = "Smooth"
	p.BottomSurface = "Smooth"
	p.CFrame = CFrame.new(sp.Position+Vector3.new(0,1.5,0))
	p.Velocity = Vector3.new((math.random()-.5)*variety,baseupvelocity+((math.random()-.5)*variety),(math.random()-.5)*variety)
	p.RotVelocity = Vector3.new((math.random()-.5)*variety,(math.random()-.5)*variety,(math.random()-.5)*variety)
	p.Elasticity = 0
	p.Friction = 1
	debris:AddItem(p, 2.5)
	p.Parent = sp
	wait(.2+(math.random()*.1))
end



