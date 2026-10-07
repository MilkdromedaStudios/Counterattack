----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "FormatAI"
local Types = require("../Types")

RankService = require("../Services/RankService")
Rules = require("./FormatAI@rules")
Flags = require("./FormatAI@flags")



return {
	_flags = Flags,
	_rules = Rules,

	IsolateCommands = function(self: Types.FormatAI, text: string)
		local list = text:split(Rules.Prefix)
		table.remove(list, 1)

		for x, text in list  do
			list[x] = `{Rules.Prefix}{text}`
		end

		return list
	end,

	Read = function(self: Types.FormatAI, text: string)
		local Config: Types.CommandConfig = {
			HasPrefix = false,
			Command = "",
			CastType = "",
			Qualifiers = {},
		}

		Config.HasPrefix = text:split(Rules.SplitKey)[1]:sub(1, #Rules.Prefix) == Rules.Prefix
		Config.Command = text:split(Rules.SplitKey)[1]:sub(#Rules.Prefix+1, 400)

		if Config.Command:lower():sub(1, 6) == "unloop" then
			Config.Command = Config.Command:sub(7, #Config.Command)
			Config.CastType = "Unloop"
		elseif Config.Command:lower():sub(1, 4) == "loop" then
			Config.Command = Config.Command:sub(5, #Config.Command)
			Config.CastType = "Loop"
		elseif Config.Command:lower():sub(1, 2) == "un" then
			Config.Command = Config.Command:sub(3, #Config.Command)
			Config.CastType = "Undo"
		else
			Config.CastType = "Run"
		end

		text = table.concat(text:split(Rules.SplitKey), " ", 2) :: string
		text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):match("^%s*(.-)%s*$") :: string

		local _argument, _allowSpace = "", false

		for x, char in text:split("") do
			if table.find(Rules.QualifierBatchKey, char) and not _allowSpace then	
				_argument ..= `\n`
				continue
			end 

			if char == " " and not _allowSpace then
				if table.find(Rules.QualifierBatchKey, text:split("")[x-1]) then
					continue
				elseif table.find(Rules.QualifierBatchKey, text:split("")[x+1]) then
					continue
				elseif text:split("")[x+1] == " " then
					continue
				elseif not table.find(Rules.QualifierBatchKey, text:split("")[x-1]) then
					table.insert(Config.Qualifiers, _argument:split("\n"))
					_argument = ""
					continue
				end
			end

			if table.find(Rules.Open, char) then
				_allowSpace = true
			elseif table.find(Rules.Close, char) then
				_allowSpace = false
			end		

			if char == "/" then
				if (not text:split("")[x+2]) or (text:split("")[x+2] == "/") or (text:split("")[x+2] == "") or (text:split("")[x+2] == " ") then
					char = char.."0" :: string 
				end
			end	

			_argument ..= char	
		end		

		table.insert(Config.Qualifiers, _argument:split("\n"))

		return Config
	end,

	Build = function(self: Types.FormatAI, speaker: Player, config: Types.CommandConfig, commandDict: Types.Command)
		local newArguments = {}; 
		for x, argument in commandDict.Arguments do
			local _temp, argument = {}, self:GetQualifierType(argument)
			if config.Qualifiers[x] == nil then continue end							
			if table.find(Rules.Stringify, argument) then
				local str = {} :: {string}

				for i=x, #config.Qualifiers do
					if (typeof(config.Qualifiers[i]) == "table") then
						table.insert(str, table.concat(config.Qualifiers[i], ", "))
					else
						table.insert(str, config.Qualifiers[i])	
					end					
				end

				str = table.concat(str, " ")
				table.insert(newArguments, str)
				break
			end

			local tableGeneration do
				if table.find(Rules.ConcatTable, argument) then
					local value = self:Obtain(speaker, argument, table.concat(config.Qualifiers[x], ","))

					if typeof(value) == "table" then
						for _, instance in value  do
							table.insert(_temp, instance)
						end
					else
						table.insert(_temp, value)
					end
				end

				for index, qualifier in config.Qualifiers[x] do
					if not qualifier then Libraries.Log(`Qualifier <{qualifier}> is not supported.`, Enum.MessageType.MessageError); continue end

					local value = self:Obtain(speaker, argument, qualifier)
					if typeof(value) == "table" then
						for _, instance in value  do
							table.insert(_temp, instance)
						end
					else
						table.insert(_temp, value)
					end
				end
			end


			if table.find(Rules.ReturnAsTable, argument) then
				if (argument:lower() == "rank") then
					_temp = {
						Id = _temp[1],
						Name = _temp[2]
					}
				end
				table.insert(newArguments, _temp)
			else
				table.insert(newArguments, _temp[#_temp])
			end
		end

		return newArguments
	end,

	Obtain = function(self: Types.FormatAI, speaker: Player, qualifierType: string, input: string)
		return Libraries.Switch(qualifierType) {
			["User"] = function()
				local player = self:Obtain(speaker, "Player", input)
				if player then return player[1].UserId end

				local storage, verifyId, verifyName;

				local prepareNumber = tonumber(input);
				storage, verifyId = pcall(game:GetService("Players").GetNameFromUserIdAsync, game:GetService("Players"), prepareNumber)
				verifyId = storage and prepareNumber or nil

				storage, verifyName = pcall(game:GetService("Players").GetUserIdFromNameAsync, game:GetService("Players"), tostring(input))
				verifyName = storage and verifyName or nil

				return verifyId or verifyName or nil
			end,

			["Player"] = function()
				local misc = Libraries.Switch(input:lower()) {
					[""] = function()
						return speaker	
					end,

					["me"] = function()
						return speaker
					end,

					["other"] = function()
						local list = game:GetService("Players"):GetPlayers()
						table.remove(list, table.find(list, speaker))
						return list
					end,

					["all"] = function()
						return game:GetService("Players"):GetPlayers()
					end,

					["random"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x = 1, #list do if math.random(1, 3) == 1 then table.remove(list, x) end end
						return list
					end,

					["admins"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if not player:HasTag("Nexus Dynamics Administrator") then table.remove(list, x) end end
						return list
					end,

					["nonadmins"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if player:HasTag("Nexus Dynamics Administrator") then table.remove(list, x) end end
						return list
					end,

					["friends"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if not player:IsFriendsWith(Libraries.Util.GetDeveloperId()) then table.remove(list, x) end end
						return list
					end,

					["nonfriends"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if player:IsFriendsWith(Libraries.Util.GetDeveloperId()) then table.remove(list, x) end end
						return list
					end,

					["premium"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if player.MembershipType ~= Enum.MembershipType.Premium then table.remove(list, x) end end
						return list
					end,

					["nonpremium"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if player.MembershipType == Enum.MembershipType.Premium then table.remove(list, x) end end
						return list
					end,

					["r6"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.RigType == Enum.HumanoidRigType.R6 then continue end table.remove(list, x) end
						return list
					end,

					["r15"] = function()
						local list = game:GetService("Players"):GetPlayers()
						for x, player in list do if player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.RigType == Enum.HumanoidRigType.R15 then continue end table.remove(list, x) end
						return list
					end,
				} if misc then return misc end

				--

				if input:lower():sub(1, 5) == "range" then
					local range = input:match("%(", 1)::string
					range = range:sub(1, #range-1)
					if not tonumber(range) then return nil end

					local list = game:GetService("Players"):GetPlayers()
					for x, player in list do if (player.Character:GetPivot().Position - (speaker.Character::Model):GetPivot().Position).Magnitude <= range then continue end table.remove(list, x) end
					return list
				end

				if input:lower():sub(1, 1) == "%" then
					local list = game:GetService("Players"):GetPlayers()
					for _, team in game:GetService("Teams"):GetTeams() do
						if team.Name:lower():sub(1, #input-1) == input:sub(2, #input) then 
							for x, player in list do
								if player.Team == team then continue end
								table.remove(list, x)
							end	
						end
					end

					return nil
				end

				local list = {} 
				for _, player in game:GetService("Players"):GetPlayers() do
					if player.Name:lower():sub(1, #input) == input:lower() then table.insert(list, player) end
				end

				return #list > 0 and list or nil
			end,

			["Team"] = function()
				for _, team in game:GetService("Teams"):GetTeams() do
					if team.Name:lower():sub(1, #input:lower():gsub(" ", "")) == input:lower():gsub(" ", ""):sub(1, #input) then 
						return team
					end
				end

				return nil
			end,	

			["Name"] = function()
				return tostring(input)
			end,

			["String"] = function()
				return tostring(input)
			end,

			["Boolean"] = function()
				return input:lower() == "true" and true or input:lower() == "false" and false or nil
			end,

			["Number"] = function()
				return tonumber(input)
			end,

			["Vector3"] = function()
				local coordinates = input:gsub(" ", ""):split(",")
				local X, Y, Z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])

				if not X then return Vector3.new(0, 0, 0) end
				if X and not Y then return Vector3.new(X, X, X) end
				if X and Y and not Z then return Vector3.new(X, Y, 0) end
				if X and Y and Z then return Vector3.new(X, Y, Z) end
				return nil
			end,

			["Enum"] = function()
				if #input:split(".") == 3 then
					return Enum[input:split(".")[2]][input:split(".")[3]]
				else
					for _, enum in Enum:GetEnums() do
						for _, enumItem in enum:GetEnumItems() do
							if enumItem.Name:lower():gsub(1, #(input or "N/A")) == (input or "N/A"):lower() then 
								return enumItem
							end
						end
					end
				end

				return nil
			end,

			["Color"] = function()
				local colorValues = input:gsub(" ", ""):split(",") 
				local R, G, B = tonumber(colorValues[1]), tonumber(colorValues[2]), tonumber(colorValues[3])
				if tonumber(R) then
					if R and not G then return Color3.fromRGB(R, R, R) end
					if R and G and not B then return Color3.fromRGB(R, G, 0) end
					if R and G and B then return Color3.fromRGB(R, G, B) end
					return Color3.fromRGB(255, 255, 255)
				elseif input:sub(1, 1) == "#" then
					return Color3.fromHex(input) or Color3.fromRGB(255, 255, 255)
				else
					for name, color in Libraries.Util.GetBrickColors() do
						if name:gsub(" ", ""):lower():sub(1, #input:gsub(" ", "")) == input:lower():gsub(" ", "") then
							return color
						end
					end
				end

				return nil
			end,

			["Material"] = function()
				for _, material in Enum.Material:GetEnumItems() do
					if material.Name:lower():gsub(" ", ""):sub(1, #input:gsub(" ", "")) == input:lower():gsub(" ", "") then
						return material
					end
				end

				return nil
			end,

			["Rank"] = function()
				local list = RankService:GetRankInfos()
				for _, rankData in list do
					if rankData.Name:lower():sub(1, #input) == input:lower() then
						return rankData
					end
				end

				return nil
			end,

			default = function()
				return nil
			end,
		}		
	end,	

	--

	GetQualifierType = function(self: Types.FormatAI, text: string )
		for name, aliases in Flags.QualifierTypes do
			if name:lower() == text or table.find(aliases, text:lower()) then
				return name
			end
		end

		return nil
	end,
} :: Types.FormatAI