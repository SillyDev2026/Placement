--!strict
--!native
--!optimize 2

-- Grid storage is fixed at 100 x 100 bytes for backwards compatibility.
-- Each grid reuses these methods rather than allocating closures for each cell API.
local Placement = {}
Placement.__index = Placement

local CELL_SIZE = 8
local GRID_SIZE = 100
local TOTAL = GRID_SIZE * GRID_SIZE

export type Grid = {
    Base: BasePart,
    GridSize: number,
    CellSize: number,
    Buffer: buffer,
}

local function validCell(x: number, z: number): boolean
    return x >= 0 and x < GRID_SIZE and z >= 0 and z < GRID_SIZE
        and x % 1 == 0 and z % 1 == 0
end

local function validFootprint(x: number, z: number, width: number, height: number): boolean
    return validCell(x, z)
        and width > 0 and height > 0 and width % 1 == 0 and height % 1 == 0
        and x + width <= GRID_SIZE and z + height <= GRID_SIZE
end

local function index(x: number, z: number): number
    return z * GRID_SIZE + x
end

function Placement.new(basepart: BasePart)
    assert(typeof(basepart) == "Instance" and basepart:IsA("BasePart"), "Placement.new requires a BasePart")
    return setmetatable({
        Base = basepart,
        GridSize = GRID_SIZE,
        CellSize = CELL_SIZE,
        Buffer = buffer.create(TOTAL), -- Luau buffers are already zero-initialized.
    }, Placement)
end

function Placement:WorldToGrid(pos: Vector3): (number, number)
    local relative = self.Base.CFrame:PointToObjectSpace(pos)
    local size = self.Base.Size
    local gx = math.floor((relative.X + size.X * 0.5) / self.CellSize)
    local gz = math.floor((relative.Z + size.Z * 0.5) / self.CellSize)
    return gx, gz
end

function Placement:GridToWorld(gx: number, gz: number): Vector3
    local size = self.Base.Size
    local x = -size.X * 0.5 + gx * self.CellSize + self.CellSize * 0.5
    local z = -size.Z * 0.5 + gz * self.CellSize + self.CellSize * 0.5
    return self.Base.CFrame:PointToWorldSpace(Vector3.new(x, size.Y * 0.5, z))
end

function Placement:IsCellEmpty(x: number, z: number): boolean
    if not validCell(x, z) then return false end
    return buffer.readu8(self.Buffer, index(x, z)) == 0
end

function Placement:SetCell(x: number, z: number, value: number)
    assert(validCell(x, z), "Placement:SetCell coordinates outside 100x100 grid")
    assert(type(value) == "number" and value % 1 == 0 and value >= 0 and value <= 255,
        "Placement:SetCell value must be a byte (0..255)")
    buffer.writeu8(self.Buffer, index(x, z), value)
end

function Placement:CanPlace(x: number, z: number, width: number, height: number): boolean
    if not validFootprint(x, z, width, height) then return false end
    for dx = 0, width - 1 do
        for dz = 0, height - 1 do
            if buffer.readu8(self.Buffer, index(x + dx, z + dz)) ~= 0 then
                return false
            end
        end
    end
    return true
end

function Placement:Occupy(x: number, z: number, width: number, height: number)
    assert(validFootprint(x, z, width, height), "Placement:Occupy footprint outside grid")
    for dx = 0, width - 1 do
        for dz = 0, height - 1 do
            buffer.writeu8(self.Buffer, index(x + dx, z + dz), 1)
        end
    end
end

function Placement:Free(x: number, z: number, width: number, height: number)
    assert(validFootprint(x, z, width, height), "Placement:Free footprint outside grid")
    for dx = 0, width - 1 do
        for dz = 0, height - 1 do
            buffer.writeu8(self.Buffer, index(x + dx, z + dz), 0)
        end
    end
end

function Placement:Clear()
    buffer.fill(self.Buffer, 0, 0, TOTAL)
end

return Placement
