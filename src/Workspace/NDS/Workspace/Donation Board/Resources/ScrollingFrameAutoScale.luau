local ScrollingFrameAutoScale = {}

local function resize(scrollingFrame: ScrollingFrame, layout: UIGridLayout | UIListLayout, axis: Enum.AutomaticSize)
	local windowSize = scrollingFrame.AbsoluteWindowSize
	local contentSize = layout.AbsoluteContentSize
	local canvasSize

	if axis == Enum.AutomaticSize.Y then
		canvasSize = UDim2.fromOffset(0, contentSize.Y)
	elseif axis == Enum.AutomaticSize.X then
		canvasSize = UDim2.fromOffset(contentSize.X, 0)
	else
		canvasSize = UDim2.fromOffset(contentSize.X, contentSize.Y)
	end

	local uiPadding = scrollingFrame:FindFirstChildOfClass("UIPadding")
	if uiPadding then
		local paddingTop = uiPadding:GetAttribute("PaddingTop")
		if not paddingTop then
			paddingTop = uiPadding.PaddingTop
			uiPadding:SetAttribute("PaddingTop", paddingTop)
			uiPadding.PaddingTop = UDim.new(0, 0)
		end
		local paddingBottom = uiPadding:GetAttribute("PaddingBottom")
		if not paddingBottom then
			paddingBottom = uiPadding.PaddingBottom
			uiPadding:SetAttribute("PaddingBottom", paddingBottom)
			uiPadding.PaddingBottom = UDim.new(0, 0)
		end

		uiPadding.PaddingTop = UDim.new(0, windowSize.Y * paddingTop.Scale)
		uiPadding.PaddingBottom = UDim.new(0, windowSize.Y * paddingBottom.Scale)
		canvasSize += UDim2.fromOffset(0, (windowSize.Y * paddingBottom.Scale) * 2)
	end

	scrollingFrame.CanvasSize = canvasSize
end

local function cellPadding(
	scrollingFrame: ScrollingFrame,
	layout: UIGridLayout | UIListLayout,
	axis: Enum.AutomaticSize
)
	local windowSize = scrollingFrame.AbsoluteWindowSize

	if layout:IsA("UIGridLayout") then
		local xScale = layout:GetAttribute("PADDING_X_SCALE")
		if not xScale then
			xScale = layout.CellPadding.X.Scale
			layout:SetAttribute("PADDING_X_SCALE", xScale)
		end
		local yScale = layout:GetAttribute("PADDING_Y_SCALE")
		if not yScale then
			yScale = layout.CellPadding.Y.Scale
			layout:SetAttribute("PADDING_Y_SCALE", yScale)
		end

		layout.CellPadding = UDim2.fromOffset(windowSize.X * xScale, windowSize.Y * yScale)
	elseif layout:IsA("UIListLayout") then
		local scale = layout:GetAttribute("PADDING_SCALE")
		if not scale then
			scale = layout.Padding.Scale
			layout:SetAttribute("PADDING_SCALE", scale)
		end

		layout.Padding.Scale = axis == Enum.AutomaticSize.X and windowSize.X * scale
			or axis == Enum.AutomaticSize.Y and windowSize.Y * scale
			or scale
	end
end

local function autoScale(scrollingFrame: ScrollingFrame, layout: UIGridLayout | UIListLayout?, axis: Enum.AutomaticSize)
	resize(scrollingFrame, layout, axis)
	cellPadding(scrollingFrame, layout, axis)
end

function ScrollingFrameAutoScale:Do(
	scrollingFrame: ScrollingFrame,
	layout: UIGridLayout | UIListLayout?,
	axis: Enum.AutomaticSize
): RBXScriptConnection
	autoScale(scrollingFrame, layout, axis)

	return layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		autoScale(scrollingFrame, layout, axis)
	end)
end

return ScrollingFrameAutoScale
