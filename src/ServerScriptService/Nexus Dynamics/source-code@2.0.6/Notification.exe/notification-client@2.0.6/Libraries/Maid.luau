----- || TYPE CHECK || -----
type tweenTypeSingular = ( instance: Instance, { tweenInfo: TweenInfo, goal: any } ) -> ( field: any ) -> TweenBase
type tweenTypePlural = ( instances: { [Instance]: { tweenInfo: TweenInfo, goal: any } } ) -> ( field: any ) -> TweenBase

export type tweenType = tweenTypeSingular & tweenTypePlural



----- || MAIN || -----
cache={{}}; return {
	
	signal = function( name: string ) 

		local internal = { Instance.new("BindableEvent"), Instance.new("BindableFunction") }	
		local methods = {__index={}} 

		--

		function methods.__index:Connect( func: any ) : RBXScriptSignal
			return internal[1].Event:Connect(func)
		end

		function methods.__index:Once(  func: any  ) : RBXScriptSignal
			return internal[1].Event:Once(func)
		end

		function methods.__index.OnInvoke( func: any ) : ...any
			internal[2].OnInvoke = func	
		end

		--

		function methods.__index:Fire( ... ) : ()
			return internal[1]:Fire(...)
		end

		function methods.__index:Invoke( ... ) : ...any
			return internal[2]:Invoke(...)
		end

		--

		function methods.__index:Destroy() : ()
			internal[1]:Destroy()
			internal[2]:Destroy()

			self = nil
			return nil
		end

		--

		return setmetatable({}, methods)
	end,

	tween = function( instance: Instance | any )
		if not cache[1] then cache[1] = {} end

		--

		if typeof(instance) == "table" then

			local tween = {}

			for instance, array in instance do
				if cache[1][instance] then cache[1][instance]:Pause() end
				cache[1][instance] = game:GetService("TweenService"):Create(instance, array[1], array[2])	
				cache[1][instance]:Play()

				tween[instance] = cache[1][instance] 
			end

			return tween
		end

		if typeof(instance) == "Instance" then

			return function( field: any )
				if cache[1][instance] then cache[1][instance]:Pause() end
				cache[1][instance] = game:GetService("TweenService"):Create(instance, field[1], field[2])	
				cache[1][instance]:Play()

				return cache[1]
			end	
		end
	end :: tweenType
}