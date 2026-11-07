--[[
	CharacterRigFixes: fills gaps in downloaded Creator Store rigs at runtime, so the
	.rbxm files never have to be edited by hand.

	Runs once on server start, before any round spawns a character, and patches the
	TEMPLATE in ReplicatedStorage/ServerStorage.Assets.Characters, so every clone is
	already fixed. It also watches for rigs added later. Every fix only fills in what
	is missing; a rig that already has the part is left alone.

	FIXES
	1. Commander (Survivor): needs a `Grenade` part.
	   Why: Survivors/Commander.luau:17 does `Character:FindFirstChild("Grenade")` and
	   immediately sets `.Transparency` on it, then clones it as the thrown grenade
	   (expects a BasePart held by a JointInstance). A rig without one THROWS when the
	   Blindside ability is used. Added: a small hidden ball welded to the Left Arm.

	2. Commander (Survivor): needs a `Deagle` with `FirePart` holding ParticleEmitters
	   `Burst`, `Front`, `Smoke` and `Flash`.
	   Why: Survivors/Commander.luau:96 finds `Deagle`, :129-133 calls `:Emit()` on those
	   four emitters, and :141/:156 toggle the Transparency of its BaseParts. A rig
	   without it THROWS when the Justice ability fires. Added: a hidden pistol-shaped
	   model welded to the Right Arm, with the four emitters (disabled, emit-only).

	3. ANY rig wrapped in an extra Model (e.g. "Ungroup this" > Commander).
	   Why: PlayerManager._RespawnPlayer needs Humanoid + HumanoidRootPart in the ROOT of
	   the model, but many Creator Store uploads wrap the character one level deeper.
	   Fix: the inner rig is moved up to take the wrapper's place, keeping the name the
	   code looks it up by. The wrapper (and anything else in it) is discarded.

	4. ANY classic R6 body (Head, Torso, Left/Right Arm, Left/Right Leg) that is missing
	   its Humanoid, HumanoidRootPart, or the six R6 Motor6Ds.
	   Why: rigs missing a Humanoid/HumanoidRootPart are rejected at spawn and replaced by
	   the placeholder noob; StarterCharacterScripts/Animate:6-10 waits forever on
	   Torso's "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" (frozen limbs).
	   Fix: creates whatever is missing: Humanoid (RigType R6), an invisible
	   HumanoidRootPart, RootJoint, Neck and the four limb Motor6Ds at the standard R6
	   positions, keeping the model's current pose. Old welds/snaps/WeldConstraints that
	   glued a limb to the Torso are removed so the new joint can move it.
	   It also forces Humanoid.RigType to R6 on bodies that have R6 parts but were saved
	   with RigType R15 (Animate:3 returns early on anything but R6).

	Things the spawn code already repairs on its own (PlayerManager._RespawnPlayer), and so
	are NOT duplicated here: PrimaryPart (set here anyway when an HRP is created), a missing
	Animator, and anchored parts.
]]

local R6_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function hasR6Body(m: Instance): boolean
	for _, n in R6_PARTS do
		local p = m:FindFirstChild(n)
		if not (p and p:IsA("BasePart")) then
			return false
		end
	end
	return m:FindFirstChild("UpperTorso") == nil
end

local function isUsableRoot(m: Instance): boolean
	return m:FindFirstChildWhichIsA("Humanoid") ~= nil and m:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Fix 3: find a nested rig and move it up into the wrapper's place.
local function unwrap(rig: Model): Model
	if isUsableRoot(rig) or hasR6Body(rig) then
		return rig
	end
	-- Preference: a nested rig named like the character, then one that already works
	-- as-is, then any R6 body (wrappers often hold spare "Delete this" copies).
	local named, working, body
	for _, d in rig:GetDescendants() do
		if d:IsA("Model") and (isUsableRoot(d) or hasR6Body(d)) then
			if not named and d.Name:lower() == rig.Name:lower() then
				named = d
			end
			if not working and isUsableRoot(d) then
				working = d
			end
			body = body or d
		end
	end
	local d = named or working or body
	if not d then
		return rig
	end
	local name, parent = rig.Name, rig.Parent
	d.Name = name
	d.Parent = parent
	rig:Destroy()
	return d
end

