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
	
	GetMaterialTextures = function() : { [string]: {ID: string, Color: Color3} }
		local textures = {
			Asphalt = { ID = "rbxassetid://9930003046", Color = Color3.fromRGB(80, 84, 84) },
			Basalt = { ID = "rbxassetid://9920482056", Color = Color3.fromRGB(75, 74, 74) },
			Brick = { ID = "rbxassetid://9920482813", Color = Color3.fromRGB(138, 97, 73) },
			Cardboard = { ID = "rbxassetid://14108651729", Color = Color3.fromRGB(255, 206, 152) },
			Carpet = { ID = "rbxassetid://14108662587", Color = Color3.fromRGB(163, 162, 165) },
			CeramicTiles = { ID = "rbxassetid://17429425079", Color = Color3.fromRGB(181, 173, 156) },
			ClayRoofTiles = { ID = "rbxassetid://18147681935", Color = Color3.fromRGB(255, 142, 87) },
			Cobblestone = { ID = "rbxassetid://9919718991", Color = Color3.fromRGB(134, 134, 118) },
			Concrete = { ID = "rbxassetid://9920484153", Color = Color3.fromRGB(152, 152, 152) },
			CorrodedMetal = { ID = "rbxassetid://9920589327", Color = Color3.fromRGB(104, 140, 173) },
			CrackedLava = { ID = "rbxassetid://9920484943", Color = Color3.fromRGB(255, 24, 67) },
			DiamondPlate = { ID = "rbxassetid://10237720195", Color = Color3.fromRGB(168, 175, 176) },
			Fabric = { ID = "rbxassetid://9920517696", Color = Color3.fromRGB(194, 193, 168) },
			Foil = { ID = "rbxassetid://9466552117", Color = Color3.fromRGB(168, 175, 176) },
			Glacier = { ID = "rbxassetid://9920518732", Color = Color3.fromRGB(221, 228, 229) },
			Glass = { ID = "rbxassetid://9438868521", Color = Color3.fromRGB(138, 167, 168) },
			Granite = { ID = "rbxassetid://9920550238", Color = Color3.fromRGB(149, 146, 139) },
			Grass = { ID = "rbxassetid://9920551868", Color = Color3.fromRGB(111, 126, 62) },
			Ground = { ID = "rbxassetid://9920554482", Color = Color3.fromRGB(140, 130, 104) },
			Ice = { ID = "rbxassetid://9920555943", Color = Color3.fromRGB(204, 210, 223) },
			LeafyGrass = { ID = "rbxassetid://9920557906", Color = Color3.fromRGB(106, 134, 64) },
			Leather = { ID = "rbxassetid://14108670073", Color = Color3.fromRGB(110, 73, 53) },
			Limestone = { ID = "rbxassetid://9920561437", Color = Color3.fromRGB(255, 243, 192) },
			Marble = { ID = "rbxassetid://9439430596", Color = Color3.fromRGB(122, 122, 122) },
			Metal = { ID = "rbxassetid://9920574687", Color = Color3.fromRGB(168, 175, 176) },
			Mud = { ID = "rbxassetid://9920578473", Color = Color3.fromRGB(121, 112, 98) },
			Pavement = { ID = "rbxassetid://9920579943", Color = Color3.fromRGB(143, 144, 135) },
			Pebble = { ID = "rbxassetid://9920581082", Color = Color3.fromRGB(122, 122, 118) },
			Plaster = { ID = "rbxassetid://14108671255", Color = Color3.fromRGB(204, 142, 105) },
			Rock = { ID = "rbxassetid://9920587470", Color = Color3.fromRGB(99, 100, 102) },
			RoofShingles = { ID = "rbxassetid://119722544879522", Color = Color3.fromRGB(66, 66, 66) },
			Rubber = { ID = "rbxassetid://14108673018", Color = Color3.fromRGB(32, 32, 32) },
			Salt = { ID = "rbxassetid://9920590225", Color = Color3.fromRGB(255, 255, 254) },
			Sand = { ID = "rbxassetid://9920591683", Color = Color3.fromRGB(207, 203, 167) },
			Sandstone = { ID = "rbxassetid://9920596120", Color = Color3.fromRGB(148, 124, 95) },
			Slate = { ID = "rbxassetid://9920599782", Color = Color3.fromRGB(88, 89, 86) },
			Snow = { ID = "rbxassetid://9920620284", Color = Color3.fromRGB(235, 253, 255) },
			Wood = { ID = "rbxassetid://9920625290", Color = Color3.fromRGB(172, 148, 108) },
			WoodPlanks = { ID = "rbxassetid://9920626778", Color = Color3.fromRGB(172, 148, 108) }
		}

		return textures
	end,	
} :: typeCheck