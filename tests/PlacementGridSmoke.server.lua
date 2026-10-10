--!strict
-- Studio Script beside a ModuleScript named Placement. No Jolt dependency.
local Placement = require(script.Parent:WaitForChild("Placement"))
local plate = Instance.new("Part")
plate.Name = "PlacementGridTestPlate"
plate.Size = Vector3.new(800, 1, 800)
plate.Anchored = true
plate.Parent = workspace
local grid = Placement.new(plate)
assert(grid:CanPlace(2, 3, 2, 2))
grid:Occupy(2, 3, 2, 2)
assert(not grid:CanPlace(2, 3, 1, 1))
assert(not grid:CanPlace(3, 4, 2, 2))
grid:Free(2, 3, 2, 2)
assert(grid:CanPlace(2, 3, 2, 2))
plate:Destroy()
print("Placement grid smoke regression PASS")
