----- || LIBRARIES || -----
local Presets = require(script.Presets)



----- || TYPE CHECK || -----
type presetManagerProperties = Presets._Manager
type presetManager = ( self: any, "Manager") -> (properties: presetManagerProperties) -> ()

type presetCommandProperties = { [string]: any }
type presetCommand = ( self: any, "Command") -> (properties: { [string]: any }) -> ()

export type presetType = presetManager & presetCommand



----- || MAIN || -----
return {
	
	New = function( self: any, type: string ) 
		if not type then assert(type, "Type does not exist.") end
		
		--
				
		local logData = Presets[type]
		logData.Timestamp = tick()
		
		return function( properties )
			for name, value in properties do 
				if not logData[name] then continue end 
				logData[name] = value 
			end

			self.MessageOut:Fire(logData)	
		end
	end :: presetType,
	
	--
	
	MessageOut = require(script.Parent.Maid).signal("MessageOut")
}