local function removeJointsBetween(a: BasePart, b: BasePart)
	-- Old models keep joints anywhere in the rig, not just inside the two parts.
	local scope = a.Parent or a
	for _, j in scope:GetDescendants() do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
			local p0, p1 = (j :: any).Part0, (j :: any).Part1
			if (p0 == a and p1 == b) or (p0 == b and p1 == a) then
				j:Destroy()
			end
		end
	end
end

local function ensureMotor(parent: BasePart, name: string, part0: BasePart, part1: BasePart, jointWorld: CFrame)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Motor6D") and existing.Part0 == part0 and existing.Part1 == part1 then
		return
	end
	if existing then
		existing:Destroy()
	end
	removeJointsBetween(part0, part1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * jointWorld
	m.C1 = part1.CFrame:Inverse() * jointWorld
	m.Parent = parent
end

-- Fix 4: rebuild the R6 skeleton around an existing R6 body.
local function repairR6(rig: Model)
	if not hasR6Body(rig) then
		return
	end
	local torso = rig:FindFirstChild("Torso") :: BasePart
	local head = rig:FindFirstChild("Head") :: BasePart
	local ra = rig:FindFirstChild("Right Arm") :: BasePart
	local la = rig:FindFirstChild("Left Arm") :: BasePart
	local rl = rig:FindFirstChild("Right Leg") :: BasePart
	local ll = rig:FindFirstChild("Left Leg") :: BasePart

	local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = rig
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		humanoid.RigType = Enum.HumanoidRigType.R6
	end

	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		if hrp then
			hrp:Destroy()
		end
		local p = Instance.new("Part")
		p.Name = "HumanoidRootPart"
		p.Size = Vector3.new(torso.Size.X, torso.Size.Y, math.max(torso.Size.Z, 1))
		p.CFrame = torso.CFrame
		p.Transparency = 1
		p.CanCollide = false
		p.Anchored = false
		p.Parent = rig
		hrp = p
	end
	local root = hrp :: BasePart

	local tx, ty = torso.Size.X / 2, torso.Size.Y / 2
	local rad = math.rad
	local tc = torso.CFrame
	ensureMotor(root, "RootJoint", root, torso, tc * CFrame.Angles(rad(-90), 0, rad(180)))
	ensureMotor(torso, "Neck", torso, head, tc * CFrame.new(0, ty, 0) * CFrame.Angles(rad(-90), 0, rad(180)))
	ensureMotor(torso, "Right Shoulder", torso, ra, tc * CFrame.new(tx, ty / 2, 0) * CFrame.Angles(0, rad(90), 0))
	ensureMotor(torso, "Left Shoulder", torso, la, tc * CFrame.new(-tx, ty / 2, 0) * CFrame.Angles(0, rad(-90), 0))
	ensureMotor(torso, "Right Hip", torso, rl, tc * CFrame.new(tx / 2, -ty, 0) * CFrame.Angles(0, rad(90), 0))
	ensureMotor(torso, "Left Hip", torso, ll, tc * CFrame.new(-tx / 2, -ty, 0) * CFrame.Angles(0, rad(-90), 0))

	if rig.PrimaryPart ~= root then
		rig.PrimaryPart = root
	end
end

local function genericRepair(rig: Instance): Instance
	if not rig:IsA("Model") then
		return rig
	end
	local fixed = unwrap(rig)
	repairR6(fixed)
	return fixed
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function weldTo(part: BasePart, limb: BasePart, offset: CFrame)
	part.CFrame = limb.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "RigFixWeld"
	weld.Part0 = limb
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
end

local function hiddenPart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	return p
end

local function emitter(name: string, parent: Instance, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false -- the ability only ever calls :Emit()
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
end

local FIXES: { [string]: { [string]: (Model) -> () } } = {
	Survivor = {
		Commander = function(rig: Model)
			local leftArm = rig:FindFirstChild("Left Arm")
			local rightArm = rig:FindFirstChild("Right Arm")

			-- Fix 1: Grenade
			if not rig:FindFirstChild("Grenade") and leftArm and leftArm:IsA("BasePart") then
				local g = hiddenPart("Grenade", Vector3.new(0.5, 0.6, 0.5))
				g.Shape = Enum.PartType.Ball
				g.Color = Color3.fromRGB(70, 80, 60)
				weldTo(g, leftArm, CFrame.new(0, -1.1, 0))
				g.Parent = rig
			end

			-- Fix 2: Deagle + FirePart emitters
			local deagle = rig:FindFirstChild("Deagle")
			if not deagle and rightArm and rightArm:IsA("BasePart") then
				deagle = Instance.new("Model")
				deagle.Name = "Deagle"

				local grip = hiddenPart("Grip", Vector3.new(0.25, 0.6, 0.35))
				grip.Color = Color3.fromRGB(40, 40, 40)
				weldTo(grip, rightArm, CFrame.new(0, -1.05, -0.2))
				grip.Parent = deagle

				local barrel = hiddenPart("Barrel", Vector3.new(0.25, 0.3, 1.1))
				barrel.Color = Color3.fromRGB(150, 150, 155)
				weldTo(barrel, rightArm, CFrame.new(0, -0.8, -0.65))
				barrel.Parent = deagle

				deagle.PrimaryPart = grip
				deagle.Parent = rig
			end

			if deagle and not deagle:FindFirstChild("FirePart") and rightArm and rightArm:IsA("BasePart") then
				local fire = hiddenPart("FirePart", Vector3.new(0.2, 0.2, 0.2))
				fire:AddTag("Transparent") -- Commander.luau:156 keeps tagged parts invisible
				weldTo(fire, rightArm, CFrame.new(0, -0.8, -1.25))
				fire.Parent = deagle
			end

			local fire = deagle and deagle:FindFirstChild("FirePart")
			if fire then
				local flashColor = ColorSequence.new(Color3.fromRGB(255, 220, 120))
				if not fire:FindFirstChild("Burst") then
					emitter("Burst", fire, { Color = flashColor, Lifetime = NumberRange.new(0.05, 0.1),
						Speed = NumberRange.new(15, 25), SpreadAngle = Vector2.new(25, 25),
						Size = NumberSequence.new(0.3, 0), LightEmission = 1 })
				end
				if not fire:FindFirstChild("Front") then
					emitter("Front", fire, { Color = flashColor, Lifetime = NumberRange.new(0.05, 0.12),
						Speed = NumberRange.new(30, 45), SpreadAngle = Vector2.new(5, 5),
						Size = NumberSequence.new(0.2, 0), LightEmission = 1, EmissionDirection = Enum.NormalId.Front })
				end
				if not fire:FindFirstChild("Smoke") then
					emitter("Smoke", fire, { Color = ColorSequence.new(Color3.fromRGB(120, 120, 120)),
						Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(1, 3),
						Size = NumberSequence.new(0.4, 1.2), Transparency = NumberSequence.new(0.4, 1) })
				end
				if not fire:FindFirstChild("Flash") then
					emitter("Flash", fire, { Color = flashColor, Lifetime = NumberRange.new(0.04, 0.06),
						Speed = NumberRange.new(0, 0), Size = NumberSequence.new(1.2, 0), LightEmission = 1 })
				end
			end
		end,
	},
}

-- Hand-built rigs the owner asked to leave exactly as they are.
local LEAVE_ALONE = { Ravel = true, Scrapheap = true }

local function applyFixes(role: string, rig: Instance)
	if LEAVE_ALONE[rig.Name] or rig:GetAttribute("RigFixesApplied") then
		return
	end
	local ok, result = pcall(genericRepair, rig)
	if not ok then
		warn("[CharacterRigFixes] repairing " .. role .. "." .. rig.Name .. " failed: " .. tostring(result))
		return
	end
	rig = result
	rig:SetAttribute("RigFixesApplied", true)
	local fix = FIXES[role] and FIXES[role][rig.Name]
	if fix and rig:IsA("Model") then
		local ok, err = pcall(fix, rig)
		if not ok then
			warn("[CharacterRigFixes] fixing " .. role .. "." .. rig.Name .. " failed: " .. tostring(err))
		end
	end
end

for _, service in { ReplicatedStorage, ServerStorage } do
	local assets = service:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	if not characters then
		continue
	end
	for _, role in { "Killer", "Survivor" } do
		local folder = characters:FindFirstChild(role)
		if folder then
			for _, rig in folder:GetChildren() do
				applyFixes(role, rig)
			end
			folder.ChildAdded:Connect(function(rig)
				applyFixes(role, rig)
			end)
		end
	end
end
