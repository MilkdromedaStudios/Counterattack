export type _Manager = {
	Sender: {
		Id: number,
		DisplayName: string,
		Name: string,
	},
	
	Type: string,
	Origin: string,
	
	Property: string,
	
	Values: {{
		["1"]: string | number,
		["2"]: string | number,
	}?}?,
	
	Index: string,
	Timestamp: number,
}

return {
	
	Manager = {
		Sender = {
			Id = game:GetService("Players").LocalPlayer.UserId,
			DisplayName = game:GetService("Players").LocalPlayer.DisplayName,
			Name = game:GetService("Players").LocalPlayer.Name,
		},
		
		Type = "N/A",
		Origin = "N/A",

		Property = "N/A",
		
		Values = {},
		
		Index = "Manager",
		Timestamp = tick(),
	} :: _Manager
}