----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "CommandService"
local Types = require("../Types")
local FormatAI = require("../AI/FormatAI")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {
	GetCommandInfoAsync = function(self: Types.CommandService, name: string)
		for index, CommandDict in self.CommandList["server@built-in"] :: { Types.Command } do
			CommandDict.RunContext = Enum.RunContext.Server
			if CommandDict.Name:lower() == name:lower() then return CommandDict end
			for _, alias in CommandDict.Aliases do if alias:lower() == name:lower() then return CommandDict end end
		end

		for index, CommandDict in self.CommandList["client@built-in"] :: { Types.Command } do
			CommandDict.RunContext = Enum.RunContext.Client
			if CommandDict.Name:lower() == name:lower() then return CommandDict end
			for _, alias in CommandDict.Aliases do if alias:lower() == name:lower() then return CommandDict end end
		end

		for index, CommandDict in self.CommandList["server@custom"] :: { Types.Command } do
			CommandDict.RunContext = Enum.RunContext.Server
			if CommandDict.Name:lower() == name:lower() then return CommandDict end
			for _, alias in CommandDict.Aliases do if alias:lower() == name:lower() then return CommandDict end end
		end

		for index, CommandDict in self.CommandList["client@custom"] :: { Types.Command } do
			CommandDict.RunContext = Enum.RunContext.Client
			if CommandDict.Name:lower() == name:lower() then return CommandDict end
			for _, alias in CommandDict.Aliases do if alias:lower() == name:lower() then return CommandDict end end
		end

		return nil
	end,
	
	GetCommandList = function(self: Types.CommandService, type: Types.CommandType)
		return Libraries.Switch(type) {
			["All"] = function()
				local dict = {}

				for context, commandList in self.CommandList do
					local runContext, moduleType = context:split("@")[1], context:split("@")[2]

					for _, command in commandList::{Types.Command} do
						command.RunContext, command.ModuleType = runContext:lower() == "server" and Enum.RunContext.Server or Enum.RunContext.Client, moduleType:gsub("^%l", string.upper)
						command.HasUndo = command.UnFunction ~= nil
						table.insert(dict, command)
					end
				end 

				return dict :: {Types.Command}
			end,

			["Server"] = function()
				local dict = {}

				for context, commandList in self.CommandList do
					local runContext, moduleType = context:split("@")[1], context:split("@")[2]
					if runContext == "server" then continue end

					for _, command in commandList do
						command.RunContext, command.ModuleType = runContext:lower() == "server" and Enum.RunContext.Server or Enum.RunContext.Client, moduleType:gsub("^%l", string.upper)
						command.HasUndo = command.UnFunction ~= nil
						table.insert(dict, command)
					end
				end 

				return dict :: {Types.Command}
			end,

			["Client"] = function()
				local dict = {}

				for context, commandList in self.CommandList do
					local runContext, moduleType = context:split("@")[1], context:split("@")[2]
					if runContext == "client" then continue end

					for _, command in commandList do
						command.RunContext, command.ModuleType = runContext:lower() == "server" and Enum.RunContext.Server or Enum.RunContext.Client, moduleType:gsub("^%l", string.upper)
						command.HasUndo = command.UnFunction ~= nil
						table.insert(dict, command)
					end
				end 

				return dict :: {Types.Command}
			end,

			["Built-In"] = function()
				local dict = {}

				for context, commandList in self.CommandList do
					local runContext, moduleType = context:split("@")[1], context:split("@")[2]
					if moduleType == "built-in" then continue end

					for _, command in commandList do
						command.RunContext, command.ModuleType = runContext:lower() == "server" and Enum.RunContext.Server or Enum.RunContext.Client, moduleType:gsub("^%l", string.upper)
						command.HasUndo = command.UnFunction ~= nil
						table.insert(dict, command)
					end
				end 

				return dict :: {Types.Command}
			end,

			["Custom"] = function()
				local dict = {}

				for context, commandList in self.CommandList do
					local runContext, moduleType = context:split("@")[1], context:split("@")[2]
					if moduleType == "custom" then continue end

					for _, command in commandList do
						command.RunContext, command.ModuleType = runContext:lower() == "server" and Enum.RunContext.Server or Enum.RunContext.Client, moduleType:gsub("^%l", string.upper)
						command.HasUndo = command.UnFunction ~= nil
						table.insert(dict, command)
					end
				end 

				return dict :: {Types.Command}
			end, 

			["Server Built-In"] = function()
				local dict = {}

				for _, command in self.CommandList["server@built-in"] do
					command.RunContext, command.ModuleType = Enum.RunContext.Server, "Built-in"
					command.HasUndo = command.UnFunction ~= nil
					table.insert(dict, command)
				end

				return self.CommandList["server@built-in"]
			end,	

			["Client Built-In"] = function()
				local dict = {}

				for _, command in self.CommandList["client@built-in"] do
					command.RunContext, command.ModuleType = Enum.RunContext.Client, "Built-in"
					command.HasUndo = command.UnFunction ~= nil
					table.insert(dict, command)
				end

				return self.CommandList["client@built-in"]
			end,

			["Server Custom"] = function()
				local dict = {}

				for _, command in self.CommandList["server@custom"] do
					command.RunContext, command.ModuleType = Enum.RunContext.Server, "Custom"
					command.HasUndo = command.UnFunction ~= nil
					table.insert(dict, command)
				end

				return self.CommandList["server@custom"]
			end,	

			["Client Custom"] = function()
				local dict = {}

				for _, command in self.CommandList["client@custom"] do
					command.RunContext, command.ModuleType = Enum.RunContext.Client, "Custom"
					command.HasUndo = command.UnFunction ~= nil
					table.insert(dict, command)
				end

				return self.CommandList["client@custom"]
			end,
		}
	end,
	
	Request = function(self: Types.CommandService, speaker: Player, text: string)
		local _, result, result2 = xpcall(function()
			local commandConfig = FormatAI:Read(text); if not commandConfig then return nil end
			local commandDict = self:GetCommandInfoAsync(commandConfig.Command); if not commandDict or not commandDict.Rank then return nil end

			return commandConfig, commandDict		
		end,

		function(message: string)
			Libraries.Log(message, Enum.MessageType.MessageError)
			return nil
		end)
		
		return result, result2
	end,
	
	Cast = function(self: Types.CommandService, speaker: Player, commandConfig: Types.CommandConfig, commandDict: Types.Command)
		xpcall(
			function()
				local args = FormatAI:Build(speaker, commandConfig, commandDict)
				
				Libraries.Switch(commandConfig.CastType) {
					["Run"] = function()
						if (commandDict.RunContext == Enum.RunContext.Client) then
							Libraries.Signals["<client>"]:InvokeClient(speaker, commandDict.Name, "run", args)
							return	
						end
						
						commandDict.Function(speaker, args)		
					end,

					["Undo"] = function()
						if (commandDict.RunContext == Enum.RunContext.Client) then
							Libraries.Signals["<client>"]:InvokeClient(speaker, commandDict.Name, "undo", args)
							return	
						end
						
						commandDict.UnFunction(speaker, args)		
					end,
				}
			end,

			function(message: string)
				Libraries.Log(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end,
	
	--
	
	CommandList = {
		["server@built-in"] = require(script["server@built-in"]),
		["client@built-in"] = require(script["client@built-in"]),
		["server@custom"] = require(Libraries.Custom["CommandList | Server"]),
		["client@custom"] = require(Libraries.Custom["CommandList | Client"]),
	}
}

return Cache.Constructor :: Types.CommandService