 --Made by Stickmasterluke


--X Meteor Storm
--X Flash Flood		--clouds
--X Thunder Storm	--clouds
--X Fire
--X Tornado			--clouds
--X Tsunami


	--Seismic Update
--X Earthquake
--X Volcanic Eruption

	--Biohazard Update
--O Epidemic/Pandemic/zombie infection?
--X Acid Rain		--clouds


	--Storm Update
--X Sandstorm
--X Blizzard		--clouds
--O Avilanch		--clouds


--[[geographically impossible but still disaster possibilities
	-landslide
	-sinkhole
	-Iceburg/gracier
	-birds
	-Zoo escape
	-Swarm
]]


--[[God Damn Problems That I Cannot Fix List
	-Physics and networking bad. Clients are assigned physics to simulate when they don't have a good connection or enough processing.
	-Sound system fails. Random sounds cut out.
	-Guests looks fugly
]]

--[[Game ideas
	-buy back in midround
	-Double disaster rounds
		-Buy extra disaster for round
	-Fun random tools/gear left on the ground
		-snowboard,liferaft,umbrella,useless pizza
	-limied lives? most rounds played without dying?
	-end rounds when noone is left alive
]]

--[[
--No clue what this code does. Turning it off :O
local RBXEnv = getfenv(1)
setfenv(1, setmetatable({}, {
	__index = function(env, index)
		local rbxValue = RBXEnv[index]
		if rbxValue~=nil then
			return rbxValue
		else
			error("Luke attempted to get nil global `"..tostring(index).."`", 2)
		end
	end;
	__newindex = RBXEnv;
}))
]]


local oldcontent = game.Workspace:WaitForChild("ContentModel")

t10clipframe = game.Workspace:WaitForChild("BillboardTop10"):WaitForChild("Board"):WaitForChild("SurfaceGui"):WaitForChild("Clipframe")
t10template = t10clipframe:WaitForChild("TemplateLabel")

game:GetService("InsertService"):ApproveAssetId(0)
local marketPlaceService = game:GetService("MarketplaceService")
local badgeService = game:GetService("BadgeService")
local storage = game:GetService("ServerStorage")
local httpservice = game:GetService("HttpService")
local dataStoreService = game:GetService('DataStoreService')
local survivesDataStore = dataStoreService:GetDataStore('SurvivesData')
local pointsservice = game:GetService("PointsService")
local sharedstorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")
local event = sharedstorage:WaitForChild("Event")
local weatherMachineTag = game.Workspace:WaitForChild('WeatherMachine'):WaitForChild('PowerLevel')

local mapVotesStorage = sharedstorage:WaitForChild('MapVotes')
local mapVoteChoice1Tag = mapVotesStorage:FindFirstChild('Choice1')
local mapVoteChoice2Tag = mapVotesStorage:FindFirstChild('Choice2')
local mapVoteChoice3Tag = mapVotesStorage:FindFirstChild('Choice3')
local mapVoteChoices = {mapVoteChoice1Tag, mapVoteChoice2Tag, mapVoteChoice3Tag}

local balloonviptshirt = 66670555
local balloonPass = 118764786
local applePass = 184766955
local compassPass = 634643698
local powerUpMachineProductId = 36120455
local goldenGiftBadgeId = 581328195
local multiDisasterBadges = {
	['n2'] = 454956782,
	['n3'] = 454956889,
	['n4'] = 454957071,
	['n5'] = 454957253,
	['n6'] = 454957314,
	['n7'] = 454957377,
}


local disasters = {}
local powerUpPlayers = {}
local playersWins = {}

local mapradius=200
local rate=1/30
local disasterNumber = 0


--fire------------------------
local fireTemplate = storage:WaitForChild('Fire')
------------------------------

--meteors---------------------
local meteorTemplate = storage:WaitForChild('MeteorTemplate')
local meteorSizes = {2,5,10,12,15}
------------------------------

--tornado---------------------
tornadopos=Vector3.new(0,0,0)
maxhight=300
low=40
speed=100
push=.1
pull=-.5
lift=.25
breakradius=35
cycloneradius=10
------------------------------

--tsunami---------------------
wavedistance=2000
wavespeed=40
wavewidth=20
wavehight=50
wavelength=500
segmentradius=20
wavesegments=wavelength/segmentradius
------------------------------

--blizzard--------------------
blizfogend=500
blizfogstart=0
blizfogcolor=Color3.new(.9,.9,.9)
------------------------------




local lastDisaster = nil


local weatherdome = game.Workspace:WaitForChild("WeatherDome")

local quarterpi = math.pi*.25

local dirtpart=Instance.new("Part")
dirtpart.Material="Slate"
dirtpart.BrickColor=BrickColor.new("Brown")
dirtpart.formFactor="Custom"
dirtpart.Anchored=true
dirtpart.Name="VolcanoPart"

local ownage = {}
function setPlayerOwns(player, id, value)
	if not ownage["a"..id] then
		ownage["a"..id] = {}
	end
	ownage["a"..id][player] = value
end
function doesPlayerOwn(player, id)			--todo: cleanout when a player leaves
	if player and id and player.userId > 1 then
		if not ownage["a"..id] then
			ownage["a"..id] = {}
		end
		if ownage["a"..id][player] then
			return true
		elseif marketPlaceService:PlayerOwnsAsset(player,id) then
			ownage["a"..id][player] = true
			return true
		end
	end
	return false
end

function getSurvives(player)
	if player then
		local userId = player.UserId
		local cachedWins = playersWins['id'..userId] or 0
		if playersWins['id'..userId] then
			return cachedWins
		end
		local playerPointsWins = 0
		local playerPointsSuccess, playerPointsReturn = nil, nil
		spawn(function()
			playerPointsSuccess, playerPointsReturn = pcall(function()
				return pointsservice:GetGamePointBalance(userId)
			end)
			if playerPointsSuccess and playerPointsReturn then
				playerPointsWins = math.ceil(playerPointsReturn / 22.5)
			end
		end)

		local dataPersistanceWins = 0
		local dataPersistanceSuccess, dataPersistanceReturn = nil, nil
		spawn(function()
			dataPersistanceSuccess, dataPersistanceReturn = pcall(function()
				if player:WaitForDataReady() then
					local dataPersistanceWins = player:LoadNumber("SurvivedTotal") or 0
				end
			end)
			if dataPersistanceSuccess and playerPointsReturn then
				dataPersistanceWins = dataPersistanceReturn
			end
		end)

		local dataStoreWins = 0
		local dataStoreSuccess, dataStoreReturn = nil, nil
		spawn(function()
			dataStoreSuccess, dataStoreReturn = pcall(function()
				return survivesDataStore:GetAsync('id'..userId)
			end)
			if dataStoreSuccess and playerPointsReturn then
				dataStoreWins = dataStoreReturn
			end
		end)

		local startWaitTick = tick()
		while true do
			if (tick() - startWaitTick) > 10 then
				break
			end
			if playerPointsSuccess~=nil and playerPointsSuccess~=nil and playerPointsSuccess~=nil then
				break
			end
			wait()
		end
		
		local finalWins = math.ceil(math.max(math.max(playerPointsWins, playerPointsWins), playerPointsWins))
		playersWins['id'..userId] = finalWins
		return finalWins
	end
	return 0
end

marketPlaceService.ProcessReceipt = function(receiptInfo)
	local buyingPlayer = nil 
	for i, player in ipairs(game.Players:GetPlayers()) do
		if player.userId == receiptInfo.PlayerId then
			buyingPlayer = player
			break
		end
	end	
	if receiptInfo.ProductId == powerUpMachineProductId then
		weatherMachineTag.Value = weatherMachineTag.Value + 1
		if buyingPlayer then
			table.insert(powerUpPlayers,buyingPlayer.Name)
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted		
end

function makefragment(dist,rotation,position,crownradius,baseradius,height,roughness)
	local idist=1-dist
	local p=dirtpart:clone()
	p.Size=Vector3.new((baseradius/math.pi)*(.5+(dist*.5)),height*.142*(.5+math.random()*.5),(baseradius-crownradius)*(.3+(math.random()*.2)))
	p.CFrame=CFrame.new(position-Vector3.new(0,p.Size.y*.5,0))*CFrame.Angles(0,rotation,0)*CFrame.new(0,height*(idist^1.5),crownradius+(p.Size.z*.25)+(dist*(baseradius-p.Size.z-crownradius)))*CFrame.Angles(idist*quarterpi,0,(idist+.1)*roughness*(math.random()-.5))
	return p
end

function createvolcano(position,crownradius,baseradius,height,roughness)
	local volcanomodel=Instance.new("Model")
	volcanomodel.Name="Volcano"
	local hitotal=4
	for hi=1,hitotal do
		local ritotal=10+hi*10
		for ri=1,ritotal do
			makefragment((hi-1)/(hitotal-1),(ri/ritotal)*2*math.pi,position,crownradius,baseradius,height,roughness).Parent=volcanomodel
		end
	end
	for i=1,150 do
		makefragment(math.random(),math.random()*2*math.pi,position,crownradius,baseradius,height,roughness).Parent=volcanomodel
	end
	for i=1,3 do
		local p=dirtpart:clone()
		p.Name="Lava"
		p.BrickColor=BrickColor.new("Bright orange")
		p.Size=Vector3.new(crownradius*2,1,crownradius*2)
		p.CFrame=CFrame.new(position+Vector3.new(0,height*.9,0))*CFrame.Angles(0,math.pi*(i/3),0)
		p.CanCollide=false
		p.Parent=volcanomodel
	end
	volcanomodel.Parent=game.Workspace.Structure
	return volcanomodel
