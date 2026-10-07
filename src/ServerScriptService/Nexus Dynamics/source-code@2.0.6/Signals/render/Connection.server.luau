----- || CACHE || -----
local cache = {{
	["Disco"]     = Instance.new("ColorCorrectionEffect"),
	["Retro"]     = Instance.new("ColorCorrectionEffect"),
	["GrayScale"] = Instance.new("ColorCorrectionEffect"), 
	["Saturate"]  = Instance.new("ColorCorrectionEffect"), 
	["Contrast"]  = Instance.new("ColorCorrectionEffect"), 
	["Invert"]  = Instance.new("ColorCorrectionEffect"),
	["Tint"]  = Instance.new("ColorCorrectionEffect"),
}}



----- || TYPE CHECK || -----
type _dictionary = {
	From: ("RenderService"), 
	EffectType: ("StaticEffect") | ("LiveEffect"),
	EffectName: ("None") | ("GrayScale") | ("Saturate") | ("Contrast") | ("Invert") | ("Tint") | ("Disco") | ("Retro"),
	Properties: {[string]: any},
}



----- || MAIN || -----
task.spawn(function()
	
	--| @ Disco
	local Properties = { TintColor = Color3.new(1,0,0), Enabled = false, Parent = nil } for name, value in Properties do cache[1].Disco[name] = value end
	coroutine.wrap(function()
		while task.wait(1/50) do
			if not cache[1].Disco.Enabled then continue end

			--

			local H, S, V = cache[1].Disco.TintColor:ToHSV()
			H = (H >= 1 and 0 or H) * 359 + 1

			cache[1].Disco.TintColor = Color3.fromHSV(H/359, S, V)
		end
	end)()
	
	--| @ Retro
	local Properties = { TintColor = Color3.new(1, 0.533333, 0.470588), Enabled = false, Parent = nil } for name, value in Properties do cache[1].Retro[name] = value end

	--| @ GrayScale
	local Properties = { Saturation = -1, Enabled = false, Parent = nil } for name, value in Properties do cache[1].GrayScale[name] = value end

	--| @ Saturate
	local Properties = { Saturation = 1, Enabled = false, Parent = nil } for name, value in Properties do cache[1].Saturate[name] = value end

	--| @ Contrast
	local Properties = { Contrast = 1, Enabled = false, Parent = nil } for name, value in Properties do cache[1].Contrast[name] = value end

	--| @ Invert
	local Properties = { Contrast = -2, Enabled = false, Parent = nil } for name, value in Properties do cache[1].Invert[name] = value end

	--| @ Tint
	local Properties = { TintColor = Color3.new(1,1,1), Enabled = false, Parent = nil } for name, value in Properties do cache[1].Tint[name] = value end
end)

script.Parent.OnClientEvent:Connect(function( dict: _dictionary )
	if dict.From == "RenderService" and dict.EffectType == "StaticEffect" then
		if dict.EffectName == "None" then
			for _, effect in cache[1] do effect.Enabled, effect.Parent = false, nil end
			return nil
		end
		
		cache[1][dict.EffectName].Enabled, cache[1][dict.EffectName].Parent = true, game:GetService("Lighting")
		if not dict.Properties then return end
		for propertyName, propertyValue in dict.Properties do
			cache[1][dict.EffectName][propertyName] = propertyValue
		end
	elseif dict.From =="RenderService" and dict.EffectType == "UnStaticEffect" then
		if dict.EffectName == "None" then
			for _, effect in cache[1] do effect.Enabled, effect.Parent = false, nil end
			return nil
		end

		cache[1][dict.EffectName].Enabled, cache[1][dict.EffectName].Parent = false, nil
		if not dict.Properties then return end
		for propertyName, propertyValue in dict.Properties do
			cache[1][dict.EffectName][propertyName] = propertyValue
		end
	end
	
	if dict.From == "RenderService" and dict.EffectType == "LiveEffect" then
		if dict.EffectName == "None" then
			for _, effect in cache[1] do effect.Enabled, effect.Parent = false, nil end
			return nil
		end
		
		cache[1][dict.EffectName].Enabled, cache[1][dict.EffectName].Parent = true, game:GetService("Lighting")
		if not dict.Properties then return end
		for propertyName, propertyValue in dict.Properties do
			cache[1][dict.EffectName][propertyName] = propertyValue
		end
	elseif dict.From =="RenderService" and dict.EffectType == "UnLiveEffect" then
		if dict.EffectName == "None" then
			for _, effect in cache[1] do effect.Enabled, effect.Parent = false, nil end
			return nil
		end

		cache[1][dict.EffectName].Enabled, cache[1][dict.EffectName].Parent = false, nil
		if not dict.Properties then return end
		for propertyName, propertyValue in dict.Properties do
			cache[1][dict.EffectName][propertyName] = propertyValue
		end
	end
end)