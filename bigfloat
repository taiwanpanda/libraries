local bigfloat = {
	__metatable = true
}

export type bigfloat = {buffer | number}

--Special thanks to kexy123 for their post @ https://devforum.roblox.com/t/how-to-convert-strings-into-a-floating-point-number/3061055/7?u=au_tk

local dividedBy2 = {
	["0"] = {0, 0},
	["1"] = {0, 5},
	["2"] = {1, 0},
	["3"] = {1, 5},
	["4"] = {2, 0},
	["5"] = {2, 5},
	["6"] = {3, 0},
	["7"] = {3, 5},
	["8"] = {4, 0},
	["9"] = {4, 5}
}

local multipliedBy2 = {
	["0"] = {0, 0},
	["1"] = {2, 0},
	["2"] = {4, 0},
	["3"] = {6, 0},
	["4"] = {8, 0},
	["5"] = {0, 1},
	["6"] = {2, 1},
	["7"] = {4, 1},
	["8"] = {6, 1},
	["9"] = {8, 1}
}

local byteCache = setmetatable({
	[1 / 8] = 0,
	[1] = 4,
	[2] = 5,
	[4] = 8,
	[8] = 11,
	[16] = 15,
	[32] = 19,
}, {
	__index = function(self, n)
		local finalResult = nil

		if math.log(n, 2) % 1 == 0 then
			local cache = {}

			n = math.log(n, 2)

			local function computeB(n, i)
				if cache[n] and cache[n][i] then
					return cache[n][i]
				end

				if not cache[n] then
					cache[n] = {}
				end

				local result
				if n == i then
					result = {n, 0}
				else
					result = {0, 0}
				end

				if i >= 1 then
					local previous = computeB(n, i - 1)
					local bShifted
					if n < i then
						bShifted = {0, 0}
					else
						bShifted = reverseTuple(computeB(n - i, i))
					end

					result = {result[1] + previous[1] + bShifted[1], result[2] + previous[2] + bShifted[2]}
				end

				cache[n][i] = result
				return result
			end

			finalResult = computeB(n, n)[1]
		else
			finalResult = math.ceil(math.exp(math.pi * math.sqrt(2 * math.log(n, 2) / 3)) / (2 * math.log(n, 2) * math.sqrt(3))) + 2
		end

		self[n] = finalResult
		return finalResult
	end
})

function reverseTuple(t)
	return {t[2], t[1]}
end

local function floorDivide2(str: string): (string, number)
	local result, remainder = "", 0

	for i = 1, #str do
		local character = string.sub(str, i, i)
		local divideResult = dividedBy2[character]

		result ..= divideResult[1] + remainder
		remainder = divideResult[2]
	end

	result = string.gsub(result, "^0+", "")
	return result, remainder
end

local function multiplyBy2(str: string): string
	local result, carry = "", 0

	for i = #str, 1, -1 do
		local character = string.sub(str, i, i)
		local multiplyResult = multipliedBy2[character]
		result = tostring(multiplyResult[1] + carry) .. result
		carry = multiplyResult[2]
	end

	if carry > 0 then
		result = tostring(carry) .. result
	end

	return result
end

local function wholeNumberToBinary(str: string): string
	local result, remainder = "", 0

	while str ~= "" do
		str, remainder = floorDivide2(str)
		result = math.sign(remainder) .. result
	end

	return result
end

local function fractionToBinary(str: string, mantissaLength: number): string
	local result = ""

	for _ = 1, mantissaLength do
		str = multiplyBy2(str)
		local digit = string.sub(str, 1, 1)
		result ..= digit
		str = `0{string.sub(str, 2)}`
	end

	return result
end

