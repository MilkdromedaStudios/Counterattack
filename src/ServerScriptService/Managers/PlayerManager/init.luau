local PlayerManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)
local PlaceholderRig = require(ReplicatedStorage.Modules.PlaceholderRig)
local TimeManager = require(ServerScriptService.Managers.TimeManager)

local AntiFly = require(ServerScriptService.Security.AntiFly)
local CommonFunctions = require(ServerScriptService.System.CommonFunctions)

local Network = require(ReplicatedStorage.Modules.Network)

local threads: {thread} = {}

local Hitboxes = ServerStorage.Assets.Hitboxes

local StarterCharacterScripts = game:GetService("StarterPlayer").StarterCharacterScripts
local PlayerFolder = workspace.Players

local StunSPPrefab = Utils.Instance.FindFirstChild(script, "StunSpawnProtection")

function PlayerManager:Init()
	local TimePlayedThreads = {}

	ReplicatedStorage.PlaceVersion.Value = game.PlaceVersion

	if #game.PrivateServerId > 0 then
		table.insert(CommonFunctions.AdminPerms, {
			Name = Players:GetPlayerByUserId(game.PrivateServerOwnerId).Name,
			UserId = game.PrivateServerOwnerId,
			Rank = "ServerOwner",
		})
	end

	Network:SetConnection("AddLoadedPlayer", "REMOTE_EVENT", function(plr: Player)
		PlayerManager.OnPlayerLoad(plr)
	end)

	Utils.Player.ObservePlayers(function(plr: Player)
		if RunService:IsStudio() then
			table.insert(CommonFunctions.AdminPerms, {
				Name = plr.Name,
				UserId = plr.UserId,
				Rank = "Owner",
			})
		end

		Utils.Character.ObserveCharacter(plr, function(char)
			task.spawn(function()
				require(char:FindFirstChild("Server"):FindFirstChild("ScriptInitter")):Init()
			end)

			AntiFly._SetupCharacter(plr, char)
			
			local Role = char:FindFirstChild("Role")

			--[[if char:GetAttribute("BaseSpeed") == nil then
				char:SetAttribute("BaseSpeed", 10.5)
			end]]
			
			if char:GetAttribute("BaseSpeed") == nil then
				local defaultSpeed = 10.5
				local charName = char:GetAttribute("CharacterName")
				local charSkin = char:GetAttribute("CharacterSkinName")
				local roleValue
				if char:FindFirstChild("Role") then
					roleValue = char.Role.Value
				end
				
				if roleValue and charName and #charName > 0 then
					local moduleInstance = Utils.Instance.GetCharacterModule(roleValue, charName, charSkin)
					if moduleInstance then
						local success, mod = pcall(require, moduleInstance)
						if success and mod.GameplayConfig and type(mod.GameplayConfig.BaseSpeed) == "number" then
							defaultSpeed = mod.GameplayConfig.BaseSpeed
						end
					end
				end
				
				char:SetAttribute("BaseSpeed", defaultSpeed)
			end

			char.Parent = PlayerFolder
			
			local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
        	Humanoid.BreakJointsOnDeath = false

			local KillerValue
			if Role.Value ~= "Spectator" then
				PlayerManager._SetupHitboxes(char)

				local CollisionGroup = Role.Value

				for _, Part in char:GetDescendants() do
					if not Part:IsA("BasePart") or Part:IsDescendantOf(char.Hitboxes) then
						continue
					end
					
					Part.CollisionGroup = CollisionGroup
				end

				-- `Killer` holds whoever last damaged this character, so kill credit still
				-- lands when they bleed out from a status effect instead of a direct hit.
				--
				-- Classic mode only gives this to survivors (the killer has nobody to be
				-- killed by). In a Free For All everybody can be killed, so everybody gets one.
				if GameMode.Enabled or Role.Value ~= "Killer" then
					KillerValue = Instance.new("ObjectValue")
					KillerValue.Name = "Killer"
					KillerValue.Parent = char
					local KillerValueThread
					KillerValue.Changed:Connect(function(value: Instance?)
						if KillerValueThread then
							task.cancel(KillerValueThread)
						end

						if not value then
							return
						end

						KillerValueThread = task.delay(15, function()
							KillerValue.Value = nil
						end)
					end)
				end

				if Role.Value == "Killer" then
					local HRP = Utils.Character.GetRootPart(char)
					local StunSP = StunSPPrefab:Clone()
					StunSP.Parent = HRP
					local Weld = Instance.new("Weld")
					Weld.Name = "StunProtectionWeld"
					Weld.Parent = HRP
					Weld.Part0 = HRP
					Weld.Part1 = StunSP
				end
			else
				for _, Part in char:GetDescendants() do
					if not Part:IsA("BasePart") then
						continue
					end
					
					Part.CollisionGroup = "Spectator"
				end
			end

			local LeaveConn
			if KillerValue then
				LeaveConn = Players.PlayerRemoving:Connect(function(p: Player)
					if p ~= plr then
						return
					end

					LeaveConn:Disconnect()
					if KillerValue and KillerValue.Value then
						if not char:GetAttribute("Dead") then
                			Network:FireClientConnection(KillerValue.Value, "KilledPlayer", "REMOTE_EVENT", plr)
                			Network:FireConnection("KilledPlayer", KillerValue.Value, plr)
						end

            	    	CommonFunctions.GrantRewardToPlayer(KillerValue.Value, {
							Money = 7,
							EXP = 20,
							Reason = GameMode.Enabled and "making a fighter ragequit" or "making a Survivor ragequit",
						})

						--i'm leaving this because it's funny to have double the extra time when someone ragequits lol -Dyscarn
						PlayerManager._AddTimeForKill()
					end
				end)
			end

			Utils.Character.ObserveOnDeath(Humanoid, function()
				char:SetAttribute("Dead", true)

				if LeaveConn then
					LeaveConn:Disconnect()
				end

				if KillerValue and KillerValue.Value then
                	Network:FireClientConnection(KillerValue.Value, "KilledPlayer", "REMOTE_EVENT", plr)
                	Network:FireConnection("KilledPlayer", KillerValue.Value, plr)

					CommonFunctions.UpdatePlayerStat(KillerValue.Value, "KillerStats.Kills", 1)
                	CommonFunctions.GrantRewardToPlayer(KillerValue.Value,
						GameMode.Enabled and GameMode.Config.KillReward or {Money = 20, EXP = 60, Reason = "killing a Survivor"}
					)

					PlayerManager._RegisterKill(KillerValue.Value)
					PlayerManager._AddTimeForKill()
				end

        	    threads[plr.UserId] = task.delay(3, function()
					PlayerManager._RespawnPlayer(plr)
        	        threads[plr.UserId] = nil
        	    end)
        	end)
		end)
		
		task.defer(function()
			--saving this before hand just in case there's a leave
			local name = plr.NameDisplayDistance
			local TimePlayed = Utils.Instance.FindFirstChild(plr, "PlayerData.Stats.General.TimePlayed", 10)
			if not TimePlayed then
				warn("[PlayerManager:Init()] TimePlayed not found for player "..name.."!")
				return
			end
			TimePlayedThreads[plr.UserId] = RunService.Heartbeat:Connect(function(delta: number)
				TimePlayed.Value += delta
			end)
		end)

		PlayerManager._RespawnPlayer(plr)
	end)

	Players.PlayerRemoving:Connect(function(plr: Player)
		if ReplicatedStorage.LoadedPlayers:FindFirstChild(plr.Name) then
			ReplicatedStorage.LoadedPlayers[plr.Name]:Destroy()
		end

		if TimePlayedThreads[plr.UserId] then
			TimePlayedThreads[plr.UserId]:Disconnect()
		end
	end)

    Network:SetConnection("CancelAutoRespawn", "REMOTE_EVENT", function(plr: Player)
        PlayerManager.CancelAutoRespawn(plr)
    end)
