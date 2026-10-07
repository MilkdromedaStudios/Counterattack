dictionary = {

	Config = _G["setup-client@2.0.6\config"] or {
		Draggable = true :: boolean,
		ColorWheelOutput = "HEX" :: string,
		Use24HourClock = true :: boolean,
		ClockEnabled = true :: boolean,
		Suggestions = true :: boolean,
		Autofill = true :: boolean,
		PreviewIcons = true :: boolean,
		Accent = "#30b0ff" :: string,
		Theme = "Dark" :: string,
		NotificationsEnabled = true :: boolean,
		NotificationPosition = "Bottom-Right" :: string,
		Alerts = true :: boolean,
		FlyPromptEnabled = true :: boolean,  
		DebugbarEnabled = true :: boolean,
		Version = true :: boolean,
		Region = true :: boolean,  
		FPS = true :: boolean,    
		Errors = true :: boolean,     
		Warnings = true :: boolean,        
		MemoryUsage = true :: boolean,
		AvgPing = true :: boolean,
		Menu = "M" :: string,
		CommandPrompt = "Quote" :: string,
		Shell = "F3" :: string,  
		TopbarEnabled = true :: boolean,
		Transparency = 0.3 :: number,
		TopbarPosition = "Center" :: string,
	},

	BuildInfo = _G["setup-client@2.0.6\buildinfo"] or {
		StudioVersion = "N/A" :: string,
		SourceCodeId = "N/A" :: string,
		SerialNumber = "N/A" :: string,
		BuildNumber = "N/A" :: string,
		ModelName = "N/A" :: string,
		ModelNumber = "N/A" :: string,
		ProductNumber = "N/A" :: string,
		BanService = "N/A" :: string,
		CommandService = "N/A" :: string,
		GhostService = "N/A" :: string,
		NotificationService = "N/A" :: string,
		PlayerService = "N/A" :: string,
		RankService = "N/A" :: string,
		VisualService = "N/A" :: string,
	},

	--

	Package = script:FindFirstAncestor("setup-client@2.0.6"),
	Libraries = script:FindFirstAncestor("setup-client@2.0.6"):FindFirstChild("Libraries"),
	Elements = script:FindFirstAncestor("setup-client@2.0.6"):FindFirstChild("Elements"),

	--

	Fusion = require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Fusion),
	Maid = require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Maid),
	Util = require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Util),

	--

	Color = require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Theme),

	--

	Common = require(script:FindFirstAncestor("setup-client@2.0.6").Elements.Common),
	Interactions = require(script:FindFirstAncestor("setup-client@2.0.6").Elements.Interactions), 
	Windows = require(script:FindFirstAncestor("setup-client@2.0.6").Elements.Windows),

	--

	Signals = game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-signals")[1],

	--
	
	Switch = function(case: any)
		return function(cases: {[string]: () -> any})
			if cases[case] then
				return cases[case]()
			elseif cases.default then
				return cases.default()
			end

			return nil
		end
	end,

	--
	
	Open = function(self: any)
		if not (shared["Nexus Dynamics // Setup"].Panel) or (shared["Nexus Dynamics // Setup"].IsOpen) then return end
		local executable = script:FindFirstAncestorWhichIsA("UIPageLayout")
		
		shared["Nexus Dynamics // Setup"].IsOpen = true
		shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame.GroupTransparency = 1
		shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame.Position -= UDim2.fromScale(0, 0.1)
		shared["Nexus Dynamics // Setup"].Panel.Element.Shadow.Position -= UDim2.fromScale(0, 0.1)
		shared["Nexus Dynamics // Setup"].Panel.Element.Shadow.ImageTransparency = 1
		shared["Nexus Dynamics // Setup"].Panel.Element.Visible = true
		
		require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Maid).tween({
			[shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame] = {
				TweenInfo.new(executable.Animated and executable.TweenTime or 0, executable.EasingStyle, executable.EasingDirection),
				
				{
					GroupTransparency = 0,
					Position = shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame.Position + UDim2.fromScale(0, 0.1)
				},
			},
			
			[shared["Nexus Dynamics // Setup"].Panel.Element.Shadow] = {
				TweenInfo.new(executable.Animated and executable.TweenTime or 0, executable.EasingStyle, executable.EasingDirection),
				
				{
					ImageTransparency = 0,
					Position = shared["Nexus Dynamics // Setup"].Panel.Element.Shadow.Position + UDim2.fromScale(0, 0.1)
				},
			}
		})
	end,	
	
	Close = function(self: any)
		if not (shared["Nexus Dynamics // Setup"].Panel) or not (shared["Nexus Dynamics // Setup"].IsOpen) then return end
		local executable = script:FindFirstAncestorWhichIsA("UIPageLayout")
		shared["Nexus Dynamics // Setup"].IsOpen = false
		require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Maid).tween({
			[shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame] = {
				TweenInfo.new(executable.Animated and executable.TweenTime or 0, executable.EasingStyle, executable.EasingDirection),
				
				{
					GroupTransparency = 1,
					Position = shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame.Position + UDim2.fromScale(0, 0.1)
				},
			},

			[shared["Nexus Dynamics // Setup"].Panel.Element.Shadow] = {
				TweenInfo.new(executable.Animated and executable.TweenTime or 0, executable.EasingStyle, executable.EasingDirection),
				
				{
					ImageTransparency = 1,
					Position = shared["Nexus Dynamics // Setup"].Panel.Element.Shadow.Position + UDim2.fromScale(0, 0.1)
				},
			}
		})
		
		task.delay(executable.Animated and executable.TweenTime or 0, function()
			shared["Nexus Dynamics // Setup"].Panel.Element.Visible = false
			shared["Nexus Dynamics // Setup"].Panel.Element.MainFrame.Position -= UDim2.fromScale(0, 0.1)
			shared["Nexus Dynamics // Setup"].Panel.Element.Shadow.Position -= UDim2.fromScale(0, 0.1)
		end)
	end,
}

if not shared["Nexus Dynamics // Cache"] then shared["Nexus Dynamics // Cache"] = {} end
if not shared["Nexus Dynamics // Setup"] then  dictionary.scope = dictionary.Fusion.scoped(dictionary.Fusion); shared["Nexus Dynamics // Setup"] = dictionary end

return dictionary