function bigfloat._writeStringToFloat(str: string, float: buffer, exponentLength: number, mantissaLength: number)
	local sign, whole, fraction = string.match(string.gsub(str, "^(-?)(%.)", "%10%2"), "^(%--)(%d+)%.?(%d*)")
	local wholeBinary, fractionBinary = wholeNumberToBinary(whole), fractionToBinary(`0{fraction}`, mantissaLength)
	local binary = wholeBinary .. fractionBinary
	local index = string.find(binary, "1")
	local exponent = 2 ^ (exponentLength - 1) - 1 + (#wholeBinary - index)
	exponent = wholeNumberToBinary(tostring(exponent))
	exponent = string.rep("0", exponentLength - #exponent) .. exponent
	binary = string.sub(binary, index + 1, index + mantissaLength)
	sign = sign == "-" and "1" or "0"

	local floatString = sign .. exponent .. binary

	for i = 1, #floatString, 8 do
		local byte = tonumber(string.sub(floatString, i, i + 7), 2)
		buffer.writeu8(float, (#floatString - i) / 8, byte)
	end

	return float
end

local function decimalToBits(decimal: number, mantissaLength: number): number
	local int = 0

	for i = 1, mantissaLength do
		local place = 2 ^ -i

		if place <= decimal then
			decimal -= place
			int += 2 ^ (mantissaLength - i)
		end
	end

	return int
end

function bigfloat._writeNumberToFloat(number: number, float: buffer, exponentLength: number, mantissaLength: number)
	if buffer.len(float) >= 128 then
		return bigfloat._writeStringToFloat(tostring(number), float, exponentLength, mantissaLength)
	else
		local sign = number > 0 and 0 or 1
		number = math.abs(number)

		local index = math.floor(math.log(number, 2))
		local exponent, mantissa = 2 ^ (exponentLength - 1) - 1 + index, number / 2 ^ index % 1
		local bitLength = 1 + exponentLength + mantissaLength

		local byte = 0

		for i = 1, bitLength do
			if i == 1 then
				byte += sign * 2 ^ 7
			elseif i - 1 <= exponentLength then
				local placeValue = 2 ^ (exponentLength - i + 1)

				if placeValue <= exponent then
					exponent -= placeValue
					byte += 2 ^ (8 - i % 8) % 255
				end
			else
				local placeValue = 2 ^ (bitLength - mantissaLength - i)

				if placeValue <= mantissa then
					mantissa -= placeValue
					byte += 2 ^ (8 - i % 8) % 255
				end
			end

			if i % 8 == 0 then
				buffer.writeu8(float, (bitLength - i) / 8, byte)
				byte = 0
			end
		end

		return float
	end
end

function bigfloat._getSpecs(n: number)
	local expBits = byteCache[n]

	return expBits, 8 * n - expBits - 1
end

function bigfloat.new(bytes: number, value: (number | string)?): bigfloat
	local float = setmetatable({buffer.create(bytes), bigfloat._getSpecs(bytes)}, bigfloat)

	if value then
		bigfloat.writeValue(float, value)
	end

	return float
end

function bigfloat.writeValue(float: bigfloat, value: number | string)

	--do the magic
	if typeof(value) == "number" then
		bigfloat._writeNumberToFloat(value, float[1], float[2], float[3])
	else
		bigfloat._writeStringToFloat(value, float[1], float[2], float[3])
	end

	return float
end

function bigfloat.readValue(float: bigfloat): string
	--MATHHH AHAAHAAAHAAHAA AAAAAAAAAAAAAAAAAAAAAAAAA
end

local exponentFactor = math.log(2) / math.log(10)

function bigfloat.getRange(value: bigfloat | number)
	if typeof(value) == "table" then
		value = value[2]
	end

	local x = 2 ^ (value - 1) * exponentFactor

	return x < 21 and `±{2 ^ 2 ^ (value - 1)}` or `±{10 ^ (x % 1)}e+{math.floor(x)}`
end


--if u have 2 floats of differing sizes, then you have to INTERPRET the smaller one into the same format as the bigger one

function bigfloat._getRawExponent(float: bigfloat)
	local length = buffer.len(float[1])

	local exponent = 0
	local transitionByte = length - math.floor((float[2] + 1) / 8) - 1
	local transitionBitMask = 256 - 2 ^ (float[3] - transitionByte * 8)
	local leadingBitMask = 128 - 2 ^ math.max(0, float[3] - 8 * (length - 1))

	for i = transitionByte, length - 1 do
		local bitmask = i == length - 1 and leadingBitMask or i == transitionByte and transitionBitMask or 255
		local displacement = i == transitionByte and -float[3] + transitionByte * 8 or i == length - 1 and 8 - float[3] + transitionByte * 8 or 0

		exponent += bit32.band(buffer.readu8(float[1], i), bitmask) * 2 ^ displacement
	end

	return exponent
end

function bigfloat.__add(a, b)
	--bigfloat + num
	--num + bigfloat

	--bigfloat + string
	--string + bigfloat

	--bigfloat + smallfloat
	--smallfloat + bigfloat

	local typeA, typeB = typeof(a), typeof(b)
	typeA, typeB = typeA == "table" and "bigfloat" or typeA, typeB == "table" and "bigfloat" or typeB

	if typeA ~= "bigfloat" then --the other one is always a table
		a, b = b, a
	end

	if typeB == "bigfloat" then --a is always a table for all of these

		print(`floatA bits: {buffer.readu32(a[1], 0)}\nfloatB bits: {buffer.readu32(b[1], 0)}`)

		if buffer.len(a[1]) < buffer.len(b[1]) then
			a, b = b, a
		end

		local length = buffer.len(a[1])
		local result = bigfloat.new(length)

		local exponentA = bigfloat._getRawExponent(a) - 2 ^ (a[2] - 1) + 1
		local exponentB = bigfloat._getRawExponent(b) - 2 ^ (b[2] - 1) + 1

		local floatA = exponentA >= exponentB and a or b
		local floatB = exponentA >= exponentB and b or a

		local displacement = math.abs(exponentA - exponentB)
		local transitionByteB = buffer.len(floatB[1]) - math.floor((floatB[2] + 1) / 8) - 1
		local alignedMantissa = buffer.create(transitionByteB + math.floor(displacement / 8) + 1)

		--print(`bitDisplacement: {displacement}, transitionByteB: {transitionByteB}, alignedMantissaLength: {buffer.len(alignedMantissa)}`)

		--I FOUND THE ISSUE (for 11.1 + 4)!! (09/24/24)
		--IT ONLY BITSHIFTS THE MANTISSA, 4'S MANTISSA IS EMPTY, THE DATA IS STORED IN THE EXPONENT ALONE
		for i = 0, transitionByteB do
			local bitmask = i == transitionByteB and 2 ^ (floatB[3] - transitionByteB * 8) - 1 or 255
			local byte = bit32.band(buffer.readu8(floatB[1], i), bitmask)
			--print(`byte: {byte}`)
			if displacement > 0 then --avoid unnecessary computations
				local nextByte = transitionByteB >= i + 1 and bit32.band(buffer.readu8(floatB[1], i + 1), i + 1 == transitionByteB and 2 ^ (floatB[3] - transitionByteB * 8) - 1 or 255) or 0
				byte = byte // (displacement + 1) + bit32.band(nextByte, 2 ^ displacement - 1) * 2 ^ (8 - displacement) + i == transitionByteB and 2 ^ (floatB[3] - transitionByteB * 8 - displacement) or 0
				--THIS WILL BREAK IF DISPLACEMENT IS LARGER THAN 8, IN THAT CASE YOU NEED TO IMPLEMENT A LESS EFFICIENT METHOD
			end
			--print(`nextByte: {nextByte}\nresultByte: {byte}\n`)
			buffer.writeu8(alignedMantissa, i, byte)
		end

		local function getbinary(b)
			local t = {}

			for i = 0, buffer.len(b) - 1 do
				local s = wholeNumberToBinary(tostring(buffer.readu8(b, i)))

				t[i] = string.rep("0", 8 - #s) .. s .. (i > 0 and " " or "")
			end

			local s = ""

			for i = #t, 0, -1 do
				s ..= t[i]
			end

			return {s, t}
		end

		warn(getbinary(floatA[1]), getbinary(floatB[1]), getbinary(alignedMantissa))

		--probably redo everything after here
		local transitionByteA = length - math.floor((floatA[2] + 1) / 8) - 1
		local transitionBitMask = 2 ^ (floatA[3] - transitionByteA * 8) - 1
		local displacement = transitionByteA - buffer.len(alignedMantissa) + 1

		--print(buffer.len(alignedMantissa), displacement, transitionByteA)

		local carryOver = 0

		for i = 0, transitionByteA do
			local bitmask = i == transitionByteA and 2 ^ (floatA[3] - transitionByteA * 8) - 1 or 255
			local byteA = buffer.readu8(floatA[1], i)

			local byteB = buffer.readu8(alignedMantissa, i - displacement)
			local byte = bit32.band(byteA, bitmask) + bit32.band(byteB, bitmask) + carryOver--bit32.band(byteA, 256 - transitionMantissa) + bit32.band(byteA, transitionMantissa - 1) + bit32.band(byteB, transitionMantissa - 1)
			carryOver, byte = math.floor(byte / (bitmask + 1)), byte % (bitmask + 1)
			--print(`byteA: {byteA}\nbyteB: {byteB}\nnewByte: {byte}\n`)
			buffer.writeu8(result[1], i, byte)
		end

		if carryOver == 1 then --overflow, bitshift right by 1 --TODO!!!!!!!!:
			for i = 0, transitionByteA do
				local byte = buffer.readu8(floatB[1], i)
				local nextByte = transitionByteA >= i + 1 and buffer.readu8(floatB[1], i + 1) or 0
				--print(`byte: {byte}`)
				--The line bitshifts the byte, then if its the transitionByte it adds the exponent bits (i think)
				byte = byte // 2 + bit32.band(nextByte, 1) * 127 + i == transitionByteA and bit32.band(buffer.readu8(floatA[1], transitionByteA), 256 - 2 ^ (floatB[3] - transitionByteB * 8)) or 0
				--print(`nextByte: {nextByte}\nresultByte: {byte}\n`)
				buffer.writeu8(result[1], i, byte)
			end
		end

		warn(getbinary(result[1]))

		--Exponent is not being calculated! Any changes to the exponent will be lost because you assume all the calculations are isolated in the mantissa! (10/04/24)

		buffer.copy(result[1], transitionByteA + 1, floatA[1], transitionByteA + 1) --This is the issue (10/1/24)

		return buffer.readf32(result[1], 0)

		--local result = bigfloat.new(buffer.len(a[1]))
		--local copyB = buffer.copy(buffer.create(buffer.len(b[1])), 0, b[1])

		--local overlap, mantissaBytes = buffer.len(a[1]) - buffer.len(b[1]), math.ceil(a[3] / 8)

		--local bytes = {}

		--for i = 0, mantissaBytes do
		--	local byteA = buffer.readu8(a[1], i)
		--	local byteB = i >= overlap and buffer.readu8(b[1], i - overlap) or 0

		--	local mantissaBits = i == mantissaBytes and a[3] % 8 or 8
		--	local carryBit, byteC = byteA + byteB < 2 ^ mantissaBits and 0 or 1, (byteA + byteB) % 2 ^ mantissaBits

		--	bytes[i] = {byteC, carryBit, mantissaBits}
		--end

		--for i, byteData in bytes do
		--	--how tf am i supposed to write this to a buffer while taking into account carries and then truncate the bits overflowing the mantissa
		--	local byte = byteData[1] + (bytes[i - 1] and bytes[i - 1][2] or 0)

		--	if byte > 2 ^ byteData[3] then
		--		byte -= 2 ^ byteData[3]

		--		if bytes[i + 1] then
		--			bytes[i + 1] += 2
		--		else
		--			--0_0
		--			--bitshift to the right some quantity
		--		end
		--	end

		--	buffer.writeu8(result[1], i, byte)
		--end
	elseif typeB == "number" then

	elseif typeB == "string" then

	end

	error(`Attempt to perform arithmetic (add) on {typeA} and {typeB}`)
end

function bigfloat.__sub()

end

function bigfloat.__mul()

end

function bigfloat.__div()

end

function bigfloat.__idiv() -- //

end

function bigfloat.__mod()

end

function bigfloat.__pow()

end

function bigfloat.__tostring()

end

function bigfloat.__lt() -- <

end

function bigfloat.__le() -- <=

end

function bigfloat.__len()
	error("attempt to get length of a number value")
end

return bigfloat
