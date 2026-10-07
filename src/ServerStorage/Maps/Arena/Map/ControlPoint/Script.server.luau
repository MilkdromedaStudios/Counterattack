--Made by Stickmasterluke


local ControlPoint = script.Parent

wait()		--Just because. Because when I clone in solo, new parts get created in wrong spot. This fixes.

function WaitForChild(parent, instance)
	while parent:FindFirstChild(instance) == nil do 
		parent.ChildAdded:wait()
	end
	return parent:FindFirstChild(instance)
end 


local RATE = 1/30												--The refresh rate
local MAX_HEIGHT = 300
local BILLBOARD_STEPS = 50
local TIME_TO_CAPTURE = 10
local POINT_AWARD_RATE = 10 									--Awards the controlling team a point at this rate

local TeamsService = Game:GetService('Teams')
local PlayersService = Game:GetService('Players')

local EventFeed = WaitForChild(game.Workspace, 'EventFeed')
local AddCustomEvent = WaitForChild(EventFeed, 'AddCustomEvent')
local Zone = WaitForChild(ControlPoint, 'Zone')
local billboard = WaitForChild(Zone, 'BillboardGui')
local ScoreText = WaitForChild(billboard, 'TextLabel')
local pad = WaitForChild(ControlPoint, 'Pad')
WaitForChild(pad,'Mesh')

local PercentControl
local ControllingTeamName
local ControllingTeamColor
local ControllingTeamPlayerCount
local TotalPlayerCount
local PlayersCapturingByTeam

local PlayersCapturingByTeam

local ControlPointName = "a control point"			--Name of control point; this will be in the kill feed
local radius = (Zone.Size.x + Zone.Size.z) * 0.25			--The radius to capture the point


local PercentControl = 1

function RayIgnoreCheck(hit)
	if hit then
		if hit.Transparency >= 1 or string.lower(string.gsub(hit.Name,1,6)) == "effect" or hit:IsDescendantOf(ControlPoint) then
			return true
		end
	end
	return false
end

