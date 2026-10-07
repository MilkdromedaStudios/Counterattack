return {

	--[[
		Boolean | String | Number | Enum | Vector3 | Color | Material | FullName | BasePart | Instance | UnionOperation | Effect | Constraint
		
		Player | Team | Speed | Power | JumpHeight | Morph | Character
		
		{
			Name = "",
			Description = "",

			Aliases = {"example", "example"},


			--

			Rank = 1,
			CaseSensitive = false,

			Loopable = false,
			Frequency = 1,

			Arguments = { "Player", "Id" },

			--

			PreFunction = function() : ()

			end,

			Function = function( speaker: Player, args: any ) : ()

			end,

			UnFunction = function( speaker: Player, args: any ) : ()

			end,
		},
	]]	
}