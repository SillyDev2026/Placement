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
local Jolt = require(Modules.Networking:WaitForChild("Jolt"))
local PlacementEvent = Jolt.Client("PlacementEvent")

local CellSize = 8
local PreviewColor = Color3.fromRGB(0,255,0)
local BlockedColor = Color3.fromRGB(255,0,0)
local MovingColor = Color3.fromRGB(255,255,0)
local SelectionColor = Color3.fromRGB(255,255,0)

local selectedItem
local previewPart
local movingPartsPreview = {}
local moveOffsets = {}
local moveTargetGrid = {}
local currentRotation = 0
local placedParts = {}
local selectedParts = {}
local isDragging = false
local startPos
local selectionHighlights = {}

local Items = {
	{name="Block", image="rbxassetid://12345678", size=Vector3.new(8,2,8), count=10},
	{name="Machine", image="rbxassetid://87654321", size=Vector3.new(16,4,16), count=5},
	{name="Conveyor", image="rbxassetid://23456789", size=Vector3.new(8,1,16), count=20},
}
local inventory = {}
for _,item in ipairs(Items) do
	inventory[item.name] = item.count
end

-- UI
local screenGui = Instance.new("ScreenGui", PlayerGui)
screenGui.Name = "PlacementUI"

local itemFrame = Instance.new("Frame", screenGui)
itemFrame.Size = UDim2.fromScale(0.15,0.4)
itemFrame.Position = UDim2.fromScale(0.02,0.3)
itemFrame.BackgroundTransparency = 0.5
itemFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)

local layout = Instance.new("UIGridLayout", itemFrame)
layout.CellSize = UDim2.fromScale(0.2,0.2)
layout.CellPadding = UDim2.fromScale(0.02,0.02)

for _,itemData in ipairs(Items) do
	local btn = Instance.new("ImageButton", itemFrame)
	btn.Image = itemData.image
	btn.BackgroundTransparency = 0.3
	btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
	local countLabel = Instance.new("TextLabel", btn)
	countLabel.Size = UDim2.fromScale(1,0.2)
	countLabel.Position = UDim2.fromScale(0,0.8)
	countLabel.BackgroundTransparency = 0.5
	countLabel.TextScaled = true
	countLabel.TextColor3 = Color3.new(1,1,1)
	countLabel.Text = inventory[itemData.name]
	btn.MouseButton1Click:Connect(function()
		if inventory[itemData.name] <= 0 then return end
		selectedItem = itemData
		if previewPart then previewPart:Destroy() previewPart=nil end
		for _,p in pairs(movingPartsPreview) do if p then p:Destroy() end end
		movingPartsPreview = {}
	end)
end

local baseData = workspace:WaitForChild("PlayerBases"):WaitForChild(player.Name.."_Base")
local basePlate = baseData:WaitForChild("BasePlate")
local grid = PlacementModule.new(basePlate)

local selectionGui = Instance.new("ScreenGui", PlayerGui)
local selectFrame = Instance.new("Frame", selectionGui)
selectFrame.BackgroundColor3 = Color3.fromRGB(128,128,128)
selectFrame.BackgroundTransparency = 0.7
selectFrame.BorderSizePixel = 1
selectFrame.Visible = false

local selectionCountLabel = Instance.new("TextLabel", selectionGui)
selectionCountLabel.Size = UDim2.fromScale(0.2,0.03)
selectionCountLabel.Position = UDim2.fromScale(0.02,0.71)
selectionCountLabel.BackgroundTransparency = 0.5
selectionCountLabel.TextColor3 = Color3.new(1,1,1)
selectionCountLabel.Text = "Selected: 0"

local buttonFrame = Instance.new("Frame", selectionGui)
buttonFrame.Size = UDim2.fromScale(0.2,0.05)
buttonFrame.Position = UDim2.fromScale(0.02,0.75)
buttonFrame.BackgroundTransparency = 0.3

local removeBtn = Instance.new("TextButton", buttonFrame)
removeBtn.Size = UDim2.fromScale(0.45,1)
removeBtn.Text = "Remove"
removeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)

local moveBtn = Instance.new("TextButton", buttonFrame)
moveBtn.Size = UDim2.fromScale(0.45,1)
moveBtn.Position = UDim2.fromScale(0.55,0)
moveBtn.Text = "Move"
moveBtn.BackgroundColor3 = Color3.fromRGB(50,200,50)

local function clearHighlights()
	for _,h in pairs(selectionHighlights) do
		h:Destroy()
	end
	selectionHighlights = {}
end

local function highlightParts(parts)
	clearHighlights()
	for _,part in ipairs(parts) do
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
	local x1,y1 = framePos.X, framePos.Y
	local x2,y2 = x1 + frameSize.X, y1 + frameSize.Y
	for _,part in ipairs(baseData:GetChildren()) do
		if part:IsA("BasePart") then
			local screenPos, visible = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
			if visible and screenPos.X >= x1 and screenPos.X <= x2 and screenPos.Y >= y1 and screenPos.Y <= y2 then
				table.insert(selectedParts, part)
			end
		end
	end
	selectionCountLabel.Text = "Selected: "..#selectedParts
	highlightParts(selectedParts)
end

