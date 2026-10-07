----- || TYPE CHECK || -----
type typeCheck = {
	GetChatColor: (( username: string ) -> Color3) & (( userId: number ) -> Color3),	
	GetLocalTime: ( clockStyle: number? ) -> string,
	ConvertToLocalTime: ( unixtimestamp: number, clockStyle: number? ) -> string,
	GetBrickColors: () -> { [string]: Color3 },
}



----- || MAIN || -----
return {


	GetChatColor = function( username: string | number ) : Color3
		if typeof(username) == "number" then username = game:GetService("Players"):GetNameFromUserIdAsync(username) end
		
		local Color_Offset, Colors = 0, {
			Color3.new(0.992157, 0.160784, 0.262745),
			Color3.new(0.00392157, 0.635294, 1),
			Color3.new(0.00784314, 0.721569, 0.341176),
			Color3.new(0.705882, 0.501961, 1),
			Color3.new(0.854902, 0.521569, 0.254902),
			Color3.new(0.960784, 0.803922, 0.188235),
			Color3.new(0.909804, 0.729412, 0.784314),
			Color3.new(0.843137, 0.772549, 0.603922),
		}

		local function GetNameValue(pName)
			local value = 0
			for index = 1, #pName do
				local cValue = string.byte(string.sub(pName, index, index))
				local reverseIndex = #pName - index + 1
				if #pName%2 == 1 then
					reverseIndex = reverseIndex - 1
				end
				if reverseIndex%4 >= 2 then
					cValue = -cValue
				end
				value = value + cValue
			end
			return value
		end	


		return Colors[((GetNameValue(username)) % #Colors) + 1]	
	end,

	GetLocalTime = function( clockStyle: number? ) : string

		local Date = os.date("*t")

		if not clockStyle or clockStyle == 12 then
			Date = `{Date.hour < 13 and Date.hour or Date.hour - 12}:{Date.min < 10 and `0{Date.min}` or Date.min} {Date.hour < 13 and "AM" or "PM"}`
		else
			Date = `{Date.hour}:{Date.min < 10 and `0{Date.min}` or Date.min}`
		end

		return Date
	end,
	
	ConvertToLocalTime = function( unixtimestamp: number, clockStyle: number? ) : string

		local Date = os.date("*t", unixtimestamp);

		if not clockStyle or clockStyle == 12 then
			Date = `{Date.hour < 13 and Date.hour or Date.hour - 12}:{Date.min < 10 and `0{Date.min}` or Date.min} {Date.hour < 13 and "AM" or "PM"}`
		else
			Date = `{Date.hour}:{Date.min < 10 and `0{Date.min}` or Date.min}`
		end

		return Date
	end,
	
	GetBrickColors = function() : { [string]: Color3 }
		local brickcolors = {
			["red"] = Color3.fromRGB(255, 0, 0),
			["orange"] = Color3.fromRGB(255, 127, 0),
			["yellow"] = Color3.fromRGB(255, 255, 0),
			["lime"] = Color3.fromRGB(127, 255, 0),
			["green"] = Color3.fromRGB(0, 255, 0),
			["darkgreen"] = Color3.fromRGB(0, 127, 0),
			["lightblue"] = Color3.fromRGB(0, 255, 255),
			["blue"] = Color3.fromRGB(0, 127, 255),
			["darkblue"] = Color3.fromRGB(0, 0, 255),
			["purple"] = Color3.fromRGB(127, 0, 255),
			["magenta"] = Color3.fromRGB(255, 0, 255),
			["pink"] = Color3.fromRGB(255, 127, 255),
			["rose"] = Color3.fromRGB(255, 0, 127),

		}; for i = 1, 1032 do pcall(function() if not brickcolors[BrickColor.new(i).Name:lower():gsub(" ", "")] then brickcolors[BrickColor.new(i).Name:lower():gsub(" ", "")] = BrickColor.new(i).Color end end) end

		return brickcolors
	end,	
} :: typeCheck