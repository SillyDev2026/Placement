--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlacementModule = require(ReplicatedStorage:WaitForChild("Placement"))
local Jolt = require(Modules:WaitForChild("Networking"):WaitForChild("Jolt"))
local PlacementEvent = Jolt.Client("PlacementEvent")

local CellSize = 8
local PreviewColor = Color3.fromRGB(0,255,0)
local BlockedColor = Color3.fromRGB(255,0,0)
local MovingColor = Color3.fromRGB(255,255,0)
local SelectionColor = Color3.fromRGB(1,1,0)

local selectedItem = nil
local previewPart = nil
local movingPartsPreview = nil
local currentRotation = 0
local placedParts = {}
local selectedParts = {}
local moveTargetGrid = nil
local isDragging = false
local startPos
local selectionHighlights = {}
local lastPlaced = nil

local Items = {
	{name="Block", image="rbxassetid://12345678", size=Vector3.new(8,2,8), count=10},
	{name="Machine", image="rbxassetid://87654321", size=Vector3.new(16,4,16), count=5},
	{name="Conveyor", image="rbxassetid://23456789", size=Vector3.new(8,1,16), count=20},
}
local inventory = {}
for _, item in ipairs(Items) do inventory[item.name] = item.count end

local screenGui = Instance.new("ScreenGui", PlayerGui)
screenGui.Name = "PlacementUI"

local itemFrame = Instance.new("Frame", screenGui)
itemFrame.Size = UDim2.fromScale(0.15,0.4)
itemFrame.Position = UDim2.fromScale(0.02,0.3)
itemFrame.BackgroundTransparency = 0.5
itemFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)

local uiGrid = Instance.new("UIGridLayout", itemFrame)
uiGrid.CellSize = UDim2.fromScale(0.2,0.2)
uiGrid.CellPadding = UDim2.fromScale(0.02,0.02)
uiGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiGrid.VerticalAlignment = Enum.VerticalAlignment.Top

for _, itemData in ipairs(Items) do
	local btn = Instance.new("ImageButton", itemFrame)
	btn.Size = UDim2.fromScale(1,1)
	btn.Image = itemData.image
	btn.BackgroundTransparency = 0.3
	btn.BackgroundColor3 = Color3.fromRGB(50,50,50)

	local countLabel = Instance.new("TextLabel", btn)
	countLabel.Size = UDim2.fromScale(1,0.2)
	countLabel.Position = UDim2.fromScale(0,0.8)
	countLabel.BackgroundTransparency = 0.5
	countLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
	countLabel.TextColor3 = Color3.fromRGB(255,255,255)
	countLabel.TextScaled = true
	countLabel.Text = inventory[itemData.name]

	btn.MouseButton1Click:Connect(function()
		if inventory[itemData.name] > 0 then
			selectedItem = itemData
			if previewPart then previewPart:Destroy() end
			previewPart = nil
			movingPartsPreview = nil
		end
	end)
end

local baseData = workspace:WaitForChild("PlayerBases"):WaitForChild(player.Name.."_Base")
local basePlate = baseData:WaitForChild("BasePlate")
local grid = PlacementModule.new(basePlate)

local selectionGui = Instance.new("ScreenGui", PlayerGui)
selectionGui.Name = "SelectionUI"

local selectFrame = Instance.new("Frame", selectionGui)
selectFrame.BackgroundColor3 = Color3.fromRGB(128,128,128)
selectFrame.BackgroundTransparency = 0.7
selectFrame.BorderSizePixel = 1
selectFrame.BorderColor3 = Color3.new(0,0,0)
selectFrame.Visible = false

local selectionCountLabel = Instance.new("TextLabel", selectionGui)
selectionCountLabel.Size = UDim2.fromScale(0.2,0.03)
selectionCountLabel.Position = UDim2.fromScale(0.02,0.71)
selectionCountLabel.BackgroundTransparency = 0.5
selectionCountLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
selectionCountLabel.TextColor3 = Color3.fromRGB(255,255,255)
selectionCountLabel.Text = "Selected: 0"

local buttonFrame = Instance.new("Frame", selectionGui)
buttonFrame.Size = UDim2.fromScale(0.2,0.05)
buttonFrame.Position = UDim2.fromScale(0.02,0.75)
buttonFrame.BackgroundTransparency = 0.3
buttonFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)

local removeBtn = Instance.new("TextButton", buttonFrame)
removeBtn.Size = UDim2.fromScale(0.45,1)
removeBtn.Position = UDim2.fromScale(0,0)
removeBtn.Text = "Remove"
removeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
removeBtn.TextColor3 = Color3.fromRGB(255,255,255)