local function createMovePreview(parts)
	for _,p in pairs(movingPartsPreview) do if p then p:Destroy() end end
	movingPartsPreview = {}
	moveOffsets = {}
	local baseGX, baseGZ = grid:WorldToGrid(parts[1].Position)
	for _,part in ipairs(parts) do
		local pgx, pgz = grid:WorldToGrid(part.Position)
		moveOffsets[part] = {x=pgx-baseGX, z=pgz-baseGZ}
		local preview = Instance.new("Part")
		preview.Size = part.Size
		preview.Anchored = true
		preview.CanCollide = false
		preview.Transparency = 0.5
		preview.Color = MovingColor
		preview.Parent = workspace
		movingPartsPreview[part] = preview
	end
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startPos = input.Position
		isDragging = true
		selectFrame.Visible = true
		selectFrame.Position = UDim2.fromOffset(startPos.X, startPos.Y)
		selectFrame.Size = UDim2.fromOffset(0,0)
	end
	if input.KeyCode == Enum.KeyCode.R and previewPart then
		currentRotation = (currentRotation + 90) % 360
	end
	if input.KeyCode == Enum.KeyCode.C then
		selectedItem=nil
		if previewPart then previewPart:Destroy() previewPart=nil end
		for _,p in pairs(movingPartsPreview) do if p then p:Destroy() end end
		movingPartsPreview = {}
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
	if isDragging then
		isDragging = false
		selectFrame.Visible = false
		updateSelection()
	end
end)

removeBtn.MouseButton1Click:Connect(function()
	if #selectedParts == 0 then return end
    local partIds = {}
    for _, part in ipairs(selectedParts) do
        if part then
            local id = part:GetAttribute("PartId")
            if type(id) == "string" then table.insert(partIds, id) end
        end
    end
    if #partIds > 0 then PlacementEvent:Fire("Remove", {partIds = partIds}) end
	selectedParts = {}
	selectionCountLabel.Text = "Selected: 0"
	clearHighlights()
end)

moveBtn.MouseButton1Click:Connect(function()
	if #selectedParts == 0 then return end
	createMovePreview(selectedParts)
end)
mouse.Button1Down:Connect(function()
	if selectedItem and previewPart then
		local gx,gz = grid:WorldToGrid(previewPart.Position)
		local sx,sz = math.ceil(selectedItem.size.X/CellSize), math.ceil(selectedItem.size.Z/CellSize)
		PlacementEvent:Fire("Place",{
			x=gx,z=gz,sx=sx,sz=sz,sy=selectedItem.size.Y,
			rot=currentRotation,itemName=selectedItem.name
		})
	end
	if next(movingPartsPreview) then
		local gx,gz = moveTargetGrid.gx, moveTargetGrid.gz
		local moveData = {}
		for _,part in ipairs(selectedParts) do
			local off = moveOffsets[part]
			local partId = part:GetAttribute("PartId")
			if partId then
				table.insert(moveData,{
					partId=partId,
					newGX=gx+off.x,
					newGZ=gz+off.z,
					sx=math.ceil(part.Size.X/CellSize),
					sz=math.ceil(part.Size.Z/CellSize),
					rot=part.Orientation.Y
				})
			end
		end
		PlacementEvent:Fire("Move",{parts=moveData})

		for _,p in pairs(movingPartsPreview) do if p then p:Destroy() end end
		movingPartsPreview = {}
		selectedParts = {}
		selectionCountLabel.Text = "Selected: 0"
		clearHighlights()
	end
end)

PlacementEvent:Connect(function(action,data)
	if action=="Place" and data.part and data.partId then
		data.part:SetAttribute("PartId",data.partId)
		table.insert(placedParts,data.part)
	elseif action=="Move" then
		for _,m in ipairs(data.parts) do
			for _,part in ipairs(placedParts) do
				if part:GetAttribute("PartId")==m.partId then
					part.Position = m.pos
					part.Orientation = Vector3.new(0,m.rot,0)
					break
				end
			end
		end
    elseif action == "Remove" then
        local removedIds = {}
        for _, id in ipairs(data.partIds or {}) do removedIds[id] = true end
        for index = #placedParts, 1, -1 do
            local part = placedParts[index]
            local id = if part then part:GetAttribute("PartId") else nil
            if id and removedIds[id] then table.remove(placedParts, index) end
        end
        -- The server owns Instances and destroys them; clients only update
        -- their local selection/preview lists.
    end
end)

RunService.RenderStepped:Connect(function()
	local mousePos = mouse.Hit.Position
	if selectedItem then
		if not previewPart then
			previewPart = Instance.new("Part")
			previewPart.Anchored = true
			previewPart.CanCollide = false
			previewPart.Transparency = 0.5
			previewPart.Parent = workspace
		end
		local gx,gz = grid:WorldToGrid(mousePos)
		local sx,sz = math.ceil(selectedItem.size.X/CellSize), math.ceil(selectedItem.size.Z/CellSize)
		previewPart.Size = Vector3.new(sx*CellSize, selectedItem.size.Y, sz*CellSize)
		local baseY = basePlate.Position.Y + basePlate.Size.Y/2
		previewPart.Position = grid:GridToWorld(gx,gz) + Vector3.new(0, selectedItem.size.Y/2 + (baseY - basePlate.Position.Y), 0)
		previewPart.Color = grid:CanPlace(gx,gz,sx,sz) and PreviewColor or BlockedColor
	end
	if next(movingPartsPreview) then
		local gx,gz = grid:WorldToGrid(mousePos)
		moveTargetGrid = {gx=gx, gz=gz}
		for part, preview in pairs(movingPartsPreview) do
			local off = moveOffsets[part]
			preview.Position = grid:GridToWorld(gx+off.x, gz+off.z) + Vector3.new(0, preview.Size.Y/2, 0)
		end
	end
end)
