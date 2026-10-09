--!strict
-- Roblox Studio Script: place beside PlacementModule in ServerScriptService.
local Placement = require(script.Parent:WaitForChild("PlacementModule"))
local plate = Instance.new("Part")
plate.Anchored = true
plate.Size = Vector3.new(800, 1, 800)
plate.CFrame = CFrame.new(12, 5, -20) * CFrame.Angles(0, math.rad(35), 0)
plate.Parent = workspace

local grid = Placement.new(plate)
assert(buffer.len(grid.Buffer) == 10000)
assert(grid:CanPlace(0, 0, 1, 1))
assert(not grid:CanPlace(100, 0, 1, 1))
assert(not grid:CanPlace(99, 99, 2, 2))
assert(not grid:CanPlace(0, 0, 0, 1))
local world = grid:GridToWorld(23, 34)
local x, z = grid:WorldToGrid(world)
assert(x == 23 and z == 34, "Rotated baseplate grid conversion failed")

grid:Occupy(1, 1, 2, 2)
assert(not grid:IsCellEmpty(1, 1) and not grid:CanPlace(2, 2, 1, 1))
grid:Free(1, 1, 2, 2)
assert(grid:IsCellEmpty(1, 1))
grid:SetCell(99, 99, 255)
assert(not grid:IsCellEmpty(99, 99))
local ok = pcall(function() grid:SetCell(100, 99, 1) end)
assert(not ok, "Out-of-bounds SetCell must fail")
local bad = pcall(function() grid:Occupy(99, 99, 2, 2) end)
assert(not bad and grid:IsCellEmpty(98, 99) and not grid:IsCellEmpty(99, 99), "Invalid occupy must not partly mutate neighboring cells")
grid:Clear()
assert(grid:IsCellEmpty(99, 99))
plate:Destroy()
print("Placement grid regression PASS")
