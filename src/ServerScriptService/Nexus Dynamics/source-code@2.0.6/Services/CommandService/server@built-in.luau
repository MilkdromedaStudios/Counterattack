----- || LIBRARIES || -----
Libraries = require("../../Connector")
storage = {}


----- || MAIN || -----
return {
	
	--[[
		Boolean | String | Number | Enum | Vector3 | Color | Material | FullName | BasePart | Instance | UnionOperation | Effect | Constraint
		
		Player | Team | Speed | Power | JumpHeight | Morph | Character
		
		{
			Name = "",
			Description = "",

			Aliases = {"example", "example"},


			--

			Rank = 1,
			CaseSensitive = false,
			
			Loopable = false,
			Frequency = 1,

			Arguments = { "Player", "Id" },

			--

			PreFunction = function() : ()
				
			end,

			Function = function( speaker: Player, args: any ) : ()
				
			end,

			UnFunction = function( speaker: Player, args: any ) : ()
				
			end,
		},
	]]
	
	{
		Name = "clear",
		Description = "Clears clones and other command instances.",

		Aliases = {"clear"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, instance in workspace:FindFirstChild("Nexus Dynamics // Workspace"):GetChildren() do instance:Destroy() end
		end,
	},

	{
		Name = "refresh",
		Description = "Respawns player on last known position.",

		Aliases = {"re", "reset", "resetcharacter", "refreshcharacter", "resetplayer", "refreshplayer"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				coroutine.wrap(function()
					local position = plr.Character:GetPivot()
					plr:LoadCharacter()
					
					repeat task.wait() until plr.Character and plr.Character:FindFirstChild("Humanoid")
					
					plr.Character:PivotTo(position)
				end)()				
			end

		end,
	},
	
	{
		Name = "respawn",
		Description = "Resets the player using LoadCharacter.",

		Aliases = {"respawns", "respawncharacter", "respawnplayer"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				plr:LoadCharacter()
			end
		end,
	},
	
	{
		Name = "rejoin",
		Description = "Rejoin the current server.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end

				game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId, game.JobId, plr)
			end
		end,
	},
	
	{
		Name = "join",
		Description = "Join a specific player in another server.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User" },

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../ServerService"):JoinPlayer(speaker.UserId, tonumber(args[1][1]) or game:GetService("Players"):GetUserIdFromNameAsync(args[1][1]))
		end,
	},
	
	{
		Name = "shirt",
		Description = "Gives player a new shirt.",

		Aliases = {"giveshirt", "addshirt", "setshirt"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				if not plr.Character:FindFirstChild("Humanoid") then continue end
				
				--
				
				local hd = plr.Character:FindFirstChild("Humanoid"):GetAppliedDescription()
				hd.Shirt = args[2]
				pcall(function() plr.Character.Humanoid:ApplyDescription(hd) end)
			end
		end,
	},	
	
	{
		Name = "pants",
		Description = "Gives player new pants.",

		Aliases = {"givepants", "addpants", "setpants"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				local hd = plr.Character:FindFirstChild("Humanoid"):GetAppliedDescription()
				hd.Pants = args[2]
				pcall(function() plr.Character.Humanoid:ApplyDescription(hd) end)				
			end
		end,
	},	
	
	{
		Name = "hat",
		Description = "Gives the player a hat.",

		Aliases = {"hats", "sethat", "addhat"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do 
				if not plr:IsA("Player") then continue end
				if not plr.Character:FindFirstChild("Humanoid") then continue end
				
				--

				local hd = plr.Character:FindFirstChild("Humanoid"):GetAppliedDescription()
				hd.HatAccessory = hd.HatAccessory..`,{args[2]}`
				pcall(function() plr.Character.Humanoid:ApplyDescription(hd) end)				
			end
		end,
	},		

	{
		Name = "clearHats",
		Description = "Clears all accessories of player.",

		Aliases = {"clearaccessories"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do 
				if not plr:IsA("Player") then continue end
				if not plr.Character:FindFirstChild("Humanoid") then continue end

				--
				
				pcall(function() 
					local hd = plr.Character:FindFirstChild("Humanoid"):GetAppliedDescription()
					hd:SetAccessories({}, false)
					plr.Character.Humanoid:ApplyDescription(hd) 
				end)
				
				for _, accessory in plr.Character:GetDescendants() do
					pcall(function()
						if accessory.ClassName == "Accessory" then accessory:Destroy() end	
					end)
				end			
			end
		end,
	},

	{
		Name = "face",
		Description = "Gives player a face.",

		Aliases = {"giveface", "addface", "setface"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character:FindFirstChild("Humanoid") then continue end			

				--
				
				local hd = plr.Character:FindFirstChild("Humanoid"):GetAppliedDescription()
				hd.Face = args[2]
				pcall(function() plr.Character.Humanoid:ApplyDescription(hd) end)				
			end
		end,
	},	
	
	{
		Name = "invisible",
		Description = "Hides the player's character.",

		Aliases = {"invis"},


		--

		Rank = 2,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if not plr.Character:FindFirstChild("Humanoid") then continue end

					--
				
					for _, object in plr.Character:GetDescendants() do
						if object.Name == "HumanoidRootPart" then continue end
						
						if object:IsA("BasePart") or object:IsA("Decal") then object.Transparency = 1 end
						if (object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Sparkles") or object:IsA("Smoke") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("Highlight") or object:IsA("SurfaceLight") or object:IsA("SpotLight") or object:IsA("PointLight")) then object.Enabled = false end
					end	
				elseif plr:IsA("BasePart") then
					plr.Transparency = 1
				elseif (plr:IsA("ParticleEmitter") or plr:IsA("Fire") or plr:IsA("Sparkles") or plr:IsA("Smoke") or plr:IsA("Trail") or plr:IsA("Beam") or plr:IsA("Highlight") or plr:IsA("SurfaceLight") or plr:IsA("SpotLight") or plr:IsA("PointLight")) then
					plr.Enabled = false
				end		
			end
		end,
	},
	
	{
		Name = "visible",
		Description = "Shows the player's character.",

		Aliases = {"vis"},


		--

		Rank = 2,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if not plr.Character:FindFirstChild("Humanoid") then continue end

					--

					for _, object in plr.Character:GetDescendants() do
						if object.Name == "HumanoidRootPart" then continue end

						if object:IsA("BasePart") or object:IsA("Decal") then object.Transparency = 0 end
						if (object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Sparkles") or object:IsA("Smoke") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("Highlight") or object:IsA("SurfaceLight") or object:IsA("SpotLight") or object:IsA("PointLight")) then object.Enabled = true end
					end	
				elseif plr:IsA("BasePart") then
					plr.Transparency = 0
				elseif (plr:IsA("ParticleEmitter") or plr:IsA("Fire") or plr:IsA("Sparkles") or plr:IsA("Smoke") or plr:IsA("Trail") or plr:IsA("Beam") or plr:IsA("Highlight") or plr:IsA("SurfaceLight") or plr:IsA("SpotLight") or plr:IsA("PointLight")) then
					plr.Enabled = true
				end	
			end
		end,
	},
	
	{
		Name = "color",
		Description = "Apply a specific color to a player.",

		Aliases = {"color3", "brickcolor", "setcolor", "colour", "colour3", "brickcolour", "setcolour"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Color" },

		--

		Function = function( speaker: Player, args: any ) : ()
			
			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if not plr.Character:FindFirstChild("Humanoid") then continue end

					--

					for _, object in plr.Character:GetDescendants() do
						if object.Name == "HumanoidRootPart" then continue end

						pcall(function() object.Color = args[2] end)
						pcall(function() object.Color = ColorSequence.new(args[2]) end)
					end	
				elseif plr:IsA("BasePart") then
					pcall(function() plr.Color = args[2] end)
				elseif (plr:IsA("ParticleEmitter") or plr:IsA("Fire") or plr:IsA("Sparkles") or plr:IsA("Smoke") or plr:IsA("Trail") or plr:IsA("Beam") or plr:IsA("Highlight") or plr:IsA("SurfaceLight") or plr:IsA("SpotLight") or plr:IsA("PointLight")) then
					pcall(function() plr.Color = ColorSequence.new(args[2]) end)
				end	
			end
		end,
	},
	
	{
		Name = "material",
		Description = "Apply a specific material to a player.",

		Aliases = {"mat", "setmat", "setmaterial"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Material" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if not plr.Character:FindFirstChild("Humanoid") then continue end

					--

					for _, object in plr.Character:GetDescendants() do
						if object.Name == "HumanoidRootPart" then continue end

						pcall(function() object.Material = args[2] end)
					end	
				elseif plr:IsA("BasePart") then
					pcall(function() plr.Material = args[2] end)
				end	
			end
		end,
	},
	
	{
		Name = "reflectance",
		Description = "Change how reflective a player is.",

		Aliases = {"reflect", "reflectancy", "glossy"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if not plr.Character:FindFirstChild("Humanoid") then continue end

					--

					for _, object in plr.Character:GetDescendants() do
						if object.Name == "HumanoidRootPart" then continue end

						pcall(function() object.Reflectance = math.clamp(args[2], 0, 1) end)
					end	
				elseif plr:IsA("BasePart") then
					pcall(function() plr.Reflectance = math.clamp(args[2], 0, 1) end)
				end	
			end
		end,
	},
	
	{
		Name = "transparency",
		Description = "Change how reflective a player is.",

		Aliases = {"transparent", "opacity"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if not plr.Character:FindFirstChild("Humanoid") then continue end

					--

					for _, object in plr.Character:GetDescendants() do
						if object.Name == "HumanoidRootPart" then continue end

						pcall(function() object.Transparency = math.clamp(args[2], 0, 1) end)
					end	
				elseif plr:IsA("BasePart") then
					pcall(function() plr.Transparency = math.clamp(args[2], 0, 1) end)
				end	
			end
		end,
	},
	
	{
		Name = "fov",
		Description = "Change a player's field of view.",

		Aliases = {"fieldofview"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "fov",
					fov = args[2] or workspace.Camera.FieldOfView,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "fov",
					fov = workspace.Camera.FieldOfView,
				})
			end
		end,
	},
	
	{
		Name = "fly",
		Description = "Lets the player fly.",

		Aliases = {"flight"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Speed" },

		--

		Function = function( speaker: Player, args: any ) : ()			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<fly>"]:FireClient(plr, true, args[2], true)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()	
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<fly>"]:FireClient(plr, false, args[2], true)
			end
		end,
	},
	
	{
		Name = "noclip",
		Description = "Lets the player noclip.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Speed" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<fly>"]:FireClient(plr, true, args[2], false)
			end
		end,
	},
	
	{
		Name = "clip",
		Description = "Stops the player from noclipping.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<fly>"]:FireClient(plr, false, args[2], false)
			end
		end,
	},
	
	{
		Name = "glitch",
		Description = "Make the player's avatar look glitched.",

		Aliases = {"glitched"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				for _, obj in pairs(plr.Character:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.Color = Color3.fromHSV(math.random(0, 360)/360, math.random(0,2)==0 and 0 or 1, math.random(0,2)==0 and 0 or 1)

					elseif obj:IsA("Decal") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("Clothing")	 then
						obj:Destroy()						
					end
				end
			end
		end,
	},
	
	{
		Name = "clearterrain",
		Description = "Removes all terrain in workspace.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			workspace.Terrain:Clear()
		end,
	},
	
	{
		Name = "colorterrain",
		Description = "Change the terrain color.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Material", "Color" },

		--

		Function = function( speaker: Player, args: any ) : ()
			
			pcall(function() workspace.Terrain:SetMaterialColor(args[1].Name or "Grass", args[2] or workspace.Terrain.Color) end)
			pcall(function() if args[1].Name ~= "Water" then return end workspace.Terrain.WaterColor = args[2] or workspace.Terrain.WaterColor end)
		end,
	},
	
	{
		Name = "award",
		Description = "Awards a badge to a player.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "BadgeId" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				game:GetService("BadgeService"):AwardBadge(plr.UserId, args[2])
			end
		end,
	},	
	
	{
		Name = "brightness",
		Description = "Change the ambience brightness.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Number" },

		--

		Function = function( speaker: Player, args: any ) : () 
			game:GetService("Lighting").Brightness = args[1] or game:GetService("Lighting").Brightness
		end,
	},	
	
	{
		Name = "ambience",
		Description = "Change the ambience color.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Color" },

		--

		Function = function( speaker: Player, args: any ) : () 
			game:GetService("Lighting").Ambient = args[1] or game:GetService("Lighting").Ambient
		end,
	},	
	
	{
		Name = "gravity",
		Description = "Adjust the world gravity.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()
			pcall(function() workspace.Gravity = args[1] or 196.2 end)
		end,
	},	

	{
		Name = "jump",
		Description = "Forces a player to jump.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = true,
		Frequency = 0.5,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end
				
				plr.Character.Humanoid.Jump = true
			end
		end,
	},
	
	{
		Name = "sit",
		Description = "Forces a player to sit.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 0.5,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				plr.Character.Humanoid.Sit = true
			end
		end,
	},
	
	{
		Name = "bighead",
		Description = "Enlarges a player's head.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 0.5,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				for _, plr in args[1] do
					if not plr:IsA("Player") then continue end
					if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

					--

					pcall(function()

						local Humanoid = plr.Character.Humanoid
						
						if Humanoid.RigType == Enum.HumanoidRigType.R6 then
							Libraries.Signals["<notification>"]:FireClient(speaker, {
								type = "notification",
								message = `This command only works on R15.`,
								timer = 10,
							})

							return
						end
						
						Humanoid.HeadScale.Value = 2
					end)

				end
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.HeadScale.Value = 1
				end)

			end
		end,
	},
	
	{
		Name = "smallhead",
		Description = "Shrinks a player's head.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 0.5,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.HeadScale.Value = 0.5
				end)

			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
								type = "notification",
								message = `This command only works on R15.`,
								timer = 10,
							})

						return
					end
					
					Humanoid.HeadScale.Value = 1
				end)

			end
		end,
	},
	
	{
		Name = "headless",
		Description = "Hides a player's head.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 0.5,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				plr.Character.Head.Transparency = 1
				if plr.Character.Head:FindFirstChildWhichIsA("Decal") then plr.Character.Head:FindFirstChildWhichIsA("Decal").Transparency = 1 end
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				plr.Character.Head.Transparency = 0
				if plr.Character.Head:FindFirstChildWhichIsA("Decal") then plr.Character.Head:FindFirstChildWhichIsA("Decal").Transparency = 0 end
			end
		end,
	},
	
	{
		Name = "spin",
		Description = "Spins a player.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local AngularVelocity = plr.Character:FindFirstChild("Nexus Dynamics // Spin Angular Velocity") or Instance.new("AngularVelocity", plr.Character)
				AngularVelocity.Name = "Nexus Dynamics // Spin Angular Velocity"
				AngularVelocity.Attachment0 = plr.Character:FindFirstChild("RootAttachment", true)
				AngularVelocity.AngularVelocity, AngularVelocity.MaxTorque = Vector3.new(0, (args[2] or 16) * 1250, 0), ((args[2] or 16) < 0) and -(args[2] or 16) * 1250 or (args[2] or 16) * 1250
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local AngularVelocity = plr.Character:FindFirstChild("Nexus Dynamics // Spin Angular Velocity")
				if AngularVelocity then AngularVelocity:Destroy() end
			end
		end,
	},
	
	{
		Name = "warp",
		Description = "Wraps the player's FOV in & out.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "warp",
				})
			end
		end,
	},
	
	{
		Name = "blur",
		Description = "Applies a blur effect",

		Aliases = {"blureffect"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Intensity" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "blur",
					intensity = args[2] or 10,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "blur",
					undo = true,
				})
			end
		end,
	},
	
	{
		Name = "freeze",
		Description = "Freezes a player on the spot.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				for _, object in plr.Character:GetDescendants() do

					if object:IsA("BasePart") then object.Anchored = true end
				end			
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				for _, object in plr.Character:GetDescendants() do
					
					if object:IsA("BasePart") then object.Anchored = false end
				end			
			end
		end,
	},
	
	{
		Name = "jail",
		Description = "Puts the player in a box.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			
			local JailCell = function()
				local Model = Instance.new("Model")
				Model.Name = "JailCell"

				local Wall1 = Instance.new("Part", Model)
				Wall1.Position = Vector3.new(-2.8, 3.6, -0)
				Wall1.Color = Color3.fromRGB(116, 134, 157)
				Wall1.Material = Enum.Material.Neon
				Wall1.Transparency = 0.5
				Wall1.Anchored = true
				Wall1.CastShadow = false
				Wall1.Locked = true
				Wall1.Size = Vector3.new(0.4, 7, 6)

				local Wall2 = Instance.new("Part", Model)
				Wall2.Position = Vector3.new(2.8, 3.6, -0)
				Wall2.Color = Color3.fromRGB(116, 134, 157)
				Wall2.Material = Enum.Material.Neon
				Wall2.Transparency = 0.5
				Wall2.Anchored = true
				Wall2.CastShadow = false
				Wall2.Locked = true
				Wall2.Size = Vector3.new(0.4, 7, 6)

				local Wall3 = Instance.new("Part", Model)
				Wall3.Position = Vector3.new(-0, 3.6, 2.8)
				Wall3.Color = Color3.fromRGB(116, 134, 157)
				Wall3.Material = Enum.Material.Neon
				Wall3.Transparency = 0.5
				Wall3.Anchored = true
				Wall3.CastShadow = false
				Wall3.Locked = true
				Wall3.Size = Vector3.new(5.2, 7, 0.4)

				local Wall4 = Instance.new("Part", Model)
				Wall4.Position = Vector3.new(-0, 3.6, -2.8)
				Wall4.Color = Color3.fromRGB(116, 134, 157)
				Wall4.Material = Enum.Material.Neon
				Wall4.Transparency = 0.5
				Wall4.Anchored = true
				Wall4.CastShadow = false
				Wall4.Locked = true
				Wall4.Size = Vector3.new(5.2, 7, 0.4)

				local Roof = Instance.new("Part", Model)
				Roof.Position = Vector3.new(0, 7.225, 0)
				Roof.Color = Color3.fromRGB(17, 17, 17)
				Roof.Material = Enum.Material.Neon
				Roof.Transparency = 0
				Roof.Anchored = true
				Roof.CastShadow = false
				Roof.Locked = true
				Roof.Size = Vector3.new(6.01, 0.4, 6.01)

				local Floor = Instance.new("Part", Model)
				Floor.Name = "Floor"
				Floor.Color = Color3.fromRGB(17, 17, 17)
				Floor.Material = Enum.Material.Neon
				Floor.Transparency = 0
				Floor.Anchored = true
				Floor.CastShadow = false
				Floor.Locked = true
				Floor.Size = Vector3.new(6.01, 0.4, 6.01)

				return Model
			end

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local JailCell = JailCell()
				JailCell.Name, JailCell.Parent = `Nexus Dynamics // JailCell ({plr.UserId})`, workspace
				
				JailCell:PivotTo(plr.Character:GetPivot() + Vector3.new(0, JailCell.Floor.Size.Y*2, 0))		
				
				local wrapped = coroutine.create(function()
					while task.wait(0.5) do if not JailCell then break end
						local isInBox = false

						local array = workspace:GetPartBoundsInBox(JailCell:GetPivot(), JailCell:GetExtentsSize())
						for _, obj in array do if obj:IsDescendantOf(plr.Character) then isInBox = true break end end

						if isInBox then continue end
						plr.Character:PivotTo(JailCell:GetPivot())
					end
				end); coroutine.resume(wrapped)							

				JailCell.Destroying:Once(function()
					pcall(function() coroutine.close(wrapped) end)
				end) 
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local JailCell = workspace:FindFirstChild(`Nexus Dynamics // JailCell ({plr.UserId})`)
				if JailCell then JailCell:Destroy() end			
			end
		end,
	},
	
	{
		Name = "forcefield",
		Description = "Gives the player a forcefield.",

		Aliases = {"ff"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local ForceField = plr.Character:FindFirstChildWhichIsA("ForceField") or Instance.new("ForceField", plr.Character)
				elseif plr:IsA("BasePart") then
					local ForceField = plr:FindFirstChildWhichIsA("ForceField") or Instance.new("ForceField", plr)
				end
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local ForceField = plr.Character:FindFirstChildWhichIsA("ForceField")
					if ForceField then ForceField:Destroy() end	
				elseif plr:IsA("BasePart") then
					local ForceField = plr:FindFirstChildWhichIsA("ForceField")
					if ForceField then ForceField:Destroy() end	
				end		
			end
		end,
	},
	
	{
		Name = "fire",
		Description = "Sets the player on fire.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Color" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local Fire = plr.Character:FindFirstChild("Nexus Dynamics // Fire", true) or Instance.new("Fire", plr.Character.HumanoidRootPart)
					Fire.Name, Fire.Size, Fire.Heat, Fire.Color = "Nexus Dynamics // Fire", 10, 5, args[2] or Color3.fromRGB(236, 139, 70)
				elseif plr:IsA("BasePart") then
					local Fire = plr:FindFirstChild("Nexus Dynamics // Fire", true) or Instance.new("Fire", plr.HumanoidRootPart)
					Fire.Name, Fire.Size, Fire.Heat, Fire.Color = "Nexus Dynamics // Fire", 10, 5, args[2] or Color3.fromRGB(236, 139, 70)
				end	
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local Fire = plr.Character:FindFirstChild("Nexus Dynamics // Fire", true)
					if Fire then Fire:Destroy() end	
				elseif plr:IsA("BasePart") then
					local Fire = plr:FindFirstChild("Nexus Dynamics // Fire", true)
					if Fire then Fire:Destroy() end	
				end			
			end
		end,
	},
	
	{
		Name = "sparkles",
		Description = "Emits sparkles from the player.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Color" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local Sparkles = plr.Character:FindFirstChild("Nexus Dynamics // Sparkles", true) or Instance.new("Sparkles", plr.Character.HumanoidRootPart)
					Sparkles.Name, Sparkles.Color = "Nexus Dynamics // Sparkles", args[2] or Color3.fromRGB(183, 49, 236)
				elseif plr:IsA("BasePart") then
					local Sparkles = plr:FindFirstChild("Nexus Dynamics // Sparkles", true) or Instance.new("Sparkles", plr.HumanoidRootPart)
					Sparkles.Name, Sparkles.Color = "Nexus Dynamics // Sparkles", args[2] or Color3.fromRGB(183, 49, 236)
				end	
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local Sparkles = plr.Character:FindFirstChild("Nexus Dynamics // Sparkles", true)
					if Sparkles then Sparkles:Destroy() end	
				elseif plr:IsA("BasePart") then
					local Sparkles = plr:FindFirstChild("Nexus Dynamics // Sparkles", true)
					if Sparkles then Sparkles:Destroy() end	
				end			
			end
		end,
	},
	
	{
		Name = "smoke",
		Description = "Emits smoke from the player.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Color" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local Smoke = plr.Character:FindFirstChild("Nexus Dynamics // Smoke", true) or Instance.new("Smoke", plr.Character.HumanoidRootPart)
					Smoke.Name, Smoke.Color = "Nexus Dynamics // Smoke", args[2] or Color3.fromRGB(236, 236, 236)
				elseif plr:IsA("BasePart") then
					local Smoke = plr:FindFirstChild("Nexus Dynamics // Smoke", true) or Instance.new("Smoke", plr.HumanoidRootPart)
					Smoke.Name, Smoke.Color = "Nexus Dynamics // Smoke", args[2] or Color3.fromRGB(236, 236, 236)
				end	
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					local Smoke = plr.Character:FindFirstChild("Nexus Dynamics // Smoke", true)
					if Smoke then Smoke:Destroy() end
				elseif plr:IsA("BasePart") then
					local Smoke = plr:FindFirstChild("Nexus Dynamics // Smoke", true)
					if Smoke then Smoke:Destroy() end
				end				
			end
		end,
	},
	
	{
		Name = "name",
		Description = "Gives a player a new name.",

		Aliases = {"rename"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "String" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character then continue end
				plr.Character.Humanoid.DisplayName = args[2]
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				if not plr.Character then continue end
				plr.Character.Humanoid.DisplayName = plr.DisplayName
			end
		end,
	},
	
	{
		Name = "hidename",
		Description = "Hides names on player's character.",

		Aliases = {"hidenames"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
						
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end
				plr.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end,
	},
	
	{
		Name = "showname",
		Description = "Shows names on player's character.",

		Aliases = {"shownames"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end
				plr.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end
		end,
	},
	
	--{
	--	Name = "r15",
	--	Description = "Changes the player to R15.",

	--	Aliases = {"rig15"},


	--	--

	--	Rank = 1,
	--	CaseSensitive = false,

	--	Loopable = false,
	--	Frequency = 1,

	--	Arguments = { "Player" },

	--	--

	--	Function = function( speaker: Player, args: any ) : ()

	--		for _, plr in args[1] do
	--			if not plr:IsA("Player") then continue end
				
	--			if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end
				
	--			local newRig, cframe = Libraries.Assets["R15"]:Clone(), plr.Character:GetPivot()
	--			newRig.Name = plr.Name

	--			--
				
	--			for _, accessory in plr.Character:GetChildren() do 
	--				if accessory:IsA("Accessory") or accessory:IsA("Pants") or accessory:IsA("Shirt") or accessory:IsA("ShirtGraphic") or accessory:IsA("BodyColors") then
	--					accessory.Parent = newRig
	--				elseif accessory.Name == "Head" and accessory:FindFirstChild("face") then
	--					newRig.Head.face.Texture = accessory.face.Texture
	--				end
	--			end
				
	--			--
				
	--			local hd = plr.Character.Humanoid:GetAppliedDescription()
	--			game:GetService("Debris"):AddItem(plr.Character, 1)
	--			plr.Character = newRig
	--			newRig.Parent = workspace
	--			newRig:PivotTo(cframe)
	--			newRig.Humanoid:ApplyDescription(hd)
	--		end
	--	end,
	--},
	
	--{
	--	Name = "r6",
	--	Description = "Changes the player to R6.",

	--	Aliases = {"rig6"},


	--	--

	--	Rank = 1,
	--	CaseSensitive = false,

	--	Loopable = false,
	--	Frequency = 1,

	--	Arguments = { "Player" },

	--	--

	--	Function = function( speaker: Player, args: any ) : ()

	--		for _, plr in args[1] do
	--			if not plr:IsA("Player") then continue end
				
	--			if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

	--			local newRig, cframe = Libraries.Assets["R6"]:Clone(), plr.Character:GetPivot()
	--			newRig.Name = plr.Name

	--			--

	--			for _, accessory in plr.Character:GetChildren() do 
	--				if accessory:IsA("Accessory") or accessory:IsA("Pants") or accessory:IsA("Shirt") or accessory:IsA("ShirtGraphic") or accessory:IsA("BodyColors") then
	--					accessory.Parent = newRig
	--				elseif accessory.Name == "Head" and accessory:FindFirstChild("face") then
	--					newRig.Head.face.Texture = accessory.face.Texture
	--				end
	--			end

	--			--

	--			local hd = plr.Character.Humanoid:GetAppliedDescription()
	--			game:GetService("Debris"):AddItem(plr.Character, 1)
	--			plr.Character = newRig
	--			newRig.Parent = workspace
	--			newRig:PivotTo(cframe)
	--			newRig.Humanoid:ApplyDescription(hd)
	--		end
	--	end,
	--},
	
	{
		Name = "dwarf",
		Description = "Turns the player into a dwarf.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				
				pcall(function()
					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyDepthScale.Value, Humanoid.BodyHeightScale.Value, Humanoid.BodyWidthScale.Value, Humanoid.HeadScale.Value = 0.75, 0.5, 0.75, 1.4
				end)
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()
					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyDepthScale.Value, Humanoid.BodyHeightScale.Value, Humanoid.BodyWidthScale.Value, Humanoid.HeadScale.Value = 1, 1, 1, 1
				end)
			end
		end,
	},
	
	{
		Name = "giant",
		Description = "Turns the player into a giant.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyDepthScale.Value, Humanoid.BodyHeightScale.Value, Humanoid.BodyWidthScale.Value, Humanoid.HeadScale.Value = 2, 2, 2, 2
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyDepthScale.Value, Humanoid.BodyHeightScale.Value, Humanoid.BodyWidthScale.Value, Humanoid.HeadScale.Value = 1, 1, 1, 1
				end)
			end
		end,
	},
	
	{
		Name = "size",
		Description = "Adjust the size of a player's character.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					Humanoid.BodyDepthScale.Value, Humanoid.BodyHeightScale.Value, Humanoid.BodyWidthScale.Value, Humanoid.HeadScale.Value = args[2] or 1, args[2] or 1, args[2] or 1, args[2] or 1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyDepthScale.Value, Humanoid.BodyHeightScale.Value, Humanoid.BodyWidthScale.Value, Humanoid.HeadScale.Value = 1, 1, 1, 1
				end)
			end
		end,
	},
	
	{
		Name = "bodytype",
		Description = "Adjust the humanoid to fit R15 (0) to slender (1)",

		Aliases = {"bodytypescale"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyTypeScale.Value = args[2] or 1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyTypeScale.Value = 1
				end)
			end
		end,
	},
	
	{
		Name = "depth",
		Description = "Adjust how much depth the character has.",

		Aliases = {"depthscale"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyDepthScale.Value = args[2] or 1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyDepthScale.Value = 1
				end)
			end
		end,
	},
	
	{
		Name = "headsize",
		Description = "Adjust how big the head of a player is.",

		Aliases = {"headscale"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.HeadScale.Value = args[2] or 1
				end)
				
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.HeadScale.Value = 1
				end)
				
			end
		end,
	},
	
	{
		Name = "height",
		Description = "Adjust the height of a player's character.",

		Aliases = {"heightscale"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyHeightScale.Value = args[2] or 1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyHeightScale.Value = 1
				end)
			end
		end,
	},
	
	{
		Name = "hipheight",
		Description = "Adjust the hipheight of a player's character.",

		Aliases = {"hipscale", "hipheightscale"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				plr.Character.Humanoid.HipHeight = args[2] or 2
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do

				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				plr.Character.Humanoid.HipHeight = 2
			end
		end,
	},
	
	{
		Name = "squash",
		Description = "Flattens a player's character like a pancake.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyHeightScale.Value = 0.1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyHeightScale.Value = 1
				end)
			end
		end,
	},
	
	{
		Name = "proportion",
		Description = "Adjust how wide/narrow a player's character is.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyProportionScale.Value = args[2] or 1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyProportionScale.Value = 1
				end)
			end
		end,
	},
	
	{
		Name = "width",
		Description = "Adjust how wide the humanoid is overall.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyWidthScale.Value = args[2] or 1
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyWidthScale.Value = 1
				end)
			end
		end,
	},
	
	{
		Name = "fat",
		Description = "Makes the player fat.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--
				
				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyWidthScale.Value, Humanoid.BodyDepthScale.Value = 2, 1.5
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end
				
				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyWidthScale.Value, Humanoid.BodyDepthScale.Value = 1, 1
				end)
			end
		end,
	},
	
	{
		Name = "thin",
		Description = "Makes the player skinny.",

		Aliases = {"skinny"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--
				
				pcall(function()

					local Humanoid = plr.Character.Humanoid
					
					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})

						return
					end
					
					Humanoid.BodyWidthScale.Value, Humanoid.BodyDepthScale.Value = 0.2, 0.2
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end
				
				pcall(function()

					local Humanoid = plr.Character.Humanoid

					if Humanoid.RigType == Enum.HumanoidRigType.R6 then
						Libraries.Signals["<notification>"]:FireClient(speaker, {
							type = "notification",
							message = `This command only works on R15.`,
							timer = 10,
						})
						
						return
					end
					
					Humanoid.BodyWidthScale.Value, Humanoid.BodyDepthScale.Value = 1, 1
				end)
			end
		end,
	},
	
	{
		Name = "character",
		Description = "Morphs into a player's character.",

		Aliases = {"char"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Username" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				local hd = game:GetService("Players"):GetHumanoidDescriptionFromUserId(game:GetService("Players"):GetUserIdFromNameAsync(args[2] or plr.Name))
				plr.Character.Humanoid:ApplyDescription(hd)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				local hd = game:GetService("Players"):GetHumanoidDescriptionFromUserId(plr.UserId)
				plr.Character.Humanoid:ApplyDescription(hd)
			end
		end,
	},
	
	{
		Name = "ragdoll",
		Description = "Ragdolls a player's character.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		PreFunction = function()
			local function check(t)
				for _, motor in pairs({"LeftWrist","RightWrist","LeftAnkle","RightAnkle"}) do
					if  motor == t then return false end
				end
				
				return true
			end
			
			storage["Joints"] = function( character: any )
				character.Humanoid.BreakJointsOnDeath = false
				character.Humanoid.RequiresNeck = false
				
				for _, motor in character:GetDescendants() do
					if motor:IsA("Motor6D") and check(motor.Name)then
						local b = Instance.new("BallSocketConstraint",motor.Parent)
						local a0,a1 = Instance.new("Attachment"),Instance.new("Attachment")
						a0.Parent,a1.Parent = motor.Part0,motor.Part1
						b.Attachment0,b.Attachment1 = a0,a1
						a0.CFrame,a1.CFrame = motor.c0,motor.c1
						b.LimitsEnabled = true
						b.TwistLimitsEnabled = true
						b.Enabled = false
					elseif motor:IsA('BasePart') then
						motor.CollisionGroup = "Group A // NoClip"
						if motor.Name == "HumanoidRootPart" then
							motor.CollisionGroup = "Group B // NoClip"
						elseif motor.Name=="Head"then
							motor.CanCollide = true
						end
					end
				end
			end
			
			storage["Ragdoll"] = function( player: Player, enabled: boolean ) : ()
				local Character = player.Character
				Character.Humanoid.RequiresNeck = false
				Character.Humanoid.BreakJointsOnDeath = false
				
				if Character.Humanoid.Health ~= 0 and ((Character:FindFirstChild('LowerTorso') and not Character.LowerTorso.Root.Enabled) or (Character:FindFirstChild('Torso') and not Character.Torso.Neck.Enabled)) and not enabled then
					Libraries.Signals["<modifyplayer>"]:InvokeClient(player, {
						type = "ragdoll",
						undo = true,
					})
					
					--
					
					for _, motor in Character:GetDescendants() do
						if motor:IsA('Motor6D') then
							motor.Enabled = true
						elseif motor:IsA('BallSocketConstraint') then
							motor.Enabled = false
						end
					end
					
					Character.Humanoid.RequiresNeck = true
					Character.Humanoid.BreakJointsOnDeath = true
				else
					Libraries.Signals["<modifyplayer>"]:InvokeClient(player, {
						type = "ragdoll",
					})
					
					--
					
					for _, motor in Character:GetDescendants() do
						if motor:IsA('Motor6D') and check(motor.Name)then
							motor.Enabled = false
						elseif motor:IsA('BallSocketConstraint') then
							motor.Enabled = true
						elseif motor.Name == "Head" then
							local BodyVelocity = Instance.new("BodyVelocity", Character.Head)
							BodyVelocity.Velocity = Vector3.new(math.random(-10,10), 0, math.random(-10,10))
							
							task.delay(0.1, function() BodyVelocity:Destroy() end)
						end
					end
				end
			end
		end,

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--
				
				storage["Joints"](plr.Character)
				storage["Ragdoll"](plr, true)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				--
				
				storage["Ragdoll"](plr, false)
			end
		end,
	},
	
	{
		Name = "bundle",
		Description = "Applies a bundle on the player.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				local hd; local success, bundleDetails = pcall(function() return game:GetService("AssetService"):GetBundleDetailsAsync(args[2]) end) if success and bundleDetails then for _, item in next, bundleDetails.Items do if item.Type == "UserOutfit" then success, hd = pcall(function() return game:GetService('Players'):GetHumanoidDescriptionFromOutfitId(item.Id) end) break end end end
				if not hd then return end

				local newDescription = plr.Character.Humanoid:GetAppliedDescription()
				local defaultDescription = Instance.new("HumanoidDescription")
				
				for _, property in next, {"BackAccessory", "BodyTypeScale", "ClimbAnimation", "DepthScale", "Face", "FaceAccessory", "FallAnimation", "FrontAccessory", "GraphicTShirt", "HairAccessory", "HatAccessory", "Head", "HeadColor", "HeadScale", "HeightScale", "IdleAnimation", "JumpAnimation", "LeftArm", "LeftArmColor", "LeftLeg", "LeftLegColor", "NeckAccessory", "Pants", "ProportionScale", "RightArm", "RightArmColor", "RightLeg", "RightLegColor", "RunAnimation", "Shirt", "ShouldersAccessory", "SwimAnimation", "Torso", "TorsoColor", "WaistAccessory", "WalkAnimation", "WidthScale"} do
					if hd[property] ~= defaultDescription[property] then newDescription[property] = hd[property] end
				end
				
				plr.Character.Humanoid:ApplyDescription(newDescription)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				local hd = game:GetService("Players"):GetHumanoidDescriptionFromUserId(plr.UserId)
				plr.Character.Humanoid:ApplyDescription(hd)
			end
		end,
	},
	
	{
		Name = "dino",
		Description = "Turns the player into a dinosaur.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				local hd; local success, bundleDetails = pcall(function() return game:GetService("AssetService"):GetBundleDetailsAsync(458) end) if success and bundleDetails then for _, item in next, bundleDetails.Items do if item.Type == "UserOutfit" then success, hd = pcall(function() return game:GetService('Players'):GetHumanoidDescriptionFromOutfitId(item.Id) end) break end end end
				if not hd then return end

				local newDescription = plr.Character.Humanoid:GetAppliedDescription()
				local defaultDescription = Instance.new("HumanoidDescription")
				newDescription.BackAccessory, newDescription.FaceAccessory, newDescription.FrontAccessory, newDescription.HairAccessory, newDescription.HatAccessory, newDescription.NeckAccessory, newDescription.ShouldersAccessory, newDescription.WaistAccessory = "", "", "", "", "", "", "", ""
				
				for _, property in next, {"BackAccessory", "BodyTypeScale", "ClimbAnimation", "DepthScale", "Face", "FaceAccessory", "FallAnimation", "FrontAccessory", "GraphicTShirt", "HairAccessory", "HatAccessory", "Head", "HeadColor", "HeadScale", "HeightScale", "IdleAnimation", "JumpAnimation", "LeftArm", "LeftArmColor", "LeftLeg", "LeftLegColor", "NeckAccessory", "Pants", "ProportionScale", "RightArm", "RightArmColor", "RightLeg", "RightLegColor", "RunAnimation", "Shirt", "ShouldersAccessory", "SwimAnimation", "Torso", "TorsoColor", "WaistAccessory", "WalkAnimation", "WidthScale"} do
					if hd[property] ~= defaultDescription[property] then newDescription[property] = hd[property] end
				end

				pcall(function() plr.Character.Humanoid:ApplyDescription(hd) end)

				plr.Character.Humanoid:ApplyDescription(newDescription)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then continue end

				local hd = game:GetService("Players"):GetHumanoidDescriptionFromUserId(plr.UserId)
				plr.Character.Humanoid:ApplyDescription(hd)
			end
		end,
	},
	
	{
		Name = "follow",
		Description = "Follow behind a player.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Player" },

		--

		PreFunction = function()
			storage["FollowLoops"] = {}
		end,

		Function = function( speaker: Player, args: any ) : ()
						
			for _, plr in args[1] do
				local target = args[2][1]
				storage["FollowLoops"][plr] = target

				coroutine.wrap(function() while storage["FollowLoops"][plr] == target do
					plr.Character:FindFirstChild("Humanoid"):MoveTo(target.Character:GetPivot().Position)
					plr.Character:FindFirstChild("Humanoid").MoveToFinished:Wait()
				end end)()
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				storage["FollowLoops"][plr] = nil
			end
		end,
	},
	
	{
		Name = "walkspeed",
		Description = "Adjust the walkspeed of a player.",

		Aliases = {"speed", "runspeed"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Speed" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.WalkSpeed = args[2]
			end
		end,
	},	
	
	{
		Name = "jumppower",
		Description = "Adjust the jumppower of a player.",

		Aliases = {"power"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Power" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.JumpPower = args[2]
			end
		end,
	},	
	
	{
		Name = "jumpheight",
		Description = "Adjust the jumpheight of a player.",

		Aliases = {"number"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.JumpHeight = args[2]
			end
		end,
	},
	
	{
		Name = "health",
		Description = "Adjust the health of the player.",

		Aliases = {"hp"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.MaxHealth = plr.Character.Humanoid.Health < args[2] and args[2] or plr.Character.Humanoid.MaxHealth
				plr.Character.Humanoid.Health = args[2] or plr.Character.Humanoid.MaxHealth
			end
		end,
	},	
	
	{
		Name = "maxhealth",
		Description = "Adjust the max health of the player.",

		Aliases = {"maxhp"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.MaxHealth = args[2]
			end
		end,
	},	
	
	{
		Name = "heal",
		Description = "Increase the health of a player.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.Health += args[2]
			end
		end,
	},	
	
	{
		Name = "damage",
		Description = "Decrease the health of a player.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid:TakeDamage(args[2] or 0)
			end
		end,
	},	
	
	{
		Name = "god",
		Description = "Make a player unable to die.",

		Aliases = {"godmode"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.MaxHealth = math.huge
				plr.Character.Humanoid.Health = math.huge
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.MaxHealth = 100
				plr.Character.Humanoid.Health = 100
			end
		end,
	},	
	
	{
		Name = "kill",
		Description = "Instantly kill a player.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character.Humanoid.Health = 0
			end
		end,
	},

	{
		Name = "teleport",
		Description = "Move players to a specific player.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character:PivotTo( args[2][1].Character:GetPivot() + args[2][1].Character:GetPivot().LookVector * 2.5 )
			end
		end,
	},
	
	{
		Name = "bring",
		Description = "Move players to your location.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character:PivotTo( (speaker.Character::Model):GetPivot() + (speaker.Character::Model):GetPivot().LookVector * 2.5 )
			end
		end,
	},
	
	{
		Name = "to",
		Description = "Go to a player's location.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			pcall(function() (speaker.Character::Model):PivotTo( args[1][1].Character:GetPivot() + args[1][1].Character:GetPivot().LookVector * 2.5 ) end)
		end,
	},
	
	{
		Name = "apparate",
		Description = "Move forward from correct position.",

		Aliases = {"LookVector"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				plr.Character:PivotTo( plr.Character:GetPivot() + plr.Character:GetPivot().LookVector * (args[2] or 5) )
			end
		end,
	},
	
	{
		Name = "playerlist",
		Description = "Display the playerlist CoreGui.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "PlayerList",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "PlayerList",
					state = false,
				})
			end
		end,
	},

	{
		Name = "backpack",
		Description = "Display the backpack CoreGui.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Backpack",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Backpack",
					state = true,
				})
			end
		end,
	},

	{
		Name = "emotesmenu",
		Description = "Display the emotes CoreGui.",

		Aliases = {"emotemenu"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "EmotesMenu",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "EmotesMenu",
					state = true,
				})
			end
		end,
	},

	{
		Name = "chatwindow",
		Description = "Display the chat CoreGui.",

		Aliases = {"chatbox"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Chat",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Chat",
					state = true,
				})
			end
		end,
	},

	{
		Name = "healthbar",
		Description = "Display the health CoreGui.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Health",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Health",
					state = true,
				})
			end
		end,
	},

	{
		Name = "captures",
		Description = "Display the captures CoreGui.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Captures",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "Captures",
					state = true,
				})
			end
		end,
	},

	{
		Name = "selfview",
		Description = "Display the selfview CoreGui.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "SelfView",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "SelfView",
					state = true,
				})
			end
		end,
	},
	
	{
		Name = "resetbutton",
		Description = "Display the reset button in escape menu.",

		Aliases = {"resetbuttoncallback"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "ResetButtonCallback",
					state = true,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["<modifyplayer>"]:InvokeClient(plr, {
					type = "coregui",
					typeOf = "ResetButtonCallback",
					state = true,
				})
			end
		end,
	},

	{
		Name = "bubblechat",
		Description = "Force a player to talk with bubblechat.",

		Aliases = {"forcebubblechat"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Message" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if plr:IsA("Player") then 
					Libraries.Signals["<chat>"]:FireAllClients("bubblechat", plr.Character, args[2])
				elseif plr:IsA("BasePart") then
					Libraries.Signals["<chat>"]:FireAllClients("bubblechat", plr, args[2])
				end	
			end
		end,
	},
	
	{
		Name = "talk",
		Description = "Force a player to talk in chat.",

		Aliases = {"chat"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Message" },

		--

		PreFunction = function() : ()
			Libraries.Signals["<chat>"]["Connection"].Enabled = true
		end,

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				Libraries.Signals["Chat // Communication"]:FireClient(plr, "chat", plr, args[2])
			end
		end,
	},
	
	{
		Name = "handto",
		Description = "Give held tool to a player.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			local tools = {}; for _, tool in (speaker.Character::Model):GetChildren() do if not tool:IsA("Tool") then continue end; table.insert(tools, tool) end 
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				for _, tool in tools do tool:Clone().Parent = plr.Backpack end
			end
			
			for _, tool in tools do tool:Destroy() end
		end,
	},
		
	{
		Name = "sword",
		Description = "Give the player a sword.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			local Sword = function()
				local Tool = Instance.new("Tool", workspace)
				Tool.Name = "Speed Coil"
				Tool.TextureId = "rbxasset://Textures/Sword128.png"
				Tool.Grip = CFrame.new(Vector3.new(0, 0, -1.5)) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(90))
				Tool.CanBeDropped = true
				Tool.ManualActivationOnly = false
				Tool.RequiresHandle = true
				Tool.Enabled = true

				local SmokePart, Smoke;

				Tool.Equipped:Connect(function()
					Tool.Handle.CoilSound:Play()		
					Tool.Parent.Humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed + (game:GetService("StarterPlayer").CharacterWalkSpeed * 5)

					SmokePart=Instance.new("Part")
					SmokePart.FormFactor="Custom"
					SmokePart.Size=Vector3.new(0,0,0)
					SmokePart.TopSurface="Smooth"
					SmokePart.BottomSurface="Smooth"
					SmokePart.CanCollide=false
					SmokePart.Transparency=1
					local weld=Instance.new("Weld")
					weld.Name="SmokePartWeld"
					weld.Part0 = Tool.Parent.HumanoidRootPart
					weld.Part1=SmokePart
					weld.C0=CFrame.new(0,-3.5,0)*CFrame.Angles(math.pi/4,0,0)
					weld.Parent=SmokePart
					SmokePart.Parent=Tool
					Smoke=Instance.new("Smoke")
					Smoke.Enabled = Tool.Parent.HumanoidRootPart.Velocity.magnitude>10
					Smoke.RiseVelocity=2
					Smoke.Opacity=.25
					Smoke.Size=.5
					Smoke.Parent=SmokePart
					Tool.Parent.Humanoid.Running:connect(function(speed)
						if Smoke then
							Smoke.Enabled=speed>10
						end
					end)
				end)

				Tool.Unequipped:Connect(function()
					Tool.Parent.Humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
					Smoke:Destroy()
					SmokePart:Destroy()
				end)

				local Handle = Instance.new("Part", Tool)
				Handle.Name = "Handle"
				Handle.Size = Vector3.new(1, 0.8, 4)
				Handle.Color = Color3.fromRGB(99, 95, 98)
				Handle.Reflectance = 0.4
				Handle.CanCollide = true

				local SwordLunge = Instance.new("Sound", Handle)
				SwordLunge.Name = "SwordLunge"
				SwordLunge.SoundId = "http://www.roblox.com/asset/?id=12222208"
				SwordLunge.Volume = 0.6

				local SwordSlash = Instance.new("Sound", Handle)
				SwordSlash.Name = "SwordSlash"
				SwordSlash.SoundId = "http://www.roblox.com/asset/?id=12222216"
				SwordSlash.Volume = 0.7

				local Unsheath = Instance.new("Sound", Handle)
				Unsheath.Name = "Unsheath"
				Unsheath.SoundId = "http://www.roblox.com/asset/?id=12222225"

				local Mesh = Instance.new("SpecialMesh", Handle)
				Mesh.Name = "Mesh"
				Mesh.MeshId = "rbxasset://fonts/sword.mesh"
				Mesh.TextureId = "rbxasset://textures/SwordTexture.png"
				Mesh.Scale = Vector3.one

				return Tool	
			end
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local sword = Sword()
				sword.Parent = plr.Backpack
				plr.Character.Humanoid:EquipTool(sword)
			end
		end,
	},
	
	{
		Name = "tool",
		Description = "Give player a tool from the custom tools folder.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Name" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, namevalue in args[2] do
				local Selected = nil;
				
				for _, tool in Libraries.Custom.Tools:GetChildren() do
					if tool.Name:lower():gsub(" ", ""):sub(1, #namevalue:lower():gsub(" ", "")) == namevalue:lower():gsub(" ", "") then 
						Selected = tool break
					end
				end

				--

				if not Selected then return end

				--

				for _, plr in args[1] do
					local tool = Selected:Clone()
					tool.Parent = plr.Backpack

					plr.Character.Humanoid:EquipTool(tool)
				end	
			end		
		end,
	},
	
	{
		Name = "setspawn",
		Description = "Turn a player invisible to the server.",

		Aliases = {"setspawnpoint", "setrespawnlocation", "respawnlocation"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Vector3" },

		--

		Function = function( speaker: Player, args: any ) : ()

			local spawnLocation = Instance.new("SpawnLocation", workspace:FindFirstChild("Nexus Dynamics // Workspace"))
			spawnLocation.Position, spawnLocation.Transparency = args[2], 1
			spawnLocation.CanCollide, spawnLocation.Anchored = false, true
			spawnLocation.AllowTeamChangeOnTouch = false
			spawnLocation.Neutral = true
			
			for _, plr in args[1] do		
				if not plr:IsA("Player") then continue end
				plr.RespawnLocation = spawnLocation
			end
		end,
	},		

	{
		Name = "weld",
		Description = "Welds an player to a part.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player", "FullName" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local weld = Instance.new("WeldConstraint", workspace:FindFirstChild("Nexus Dynamics // Workspace"))
				weld.Part0, weld.Part1 = plr.Character.HumanoidRootPart, args[2]
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				for _, weld in workspace:FindFirstChild("Nexus Dynamics // Workspace"):GetChildren() do if weld:IsA("WeldConstraint") and weld.Part1 == plr.Character.HumanoidRootPart or weld.Part0 == plr.Character.HumanoidRootPart then weld:Destroy() end end
			end
		end,
	},

	{
		Name = "explode",
		Description = "Kills a player using an explosion.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = true,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				local explosion = Instance.new("Explosion", plr.Character)
				explosion.Position = plr.Character:GetPivot().Position

				game:GetService("Debris"):AddItem(1, explosion)
			end
		end,
	},
	
	{
		Name = "ghost",
		Description = "Turn a player invisible to the server.",

		Aliases = {},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do		
				if not plr:IsA("Player") then continue end
				require("../GhostService"):GhostAsync(plr)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do		
				if not plr:IsA("Player") then continue end
				require("../GhostService"):UnghostAsync(plr)
			end
		end,
	},	
	
	{
		Name = "title",
		Description = "Apply a title above a player's head.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Color", "Text" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if plr.Character.Head:FindFirstChild("Nexus Dynamics // Title") then
						plr.Character.Head:FindFirstChild("Nexus Dynamics // Title").TextLabel.Text, plr.Character.Head:FindFirstChild("Nexus Dynamics // Title").TextLabel.TextColor3 = args[3] or "", args[2] or Color3.fromRGB(255, 255, 255)
						
						continue
					end
					
					
					local title = Instance.new("BillboardGui", plr.Character.Head)
					title.Name = "Nexus Dynamics // Title"
					title.Size = UDim2.fromScale(5, 1.25)
					title.StudsOffset = Vector3.new(0, 2.6, 0)
					title.MaxDistance = math.huge
					title.LightInfluence = 0
					title.AlwaysOnTop = true
					
					local textLabel = Instance.new("TextLabel", title)
					textLabel.Size = UDim2.fromScale(1, 1)
					textLabel.BackgroundTransparency = 1
					textLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
					textLabel.TextScaled = true
					textLabel.Text = args[3] or ""
					textLabel.TextColor3 = args[2] or Color3.fromRGB(255, 255, 255)	
				elseif plr:IsA("BasePart") then
					if plr:FindFirstChild("Nexus Dynamics // Title") then
					
						plr:FindFirstChild("Nexus Dynamics // Title").TextLabel.Text, plr:FindFirstChild("Nexus Dynamics // Title").TextLabel.TextColor3 = args[3] or "", args[2] or Color3.fromRGB(255, 255, 255)
						
						continue
					end
					
					local title = Instance.new("BillboardGui", plr)
					title.Name = "Nexus Dynamics // Title"
					title.Size = UDim2.fromScale(5, 1.25)
					title.StudsOffset = Vector3.new(0, 2.6, 0)
					title.MaxDistance = math.huge
					title.LightInfluence = 0
					title.AlwaysOnTop = true

					local textLabel = Instance.new("TextLabel", title)
					textLabel.Size = UDim2.fromScale(1, 1)
					textLabel.BackgroundTransparency = 1
					textLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
					textLabel.TextScaled = true
					textLabel.Text = args[3] or ""
					textLabel.TextColor3 = args[2] or Color3.fromRGB(255, 255, 255)
				end	
				
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do
				if plr:IsA("Player") then 
					if plr.Character.Head:FindFirstChild("Nexus Dynamics // Title") then
						plr.Character.Head:FindFirstChild("Nexus Dynamics // Title"):Destroy()
					end
				elseif plr:IsA("BasePart") then
					if plr:FindFirstChild("Nexus Dynamics // Title") then
						plr:FindFirstChild("Nexus Dynamics // Title"):Destroy()
					end
				end	
				
			end
		end,
	},
	
	{
		Name = "fling",
		Description = "Fling a player off the map.",

		Aliases = {"colortitle"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local Character = speaker.Character
				local speakerHrp, plrHrp, plrHumanoid = Character.HumanoidRootPart, plr.Character.HumanoidRootPart, plr.Character.Humanoid

				local flingDistance = 50--math.random(14,20)
				local speakerPos = speakerHrp.Position
				local plrPos = plrHrp.Position
				local bodyPosition = Instance.new("BodyPosition")
				bodyPosition.MaxForce = Vector3.new(10000000, 10000000, 10000000)
				bodyPosition.Name = "HDAdminFlingBP"
				bodyPosition.D = 450
				bodyPosition.P = 10000
				if plr == speaker then
					plrPos = (plrHrp.CFrame * CFrame.new(0,0,-4)).p
				end
				local direction = (plrPos - speakerPos).Unit
				bodyPosition.Position = plrPos + Vector3.new(direction.X, 1.4, direction.Z) * flingDistance
				--
				local spin = Instance.new("BodyAngularVelocity")
				spin.MaxTorque = Vector3.new(300000, 300000, 300000)
				spin.P = 300
				spin.AngularVelocity = Vector3.new(10, 10 ,10)
				spin.Name = "HDAdminFlingSpin"
				spin.Parent = plrHrp
				game:GetService("Debris"):AddItem(spin, 0.1)
				--
				plrHumanoid.JumpPower = 0
				bodyPosition.Parent = plrHrp
				game:GetService("Debris"):AddItem(bodyPosition, 0.1)
				
				wait(1)
				
				plr.Character.Humanoid.JumpPower = game:GetService("StarterPlayer").CharacterJumpPower
			end
		end,
	},
	
	{
		Name = "clone",
		Description = "Clone a player's character.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				plr.Character.Archivable = true

				local clone = plr.Character:Clone()
				clone.Parent = workspace:FindFirstChild("Nexus Dynamics // Workspace")
				clone:PivotTo(plr.Character:GetPivot() + plr.Character:GetPivot().LookVector * 2.5 + Vector3.new(0, 1 + (plr.Character:GetExtentsSize().Y or 0), 0))
			end
		end,
	},
	
	{
		Name = "setProperty",
		Description = "Set a property of an instance.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "FullName", "Name", "Any" },

		--

		Function = function( speaker: Player, args: any ) : ()

			local PropertyType = typeof(args[1][args[2]])

			--

			local _suc, _error = pcall(function()
				if PropertyType == "number" and typeof(args[3][1]) == "Vector3" then
					for _, valname in args[2] do
						args[1][valname] = args[3][1].X
					end 

					return
				end

				if PropertyType == "Color3" and typeof(args[3][1]) == "Vector3" then
					for _, valname in args[2] do
						args[1][valname] = Color3.fromRGB(args[3][1].X, args[3][1].Y, args[3][1].Z)
					end 

					return
				end

				--

				for _, valname in args[2] do
					args[1][valname] = typeof(args[3]) ~= "table" and args[3] or args[3][1]
				end
			end)
		end,
	},

	{
		Name = "getProperty",
		Description = "Get a property of an instance.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "FullName", "Name" },

		--

		Function = function( speaker: Player, args: any ) : ()
			local propertyValue = "N/A"

			pcall(function() propertyValue = args[1][args[2]] or "nil" end)
			Libraries.Signals["<notification>"]:FireClient(speaker, {
				type = "notification",
				message = `{args[2][#args[2]]} set to {propertyValue}`,
				timer = 20,
			})
		end,
	},
	
	{
		Name = "gravitycoil",
		Description = "Give the player a gravity coil.",

		Aliases = {"gcoil"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			local GravityCoil = function()
				local Tool = Instance.new("Tool", workspace)
				Tool.Name = "Gravity Coil"
				Tool.TextureId = "rbxassetid://16619617"
				Tool.Grip = CFrame.new(Vector3.new(0, 0, 1)) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0))
				Tool.CanBeDropped = true
				Tool.ManualActivationOnly = false
				Tool.RequiresHandle = true
				Tool.Enabled = true

				local AntiGravityForce = Instance.new("BodyForce")
				AntiGravityForce.Name = "GravityCoilEffect"
				AntiGravityForce.Archivable = true
				AntiGravityForce.force = Vector3.new(0, 4850, 0)

				Tool.Equipped:Connect(function()
					Tool.Handle.CoilSound:Play()
					if not AntiGravityForce then return end
					AntiGravityForce.Parent = Tool.Handle
				end)

				Tool.Unequipped:Connect(function()
					AntiGravityForce = nil
				end)

				local Handle = Instance.new("Part", Tool)
				Handle.Name = "Handle"
				Handle.Size = Vector3.new(1, 1.2, 2)
				Handle.Color = Color3.fromRGB(9, 137, 207)
				Handle.Material = Enum.Material.Metal
				Handle.CanCollide = true


				local Sound = Instance.new("Sound", Handle)
				Sound.Name = "CoilSound"
				Sound.SoundId = "http://www.roblox.com/asset/?id=177979632"
				Sound.PlaybackSpeed = 1.5
				Sound.Volume = 1

				local Mesh = Instance.new("SpecialMesh", Handle)
				Mesh.Name = "Mesh"
				Mesh.MeshId = "http://www.roblox.com/asset/?id=16606212"
				Mesh.Scale = Vector3.one * 0.7

				return Tool	
			end
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end

				local tool = GravityCoil()
				tool.Parent = plr.Backpack
				plr.Character.Humanoid:EquipTool(tool)
			end
		end,
	},
	
	{
		Name = "speedcoil",
		Description = "Give the player a speed coil.",

		Aliases = {"scoil"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : ()
			local SpeedCoil = function()
				local Tool = Instance.new("Tool", workspace)
				Tool.Name = "Speed Coil"
				Tool.TextureId = "http://www.roblox.com/asset/?id=99170415"
				Tool.Grip = CFrame.new(Vector3.new(0, 0, 1)) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0))
				Tool.CanBeDropped = true
				Tool.ManualActivationOnly = false
				Tool.RequiresHandle = true
				Tool.Enabled = true

				local SmokePart, Smoke;

				Tool.Equipped:Connect(function()
					Tool.Handle.CoilSound:Play()		
					Tool.Parent.Humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed + (game:GetService("StarterPlayer").CharacterWalkSpeed * 5)

					SmokePart=Instance.new("Part")
					SmokePart.FormFactor="Custom"
					SmokePart.Size=Vector3.new(0,0,0)
					SmokePart.TopSurface="Smooth"
					SmokePart.BottomSurface="Smooth"
					SmokePart.CanCollide=false
					SmokePart.Transparency=1
					local weld=Instance.new("Weld")
					weld.Name="SmokePartWeld"
					weld.Part0 = Tool.Parent.HumanoidRootPart
					weld.Part1=SmokePart
					weld.C0=CFrame.new(0,-3.5,0)*CFrame.Angles(math.pi/4,0,0)
					weld.Parent=SmokePart
					SmokePart.Parent=Tool
					Smoke=Instance.new("Smoke")
					Smoke.Enabled = Tool.Parent.HumanoidRootPart.Velocity.magnitude>10
					Smoke.RiseVelocity=2
					Smoke.Opacity=.25
					Smoke.Size=.5
					Smoke.Parent=SmokePart
					Tool.Parent.Humanoid.Running:connect(function(speed)
						if Smoke then
							Smoke.Enabled=speed>10
						end
					end)
				end)

				Tool.Unequipped:Connect(function()
					Tool.Parent.Humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
					Smoke:Destroy()
					SmokePart:Destroy()
				end)

				local Handle = Instance.new("Part", Tool)
				Handle.Name = "Handle"
				Handle.Size = Vector3.new(1.3, 1.3, 2.4)
				Handle.Color = Color3.fromRGB(196, 40, 28)
				Handle.CanCollide = true


				local Sound = Instance.new("Sound", Handle)
				Sound.Name = "CoilSound"
				Sound.SoundId = "http://www.roblox.com/asset/?id=99173388"
				Sound.PlaybackSpeed = 1
				Sound.Volume = 1

				local Mesh = Instance.new("SpecialMesh", Handle)
				Mesh.Name = "Mesh"
				Mesh.MeshId = "http://www.roblox.com/asset/?id=16606212"
				Mesh.TextureId = "http://www.roblox.com/asset/?id=99170547"
				Mesh.Scale = Vector3.one * 0.7

				local Attachment = Instance.new("Attachment", Handle)
				Attachment.CFrame = CFrame.new(Vector3.new(0, 0, -1)) * CFrame.Angles(0, 0, math.rad(135))
				Attachment.Axis = Vector3.new(-0.707, 0.707, 0)
				Attachment.SecondaryAxis = Vector3.new(-0.707, -0.707, -0)
				Attachment.WorldAxis = Vector3.new(1, -0, 0)
				Attachment.WorldSecondaryAxis = Vector3.new(0, 0, -1)

				return Tool	
			end
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end

				local tool = SpeedCoil()
				tool.Parent = plr.Backpack
				plr.Character.Humanoid:EquipTool(tool)
			end
		end,
	},
	
	{
		Name = "unvisuals",
		Description = "Remove all visuals.",

		Aliases = {"disablevisuals"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):StaticEffect("None")
			require("../RenderService"):LiveEffect("None")
		end,
	},
	
	{
		Name = "disco",
		Description = "Start a disco part using TintColor.",

		Aliases = {"party", "discoparty", "danceparty"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):LiveEffect("Disco")
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()
			require("../RenderService"):UnLiveEffect("Disco")
		end,
	},
	
	{
		Name = "grayscale",
		Description = "Desaturate the server to look gray.",

		Aliases = {"b&w"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):StaticEffect("GrayScale")
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			require("../RenderService"):UnStaticEffect("GrayScale")
		end,
	},
	
	{
		Name = "saturate",
		Description = "Over saturate the server.",

		Aliases = {"saturated", "oversaturated"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):StaticEffect("Saturate")
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			require("../RenderService"):UnStaticEffect("Saturate")
		end,
	},
	
	{
		Name = "contrast",
		Description = "Over contrast the server.",

		Aliases = {"contrasted", "overcontrast"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):StaticEffect("Contrast")
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			require("../RenderService"):UnStaticEffect("Contrast")
		end,
	},
	
	{
		Name = "inverted",
		Description = "Invert the colors of the server.",

		Aliases = {"invert"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):StaticEffect("Invert")
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			require("../RenderService"):UnStaticEffect("Invert")
		end,
	},
	
	{
		Name = "tint",
		Description = "Tint the colors of the server.",

		Aliases = {"tintcolor"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Color" },

		--

		Function = function( speaker: Player, args: any ) : ()
			require("../RenderService"):StaticEffect("Tint", { ["TintColor"] = args[1] })
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			require("../RenderService"):UnStaticEffect("Tint")
		end,
	},
	
	{
		Name = "sellgamepass",
		Description = "Prompts & sells the gamepass.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				pcall(game:GetService("MarketplaceService").PromptGamePassPurchase, game:GetService("MarketplaceService"), plr, args[2])
			end
		end,
	},	

	{
		Name = "sellproduct",
		Description = "Prompts & sells the developer product.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				pcall(game:GetService("MarketplaceService").PromptProductPurchase, game:GetService("MarketplaceService"), plr, args[2])
			end
		end,
	},	

	{
		Name = "sellasset",
		Description = "Prompts & sells the asset.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				pcall(game:GetService("MarketplaceService").PromptPurchase, game:GetService("MarketplaceService"), plr, args[2])
			end
		end,
	},
	
	{
		Name = "change",
		Description = "Set the current leaderstats value.",

		Aliases = {"changestat"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Name", "Value" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, plr in args[1] do if not plr:IsA("Player") then continue end pcall(function()
				for _, valname in args[2] do
					local stat = plr:FindFirstChild(valname or "", true) 

					if not stat then  
						local leaderstats = Instance.new("Folder", plr)
						leaderstats.Name = "leaderstats"

						local value = Instance.new((typeof(args[3]) == "number" and "NumberValue") or (typeof(args[3]) == "Instance" and "ObjectValue") or "StringValue", leaderstats)
							value.Name = valname or ""
						value.Value = args[3] or value.Value

						return
					end

					stat.Value = args[3] or stat.Value 
				end
				end)
			end
		end,
	},	
	
	{
		Name = "add",
		Description = "Adds to the current leaderstats value.",

		Aliases = {"addstat"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Name", "Value" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do if not plr:IsA("Player") then continue end pcall(function()
					for _, valname in args[2] do
						local stat = plr:FindFirstChild(valname, true)

						if not stat then  
							local leaderstats = Instance.new("Folder", plr)
							leaderstats.Name = "leaderstats"

							local value = Instance.new((typeof(args[3]) == "number" and "NumberValue") or (typeof(args[3]) == "Instance" and "ObjectValue") or "StringValue", leaderstats)
							value.Name = valname or ""
							value.Value = args[3] or value.Value

							return
						end

						stat.Value += args[3] or 0
					end
			end) end
		end,
	},

	{
		Name = "subtract",
		Description = "Subtracts from the current leaderstats value.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Name", "Value" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do if not plr:IsA("Player") then continue end pcall(function()
					for _, valname in args[2] do
						local stat = plr:FindFirstChild(valname, true)

						if not stat then  
							local leaderstats = Instance.new("Folder", plr)
							leaderstats.Name = "leaderstats"

							local value = Instance.new((typeof(args[3]) == "number" and "NumberValue") or (typeof(args[3]) == "Instance" and "ObjectValue") or "StringValue", leaderstats)
							value.Name = valname or ""
							value.Value = args[3] or value.Value

							return
						end

						stat.Value -= args[3] or 0
					end
			end) end
		end,
	},
	
	{
		Name = "remove",
		Description = "Removes a leaderstat value.",

		Aliases = {"removestat"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Name" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				for _, namevalue in args[2] do
					for _, leaderstatsFolder in plr:GetChildren() do
						if leaderstatsFolder.Name ~= "leaderstats" then continue end

						for _, value in leaderstatsFolder:GetChildren() do
							if value.Name:lower():gsub(" ", ""):sub(1, #namevalue) ~= namevalue:lower():gsub(" ", "") then continue end
							value:Destroy()
						end
					end
				end
			end
		end,
	},
	
	{
		Name = "resetStats",
		Description = "Resets the stat value to the current leaderstats value.",

		Aliases = {"removestats"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Name" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				for _, leaderstatsFolder in plr:GetChildren() do
					if leaderstatsFolder.Name ~= "leaderstats" then continue end

					for _, value in leaderstatsFolder:GetChildren() do
						value.Value = typeof(value.Value) == "number" and 0 or typeof(value.Value) == "string" and "" or nil
					end
				end
			end
		end,
	},
	
	{
		Name = "time",
		Description = "Set the time of the world.",

		Aliases = {"settime"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Number" },

		--

		Function = function( speaker: Player, args: any ) : () 
			game:GetService("Lighting").ClockTime = math.clamp((args[1] or 0), 0, 24) 
		end,
	},
	
	{
		Name = "kick",
		Description = "Kick a player from the server.",

		Aliases = {"leave", "forcekick", "forceleave"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Reason" },

		--

		Function = function( speaker: Player, args: any ) : ()
			local myRank = require("../RankService"):GetRankByUserId(speaker.UserId)
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				local rank = require("../RankService"):GetRankByUserId(plr.UserId)
				if (rank and myRank) and (rank.Id > myRank.Id) then continue end
				
				plr:Kick(args[2]..` by @{speaker.Name}` or `No reason provided. by @{speaker.Name}`)
			end 
		end,
	},
	
	{
		Name = "place",
		Description = "Force a player to join a specific place.",

		Aliases = {"forceplace"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Id" },

		--

		Function = function( speaker: Player, args: any ) : () 
			local placeInfo = game:GetService("MarketplaceService"):GetProductInfo(args[2], Enum.InfoType.Asset)
			local placeName = placeInfo.Name
			if not placeName then return end
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				game:GetService("TeleportService"):Teleport(args[2], plr)
			end
		end,
	},
	
	{
		Name = "fog",
		Description = "Set the world fog.",

		Aliases = {"forceplace"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Min", "Max", "Color" },

		--

		Function = function( speaker: Player, args: any ) : () 
			repeat task.wait() if game:GetService("Lighting"):FindFirstChildWhichIsA("Atmosphere") then game:GetService("Lighting"):FindFirstChildWhichIsA("Atmosphere"):Destroy() end until not game:GetService("Lighting"):FindFirstChildWhichIsA("Atmosphere")
			game:GetService("Lighting").FogStart, game:GetService("Lighting").FogEnd, game:GetService("Lighting").FogColor = args[1] or game:GetService("Lighting").FogStart, args[2] or game:GetService("Lighting").FogEnd, args[3] or game:GetService("Lighting").FogColor
		end,
	},
	
	{
		Name = "lockplayer",
		Description = "Enable the lock property of player.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : () 
			
			for _, plr in args[1] do
				if plr:IsA("Player") then 
					for _, basepart in plr.Character:GetDescendants() do
						if not basepart:IsA("BasePart") then continue end
						basepart.Locked = true
					end	
				elseif plr:IsA("BasePart") then
					plr.Locked = true
				end	
			end			
		end,
		
		UnFunction = function( speaker: Player, args: any ) : () 

			for _, plr in args[1] do
				if plr:IsA("Player") then 
					for _, basepart in plr.Character:GetDescendants() do
						if not basepart:IsA("BasePart") then continue end
						basepart.Locked = false
					end
				elseif plr:IsA("BasePart") then
					plr.Locked = false
				end	
			end			
		end,
	},	
	
	{
		Name = "age",
		Description = "Obtain the age of a player.",

		Aliases = {"accountage"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : () 

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end

				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `{plr.Name}'s account was made {plr.AccountAge} days ago.`,
					timer = 20,
				})
			end			
		end,
	},	
	
	{
		Name = "createteam",
		Description = "Creates a new team.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Color", "String" },

		--

		Function = function( speaker: Player, args: any ) : () 

			local Team = game:GetService("Teams"):FindFirstChild(args[2]) or Instance.new("Team", game:GetService("Teams"))
			Team.Name, Team.TeamColor = args[2], BrickColor.new(args[1])
		end,
	},	

	{
		Name = "removeteam",
		Description = "Removes a existing team.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Team" },

		--

		Function = function( speaker: Player, args: any ) : () 
			if args[1] then args[1]:Destroy() end
		end,
	},	
	
	{
		Name = "team",
		Description = "Sets a player to a team.",

		Aliases = {"setteam"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Team" },

		--

		Function = function( speaker: Player, args: any ) : ()
			if not args[2] then return end
			for _, plr in args[1] do if not plr:IsA("Player") then continue end plr.Team = args[2] end
		end,
	},

	{
		Name = "hint",
		Description = "Send a server message as a hint.",

		Aliases = {"h"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Message" },

		--

		Function = function( speaker: Player, args: any ) : ()
			Libraries.Signals["<notification>"]:FireAllClients({
				type = "hint",
				speaker = speaker,
				message = args[1]
			})
		end,
	},
	
	{
		Name = "countdown",
		Description = "Sends a message with countdown through notifications.",

		Aliases = {"timer"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Number" },

		--

		Function = function( speaker: Player, args: any ) : ()
			task.wait(1)

			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				Libraries.Signals["<notification>"]:FireAllClients({
					type = "countdown",
					message = args[2] or 10,
					timer = args[2] or 10,
				})
			end
		end,
	},

	{
		Name = "notice",
		Description = "Sends a message through notifications.",

		Aliases = {"notify"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Message" },

		--

		Function = function( speaker: Player, args: any ) : ()
			task.wait(1)
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				Libraries.Signals["<notification>"]:FireClient(plr, {
					type = "notification",
					message = args[2],
					timer = 20,
				})
			end
		end,
	},
	
	{
		Name = "message",
		Description = "Send a server message to all players.",

		Aliases = {"m"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Message" },

		--

		Function = function( speaker: Player, args: any ) : ()
			task.wait(1)
			
			for _, plr in args[1] do
				if not plr:IsA("Player") then continue end
				
				Libraries.Signals["<notification>"]:FireClient(plr, {
					type = "message",
					speaker = speaker,
					message = args[2],
					timer = 20,
				})
			end
		end,
	},
	
	{
		Name = "announce",
		Description = "Send a server message to all players.",

		Aliases = {"announcement", "a"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Message" },

		--

		Function = function( speaker: Player, args: any ) : ()
			task.wait(1)

			Libraries.Signals["<notification>"]:FireAllClients({
				type = "message",
				speaker = speaker,
				message = args[1],
				timer = 20,
			})
		end,
	},
	
	{
		Name = "checkban",
		Description = "Check whether or not a player is banned.",

		Aliases = {"isuserbanned", "isbanned"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User" },

		--

		Function = function( speaker: Player, args: any ) : () 
			for _, user in args[1] do
				local isBanned, history = require("../BanService"):IsBanned(user)
				
				if isBanned then 
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `{game:GetService("Players"):GetNameFromUserIdAsync(user)} is banned.`,
						timer = 20,
					})
				else
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `{game:GetService("Players"):GetNameFromUserIdAsync(user)} is not banned.`,
						timer = 20,
					})
				end
			end
		end,
	},
	
	{
		Name = "timeban",
		Description = "Ban a player for a length of time.",

		Aliases = {"timeban"},


		--

		Rank = 2,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User", "Seconds", "Reason" },

		--

		Function = function( speaker: Player, args: any ) : () 
			require("../BanService"):UniverseBan(args[1], args[3], tick() + args[2])

			if #args[1] > 4 then
				require("../BanService").UniverseBanned:Once(function(data)
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `Successfully time banned {#args[1]} players.`,
						timer = 20,
					})
				end)
			else
				local _d, count = nil, 0; _d = require("../BanService").UniverseBanned:Connect(function(data)
					if not table.find(args[1], data.UserId) then return end

					count += 1; if count > 4 then _d:Disconnect() return end
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `Successfully time banned {game:GetService("Players"):GetNameFromUserIdAsync(data.UserId)}`,
						timer = 20,
					})
				end)

				task.delay(10, function() _d:Disconnect() end)
			end
		end,
	},
	
	{
		Name = "ban",
		Description = "Permanently ban a player.",

		Aliases = {"permban", "permanentban", "universalban"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User", "Reason" },

		--

		Function = function( speaker: Player, args: any ) : () 
			require("../BanService"):UniverseBan(args[1], args[2])

			if #args[1] > 4 then
				require("../BanService").UniverseBanned:Once(function(data)
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `Successfully banned {#args[1]} players.`,
						timer = 20,
					})
				end)
			else
				local _d, count = nil, 0; _d = require("../BanService").UniverseBanned:Connect(function(data)
					if not table.find(args[1], data.UserId) then return end

					count += 1; if count > 4 then _d:Disconnect() return end
					
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `Successfully banned {game:GetService("Players"):GetNameFromUserIdAsync(data.UserId)}`,
						timer = 20,
					})
				end)

				task.delay(10, function() _d:Disconnect() end)
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()
			warn(args[1], "Test")
			require("../BanService"):UnBan(args[1])

			if #args[1] > 4 then
				require("../BanService").UnBanned:Once(function(data)
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `Successfully unbanned {#args[1]} players.`,
						timer = 20,
					})
				end)
			else
				local _d, count = nil, 0; _d = require("../BanService").UnBanned:Connect(function(data)
					if not table.find(args[1], data.UserId) then return end

					count += 1; if count > 4 then _d:Disconnect() return end
					Libraries.Signals["<notification>"]:FireClient(speaker, {
						type = "notification",
						message = `Successfully unbanned {game:GetService("Players"):GetNameFromUserIdAsync(data.UserId)}`,
						timer = 20,
					})
				end)

				task.delay(10, function() _d:Disconnect() end)
			end
		end, 	
	},

	{
		Name = "savemap",
		Description = "Save the current map in the server cache.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()

			local folder = Instance.new("WorldModel", game:GetService("ServerStorage").Saves)
			folder.Name = "world#"..#game:GetService("ServerStorage").Saves:GetChildren()+1

			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Terrain") or obj:IsA("Camera") then continue end
				if obj:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(obj) then continue end

				obj = obj:Clone()
				obj.Parent = folder
				
				if obj.ClassName:lower():find("script") and obj["Enabled"] ~= nil then
					obj:SetAttribute("State", obj.Enabled)
					obj.Enabled = false
				else
					for _, script in obj:GetDescendants() do
						if script.ClassName:lower():find("script") and script["Enabled"] ~= nil then
							script:SetAttribute("State", script.Enabled)
							script.Enabled = false
						end
					end
				end
			end
			Libraries.Signals["<notification>"]:FireClient(speaker, {
				type = "notification",
				message = `[{folder.Name}] saved successfully.`,
				timer = 20,
			})
		end,
	},
	
	{
		Name = "loadmap",
		Description = "Load the latest map from the server cache.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		PreFunction = function() : ()
			local Saves = Instance.new("Folder", game:GetService("ServerStorage"))
			Saves.Name = "Saves"
			
			task.delay(5, function()
				pcall(function()
					local folder = Instance.new("WorldModel", Saves)
					folder.Name = "world#1"

					for _, obj in pairs(workspace:GetChildren()) do
						if obj:IsA("Terrain") or obj:IsA("Camera") then continue end
						if obj:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(obj) then continue end

						obj = obj:Clone()
						obj.Parent = folder

						if obj.ClassName:lower():find("script") and obj["Enabled"] ~= nil then
							obj:SetAttribute("State", obj.Enabled)
							obj.Enabled = false
						else
							for _, script in obj:GetDescendants() do
								if script.ClassName:lower():find("script") and script["Enabled"] ~= nil then
									script:SetAttribute("State", script.Enabled)
									script.Enabled = false
								end
							end
						end
					end
				end)
			end)
		end,

		Function = function( speaker: Player, args: any ) : ()
			Libraries.Signals["<notification>"]:FireAllClients({
				type = "hint",
				speaker = speaker,
				message = `⚠ Map loading, please wait a moment.`
			})
			
			--
			
			local folder = game:GetService("ServerStorage").Saves:FindFirstChild("world#"..#game:GetService("ServerStorage").Saves:GetChildren())
			local loaded = false

			if folder == nil then folder = game:GetService("ServerStorage").Saves:FindFirstChild("world#1") end
			if folder == nil then return end

			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Terrain") or obj:IsA("Camera") then continue end
				if obj:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(obj) then 
					obj.PrimaryPart.Anchored = true
					coroutine.wrap(function() repeat wait() until loaded == true; obj.PrimaryPart.Anchored = false end)()
				end
			end

			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Terrain") or obj:IsA("Camera") then continue end
				if obj:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(obj) then continue end

				obj:Destroy()
			end

			for _, obj in pairs(folder:GetChildren()) do
				obj = obj:Clone()
				obj.Parent = workspace
				
				if obj.ClassName:lower():find("script") and obj["Enabled"] ~= nil then
					obj.Enabled = obj:GetAttribute("State") or true
				else
					for _, script in obj:GetDescendants() do
						if script.ClassName:lower():find("script") and script["Enabled"] ~= nil then
							script.Enabled = obj:GetAttribute("State") or true
						end
					end
				end
			end
			
			Libraries.Signals["<notification>"]:FireClient(speaker, {
				type = "notification",
				message = `[{folder.Name}] loaded successfully.`,
				timer = 20,
			})
			
			loaded = true
		end,
	},
	
	{
		Name = "restoremap",
		Description = "Load the original map from the server cache.",

		Aliases = {},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : ()
			Libraries.Signals["<notification>"]:FireAllClients({
				type = "hint",
				speaker = speaker,
				message = `⚠ Map loading, please wait a moment.`
			})
			
			--

			local folder = game:GetService("ServerStorage").Saves:FindFirstChild("world#1")
			local loaded = false

			if folder == nil then return end

			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Terrain") or obj:IsA("Camera") then continue end
				if obj:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(obj) then 
					obj.PrimaryPart.Anchored = true
					coroutine.wrap(function() repeat wait() until loaded == true; obj.PrimaryPart.Anchored = false end)()
				end
			end

			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Terrain") or obj:IsA("Camera") then continue end
				if obj:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(obj) then continue end

				obj:Destroy()
			end

			for _, obj in pairs(folder:GetChildren()) do
				obj = obj:Clone()
				obj.Parent = workspace
				
				if obj.ClassName:lower():find("script") and obj["Enabled"] ~= nil then
					obj.Enabled = obj:GetAttribute("State") or true
				else
					for _, script in obj:GetDescendants() do
						if script.ClassName:lower():find("script") and script["Enabled"] ~= nil then
							script.Enabled = obj:GetAttribute("State") or true
						end
					end
				end
			end
			
			Libraries.Signals["<notification>"]:FireClient(speaker, {
				type = "notification",
				message = `Original map restored successfully.`,
				timer = 20,
			})
			
			loaded = true
		end,
	},
	
	{
		Name = "shutdown",
		Description = "Close the current server.",

		Aliases = {"closeserver", "shutdownserver"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : () 
			require("../ServerService"):Shutdown()
		end,
	},	
	
	{
		Name = "gshutdown",
		Description = "Close all running servers.",

		Aliases = {"globalshutdown", "universalshutdown", "shutdowngame"},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : () 
			require("../ServerService"):UniversalShutdown()
		end,
	},
	
	{
		Name = "migrate",
		Description = "Update server to latest version.",

		Aliases = {"updateserver", "migrateserver"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : () 
			require("../ServerService"):Migrate()
		end,
	},	

	{
		Name = "gmigrate",
		Description = "Update all servers to latest versions.",

		Aliases = {"globalmigrate", "universalmigrate", "migrategame"},


		--

		Rank = 4,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {},

		--

		Function = function( speaker: Player, args: any ) : () 
			require("../ServerService"):UniversalMigrate()
		end,
	},
	
	{
		Name = "serverlock",
		Description = "Stop anyone from joining server without required rank.",

		Aliases = {"lockserver"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Rank" },

		--

		PreFunction = function()
			storage["serverlock"] = {}
		end,

		Function = function( speaker: Player, args: any ) : () 
			local speakerRank = require("../RankService"):GetRankByUserId(speaker.UserId); if args[1] == nil then args[1] = speakerRank end
			if speakerRank and speakerRank.Id < args[1].Id then args[1] = speakerRank end
			
			--
			
			if args[1].Id > 0 then
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Server locked for {args[1].Name} and above.`,
					timer = 20,
				})
				
				require("../ServerService"):Lock(true, args[1])
			else
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Server unlocked.`,
					timer = 20,
				})
				
				require("../ServerService"):Lock(false)
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()
			require("../ServerService"):Lock(false)
		end,
	},		
	
	{
		Name = "universalLock",
		Description = "Stop anyone from joining without required rank.",

		Aliases = {"globallock"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Rank" },

		--

		PreFunction = function()
			storage["serverlock"] = {}
		end,

		Function = function( speaker: Player, args: any ) : () 
			if args[1] == speaker then args[1] = nil end

			local speakerRank = require("../RankService"):GetRankByUserId(speaker.UserId); if args[1] == nil or args[1] == speaker then args[1] = speakerRank end
			if speakerRank and speakerRank.Id < args[1].Id then args[1] = speakerRank end

			--

			if args[1].Id > 0 then
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Universe locked for {args[1].Name} and above.`,
					timer = 20,
				})
				
				require("../ServerService"):UniversalLock(true, args[1])
			else
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Universe unlocked.`,
					timer = 20,
				})
				
				require("../ServerService"):UniversalLock(false)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			Libraries.Signals["<notification>"]:FireClient(speaker, {
				type = "notification",
				message = `Universe unlocked.`,
				timer = 20,
			})
			
			require("../ServerService"):UniversalLock(false)
		end,
	},	
	
	{
		Name = "timeout",
		Description = "Temporarily mute someone for a limited time.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player", "Seconds" },

		--

		PreFunction = function()
			shared["Nexus Dynamics // Cache"]["Timeout"] = {}
			
			coroutine.wrap(function() while task.wait(1) do
				if shared["Nexus Dynamics // Cache"] and shared["Nexus Dynamics // Cache"]["Timeout"] and shared["Nexus Dynamics // Cache"]["Timeout"] == {} then continue end
				if shared["Nexus Dynamics // Cache"] and shared["Nexus Dynamics // Cache"]["Timeout"] and shared["Nexus Dynamics // Cache"]["Timeout"] ~= {} then
					Libraries.Signals["<timeout>"]:FireAllClients(shared["Nexus Dynamics // Cache"]["Timeout"])
				end
			end end)()
		end,

		Function = function( speaker: Player, args: any ) : () 

			for _, plr in args[1] do
				local threshold = tick() + (args[2] or 10000)
				shared["Nexus Dynamics // Cache"]["Timeout"][tostring(plr.UserId)] = (game:GetService("RunService"):IsStudio() and tick() or os.time()) + (args[2] or 10000)
				task.delay((args[2] or 10000), function()
					shared["Nexus Dynamics // Cache"]["Timeout"][tostring(plr.UserId)] = nil
				end)
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()
			
			for _, plr in args[1] do
				shared["Nexus Dynamics // Cache"]["Timeout"][tostring(plr.UserId)] = nil
			end
		end,
	},	
	
	{
		Name = "mute",
		Description = "Server mute a player.",

		Aliases = {},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "Player" },

		--

		Function = function( speaker: Player, args: any ) : () 

			for _, plr in args[1] do
				shared["Nexus Dynamics // Cache"]["Timeout"][plr.UserId] = math.huge
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			for _, plr in args[1] do
				shared["Nexus Dynamics // Cache"]["Timeout"][plr.UserId] = nil
			end
		end,
	},	

	{
		Name = "checkRank",
		Description = "Obtain the rank of a player.",

		Aliases = {"playerrank"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User" },

		--

		Function = function( speaker: Player, args: any ) : ()
			for _, userid in args[1] do
				local playerRank = require("../RankService"):GetRankByUserId(userid)
				if playerRank then
					Libraries.Signals["<notification>"]:FireClient(speaker, `{game:GetService("Players"):GetNameFromUserIdAsync(userid)} is ranked as {playerRank.Name}.`, 20, "notification")
				else
					Libraries.Signals["<notification>"]:FireClient(speaker, `{game:GetService("Players"):GetNameFromUserIdAsync(userid)} doesn't have a rank.`, 20, "notification")
				end
			end
		end,
	},
	
	{
		Name = "rank",
		Description = "Rank a person on Nexus Dynamics.",

		Aliases = {"permrank"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User", "Rank" },

		--

		Function = function( speaker: Player, args: any ) : () 
			local speakerRank = require("../RankService"):GetRankByUserId(speaker.UserId)
			if not args[2] then return end
			if speakerRank and args[2] and speakerRank.Id <= args[2].Id then return end

			for _, userid in args[1] do
				if userid == speaker.UserId then continue end
				
				local playerRank = require("../RankService"):GetRankByUserId(userid)
				if playerRank and (playerRank.Id > speakerRank.Id) then continue end
				
				require("../RankService"):Grant(userid, args[2].Name)
				
				--
				
				if #args[1] > 4 then continue end
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully ranked {game:GetService("Players"):GetNameFromUserIdAsync(userid)} to {args[2].Name}`,
					timer = 20,
				})
			end
			
			--
			
			if #args[1] > 4 then
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully ranked {#args[1]} players to {args[2].Name}`,
					timer = 20,
				})
			end
		end,
		
		UnFunction = function( speaker: Player, args: any ) : ()
			
			local speakerRank = require("../RankService"):GetRankByUserId(speaker.UserId)
			if speakerRank and args[2] and speakerRank.Id <= args[2].Id then return end
			
			for _, userid in args[1] do
				
				if userid == speaker.UserId then continue end
				
				--
				
				local playerRank = require("../RankService"):GetRankByUserId(userid)
				if playerRank and (playerRank.Id > speakerRank.Id) then continue end

				require("../RankService"):Revoke(userid)

				--

				if #args[1] > 4 then continue end
				
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully unranked {game:GetService("Players"):GetNameFromUserIdAsync(userid)}`,
					timer = 20,
				})
			end
			
			--
			
			if #args[1] > 4 then
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully unranked {#args[1]} players`,
					timer = 20,
				})
			end
		end,
	},	
	
	{
		Name = "serverRank",
		Description = "Rank a person in server on Nexus Dynamics.",

		Aliases = {"temporaryrank", "temprank"},


		--

		Rank = 3,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = { "User", "Rank" },

		--

		Function = function( speaker: Player, args: any ) : () 

			local speakerRank = require("../RankService"):GetRankByUserId(speaker.UserId)
			if not args[2] or not speakerRank then return end
			if speakerRank and args[2] and speakerRank.Id <= args[2].Id then return end
			
			for _, userid in args[1] do

				if userid == speaker.UserId then continue end

				--

				local playerRank = require("../RankService"):GetRankByUserId(userid)
				if playerRank and (playerRank.Id > speakerRank.Id) then continue end

				require("../RankService"):GrantT(userid, args[2].Name)

				--

				if #args[1] > 4 then continue end
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully server ranked {game:GetService("Players"):GetNameFromUserIdAsync(userid)} to {args[2].Name}`,
					timer = 20,
				})
			end

			--

			if #args[1] > 4 then
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully server ranked {#args[1]} players to {args[2].Name}`,
					timer = 20,
				})
			end
		end,

		UnFunction = function( speaker: Player, args: any ) : ()

			local speakerRank = require("../RankService"):GetRankByUserId(speaker.UserId)
			if speakerRank and args[2] and speakerRank.Id <= args[2].Id then return end

			for _, userid in args[1] do

				if userid == speaker.UserId then continue end

				--

				local playerRank = require("../RankService"):GetRankByUserId(userid)
				if playerRank.Id > speakerRank.Id then continue end

				require("../RankService"):Revoke(userid)

				--

				if #args[1] > 4 then continue end
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully unranked {game:GetService("Players"):GetNameFromUserIdAsync(userid)}`,
					timer = 20,
				})
			end

			--

			if #args[1] > 4 then
				Libraries.Signals["<notification>"]:FireClient(speaker, {
					type = "notification",
					message = `Successfully unranked {#args[1]} players`,
					timer = 20,
				})
			end
		end,
	},	
}
