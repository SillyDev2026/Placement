--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Placement = require(ReplicatedStorage:WaitForChild("Placement"))
local Jolt = require(ReplicatedStorage.Modules.Networking:WaitForChild("Jolt"))

local PlacementEvent = Jolt.Server("PlacementEvent")
local CELL_SIZE = 8
local MAX_BATCH = 64

-- This demo's server-authoritative catalog mirrors the client Items list.
-- Replace these quotas with your inventory/data service before production.
local ITEMS = {
    Block = {sx = 1, sz = 1, sy = 2, count = 10},
    Machine = {sx = 2, sz = 2, sy = 4, count = 5},
    Conveyor = {sx = 1, sz = 2, sy = 1, count = 20},
}

local grids = {}
local playerParts = {}
local partsById = {}
local itemCounts = {}

local function validInteger(value: any): boolean
    return typeof(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < math.huge
end

local function validRotation(rot: any): boolean
    return validInteger(rot) and rot >= 0 and rot < 360 and rot % 90 == 0
end

local function withinBatch(value: any): boolean
    return typeof(value) == "table" and #value <= MAX_BATCH
end

local function validGrid(x: any, z: any): boolean
    return validInteger(x) and validInteger(z) and x >= 0 and z >= 0 and x < 100 and z < 100
end

local function attach(player: Player)
    local bases = workspace:WaitForChild("PlayerBases")
    local base = bases:WaitForChild(player.Name .. "_Base", 15)
    if not base or not player.Parent then return end
    local plate = base:WaitForChild("BasePlate", 15)
    if not plate or not plate:IsA("BasePart") or not player.Parent then return end
    grids[player.UserId] = Placement.new(plate)
    playerParts[player.UserId] = {}
    partsById[player.UserId] = {}
    itemCounts[player.UserId] = {}
end

Players.PlayerAdded:Connect(attach)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(attach, player) end
Players.PlayerRemoving:Connect(function(player)
    local id = player.UserId
    grids[id] = nil
    playerParts[id] = nil
    partsById[id] = nil
    itemCounts[id] = nil
end)

PlacementEvent:Connect(function(player, action, data)
    local id = player.UserId
    local grid = grids[id]
    local parts = playerParts[id]
    local byId = partsById[id]
    local counts = itemCounts[id]
    if not grid or not parts or not byId or not counts or typeof(data) ~= "table" then return end
    local base = grid.Base.Parent
    if not base then return end

    if action == "Place" then
        local gx, gz = data.x, data.z
        local sx, sz, sy, rot, name = data.sx, data.sz, data.sy, data.rot, data.itemName
        local def = if typeof(name) == "string" then ITEMS[name] else nil
        if not def or not validGrid(gx, gz) or not validRotation(rot) then return end
        if sx ~= def.sx or sz ~= def.sz or sy ~= def.sy then return end
        if (counts[name] or 0) >= def.count then return end

        local width = if rot % 180 == 0 then sx else sz
        local height = if rot % 180 == 0 then sz else sx
        if not grid:CanPlace(gx, gz, width, height) then return end
        local part = Instance.new("Part")
        part.Size = Vector3.new(sx * CELL_SIZE, sy, sz * CELL_SIZE)
        part.Position = grid:GridToWorld(gx, gz) + Vector3.new((width - 1) * CELL_SIZE / 2, sy / 2, (height - 1) * CELL_SIZE / 2)
        part.Orientation = Vector3.new(0, rot, 0)
        part.Anchored = true
        part.Name = name
        local partId = HttpService:GenerateGUID(false)
        part:SetAttribute("PartId", partId)
        part:SetAttribute("GridX", gx)
        part:SetAttribute("GridZ", gz)
        part:SetAttribute("GridWidth", width)
        part:SetAttribute("GridHeight", height)
        grid:Occupy(gx, gz, width, height)
        byId[partId] = part
        parts[#parts + 1] = part
        counts[name] = (counts[name] or 0) + 1
        part.Parent = base
        PlacementEvent:Fire(player, "Place", {part = part, partId = partId, itemName = name})

    elseif action == "Move" then
        if not withinBatch(data.parts) then return end
        local confirmed = {}
        local seen = {}
        for _, move in ipairs(data.parts) do
            if typeof(move) ~= "table" then continue end
            local partId = move.partId
            if typeof(partId) ~= "string" or seen[partId] then continue end
            seen[partId] = true
            local part = byId[partId]
            if not part or not part.Parent then continue end
            local newX, newZ, newRot = move.newGX, move.newGZ, move.rot
            if not validGrid(newX, newZ) or not validRotation(newRot) then continue end
            local oldX = part:GetAttribute("GridX")
            local oldZ = part:GetAttribute("GridZ")
            local oldW = part:GetAttribute("GridWidth")
            local oldH = part:GetAttribute("GridHeight")
            if not validGrid(oldX, oldZ) or not validInteger(oldW) or not validInteger(oldH) then continue end
            local def = ITEMS[part.Name]
            if not def then continue end
            local width = if newRot % 180 == 0 then def.sx else def.sz
            local height = if newRot % 180 == 0 then def.sz else def.sx
            if not grid:Free(oldX, oldZ, oldW, oldH) then continue end
            if grid:CanPlace(newX, newZ, width, height) then
                grid:Occupy(newX, newZ, width, height)
                part.Position = grid:GridToWorld(newX, newZ) + Vector3.new((width - 1) * CELL_SIZE / 2, part.Size.Y / 2, (height - 1) * CELL_SIZE / 2)
                part.Orientation = Vector3.new(0, newRot, 0)
                part:SetAttribute("GridX", newX)
                part:SetAttribute("GridZ", newZ)
                part:SetAttribute("GridWidth", width)
                part:SetAttribute("GridHeight", height)
                confirmed[#confirmed + 1] = {part = part, pos = part.Position, rot = newRot, partId = partId}
            else
                grid:Occupy(oldX, oldZ, oldW, oldH)
            end
        end
        if #confirmed > 0 then PlacementEvent:Fire(player, "Move", {parts = confirmed}) end

    elseif action == "Remove" then
        local ids = data.ids
        local names = data.names
        if not withinBatch(ids) and not withinBatch(names) then return end
        local selected = if withinBatch(ids) then ids else names
        local byName = not withinBatch(ids)
        local removedIds = {}
        for _, value in ipairs(selected) do
            if typeof(value) ~= "string" then continue end
            local part = byName and nil or byId[value]
            if byName then
                for _, candidate in ipairs(parts) do
                    if candidate.Name == value then part = candidate break end
                end
            end
            if part then
                local oldX = part:GetAttribute("GridX")
                local oldZ = part:GetAttribute("GridZ")
                local oldW = part:GetAttribute("GridWidth")
                local oldH = part:GetAttribute("GridHeight")
                if not validGrid(oldX, oldZ) then continue end
                grid:Free(oldX, oldZ, oldW, oldH)
                local partId = part:GetAttribute("PartId")
                if typeof(partId) == "string" then
                    byId[partId] = nil
                    removedIds[#removedIds + 1] = partId
                end
                local name = part.Name
                counts[name] = math.max(0, (counts[name] or 1) - 1)
                local index = table.find(parts, part)
                if index then table.remove(parts, index) end
                part:Destroy()
            end
        end
        if #removedIds > 0 then PlacementEvent:Fire(player, "Remove", {ids = removedIds}) end
    end
end)
