--!nonstrict
--[[
  TimePlayedClass, RenanMSV @2023

  A script designed to update a leaderboard with
  the top 10 players who most play your game.
  
  Do not change this script. All configurations can be found
  in the Settings script.

  Version 1.2.0.
]]

local PlayersService = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

if not script.Parent then return end
local SettingsModule = script.Parent:FindFirstChild("Settings")
local Config = require(SettingsModule)

local function bool(v, d) if typeof(v) == "boolean" then return v end; return d end
local function str(v, d) if typeof(v) == "string" then return v end; return d end
local function num(v, d) if typeof(v) == "number" then return v end; return d end
local function tab(v, d) if typeof(v) == "table" then return v end; return d end

local CONST_DEBUG_ENABLED = bool(Config.DO_DEBUG, false)
local CONST_DEBUG_PREFIX = "TopTimePlayed Board:"
local CONST_DS_UP_CHECK_KEY = "____PS"
local CONST_DS_PAGE_SIZE = 100
local CONST_USER_NAME_NOT_FOUND = "Name not found"
local CONST_USER_THUMBNAIL_NOT_FOUND = "rbxassetid://124229005620731"
local CONST_USER_TEST_PROFILE_NAME = "Studio Test Profile"
local CONST_USER_TEST_PROFILE_THUMBNAIL = "rbxassetid://1146888101"
local CONST_FLAG_NO_API_SERVICES = "TopTimePlayedLeaderboard_NoAPIServices_Flag"
local CONST_FLAG_BOARD_RUNNING = "TopTimePlayedLeaderboard_Running_Flag"
local CONST_FLAG_BOARD_TAG = "TopTimePlayedLeaderboard_Board_Tag"
local CONST_FLAG_BOARD_MAIN_SC_ATTR = "TopTimePlayedLeaderboard_IsMainBoard"
local CONST_BINDABLE_EVENT_NAME = "TimePlayedLeaderboardBE-SR"
local CONST_COMMAND_UPDATE_BOARD_TIMER = "UpdateBoardTimer"
local CONST_COMMAND_UPDATE_FROM_RESULTS = "UpdateFromResults"

local dbg = {
  -- Warns if debug enabled
  warn = function(...) if CONST_DEBUG_ENABLED then warn(CONST_DEBUG_PREFIX, ...) end end,
  -- Prints if debug enabled
  log = function(...) if CONST_DEBUG_ENABLED then print(CONST_DEBUG_PREFIX, ...) end end,
  -- Warns regardless of debug configuration
  force_warn = function(...) warn(CONST_DEBUG_PREFIX, ...) end,
}

local TimePlayedClass = {}
TimePlayedClass.__index = TimePlayedClass


function TimePlayedClass.new()
  local new = {}
  setmetatable(new, TimePlayedClass)

  new._dataStoreName = str(Config.DATA_STORE, "TopTimePlayed")
  new._dataStoreStatName = str(Config.NAME_OF_STAT, "TimePlayed")
  new._scoreUpdateDelay = num(Config.SCORE_UPDATE, 1) * 60
  new._boardUpdateDelay = num(Config.LEADERBOARD_UPDATE, 1) * 60
  new._useLeaderstats = bool(Config.USE_LEADERSTATS, false)
  new._nameLeaderstats = str(Config.NAME_LEADERSTATS, "Time Played")
  new._show1stPlaceAvatar = bool(Config.SHOW_1ST_PLACE_AVATAR, true)
  new._tryAdjustAvatar = bool(Config.TRY_ADJUST_AVATAR, true)
  new._ignoredPlayers = tab(Config.IGNORED_PLAYERS, {[1]=true, [2]=true, [3]=true})

  new._datastore = nil :: OrderedDataStore?
  new._scoreBlock = script.Parent:FindFirstChild("ScoreBlock")
  new._boardModel = script.Parent
  new._boardModel:AddTag(CONST_FLAG_BOARD_TAG)

  new._internalBE = nil :: BindableEvent?
  new._externalBE = nil :: BindableEvent?

  local updateBoardTimerInst = script.Parent:FindFirstChild("UpdateBoardTimer")
  local timerInst =  updateBoardTimerInst:FindFirstChild("Timer")
  local textLabelInst = timerInst:FindFirstChild("TextLabel")
  new._updateBoardTimer = textLabelInst

  new._apiServicesEnabled = false
  new._isMainScript = false

  new._isDancingRigEnabled = false
  new._dancingRigModule = nil :: {SetRigHumanoidDescription: (userId: number, tryAdjustAvatar: boolean) -> ()}?
  
  new._usernameCache = {}
  new._thumbnailCache = {}

  new:_init()

  return new
