--Made by Stickmasterluke

sp=script.Parent
midhight=16
radius=4.5		--hight
wavetime=10		--seconds
shakeradius=6
phi=.618033988
a=0
while true do
	wait()
	a=a+1
	sp.CFrame=CFrame.new(math.sin((a/(wavetime*30/phi))*math.pi)*shakeradius,midhight+math.sin((a/(wavetime*30))*math.pi)*radius,math.sin((a/(wavetime*30*phi))*math.pi)*shakeradius)
end
