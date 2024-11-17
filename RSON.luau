--!optimize 2
--!native

local APIDump = require(script.API_Dump)
local VLBuffer = require(script.VLBuffer)

local RSON RSON = {
	Encode = setmetatable({
		null = function(): string
			return `\x00`
		end,
		boolean = function(b: boolean): string
			return b and `\x01\x01` or `\x01\x00`
		end,
		number = setmetatable({
			uint8 = function(number: number): string
				return `\x02{string.pack("B", number)}`
			end,
			uint16 = function(number: number): string
				return `\x03{string.pack("H", number)}`
			end,
			uint32 = function(number: number): string
				return `\x04{string.pack("J", number)}`
			end,
			uint64 = function(number: number): string
				return `\x05{string.pack("L", number)}`
			end,
			int8 = function(number: number): string
				return `\x06{string.pack("b", number)}`
			end,
			int16 = function(number: number): string
				return `\x07{string.pack("h", number)}`
			end,
			int32 = function(number: number): string
				return `\x08{string.pack("j", number)}`
			end,
			int64 = function(number: number): string
				return `\x09{string.pack("l", number)}`
			end,
			float32 = function(number: number): string
				return `\x0A{string.pack("f", number)}`
			end,
			float64 = function(number: number): string
				return `\x0B{string.pack("d", number)}`
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
			end :: (number: number) -> string,
		}),
		string = function(str: string): string
			return `\x0C{str}`
		end,
		table = setmetatable({
			isArray = function(tbl: {[any]: any}): boolean
				return #tbl > 0 and next(tbl, #tbl) == nil
			end,
			isDictionary = function(tbl: {[any]: any}): boolean
				return #tbl == 0 and next(tbl, #tbl > 0 and #tbl or nil) ~= nil
			end,
			isMixed = function(tbl: {[any]: any}): boolean
				return next(tbl, #tbl > 0 and #tbl or nil) ~= nil
			end,
			array = function(tbl: {any}): string
				local data = `\x0D{RSON.Encode.number(#tbl)}`

				for _, value in ipairs(tbl) do
					data ..= RSON.Encode(value)
				end

				return data --[0x0D][length][elements]
			end,
			dictionary = function(tbl: {[any]: any}): string
				local data = `\x0E`

				for key, value in next, tbl, #tbl > 0 and #tbl or nil do
					data ..= RSON.Encode(key) .. RSON.Encode(value)
				end

				return data --[0x0E][key-value pairs]
			end,
			mixed = function(tbl: {[any]: any}): string
				local data = `\x0F{RSON.Encode.number(#tbl)}`

				for _, value in ipairs(tbl) do
					data ..= RSON.Encode(value)
				end

				for key, value in next, tbl, #tbl > 0 and #tbl or nil do
					data ..= RSON.Encode(key) .. RSON.Encode(value)
				end

				return data --[0x0F][length][elements][key-value pairs]
			end,
		}, {
			__call = function(self, tbl: {[any]: any})
				local tblData = self.isArray(tbl) and self.array(tbl) or self.isDictionary(tbl) and self.dictionary(tbl) or self.mixed(tbl)
				local mtbl = getmetatable(tbl)
				mtbl = mtbl ~= nil and (typeof(mtbl) == "table" and self(mtbl) or self({__metatable = mtbl}))

				return tblData .. (mtbl and `\x10{mtbl}` or "") --[tblData][optional: [0x10][mtblData]]
			end :: ({[any]: any}) -> string,
		}),
		
		--REALIZATION: all type data has to be fixed length 100% of the time, otherwise there is no way to predict with certainty the length
		["function"] = function(f: (...any?) -> ...any?): string
			return `\x11{debug.info(f, "n")}`
		end,
		Axes = function(): string
			return `\x12`
		end,
		BrickColor = function(B: BrickColor): string
			return `\x13{RSON.Encode.number.uint16(B.Number % 635)}`
		end,
		CatalogSearchParams = function(): string
			return `\x14`
		end,
		CFrame = function(): string
			return `\x15`
		end,
		Color3 = function(C: Color3): string
			return `\x16{string.pack("I1I1I1", C.R, C.G, C.B)}` --[0x16][int][int][int]
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
		EnumItem = function(): string
			return `\x1D`
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
			return `\x36{RSON.Encode.number.float32(T.Time or 1)}{RSON.Encode.EnumItem(T.EasingStyle or Enum.EasingStyle.Quad)}{RSON.Encode.EnumItem(T.EasingDirection or Enum.EasingDirection.Out)}{RSON.Encode.number.int32(T.RepeatCount or 0)}{RSON.Encode.boolean(T.Reverses or false)}{RSON.Encode.number.float32(T.DelayTime or 0)}`
			--[\x36][float32][Encoded_EnumItem][Encoded_EnumItem][int32][boolean][float32]
		end,
		UDim = function(U: UDim): string
			return `\x37{RSON.Encode.number.float32(U.X.Scale)}{RSON.Encode.number.int32(U.X.Offset)}`
		end,
		UDim2 = function(U: UDim2): string
			return `\x38{RSON.Encode.number.float32(U.X.Scale)}{RSON.Encode.number.int32(U.X.Offset){RSON.Encode.number.float32(U.Y.Scale)}{RSON.Encode.number.int32(U.Y.Offset)}}`
		end,
		Vector2 = function(Vector: Vector2): string
			return `\x39{RSON.Encode.number.float32(Vector.X)}{RSON.Encode.number.float32(Vector.Y)}`
		end,
		Vector2int16 = function(Vector: Vector2int16): string
			return `\x3A{RSON.Encode.number.int16(Vector.X)}{RSON.Encode.number.int16(Vector.Y)}`
		end,
		Vector3 = function(Vector: Vector3): string
			return `\x3B{RSON.Encode.number.float32(Vector.X)}{RSON.Encode.number.float32(Vector.Y)}{RSON.Encode.number.float32(Vector.Z)}`
		end,
		Vector3int16 = function(Vector: Vector3int16): string
			return `\x3C{RSON.Encode.number.int16(Vector.X)}{RSON.Encode.number.int16(Vector.Y)}{RSON.Encode.number.int16(Vector.Z)}`
		end,
	}, {
		__call = function(self, data)
			return self[typeof(data)](data)
		end:: (any) -> string,
	}),
	Decode = function(data: string)
		
	end,
}

return RSON