end


function TimePlayedClass:_init()

  dbg.log("Debugging is enabled")

  self:_checkIsMainScript()

  if self._isMainScript then
    -- runs for the main board
    self._boardModel:SetAttribute(CONST_FLAG_BOARD_MAIN_SC_ATTR, true) -- sets itself as main
    self:_createInternalBindableEvent()

    -- test and load the datastore
    if not self:_checkDataStoreUp() then -- if datastore test fails must return
      self:_clearBoard()
      self._scoreBlock.NoAPIServices.Warning.Visible = true
      return
    end
    -- load datastore
    local suc, err = pcall(function ()
      self._datastore = DataStoreService:GetOrderedDataStore(self._dataStoreName)
    end)
    if not suc or self._datastore == nil then
      dbg.force_warn("Failed to load OrderedDataStore. Error:", err)
      self._scoreBlock.NoAPIServices.Warning.Visible = true
      return
    end

    -- setup leaderstats if enabled
    if self._useLeaderstats then
      local function createLeaderstats (player: Player)
        task.spawn(function ()
          if not self._datastore then return end
          local stat = Instance.new("NumberValue")
          stat.Name = self._nameLeaderstats
          dbg.log("Searching for the player's leaderstats folder")
          -- creates the leaderstats folder in case it does not find one in 8 seconds
          local leaderstatsFolder: Instance? = player:WaitForChild("leaderstats", 8)
          if not leaderstatsFolder then
            dbg.log("Could not find the player's leaderstats folder. Creating one")
            local newFolder = Instance.new("Configuration")
            newFolder.Name = "leaderstats"
            newFolder.Parent = player
            leaderstatsFolder = newFolder
          end
          stat.Parent = leaderstatsFolder
          -- retrieves and updates leaderstat value to the player's time saved in the datastore
          local success, resultOrError = pcall(function ()
            return self._datastore:GetAsync(self._dataStoreStatName .. player.UserId)
          end)
          stat.Value = not success and 0 or resultOrError
          if not success then dbg.warn("Failed to GetAsync the player's time played. Will retry later") end
        end)
      end
      for _, player: Player in pairs(PlayersService:GetPlayers()) do
        createLeaderstats(player)
      end
      PlayersService.PlayerAdded:Connect(function (player)
        createLeaderstats(player)
      end)
    end
  else
    -- runs for secondary boards
    local apiServicesEnabledFlag = ServerStorage:WaitForChild(CONST_FLAG_NO_API_SERVICES, 99)
    if not apiServicesEnabledFlag then
      dbg.warn(("Timed out waiting for ServerStorage.%s: BoolValue - assuming API services unavailable"):format(CONST_FLAG_NO_API_SERVICES))
      self._apiServicesEnabled = false
    elseif not apiServicesEnabledFlag:IsA("BoolValue") then
      dbg.warn(("ServerStorage.%s exists but is not a BoolValue - assuming API services unavailable"):format(CONST_FLAG_NO_API_SERVICES))
      self._apiServicesEnabled = false
    else
      dbg.log(("Found ServerStorage.%s: BoolValue"):format(CONST_FLAG_NO_API_SERVICES))
      self._apiServicesEnabled = apiServicesEnabledFlag.Value
    end
    if not self._apiServicesEnabled then
      self:_clearBoard()
      self._scoreBlock.NoAPIServices.Warning.Visible = true
      return
    end
    self._scoreBlock.WaitingSync.Warning.Visible = true
    self:_findExternalBindableEvent()
  end

  self:_checkDancingRigEnabled()
  self:_initScoreUpdater()
  self:_clearBoard() -- clear the board when first loading
  self:_initUpdateLoop()
end


