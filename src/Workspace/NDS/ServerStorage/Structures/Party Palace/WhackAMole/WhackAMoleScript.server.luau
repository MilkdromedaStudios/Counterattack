--Made by Stickmasterluke


local sp = script.Parent

local clickDistance = 16
local difficultyCycle = 60 --seconds

wait(1)

local points = 0
local moles = {}
local startTime = tick()

for _,part in pairs(sp:GetChildren()) do
	if part.Name == 'Mole' then
		local clickDetector = part:FindFirstChild('ClickDetector')
		local hitSound = part:FindFirstChild('HitSound')
		if clickDetector and hitSound then
			table.insert(moles, part)
			clickDetector.MouseClick:connect(function()
				if part.Transparency == 0 and part.CanCollide then
					part.Transparency = 1
					part.CanCollide = false
					if hitSound then
						hitSound.Pitch = .8+math.random()*.4
						hitSound:Play()
					end
					if clickDetector then
						clickDetector.MaxActivationDistance = 0
					end
					points = points + 1
				end
			end)
		end
	end
end

while sp and sp.Parent and sp:IsDescendantOf(game.Workspace) do
	local difficulty = (math.sin(((startTime-tick())*math.pi)/difficultyCycle)+1)/2

	local adjustedDifficulty = .25+difficulty*.75
	if #moles > 0 then
		local mole = moles[math.random(#moles)]
		if mole then
			local clickDetector = mole:FindFirstChild('ClickDetector')
			if mole.CanCollide or mole.Transparency < 1 or not clickDetector then
				mole.CanCollide = false
				mole.Transparency = 1
				if clickDetector then
					clickDetector.MaxActivationDistance = 0
				end
			else
				mole.CanCollide = true
				mole.Transparency = 0
				clickDetector.MaxActivationDistance = clickDistance
				delay((2+math.random()*5)*adjustedDifficulty,function()
					if mole then
						mole.CanCollide = false
						mole.Transparency = 1
						if clickDetector then
							clickDetector.MaxActivationDistance = 0
						end
					end
				end)
			end
		end
	end
	wait((.5+math.random()*3)*adjustedDifficulty)
end


