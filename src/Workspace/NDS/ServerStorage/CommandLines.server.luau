--





--resize model
theScale = 2 function resize(thing,scale) if thing:IsA('BasePart') then local cf = thing.CFrame thing.Size = thing.Size*scale thing.CFrame = CFrame.new((cf.p*(scale-1)))*cf end if thing:IsA('DataModelMesh') then thing.Scale = thing.Scale*scale end for _,v in pairs(thing:GetChildren()) do resize(v,scale) end end resize(game.Selection:Get()[1],theScale)