end

--[=[
    Internal: adds time to the match clock after a kill.

    Classic mode only — that's the original flat +35s for the killer. The Free For All
    arena has no clock at all, so there is nothing to extend.
]=]
function PlayerManager._AddTimeForKill()
	if GameMode.Enabled then
		return
	end

	TimeManager.SetTime(TimeManager.CurrentTime + 35)
end

--[=[
    Internal: tells the round manager somebody scored a kill so killstreaks can tick up.

    `RoundManager` is required lazily here on purpose: it requires `ServerCharacterManager`,
    which requires this module, so requiring it at the top of the file would be a cycle.
]=]
function PlayerManager._RegisterKill(killer: Player)
	if not GameMode.Enabled then
		return
	end

	local Success, RoundManager = pcall(require, ServerScriptService.Managers.RoundManager)
	if Success and RoundManager and RoundManager.Callables.RegisterKill then
		RoundManager.Callables.RegisterKill(killer)
	end
end

--- Cancels a player's automatic respawn if they died.
function PlayerManager.CancelAutoRespawn(plr: Player)
    if threads[plr.UserId] then
		pcall(function()
        	task.cancel(threads[plr.UserId])
        	threads[plr.UserId] = nil
		end)
    end
end

--- Internal: Creates all hitboxes available for a character.
function PlayerManager._SetupHitboxes(Character: Model)
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local HumanoidRootPart = Utils.Character.GetRootPart(Character)
	
	-- Get character config for priority
	local hurtboxPriority = 1 -- fallback
	local charName = Character:GetAttribute("CharacterName")
	local charSkin = Character:GetAttribute("CharacterSkinName")
	local roleValue = Character:FindFirstChild("Role") and Character.Role.Value
	
	if roleValue and charName and #charName > 0 then
		local moduleInstance = Utils.Instance.GetCharacterModule(roleValue, charName, charSkin)
		if moduleInstance then
			local success, mod = pcall(require, moduleInstance)
			if success and mod.GameplayConfig and type(mod.GameplayConfig.HitboxPriority) == "number" then
				hurtboxPriority = mod.GameplayConfig.HitboxPriority
			end
		end
	end
	
	local HitboxFolder = Instance.new("Folder")
	HitboxFolder.Name = "Hitboxes"
	HitboxFolder.Parent = Character

	for _, hitbox in Hitboxes:GetChildren() do
		local Weld = Instance.new("Weld")
		Weld.Name = hitbox.Name
		Weld.Parent = HumanoidRootPart
		local h = hitbox:Clone()
		h:SetAttribute("HitboxPriority", hurtboxPriority)
		h.Parent = HitboxFolder
		h.CFrame = HumanoidRootPart.CFrame
		Weld.Part0 = HumanoidRootPart
		Weld.Part1 = h
		Weld.C0 *= CFrame.fromEulerAnglesXYZ(0, 0, math.rad(90))
	end

	Utils.Character.ObserveOnDeath(Humanoid, function()
		for _, Descendant in HitboxFolder:GetDescendants() do
			Descendant:Destroy()
		end
		HitboxFolder:Destroy()
	end)
