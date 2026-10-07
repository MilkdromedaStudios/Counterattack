local Log, Types, History = {}, require("../Types"), {}
Log.__index = Log


return {
	Capture = function(self, message, messageType)
		local universalTime = DateTime.fromUnixTimestamp(tick()):ToUniversalTime()

		table.insert(History, {
			MessageType = messageType.Name or Enum.MessageType.MessageOutput.Name,
			Message = message, 
			Timestamp = `{universalTime.Hour}:{universalTime.Minute}:{universalTime.Second}`,
		})

		if (shared["nd diagnostics"]) then
			warn(game:GetService("RunService"):IsStudio() and History[#History] or `{History[#History].MessageType} - {History[#History].Message}`)
		end
		
		return self
	end,

	GetLogHistory = function(self, filter: {MessagingService})
		if filter then
			local backup = History
			for _, message in backup do
				if table.find(filter, message.MessageType) then table.insert(backup, message) end
			end
			return backup
		end

		return History
	end,
} :: Types.Log