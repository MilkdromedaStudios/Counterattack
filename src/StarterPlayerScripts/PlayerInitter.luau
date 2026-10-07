local PlayerModule = script.Parent.PlayerModule

local Player = game:GetService("Players").LocalPlayer

local PlayerInitter = {
    Loaded = false,
    CurrentlyInitting = nil,
    Initting = false,
}

function PlayerInitter:Init()
    if game:GetService("RunService"):IsServer() or self.Initting then
        return
    end

    self.Initting = true

    Player:SetAttribute("BaseFOV", 70)

    for _, Module in script.Parent:GetDescendants() do
        if not (Module:IsA("ModuleScript") and Module ~= script and Module ~= PlayerModule and not Module:IsDescendantOf(PlayerModule)) then
            continue
    	end

        if Module.Name ~= "ModPanel" then
            self.CurrentlyInitting = Module.Name
        end
        debug.setmemorycategory(Module.Name)

        --[[
            Each module gets its own `pcall`.

            This loop used to run every `Init()` bare, so ONE module erroring took out
            every module after it in the iteration — and because `Loaded` below never got
            set, the loading screen hung forever waiting for an initialisation that had
            already died. From the player's seat that's "the game takes forever to load",
            and pressing Skip left them with half a game.

            `ServerScriptService.Initter` has always done this. The client just never did.
        ]]
    	local Success, Result = pcall(require, Module)
        if not Success then
            warn("[PlayerInitter] `"..Module:GetFullName().."` failed to load: "..tostring(Result))
            continue
        end

    	if type(Result) == "table" and type(Result.Init) == "function" then
            local InitSuccess, InitError = pcall(Result.Init, Result)
            if not InitSuccess then
                warn("[PlayerInitter] `"..Module:GetFullName()..":Init()` errored: "..tostring(InitError))
            end
    	end
    end

    debug.setmemorycategory("Default")

    self.Loaded = true
end

return PlayerInitter