function TimePlayedClass:_initScoreUpdater()
  -- increments players time in the datastore
  if not self._isMainScript then return end
  task.spawn(function ()
    while true do
      task.wait(self._scoreUpdateDelay)
      self:_updateScore()
    end
  end)
end


function TimePlayedClass:_initUpdateLoop()
  -- update leaderboard and leaderboard timer text
  if not self._isMainScript then return end
  task.spawn(function ()
    self:_updateBoard() -- update once
    local count = self._boardUpdateDelay
    while true do
      task.wait(1)
      count -= 1
      self:_setUpdateBoardTimer(count)
      if self._internalBE then -- replicate timer to others
        self._internalBE:Fire(CONST_COMMAND_UPDATE_BOARD_TIMER, count)
      end
      if count <= 0 then
        self:_updateBoard()
        count = self._boardUpdateDelay
      end
    end
  end)
end


function TimePlayedClass:_clearBoard ()
  for _, folder in pairs({self._scoreBlock.Leaderboard.Names, self._scoreBlock.Leaderboard.Photos, self._scoreBlock.Leaderboard.Score}) do
    for _, item in pairs(folder:GetChildren()) do
      item.Visible = false
    end
  end
end


function TimePlayedClass:_updateBoard (replicatedResults: {any}?)
  dbg.log("Updating board")

  local success, results
  if replicatedResults ~= nil then -- use results received from main board
    results = replicatedResults
  end

  if self._isMainScript then
    if not self._datastore then return end
    success, results = pcall(function()
      dbg.log("Filtering out ignored players")
      local pages = self._datastore:GetSortedAsync(false, CONST_DS_PAGE_SIZE, 1)
      local validResults = {}
      while #validResults < 10 do
        for _, v in pages:GetCurrentPage() do
          local userid = tonumber(string.split(v.key, self._dataStoreStatName)[2])
          if not self._ignoredPlayers[userid] then
            table.insert(validResults, v)
            if #validResults >= 10 then
              break
            end
          end
        end
        if #validResults >= 10 or pages.IsFinished then
          break
        end
        pages:AdvanceToNextPageAsync()
      end
      return validResults
    end)

    if not success or not results then
      dbg.warn("Failed to retrieve top 10 with most time. Error:", results)
      return
    end
  end

  local sufgui = self._scoreBlock.Leaderboard
  self._scoreBlock.Credits.Enabled = true
  self._scoreBlock.Leaderboard.Enabled = #results ~= 0
  self._scoreBlock.NoDataFound.Enabled = #results == 0
  self:_clearBoard()
  for k, v in pairs(results) do
    if not v.key or typeof(v.key) ~= "string" or not v.value or typeof(v.value) ~= "number" then
      dbg.warn("Skipping invalid datastore result key", v)
      continue
    end
    local userid = tonumber(string.split(v.key, self._dataStoreStatName)[2])
    if not userid or typeof(userid) ~= "number" then
      dbg.warn("Could not process user id from the key:", v.key)
      continue
    end
    local name = self:_getUsernameAsync(userid)
    local thumbnail = self:_getThumbnailAsync(userid)
    local score = self:_timeToString(v.value)
    self:_onPlayerScoreUpdate(userid, v.value)
    sufgui.Names["Name"..k].Visible = true
    sufgui.Score["Score"..k].Visible = true
    sufgui.Photos["Photo"..k].Visible = true
    sufgui.Names["Name"..k].Text = name
    sufgui.Score["Score"..k].Text = score
    sufgui.Photos["Photo"..k].Image = thumbnail
    if k == 1 and self._dancingRigModule then
      task.spawn(function ()
        self._dancingRigModule.SetRigHumanoidDescription(userid > 0 and userid or 1, self._tryAdjustAvatar)
      end)
    end
  end
  if self._scoreBlock:FindFirstChild("_backside") then self._scoreBlock["_backside"]:Destroy() end
  local temp = self._scoreBlock.Leaderboard:Clone()
  temp.Parent = self._scoreBlock
  temp.Name = "_backside"
  temp.Face = Enum.NormalId.Back
  self:_replicateToBoards(results)
  dbg.log("Board updated sucessfully")
end


