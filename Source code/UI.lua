local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local body = script.Parent.Main.Body
local genButton = body.Generate
local teleportButton = body.Teleport
local popLbl = script.Parent.Popup

local debounce = false -- Debouncing the popup function

local options = { -- List of options and their UI object
	["xLength"] = body.XLength,
	["yLength"] = body.YLength,
	["minHeight"] = body.MinHeight,
	["maxHeight"] = body.MaxHeight,
	["tileSize"] = body.TileSize,
	["seed"] = body.Seed,
	["biome"] = body.Biome,
	["treeMultiplier"] = body.TreeMultiplier
}

function PopUp(field, state)
	if debounce and not state then return end -- If the function is already running and requests to close then return
	debounce = true
	
	if state then
		popLbl.Text = field:GetAttribute("Description")
		popLbl.Position = UDim2.new(0, field.AbsolutePosition.X + 205, 0 ,field.AbsolutePosition.Y)
	else
		popLbl.Text = ""
	end
	
	debounce = false
end

genButton.MouseButton1Click:Connect(function() -- When the generation button is pressed
	local completeOptions = {}
	for i,v in pairs(options) do -- Gather all options
		completeOptions[i] = v.InputBox.Text
	end
	print(completeOptions) -- Print options to output

	RS.GenerateTerrain:FireServer(completeOptions) -- Send options to generation script
end)

teleportButton.MouseButton1Click:Connect(function() -- When the generation button is pressed
	local character = player.Character:MoveTo(workspace.SpawnLocation.Position + Vector3.new(0,5,0))
end)

for i,v in pairs(body:GetChildren()) do -- Setup the popup
	if v.ClassName == "TextLabel" then
		v.MouseEnter:Connect(function(x,y)
			PopUp(v, true)
		end)
		v.MouseLeave:Connect(function(x,y)
			PopUp(v, false)
		end)
	end
end
