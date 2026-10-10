--!nonstrict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Placement = require(ReplicatedStorage:WaitForChild("Placement"))
local Jolt = require(ReplicatedStorage.Modules.Networking:WaitForChild("Jolt"))

local PlacementEvent = Jolt.Server("PlacementEvent")
local CELL_SIZE = 8
local MAX_BATCH = 32
local MIN_REQUEST_INTERVAL = 0.08
local LIMITS = {Block = 10, Machine = 5, Conveyor = 20}
local ITEM_SIZE = {
    Block = Vector3.new(8, 2, 8),
    Machine = Vector3.new(16, 4, 16),
    Conveyor = Vector3.new(8, 1, 16),
}

local grids = {}
local baseplates = {}
local playerParts = {}
local lastRequest = {}
local counts = {}

local function integer(value): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge and value % 1 == 0
end

local function rotationValid(value): boolean
    return integer(value) and (value == 0 or value == 90 or value == 180 or value == 270)
end

local function rectangleValid(x, z, sx, sz): boolean
    return integer(x) and integer(z) and integer(sx) and integer(sz)
        and x >= 0 and z >= 0 and sx > 0 and sz > 0
        and x + sx <= 100 and z + sz <= 100
end

local function worldCenter(base, gx, gz, width, depth, height, rotation)
    local halfX = -base.Size.X * 0.5 + (gx + width * 0.5) * CELL_SIZE
    local halfZ = -base.Size.Z * 0.5 + (gz + depth * 0.5) * CELL_SIZE
    return base.CFrame * CFrame.new(halfX, base.Size.Y * 0.5 + height * 0.5, halfZ)
        * CFrame.Angles(0, math.rad(rotation), 0)
end

local function enoughRoom(grid, x, z, sx, sz): boolean
    return rectangleValid(x, z, sx, sz) and grid:CanPlace(x, z, sx, sz)
end

local function canProcess(player): boolean
    if player.Parent ~= Players then return false end
    local now = os.clock()
    local previous = lastRequest[player.UserId] or -math.huge
    if now - previous < MIN_REQUEST_INTERVAL then return false end
    lastRequest[player.UserId] = now
    return true
end

local function setup(player)
    local container = workspace:WaitForChild("PlayerBases", 10)
    if not container then return end
    local base = container:WaitForChild(player.Name .. "_Base", 10)
    if not base or player.Parent ~= Players then return end
    local plate = base:FindFirstChild("BasePlate")
    if not plate or not plate:IsA("BasePart") then return end
    grids[player.UserId] = Placement.new(plate)
    baseplates[player.UserId] = plate
    playerParts[player.UserId] = {}
    counts[player.UserId] = {}
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(setup, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setup, player)
end

Players.PlayerRemoving:Connect(function(player)
    local id = player.UserId
    grids[id] = nil
    baseplates[id] = nil
    playerParts[id] = nil
    lastRequest[id] = nil
    counts[id] = nil
end)