function TimePlayedClass:_updateScore ()
  task.spawn(function ()
    for _, player: Player in pairs(PlayersService:GetPlayers()) do
      local stat = self._dataStoreStatName .. player.UserId
      if not self._datastore then return end
      local suc, newvalOrErr = pcall(function ()
        return self._datastore:IncrementAsync(stat, self._scoreUpdateDelay / 60)
      end)
      if suc then
        dbg.log("Incremented time played stat of", player, stat, "to", newvalOrErr)
      else
        dbg.warn(("Failed to increment score for %s (%s). Error: %s"):format(player.Name, stat, newvalOrErr))
      end
    end
  end)
end


function TimePlayedClass:_onPlayerScoreUpdate (userid, minutes)
  -- updates leaderstats if enabled
  if not self._useLeaderstats then return end
  if not self._isMainScript then return end
  local player = PlayersService:GetPlayerByUserId(userid)
  if not player or not player:FindFirstChild("leaderstats") then
    dbg.warn("Could not find leaderstats for player:", player)
    return
  end
  local leaderstat = player.leaderstats:FindFirstChild(self._nameLeaderstats)
  if not leaderstat or not leaderstat:IsA("NumberValue") then
    dbg.warn("Could not find leaderstat named", self._nameLeaderstats, "for player:", player)
    return
  end
  leaderstat.Value = tonumber(minutes)
end


function TimePlayedClass:_checkDancingRigEnabled()
  if self._show1stPlaceAvatar then
    local rigFolder = script.Parent:FindFirstChild("First Place Avatar")
    if not rigFolder then return end
    local rig = rigFolder:FindFirstChild("Rig")
    local rigModule = rigFolder:FindFirstChild("PlayAnimationInRig")
    if not rig or not rigModule then return end
    self._dancingRigModule = require(rigModule)
    if self._dancingRigModule then
      self._isDancingRigEnabled = true
    end
  else
    local rigFolder = script.Parent:FindFirstChild("First Place Avatar")
    if not rigFolder then return end
    rigFolder:Destroy()
  end
end


function TimePlayedClass:_checkIsMainScript()
  local timePlayedClassRunning = ServerStorage:FindFirstChild(CONST_FLAG_BOARD_RUNNING)
  if timePlayedClassRunning then
    self._isMainScript = false
    dbg.log("Initializing as (secondary)")
  else
    self._isMainScript = true
    local boolValue = Instance.new("BoolValue", ServerStorage)
    boolValue.Name = CONST_FLAG_BOARD_RUNNING
    boolValue.Value = true
    dbg.log("Initializing as (main)")
  end
end


function TimePlayedClass:_checkDataStoreUp()
  local status, message = pcall(function()
    -- This will error if current instance has no Studio API access:
    DataStoreService:GetDataStore(CONST_DS_UP_CHECK_KEY):SetAsync(CONST_DS_UP_CHECK_KEY, os.time())
  end)
  if status == false and
    (string.find(message, "404", 1, true) ~= nil or 
      string.find(message, "403", 1, true) ~= nil or -- Cannot write to DataStore from studio if API access is not enabled
      string.find(message, "must publish", 1, true) ~= nil) then -- Game must be published to access live keys
    local boolValue = Instance.new("BoolValue", ServerStorage)
    boolValue.Value = false
    boolValue.Name = CONST_FLAG_NO_API_SERVICES
    return false
  end
  self._apiServicesEnabled = true
  local boolValue = Instance.new("BoolValue", ServerStorage)
  boolValue.Value = true
  boolValue.Name = CONST_FLAG_NO_API_SERVICES
  return self._apiServicesEnabled
end


function TimePlayedClass:_getUsernameAsync(userid: number)
  if userid <= 0 then return CONST_USER_TEST_PROFILE_NAME end -- ids below 0 are studio test players
  local useridStr = tostring(userid)
  if not self._isMainScript then -- secondary board should have read-only acess to cache
    return self._usernameCache[useridStr] or CONST_USER_NAME_NOT_FOUND
  end
  if self._usernameCache[useridStr] then -- already cached, return
    return self._usernameCache[useridStr]
  end
  local success: boolean, resultOrError: string = pcall(function ()
    return PlayersService:GetNameFromUserIdAsync(userid)
  end)
  if not success then
    dbg.warn(("Error retrieving username for userid %d. Cause: %s"):format(userid, resultOrError))
    return CONST_USER_NAME_NOT_FOUND
  else
    self._usernameCache[useridStr] = resultOrError
    return self._usernameCache[useridStr]
  end
