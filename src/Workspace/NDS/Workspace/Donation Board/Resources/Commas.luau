local Commas = {}

function Commas:Add(str)
	str = tostring(str)

	return #str % 3 == 0 and str:reverse():gsub("(%d%d%d)", "%1,"):reverse():sub(2)
		or str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
end

function Commas:Remove(str)
	if tonumber(str) then
		return str
	end

	for a = 1, #str do
		if string.sub(str, a, a) == "," then
			str = string.sub(str, 1, a - 1) .. string.sub(str, a + 1, #str)
		end
	end

	return str
end

return Commas
