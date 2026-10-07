return {
	
	--[[
		Boolean | String | Number | Enum | Vector3 | Color | Material | FullName | BasePart | Instance | UnionOperation | Effect | Constraint
		
		Player | Team | Speed | Power | JumpHeight | Morph | Character
	]]	
	
	{

		Name = "ping",
		Description = "Identify your ping",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : () 
			local current, result = tick(), game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-signals")[1]["<ping>"]:InvokeServer();
			result = tick()
			game:GetService("TestService"):Message("WORKED")
			shared["Nexus Dynamics // Notification"]:Notify(`Ping: {math.floor((result - current) * 1000)}ms`, 20)
		end,
	},
	
	{

		Name = "prefix",
		Description = "Get the prefix for commands.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			shared["Nexus Dynamics // Notification"].Notification:Fire({
				type = "notification",
				message = `Prefix: {game:GetService("Players"):GetAttribute("Prefix")}`,
				timer = 10,
			})
		end,
	},
	
	{

		Name = "panel",
		Description = "Opens the panel.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			shared["Nexus Dynamics"]:Open()
			_G["topbar-client@2.0.6"]:Hide()
		end,

		UnFunction = function(speaker, args) : ()
			shared["Nexus Dynamics"]:Close()
			_G["topbar-client@2.0.6"]:Show()
		end,	
	},
	
	{

		Name = "commands",
		Description = "View a list of commands.",

		Aliases = {"command", "cmds", "cmd", "help"},


		--

		Rank = 1,
		CaseSensitive = false,
		
		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			shared["Nexus Dynamics"].Ribbon:ChangeTab("Commands")
			game:GetService("RunService").Heartbeat:Wait()
			shared["Nexus Dynamics"]:Open()
		end,

		UnFunction = function(speaker, args) : ()
			shared["Nexus Dynamics"]:Close()
			_G["topbar-client@2.0.6"]:Show()
		end,	
	},
	
	{

		Name = "settings",
		Description = "View a list of commands.",

		Aliases = {"preferences", "config"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			shared["Nexus Dynamics"].Ribbon:ChangeTab("Settings")
			game:GetService("RunService").Heartbeat:Wait()
			shared["Nexus Dynamics"]:Open()
		end,

		UnFunction = function(speaker, args) : ()
			shared["Nexus Dynamics"]:Close()
			_G["topbar-client@2.0.6"]:Show()
		end,	
	},
	
	{

		Name = "manager",
		Description = "View the managers tab.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			shared["Nexus Dynamics"].Ribbon:ChangeTab("Manager")
			game:GetService("RunService").Heartbeat:Wait()
			shared["Nexus Dynamics"]:Open()
		end,

		UnFunction = function(speaker, args) : ()
			shared["Nexus Dynamics"]:Close()
			_G["topbar-client@2.0.6"]:Show()
		end,	
	},
	
	{

		Name = "logs",
		Description = "View the debugger tab.",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			shared["Nexus Dynamics"].Ribbon:ChangeTab("AuditLog")
			game:GetService("RunService").Heartbeat:Wait()
			shared["Nexus Dynamics"]:Open()
		end,

		UnFunction = function(speaker, args) : ()
			shared["Nexus Dynamics"]:Close()
			_G["topbar-client@2.0.6"]:Show()
		end,	
	},
	
	{

		Name = "hideguis",
		Description = "Hides all visible GUIs",

		Aliases = {},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {"hideui"}, 

		--

		Function = function(speaker, args) : ()
			for _, gui in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
				if gui:IsA("ScreenGui") then gui:SetAttribute("OriginalState", gui:GetAttribute("OriginalState") or gui.Enabled) gui.Enabled = gui.Name:lower():find("nexus-dynamics") ~= nil end 
			end
		end,	
	},
	
	{

		Name = "showguis",
		Description = "Hides all visible GUIs",

		Aliases = {"showui"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {}, 

		--

		Function = function(speaker, args) : ()
			for _, gui in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
				if gui:IsA("ScreenGui") then gui.Enabled = gui:GetAttribute("OriginalState") or gui.Enabled end
			end
		end,	
	},
	
	{

		Name = "view",
		Description = "Spectate a specific player.",

		Aliases = {"spectate"},


		--

		Rank = 1,
		CaseSensitive = false,

		Loopable = false,
		Frequency = 1,

		Arguments = {"Player"}, 

		--

		Function = function(speaker, args) : ()
			local __suc, __error = pcall(function()
				speaker.Character.Humanoid.WalkSpeed = (not args[1] or args[1][1] == speaker) and game:GetService("StarterPlayer").CharacterWalkSpeed or 0
				workspace.CurrentCamera.CameraSubject = (args[1] and args[1][1]) and (args[1][1].Character:FindFirstChild("Humanoid")) or game:GetService("Players").LocalPlayer.Character:FindFirstChild("Humanoid")
			end)
			
			if not __suc then
				shared["Nexus Dynamics // Cache"][__error] = game:GetService("RunService"):IsStudio() and tick() or os.time()
			end
		end,

		UnFunction = function(speaker, args) : ()
			local __suc, __error = pcall(function()
				speaker.Character.Humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
				workspace.CurrentCamera.CameraSubject = game:GetService("Players").LocalPlayer.Character:FindFirstChild("Humanoid")
			end)
			
			if not __suc then
				shared["Nexus Dynamics // Cache"][__error] = game:GetService("RunService"):IsStudio() and tick() or os.time()
			end
		end,	
	},
}