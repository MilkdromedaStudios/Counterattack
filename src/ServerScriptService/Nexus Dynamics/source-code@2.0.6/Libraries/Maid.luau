local Maid, Types = {}, require("../Types")
Maid.__index = Maid


function Maid.new()
	local self = setmetatable({}, Maid)
	self._tasks = {}
	return self
end


function Maid:GiveTask(task)
	local n = #self._tasks + 1
	self._tasks[n] = task
	
	if (typeof(task) == "thread") then
		coroutine.resume(task)
	end
	
	return function()
		if self._tasks[n] then
			self:_doTask(self._tasks[n])
			self._tasks[n] = nil
		end
	end
end


function Maid:DoCleaningByType(type)
	for i = 1, #self._tasks do 
		if typeof(self._tasks[i]) ~= type then continue end 

		self:_doTask(self._tasks[i])
		self._tasks[i] = nil
	end
end


function Maid:DoCleaning()
	for i = 1, #self._tasks do
		self:_doTask(self._tasks[i])
		self._tasks[i] = nil
	end
end


function Maid:_doTask(task)
	if not task then return end

	local taskType = typeof(task)

	if taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "Instance" then
		if task.Parent then
			task:Destroy()
		end
	elseif taskType == "function" then
		task()
	elseif taskType == "thread" then
		if coroutine.status(task) ~= "dead" then
			coroutine.close(task)
		elseif coroutine.status(task) == "running" then
			coroutine.yield(task)
			coroutine.close(task)
		end
	elseif taskType == "table" and task.Destroy then
		task:Destroy()
	elseif taskType == "userdata" and task.disconnect then
		task:disconnect()
	elseif taskType == "table" and task.Cancel then
		task:Cancel()
	end
end


return Maid :: Types.Maid