local moveBtn = Instance.new("TextButton", buttonFrame)
moveBtn.Size = UDim2.fromScale(0.45,1)
moveBtn.Position = UDim2.fromScale(0.55,0)
moveBtn.Text = "Move"
moveBtn.BackgroundColor3 = Color3.fromRGB(50,200,50)
moveBtn.TextColor3 = Color3.fromRGB(255,255,255)

local function createPreview(color)
	if previewPart then previewPart:Destroy() end
	previewPart = Instance.new("Part")
	previewPart.Anchored = true
	previewPart.CanCollide = false
	previewPart.Transparency = 0.5
	previewPart.Color = color or PreviewColor
	previewPart.Parent = workspace
end

local function createMovePreview(parts)
	if movingPartsPreview then movingPartsPreview:Destroy() end
	if #parts == 0 then return end
	local minX,minY,minZ,maxX,maxY,maxZ
	for _, part in ipairs(parts) do
		local half = part.Size/2
		local pos = part.Position
		minX = minX and math.min(minX,pos.X-half.X) or pos.X-half.X
		minY = minY and math.min(minY,pos.Y-half.Y) or pos.Y-half.Y
		minZ = minZ and math.min(minZ,pos.Z-half.Z) or pos.Z-half.Z
		maxX = maxX and math.max(maxX,pos.X+half.X) or pos.X+half.X
		maxY = maxY and math.max(maxY,pos.Y+half.Y) or pos.Y+half.Y
		maxZ = maxZ and math.max(maxZ,pos.Z+half.Z) or pos.Z+half.Z
	end
	local center = Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2)
	moveTargetGrid = grid:WorldToGrid(center)

	movingPartsPreview = Instance.new("Part")
	movingPartsPreview.Anchored = true
	movingPartsPreview.CanCollide = false
	movingPartsPreview.Transparency = 0.5
	movingPartsPreview.Color = MovingColor
	movingPartsPreview.Size = Vector3.new(maxX-minX,maxY-minY,maxZ-minZ)
	movingPartsPreview.Position = center
	movingPartsPreview.Parent = workspace
end

local function clearHighlights()
	for part, highlight in pairs(selectionHighlights) do
		highlight:Destroy()
	end
	selectionHighlights = {}
end

local function highlightParts(parts)
	clearHighlights()
	for _, part in ipairs(parts) do
		local sel = Instance.new("SelectionBox")
		sel.Adornee = part
		sel.LineThickness = 0.05
		sel.Color3 = SelectionColor
		sel.SurfaceTransparency = 0.7
		sel.Parent = part
		selectionHighlights[part] = sel
	end
end

local function updateSelection()
	selectedParts = {}
	clearHighlights()

	local framePos = selectFrame.AbsolutePosition
	local frameSize = selectFrame.AbsoluteSize
	local frameRect = {
		x1 = framePos.X,
		y1 = framePos.Y,
		x2 = framePos.X + frameSize.X,
		y2 = framePos.Y + frameSize.Y
	}

	for _, part in ipairs(placedParts) do
		local corners = {}
		local size = part.Size/2
		local pos = part.Position
		corners[1] = pos + Vector3.new(size.X, size.Y, size.Z)
		corners[2] = pos + Vector3.new(-size.X, size.Y, size.Z)
		corners[3] = pos + Vector3.new(size.X, -size.Y, size.Z)
		corners[4] = pos + Vector3.new(-size.X, -size.Y, size.Z)
		corners[5] = pos + Vector3.new(size.X, size.Y, -size.Z)
		corners[6] = pos + Vector3.new(-size.X, size.Y, -size.Z)
		corners[7] = pos + Vector3.new(size.X, -size.Y, -size.Z)
		corners[8] = pos + Vector3.new(-size.X, -size.Y, -size.Z)

		for _, corner in ipairs(corners) do
			local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(corner)
			if onScreen then
				if screenPos.X >= frameRect.x1 and screenPos.X <= frameRect.x2 and
					screenPos.Y >= frameRect.y1 and screenPos.Y <= frameRect.y2 then
					table.insert(selectedParts, part)
					break
				end
			end
		end
	end

	selectionCountLabel.Text = "Selected: "..#selectedParts
	highlightParts(selectedParts)
end

UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startPos = input.Position
		isDragging = true
		selectFrame.Visible = true
		selectFrame.Position = UDim2.fromOffset(startPos.X,startPos.Y)
		selectFrame.Size = UDim2.fromOffset(0,0)
	elseif input.KeyCode == Enum.KeyCode.R and previewPart then
		currentRotation = (currentRotation + 90)%360
		previewPart.Orientation = Vector3.new(0,currentRotation,0)
	elseif input.KeyCode == Enum.KeyCode.C then
		if previewPart then previewPart:Destroy() end
		if movingPartsPreview then movingPartsPreview:Destroy() end
		selectedItem = nil
		movingPartsPreview = nil
	elseif input.KeyCode == Enum.KeyCode.F then
		if lastPlaced then
			local undoPart
			for _, part in ipairs(placedParts) do
				local gx,gz = grid:WorldToGrid(part.Position)
				if gx == lastPlaced.gridPos.X and gz == lastPlaced.gridPos.Y and part.Name == lastPlaced.itemData.name then
					undoPart = part
					break
				end
			end
			if undoPart then
				table.remove(placedParts, table.find(placedParts, undoPart))
				undoPart:Destroy()
				lastPlaced = nil
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local x = math.min(startPos.X,input.Position.X)
		local y = math.min(startPos.Y,input.Position.Y)
		selectFrame.Position = UDim2.fromOffset(x,y)
		selectFrame.Size = UDim2.fromOffset(math.abs(input.Position.X-startPos.X), math.abs(input.Position.Y-startPos.Y))
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	isDragging = false
	selectFrame.Visible = false
	updateSelection()
end)

removeBtn.MouseButton1Click:Connect(function()
	if #selectedParts == 0 then return end
	local indexes = {}
	for _, part in ipairs(selectedParts) do
		local idx = table.find(placedParts, part)
		if idx then table.insert(indexes, idx) end
	end
	if #indexes>0 then
		PlacementEvent:Fire("Remove",{indexes=indexes})
	end
	selectedParts = {}
	selectionCountLabel.Text = "Selected: 0"
	clearHighlights()
	if movingPartsPreview then movingPartsPreview:Destroy() movingPartsPreview=nil end
end)

moveBtn.MouseButton1Click:Connect(function()
	if #selectedParts == 0 then return end
	createMovePreview(selectedParts)
end)

mouse.Button1Down:Connect(function()
	if selectedItem and previewPart then
		local gx,gz = grid:WorldToGrid(previewPart.Position)
		local sx,sz = math.ceil(selectedItem.size.X/CellSize), math.ceil(selectedItem.size.Z/CellSize)
		PlacementEvent:Fire("Place",{x=gx,z=gz,sx=sx,sz=sz,sy=selectedItem.size.Y,rot=currentRotation,itemName=selectedItem.name})
		lastPlaced = {itemData = selectedItem, gridPos = Vector2.new(gx,gz), rot=currentRotation}
	end
	if movingPartsPreview and #selectedParts>0 then
		local gx,gz = moveTargetGrid.gx, moveTargetGrid.gz
		local moveData = {}
		for _, part in ipairs(selectedParts) do
			local idx = table.find(placedParts,part)
			table.insert(moveData,{index=idx,newGX=gx,newGZ=gz,sx=math.ceil(part.Size.X/CellSize),sz=math.ceil(part.Size.Z/CellSize),rot=part.Orientation.Y})
		end
		PlacementEvent:Fire("Move",{parts=moveData})
		movingPartsPreview:Destroy()
		movingPartsPreview=nil
		selectedParts = {}
		selectionCountLabel.Text="Selected: 0"
		clearHighlights()
	end
end)

PlacementEvent:Connect(function(action,data)
	if action=="Place" then
		table.insert(placedParts, data.part)
	elseif action=="Move" then
		for _,move in ipairs(data.parts) do
			local part = move.part
			if part then
				part.Position = move.pos
				part.Orientation = Vector3.new(0,move.rot,0)
			end
		end
	elseif action=="Remove" then
		for _,part in ipairs(data.parts) do
			if part then
				part:Destroy()
				table.remove(placedParts,table.find(placedParts,part))
			end
		end
		clearHighlights()
	end
end)

RunService.RenderStepped:Connect(function()
	if selectedItem then
		if not previewPart then createPreview() end
		local mousePos = mouse.Hit.Position
		local gx,gz = grid:WorldToGrid(mousePos)
		local sx,sz = math.ceil(selectedItem.size.X/CellSize), math.ceil(selectedItem.size.Z/CellSize)
		previewPart.Position = grid:GridToWorld(gx,gz)
		previewPart.Size = Vector3.new(sx*CellSize,selectedItem.size.Y,sz*CellSize)
		previewPart.Color = grid:CanPlace(gx,gz,sx,sz) and PreviewColor or BlockedColor
	end
	if movingPartsPreview then
		local mousePos = mouse.Hit.Position
		local gx,gz = grid:WorldToGrid(mousePos)
		movingPartsPreview.Position = grid:GridToWorld(gx,gz)
	end
end)
