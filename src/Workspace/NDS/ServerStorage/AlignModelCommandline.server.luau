--Stickmasterluke



--Align a model to a specific part.
--Create a part in workspace. Select it, then a part in the model that you want to get aligned with it exactly. Run code. WIll breakjoints


s=game.Selection:Get() s[2].Parent:BreakJoints() localcf=s[2].CFrame function recurse(a) if a:IsA("BasePart") then a.CFrame=s[1].CFrame*(s[2].CFrame:toObjectSpace(a.CFrame)) end for _,v in pairs(a:GetChildren()) do recurse(v) end end recurse(s[2].Parent)





