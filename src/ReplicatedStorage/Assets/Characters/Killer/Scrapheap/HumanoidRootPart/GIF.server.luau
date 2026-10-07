local face1 = script.Parent.Face1
local face2 = script.Parent.Face2
local face3 = script.Parent.Face3
local face4 = script.Parent.Face4
local face5 = script.Parent.Face5

while true do
wait(math.random(0.95,0.95))
face1.Enabled = true
face5.Enabled = false
wait(math.random(0.95,0.95))
face1.Enabled = false
face2.Enabled = true
wait(math.random(0.95,0.95))
face2.Enabled = false
face3.Enabled = true
wait(math.random(0.95,0.95))
face4.Enabled = true
face3.Enabled = false
wait(math.random(0.95,0.95))
face5.Enabled = true
face4.Enabled = false
end