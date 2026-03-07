--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService('HttpService')
local Placement = require(ReplicatedStorage:WaitForChild("Placement"))
local Jolt = require(ReplicatedStorage.Modules.Networking:WaitForChild("Jolt"))

local PlacementEvent = Jolt.Server("PlacementEvent")
local CELL_SIZE = 8

local grids = {}
local playerParts = {}

Players.PlayerAdded:Connect(function(player)
	local base = workspace.PlayerBases:WaitForChild(player.Name.."_Base")
	local plate = base:WaitForChild("BasePlate")
	grids[player.UserId] = Placement.new(plate)
	playerParts[player.UserId] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	grids[player.UserId] = nil
	playerParts[player.UserId] = nil
end)

PlacementEvent:Connect(function(player, action, data)
	local grid = grids[player.UserId]
	local parts = playerParts[player.UserId]
	if not grid then return end
	local base = workspace.PlayerBases[player.Name.."_Base"]

	if action == "Place" then
		local gx,z,sx,sz,sy,rot,itemName = data.x,data.z,data.sx,data.sz,data.sy,data.rot,data.itemName
		if grid:CanPlace(gx,z,sx,sz) then
			local part = Instance.new("Part")
			part.Size = Vector3.new(sx*CELL_SIZE, sy, sz*CELL_SIZE)
			local baseY = base.BasePlate.Position.Y + base.BasePlate.Size.Y/2
			part.Position = grid:GridToWorld(gx,z) + Vector3.new(0, sy/2, 0)
			part.Orientation = Vector3.new(0,rot,0)
			part.Anchored = true
			part.Name = itemName
			part.Parent = base
			local partId = HttpService:GenerateGUID(false)
			part:SetAttribute('PartId', partId)
			grid:Occupy(gx,z,sx,sz,part)
			table.insert(parts, part)
			
			PlacementEvent:Fire(player,"Place",{part=part, partId = partId, itemName = itemName})
		end
	elseif action == "Move" then
		local moves = data.parts or {}
		local confirmed = {}
		for _,move in ipairs(moves) do
			local part
			-- find part by PartId instead of Name
			for _,p in ipairs(parts) do
				if p:GetAttribute("PartId") == move.partId then
					part = p
					break
				end
			end

			if part then
				local oldGX, oldGZ = grid:WorldToGrid(part.Position)
				local sx, sz = math.ceil(part.Size.X / CELL_SIZE), math.ceil(part.Size.Z / CELL_SIZE)
				grid:Free(oldGX, oldGZ, sx, sz)

				if grid:CanPlace(move.newGX, move.newGZ, sx, sz) then
					local baseY = base.BasePlate.Position.Y + base.BasePlate.Size.Y/2
					part.Position = grid:GridToWorld(move.newGX, move.newGZ) + Vector3.new(0, part.Size.Y/2, 0)
					part.Orientation = Vector3.new(0, move.rot, 0)
					grid:Occupy(move.newGX, move.newGZ, sx, sz, part)
					table.insert(confirmed, {part = part, pos = part.Position, rot = move.rot, partId = move.partId})
				else
					grid:Occupy(oldGX, oldGZ, sx, sz, part) -- restore if move invalid
				end
			end
		end

		if #confirmed > 0 then
			PlacementEvent:Fire(player, "Move", {parts = confirmed})
		end
	elseif action == "Remove" then
		local names = data.names or {}
		local removedParts = {}
		for _,name in ipairs(names) do
			for idx,part in ipairs(parts) do
				if part and part.Name == name then
					local gx,gz = grid:WorldToGrid(part.Position)
					local sx,sz = math.ceil(part.Size.X/CELL_SIZE), math.ceil(part.Size.Z/CELL_SIZE)
					grid:Free(gx,gz,sx,sz)
					part:Destroy()
					table.remove(parts, idx)
					table.insert(removedParts, part)
					break
				end
			end
		end
		if #removedParts > 0 then
			PlacementEvent:Fire(player, "Remove", {parts = removedParts})
		end
	end
end)
