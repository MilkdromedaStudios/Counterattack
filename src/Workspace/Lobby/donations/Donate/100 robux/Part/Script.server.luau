
local CLICK_BLOCK = script.Parent
local ITEM_ID = 643934146

local Click = Instance.new("ClickDetector",CLICK_BLOCK)

Click.MouseClick:connect(function(p)
	game:GetService("MarketplaceService"):PromptGamePassPurchase(p,ITEM_ID)
end)