end

local intangibles={"handle","flash","water","bullet"}
function checkintangible(t)
	local lowername=string.lower(t.Name)
	if not t.CanCollide or string.sub(lowername,1,6)=="effect" then
		return true
	end
	for _,v in ipairs(intangibles) do
		if v==lowername then
			return true
		end
	end
	return false
end
function castray(startpos,vec,length,ignore)
	if length>999 then
		length=999
	end
	local hit,endpos=game.Workspace:FindPartOnRay(Ray.new(startpos,vec*length),ignore)
	if hit~=nil then
		if checkintangible(hit) then
			hit,endpos=castray(endpos+(vec*.01),vec,length-((startpos-endpos).magnitude),ignore)
		end
	end
	return hit,endpos
end

local lavacolors={"Bright red","Bright orange","Bright yellow"}
local lavacolorsdirty={"Reddish brown","Brown","Bright red","Bright orange","Bright yellow"}
function makelavalthrow(pos,lavaclr)
	local p=Instance.new("Part")
	p.Name="Lava"
	p.BrickColor=lavaclr
	p.TopSurface="Smooth"
	p.BottomSurface="Smooth"
	p.formFactor="Custom"
	p.Material="Sand"
	p.Friction=.3
	p.Elasticity=0
	p.Size=Vector3.new(5+math.random()*5,5+math.random()*5,5+math.random()*5)*(1+math.random())
	p.Anchored=false
	p.CanCollide=false
	local lavac=p.Touched:connect(function(hit)
		if p and hit and not hit.Anchored and p.Position.magnitude<300 then
			hit:BreakJoints()
			if not p.CanCollide then
				hit.Velocity=hit.Velocity-(p.Velocity*.3)
				wait(.05)
				p.CanCollide=true
			end
		end
	end)
	delay(4,function()
		if p then
			p.CanCollide=true
		end
		wait(math.random(20,30))
		if p then
			p.BrickColor=BrickColor.new("Black")
			p.Material="Slate"
		end
		if lavac then
			lavac:disconnect()
		end
		wait(30)
		if p then
			p:destroy()
		end
	end)
	p.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.random()*2*math.pi,math.random())*CFrame.new(0,10,0)
	p.Velocity=(((p.Position-pos)+Vector3.new(0,.1,0)).unit*250)+(Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*(50+math.random()*50))
	p.RotVelocity=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*20
	p.Parent=game.Workspace.Structure
end

function makesandray(vec)
	local frames=math.random(10,30)
	local startpos=((vec+(Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*.5)).unit*-100)+(Vector3.new(math.random()-.5,math.random()*.5,math.random()-.5))*300
	local hit,pos=castray(startpos,(vec+(Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*.2)).unit,200)
	if hit and hit.Parent then
		local h=hit.Parent:FindFirstChild("Humanoid")
		if h and hit.Parent:FindFirstChild("SurvivalTag") then
			h:TakeDamage(45)
			frames=4
		end
	end
	local dustdist=(startpos-pos).magnitude
	local dust=Instance.new("Part")
	dust.Name="Dust"
	dust.BrickColor=BrickColor.new("Brick yellow")
	dust.Anchored=true
	dust.CanCollide=true
	dust.formFactor="Custom"
	dust.Size=Vector3.new(.2,.2,.2)
	local bm=Instance.new("BlockMesh")
	bm.Scale=Vector3.new(1,1,dustdist*5)--*(1/frames))
	bm.Parent=dust
	dust.CFrame=CFrame.new(startpos,pos)*CFrame.new(0,100,0)
	dust.Parent=game.Workspace.Structure
	for i=1,frames do
		if bm then
			bm.Offset=Vector3.new(0,-100,-dustdist*5*(((i-.5)/frames)-.5))
			wait()
		end
	end
	if dust then
		dust:destroy()
	end
end


function acidtouch(hit)
	if hit and hit.Parent and math.random()<.5 then
		local h=hit.Parent:FindFirstChild("Humanoid")
		if h then
			h:TakeDamage(1)
		end
	end
end

