local Player = game.Players.LocalPlayer
local MarketPlaceService = game:GetService("MarketplaceService")

local DevproductId = script.Parent.DevproductId.Value
local PurchaseButton = script.Parent

PurchaseButton.MouseButton1Click:Connect(function()
	MarketPlaceService:PromptProductPurchase(Player, DevproductId)
end)