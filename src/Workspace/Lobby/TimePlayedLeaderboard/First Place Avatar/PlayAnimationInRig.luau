--!nonstrict
--[[
  TimePlayedClass, RenanMSV @2024
  A ModuleScript that plays an animation on a rig.
  The rig is provided by the user through the
  "Rig" object below.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

if not script.Parent or not script.Parent.Parent then return {} end
local SettingsModule = script.Parent.Parent:FindFirstChild("Settings")
local Config = require(SettingsModule)

local function bool(v, d) if typeof(v) == "boolean" then return v end; return d end

local CONST_DEBUG_ENABLED = bool(Config.DO_DEBUG, false)
local CONST_DEBUG_PREFIX = "TopTimePlayed Board:"
local CONST_RIG_STORAGE_NAME = "TopTimePlayedLeaderboard_DancingRigStorage"
local CONST_ADJUST_METHOD_MOVE_TO = "BOUNDING_BOX_MOVE_TO"
local CONST_ADJUST_METHOD_PIVOT = "BOUNDING_BOX_PIVOT"
local CONST_ADJUST_METHOD_FOOT = "PIVOT_FOOT"

local dbg = {
  -- Warns if debug enabled
  warn = function(...) if CONST_DEBUG_ENABLED then warn(CONST_DEBUG_PREFIX, ...) end end,
  -- Prints if debug enabled
  log = function(...) if CONST_DEBUG_ENABLED then print(CONST_DEBUG_PREFIX, ...) end end,
}

local usernameCache = {}

local function getUsernameAsync(userid: number)
  if usernameCache[userid] then -- already cached, return
    return usernameCache[userid]
  end
  local success, resultOrError = pcall(function ()
    return Players:GetNameFromUserIdAsync(userid)
  end)
  if not success then
    dbg.warn(("Error retrieving username of userid %d. Cause: %s"):format(userid, resultOrError))
    return "Name not found"
  else
    usernameCache[userid] = resultOrError
    return resultOrError
  end
end

local PlayAnimationInRig = {}

PlayAnimationInRig.currentId = -1
PlayAnimationInRig.animation = script.Parent:FindFirstChild("AnimationToPlay")
PlayAnimationInRig.tag = script.Parent:FindFirstChild("FirstPlaceTag")
PlayAnimationInRig.pedestal = script.Parent:FindFirstChild("Pedestal")
PlayAnimationInRig.rig = script.Parent:FindFirstChild("Rig")
PlayAnimationInRig.rigCopy = PlayAnimationInRig.rig:Clone()
PlayAnimationInRig.rigCopyStorage = ServerStorage:FindFirstChild(CONST_RIG_STORAGE_NAME)
if not PlayAnimationInRig.rigCopyStorage then
  PlayAnimationInRig.rigCopyStorage = Instance.new("Folder")
  PlayAnimationInRig.rigCopyStorage.Name = CONST_RIG_STORAGE_NAME
  PlayAnimationInRig.rigCopyStorage.Parent = ServerStorage
end
PlayAnimationInRig.rigCopy.Parent = PlayAnimationInRig.rigCopyStorage
PlayAnimationInRig.animationTrack = nil :: AnimationTrack?


function PlayAnimationInRig.StopAnimationTrack()
  if PlayAnimationInRig.animationTrack then
    PlayAnimationInRig.animationTrack:Stop()
    PlayAnimationInRig.animationTrack = nil
  end
end


function PlayAnimationInRig.AnimateRig()
  PlayAnimationInRig.StopAnimationTrack()
  PlayAnimationInRig.humanoid = PlayAnimationInRig.rig.Humanoid
  PlayAnimationInRig.rigAnimator = PlayAnimationInRig.humanoid.Animator
  PlayAnimationInRig.animationTrack = PlayAnimationInRig.rigAnimator:LoadAnimation(PlayAnimationInRig.animation)
  if PlayAnimationInRig.animationTrack then
    PlayAnimationInRig.animationTrack.Looped = true
    PlayAnimationInRig.animationTrack:Play()
  end
end


function PlayAnimationInRig.SetRigHumanoidDescription(userId: number, tryAdjustAvatar: boolean)
  if PlayAnimationInRig.currentId == userId then
    dbg.log("First place player did not change since last check. Will skip loading the avatar")
    return
  end
  PlayAnimationInRig.currentId = userId
  PlayAnimationInRig.StopAnimationTrack()
  PlayAnimationInRig.rig:Destroy()
  PlayAnimationInRig.rig = PlayAnimationInRig.rigCopy:Clone()
  PlayAnimationInRig.rig.Parent = script.Parent
  PlayAnimationInRig.AnimateRig()
  task.spawn(function ()
    local tries = 0
    local maxTries = 3
    local retryCooldown = 5
    local skip = false
    local username
    repeat
      tries += 1
      local success, err = pcall(function ()
        local humanoidDescription = Players:GetHumanoidDescriptionFromUserId(userId)
        local humanoid: Humanoid = PlayAnimationInRig.humanoid
        humanoid:ApplyDescriptionResetAsync(humanoidDescription)
        username = getUsernameAsync(userId)
      end)
      if not success then
        dbg.warn(("Failed to get humanoid description/username of userid %d. Cause: %s"):format(userId, err))
        task.wait(retryCooldown)
        continue
      end
      skip = true
      local tagClone = PlayAnimationInRig.tag:Clone()
      tagClone.Enabled = true
      tagClone.Parent = PlayAnimationInRig.rig.Head
      PlayAnimationInRig.humanoid.DisplayName = username
      if tryAdjustAvatar then
        PlayAnimationInRig.FitCharacterToPedestal()
      end
    until tries >= maxTries or skip == true
  end)
end


function PlayAnimationInRig.FitCharacterToPedestal()
  -- Here we choose a method to adjust the rig to the pedestal
  -- 1. MoveTo [CONST_ADJUST_METHOD_MOVE_TO] - trust Roblox
  -- 2. PivotTo + AdjustByPivot [CONST_ADJUST_METHOD_PIVOT] - trust our math
  -- 3. PivotTo + LeftFootAttachment [CONST_ADJUST_METHOD_FOOT] - trust the rig's foot
  local method = CONST_ADJUST_METHOD_FOOT

  if not PlayAnimationInRig.rig.PrimaryPart then return end

  if method == CONST_ADJUST_METHOD_MOVE_TO then
    local function resetPivot(model)
      local boundsCFrame = model:GetBoundingBox()
      if model.PrimaryPart then
        model.PrimaryPart.PivotOffset = model.PrimaryPart.CFrame:ToObjectSpace(boundsCFrame)
      else
        model.WorldPivot = boundsCFrame
      end
    end
    resetPivot(PlayAnimationInRig.rig)
    -- Adjusting by trusting Roblox MoveTo which accounts for collision.
    PlayAnimationInRig.rig:MoveTo(PlayAnimationInRig.pedestal:GetPivot().Position)
  end

  if method == CONST_ADJUST_METHOD_PIVOT then
    local function setPivotToBottom(model)
      local boundsCFrame, boundsSize = model:GetBoundingBox()
      local bottomPosition = boundsCFrame.Position - boundsCFrame.UpVector * (boundsSize.Y / 2)
      local pivotCFrame = CFrame.new(bottomPosition) * boundsCFrame.Rotation
      model.PrimaryPart.PivotOffset = model.PrimaryPart.CFrame:ToObjectSpace(pivotCFrame)
    end
    setPivotToBottom(PlayAnimationInRig.rig)
    PlayAnimationInRig.rig:PivotTo(PlayAnimationInRig.pedestal:GetPivot())
  end

  if method == CONST_ADJUST_METHOD_FOOT then
    local function setPivotToFoot(model)
      local leftFoot = model:FindFirstChild("LeftFoot")
      local leftLeg = model:FindFirstChild("Left Leg")
      local footAttachment: Attachment?
      if leftFoot then -- R15
        footAttachment = leftFoot:FindFirstChild("LeftFootAttachment")
      elseif leftLeg then -- R6
        footAttachment = leftLeg:FindFirstChild("LeftFootAttachment")
      end
      if not footAttachment then return end
      local currentPivot = model:GetPivot()
      -- Keep the current pivot X/Z and rotation, move the pivot vertically to the foot.
      local pivotPosition = Vector3.new(
        currentPivot.Position.X,
        footAttachment.WorldPosition.Y,
        currentPivot.Position.Z
      )
      local pivotCFrame = CFrame.new(pivotPosition) * currentPivot.Rotation
      model.PrimaryPart.PivotOffset = model.PrimaryPart.CFrame:ToObjectSpace(pivotCFrame)
    end
    setPivotToFoot(PlayAnimationInRig.rig)
    PlayAnimationInRig.rig:PivotTo(PlayAnimationInRig.pedestal:GetPivot())
  end
end


return PlayAnimationInRig
