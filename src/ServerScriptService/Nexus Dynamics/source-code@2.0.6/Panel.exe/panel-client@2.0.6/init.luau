xpcall(
	function()
		require(script.Connector)
		require(script.Panel)
	end,
	
	function(err)
		task.wait(1)
		error(err)
	end
)


return true