dictionary = {

	Package = script:FindFirstAncestor("notification-client@2.0.6"),
	Libraries = script:FindFirstAncestor("notification-client@2.0.6"):FindFirstChild("Libraries"),
	Elements = script:FindFirstAncestor("notification-client@2.0.6"):FindFirstChild("Elements"),
	
	--

	Fusion = require(script:FindFirstAncestor("notification-client@2.0.6").Libraries.Fusion),
	Maid = require(script:FindFirstAncestor("notification-client@2.0.6").Libraries.Maid),
	Util = require(script:FindFirstAncestor("notification-client@2.0.6").Libraries.Util),
	
	--
	
	Windows = require(script:FindFirstAncestor("notification-client@2.0.6").Elements.Windows),
	
	--
	
	Color = require(script:FindFirstAncestor("notification-client@2.0.6").Libraries.Theme),
	
	--
	
	Signals = game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-signals")[1],
	
	--
	
	Cache = {},

	Prompt = function( self: any, title: string, description: string, alt: string?, buttonA: string?, buttonB: string?)
		self.Notification:Fire({
			type = "prompt",
			title = title,
			description = description,
			alt = alt,
			buttonA = buttonA,
			buttonB = buttonB,
		})
	end,

	Notify = function( self: any, message: string, timer: number?, type: string?, speaker: Player?)
		self.Notification:Fire({
			type = type or "notification",
			typeOf = type,
			message = message,
			speaker = speaker,
			timer = timer,
		})		
	end,

	Fly = function( self: any, state: boolean, speed: number, collision: boolean? )
		self.Notification:Fire({
			type = not collision and "flying" or "noclipping",
			state = state,
			speed = speed,
		})	
	end,

	Notification = require(script:FindFirstAncestor("notification-client@2.0.6").Libraries.Maid).signal("Notification"),
}

if not shared["Nexus Dynamics // Notification"] then  dictionary.scope = dictionary.Fusion.scoped(dictionary.Fusion) shared["Nexus Dynamics // Notification"] = dictionary end

return dictionary