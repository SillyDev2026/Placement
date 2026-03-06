--!native
--!optimize 2

local Placement = {}

local CellSize = 8
local GridSize = 100
local Total = GridSize * GridSize

function Placement.new(basepart: BasePart)
	local self = {}
	self.Base = basepart
	self.GridSize = GridSize
	self.CellSize = CellSize
	self.Buffer = buffer.create(Total)
	for i = 0, Total - 1 do
		buffer.writeu8(self.Buffer, i, 0)
	end
	local function index(x,z)
		return z * GridSize + x
	end

	function self:WorldToGrid(pos)
		local relative = pos - self.Base.Position
		local gx = math.floor((relative.X + (self.Base.Size.X/2)) / CellSize)
		local gz = math.floor((relative.Z + (self.Base.Size.Z/2)) / CellSize)
		return gx,gz
	end
	function self:GridToWorld(gx,gz)
		local basePos = self.Base.Position
		local baseSize = self.Base.Size
		local x = basePos.X - baseSize.X/2 + (gx*self.CellSize) + self.CellSize/2
		local z = basePos.Z - baseSize.Z/2 + (gz*self.CellSize) + self.CellSize/2
		local y = basePos.Y + baseSize.Y/2
		return Vector3.new(x,y,z)
	end
	function self:IsCellEmpty(x,z)
		if x < 0 or z < 0 or x >= GridSize or z >= GridSize then
			return false
		end
		local i = index(x,z)
		return buffer.readu8(self.Buffer,i) == 0
	end
	function self:SetCell(x,z,val)
		local i = index(x,z)
		buffer.writeu8(self.Buffer,i,val)
	end
	function self:CanPlace(x,z,w,h)
		for ix = 0,w-1 do
			for iz = 0,h-1 do
				if not self:IsCellEmpty(x+ix,z+iz) then
					return false
				end
			end
		end
		return true
	end
	function self:Occupy(x,z,w,h)
		for ix = 0,w-1 do
			for iz = 0,h-1 do
				self:SetCell(x+ix,z+iz,1)
			end
		end
	end
	function self:Free(x,z,w,h)
		for ix = 0,w-1 do
			for iz = 0,h-1 do
				self:SetCell(x+ix,z+iz,0)
			end
		end
	end
	function self:Clear()
		for i = 0, Total-1 do
			buffer.writeu8(self.Buffer, i, 0)
		end
	end
	return self
end

return Placement
