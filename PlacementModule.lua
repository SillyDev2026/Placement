--!native
--!optimize 2

local Placement = {}
local CellSize = 8
local GridSize = 100
local Total = GridSize * GridSize

local function validInteger(value: any): boolean
    return typeof(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < math.huge
end

local function validCell(x: number, z: number): boolean
    return validInteger(x) and validInteger(z) and x >= 0 and z >= 0 and x < GridSize and z < GridSize
end

local function validRegion(x: number, z: number, w: number, h: number): boolean
    return validCell(x, z) and validInteger(w) and validInteger(h)
        and w >= 1 and h >= 1 and x + w <= GridSize and z + h <= GridSize
end

local function index(x: number, z: number): number
    return z * GridSize + x
end

function Placement.new(basepart: BasePart)
    assert(typeof(basepart) == "Instance" and basepart:IsA("BasePart"), "BasePart required")
    local self = {}
    self.Base = basepart
    self.GridSize = GridSize
    self.CellSize = CellSize
    -- buffer.create initializes contents to zero. No 10,000-iteration clearing loop.
    self.Buffer = buffer.create(Total)

    function self:WorldToGrid(pos: Vector3)
        local relative = pos - self.Base.Position
        local gx = math.floor((relative.X + self.Base.Size.X / 2) / CellSize)
        local gz = math.floor((relative.Z + self.Base.Size.Z / 2) / CellSize)
        return gx, gz
    end

    function self:GridToWorld(gx: number, gz: number)
        local basePos = self.Base.Position
        local baseSize = self.Base.Size
        local x = basePos.X - baseSize.X / 2 + gx * CellSize + CellSize / 2
        local z = basePos.Z - baseSize.Z / 2 + gz * CellSize + CellSize / 2
        local y = basePos.Y + baseSize.Y / 2
        return Vector3.new(x, y, z)
    end

    function self:IsCellEmpty(x: number, z: number): boolean
        return validCell(x, z) and buffer.readu8(self.Buffer, index(x, z)) == 0
    end

    function self:SetCell(x: number, z: number, value: number): boolean
        if not validCell(x, z) or (value ~= 0 and value ~= 1) then return false end
        buffer.writeu8(self.Buffer, index(x, z), value)
        return true
    end

    function self:CanPlace(x: number, z: number, w: number, h: number): boolean
        if not validRegion(x, z, w, h) then return false end
        for ix = 0, w - 1 do
            for iz = 0, h - 1 do
                if buffer.readu8(self.Buffer, index(x + ix, z + iz)) ~= 0 then return false end
            end
        end
        return true
    end

    function self:Occupy(x: number, z: number, w: number, h: number): boolean
        if not validRegion(x, z, w, h) then return false end
        for ix = 0, w - 1 do
            for iz = 0, h - 1 do
                buffer.writeu8(self.Buffer, index(x + ix, z + iz), 1)
            end
        end
        return true
    end

    function self:Free(x: number, z: number, w: number, h: number): boolean
        if not validRegion(x, z, w, h) then return false end
        for ix = 0, w - 1 do
            for iz = 0, h - 1 do
                buffer.writeu8(self.Buffer, index(x + ix, z + iz), 0)
            end
        end
        return true
    end

    function self:Clear()
        buffer.fill(self.Buffer, 0, 0, Total)
    end
    return self
end

return Placement
