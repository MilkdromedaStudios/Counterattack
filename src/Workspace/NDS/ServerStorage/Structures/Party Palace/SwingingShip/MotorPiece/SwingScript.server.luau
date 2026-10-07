--Made by Stickmasterluke

local sp = script.Parent


while sp and sp.Parent and sp:IsDescendantOf(game.Workspace) do
	sp.FrontParamB = .05
	for i=1,2 do
		sp.FrontParamB = sp.FrontParamB * -1
		wait(2)
	end
	sp.FrontParamB = .1
	for i=1,4 do
		sp.FrontParamB = sp.FrontParamB * -1
		wait(2)
	end
	sp.FrontParamB = .2
	for i=1,2 do
		sp.FrontParamB = sp.FrontParamB * -1
		wait(2)
	end
	sp.FrontParamB = .05
	for i=1,2 do
		sp.FrontParamB = sp.FrontParamB * -1
		wait(2)
	end
	sp.FrontParamB = 0
	wait(10)
end