end


function TimePlayedClass:_getThumbnailAsync(userid: number)
  if userid <= 0 then return CONST_USER_TEST_PROFILE_THUMBNAIL end -- ids below 0 are studio test players
  local useridStr = tostring(userid)
  if not self._isMainScript then -- secondary board should have read-only acess to cache
    return self._thumbnailCache[useridStr] or CONST_USER_THUMBNAIL_NOT_FOUND
  end
  if self._thumbnailCache[useridStr] then -- already cached, return
    return self._thumbnailCache[useridStr]
  end
  local success: boolean, resultOrError: string = pcall(function ()
    return PlayersService:GetUserThumbnailAsync(userid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
  end)
  if not success then
    dbg.warn(("Error retrieving thumbnail for userid %d. Cause: %s"):format(userid, resultOrError))
    return CONST_USER_THUMBNAIL_NOT_FOUND
  else
    self._thumbnailCache[useridStr] = if not string.find(resultOrError, "=AvatarHeadShot&id=0") then resultOrError else CONST_USER_THUMBNAIL_NOT_FOUND
    return self._thumbnailCache[useridStr]
  end
end


function TimePlayedClass:_timeToString(_time)
  _time = _time * 60
  local days = math.floor(_time / 86400)
  local hours = math.floor(math.fmod(_time, 86400) / 3600)
  local minutes = math.floor(math.fmod(_time, 3600) / 60)
  return string.format("%02dd : %02dh : %02dm",days,hours,minutes)
end


function TimePlayedClass:_createInternalBindableEvent()
  if not self._isMainScript then return end
  self._internalBE = Instance.new("BindableEvent")
  self._internalBE.Name = CONST_BINDABLE_EVENT_NAME
  self._internalBE.Parent = self._boardModel
  dbg.log("Created internal bindable event")
end


function TimePlayedClass:_setUpdateBoardTimer(count)
  self._updateBoardTimer.Text = ("Updating the board in %d seconds"):format(count)
end


function TimePlayedClass:_findExternalBindableEvent()
  if self._isMainScript then return end
  local function findBE(instances)
    if self._externalBE then return end
    for _, o in pairs(instances) do
      if o:GetAttribute(CONST_FLAG_BOARD_MAIN_SC_ATTR) == true then
        self._externalBE = o:WaitForChild(CONST_BINDABLE_EVENT_NAME)
        self._externalBE.Event:Connect(function (command, ...)
          if command == CONST_COMMAND_UPDATE_FROM_RESULTS then
            local args = {...}
            local results = args[1]
            local cacheUsername = args[2]
            local cacheThumbnail = args[3]
            if typeof(results) ~= "table" then return end
            if typeof(cacheUsername) ~= "table" then return end
            if typeof(cacheThumbnail) ~= "table" then return end
            self._usernameCache = cacheUsername
            self._thumbnailCache = cacheThumbnail
            self._scoreBlock.WaitingSync.Warning.Visible = false
            self:_updateBoard(results)
          end
          if command == CONST_COMMAND_UPDATE_BOARD_TIMER then
            local args = {...}
            local count = args[1]
            if typeof(count) == "number" then
              self:_setUpdateBoardTimer(count)
            end
          end
        end)
        dbg.log("Found external bindable event")
        break
      end
    end
  end
  CollectionService:GetInstanceAddedSignal(CONST_FLAG_BOARD_TAG):Connect(function(...) findBE({...}) end)
  findBE(CollectionService:GetTagged(CONST_FLAG_BOARD_TAG))
end


function TimePlayedClass:_replicateToBoards(results)
  if not self._isMainScript then return end
  if not self._internalBE then return end
  self._internalBE:Fire(
    CONST_COMMAND_UPDATE_FROM_RESULTS,
    results,
    self._usernameCache,
    self._thumbnailCache
  )
end


TimePlayedClass.new()
