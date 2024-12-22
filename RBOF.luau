--RBOF superscedes RSON
local BACK_REFERENCING_ENABLED = false --Enabling will reduce output size at the cost of increased computation time and if compressed, lower compression ratios.

local APIDump = require(script.API_Dump)
local Subsets = require(script.Subsets)

type Memory = {
	buffer: buffer,
	pointer: number,
}

function allocate(bytes: number)
	local self = {buffer = buffer.create(bytes), pointer = 0, cache = {}}

	return self
end

function realloc(self: Memory, bytes: number)
	--local b = buffer.create(buffer.len(self.buffer) + bytes)
	--buffer.copy(b, 0, self.buffer, 0)

	--self.buffer = b

	local buff = self.buffer
	local pointer = self.pointer
	local length = buffer.len(buff)

	if length < pointer + bytes then
		if length == 0 then
			length = 1
		end

		local exponent = math.ceil(math.log((pointer + bytes) / length, 2))
		local new = buffer.create(length * 2 ^ exponent)
		buffer.copy(new, 0, buff, 0)

		self.buffer = new
	end
end

local Write = {}
local EnumCache = {}

function getNumericalEncodingLength(number)
	if number % 1 == 0 then
		if number < 0 then
			if math.abs(number) <= 0x7F then
				return 0x1
			elseif math.abs(number) <= 0x7FFF then
				return 0x2
			elseif math.abs(number) <= 0x7FFFFF then
				return 0x4
			elseif math.abs(number) <= 0x7FFFFFFF then
				return 0x8
			end
		else
			if math.abs(number) <= 0xFF then
				return 0x1
			elseif math.abs(number) <= 0xFFFF then
				return 0x2
			elseif math.abs(number) <= 0xFFFFFF then
				return 0x4
			elseif math.abs(number) <= 0xFFFFFFFF then
				return 0x8
			end
		end
	else
		if number < 2 ^ 128 then
			return 0x4
		else
			return 0x8
		end
	end
end

function backRef(self: Memory, position, length: number)
	local Value = buffer.readstring(self.buffer, position, length)

	if self.cache[Value] then
		local offset = position - self.cache[Value]
		
		if length > getNumericalEncodingLength(offset) + getNumericalEncodingLength(length) + 1 then
			buffer.fill(self.buffer, position, 0, length)
			self.pointer = position

			realloc(self, 1)

			buffer.writeu8(self.buffer, self.pointer, 0x40)
			Write.number(self, offset)
			Write.number(self, length)

			self.pointer += 1

			--[backRef][number][number]
		end
	elseif length > 3 then --3 is the smallest possible size for a back reference
		self.cache[Value] = position
	end
end

function readBackRef(self: buffer, position: number)

end

Write["nil"] = function(self: Memory): Memory
	realloc(self, 1)
	self.pointer += 1
end

function Write.boolean(self: Memory, Value): Memory
	realloc(self, 2)

	buffer.writeu8(self.buffer, self.pointer, 0x01)
	buffer.writeu8(self.buffer, self.pointer + 1, Value and 0x01 or 0x00)

	self.pointer += 2
end

function Write.uint8(self: Memory, Value): Memory
	realloc(self, 2)

	buffer.writeu8(self.buffer, self.pointer, 0x02)
	buffer.writeu8(self.buffer, self.pointer + 1, Value)

	self.pointer += 2
end


function Write.uint16(self: Memory, Value): Memory
	realloc(self, 3)

	buffer.writeu8(self.buffer, self.pointer, 0x03)
	buffer.writeu16(self.buffer, self.pointer + 1, Value)

	self.pointer += 3
end

function Write.uint32(self: Memory, Value): Memory
	realloc(self, 5)

	buffer.writeu8(self.buffer, self.pointer, 0x04)
	buffer.writeu32(self.buffer, self.pointer + 1, Value)

	self.pointer += 5
end

