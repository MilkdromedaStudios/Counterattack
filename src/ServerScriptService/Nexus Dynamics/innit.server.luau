repeat task.wait() until game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0")[1]

game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0")[1].Parent = game:GetService("ServerScriptService")
require(script.Parent:FindFirstChild("PackageLink", true).Parent)