function RayCast(startPos, vec, rayLength)	-- Ignore any ">1000 length" warnings that pop up when running this function.
	local hitObject, hitPos = game.Workspace:FindPartOnRay(Ray.new(startPos + (vec * .01), vec * rayLength), Handle)
	if hitObject and hitPos then
		local distance = rayLength - (hitPos - startPos).magnitude
		if RayIgnoreCheck(hitObject) and distance > 0 then
			-- there is a chance here for potential infinite recursion. (Don't call rayLength as math.huge)
			return RayCast(hitPos, vec, distance)
		end
	end
	return hitObject, hitPos
end

------------------------------------------Set pillar height
local RayHit, RayEnd = RayCast(pad.Position, Vector3.new(0,1,0), 1000)
local height = math.min(MAX_HEIGHT, (pad.Position - RayEnd).magnitude)
------------------------------------------

local padlight
if ControlPoint:FindFirstChild('Padlight') then
	padlight = ControlPoint.Padlight
else
	padlight = pad:Clone()
end
padlight.Name = 'Padlight'
padlight.CanCollide = false
padlight.Parent = ControlPoint

local highlight
if ControlPoint:FindFirstChild('Highlight') then
	highlight = ControlPoint.Highlight
else
	highlight = pad:Clone()
end
highlight.Name = 'Highlight'
highlight.CanCollide = false
highlight.Transparency = .75
highlight.Mesh.Offset = Vector3.new(0, height*.5, 0)
highlight.Parent = ControlPoint

pad.BrickColor = BrickColor.new("Institutional white")
billboard.Enabled = false

local function ResizeHighlight(PercentControl, height)
	padlight.Mesh.Scale = pad.Mesh.Scale * Vector3.new(PercentControl, 1, PercentControl) * 1.01
	highlight.Mesh.Scale = pad.Mesh.Scale * Vector3.new(PercentControl, height * (1 / highlight.Size.y), PercentControl)
end

ResizeHighlight(PercentControl, height)

---------Awarding points to controlling teams---------
Spawn(function()		-- This creates a coroutine
	while true do
		wait(POINT_AWARD_RATE)
		local AwardTeam = nil
		for _, CheckTeam in ipairs(TeamsService:GetTeams()) do
			if CheckTeam.TeamColor == padlight.BrickColor then
				CheckTeam.Score = CheckTeam.Score + 1
				ScoreText.TextColor3 = padlight.BrickColor.Color
				Spawn(function()
					ScoreText.TextStrokeTransparency = 0
					ScoreText.TextTransparency = 0
					billboard.StudsOffset = Vector3.new(0, 5, 0)
					billboard.Enabled=true
					for i = 1, BILLBOARD_STEPS do
						wait(RATE)
						local percent = i / BILLBOARD_STEPS
						billboard.StudsOffset = Vector3.new(0, 5 + (percent * 5), 0)
						ScoreText.TextStrokeTransparency = percent
						ScoreText.TextTransparency = percent
					end
					billboard.Enabled=false
				end)
			end
		end
	end
end)
------------------------------------------------------

local function IsPlayerWithinCaptureRadius(player, capturePosition, captureRadius)
	if player and player.Character ~= nil then
		local torso = player.Character:FindFirstChild('Torso')
		local humanoid = player.Character:FindFirstChild('Humanoid')
		if torso ~= nil and humanoid~=nil and humanoid.Health > 0 then
			return torso.Position.y > capturePosition.y and (torso.Position - capturePosition).magnitude < radius
		end
	end
	return false
end

local function FindTeam(color)
	for _, team in ipairs(PlayersCapturingByTeam) do
		if team.color == color then
			return team
		end
	end
	local team = {color = color, players = {}}
	table.insert(PlayersCapturingByTeam,team)
	return team
end



while true do
	wait(RATE)
	-- Each tick reset the team table so we can recalcuate it
	PlayersCapturingByTeam = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		if IsPlayerWithinCaptureRadius(player, Zone.Position, radius + 2) then
			local team = FindTeam(player.TeamColor)
			table.insert(team.players, player.Name)
		end
	end

	ControllingTeamColor = BrickColor.new('Medium stone grey')		----Determining top team
	ControllingTeamPlayerCount = 0
	TotalPlayerCount = 0
	for _, team in ipairs(PlayersCapturingByTeam) do
		TotalPlayerCount = TotalPlayerCount + #team.players
		if #team.players > ControllingTeamPlayerCount then
			ControllingTeamColor = team.color
			ControllingTeamPlayerCount = #team.players
		end
	end

	if TotalPlayerCount >= 1 then
		local influence = ControllingTeamPlayerCount - (TotalPlayerCount - ControllingTeamPlayerCount)
		if influence >= 1 then
			if padlight.BrickColor == ControllingTeamColor then
				if PercentControl < 1 then
					PercentControl = PercentControl + ((RATE / TIME_TO_CAPTURE) * influence)
				end
			else
				PercentControl = PercentControl - ((RATE / TIME_TO_CAPTURE) * influence)
			end
			if PercentControl > 1 then
				PercentControl = 1
			elseif PercentControl < 0 then		--Take over
				padlight.BrickColor = ControllingTeamColor
				highlight.BrickColor = ControllingTeamColor
				PercentControl = 0
				ControllingTeamName = ""
				for _, team in ipairs(TeamsService:GetTeams()) do
					if team.TeamColor == ControllingTeamColor then
						ControllingTeamName = team.Name .. "#"
					end
				end
				if ControllingTeamName ~= "" then
					AddCustomEvent:Invoke(ControllingTeamName,'['..tostring(ControllingTeamColor.Number)..']'," captured "..ControlPointName.."!")
				else
					AddCustomEvent:Invoke(ControlPointName.." has been captured!")
				end
			end
			ResizeHighlight(PercentControl, height)
		end
	end
end




