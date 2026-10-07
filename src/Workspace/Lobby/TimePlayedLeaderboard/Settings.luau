return {
  DATA_STORE              = "TopTimePlayed" , --< Name of the Data store values will be saved in
  SCORE_UPDATE            = 1 , --< How often you want the score to be sent to datastore in minutes (no less than 1)
  LEADERBOARD_UPDATE      = 1 , --< How often you want the leaderboard to update in minutes (no less than 1) 
  NAME_OF_STAT            = "TimePlayed" , --< Stat name to save in the database
  USE_LEADERSTATS         = false , --< Should use the Roblox built-in Leaderboard system too? More info: https://create.roblox.com/docs/building-and-visuals/ui/leaderboard-system
  NAME_LEADERSTATS        = "Time Played" , --< What the name of the Leaderboard to use?
  SHOW_1ST_PLACE_AVATAR   = true , --< Show the avatar of the player in 1st place?
  TRY_ADJUST_AVATAR       = true , --< Try to adjust the avatar to not be floating in the air?
  DO_DEBUG                = false , --< Should it debug (print) messages to the console?
  IGNORED_PLAYERS         = { --< List player IDs to hide from the leaderboard (e.g. owners/staff).
    [1] = true, -- Roblox
    [2] = true, -- John Doe
    [3] = true, -- Jane Doe
  },
}
