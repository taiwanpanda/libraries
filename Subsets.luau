local Subsets = {}

local factorial = {
	[0] = 1,
	[1] = 1,
}

for i = 2, 170 do
	factorial[i] = factorial[i - 1] * i
end

local binomialCoefficient = {}

for n = 0, 170 do
	binomialCoefficient[n] = {}

	for k = 0, n do
		binomialCoefficient[n][k] = factorial[n] / (factorial[k] * factorial[n - k])
	end
end

local setSizes = {[0] = 0}

for i = 1, 170 do
	setSizes[i] = setSizes[i - 1] + binomialCoefficient[170][i]
end

function Subsets.constructSetFromIndex(n, setSize)
	local subset = {}

	if n < 1 then
		return subset
	end

	local size = 0
	for l = 1, setSize do
		if n <= setSizes[l] then
			size = l
			break
		end
	end

	local offset = n - setSizes[size - 1]

	local start = 1
	for i = 1, size do
		for j = start, setSize do
			local countedSubsets = binomialCoefficient[setSize - j][size - i]

			if offset <= countedSubsets then
				table.insert(subset, j)
				start = j + 1
				break
			else
				offset -= countedSubsets
			end
		end
	end

	return subset
end

function Subsets.findIndexFromSet(subset, setSize)
	local length = #subset
	local position = setSizes[length - 1] or 0

	if length == 0 then
		return 0
	end

	local previous = 0
	for i, v in subset do
		for skipped = previous + 1, v - 1 do
			position += binomialCoefficient[setSize - skipped][length - i]
		end
		previous = v
	end

	return position + 1
end

return Subsets