local raincolors={"Medium green","Sand green","Deep blue","Grime","Medium blue","Dark stone grey","Black"}
local recoloracid={["Medium stone grey"]="Medium green",["Medium green"]="Sand green",["Sand green"]="Grime",["Grime"]="Black"}
function makerainray(vec,forplayer)
	local frames=math.random(5,15)
	local vec=(vec+(Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*.1)).unit
	local startpos=forplayer and forplayer-(vec*300) or Vector3.new((math.random()-.5)*300,250,(math.random()-.5)*300)
	local hit,pos=castray(startpos,vec,400)
	local damagedealt=false
	if hit and hit.Parent then
		local h=hit.Parent:FindFirstChild("Humanoid")
		if h and hit.Parent:FindFirstChild("SurvivalTag") then
			h:TakeDamage(5)
			frames=4
			damagedealt=true
		end
		--if hit:IsDescendantOf(game.Workspace.Structure) then
			if hit and not hit.Anchored and not forplayer then
				if hit.BrickColor.Name=="Black" then
					if h==nil then
						hit:destroy()
					end
				else
					hit.BrickColor=BrickColor.new(recoloracid[hit.BrickColor.Name] or "Medium stone grey")
					if hit.BrickColor.Name=="Medium green" then
						if h==nil then
							if math.random()<.5 then
								hit:BreakJoints()
							end
							hit.Touched:connect(acidtouch)
						end
						delay(0,function()
							local acidsound=oldcontent.Sounds["Acid"..math.random(1,2)]:clone()
							acidsound.Pitch=.5+math.random()
							acidsound.Parent=hit
							wait()
							acidsound:Play()
							wait(5)
							acidsound:Stop()
							acidsound:destroy()
						end)
					elseif hit.BrickColor.Name=="Sand green" then
						if h==nil then
							hit:BreakJoints()
						end
					end
				end
			end
		--end
	end
	if not forplayer or damagedealt then
		local dustdist=(startpos-pos).magnitude
		local dust=Instance.new("Part")
		dust.Name="AcidRain"
		dust.BrickColor=BrickColor.new(raincolors[math.random(1,#raincolors)])
		dust.Transparency=.5
		dust.Anchored=true
		dust.CanCollide=true
		dust.formFactor="Custom"
		dust.Size=Vector3.new(.2,.2,.2)
		local bm=Instance.new("BlockMesh")
		bm.Scale=Vector3.new(1,1,dustdist*5/(frames*.5))
		bm.Parent=dust
		dust.CFrame=CFrame.new(startpos,pos)*CFrame.new(0,100,0)
		dust.Parent=game.Workspace.Structure
		for i=1,frames do
			if bm then
				bm.Offset=Vector3.new(0,-100,-dustdist*((i-.5)/frames))
				wait()
			end
		end
		if dust then
			dust:destroy()
		end
	end
end

function setexposures(exposure)
	for _,v in pairs(game.Players:GetPlayers()) do
		if v.Character then
			local chr=v.Character
			local t=chr:FindFirstChild("HumanoidRootPart")
			local h=chr:FindFirstChild("Humanoid")
			local st=chr:FindFirstChild("SurvivalTag")
			if t and h and st then
				local etag=st:FindFirstChild("ExposureTag")
				if etag then
					etag.Value=exposure
				end
			end
		end
	end
end
function giveguis(a)
	if a then
		for _,v in pairs(game.Players:GetPlayers()) do
			local plrgui=v:FindFirstChild("PlayerGui")
			if v.Character and plrgui then
				local chr=v.Character
				local t=chr:FindFirstChild("HumanoidRootPart")
				local h=chr:FindFirstChild("Humanoid")
				local st=chr:FindFirstChild("SurvivalTag")
				if t and h and st and plrgui:FindFirstChild(a.Name)==nil then
					a:clone().Parent=plrgui
				end
			end
		end
	end
end

function cframemodel(modl,centercframe,goalcframe)
	for _,Object in pairs(modl:GetChildren()) do
		Object.CFrame=goalcframe:toWorldSpace(centercframe:toObjectSpace(Object.CFrame))
	end
end

function RandomizeTable(tbl)
	local returntbl={}
	if tbl[1]~=nil then
		for i=1,#tbl do
			table.insert(returntbl,math.random(1,#returntbl+1),tbl[i])
		end
	end
	return returntbl
end

function resurface(p,s)
	if p and s then
		p.BackSurface=s
		p.BottomSurface=s
		p.FrontSurface=s
		p.LeftSurface=s
		p.RightSurface=s
		p.TopSurface=s
	end
end

function clouds(cloudtime)
	local cloud=storage.Cloud:clone()
	cloud.Parent=game.Workspace.Structure
	local pos1=Vector3.new(6000,300,-4000)
	local pos2=Vector3.new(-2000,300,2000)
	for i=1,(1/rate)*cloudtime do
		if cloud then
			wait(rate)
			cloud.CFrame=CFrame.new(pos1+((pos2-pos1)*(i/(cloudtime*(1/rate)))))
		end
	end
end

local function connectMeteorTouched(meteor)
	local active = true
	local firstHit = true
	
	local function removeMeteor(meteor)
		local fire = meteor:FindFirstChild('Fire')
		local smoke = meteor:FindFirstChild('Smoke')
		if fire and smoke then
			fire.Enabled = false
			smoke.Enabled = false
		end
		
		active = false
		meteor.Anchored = true
		meteor.Transparency = 1
		DebrisService:AddItem(meteor, 3)
	end	
	
	meteor.Touched:connect(function(hit)
		if not active then
			return
		end
		
		if hit and hit.Parent ~= nil then
			if not hit.Anchored then
				hit:BreakJoints()
				hit.Velocity = meteor.Velocity
			end

			if firstHit then
				firstHit = false

				local explosion = Instance.new("Explosion")
				explosion.Position = meteor.Position
				explosion.BlastPressure = 0
				explosion.BlastRadius = 0
				explosion.ExplosionType = Enum.ExplosionType.NoCraters
				explosion.DestroyJointRadiusPercent = 0
				explosion.Parent = meteor

				local sound = meteor:FindFirstChild("ExplosionSound")
				if sound ~= nil then
					sound:Play()
				end

				wait(.2) -- Allows the meteor to dig a hole before expiring
				removeMeteor(meteor)
			end
		end
	end)
end

function createMeteor(meteorFolder)
	local meteor = meteorTemplate:Clone()
	local meteorSize = meteorSizes[math.random(1, #meteorSizes)]
	meteor.Size = Vector3.new(meteorSize, meteorSize, meteorSize)
	meteor.Position = Vector3.new(math.random(-mapradius/2, mapradius/2), 500, math.random(-mapradius/2, mapradius/2))
	meteor.Velocity = Vector3.new(math.random(-100,100), -100, math.random(-100,100))
	meteor.CanCollide = false

	local randomMeteorSound = oldcontent.Sounds:FindFirstChild("Meteor" ..tostring(math.random(1, 3)))
	if randomMeteorSound ~= nil then
		-- TODO: Woosh sound
		local meteorSound = randomMeteorSound:Clone()
		meteorSound.Name = "ExplosionSound"
		meteorSound.Parent = meteor
	end
	
	game.Debris:AddItem(meteor, 12)
	meteor.Parent = meteorFolder
	
	connectMeteorTouched(meteor)
	return meteor
end

function createlightning(islast)
	local m=Instance.new("Model")
	m.Name="Lightning"
	local ls=storage.LightningScript:clone()
	ls.Disabled=false
	ls.Parent=m
	local origin=Vector3.new(math.random(-mapradius/2,mapradius/2),300,math.random(-mapradius/2,mapradius/2))
	local lastpoint=origin
	local depth=300
	local nothit=true
	local segments=0
	while depth>0 and nothit and segments<20 do
		segments=segments+1
		local range=40
		local nextpoint=lastpoint+Vector3.new(math.random(-range,range),math.random(-range*2,-5),math.random(-range,range))
		local stuff=game.Workspace:FindPartsInRegion3(Region3.new(lastpoint-Vector3.new(range/2,range*2,range/2),lastpoint+Vector3.new(range/2,-5,range/2)),nil,100)
		if stuff then
			if #stuff>0 then
				local highest=nextpoint
				for i2,v2 in ipairs(stuff) do
					if v2 then
						if v2.Position.y>highest.y then
							highest=v2.Position
						end
					end
				end
				nextpoint=highest
			end
		end
		local dist=(lastpoint-nextpoint).magnitude
		local hit,pos=game.Workspace:FindPartOnRay(Ray.new(lastpoint,nextpoint-lastpoint))
		if hit~=nil and pos~=nil then
			nothit=false
			local e=Instance.new("Explosion")
			e.BlastRadius=7
			e.BlastPressure=2000000
			e.Position=pos
			if islast then
				e.Hit:connect(function(hit2,distnc)
					if hit2.Parent~=nil and hit2.Name=="Head" then
						local dedman=game.Players:GetPlayerFromCharacter(hit2.Parent)
						if dedman then
							badgeService:AwardBadge(dedman.userId,66918848)
						end
					end
				end)
			end
			e.Parent=game.Workspace
		end
		if pos~=nil then
			nextpoint=pos
		end
		depth=nextpoint.y
		local p=storage.LightningPart:clone()
		local dist=(lastpoint-nextpoint).magnitude
		p.Size=Vector3.new(.75,dist,.75)
		p.CFrame=CFrame.new(lastpoint,nextpoint)*CFrame.Angles(math.pi/2,0,0)*CFrame.new(0,-dist/2,0)
		p.Parent=m
		lastpoint=nextpoint
	end
	local lightningsound=oldcontent.Sounds:FindFirstChild("Lightning"..tostring(math.random(1,5)))
	if lightningsound~=nil then
		lightningsound:Play()
	end
	game.Lighting.Ambient=Color3.new(1,1,1)
	game.Lighting.Brightness=2
	m.Parent=game.Workspace.Structure
	delay(.1,function()
		game.Lighting.Ambient=Color3.new(128/255,128/255,128/255)
		game.Lighting.Brightness=1
	end)
end

function breakjointsunderhight(mdl,breakhight,breakchance)
	if mdl then
		if mdl:IsA('BasePart') then
			if not mdl.Anchored and mdl.Position.y<=breakhight then
				if math.random()<breakchance then
					mdl:BreakJoints()
					mdl.Velocity=mdl.Velocity+Vector3.new(math.random(-3,3),math.random(-3,3),math.random(-3,3))
				end
				if math.random()<breakchance then
					mdl:destroy()
				end
			end
		end
		if mdl then
			if mdl.Parent~=nil then
				for i3,v3 in ipairs(mdl:GetChildren()) do
					breakjointsunderhight(v3,breakhight,breakchance)
				end
			end
		end
	end
end

function updatefireparts(mdl)
	if mdl then
		if mdl:IsA('BasePart') then
			local ft=mdl:FindFirstChild("FireTag")
			if not mdl.Anchored and ft then
				ft.Value=ft.Value+1
				if ft.Value==1 and mdl.Transparency==0 then
					local f=fireTemplate:clone()
					f.Rate = math.max(3,math.min(200,mdl.Size.magnitude/3))
					f.Parent=mdl
				elseif ft.Value==5 then
					mdl.BrickColor=BrickColor.new("Black")
				elseif ft.Value==10 then
					mdl:BreakJoints()
				elseif ft.Value==20 and math.random()<=.6 then
					mdl:destroy()
				elseif ft.Value==30 then
					local f=mdl:FindFirstChild("Fire")
					if f then
						f:destroy()
					end
				end
				if ft.Value>5 and ft.Value<30 and mdl and mdl.Parent then
					local prerange=(mdl.CFrame*CFrame.new(mdl.Size*.5)).p-mdl.Position
					local range=Vector3.new(math.abs(prerange.x)+.5,math.abs(prerange.y)+.5,math.abs(prerange.z)+.5)
					local stuff=game.Workspace:FindPartsInRegion3(Region3.new(mdl.Position-range,mdl.Position+range),nil,100)
					for i2,v2 in ipairs(stuff) do
						if v2 then
							if v2:IsA('BasePart') then
								local ft=v2:FindFirstChild("FireTag")
								if not v2.Anchored and not ft then
									local h=v2.Parent:FindFirstChild("Humanoid")
									if h then
										h.Health=h.Health-16
									elseif math.random()>.25 then
										local ft=Instance.new("IntValue")
										ft.Name="FireTag"
										ft.Value=0
										ft.Parent=v2
									end
								end
							end
						end
					end
				end
			end
		end
		if mdl then
			if mdl.Parent~=nil then
				for i3,v3 in ipairs(mdl:GetChildren()) do
					updatefireparts(v3)
				end
			end
		end
	end
end

function updatetornado(mdl)
	if mdl then
		if mdl:IsA('BasePart') then
			if not mdl.Anchored and mdl.Position.y<maxhight then
				local dist=((mdl.Position*Vector3.new(1,0,1))-tornadopos).magnitude
				if dist<breakradius then
					local h=mdl.Parent:FindFirstChild("Humanoid")
					if not h then
						mdl:BreakJoints()
					end
					local pushpull=pull
					local hightpercentage=(mdl.Position.y/(maxhight-low))
					pushpull=pull+((push-pull)*hightpercentage)
					if dist<cycloneradius then
						pushpull=push
					end
					local angle=math.atan2(mdl.Position.x-tornadopos.x,mdl.Position.z-tornadopos.z)
					local ncf=(CFrame.new(tornadopos)+Vector3.new(0,mdl.Position.y,0))*CFrame.Angles(0,angle+.1,0)*CFrame.new(0,0,dist+pushpull)

					if game.Workspace:FindFirstChild("Marker") then
						game.Workspace.Marker.CFrame=ncf
					end

					local vec=(ncf.p-mdl.Position).unit
					local speedpercent=(dist-cycloneradius)/(breakradius-cycloneradius)
					if speedpercent<0 then
						speedpercent=0
					end
					speedpercent=1-speedpercent
					speedpercent=speedpercent+.1
					if speedpercent>1 then
						speedpercent=1
					end
					mdl.Velocity=(vec*speedpercent*speed*(1+(2*hightpercentage)))+Vector3.new(0,(lift*(speedpercent+hightpercentage)*speed),0)
					mdl.RotVelocity=mdl.RotVelocity+Vector3.new(math.random(-1,1),math.random(-1,1)+.1,math.random(-1,1))
					if not tornadodparts[mdl] then
						if h then
							if mdl.Name=="HumanoidRootPart" and not h.PlatformStand then
								h.PlatformStand=true
								delay(5,function()
									if h then
										h.PlatformStand=false
									end
								end)
							end
							if mdl.Name~='HumanoidRootPart' and mdl.Name~='Head' and mdl.Name~='Torso' and mdl.Name~='UpperTorso' and mdl.Name~='LowerTorso' then
								if math.random()<.001 then	-- randomly rip limbs off. :D
									mdl:Destroy()
								end
							end
						else
							if math.random(1,2)==1 then
								mdl:Destroy()
							else
								tornadodparts[mdl]=true
							end
						end
					end
				end
			end
		end
		if mdl then
			if mdl.Parent~=nil then
				for i3,v3 in ipairs(mdl:GetChildren()) do
					updatetornado(v3)
				end
			end
		end
	end
end

function startfire(mdl)
	if mdl then
		if mdl.Name=="FireStarter" then
			if mdl:IsA('BasePart') then
				local ft=Instance.new("IntValue")
				ft.Name="FireTag"
				ft.Value=0
				ft.Parent=mdl
			end
		end
		for i3,v3 in ipairs(mdl:GetChildren()) do
			startfire(v3)
		end
	end
end

function spread(mdl,func)
	if mdl and mdl.Parent~=nil then
		func(mdl)
		if mdl and mdl.Parent~=nil then
			for i,v in ipairs(mdl:GetChildren()) do
				spread(v,func)
			end
		end
	end
end

meteorstorm = {}

meteorstorm.Name="Meteor Shower"
meteorstorm.PreStart=function()
end

meteorstorm.Start = function()
	local shower = true
	local meteorFolder = Instance.new("Folder")
	meteorFolder.Name = "MeteorFolder"
	meteorFolder.Parent = game.Workspace.Structure
	
	local activeMeteors = {}	
	
	local meteorRemovingConnection = meteorFolder.DescendantRemoving:connect(function(descendant)
		if activeMeteors[descendant] then
			activeMeteors[descendant] = nil
			if not shower then
				return
			end
			
			local emitters = {}
			for _, item in pairs(descendant:GetChildren()) do
				if item:IsA("ParticleEmitter") then
					if item.Enabled then
						table.insert(emitters, item)
					end
				end
			end
			
			if #emitters == 0 then
				return
			end
			
			local meteorClone = descendant:Clone()
			meteorClone:ClearAllChildren()
			meteorClone.Anchored = true
			meteorClone.Transparency = 1
			meteorClone.Parent = game.Workspace.Structure

			for _, emitter in pairs(emitters) do
				emitter.Parent = meteorClone
				emitter.Enabled = false
			end
			
			DebrisService:AddItem(meteorClone, 3)
		end
	end)
	
	delay(0, function()
		event:FireAllClients('DisasterWarning', 'Meteor Shower!  Watch the skies and find shelter')
		while shower do
			local newMeteor = createMeteor(meteorFolder)
			activeMeteors[newMeteor] = true
			wait(0.5)
		end
	end)
	
	wait(90)
	shower = false
end

flooding={}
flooding.Name="Flash Flood"
flooding.PreStart=function()
	delay(1,function()
		clouds(100)
	end)
	delay(15,function()
		oldcontent.Sounds.Wind:Play()
	end)
end
flooding.Start=function()
	local fl=storage.FloodLevel:clone()
	fl.Parent=game.Workspace.Structure
	totalfloodhight=70
	floodspeed=2*rate
	floodstart=15
	radius=3			--hight
	wavetime=10		--seconds
	local a=0
	local flooding=true
	delay(0,function()
		event:FireAllClients('DisasterWarning','Flash Flood!  Seek high and stable ground')
		while flooding do
			wait(rate)
			a=a+1
			local floodhight=floodstart+(a*floodspeed)
			if floodhight>totalfloodhight then
				floodhight=totalfloodhight
			end
			local floodhight=floodhight+math.sin((a/(wavetime*30))*math.pi)*radius
			if fl then
				fl.CFrame=CFrame.new(0,floodhight,0)
			end
			if a%30==0 then
				for i,v in ipairs(game.Players:GetPlayers()) do
					if v then
						if v.Character~=nil then
							local he=v.Character:FindFirstChild("Head")
							local hu=v.Character:FindFirstChild("Humanoid")
							if he and hu then
								if he.Position.y<floodhight then
									hu.Health=hu.Health-7
								end
							end
						end
					end
				end
			end
			if (a+15)%30==0 then
				breakjointsunderhight(game.Workspace.Structure,floodhight,.05)
			end
		end
	end)
	wait(60)
	flooding=false
	oldcontent.Sounds.Wind:Stop()
end

lightningstorm={}
lightningstorm.Name="Thunder Storm"
lightningstorm.PreStart=function()
	delay(1,function()
		clouds(100)
	end)
	delay(15,function()
		oldcontent.Sounds.Wind:Play()
	end)
end
lightningstorm.Start=function()
	local thundering=true
	delay(0,function()
		event:FireAllClients('DisasterWarning',"Thunder Storm!  Don't stand in the open or in high places")
		while thundering do
			wait(1.5+math.random())
			createlightning(not thundering)
		end
	end)
	wait(90)
	thundering=false
	wait(3)
	oldcontent.Sounds.Wind:Stop()
end

fire={}
fire.Name="Fire"
fire.PreStart=function()
end
fire.Start=function()
	startfire(game.Workspace.Structure)
	local burning=true
	delay(0,function()
		event:FireAllClients('DisasterWarning','Fire!  Keep distance from the fire')
		while burning do
			wait(1)
			updatefireparts(game.Workspace.Structure)
		end
	end)
	wait(90)
	burning=false
end

tornado={}
tornado.Name="Tornado"
tornado.PreStart=function()
	delay(1,function()
		clouds(100)
	end)
	delay(15,function()
		oldcontent.Sounds.Wind:Play()
	end)
end
tornado.Start=function()
	local tornadoing=true
	tornadoposes={}
	local tornadostartpos=Vector3.new(math.random(-85,70),0,math.random(-90,80))
	tornadopos=tornadostartpos
	for i=1,10 do
		table.insert(tornadoposes,Vector3.new(math.random(-85,70),0,math.random(-90,80)))
	end
	local tp=storage.TornadoPart:clone()
	tp.CFrame=CFrame.new(tornadostartpos+Vector3.new(0,low,0))
	tp.Parent=game.Workspace.Structure
	wait(.2)
	local iwsound=tp:FindFirstChild("IntenseWind")
	if iwsound then
		iwsound:Play()
	end
	local a=0
	delay(0,function()
		event:FireAllClients('DisasterWarning',"Tornado!  Stay clear of it's path")
		local starttime=tick()
		local endtime=starttime+90
		tornadodparts={}
		while tornadoing do
			a=a+1
			if a%2==0 then
				local totalpercent=math.min(1,math.max(0,(tick()-starttime)/(endtime-starttime)))
				local posframe=math.ceil(#tornadoposes*totalpercent)
				local pospercent=(totalpercent-((posframe-1)/#tornadoposes))*#tornadoposes
				local lastposframe=(tornadoposes[posframe-1] or tornadostartpos)
				tornadopos=lastposframe+((tornadoposes[posframe]-lastposframe)*pospercent)
				if tp then
					tp.CFrame=CFrame.new(tornadopos+Vector3.new(0,low,0))
				end
				updatetornado(game.Workspace.Structure)
			else
				for i,v in ipairs(game.Players:GetPlayers()) do
					if v then
						if v.Character~=nil then
							updatetornado(v.Character)
						end
					end
				end
			end
			wait(rate)
		end
	end)
	wait(90)
	tornadodparts={}
	tornadoing=false
	oldcontent.Sounds.Wind:Stop()
end

tsunami={}
tsunami.Name="Tsunami"
tsunami.PreStart=function()
end
tsunami.Start=function()
	--presetangle=(math.pi/4)+(math.pi/2)
	waveangle=math.pi*2*math.random()
	tsunamiinitial=CFrame.Angles(0,waveangle,0)*CFrame.new(-wavedistance/2,11+wavehight/2,0)
	tsunamifinal=CFrame.Angles(0,waveangle,0)*CFrame.new(wavedistance/2,11+wavehight/2,0)
	wavevec=(tsunamiinitial.p-tsunamifinal.p).unit --tsunamiinitial.lookVector--
	tsunamiwave=storage.TsunamiWave:clone()
	tsunamiwave.Parent=game.Workspace.Structure
	while tsunamiwave:FindFirstChild("Center")==nil do wait() end
	cframemodel(tsunamiwave,tsunamiwave.Center.CFrame,tsunamiinitial*CFrame.Angles(0,math.pi,0))
	local wavesound=oldcontent.Sounds.Wave:clone()
	wavesound.Name="Sound"
	wavesound.Parent=tsunamiwave.Center
	wait(1)
	wavesound:Play()
	local tsunaming=true
	delay(0,function()
		event:FireAllClients('DisasterWarning','Tsunami!  Get to higher ground')
		local starttime=tick()
		local endtime=starttime+90
		while tsunaming do
			wait(rate)
			local wavepercentage=math.min(1,math.max(0,(tick()-starttime)/(endtime-starttime)))
			local tsunamicurrent = CFrame.Angles(0,waveangle,0)*CFrame.new((-wavedistance/2)+wavedistance*wavepercentage,11+wavehight/2,0)
			if tsunamiwave and tsunamiwave~=nil then
				cframemodel(tsunamiwave,tsunamiwave.Center.CFrame,tsunamicurrent*CFrame.Angles(0,math.pi,0))
			end
			for i=1,wavesegments do
				local segpos=(tsunamicurrent*CFrame.new(0,0,(-wavelength/2)+(i*segmentradius))).p
				local waverange=Vector3.new(segmentradius,wavehight/2,segmentradius)
				local stuff=game.Workspace:FindPartsInRegion3(Region3.new(segpos-waverange,segpos+waverange),nil,100)
				for i2,v2 in ipairs(stuff) do
					if v2 and v2.Parent~=nil then
						if not v2.Anchored then
							v2:BreakJoints()
							if math.random(1,5)==1 then
								v2.Velocity=wavevec*-1*wavespeed
							end
							if math.random(1,100)==1 then
								v2:destroy()
							end
						end
					end
				end
			end
		end
	end)
	wait(90)
	tsunaming=false
	if wavesound~=nil then
		wavesound:Stop()
	end
end

blizzard={}
blizzard.Name="Blizzard"
blizzard.PreStart=function()
	giveguis(storage:FindFirstChild("BlizzardGui"))
	delay(1,function()
		clouds(100)
	end)
	delay(12,function()
		game.Lighting.Brightness=.8
		weatherdome.Transparency=.8
		game.Lighting.FogColor=Color3.new(.9,.9,.9)
		game.Lighting.FogEnd=5000
		game.Lighting.FogStart=0
	end)
	delay(18,function()
		game.Lighting.Brightness=.6
		weatherdome.Transparency=.4
		game.Lighting.FogEnd=2500
		oldcontent.Sounds.Wind:Play()
	end)
	delay(26,function()
		game.Lighting.Brightness=.4
		weatherdome.Transparency=.1
		game.Lighting.FogEnd=1000
	end)
	delay(32,function()
		game.Lighting.Brightness=.2
		weatherdome.Transparency=.05
		game.Lighting.FogEnd=550
		end)
	delay(39,function()
		game.Lighting.Brightness=0
		weatherdome.Transparency=0
		game.Lighting.FogEnd=400
	end)
end
blizzard.Start=function()
	oldcontent.Sounds.IntenseWind:Play()
	blizzing=true
	blizvecunits={Vector3.new(0,1,0),Vector3.new(1,0,0),Vector3.new(.5,0,.5),Vector3.new(0,0,1),Vector3.new(-.5,0,.5),Vector3.new(-1,0,0),Vector3.new(-.5,0,-.5),Vector3.new(0,0,-1),Vector3.new(.5,0,-.5),}
	freezelength=16
	windvec=Vector3.new(math.random()-.5,0,math.random()-.5).unit
	delay(0,function()
		event:FireAllClients('DisasterWarning','Blizzard!  Seek warmth and find shelter')
		while blizzing do
			wait(1/30)
			for _,v in pairs(game.Players:GetPlayers()) do
				if math.random()<=.15 and v.Character then
					local chr=v.Character
					local t=chr:FindFirstChild("HumanoidRootPart")
					local h=chr:FindFirstChild("Humanoid")
					local st=chr:FindFirstChild("SurvivalTag")
					if t and h and st then
						local etag=st:FindFirstChild("ExposureTag")
						if etag then
							local exposure=0
							for _,bvec in pairs(blizvecunits) do
								local bvec2=(bvec+(Vector3.new(math.random()-.5,(math.random()-.5)*.5,math.random()-.5)*.15)).unit
								local hit,pos=castray(t.Position+(-bvec2*freezelength),bvec2,freezelength)
								if hit and hit.Parent==chr then
									exposure=exposure+1
								end
							end
							local damage=math.min(1,(exposure-5)/2)
							if damage>0 then
								h:TakeDamage(damage)
							end
							etag.Value=exposure
						end
					end
				end
			end
			if math.random()<=.2 then
				blowableparts={}
				spread(game.Workspace.Structure,function(mdl2)
					if mdl2~=nil then
						if mdl2:IsA("BasePart") and not mdl2.Anchored and not mdl2:FindFirstChild("BodyVelocity") and not mdl2:FindFirstChild("BodyForce") then
							if not mdl2:FindFirstChild("KeepAnchored") then
								table.insert(blowableparts,mdl2)
							end
						end
					end
				end)
				if #blowableparts>0 then
					for i=1,math.random(2,3) do
						local rp=blowableparts[math.random(1,#blowableparts)]
						if rp then
							rp.BrickColor=BrickColor.new("Institutional white")
							rp.Material="Sand"
						end
					end
					local rp=blowableparts[math.random(1,#blowableparts)]
					if rp then
						rp:BreakJoints()
						local bf=Instance.new("BodyForce")
						bf.force=windvec*300*rp:GetMass()
						bf.Parent=rp
					end
				end
				blowableparts=nil
			end
		end
	end)
	wait(90)
	blizzing=false
	oldcontent.Sounds.IntenseWind:Stop()
	oldcontent.Sounds.Wind:Stop()
	game.Lighting.Brightness=1
	weatherdome.Transparency=1
	game.Lighting.FogColor=Color3.new(171/255,208/255,217/255)
	game.Lighting.FogEnd=5000
	game.Lighting.FogStart=500
end


sandstorm={}
sandstorm.Name="Sandstorm"
sandstorm.PreStart=function()
	giveguis(storage:FindFirstChild("SandStormGui"))
	delay(1,function()
		clouds(100)
	end)
	delay(12,function()
		game.Lighting.Brightness=.8
		weatherdome.Transparency=.8
		game.Lighting.FogColor=Color3.new(190/255,191/255,169/255)
		game.Lighting.FogEnd=5000
		game.Lighting.FogStart=0
		setexposures(1)
	end)
	delay(18,function()
		game.Lighting.Brightness=.6
		weatherdome.Transparency=.4
		game.Lighting.FogEnd=2500
		oldcontent.Sounds.Wind:Play()
		setexposures(2)
	end)
	delay(26,function()
		game.Lighting.Brightness=.4
		weatherdome.Transparency=.1
		game.Lighting.FogEnd=1000
		setexposures(3)
	end)
	delay(32,function()
		game.Lighting.Brightness=.2
		weatherdome.Transparency=.05
		game.Lighting.FogEnd=550
		setexposures(4)
		end)
	delay(39,function()
		game.Lighting.Brightness=0
		weatherdome.Transparency=0
		game.Lighting.FogEnd=400
		setexposures(5)
	end)
	delay(46,function()
		game.Lighting.Brightness=0
		weatherdome.Transparency=0
		game.Lighting.FogEnd=400
		setexposures(8)
	end)
end
sandstorm.Start=function()
	oldcontent.Sounds.IntenseWind:Play()
	storming=true
	blizvecunits={Vector3.new(1,0,0),Vector3.new(.5,0,.5),Vector3.new(0,0,1),Vector3.new(-.5,0,.5),Vector3.new(-1,0,0),Vector3.new(-.5,0,-.5),Vector3.new(0,0,-1),Vector3.new(.5,0,-.5),}
	freezelength=16
	windvec=Vector3.new(math.random()-.5,0,math.random()-.5).unit
	delay(0,function()
		event:FireAllClients('DisasterWarning','Sandstorm!  Dodge flying objects')
		while storming do
			wait(1/30)
			if math.random()<=.25 then
				blowableparts={}
				spread(game.Workspace.Structure,function(mdl2)
					if mdl2~=nil then
						if mdl2:IsA("BasePart") and not mdl2.Anchored and not mdl2:FindFirstChild("BodyVelocity") and not mdl2:FindFirstChild("BodyForce") then
							if not mdl2:FindFirstChild("KeepAnchored") then
								table.insert(blowableparts,mdl2)
							end
						end
					end
				end)
				if #blowableparts>0 then
					for i=1,math.random(1,2) do
						local rp=blowableparts[math.random(1,#blowableparts)]
						if rp then
							rp.BrickColor=BrickColor.new("Brick yellow")
							rp.Material="Sand"
						end
					end
					for i=1,math.random(1,2) do
						local rp=blowableparts[math.random(1,#blowableparts)]
						if rp then
							rp:BreakJoints()
							local bf=Instance.new("BodyForce")
							bf.force=windvec*500*rp:GetMass()
							bf.Parent=rp
						end
					end
				end
				blowableparts=nil
			end
			delay(0,function()
				makesandray(windvec)
				makesandray(windvec)
			end)
		end
	end)
	wait(90)
	storming=false
	oldcontent.Sounds.IntenseWind:Stop()
	oldcontent.Sounds.Wind:Stop()
	game.Lighting.Brightness=1
	weatherdome.Transparency=1
	game.Lighting.FogColor=Color3.new(171/255,208/255,217/255)
	game.Lighting.FogEnd=5000
	game.Lighting.FogStart=500
end


volcaniceruption={}
volcaniceruption.Name="Volcanic Eruption"
volcaniceruption.PreStart=function()
end
volcaniceruption.Start=function()
	local volcanopos=(CFrame.Angles(0,math.random()*2*math.pi,0)*CFrame.new(0,10,300)).p
	local spoutpos=volcanopos+Vector3.new(0,60,0)
	createvolcano(volcanopos,30,200,60,.2)
	wait(15)
	oldcontent.Sounds.Explosion1:Play()
	oldcontent.Sounds.Explosion2:Play()
	oldcontent.Sounds.RockSound:Play()
	oldcontent.Sounds.DirtSound:Stop()
	oldcontent.Sounds.DirtSound:Play()
	local erupting=true
	for i=1,30 do
		makelavalthrow(spoutpos,BrickColor.new(lavacolorsdirty[math.random(1,#lavacolorsdirty)]))
	end
	delay(0,function()
		event:FireAllClients('DisasterWarning','Volcanic Eruption!  Get away from the volcano')
		local nextexplodesound=tick()+1+math.random()
		while erupting do
			for _=1,math.random(1,2) do
				makelavalthrow(spoutpos,BrickColor.new(lavacolors[math.random(1,#lavacolors)]))
			end
			if tick()>nextexplodesound then
				nextexplodesound=tick()+1+math.random()
				local esound=oldcontent.Sounds:FindFirstChild(math.random()<.5 and "RockSound" or "Explosion2")
				if esound then
					esound:Play()
				end
			end
			wait(.03+math.random()*.4)
		end
	end)
	wait(90)
	oldcontent.Sounds.DirtSound:Stop()
	erupting=false
	game.Lighting.Brightness=1
	weatherdome.Transparency=1
	game.Lighting.FogColor=Color3.new(171/255,208/255,217/255)
	game.Lighting.FogEnd=5000
	game.Lighting.FogStart=500
end

earthquake={}
earthquake.Name="Earthquake"
earthquake.PreStart=function()
end
earthquake.Start=function()
	local island=game.Workspace:WaitForChild("Island")
	local shakingstuff=true
	oldcontent.Sounds.RockSound:Play()
	oldcontent.Sounds.DirtSound:Stop()
	oldcontent.Sounds.DirtSound:Play()
	event:FireAllClients('DisasterWarning','Earthquake!  Get outside and stay away from tall structures')
	delay(0,function()
		while shakingstuff do
			local shakedirection=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*20
			--local rotshakedirection=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*10
			for _,v in pairs(island:GetChildren()) do
				if math.random()<.5 and v and v:IsA("BasePart") then
					v.Velocity=shakedirection+Vector3.new(math.random()-.5,math.random()*.5,math.random()-.5)*20
					--v.RotVelocity=rotshakedirection
					v:BreakJoints()
				end
			end
			
			breakableparts={}
			spread(game.Workspace.Structure,function(mdl2)
				if mdl2~=nil then
					if mdl2:IsA("BasePart") then
						if not mdl2:FindFirstChild("KeepAnchored") and not mdl2.Anchored then
							table.insert(breakableparts,mdl2)
						else
							if math.random()<.5 and mdl2 and mdl2:IsA("BasePart") then
								mdl2.Velocity=shakedirection+Vector3.new(math.random()-.5,math.random()*.5,math.random()-.5)*20
								--mdl2.RotVelocity=rotshakedirection
								mdl2:BreakJoints()
							end
						end
					end
				end
			end)
			if #breakableparts>0 then
				for i=1,math.random(2,5) do
					local rp=breakableparts[math.random(1,#breakableparts)]
					if rp then
						rp:BreakJoints()
					end
				end
			end
			breakableparts=nil
			wait(math.random()*1)
		end
	end)
	wait(90)
	for _,v in pairs(island:GetChildren()) do
		if v and v:IsA("BasePart") then
			v.Velocity=Vector3.new(0,0,0)
			v.RotVelocity=Vector3.new(0,0,0)
		end
	end
	shakingstuff=false
	oldcontent.Sounds.DirtSound:Stop()
	wait(5)
end

acidrain={}
acidrain.Name="Acid Rain"
acidrain.PreStart=function()
	oldcontent.Sounds.Wind:Play()
	delay(1,function()
		clouds(100)
	end)
end
acidrain.Start=function()
	oldcontent.Sounds.Rain:Play()
	raining=true
	local windvec=Vector3.new(math.random()-.5,0,math.random()-.5).unit
	local rainvec=(Vector3.new(0,-1,0)+windvec*.25).unit
	delay(0,function()
		event:FireAllClients('DisasterWarning','Acid Rain!  Stay indoors')
		while raining do
			delay(0,function()
				for i=1,4 do
					makerainray(rainvec)
				end
			end)
			for _,v in pairs(game.Players:GetPlayers()) do
				if math.random()<=.03 and v.Character then
					local chr=v.Character
					local t=chr:FindFirstChild("HumanoidRootPart")
					local h=chr:FindFirstChild("Humanoid")
					local st=chr:FindFirstChild("SurvivalTag")
					if t and h and st then
						makerainray(rainvec,t.Position)
					end
				end
			end
			wait(1/30)
		end
	end)
	wait(90)
	raining=false
	oldcontent.Sounds.Wind:Stop()
	oldcontent.Sounds.Rain:Stop()
	game.Lighting.Brightness=1
	weatherdome.Transparency=1
	game.Lighting.FogColor=Color3.new(171/255,208/255,217/255)
	game.Lighting.FogEnd=5000
	game.Lighting.FogStart=500
end

emptydisaster = {}
emptydisaster.Name = "emptydisaster"
emptydisaster.PreStart = function()
end
emptydisaster.Start = function()
	wait(5)
end



disasters = {meteorstorm, flooding, lightningstorm, fire, tornado, tsunami, blizzard, sandstorm, volcaniceruption, earthquake, acidrain}
--disasters = {blizzard,sandstorm,volcaniceruption,earthquake,acidrain}--Testing
--disasters = {meteorstorm}




function onPlayerRespawn(property,player)
	if property == "Character" and player.Character ~= nil then
		local cs = storage.CharacterScript:clone()
		cs.Disabled = false
		cs.Parent = player.Character
		if player:FindFirstChild("Backpack") then
			if doesPlayerOwn(player, balloonPass) or doesPlayerOwn(player, balloonviptshirt) then
				storage.GreenBalloon:clone().Parent = player.Backpack
			end
			if doesPlayerOwn(player, applePass) then--or (player and player.userId==80254) then
				storage.RedApple:clone().Parent = player.Backpack
			end
			if doesPlayerOwn(player, compassPass) or doesPlayerOwn(player, goldenGiftBadgeId) then
				storage.Compass:clone().Parent = player.Backpack
			end
		end
		if player.DataReady then
			player:SaveNumber("ConsecutiveWins", 0)	
		end
		wait()
		if player.Character and player.Character.Parent ~= nil then
			local healthscript = player.Character:WaitForChild('Health',10)
			if healthscript then
				healthscript:destroy()
			end
		end
	end
end
function onPlayerEntered(newPlayer)
	newPlayer.Changed:connect(function(property)
		onPlayerRespawn(property,newPlayer)
	end)
	onPlayerRespawn("Character",newPlayer)
	getSurvives(newPlayer)
end
game.Players.ChildAdded:connect(onPlayerEntered)
for i,v in pairs(game.Players:GetPlayers()) do
	delay(0,function()
		onPlayerEntered(v)
	end)
end
game.Players.ChildRemoved:connect(function()
	for _,vid in pairs(ownage) do
		for iplr,_ in pairs(vid) do
			if not (iplr and iplr.Parent and iplr.Parent==game.Players) then
				vid[iplr]=nil
			end
		end
	end
end)

game.Workspace.ChildAdded:connect(function(item)
	if item.className=="Tool" then
		item:destroy()
	end
end)

function findplayer(id)
	for _,v in ipairs(game.Players:GetPlayers()) do
		if v and v.userId==id then
			return v
		end
	end
end
pointsservice.PointsAwarded:connect(function(userId,pointsawarded)
	local plr=findplayer(userId)
	if plr and pointsawarded>0 then
		--event:FireAllClients("PointsAwarded",plr.Name,pointsawarded)		--There used to not be notifications
	end
end)


function checkplayer(player,ph,pst,pst2,amount)
	delay(0,function()
		if player and player.DataReady and ph and pst and pst2 and player~=nil and player.Parent~=nil and player.userId > 0 then
			local userId = player.userId
			local cwscore = player:LoadNumber("ConsecutiveWins") or 0
			player:SaveNumber("ConsecutiveWins",cwscore+amount)
			local disasterscore = player:LoadNumber("Survived"..pst) or 0
			player:SaveNumber("Survived"..pst,disasterscore+amount)
			local mapscore = player:LoadNumber("Survived"..pst2) or 0
			player:SaveNumber("Survived"..pst2,mapscore+amount)
			local totalscore = (getSurvives(player) or 0) + amount		--player:LoadNumber("SurvivedTotal") or 0
			--player:SaveNumber("SurvivedTotal",totalscore+amount)
			local updatedScore = totalscore
			survivesDataStore:UpdateAsync('id'..userId, function(oldValue)
				local oldValue = oldValue or 0
				updatedScore = math.max(totalscore, oldValue)
				return updatedScore
			end)
			playersWins['id'..userId] = updatedScore
			if player~=nil and player.Parent~=nil then
				if cwscore%5>(cwscore+1)%5 then	--fun math that only triggers a win once every five consecutive disasters won
					local pointstoaward = 50
					if pointstoaward >= 1 then
						pointsservice:AwardPoints(userId,pointstoaward)
					end
					badgeService:AwardBadge(userId,66918916)
				end
				local pointstoaward = math.random(10,30)	--just for winning
				if pointstoaward >= 1 then
					pointsservice:AwardPoints(userId,pointstoaward)
				end
			end
			if player~=nil and player.Parent~=nil and amount >= 2 then
				local associatedMultiDisasterBadge = multiDisasterBadges['n'..tostring(amount)]
				if associatedMultiDisasterBadge and associatedMultiDisasterBadge ~= 0 then
					--[[if amount >= 3 then		--This code was used to award the mysterious golden gift during Dec 2016
						badgeService:AwardBadge(userId, goldenGiftBadgeId)
						if player and doesPlayerOwn(player, goldenGiftBadgeId) then
							storage.Compass:clone().Parent = player.Backpack
						end
					end]]
					badgeService:AwardBadge(userId, associatedMultiDisasterBadge)
				end
			end
			if player~=nil and player.Parent~=nil and totalscore>=1 then
				badgeService:AwardBadge(userId,66918518)
			end
			if player~=nil and player.Parent~=nil and totalscore>=10 then
				badgeService:AwardBadge(userId,66918551)
			end
			if player~=nil and player.Parent~=nil and totalscore>=25 then
				badgeService:AwardBadge(userId,66918611)
			end
			if player~=nil and player.Parent~=nil and totalscore>=50 then
				badgeService:AwardBadge(userId,66918640)
			end
			if player~=nil and player.Parent~=nil and totalscore>=100 then
				badgeService:AwardBadge(userId,66918685)
			end
			if player~=nil and player.Parent~=nil and totalscore>=200 then
				badgeService:AwardBadge(userId,66918716)
			end
			if player~=nil and player.Parent~=nil and totalscore>=400 then
				badgeService:AwardBadge(userId,66918795)
			end
			if ph~=nil and ph.Parent~=nil and player~=nil and player.Parent~=nil and ph.Health<=10 then
				badgeService:AwardBadge(userId,66919023)
			end
			if player~=nil and player.Parent~=nil then
				if pst2=="Sunny Ranch" and pst=="Fire" then
					badgeService:AwardBadge(userId,66918988)
				elseif pst2=="Trailer Park" and pst=="Tornado" then
					badgeService:AwardBadge(userId,66956295)
				elseif pst2=="Surf Central" and pst=="Tsunami" then
					badgeService:AwardBadge(userId,66918948)
				elseif pst2=="Happy Home" and pst=="Flash Flood" then
					badgeService:AwardBadge(userId,66919105)
				elseif pst2=="Fort Indestructible" and pst=="Thunder Storm" then
					badgeService:AwardBadge(userId,66919155)
				elseif pst2=="Rakish Refinery" and pst=="Acid Rain" then
					--badgeService:AwardBadge(v.userId,0)
				end
			end
		end
	end)
end

function updateleaderboard()
	local surviveslist={}
	for _,plr in pairs(game.Players:GetPlayers()) do
		if plr and plr.DataReady then
			local totalwins = getSurvives(plr) or 0
			local place=1
			for i,v in ipairs(surviveslist) do
				if v and v[2] and totalwins<=v[2] then
					place=i+1
				end
			end
			table.insert(surviveslist,place,{plr,totalwins})
		end
	end
	local removelabellist={}
	for _,v in pairs(t10clipframe:GetChildren()) do
		if string.sub(v.Name,1,5)=="Label" then
			removelabellist[v]=true
		end
	end
	local place=0
	for i,v in ipairs(surviveslist) do
		if v and v[1] and v[2] then
			place=place+1
			if place<=10 then
				local desiredpos=UDim2.new(0,0,0,145+(place-1)*45)
				local label=t10clipframe:FindFirstChild("Label"..v[1].Name)
				if not label then
					label=t10template:clone()
					label.Name="Label"..v[1].Name
					label.NameLabel.Text=v[1].Name
					label.Position=UDim2.new(0,0,1,50)
					label.Visible=true
					label.Parent=t10clipframe
				end
				label.WinsLabel.Text=tostring(v[2])
				label:TweenPosition(desiredpos,"Out","Quad",1+math.random()*5,true)
				removelabellist[label]=false
			end
		end
	end
	for i,v in pairs(removelabellist) do
		if i and v~=false then
			i:destroy()
		end
	end
end

local billboardBalloonDebounce = false
game.Workspace:WaitForChild('BillboardBalloon'):WaitForChild('Board').Touched:connect(function(hit)
	if not billboardBalloonDebounce and hit and hit.Parent and hit.Parent:FindFirstChild('Humanoid') then
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			billboardBalloonDebounce = true
			if not doesPlayerOwn(player, balloonPass) then 
				marketPlaceService:PromptPurchase(player,balloonPass,false)
			end
			wait(1)
			billboardBalloonDebounce = false
		end
	end
end)

local billboardAppleDebounce = false
game.Workspace:WaitForChild('BillboardApple'):WaitForChild('Board').Touched:connect(function(hit)
	if not billboardBalloonDebounce and hit and hit.Parent and hit.Parent:FindFirstChild('Humanoid') then
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			billboardAppleDebounce = true
			if not doesPlayerOwn(player, applePass) then
				marketPlaceService:PromptPurchase(player,applePass,false)
			end
			wait(1)
			billboardAppleDebounce = false
		end
	end
end)

local billboardCompassDebounce = false
game.Workspace:WaitForChild('BillboardCompass'):WaitForChild('Board').Touched:connect(function(hit)
	if not billboardBalloonDebounce and hit and hit.Parent and hit.Parent:FindFirstChild('Humanoid') then
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			billboardCompassDebounce = true
			if not doesPlayerOwn(player, compassPass) then
				marketPlaceService:PromptPurchase(player,compassPass,false)
			end
			wait(1)
			billboardCompassDebounce = false
		end
	end
end)

event.OnServerEvent:connect(function(player,...)
	if player then
		local tuple={...}
		if tuple[1]=='ClickedBalloon' then
			if not doesPlayerOwn(player, balloonPass) then
				marketPlaceService:PromptPurchase(player, balloonPass, false)
			end
		elseif tuple[1]=='ClickedApple' then
			if not doesPlayerOwn(player, applePass) then
				marketPlaceService:PromptPurchase(player, applePass, false)
			end
		elseif tuple[1]=='ClickedCompass' then
			if not doesPlayerOwn(player, applePass) then
				marketPlaceService:PromptPurchase(player, compassPass, false)
			end
		elseif tuple[1] == 'MapVote' then
			local choice = mapVotesStorage:FindFirstChild(tuple[2])
			if choice and player and not choice:FindFirstChild(player.Name) then
				for _,choiceTag in pairs(mapVoteChoices) do
					local oldVote = choiceTag:FindFirstChild(player.Name)
					if oldVote then
						oldVote:Destroy()
					end
				end
				local vote = Instance.new('StringValue')
				vote.Name = player.Name
				vote.Parent = choice
			end
		end
	end
end)
marketPlaceService.PromptPurchaseFinished:connect(function(player, assetid, happened)
	--local happened = player and doesPlayerOwn(player, assetid)	--There is currently a bug where 'happened' can be wrong. This line gets the true value.
	if player and happened then
		setPlayerOwns(player, assetid, true)
		local backpack = player:FindFirstChild('Backpack')
		if backpack then
			local character = backpack
			if player.Character and player.Character.Parent and player.Character.Parent then
				character = player.Character
			end
			if assetid == balloonPass then
				if not (backpack:FindFirstChild('GreenBalloon') or character:FindFirstChild('GreenBalloon')) then
					storage.GreenBalloon:clone().Parent = player.Backpack
				end
			elseif assetid == applePass then
				if not (backpack:FindFirstChild('RedApple') or character:FindFirstChild('RedApple')) then
					storage.RedApple:clone().Parent = player.Backpack
				end
			elseif assetid == compassPass then
				if not (backpack:FindFirstChild('Compass') or character:FindFirstChild('Compass')) then
					storage.Compass:clone().Parent = player.Backpack
				end
			end
		end
	end
end)

function setMapVoteOptions()
	local structures = storage.Structures:GetChildren()
	for _,choiceTag in pairs(mapVoteChoices) do
		choiceTag:ClearAllChildren()
		choiceTag.Value = structures[math.random(#structures)].Name
	end
end
setMapVoteOptions()

while true do
	wait(20)
	while #game.Players:GetPlayers()<1 do
		oldcontent.Status.Value = "Waiting for more players"
		wait(1)
	end
	updateleaderboard()
	game.Workspace.Structure:ClearAllChildren()
	for i,v in ipairs(game.Workspace:GetChildren()) do
		if v:IsA("Accoutrement") then
			v:destroy()
		end
	end
	wait(3)
	--[[
	local structures=storage.Structures:GetChildren()
	local rs=math.random(1,#structures)
	local ns=structures[rs]:clone()]]

	local map1Votes = #(mapVoteChoice1Tag:GetChildren())
	local map2Votes = #(mapVoteChoice2Tag:GetChildren())
	local map3Votes = #(mapVoteChoice3Tag:GetChildren())
	local highestVote = 0
	local highestVoteList = {}

	if map1Votes > highestVote then
		highestVote = map1Votes
		highestVoteList = {mapVoteChoice1Tag}
	elseif map1Votes == highestVote then
		table.insert(highestVoteList, mapVoteChoice1Tag)
	end
	if map2Votes > highestVote then
		highestVote = map2Votes
		highestVoteList = {mapVoteChoice2Tag}
	elseif map2Votes == highestVote then
		table.insert(highestVoteList, mapVoteChoice2Tag)
	end
	if map3Votes > highestVote then
		highestVote = map3Votes
		highestVoteList = {mapVoteChoice3Tag}
	elseif map3Votes == highestVote then
		table.insert(highestVoteList, mapVoteChoice3Tag)
	end

	local targetMapName = highestVoteList[math.random(#highestVoteList)].Value
	local ns = storage.Structures:FindFirstChild(targetMapName):clone()
	--local ns = storage.Structures:FindFirstChild('Furious Station'):clone()	--This is where you pick new map for testing


	setMapVoteOptions()

	ns.Parent=game.Workspace.Structure
	oldcontent.Information.Value=ns.Name
	oldcontent.Status.Value="New Map"
	wait(3)
	ns:MakeJoints()
	wait(2)
	spread(ns,function(mdl2)
		if mdl2~=nil and mdl2:IsA("BasePart") then
			if not mdl2:FindFirstChild("KeepAnchored") then
				mdl2.Anchored=false
			end
		end
	end)

	wait(1)
	disasterNumber = disasterNumber + 1
	local numMultiDisasters = 1
	multiDisaster = disasterNumber%3==1 and #disasters>1 and weatherMachineTag.Value>0	--every fourth round is a double disaster
	if multiDisaster then
		print('Multi-Disaster')
		oldcontent.Status.Value = "Multi-Disaster"
		while weatherMachineTag.Value > 0 do
			wait(1)
			weatherMachineTag.Value = weatherMachineTag.Value - 1
			numMultiDisasters = numMultiDisasters + 1
			if numMultiDisasters >= 7 then
				break
			end
		end
		local thisPowerUpPlayers = {}
		while #powerUpPlayers > 0 and #thisPowerUpPlayers < 10 do
			local playerName = powerUpPlayers[1]
			if playerName then
				local found = false
				for _,v in pairs(thisPowerUpPlayers) do
					if v == playerName then
						found = true
					end
				end
				if not found then
					table.insert(thisPowerUpPlayers, playerName)
				end
			end
			table.remove(powerUpPlayers,1)
		end
		event:FireAllClients("Multi-Disaster", numMultiDisasters, thisPowerUpPlayers)
		wait(5)
	end
	local playingDisasters = {}
	if #disasters > 1 then
		while #playingDisasters < math.min(numMultiDisasters, #disasters) do
			local chosenDisaster = nil
			while not chosenDisaster do
				chosenDisaster = disasters[math.random(1,#disasters)]
				if chosenDisaster == lastDisaster and not multiDisaster then	--don't replay last disaster unless it's multi-disaster
					chosenDisaster = nil
				end
				for _,v in pairs(playingDisasters) do	--don't add the same disaster multiple times
					if v == chosenDisaster then
						chosenDisaster = nil
					end
				end
			end
			print(chosenDisaster.Name)
			table.insert(playingDisasters, chosenDisaster)
		end
	else
		table.insert(playingDisasters, disasters[1])
	end
	lastDisaster = playingDisasters[1]

	for i,v in ipairs(game.Players:GetPlayers()) do
		if v then
			if v.Character then
				local t=v.Character:FindFirstChild("HumanoidRootPart")
				local h=v.Character:FindFirstChild("Humanoid")
				if t~=nil and h~=nil then
					if h.Health>0 then
						t.Velocity = Vector3.new(0,0,0)
						v.Character:MoveTo((CFrame.new(-109,47,16.5)+Vector3.new((math.random()-.5)*40,0,(math.random()-.5)*40)).p)
						local st = Instance.new("StringValue")
						st.Name = "SurvivalTag"
						st.Value = lastDisaster.Name
						local st2 = Instance.new("StringValue")
						st2.Name = "MapName"
						st2.Value = ns.Name
						st2.Parent = st
						local st3 = Instance.new("IntValue")
						st3.Name = "ExposureTag"
						st3.Value = 0
						st3.Parent = st
						st.Parent = v.Character
						if v.DataReady then
							disasterscore = v:LoadNumber("Played"..lastDisaster.Name) or 0
							v:SaveNumber("Played"..lastDisaster.Name,disasterscore+1)

							mapscore=v:LoadNumber("Played"..ns.Name) or 0
							v:SaveNumber("Played"..ns.Name,mapscore+1)

							totalscore=v:LoadNumber("PlayedTotal") or 0
							v:SaveNumber("PlayedTotal",totalscore+1)
						end
					end
				end
			end
		end
	end

	for _,disaster in pairs(playingDisasters) do
		spawn(function()
			disaster.PreStart()
		end)
	end

	wait(40)
	updateleaderboard()


	--Start disasters
	local waitingForDisastersFinish = {}
	for index, disaster in pairs(playingDisasters) do
		waitingForDisastersFinish[index] = false
		delay(math.random(0,5),function()
			print('Starting', disaster.Name)
			disaster.Start()
			waitingForDisastersFinish[index] = true
			print('Ended', disaster.Name)
		end)
	end

	--Wait for all disasters to finish
	while true do
		wait(.5)
		local allGood = true
		for _,good in pairs(waitingForDisastersFinish) do
			if not good then
				allGood = false
				break
			end
		end
		if allGood then
			break
		end
	end
	
	oldcontent.Survivers:ClearAllChildren()

	local spawns=game.Workspace.Spawns:GetChildren()
	local pws = {}
	for i,v in ipairs(game.Players:GetPlayers()) do
		if v then
			if v.Character then
				local t=v.Character:FindFirstChild("HumanoidRootPart")
				local h=v.Character:FindFirstChild("Humanoid")
				if t~=nil and h~=nil then
					h.Sit=false
					local st=v.Character:FindFirstChild("SurvivalTag")
					if st~=nil and h.Health>0 then
						v.Character:MoveTo(spawns[math.random(1,#spawns)].Position)
						table.insert(pws,v.Name)
						checkplayer(v,h,st.Value, st.MapName.Value, numMultiDisasters)
						local plrgui = v:FindFirstChild("PlayerGui")
						if plrgui then
							local gui = plrgui:FindFirstChild("MainGui")
							if gui then
								if multiDisaster then
									local sound1 = gui:FindFirstChild("Cheer1Sound")
									if sound1 then
										sound1:Play()
									end
									local sound2 = gui:FindFirstChild("Cheer2Sound")
									if sound2 then
										sound2:Play()
									end
								else
									local sound = gui:FindFirstChild("Cheer"..tostring(math.random(1,2)).."Sound")
									if sound then
										sound:Play()
									end
								end
							end
						end
					end
					for _,v in pairs(v.Character:GetChildren()) do
						if v.Name == "SurvivalTag" then
							v:destroy()
						end
					end
				end
			end
			local plrgui = v:FindFirstChild("PlayerGui")
			if plrgui then
				for _,vgui in pairs(plrgui:GetChildren()) do
					if vgui and vgui.Name ~= "MainGui" and vgui.Name ~= 'Chat' then
						vgui:destroy()
					end
				end
			end
		end
	end
	pws = RandomizeTable(pws)
	for i,v in ipairs(pws) do
		local sst = Instance.new("StringValue")
		sst.Name = v
		sst.Parent = oldcontent.Survivers
	end
	oldcontent.Status.Value = "Survivers"
end




