local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local FootstepPlayer = {
	DefaultSFXID = "rbxassetid://78754179999047",
	ControlledCharacters = {},
}

function FootstepPlayer.PlayFootstep(player: Player, Anchor: BasePart)
	if Anchor:FindFirstChildWhichIsA("LinearVelocity") or Anchor.Parent:GetAttribute("Emoting") then return end

	--[=[
		`FootstepVolume` lets a character turn its own footsteps down.

		Added for the Creeper, whose entire identity is that you do not hear it coming — and
		read here rather than implemented in that character so anything can use it. The
		alternative was a Creeper-specific branch in the footstep system, which is exactly
		the kind of per-character special case that accumulates until nobody can change the
		system at all.

		`0` is genuinely silent. The attribute is set by the character's passive and cleared
		the moment it attacks, so "silent" is a state you can leave rather than a permanent
		advantage.
	]=]
	local Volume = Anchor.Parent:GetAttribute("FootstepVolume")
	if Volume == 0 then
		return
	end

	Sounds.PlaySound(FootstepPlayer.ControlledCharacters[player.UserId] or FootstepPlayer.DefaultSFXID, {
		MinPitch = 0.9,
		MaxPitch = 1.05,
		Volume = Volume or 0.5,
		Position = Anchor.Position - Vector3.new(0, 3, 0),
	})
end

function FootstepPlayer._SetupChar(player: Player, character: Model)
	local Humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid then
		return
	end
	local HRP = Utils.Character.GetRootPart(character)
	if not HRP then
		return
	end

	--[[
		Runs for EVERY player's character, so one bad entry used to break footsteps for
		everybody: `character.Role.Value` throws when `Role` hasn't replicated, and
		`GetCharacterModule` returns nil for a character with no module, which `require`
		then throws on.
	]]
	local Role = Utils.Character.GetRole(character)
	if Role and character:GetAttribute("CharacterName") then
		local ModuleInstance = Utils.Instance.GetCharacterModule(Role, character:GetAttribute("CharacterName"), character:GetAttribute("CharacterSkinName"), false)
		local CharModule = ModuleInstance and require(ModuleInstance)

		if CharModule and CharModule.Config.Sounds.FootstepSounds then
			FootstepPlayer.ControlledCharacters[player.UserId] = CharModule.Config.Sounds.FootstepSounds
		end
	elseif FootstepPlayer.ControlledCharacters[player.UserId] then
		FootstepPlayer.ControlledCharacters[player.UserId] = nil
	end

	local ConnectedTracks = {}
	Humanoid:FindFirstChildWhichIsA("Animator").AnimationPlayed:Connect(function(track: AnimationTrack)
		if table.find(ConnectedTracks, track) then
			return
		end
		table.insert(ConnectedTracks, track)

		track:GetMarkerReachedSignal("Footstep"):Connect(function()
			if Humanoid.FloorMaterial == Enum.Material.Air or HRP.Anchored then
				return
			end
			FootstepPlayer.PlayFootstep(player, HRP)
		end)
	end)
end

function FootstepPlayer:Init()
	Utils.Player.ObservePlayers(function(plr: Player)
		Utils.Character.ObserveCharacter(plr, function(newChar: Model)
			FootstepPlayer._SetupChar(plr, newChar)
		end)
	end)
	Players.PlayerRemoving:Connect(function(plr: Player)
		if FootstepPlayer.ControlledCharacters[plr.UserId] then
			FootstepPlayer.ControlledCharacters[plr.UserId] = nil
		end
	end)
end

return FootstepPlayer
