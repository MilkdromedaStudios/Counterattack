----- || SERVICES || -----
local RunService = game:GetService("RunService")



----- || LIBRARY || -----
local Callbacks = {}; Callbacks.__index = Callbacks
local Player = game.Players.LocalPlayer



----- || CALLBACKS || -----
function Callbacks:Predict( delta: number ) : CFrame | Vector3

	local NextMove, Directions = Vector3.zero, {
		["Left"] = Vector3.new(-1, 0, 0),
		["Right"] = Vector3.new(1, 0, 0),
		["Forwards"] = Vector3.new(0, 0, -1),
		["Backwards"] = Vector3.new(0, 0, 1),
		["Up"] = Vector3.new(0, 1, 0),
		["Down"] = Vector3.new(0, -1, 0),
	}


	if game:GetService("UserInputService"):GetFocusedTextBox() then return CFrame.new(), Vector3.zero end



	--| @ Computer
	if not game:GetService("UserInputService").TouchEnabled then

		local Pressed = {
			["Left"] = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A),
			["Right"] = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D),
			["Forwards"] = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W),
			["Backwards"] = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S),
			["Up"] = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) or game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.E),
			["Down"] = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Q),
		}

		--

		for keybind, active in Pressed do
			NextMove += active and Directions[keybind] or Vector3.zero 
		end

		return CFrame.new(NextMove * (shared["Nexus Dynamics"].FlySpeed * 10) * delta), NextMove
	end


	--| @ Other
	local Root = game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = game:GetService("Players").LocalPlayer.Character:FindFirstChild("Humanoid")

	if Humanoid then

		for keybind, vector in Directions do

			local isForward = (keybind == "Forwards" or keybind == "Backwards")

			local NormalizedPos, X, Y, Z = CFrame.new(Root.CFrame.Position), (workspace.CurrentCamera.CFrame - workspace.CurrentCamera.CFrame.p):toEulerAnglesXYZ()
			local NewVector = ((NormalizedPos * CFrame.Angles(isForward and Z or X, Y, Z)) * CFrame.new(vector) - Root.CFrame.Position).Position


			if (NewVector - Humanoid.MoveDirection).Magnitude <= 1.05 and Humanoid.MoveDirection ~= Vector3.zero then
				NextMove += vector
			end
		end
	end

	return CFrame.new(NextMove * (shared["Nexus Dynamics"].FlySpeed * 10) * delta), NextMove	
end

function Callbacks:SetProperties( object: Instance, properties: {["string"] : any} ) : ()
	for name, value in properties do 
		local __suc, __error = pcall(function() object[name] = value end)

		if not __suc then
			shared["Nexus Dynamics // Cache"][__error] = game:GetService("RunService"):IsStudio() and tick() or os.time()
		end
	end
end

--

function Callbacks:Fly( collision: boolean, boost: boolean? ) : ()
	local Root = Player.Character:FindFirstChild("HumanoidRootPart")
	local Humanoid: Humanoid = Player.Character:FindFirstChild("Humanoid")

	--

	if not Root or not Humanoid then return end

	--

	local BodyPosition = Instance.new("BodyPosition", Root); self:SetProperties(BodyPosition, {
		["MaxForce"] = Vector3.one * math.huge,
		["Position"] = Root.Position + ((Root.CFrame.UpVector * 2) * (boost and 1 or 0)),
		["Name"] = "Nexus Dynamics // BodyPosition",
	})

	local BodyGyro = Instance.new("BodyGyro", Root); self:SetProperties(BodyGyro, {
		["D"] = 50,
		["P"] = collision and 200 or 1000,
		["MaxTorque"] = Vector3.one * math.huge,
		["Name"] = "Nexus Dynamics // BodyGyro",
		["CFrame"] = Root.CFrame,
	})

	--

	local connection

	if not collision then
		connection = RunService.Stepped:Connect(function()
			local char = Player.Character
			if not char then return end

			for _, v in char:GetDescendants() do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
		end)
	elseif Humanoid then
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		task.defer(function()
			if Humanoid:GetState() == Enum.HumanoidStateType.Physics then
				Humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)
			end
		end)
	end



	--

	self.Static = 0

	self.Last = {
		["Update"] = tick(),
		["Position"] = Root.Position,
	}

	self.Tilt = {
		["Max"] = 25,
		["Amount"] = 0,
		["Increment"] = 1,
	}

	--

	repeat

		local Delta, Look = tick() - self.Last.Update, (workspace.CurrentCamera.Focus.Position - workspace.CurrentCamera.CFrame.Position).Unit
		local Predict, Direction = self:Predict(Delta)

		--

		local TargetCFrame = CFrame.new(Root.Position, Root.Position + Look) * Predict
		local TargetD = (750 + (shared["Nexus Dynamics"].FlySpeed * 0.2)) --/ (not collision and 2 or 1)

		--

		if Predict.Position ~= Vector3.zero then
			self.Static, self.Tilt.Amount = 0, self.Tilt.Amount + self.Tilt.Increment
			BodyPosition.D, BodyPosition.Position = TargetD, TargetCFrame.Position
		else
			self.Static, self.Tilt.Amount = self.Static + 1, 1

			if (Root.Position - self.Last.Position).Magnitude > 6 and self.Static >= 4 then
				BodyPosition.Position = Root.Position
			end 
		end

		--


		if math.abs(self.Tilt.Amount) > self.Tilt.Max then
			self.Tilt.Amount = self.Tilt.Max
		end

		--

		if BodyPosition.D == TargetD then
			BodyGyro.CFrame = TargetCFrame * CFrame.Angles(math.rad((not collision and 0) or self.Tilt.Amount * Direction.Z), 0, 0)
		end

		self.Last = {
			["Update"] = tick(),
			["Position"] = Root.Position,
		}

		Humanoid.PlatformStand = true; task.wait()
		Humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)
	until not Humanoid or not Root or not shared["Nexus Dynamics"].Flying

	--

	BodyPosition:Destroy()
	BodyGyro:Destroy()

	if Humanoid then
		Humanoid.PlatformStand = false
		Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end

	if connection then
		connection:Disconnect()
	end
end



----- || META || -----
local Meta = setmetatable({}, Callbacks)

Meta.Last = {
	["Update"] = 0,
	["Position"] = Vector3.zero,
}

Meta.Static = 0
Meta.Tilt = {
	["Max"] = 25,
	["Amount"] = 0,
	["Increment"] = 1,
}



return Meta