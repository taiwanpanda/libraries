--!optimize 2
--!native

local VLBuffer = {}
VLBuffer.__index = VLBuffer

function VLBuffer.new()
	return setmetatable({
		Data = buffer.create(0)
	}, VLBuffer)
end

function VLBuffer:Append(...: buffer...)
	local incomingData = {...}
	local byteLength = buffer.len(self.Data)
	
	for _, data in incomingData do
		byteLength += buffer.len(data)
	end
	
	local outputData = buffer.create(byteLength)
	buffer.copy(outputData, 0, self.Data, 0)
	
	local position = buffer.len(self.Data)
	
	for _, data in incomingData do
		buffer.copy(outputData, position, data, 0)
		position += buffer.len(data)
	end
	
	self.Data = outputData
	return self
end

function VLBuffer:Enumerate(bytes: number)
	local newData = buffer.create(buffer.len(self.Data) + bytes)
	buffer.copy(newData, 0, self.Data, 0)

	self.Data = newData
	return self
end

return VLBuffer
