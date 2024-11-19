--!optimize 2
--!native

local APIDump = require(script.API_Dump)
local VLBuffer = require(script.VLBuffer)

local EnumCache = {}

local RSON RSON = {
	Encode = setmetatable({
		null = function(): string
			--return `\x00`
			return buffer.create(1) --[0x00]
		end,
		boolean = function(b: boolean): buffer
			--return b and `\x01\x01` or `\x01\x00`
			local boolean = buffer.create(2)
			buffer.writeu16(boolean, 0, 0x0100 + (b and 1 or 0))
			
			return boolean --[0x01][data]
		end,
		number = setmetatable({
			uint8 = function(number: number): buffer
				--return `\x02{string.pack("B", number)}`
				local uint8 = buffer.create(2)
				buffer.writeu16(uint8, 0, 0x0200 + number)
				
				return uint8 --[0x02][data]
			end,
			uint16 = function(number: number): buffer
				--return `\x03{string.pack("H", number)}`
				local uint16 = buffer.create(3)
				buffer.writeu8(uint16, 0, 0x03)
				buffer.writeu16(uint16, 1, number)
				
				return uint16
			end,
			uint32 = function(number: number): buffer
				--return `\x04{string.pack("J", number)}`
				local uint32 = buffer.create(5)
				buffer.writeu8(uint32, 0, 0x04)
				buffer.writeu32(uint32, 1, number)
				
				return uint32
			end,
			uint64 = function(number: number): buffer
				--return `\x05{string.pack("L", number)}`
				local uint64 = buffer.create(9)
				buffer.writeu8(uint64, 0, 0x05)
				buffer.writeu32(uint64, 1, number // 0x100000000) --TODO: See if you can use bit32 instead --On second thought ask for help cuz u tried this and it weird
				buffer.writeu32(uint64, 5, number % 0x100000000)
				
				return uint64
			end,
			int8 = function(number: number): buffer
				--return `\x06{string.pack("b", number)}`
				local int8 = buffer.create(2)
				buffer.writeu8(int8, 0, 0x06)
				buffer.writei8(int8, 1, number)
				
				return int8
			end,
			int16 = function(number: number): buffer
				--return `\x07{string.pack("h", number)}`
				local int16 = buffer.create(3)
				buffer.writeu8(int16, 0, 0x07)
				buffer.writei16(int16, 1, number)
				
				return int16
			end,
			int32 = function(number: number): buffer
				--return `\x08{string.pack("j", number)}`
				local int32 = buffer.create(5)
				buffer.writeu8(int32, 0, 0x08)
				buffer.writei32(int32, 1, number)
				
				return int32
			end,
			int64 = function(number: number): buffer
				--return `\x09{string.pack("l", number)}`
				local int64 = buffer.create(9)
				buffer.writeu8(int64, 0, 0x09)
				buffer.writei32(int64, 1, number // 0x100000000)
				buffer.writeu32(int64, 5, math.abs(number) % 0x100000000)
				
				return int64
			end,
			float32 = function(number: number): buffer
				--return `\x0A{string.pack("f", number)}`
				local float32 = buffer.create(5)
				buffer.writeu8(float32, 0, 0x0A)
				buffer.writef32(float32, 1, number)
				
				return float32
			end,
			float64 = function(number: number): buffer
				--return `\x0B{string.pack("d", number)}`
				local float64 = buffer.create(9)
				buffer.writeu8(float64, 0, 0x0B)
				buffer.writef64(float64, 1, number)
				
				return float64
			end,
		}, {
			__call = function(self, number: number)
				return number % 1 == 0 and 
					(
						number < 0 and (
							math.abs(number) <= 0x7F and self.int8(number)
							or math.abs(number) <= 0x7FFF and self.int16(number)
							or math.abs(number) <= 0x7FFFFF and self.int32(number)
							or math.abs(number) <= 0x7FFFFFFF and self.int64(number)
						)
						or number >= 0 and (
							number <= 0xFF and self.uint8(number)
							or number <= 0xFFFF and self.uint16(number)
							or number <= 0xFFFFFF and self.uint32(number)
							or number <= 0xFFFFFFFF and self.uint64(number)
						)
					) 
					or number < 2 ^ 128 and self.float32(number) or self.float64(number)
			end :: (number: number) -> buffer,
		}),
		string = function(str: string): buffer
			--return `\x0C{str}`
			local string = VLBuffer.new()
			string:Append(buffer.fromstring(`\x0C`), RSON.Encode.number(#str), buffer.fromstring(str))
			
			return string.Data
		end,
		table = setmetatable({
			isArray = function(tbl: {[any]: any}): boolean
				return #tbl > 0 and next(tbl, #tbl) == nil
			end,
			isDictionary = function(tbl: {[any]: any}): boolean
				return #tbl == 0 and next(tbl, #tbl > 0 and #tbl or nil) ~= nil
			end,
			isMixed = function(tbl: {[any]: any}): boolean
				return #t > 0 and next(tbl, #tbl > 0 and #tbl or nil) ~= nil
			end,
			array = function(tbl: {any}): buffer
				--local data = `\x0D{RSON.Encode.number(#tbl)}`
				local array = VLBuffer.new()
				array:Append(buffer.fromstring(`\x0D`), RSON.Encode.number(#tbl))

				for _, value in ipairs(tbl) do
					--data ..= RSON.Encode(value)
					array:Append(RSON.Encode(value))
				end

				return array.Data--data --[0x0D][length][elements]
			end,
			dictionary = function(tbl: {[any]: any}): buffer
				--local data = `\x0E`
				local dictionary = VLBuffer.new()
				dictionary:Append(buffer.fromstring(`\x0E`))

				for key, value in next, tbl, #tbl > 0 and #tbl or nil do
					--data ..= RSON.Encode(key) .. RSON.Encode(value)
					dictionary:Append(RSON.Encode(key), RSON.Encode(value))
				end

				return dictionary.Data--data --[0x0E][key-value pairs]
			end,
			mixed = function(tbl: {[any]: any}): buffer
				--local data = `\x0F{RSON.Encode.number(#tbl)}`
				local mixed = VLBuffer.new()
				mixed:Append(buffer.fromstring(`\x0F`))

				for _, value in ipairs(tbl) do
					--data ..= RSON.Encode(value)
					mixed:Append(RSON.Encode(value))
				end

				for key, value in next, tbl, #tbl > 0 and #tbl or nil do
					--data ..= RSON.Encode(key) .. RSON.Encode(value)
					mixed:Append(RSON.Encode(key), RSON.Encode(value))
				end

				return mixed.Data--data --[0x0F][length][elements][key-value pairs]
			end,
		}, {
			__call = function(self, tbl: {[any]: any})
				local tblBuffer = VLBuffer.new()--self.isArray(tbl) and self.array(tbl) or self.isDictionary(tbl) and self.dictionary(tbl) or self.mixed(tbl)
				tblBuffer:Append(self.isArray(tbl) and self.array(tbl) or self.isDictionary(tbl) and self.dictionary(tbl) or self.mixed(tbl))
				local mtbl = getmetatable(tbl)
				mtbl = mtbl ~= nil and (typeof(mtbl) == "table" and self(mtbl) or self({__metatable = mtbl}))

				if mtbl then
					tblBuffer:Append(buffer.fromstring(`\x10`), mtbl)
				end

				return tblBuffer.Data--tblData --.. (mtbl and `\x10{mtbl}` or "") --[tblData][optional: [0x10][mtblData]]
			end :: ({[any]: any}) -> buffer,
		}),
		
		--REALIZATION: all encodings (other than inherently variable length ones) have to be fixed length, ALWAYS. otherwise there is no way to predict with certainty the length
		["function"] = function(f: (...any?) -> ...any?): buffer
			return buffer.fromstring(`\x11`) --[0x11]
		end,
		Axes = function(): string
			return `\x12`
		end,
		BrickColor = function(B: BrickColor): string
			--return `\x13{RSON.Encode.number.uint16(B.Number % 635)}`
			local BrickColor = buffer.create(3)
			buffer.writeu8(BrickColor, 0, 0x13)
			buffer.writeu16(BrickColor, 1, B.Number % 635)
			
			return BrickColor
		end,
		CatalogSearchParams = function(): string
			return `\x14`
		end,
		CFrame = function(): string
			return `\x15`
		end,
		Color3 = function(C: Color3): buffer
			--return `\x16` --[0x16][int][int][int]
			local Color3 = buffer.create(4)
			buffer.writeu32(Color3, 0, 0x16000000 + bit32.lshift(math.floor(C.R, 16)) + bit32.lshift(math.floor(C.G, 8)) + math.floor(C.B))
			
			return Color3
		end,
		ColorSequence = function(): string
			return `\x17`
		end,
		ColorSequenceKeypoint = function(): string
			return `\x18`
		end,
		Content = function(): string
			return `\x19`
		end,
		DateTime = function(): string
			return `\x1A`
		end,
		DockWidgetPluginGuiInfo = function(): string
			return `\x1B`
		end,
		Enum = function(): string
			return `\x1C`
		end,
		EnumItem = function(EnumItem): buffer
			--return `\x1D`
			--mayb gmatch(EnumItem.Name, "%.(%w+)")? look into string patterns
			--[0x1D][14bits: Enum][10bits: EnumItem]
			if EnumCache[EnumItem] then
				return EnumCache[EnumItem] --will repeatedly return a reference to the same buffer
			end
			
			local match = string.gmatch(EnumItem.Name, "%.(%w+)")
			local CategoryName, ItemName, Category, Item = match(), match()
			
			for CategoryIndex, EnumCategory in APIDump.Enums do
				local exit = false
			
				if EnumCategory.Name == CategoryName then
					for ItemIndex, EnumObject in EnumCategory.Items do
						if EnumObject.Name == ItemName then
							Item = ItemIndex
						end
					end
					
					Category = CategoryIndex
					exit = true
				end
				
				if exit then
					break
				end
			end
			
			local numericalIdentity = Category * 0x4000 + Item
			
			local EnumItemBuffer = buffer.create(4)
			buffer.writeu8(EnumItemBuffer, 0, 0x1D)
			buffer.writeu8(EnumItemBuffer, 1, bit32.extract(numericalIdentity, 16, 8))
			buffer.writeu16(EnumItemBuffer, 2, bit32.extract(numericalIdentity, 0, 16))
			
			EnumCache[EnumItem] = EnumItemBuffer
			
			return EnumItemBuffer
		end,
		Enums = function(): string
			return `\x1E`
		end,
		Faces = function(): string
			return `\x1F`
		end,
		FloatCurveKey = function(): string
			return `\x20`
		end,
		Font = function(): string
			return `\x21`
		end,
		Instance = function(): string
			return `\x22`
		end,
		NumberRange = function(): string
			return `\x23`
		end,
		NumberSequence = function(): string
			return `\x24`
		end,
		NumberSequenceKeypoint = function(): string
			return `\x25`
		end,
		OverlapParams = function(): string
			return `\x26`
		end,
		Path2DControlPoint = function(): string
			return `\x27`
		end,
		PathWaypoint = function(): string
			return `\x28`
		end,
		PhysicalProperties = function(): string
			return `\x29`
		end,
		Random = function(): string
			return `\x2A`
		end,
		Ray = function(): string
			return `\x2B`
		end,
		RaycastParams = function(): string
			return `\x2C`
		end,
		RaycastResult = function(): string
			return `\x2D`
		end,
		RBXScriptConnection = function(): string
			return `\x2E`
		end,
		RBXScriptSignal = function(): string
			return `\x2F`
		end,
		Rect = function(): string
			return `\x30`
		end,
		Region3 = function(): string
			return `\x31`
		end,
		Region3int16 = function(): string
			return `\x32`
		end,
		RotationCurveKey = function(): string
			return `\x33`
		end,
		Secret = function(S): string --Leave this be
			return `\x34`
		end,
		SharedTable = function(tbl): string --Leave this be
			return `\x35`
		end,
		TweenInfo = function(T: TweenInfo): string
			--return `\x36{RSON.Encode.number.float32(T.Time or 1)}{RSON.Encode.EnumItem(T.EasingStyle or Enum.EasingStyle.Quad)}{RSON.Encode.EnumItem(T.EasingDirection or Enum.EasingDirection.Out)}{RSON.Encode.number.int32(T.RepeatCount or 0)}{RSON.Encode.boolean(T.Reverses or false)}{RSON.Encode.number.float32(T.DelayTime or 0)}`
			--[\x36][float32][Encoded_EnumItem][Encoded_EnumItem][int32][boolean][float32]
			
			--11 easing styles, 3 easing directions
			--Key: S = EasingStyle, D = EasingDirection, R = Reverses
			--[\x36][Time: float32][1 byte: -SSSSDDR][Repeat Count: int32][Delay Time: float32]
			
			local tripleByte = ((T.EasingStyle or Enum.EasingStyle.Quad).Value + 1) * 8 + ((T.EasingDirection or Enum.EasingDirection.Out).Value + 1) * 4 + (T.Reverses and 1 or 0)
			
			local TweenInfo = buffer.create(14)
			buffer.writeu8(TweenInfo, 0, 0x36)
			buffer.writef32(TweenInfo, 1, T.Time or 1)
			buffer.writeu8(TweenInfo, 5, tripleByte)
			buffer.writei32(TweenInfo, 6, T.RepeatCount or 0)
			buffer.writef32(TweenInfo, 10, T.DelayTime or 0)
			
			return TweenInfo
		end,
		UDim = function(U: UDim): buffer
			--return `\x37{RSON.Encode.number.float32(U.X.Scale)}{RSON.Encode.number.int32(U.X.Offset)}`
			local UDim = buffer.create(9)
			buffer.writeu8(UDim, 0, 0x37)
			buffer.writef32(UDim, 1, U.X.Scale)
			buffer.writei32(UDim, 5, U.X.Offset)
			
			return UDim
		end,
		UDim2 = function(U: UDim2): buffer
			--return `\x38{RSON.Encode.number.float32(U.X.Scale)}{RSON.Encode.number.int32(U.X.Offset){RSON.Encode.number.float32(U.Y.Scale)}{RSON.Encode.number.int32(U.Y.Offset)}}`
			local UDim2 = buffer.create(17)
			buffer.writeu8(UDim2, 0, 0x38)
			buffer.writef32(UDim2, 1, U.X.Scale)
			buffer.writei32(UDim2, 5, U.X.Offset)
			buffer.writef32(UDim2, 9, U.Y.Scale)
			buffer.writei32(UDim2, 13, U.Y.Offset)
			
			return UDim2
		end,
		Vector2 = function(Vector: Vector2): buffer
			--return `\x39{RSON.Encode.number.float32(Vector.X)}{RSON.Encode.number.float32(Vector.Y)}`
			local Vector2 = buffer.create(9)
			buffer.writeu8(Vector3, 0, 0x39)
			buffer.writef32(Vector2, 1, Vector.X)
			buffer.writef32(Vector2, 5, Vector.Y)
			
			return Vector2
		end,
		Vector2int16 = function(Vector: Vector2int16): buffer
			--return `\x3A{RSON.Encode.number.int16(Vector.X)}{RSON.Encode.number.int16(Vector.Y)}`
			local Vector2int16 = buffer.create(5)
			buffer.writeu8(Vector2int16, 0, 0x3A)
			buffer.writei16(Vector2int16, 1, Vector.X)
			buffer.writei16(Vector2int16, 3, Vector.Y)
		
			return Vector2int16
		end,
		Vector3 = function(Vector: Vector3): buffer
			--return `\x3B{RSON.Encode.number.float32(Vector.X)}{RSON.Encode.number.float32(Vector.Y)}{RSON.Encode.number.float32(Vector.Z)}`
			local Vector3 = buffer.create(13)
			buffer.writeu8(Vector3, 0, 0x3B)
			buffer.writef32(Vector3, 1, Vector.X)
			buffer.writef32(Vector3, 5, Vector.Y)
			buffer.writef32(Vector3, 9, Vector.Z)
			
			return Vector3
		end,
		Vector3int16 = function(Vector: Vector3int16): buffer
			--return `\x3C{RSON.Encode.number.int16(Vector.X)}{RSON.Encode.number.int16(Vector.Y)}{RSON.Encode.number.int16(Vector.Z)}`
			local Vector3int16 = buffer.create(7)
			buffer.writeu8(Vector3int16, 0, 0x3C)
			buffer.writei16(Vector3int16, 1, Vector.X)
			buffer.writei16(Vector3int16, 3, Vector.Y)
			buffer.writei16(Vector3int16, 5, Vector.Z)
			
			return Vector3int16
		end,
	}, {
		__call = function(self, data)
			return self[typeof(data)](data)
		end:: (any) -> buffer,
	}),
	Decode = function(data: buffer)
		
	end,
}

return RSON