PlacementEvent:Connect(function(player, action, data)
    if not canProcess(player) or type(action) ~= "string" or type(data) ~= "table" then return end
    local userId = player.UserId
    local grid = grids[userId]
    local plate = baseplates[userId]
    local parts = playerParts[userId]
    local used = counts[userId]
    if not grid or not plate or not parts or not used then return end
    local base = plate.Parent
    if not base or base.Name ~= player.Name .. "_Base" or not base:IsDescendantOf(workspace) then return end

    if action == "Place" then
        local name = data.itemName
        local expected = ITEM_SIZE[name]
        if not expected or (used[name] or 0) >= LIMITS[name] then return end
        local x, z, sx, sz = data.x, data.z, data.sx, data.sz
        local rotation = data.rot
        local height = data.sy
        if not rotationValid(rotation) or not integer(height) then return end
        if height ~= expected.Y or sx ~= expected.X / CELL_SIZE or sz ~= expected.Z / CELL_SIZE then return end
        local width = if rotation % 180 == 0 then sx else sz
        local depth = if rotation % 180 == 0 then sz else sx
        if not enoughRoom(grid, x, z, width, depth) then return end

        local part = Instance.new("Part")
        part.Size = expected
        part.CFrame = worldCenter(plate, x, z, width, depth, height, rotation)
        part.Anchored = true
        part.CanCollide = true
        part.Name = name
        local partId = HttpService:GenerateGUID(false)
        part:SetAttribute("PartId", partId)
        part:SetAttribute("GridX", x)
        part:SetAttribute("GridZ", z)
        part:SetAttribute("GridWidth", width)
        part:SetAttribute("GridDepth", depth)
        part:SetAttribute("Rotation", rotation)
        grid:Occupy(x, z, width, depth)
        part.Parent = base
        parts[partId] = part
        used[name] = (used[name] or 0) + 1
        PlacementEvent:Fire(player, "Place", {part = part, partId = partId, itemName = name})
    elseif action == "Move" then
        local moves = data.parts
        if type(moves) ~= "table" or #moves > MAX_BATCH then return end
        local confirmed = {}
        local seen = {}
        for _, move in ipairs(moves) do
            if type(move) ~= "table" then continue end
            local id = move.partId
            local part = if type(id) == "string" then parts[id] else nil
            local rotation = move.rot
            if not part or seen[id] or not rotationValid(rotation) then continue end
            seen[id] = true
            if part.Parent ~= base then continue end
            local oldX = part:GetAttribute("GridX")
            local oldZ = part:GetAttribute("GridZ")
            local oldWidth = part:GetAttribute("GridWidth")
            local oldDepth = part:GetAttribute("GridDepth")
            if not rectangleValid(oldX, oldZ, oldWidth, oldDepth) then continue end
            local rawWidth = math.floor(part.Size.X / CELL_SIZE)
            local rawDepth = math.floor(part.Size.Z / CELL_SIZE)
            local width = if rotation % 180 == 0 then rawWidth else rawDepth
            local depth = if rotation % 180 == 0 then rawDepth else rawWidth
            local newX, newZ = move.newGX, move.newGZ
            if not rectangleValid(newX, newZ, width, depth) then continue end

            grid:Free(oldX, oldZ, oldWidth, oldDepth)
            if grid:CanPlace(newX, newZ, width, depth) then
                grid:Occupy(newX, newZ, width, depth)
                part.CFrame = worldCenter(plate, newX, newZ, width, depth, part.Size.Y, rotation)
                part:SetAttribute("GridX", newX)
                part:SetAttribute("GridZ", newZ)
                part:SetAttribute("GridWidth", width)
                part:SetAttribute("GridDepth", depth)
                part:SetAttribute("Rotation", rotation)
                table.insert(confirmed, {part = part, pos = part.Position, rot = rotation, partId = id})
            else
                grid:Occupy(oldX, oldZ, oldWidth, oldDepth)
            end
        end
        if #confirmed > 0 then PlacementEvent:Fire(player, "Move", {parts = confirmed}) end
    elseif action == "Remove" then
        local ids = data.partIds
        local names = data.names
        if type(ids) ~= "table" and type(names) ~= "table" then return end
        local targets = if type(ids) == "table" then ids else names
        if #targets > MAX_BATCH then return end
        local removedParts = {}
        local seen = {}
        for _, candidate in ipairs(targets) do
            if type(candidate) ~= "string" or seen[candidate] then continue end
            seen[candidate] = true
            local id = candidate
            local part = if type(ids) == "table" then parts[id] else nil
            if not part and type(ids) ~= "table" then
                for ownedId, ownedPart in pairs(parts) do
                    if ownedPart.Name == candidate then
                        id = ownedId
                        part = ownedPart
                        break
                    end
                end
            end
            if not part or part.Parent ~= base then continue end
            local x = part:GetAttribute("GridX")
            local z = part:GetAttribute("GridZ")
            local width = part:GetAttribute("GridWidth")
            local depth = part:GetAttribute("GridDepth")
            if not rectangleValid(x, z, width, depth) then continue end
            grid:Free(x, z, width, depth)
            parts[id] = nil
            used[part.Name] = math.max(0, (used[part.Name] or 1) - 1)
            table.insert(removedParts, part)
        end
        if #removedParts > 0 then
            PlacementEvent:Fire(player, "Remove", {parts = removedParts})
            for _, part in ipairs(removedParts) do part:Destroy() end
        end
    end
end)