end

--- Internal: Literally just `Player:LoadCharacterAsync()` but with a safety check so that the `LoadCharacter can only be called when Player is in the world` warn doesn't appear.
function PlayerManager._LoadCharacterAsyncSafely(Player: Player)
	if Player.Parent then
		Player:LoadCharacterAsync()
	end
end

--- Internal: Respawns a player with a possibility to add a custom character rig from `ServerStorage.Assets.Characters`.
function PlayerManager._RespawnPlayer(plr: Player, RigName: string?, RigType: ("Killer" | "Survivor")?, skinName: string?) --: Model
	PlayerManager.CancelAutoRespawn(plr)
	if plr.Character then
		plr.Character:Destroy()
	end

	local function LoadEmpty()
		PlayerManager._LoadCharacterAsyncSafely(plr)

		--creates the role asap
		local Role = Instance.new("StringValue")
		Role.Name = "Role"
		Role.Value = "Spectator"
		Role.Parent = plr.Character

		return plr.Character
	end

	--loads the default char if there's none to load already
	if not RigName or not RigType then
		return LoadEmpty()
	end

	local char

	local function FindChar(Service: "ServerStorage" | "ReplicatedStorage", Name: string, Type: ("Killer" | "Survivor")?, Skin: string?)
		--gets the skin if queued to
		if Skin ~= nil and #Skin > 0 then
			char = Utils.Instance.FindFirstChild(game:GetService(Service).Assets.Characters.Skins[RigType], RigName.."."..Skin, false)
		end

		--if there's a skin then it gets cloned and used
		if char then
			char = char:Clone()
			char:SetAttribute("CharacterSkinName", Skin)
			return
		end

		--[[
			If not, get the default rig for the character.

			NOTE: this used to be a direct index — `.Assets.Characters[RigType][RigName]`.
			Indexing a missing child THROWS in Roblox rather than returning nil, so a
			character whose model hadn't been built yet raised
			"X is not a valid member of Folder" right here, and the `if not char`
			fallback underneath was unreachable. That error propagated all the way up
			through `SetupCharacter` and aborted whatever loop was spawning players.

			`FindFirstChild` returns nil instead, so the ServerStorage fallback and the
			LoadEmpty path below can actually do their jobs.
		]]
		local RoleFolder = Utils.Instance.FindFirstChild(game:GetService(Service).Assets.Characters, RigType, 0)
		local Prefab = RoleFolder and RoleFolder:FindFirstChild(RigName)

		if not Prefab then
			--secret characters live in ServerStorage, so check there before giving up
			if Service == "ReplicatedStorage" then
				FindChar("ServerStorage", Name, Type, Skin)
				return
			end

			warn(
				"[PlayerManager._RespawnPlayer()] No rig named \""..tostring(RigName).."\" found in "..
				"ReplicatedStorage.Assets.Characters."..tostring(RigType).." or ServerStorage.Assets.Characters."..tostring(RigType)..
				"! Build the model and make sure its name matches the character module EXACTLY."
			)
			return
		end

		char = Prefab:Clone()
	end
	FindChar("ReplicatedStorage", RigName, RigType, skinName)

	--[[
		No model built for this character yet, so stand in a classic Roblox noob.

		This used to fall through to `LoadEmpty()`, which spawns the player as a
		SPECTATOR — meaning they silently never entered the match at all. A placeholder
		body keeps them in the fight as the character they actually chose: the module,
		abilities, health, speed and animations are all the real ones, and only the body
		is temporary. Build the real rig and the game picks it up automatically.
	]]
	if not char then
		warn(
			"[PlayerManager._RespawnPlayer()]: No model for \""..tostring(RigName).."\" — "..
			"spawning "..plr.Name.." with a placeholder noob body instead. "..
			"Build the rig in ReplicatedStorage.Assets.Characters."..tostring(RigType).." to replace it."
		)

		char = PlaceholderRig.Build(RigName)
	end

	--[[
		A rig that EXISTS but is malformed used to fall through to `LoadEmpty()`, which
		spawns the player as a SPECTATOR — so a half-built model left them stuck outside the
		fight with no body and nothing replacing it. "Some skins load, some are broken and
		never get swapped out" is exactly that branch.

		A missing model already fell back to the placeholder noob. A broken one should do
		the same thing: the player keeps the character they picked, with a stand-in body,
		and the Output says precisely which part of the rig is wrong.
	]]
	do
		local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
		local RootPart = char:FindFirstChild("HumanoidRootPart")

		if not Humanoid or not RootPart then
			local Missing = {}
			if not Humanoid then table.insert(Missing, "a Humanoid") end
			if not RootPart then table.insert(Missing, "a HumanoidRootPart") end

			warn(
				"[PlayerManager._RespawnPlayer()] The model for \""..tostring(RigName).."\" is missing "..
				table.concat(Missing, " and ").." in the root of the model, so it can't be used as a character. "..
				"Spawning "..plr.Name.." with a placeholder noob instead — fix the model and it swaps back automatically."
			)

			char:Destroy()
			char = PlaceholderRig.Build(RigName)
			Humanoid = char:FindFirstChildWhichIsA("Humanoid")
		end

		local Animator = Humanoid:FindFirstChildWhichIsA("Animator")
		if not Animator then
			Animator = Instance.new("Animator")
			Animator.Parent = Humanoid
		end
	end
	
	--[[
		Hand-built rigs very often ship without `PrimaryPart` set, and a surprising amount
		of the engine quietly depends on it. `Utils.Character.WaitForCharacterLoaded()`
		yields on `GetPropertyChangedSignal("PrimaryPart")`, so on a rig that never sets
		one EVERY `ObserveCharacter` callback waits forever — client ability loading, the
		killer intro's fade-out, the ability GUI, the lot. It also makes `PivotTo()` land
		the character accurately on its spawn point instead of by bounding-box centre.

		So point it at the root part ourselves rather than leaving that landmine armed.
	]]
	if not char.PrimaryPart then
		local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
		local Root = char:FindFirstChild("HumanoidRootPart")
			or (Humanoid and Humanoid.RootPart)
			or char:FindFirstChild("Torso")
			or char:FindFirstChildWhichIsA("BasePart")

		if Root and Root:IsA("BasePart") then
			warn(
				"[PlayerManager._RespawnPlayer()] \""..tostring(RigName).."\"'s model has no PrimaryPart set, "..
				"so \""..Root.Name.."\" is being used. Set the model's PrimaryPart to its HumanoidRootPart in "..
				"Studio — a lot of the engine waits on it before a character counts as loaded."
			)
			char.PrimaryPart = Root
		else
			warn(
				"[PlayerManager._RespawnPlayer()] \""..tostring(RigName).."\"'s model has no BasePart in it at "..
				"all, so there's nothing to use as a PrimaryPart. This character will not load correctly."
			)
		end
	end

	--[[
		Unanchor the whole rig.

		Models built by hand in Studio are almost always anchored — it's the only sane way
		to build one without it collapsing on the workspace floor — and an anchored part
		anywhere in a character freezes the entire assembly. The Humanoid then reports a
		perfectly normal WalkSpeed and simply never moves. The camera follows it correctly
		to the arena and then sits there, which reads exactly like a broken camera.

		Classic mode hid this by accident: `SetupPlayer` anchored the root for the intro and
		`PlayIntro` unanchored it three seconds later, so anchored rigs were quietly fixed
		on the way in. The arena has no intro, so nothing was undoing it.

		`AntiFly` also treats an anchored root as "not flying" and skips its check entirely,
		so nothing else in the engine would have complained either.
	]]
	do
		local AnchoredCount = 0
		for _, Descendant in char:GetDescendants() do
			if Descendant:IsA("BasePart") and Descendant.Anchored then
				Descendant.Anchored = false
				AnchoredCount += 1
			end
		end

		if AnchoredCount > 0 then
			warn(
				"[PlayerManager._RespawnPlayer()] \""..tostring(RigName).."\"'s model had "..AnchoredCount..
				" anchored part(s), which would have left "..plr.Name.." unable to move. Unanchored them. "..
				"Uncheck Anchored on every part of your character models in Studio."
			)
		end
	end

	char:SetAttribute("CharacterName", RigName)

	char.Name = plr.Name

	--creates the role asap
	local Role = Instance.new("StringValue")
	Role.Name = "Role"
	Role.Value = RigType
	Role.Parent = char
	
	char:PivotTo(plr.Character and plr.Character.WorldPivot or CFrame.new(0, 10, 0))
	
	--clones all scripts
	for _, Child in StarterCharacterScripts:GetChildren() do
		Child:Clone().Parent = char
	end

	--adds the char to `Players` in `workspace`
	char.Parent = PlayerFolder
	
	plr.Character = char

	--failsafe
	PlayerManager.CancelAutoRespawn(plr)

	Network:FireAllClientConnection("SetupLocalRagdoll", "REMOTE_EVENT", plr)

	return char
end

function PlayerManager._AttemptWelcomeAchievementGranting(Player: Player)
	if not Player:IsA("Player") then
		return
	end

	if not RunService:IsStudio() then
		task.defer(CommonFunctions.CompleteAchievement, Player, "General.Welcome")
	end
end

function PlayerManager.OnPlayerLoad(Player: Player)
	PlayerManager._AttemptWelcomeAchievementGranting(Player)

	task.wait(3)

	if Player then
		if not ReplicatedStorage.LoadedPlayers:FindFirstChild(Player.Name) then
			local Value = Instance.new("ObjectValue")
			Value.Name = Player.Name
			Value.Value = Player
			Value.Parent = ReplicatedStorage.LoadedPlayers
		end

		local Log = Utils.Instance.FindFirstChild(Player, "PlayerData.Misc.LastSeenLog")
		Log.Value = game.PlaceVersion
	end
end

return PlayerManager