function Write.uint64(self: Memory, Value): Memory
	realloc(self, 9)

	buffer.writeu8(self.buffer, self.pointer, 0x05)
	buffer.writeu32(self.buffer, self.pointer + 1, Value // 0x100000000)
	buffer.writeu32(self.buffer, self.pointer + 5, Value % 0x100000000)

	self.pointer += 9
end

function Write.int8(self: Memory, Value): Memory
	realloc(self, 2)

	buffer.writeu8(self.buffer, self.pointer, 0x06)
	buffer.writei8(self.buffer, self.pointer + 1, Value)

	self.pointer += 2
end


function Write.int16(self: Memory, Value): Memory
	realloc(self, 3)

	buffer.writeu8(self.buffer, self.pointer, 0x07)
	buffer.writei16(self.buffer, self.pointer + 1, Value)

	self.pointer += 3
end

function Write.int32(self: Memory, Value): Memory
	realloc(self, 5)

	buffer.writeu8(self.buffer, self.pointer, 0x08)
	buffer.writei32(self.buffer, self.pointer + 1, Value)

	self.pointer += 5
end

function Write.int64(self: Memory, Value): Memory
	realloc(self, 9)

	buffer.writeu8(self.buffer, self.pointer, 0x09)
	buffer.writei32(self.buffer, self.pointer + 1, Value // 0x100000000)
	buffer.writeu32(self.buffer, self.pointer + 5, Value % 0x100000000)

	self.pointer += 9
end

function Write.float32(self: Memory, Value): Memory
	realloc(self, 5)

	buffer.writeu8(self.buffer, self.pointer, 0x0A)
	buffer.writef32(self.buffer, self.pointer + 1, Value)

	self.pointer += 5
end

function Write.float64(self: Memory, Value): Memory
	realloc(self, 9)

	buffer.writeu8(self.buffer, self.pointer, 0x0B)
	buffer.writef64(self.buffer, self.pointer + 1, Value)

	self.pointer += 9
end

function Write.number(self: Memory, Value)
	if Value % 1 == 0 then
		if Value < 0 then
			if math.abs(Value) <= 0x7F then
				Write.int8(self, Value)
			elseif math.abs(Value) <= 0x7FFF then
				Write.int16(self, Value)
			elseif math.abs(Value) <= 0x7FFFFF then
				Write.int32(self, Value)
			elseif math.abs(Value) <= 0x7FFFFFFF then
				Write.int64(self, Value)
			end
		else
			if math.abs(Value) <= 0xFF then
				Write.uint8(self, Value)
			elseif math.abs(Value) <= 0xFFFF then
				Write.uint16(self, Value)
			elseif math.abs(Value) <= 0xFFFFFF then
				Write.uint32(self, Value)
			elseif math.abs(Value) <= 0xFFFFFFFF then
				Write.uint64(self, Value)
			end
		end
	else
		if Value < 2 ^ 128 then
			Write.float32(self, Value)
		else
			Write.float64(self, Value)
		end
	end
end

function Write.string(self: Memory, Value)
	realloc(self, 1)
	
	local position = self.pointer
	
	buffer.writeu8(self.buffer, self.pointer, 0x0C)
	Write.number(self, #Value)
	
	realloc(self, #Value + 1)
	buffer.writestring(self.buffer, self.pointer + 1, Value)

	self.pointer += #Value + 1
	
	if BACK_REFERENCING_ENABLED then
		backRef(self, position, self.pointer - position)
	end
end

function isArray(tbl: {[any]: any}): boolean
	return #tbl > 0 and next(tbl, #tbl) == nil
end

function isDictionary(tbl: {[any]: any}): boolean
	return #tbl == 0 and next(tbl, #tbl > 0 and #tbl or nil) ~= nil
end

function isMixed(tbl: {[any]: any}): boolean
	return #tbl > 0 and next(tbl, #tbl > 0 and #tbl or nil) ~= nil
end

function Write.array(self: Memory, tbl)
	--Write.uint8(self, 0x0D)
	realloc(self, 1)
	buffer.writeu8(self.buffer, self.pointer, 0x0D)
	self.pointer += 1
	
	Write.number(self, #tbl)

	for _, Value in ipairs(tbl) do
		Write[typeof(Value)](self, Value)
	end
end

function Write.dictionary(self: Memory, tbl)
	--Write.uint8(self, 0x0E)
	realloc(self, 1)
	buffer.writeu8(self.buffer, self.pointer, 0x0E)
	self.pointer += 1
	
	for Key, Value in next, tbl, #tbl > 0 and #tbl or nil do
		Write[typeof(Key)](self, Key)
		Write[typeof(Value)](self, Value)
	end
end

function Write.mixed(self: Memory, tbl)
	--Write.uint8(self, 0x0F)
	realloc(self, 1)
	buffer.writeu8(self.buffer, self.pointer, 0x0F)
	self.pointer += 1
	
	Write.number(self, #tbl)

	for _, Value in ipairs(tbl) do
		Write[typeof(Value)](self, Value)
	end

	for Key, Value in next, tbl, #tbl > 0 and #tbl or nil do
		Write[typeof(Key)](self, Key)
		Write[typeof(Value)](self, Value)
	end
end

function Write.table(self: Memory, tbl)
	Write[isArray(tbl) and "array" or isDictionary(tbl) and "dictionary" or "mixed"](self, tbl)
	local mtbl = getmetatable(tbl)

	if mtbl then
		realloc(self, 1)
		buffer.writeu8(self.buffer, self.pointer, 0x10)
		self.pointer += 1
		
		Write.table(self, typeof(mtbl) == "table" and mtbl or {__metatable = mtbl})
	end
end

Write["function"] = function(self: Memory, Value)
	realloc(self, 1)

	buffer.writeu8(self.buffer, self.pointer, 0x11)

	self.pointer += 1
end

function Write.thread(self: Memory, Value)
	realloc(self, 1)

	buffer.writeu8(self.buffer, self.pointer, 0x12)

	self.pointer += 1
end

function Write.userdata(self: Memory, Value)
	realloc(1)

	buffer.writeu8(self.buffer, self.pointer, 0x13)

	self.pointer += 1

	local mtbl = getmetatable(Value)

	if mtbl then
		Write.uint8(self, 0x10)
		Write.table(self, typeof(mtbl) == "table" and mtbl or {__metatable = mtbl})
	end
end

function Write.buffer(self: Memory, Value)
	realloc(buffer.len(Value) + 1)

	buffer.writeu8(self.buffer, self.pointer, 0x14)
	buffer.copy(self.buffer, self.pointer + 1, Value, 0)

	self.pointer += buffer.len(Value) + 1
end

function Write.Axes(self: Memory, Value)
	realloc(self, 3)

	buffer.writeu8(self.buffer, self.pointer, 0x15)
	buffer.writeu16(self.buffer, self.pointer + 1, 
		Value.X and 0x100 or 0 +
		Value.Y and 0x80 or 0 + 
		Value.Z and 0x40 or 0 +
		Value.Top or 0x20 or 0 +
		Value.Bottom or 0x10 or 0 +
		Value.Left or 0x08 or 0 +
		Value.Right or 0x04 or 0 +
		Value.Back and 0x02 or 0 +
		Value.Front or 0x01 or 0
	)

	self.pointer += 3 
	--[X][Y][Z][Top][Bottom][Left][Right][Back][Front]
	--Each true or false is represented as a 0 or 1 in the above order
end

function Write.BrickColor(self: Memory, Value)
	realloc(self, 3)

	buffer.writeu8(self.buffer, self.pointer, 0x16)
	buffer.writeu16(self.buffer, self.pointer, Value.Number % 635)

	self.pointer += 3
end

function Write.CatalogSearchParams(self: Memory, Value)

	local packedArrays = 0
	
	if #Value.BundleTypes > 0 then
		local BundleTypesArray = {}

		for _, BundleType in Value.BundleTypes do
			table.insert(BundleTypesArray, BundleType.Value)
		end
		
		table.sort(BundleTypesArray, function(a, b)
			return a < b
		end)
		
		packedArrays += Subsets.findIndexFromSet(BundleTypesArray, 5) * 0x10000000000
	end
	
	if #Value.AssetTypes > 0 then
		local AssetTypesArray = {}

		for _, AssetType in Value.AssetTypes do
			table.insert(AssetTypesArray, AssetType.Value)
		end

		table.sort(AssetTypesArray, function(a, b)
			return a < b
		end)

		packedArrays += Subsets.findIndexFromSet(AssetTypesArray, 40)
	end
	
	
	--[string][int32][int32][A | 6 options][B | 6 options][C | 6 options][D | 3 options][array <5 options>][array <40 options>][E | bool][string][int32]
	-- - 101 101 1|01 10 0 101
	--[string][int32][int32][packedData][array][array][string][int32]
	local packedData = 
		(Value.SortType.Value - 1) * 0x1000 +
		(Value.SortAggregation.Value - 1) * 0x200 +
		(Value.CategoryFilter.Value - 1) * 0x40 +
		(Value.SalesTypeFilter.Value - 1) * 0x10 +
		(Value.IncludeOffSale and 0x8 or 0) + 
		(Value.Limit == 10 and 0 or Value.Limit == 28 and 1 or Value.Limit == 60 and 3 or Value.Limit == 120 and 4 or 2) --Value.Limit == 30 and 2, 30 is the default
	
	local expectedLength =  #Value.SearchKeyword + #Value.CreatorName + 19
	
	realloc(self, expectedLength)
	buffer.writeu8(self.buffer, self.pointer, 0x17)
	Write.number(self, #Value.SearchKeyword)
	realloc(self, expectedLength)
	buffer.writestring(self.buffer, self.pointer + 1, Value.SearchKeyword)
	buffer.writei32(self.buffer, self.pointer + #Value.SearchKeyword + 1, Value.MinPrice)
	buffer.writei32(self.buffer, self.pointer + #Value.SearchKeyword + 5, Value.MaxPrice)
	buffer.writeu16(self.buffer, self.pointer + #Value.SearchKeyword + 9, packedData)
	buffer.writeu32(self.buffer, self.pointer + #Value.SearchKeyword + 11, packedArrays // 0x100000000)
	buffer.writeu32(self.buffer, self.pointer + #Value.SearchKeyword + 15, packedArrays % 0x100000000)
	Write.number(self, #Value.CreatorName)
	realloc(self, expectedLength)
	buffer.writestring(self.buffer, self.pointer + #Value.SearchKeyword + 19, Value.CreatorName)

	self.pointer += expectedLength
	--[string][int32][int32][packedData][packedArrays][string]
end

function Write.CFrame(self: Memory, Value)
	realloc(self, 49)
	
	local Components = Value:GetComponents()
	
	buffer.writeu8(self.buffer, self.pointer, 0x18)
	buffer.writeu8(self.buffer, self.pointer + 1, Components[1])
	buffer.writeu8(self.buffer, self.pointer + 5, Components[2])
	buffer.writeu8(self.buffer, self.pointer + 9, Components[3])
	buffer.writeu8(self.buffer, self.pointer + 13, Components[4])
	buffer.writeu8(self.buffer, self.pointer + 17, Components[5])
	buffer.writeu8(self.buffer, self.pointer + 21, Components[6])
	buffer.writeu8(self.buffer, self.pointer + 25, Components[7])
	buffer.writeu8(self.buffer, self.pointer + 29, Components[8])
	buffer.writeu8(self.buffer, self.pointer + 33, Components[9])
	buffer.writeu8(self.buffer, self.pointer + 37, Components[10])
	buffer.writeu8(self.buffer, self.pointer + 41, Components[11])
	buffer.writeu8(self.buffer, self.pointer + 45, Components[12])

	self.pointer += 49
end

function Write.Color3(self: Memory, Value)
	realloc(self, 4)

	buffer.writeu8(self.buffer, self.pointer, 0x19)
	buffer.writeu8(self.buffer, self.pointer + 1, Value.R)
	buffer.writeu8(self.buffer, self.pointer + 2, Value.G)
	buffer.writeu8(self.buffer, self.pointer + 3, Value.B)

	self.pointer += 4
end

function Write.ColorSequence(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x1A)

	self.pointer += 
end

function Write.ColorSequenceKeypoint(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x1B)

	self.pointer += 
end

function Write.Content(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x1C)

	self.pointer += 
end

function Write.DateTime(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x1D)

	self.pointer += 
end

function Write.DockWidgetPluginGuiInfo(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x1E)

	self.pointer += 
end

function Write.Enum(self: Memory, Value)
	realloc(self, 3)
	
	local EnumName = tostring(Value)
	
	if not EnumCache[Value] then
		for position, Data in APIDump.Enums do
			if Data.Name == EnumName then
				EnumCache[Value] = position - 1
				break
			end
		end
	end
	
	local EnumValue = EnumCache[Value]
	
	buffer.writeu8(self.buffer, self.pointer, 0x1F)
	buffer.writeu16(self.buffer, self.pointer + 1, EnumValue)

	self.pointer += 3
end

function Write.EnumItem(self: Memory, Value)
	realloc(self, 3)
	
	local EnumName = tostring(Value.EnumType)
	
	if not EnumCache[Value] then
		for position, Data in APIDump.Enums do
			if Data.Name == EnumName then
				EnumCache[Value] = position - 1
				break
			end
		end
	end

	local EnumValue = EnumCache[Value]
	
	buffer.writeu8(self.buffer, self.pointer, 0x20)
	buffer.writeu16(self.buffer, self.pointer + 1, EnumValue * 0x400 + Value.Value)

	self.pointer += 3
end

function Write.Enums(self: Memory, Value)
	realloc(self, 1)

	buffer.writeu8(self.buffer, self.pointer, 0x21)

	self.pointer += 1
end

function Write.Faces(self: Memory, Value)
	realloc(self, 2)
	
	buffer.writeu8(self.buffer, self.pointer, 0x22)
	buffer.writeu8(self.buffer, self.pointer + 1, 
		Value.Top * 0x20 or 0 +
		Value.Bottom * 0x10 or 0 +
		Value.Left * 0x8 or 0 +
		Value.Right * 0x4 or 0 +
		Value.Back * 0x2 or 0 +
		Value.Front * 0x1 or 0
	)

	self.pointer += 2 
end

function Write.FloatCurveKey(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x23)

	self.pointer += 
end

function Write.Font(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x24)

	self.pointer += 
end

function Write.Instance(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x25)

	self.pointer += 
end

function Write.NumberRange(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x26)

	self.pointer += 
end

function Write.NumberSequence(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x27)

	self.pointer += 
end

function Write.NumberSequenceKeypoint(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x28)

	self.pointer += 
end

function Write.OverlapParams(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x29)

	self.pointer += 
end

function Write.Path2DControlPoint(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x2A)

	self.pointer += 
end

function Write.PathWaypoint(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x2B)

	self.pointer += 
end

function Write.PhysicalProperties(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x2C)

	self.pointer += 
end

function Write.Random(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x2D)

	self.pointer += 
end

function Write.Ray(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x2E)

	self.pointer += 
end

function Write.RaycastParams(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x2F)

	self.pointer += 
end

function Write.RaycastResult(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x30)

	self.pointer += 
end

function Write.RBXScriptConnection(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x31)

	self.pointer += 
end

function Write.RBXScriptSignal(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x32)

	self.pointer += 
end

function Write.Rect(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x33)

	self.pointer += 
end

function Write.Region3(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x34)

	self.pointer += 
end

function Write.Region3int16(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x35)

	self.pointer += 
end

function Write.RotationCurveKey(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x36)

	self.pointer += 
end

function Write.Secret(self: Memory, Value)
	realloc(self, 1)

	buffer.writeu8(self.buffer, self.pointer, 0x37)

	self.pointer += 1
end

function Write.SharedTable(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x38)

	self.pointer += 
end

function Write.TweenInfo(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x39)

	self.pointer += 
end

function Write.UDim(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x3A)

	self.pointer += 
end

function Write.UDim2(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x3B)

	self.pointer += 
end

function Write.Vector2(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x3C)

	self.pointer += 
end

function Write.Vector2int16(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x3D)

	self.pointer += 
end

function Write.Vector3(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x3E)

	self.pointer += 
end

function Write.Vector3int16(self: Memory, Value)
	realloc(self, )

	buffer.writeu8(self.buffer, self.pointer, 0x3F)

	self.pointer += 
end
